import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:file_picker/file_picker.dart';
import 'dart:io';
import 'dart:convert';
import 'dart:async';
import 'package:desktop_drop/desktop_drop.dart';
import 'dart:ui';
import 'dart:isolate';

import '../models/csv_undoable_actions.dart';
import '../services/csv_file_service.dart';
import '../services/csv_history_service.dart';
import '../services/window_manager_service.dart';
import '../widgets/csv_dialogs.dart';
import '../widgets/csv_table_widgets.dart';
import '../widgets/csv_toolbar.dart';
import '../widgets/csv_status_bar.dart';
import '../widgets/csv_search_bar.dart';
import '../widgets/csv_history_board.dart';
import '../mixins/csv_operations_mixin.dart';
import '../mixins/csv_undo_redo_mixin.dart';
import '../theme/csv_theme.dart';

class CsvReaderScreenModern extends StatefulWidget {
  const CsvReaderScreenModern({super.key});

  @override
  State<CsvReaderScreenModern> createState() => _CsvReaderScreenModernState();
}

class _CsvReaderScreenModernState extends State<CsvReaderScreenModern>
    with CsvOperationsMixin, CsvUndoRedoMixin {
  List<List<String>> _allCsvData = [];
  List<String> _headers = [];
  bool _isLoading = false;
  String? _fileName;
  int _totalRows = 0;
  bool _isDragging = false;
  File? _currentFile;
  final ScrollController _horizontalScrollController = ScrollController();
  final ScrollController _verticalScrollController = ScrollController();
  final FocusNode _keyboardFocusNode = FocusNode();
  List<List<String>> _filteredData = [];
  Key _listKey = UniqueKey();
  final Map<int, int> _filteredIndexToOriginalIndex = {};

  // History service
  final CsvHistoryService _historyService = CsvHistoryService();
  bool _showHistoryBoard = false;

  // Editing state
  bool _hasUnsavedChanges = false;
  bool _showCheckboxes = false;

  // Column widths (index 0 is line number column)
  final List<double> _columnWidths = [];

  // Row selection and actions
  final Set<int> _selectedRowIndices = {};
  final Set<String> _selectedCells = {};
  final List<UndoableAction> _actionHistory = [];
  int _currentActionIndex = -1;

  // Advanced search/filter state
  final Set<int> _selectedSearchColumns = {};
  int? _rowRangeStart;
  int? _rowRangeEnd;
  bool _caseSensitive = false;
  bool _useRegex = false;
  bool _showAdvancedSearch = false;
  String _searchQuery = '';
  Timer? _searchDebounceTimer;

  // Drag & drop state
  int? _draggingColumnIndex;
  int? _draggingRowIndex;

  // Display mode state
  bool _compactMode =
      false; // When true, show collapsed rows with truncated text

  // Remember last directory path
  String? _lastDirectoryPath;

  // Calculate line number column width based on number of rows
  double get _lineNumberColumnWidth {
    if (_totalRows == 0) return 60;
    final digits = _totalRows.toString().length;
    // Minimum 60 to accommodate icon + number + padding
    return (40 + (digits * 10.0)).clamp(60.0, 120.0);
  }

  // Implement getters/setters for mixins
  @override
  List<List<String>> get csvData => _allCsvData;

  @override
  set csvData(List<List<String>> value) => _allCsvData = value;

  @override
  List<String> get headers => _headers;

  @override
  set headers(List<String> value) => _headers = value;

  @override
  List<UndoableAction> get actionHistory => _actionHistory;

  @override
  int get currentActionIndex => _currentActionIndex;

  @override
  set currentActionIndex(int value) => _currentActionIndex = value;

  @override
  void rebuildFilteredData() {
    _filteredData = List.from(_allCsvData);
    _rebuildFilteredIndexMapping();
    _totalRows = _allCsvData.length;
  }

  @override
  void clearSelections() {
    _selectedRowIndices.clear();
    _selectedCells.clear();
  }

  @override
  void markUnsavedChanges() {
    _hasUnsavedChanges = true;
  }

  @override
  void forceRebuild() {
    _listKey = UniqueKey();
  }

  bool get _canUndo => canUndo;
  bool get _canRedo => canRedo;

  @override
  void initState() {
    super.initState();
    _verticalScrollController.addListener(_onScroll);
    _initializeHistoryService();
    // Request focus for keyboard shortcuts when the widget is built
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _keyboardFocusNode.requestFocus();
    });
  }

  Future<void> _initializeHistoryService() async {
    await _historyService.initialize();
  }

  @override
  void dispose() {
    _searchDebounceTimer?.cancel();
    _verticalScrollController.removeListener(_onScroll);
    _horizontalScrollController.dispose();
    _verticalScrollController.dispose();
    _keyboardFocusNode.dispose();
    super.dispose();
  }

  void _onScroll() {
    // Placeholder for future virtualization implementation
  }

  Future<String?> _showEncodingDialog() async {
    return showDialog<String>(
      context: context,
      builder: (context) => const EncodingSelectionDialog(),
    );
  }

  void _initializeColumnWidths() {
    _columnWidths.clear();
    _columnWidths.add(_lineNumberColumnWidth);

    // Get screen width
    final screenWidth = MediaQuery.of(context).size.width;

    // Calculate available width (subtract margins, padding, scrollbar, borders)
    final availableWidth = screenWidth -
        (CsvTheme.spacingMd * 2) - // table margins
        _lineNumberColumnWidth - // line number column
        (_showCheckboxes ? 48 : 0) - // checkbox column
        24; // scrollbar width + padding buffer

    // Minimum column width
    const minColumnWidth = 150.0;

    // Calculate column width based on number of columns
    final numColumns = _headers.length;
    if (numColumns == 0) return;

    final defaultTotalWidth = numColumns * minColumnWidth;

    double columnWidth;
    if (defaultTotalWidth < availableWidth) {
      // If total default width is less than available width, expand columns to fill screen
      columnWidth = availableWidth / numColumns;
      // Ensure column width doesn't exceed a reasonable maximum
      columnWidth = columnWidth.clamp(minColumnWidth, 600.0);
    } else {
      // Otherwise use default width
      columnWidth = minColumnWidth;
    }

    for (int i = 0; i < _headers.length; i++) {
      _columnWidths.add(columnWidth);
    }
  }

  void _addAction(UndoableAction action) => addAction(action);
  void _undo() => undo();
  void _redo() => redo();

  /// Create a history snapshot after each change
  Future<void> _createHistorySnapshot(String actionDescription,
      {String? actionType}) async {
    try {
      await _historyService.createSnapshot(
        headers: _headers,
        data: _allCsvData,
        actionDescription: actionDescription,
        actionType: actionType,
      );
    } catch (e) {
      print('Failed to create history snapshot: $e');
    }
  }

  /// Restore data from a history snapshot
  Future<void> _restoreFromHistory(String snapshotId) async {
    try {
      final result = await _historyService.restoreFromSnapshot(snapshotId);

      setState(() {
        // Save current state before restoring
        _createHistorySnapshot(
            'Before restore to: ${result.entry.actionDescription}',
            actionType: 'restore');

        // Restore data
        _headers = List.from(result.headers);
        _allCsvData = result.data.map((row) => List<String>.from(row)).toList();
        _filteredData = List.from(_allCsvData);
        _totalRows = _allCsvData.length;
        _rebuildFilteredIndexMapping();
        _initializeColumnWidths();
        _listKey = UniqueKey();
        _hasUnsavedChanges = true;

        // Clear undo/redo history since we're jumping to a different state
        clearHistory();
        _selectedRowIndices.clear();
        _selectedCells.clear();
      });

      // Create a snapshot of the restored state
      await _createHistorySnapshot(
          'Restored to: ${result.entry.actionDescription}',
          actionType: 'restore');

      _showSnackBar(
        'Restored to snapshot from ${result.entry.formattedTimestamp}',
        type: SnackBarType.success,
      );
    } catch (e) {
      _showSnackBar(
        'Failed to restore from history: $e',
        type: SnackBarType.error,
      );
    }
  }

  void _toggleRowSelection(int rowIndex) {
    setState(() {
      if (_selectedRowIndices.contains(rowIndex)) {
        _selectedRowIndices.remove(rowIndex);
      } else {
        _selectedRowIndices.add(rowIndex);
      }
    });
  }

  void _addNewRow() {
    addNewRow();
    _createHistorySnapshot('Added new row', actionType: 'add');
  }

  void _addColumn(
      {int? afterIndex, bool duplicate = false, int? duplicateIndex}) {
    if (afterIndex != null && _columnWidths.length > afterIndex + 1) {
      _columnWidths.insert(afterIndex + 2, 150.0);
    } else {
      _columnWidths.add(150.0);
    }

    addColumn(
        afterIndex: afterIndex,
        duplicate: duplicate,
        duplicateIndex: duplicateIndex);

    _createHistorySnapshot(
      duplicate ? 'Duplicated column' : 'Added new column',
      actionType: 'add',
    );
  }

  void _deleteColumn(int columnIndex) {
    final columnName = columnIndex < _headers.length
        ? _headers[columnIndex]
        : 'Column ${columnIndex + 1}';
    if (_columnWidths.length > columnIndex + 1) {
      _columnWidths.removeAt(columnIndex + 1);
    }
    deleteColumn(columnIndex);
    _createHistorySnapshot('Deleted column: $columnName', actionType: 'delete');
  }

  void _renameColumn(int columnIndex, String currentName) {
    showDialog(
      context: context,
      builder: (context) => RenameColumnDialog(
        currentName: currentName,
        onSave: (newName) {
          renameColumn(columnIndex, newName);
          _createHistorySnapshot('Renamed column: $currentName → $newName',
              actionType: 'edit');
        },
      ),
    );
  }

  void _deleteSelectedRows() {
    final count = _selectedRowIndices.length;
    deleteRows(_selectedRowIndices);
    setState(() {
      _selectedRowIndices.clear();
    });
    _createHistorySnapshot('Deleted $count row${count > 1 ? 's' : ''}',
        actionType: 'delete');
  }

  void _mergeSelectedRows() {
    if (_selectedRowIndices.length < 2) {
      _showSnackBar(
        'Please select at least 2 rows to merge',
        type: SnackBarType.info,
      );
      return;
    }

    showDialog(
      context: context,
      builder: (context) => MergeRowsDialog(
        selectedCount: _selectedRowIndices.length,
        onMerge: (separator, keepFirst) {
          final sortedIndices = _selectedRowIndices.toList()..sort();
          final targetIndex =
              keepFirst ? sortedIndices.first : sortedIndices.last;

          final mergedRow = <String>[];
          for (int col = 0; col < _headers.length; col++) {
            final cellValues = <String>[];
            for (final rowIndex in sortedIndices) {
              if (col < _allCsvData[rowIndex].length) {
                final value = _allCsvData[rowIndex][col].trim();
                if (value.isNotEmpty) {
                  cellValues.add(value);
                }
              }
            }
            mergedRow.add(cellValues.join(separator));
          }

          final Map<int, List<String>> deletedRows = {};
          for (final index in sortedIndices) {
            deletedRows[index] = List.from(_allCsvData[index]);
          }

          final action = MergeRowsAction(
            _allCsvData,
            targetIndex,
            sortedIndices,
            mergedRow,
            deletedRows,
          );

          setState(() {
            action.redo();
            _addAction(action);
            _selectedRowIndices.clear();
            _totalRows = _allCsvData.length;
            _filteredData = List.from(_allCsvData);
            _rebuildFilteredIndexMapping();
            _listKey = UniqueKey();
            _hasUnsavedChanges = true;
          });

          _showSnackBar(
            'Merged ${sortedIndices.length} rows',
            type: SnackBarType.success,
          );
          _createHistorySnapshot('Merged ${sortedIndices.length} rows',
              actionType: 'merge');
        },
      ),
    );
  }

  void _deleteEmptyRows() {
    deleteEmptyRows();
    _createHistorySnapshot('Deleted empty rows', actionType: 'delete');
  }

  void _removeDuplicateRows() {
    removeDuplicateRows();
    _createHistorySnapshot('Removed duplicate rows', actionType: 'delete');
  }

  void _deleteEmptyColumns() {
    deleteEmptyColumns();
    setState(() {
      while (_columnWidths.length > _headers.length + 1) {
        _columnWidths.removeLast();
      }
    });
    _createHistorySnapshot('Deleted empty columns', actionType: 'delete');
  }

  void _reorderColumn(int fromIndex, int toIndex) {
    if (fromIndex == toIndex || fromIndex < 0 || toIndex < 0) return;
    if (fromIndex >= _headers.length || toIndex >= _headers.length) return;

    setState(() {
      // Reorder header (create mutable copy)
      final newHeaders = List<String>.from(_headers);
      final header = newHeaders.removeAt(fromIndex);
      newHeaders.insert(toIndex, header);
      _headers = newHeaders;

      // Reorder column width (remember index 0 is line number column)
      final width = _columnWidths.removeAt(fromIndex + 1);
      _columnWidths.insert(toIndex + 1, width);

      // Reorder data in each row (create mutable copies)
      final newData = <List<String>>[];
      for (var row in _allCsvData) {
        final mutableRow = List<String>.from(row);
        if (fromIndex < mutableRow.length && toIndex < mutableRow.length) {
          final cell = mutableRow.removeAt(fromIndex);
          mutableRow.insert(toIndex, cell);
        }
        newData.add(mutableRow);
      }
      _allCsvData = newData;

      _filteredData = List.from(_allCsvData);
      _rebuildFilteredIndexMapping();
      _listKey = UniqueKey();
      _hasUnsavedChanges = true;
    });

    _showSnackBar(
      'Column moved from position ${fromIndex + 1} to ${toIndex + 1}',
      type: SnackBarType.success,
    );
    _createHistorySnapshot(
        'Reordered column from ${fromIndex + 1} to ${toIndex + 1}',
        actionType: 'edit');
  }

  void _reorderRow(int fromIndex, int toIndex) {
    if (fromIndex == toIndex || fromIndex < 0 || toIndex < 0) return;
    if (fromIndex >= _allCsvData.length || toIndex >= _allCsvData.length) {
      return;
    }

    setState(() {
      // Move the row
      final row = _allCsvData.removeAt(fromIndex);
      _allCsvData.insert(toIndex, row);

      _filteredData = List.from(_allCsvData);
      _rebuildFilteredIndexMapping();
      _listKey = UniqueKey();
      _hasUnsavedChanges = true;

      // Update selected row indices
      if (_selectedRowIndices.contains(fromIndex)) {
        _selectedRowIndices.remove(fromIndex);
        _selectedRowIndices.add(toIndex);
      }
    });

    _showSnackBar(
      'Row moved from line ${fromIndex + 1} to line ${toIndex + 1}',
      type: SnackBarType.success,
    );
    _createHistorySnapshot(
        'Reordered row from ${fromIndex + 1} to ${toIndex + 1}',
        actionType: 'edit');
  }

  void _toggleCellSelection(int rowIndex, int colIndex) {
    setState(() {
      final cellKey = '$rowIndex:$colIndex';
      if (_selectedCells.contains(cellKey)) {
        _selectedCells.remove(cellKey);
      } else {
        _selectedCells.add(cellKey);
      }
    });
  }

  void _bulkEditCells() {
    if (_selectedCells.isEmpty) return;

    final firstCellKey = _selectedCells.first;
    final parts = firstCellKey.split(':');
    final rowIndex = int.parse(parts[0]);
    final colIndex = int.parse(parts[1]);
    final initialValue =
        rowIndex < _allCsvData.length && colIndex < _allCsvData[rowIndex].length
            ? _allCsvData[rowIndex][colIndex]
            : '';

    showDialog(
      context: context,
      builder: (context) => BulkEditDialog(
        initialValue: initialValue,
        cellCount: _selectedCells.length,
        onSave: (newValue) {
          bulkEditCells(_selectedCells, newValue);
          setState(() {
            _selectedCells.clear();
          });
          _createHistorySnapshot('Bulk edited ${_selectedCells.length} cells',
              actionType: 'edit');
        },
      ),
    );
  }

  void _splitCells() {
    if (_selectedCells.isEmpty) {
      _showSnackBar(
        'Please select cells to split',
        type: SnackBarType.info,
      );
      return;
    }

    showDialog(
      context: context,
      builder: (context) => SplitDialog(
        mode: 'cells',
        selectionCount: _selectedCells.length,
        onSplit: (delimiter) {
          _performCellSplit(delimiter);
        },
      ),
    );
  }

  void _splitRows() {
    if (_selectedRowIndices.isEmpty) {
      _showSnackBar(
        'Please select rows to split',
        type: SnackBarType.info,
      );
      return;
    }

    showDialog(
      context: context,
      builder: (context) => SplitDialog(
        mode: 'rows',
        selectionCount: _selectedRowIndices.length,
        onSplit: (delimiter) {
          _performRowSplit(delimiter);
        },
      ),
    );
  }

  void _performCellSplit(String delimiter) {
    // Backup old state
    final oldData = _allCsvData.map((row) => List<String>.from(row)).toList();
    final oldHeaders = List<String>.from(_headers);

    setState(() {
      // Split cells into new rows
      final newRows = <List<String>>[];
      final cellsByRow = <int, List<int>>{};

      // Group cells by row
      for (final cellKey in _selectedCells) {
        final parts = cellKey.split(':');
        final rowIndex = int.parse(parts[0]);
        final colIndex = int.parse(parts[1]);
        cellsByRow.putIfAbsent(rowIndex, () => []).add(colIndex);
      }

      // Process each row
      for (int i = 0; i < _allCsvData.length; i++) {
        final row = List<String>.from(_allCsvData[i]);

        if (cellsByRow.containsKey(i)) {
          final colIndices = cellsByRow[i]!;
          final maxSplits = colIndices
              .map((col) => row[col].split(delimiter).length)
              .reduce((a, b) => a > b ? a : b);

          // Create rows for each split
          for (int splitIdx = 0; splitIdx < maxSplits; splitIdx++) {
            final newRow = List<String>.from(row);
            for (int colIdx = 0; colIdx < newRow.length; colIdx++) {
              if (colIndices.contains(colIdx)) {
                // This is a selected cell - split it
                final splits = row[colIdx].split(delimiter);
                if (splits.length == 1) {
                  // No delimiter found - duplicate the value
                  newRow[colIdx] = splits[0].trim();
                } else {
                  // Delimiter found - use the split value
                  newRow[colIdx] =
                      splitIdx < splits.length ? splits[splitIdx].trim() : '';
                }
              }
              // Non-selected cells keep their original value (already set by List.from)
            }
            newRows.add(newRow);
          }
        } else {
          // Row not affected by split
          newRows.add(row);
        }
      }

      _allCsvData = newRows;

      // Create undoable action
      final action = SplitCellsAction(
        data: _allCsvData,
        headers: _headers,
        oldData: oldData,
        oldHeaders: oldHeaders,
        newData: _allCsvData.map((row) => List<String>.from(row)).toList(),
        newHeaders: List<String>.from(_headers),
      );
      _addAction(action);

      _filteredData = List.from(_allCsvData);
      _totalRows = _allCsvData.length;
      _rebuildFilteredIndexMapping();
      _listKey = UniqueKey();
      _hasUnsavedChanges = true;
      _selectedCells.clear();
    });

    _showSnackBar(
      'Cells split successfully',
      type: SnackBarType.success,
    );
    _createHistorySnapshot('Split ${_selectedCells.length} cells',
        actionType: 'split');
  }

  void _performRowSplit(String delimiter) {
    final sortedIndices = _selectedRowIndices.toList()..sort();

    // Backup old state
    final oldData = _allCsvData.map((row) => List<String>.from(row)).toList();

    setState(() {
      final newRows = <List<String>>[];

      for (int i = 0; i < _allCsvData.length; i++) {
        final row = List<String>.from(_allCsvData[i]);

        if (sortedIndices.contains(i)) {
          // Find max splits in any cell
          int maxSplits = 1;
          for (final cell in row) {
            final splits = cell.split(delimiter).length;
            if (splits > maxSplits) maxSplits = splits;
          }

          // Create new rows
          for (int splitIdx = 0; splitIdx < maxSplits; splitIdx++) {
            final newRow = <String>[];
            for (final cell in row) {
              final splits = cell.split(delimiter);
              if (splits.length == 1) {
                // No delimiter found - duplicate the value to all new rows
                newRow.add(splits[0].trim());
              } else {
                // Delimiter found - use the split value or empty string
                newRow.add(
                    splitIdx < splits.length ? splits[splitIdx].trim() : '');
              }
            }
            newRows.add(newRow);
          }
        } else {
          newRows.add(row);
        }
      }

      _allCsvData = newRows;

      // Create undoable action
      final action = SplitRowsAction(
        data: _allCsvData,
        oldData: oldData,
        newData: _allCsvData.map((row) => List<String>.from(row)).toList(),
      );
      _addAction(action);

      _filteredData = List.from(_allCsvData);
      _totalRows = _allCsvData.length;
      _rebuildFilteredIndexMapping();
      _listKey = UniqueKey();
      _hasUnsavedChanges = true;
      _selectedRowIndices.clear();
    });

    _showSnackBar(
      'Rows split successfully',
      type: SnackBarType.success,
    );
    _createHistorySnapshot('Split ${_selectedRowIndices.length} rows',
        actionType: 'split');
  }

  void _startEditing(int rowIndex, int colIndex, String currentValue) {
    showDialog(
      context: context,
      builder: (context) => EditCellDialog(
        initialValue: currentValue,
        columnName: _headers.isNotEmpty && colIndex < _headers.length
            ? _headers[colIndex]
            : 'Column ${colIndex + 1}',
        onSave: (newValue) {
          final row = _filteredData[rowIndex];
          final originalRowIndex = _allCsvData.indexOf(row);

          if (originalRowIndex != -1) {
            editCell(originalRowIndex, colIndex, newValue);
            setState(() {
              _filteredData[rowIndex][colIndex] = newValue;
            });
            _createHistorySnapshot('Edited cell', actionType: 'edit');
          }
        },
      ),
    );
  }

  Future<void> _saveToFile() async {
    if (!_hasUnsavedChanges || _currentFile == null) return;

    try {
      await CsvFileService.saveCsvFile(_currentFile!, _headers, _allCsvData);

      setState(() {
        _hasUnsavedChanges = false;
      });

      if (mounted) {
        _showSnackBar('Changes saved successfully!',
            type: SnackBarType.success);
      }
    } catch (e) {
      if (mounted) {
        _showSnackBar('Error saving file: $e', type: SnackBarType.error);
      }
    }
  }

  Future<void> _reloadWithDifferentEncoding() async {
    if (_currentFile == null) return;

    final encodingName = await _showEncodingDialog();
    if (encodingName == null) return;

    setState(() {
      _isLoading = true;
      _allCsvData = [];
      _filteredData = [];
      clearHistory();
      _hasUnsavedChanges = false;
      _selectedRowIndices.clear();
      _selectedCells.clear();
    });

    final selectedEncoding = CsvFileService.getEncodingFromString(encodingName);
    await _readCsvFileGradually(_currentFile!, encoding: selectedEncoding);
  }

  Future<void> _pickAndReadCsvFile() async {
    try {
      FilePickerResult? result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['csv'],
        initialDirectory: _lastDirectoryPath,
      );

      if (result != null && result.files.single.path != null) {
        final filePath = result.files.single.path!;
        final file = File(filePath);

        // Remember the directory for next time
        _lastDirectoryPath = file.parent.path;

        setState(() {
          _isLoading = true;
          _fileName = result.files.single.name;
          _allCsvData = [];
          _filteredData = [];
          clearHistory();
          _hasUnsavedChanges = false;
          _selectedRowIndices.clear();
          _selectedCells.clear();
        });

        _currentFile = file;
        await _readCsvFileGradually(file);
      }
    } catch (e) {
      if (mounted) {
        _showSnackBar('Error loading file: $e', type: SnackBarType.error);
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _readCsvFileGradually(File file, {Encoding? encoding}) async {
    try {
      // First, check file size quickly
      final fileSize = await file.length();
      final estimatedRows =
          (fileSize / 100).round(); // Rough estimate: ~100 bytes per row

      // For very large files (>5MB or estimated >50k rows), use streaming
      if (fileSize > 5 * 1024 * 1024 || estimatedRows > 50000) {
        await _readCsvFileWithStreaming(file, encoding ?? utf8);
        return;
      }

      // For smaller files, use the fast in-memory approach
      final csvFileData =
          await CsvFileService.readCsvFile(file, encoding: encoding);

      if (mounted) {
        setState(() {
          _currentFile = file;
          _fileName = file.path.split('/').last;
          _allCsvData = csvFileData.data;
          _filteredData = csvFileData.data;
          _headers = csvFileData.headers;
          _totalRows = csvFileData.data.length;
          _rebuildFilteredIndexMapping();
          _initializeColumnWidths();
          _isLoading = false;
        });

        // Start new history session and create initial snapshot
        await _historyService.startNewSession(_fileName!);
        await _createHistorySnapshot('Loaded file: $_fileName',
            actionType: 'initial');
      }
    } catch (e) {
      if (e.toString().contains('decode') && encoding == null) {
        if (mounted) {
          final encodingName = await _showEncodingDialog();
          if (encodingName == null) {
            setState(() {
              _isLoading = false;
            });
            return;
          }
          final selectedEncoding =
              CsvFileService.getEncodingFromString(encodingName);
          await _readCsvFileGradually(file, encoding: selectedEncoding);
        }
      } else {
        if (mounted) {
          setState(() {
            _isLoading = false;
          });
          _showSnackBar('Error loading CSV: $e', type: SnackBarType.error);
        }
      }
    }
  }

  /// Fast streaming load with animated dialog to mask any freeze
  Future<void> _readCsvFileWithStreaming(File file, Encoding encoding) async {
    String? loadingFileName = file.path.split('/').last;

    try {
      // Show ANIMATED loading dialog BEFORE any heavy work
      // This ensures the animation starts smoothly
      if (mounted) {
        showDialog(
          context: context,
          barrierDismissible: false,
          builder: (context) =>
              _AnimatedLoadingDialog(fileName: loadingFileName),
        );
      }

      // Small delay to ensure dialog animation starts
      await Future.delayed(const Duration(milliseconds: 100));

      final List<List<String>> allRows = [];
      List<String>? headers;

      // Fast bulk parse - no interruptions for maximum speed
      await for (final line in file
          .openRead()
          .transform(encoding.decoder)
          .transform(const LineSplitter())) {
        final List<String> row = _parseCsvLineStatic(line);

        if (headers == null) {
          headers = row;
        } else {
          allRows.add(row);
        }
      }

      // Close dialog
      if (mounted) {
        Navigator.of(context).pop();
      }

      // Apply data
      if (mounted) {
        setState(() {
          _currentFile = file;
          _fileName = file.path.split('/').last;
          _headers = headers ?? [];
          _allCsvData = allRows;
          _filteredData = allRows;
          _totalRows = allRows.length;
          _rebuildFilteredIndexMapping();
          _initializeColumnWidths();
          _isLoading = false;
          _listKey = UniqueKey();
        });

        await _historyService.startNewSession(_fileName!);
        await _createHistorySnapshot('Loaded file: $_fileName',
            actionType: 'initial');

        _showSnackBar(
          'Loaded ${_formatNumber(_totalRows)} rows successfully',
          type: SnackBarType.success,
        );
      }
    } catch (e) {
      if (e.toString().contains('decode') ||
          e.toString().contains('FormatException')) {
        if (mounted) {
          Navigator.of(context).pop();
          final encodingName = await _showEncodingDialog();
          if (encodingName != null) {
            final selectedEncoding =
                CsvFileService.getEncodingFromString(encodingName);
            await _readCsvFileWithStreaming(file, selectedEncoding);
          } else {
            setState(() => _isLoading = false);
          }
        }
      } else {
        if (mounted) {
          Navigator.of(context).pop();
          setState(() => _isLoading = false);
          _showSnackBar('Error loading CSV: $e', type: SnackBarType.error);
        }
      }
    }
  }

  /// Background isolate function to parse CSV with chunked transfer
  static void _parseCsvInIsolate(_CsvParseParams params) async {
    try {
      final file = File(params.filePath);
      final List<List<String>> allRows = [];
      List<String>? headers;
      int rowCount = 0;
      final int progressInterval = 10000; // Send progress every 10k rows
      final int chunkSize = 50000; // Send data in chunks of 50k rows
      int lastProgressUpdate = 0;
      int lastChunkSent = 0;

      await for (final line in file
          .openRead()
          .transform(params.encoding.decoder)
          .transform(const LineSplitter())) {
        final List<String> row = _parseCsvLineStatic(line);

        if (headers == null) {
          headers = row;
          // Send headers immediately
          params.sendPort.send(CsvParseHeaders(headers));
        } else {
          allRows.add(row);
          rowCount++;

          // Send progress update
          if (rowCount - lastProgressUpdate >= progressInterval) {
            params.sendPort.send(CsvParseProgress(rowCount));
            lastProgressUpdate = rowCount;
          }

          // Send data in chunks to avoid large transfer freeze
          if (rowCount - lastChunkSent >= chunkSize) {
            final chunkStart = lastChunkSent;
            final chunk = allRows.sublist(chunkStart, rowCount);
            params.sendPort.send(CsvParseChunk(chunk, chunkStart));
            lastChunkSent = rowCount;
          }
        }
      }

      // Send remaining data as final chunk
      if (lastChunkSent < rowCount) {
        final chunk = allRows.sublist(lastChunkSent);
        params.sendPort.send(CsvParseChunk(chunk, lastChunkSent));
      }

      // Send completion signal
      params.sendPort.send(CsvParseComplete(rowCount));
    } catch (e) {
      final isEncodingError = e.toString().contains('decode') ||
          e.toString().contains('FormatException');
      params.sendPort.send(CsvParseError(e.toString(), isEncodingError));
    }
  }

  /// Static version of CSV parser for use in isolate
  static List<String> _parseCsvLineStatic(String line) {
    final List<String> result = [];
    bool inQuotes = false;
    StringBuffer current = StringBuffer();

    for (int i = 0; i < line.length; i++) {
      final char = line[i];

      if (char == '"') {
        if (inQuotes && i + 1 < line.length && line[i + 1] == '"') {
          current.write('"');
          i++;
        } else {
          inQuotes = !inQuotes;
        }
      } else if (char == ',' && !inQuotes) {
        result.add(current.toString());
        current = StringBuffer();
      } else {
        current.write(char);
      }
    }
    result.add(current.toString());

    return result;
  }

  void _rebuildFilteredIndexMapping() {
    _filteredIndexToOriginalIndex.clear();
    if (_filteredData.isEmpty) return;

    for (int filteredIdx = 0;
        filteredIdx < _filteredData.length;
        filteredIdx++) {
      final row = _filteredData[filteredIdx];
      for (int originalIdx = 0;
          originalIdx < _allCsvData.length;
          originalIdx++) {
        if (identical(row, _allCsvData[originalIdx])) {
          _filteredIndexToOriginalIndex[filteredIdx] = originalIdx;
          break;
        }
      }
    }
  }

  void _filterData(String query) {
    // Cancel previous timer
    _searchDebounceTimer?.cancel();

    // Update UI immediately for responsive feel
    setState(() {
      _searchQuery = query;
    });

    // Clear results immediately if query is empty
    if (query.isEmpty &&
        _selectedSearchColumns.isEmpty &&
        _rowRangeStart == null &&
        _rowRangeEnd == null) {
      setState(() {
        _filteredData = _allCsvData;
        _rebuildFilteredIndexMapping();
      });
      return;
    }

    // Debounce the actual filtering by 150ms (shorter for in-memory data)
    _searchDebounceTimer = Timer(const Duration(milliseconds: 150), () {
      if (!mounted) return;

      setState(() {
        _filteredData = _allCsvData
            .asMap()
            .entries
            .where((entry) {
              final rowIndex = entry.key;
              final row = entry.value;

              if (_rowRangeStart != null && rowIndex < _rowRangeStart! - 1) {
                return false;
              }
              if (_rowRangeEnd != null && rowIndex > _rowRangeEnd! - 1) {
                return false;
              }

              if (query.isEmpty) {
                return true;
              }

              final columnsToSearch = _selectedSearchColumns.isEmpty
                  ? List.generate(row.length, (i) => i)
                  : _selectedSearchColumns.toList();

              try {
                if (_useRegex) {
                  final regex = RegExp(query, caseSensitive: _caseSensitive);
                  return columnsToSearch.any((colIndex) {
                    if (colIndex < row.length) {
                      return regex.hasMatch(row[colIndex]);
                    }
                    return false;
                  });
                } else {
                  final searchQuery =
                      _caseSensitive ? query : query.toLowerCase();
                  return columnsToSearch.any((colIndex) {
                    if (colIndex < row.length) {
                      final cellValue = _caseSensitive
                          ? row[colIndex]
                          : row[colIndex].toLowerCase();
                      return cellValue.contains(searchQuery);
                    }
                    return false;
                  });
                }
              } catch (e) {
                final searchQuery = query.toLowerCase();
                return columnsToSearch.any((colIndex) {
                  if (colIndex < row.length) {
                    return row[colIndex].toLowerCase().contains(searchQuery);
                  }
                  return false;
                });
              }
            })
            .map((entry) => entry.value)
            .toList();
        _rebuildFilteredIndexMapping();
      });
    });
  }

  void _resetFilters() {
    setState(() {
      _selectedSearchColumns.clear();
      _rowRangeStart = null;
      _rowRangeEnd = null;
      _caseSensitive = false;
      _useRegex = false;
      _filteredData = _allCsvData;
    });
  }

  String _formatNumber(int number) {
    return number.toString().replaceAllMapped(
          RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'),
          (Match m) => '${m[1]},',
        );
  }

  void _showSnackBar(String message, {SnackBarType type = SnackBarType.info}) {
    if (!mounted) return;

    Color backgroundColor;
    IconData icon;

    switch (type) {
      case SnackBarType.success:
        backgroundColor = CsvTheme.successColor;
        icon = Icons.check_circle_outline;
        break;
      case SnackBarType.error:
        backgroundColor = CsvTheme.errorColor;
        icon = Icons.error_outline;
        break;
      case SnackBarType.warning:
        backgroundColor = CsvTheme.warningColor;
        icon = Icons.warning_amber_rounded;
        break;
      case SnackBarType.info:
        backgroundColor = CsvTheme.infoColor;
        icon = Icons.info_outline;
        break;
    }

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(icon, color: Colors.white, size: 20),
            const SizedBox(width: CsvTheme.spacingMd),
            Expanded(
              child: Text(
                message,
                style: CsvTheme.bodyMedium.copyWith(color: Colors.white),
              ),
            ),
          ],
        ),
        backgroundColor: backgroundColor,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(CsvTheme.radiusMd),
        ),
        margin: const EdgeInsets.all(CsvTheme.spacingLg),
        duration: const Duration(seconds: 3),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return DropTarget(
      onDragEntered: (details) {
        setState(() {
          _isDragging = true;
        });
      },
      onDragExited: (details) {
        setState(() {
          _isDragging = false;
        });
      },
      onDragDone: (details) async {
        setState(() {
          _isDragging = false;
        });
        for (final file in details.files) {
          if (file.path.toLowerCase().endsWith('.csv')) {
            final csvFile = File(file.path);

            // Remember the directory for next time
            _lastDirectoryPath = csvFile.parent.path;

            setState(() {
              clearHistory();
              _hasUnsavedChanges = false;
              _selectedRowIndices.clear();
              _selectedCells.clear();
            });
            await _readCsvFileGradually(csvFile);
            break;
          }
        }
      },
      child: Focus(
        focusNode: _keyboardFocusNode,
        autofocus: true,
        onKeyEvent: (node, event) {
          if (event is KeyDownEvent) {
            final isCmdOrCtrl = HardwareKeyboard.instance.isMetaPressed ||
                HardwareKeyboard.instance.isControlPressed;
            final isShift = HardwareKeyboard.instance.isShiftPressed;

            if (isCmdOrCtrl) {
              if (event.logicalKey == LogicalKeyboardKey.keyS) {
                _saveToFile();
                return KeyEventResult.handled;
              } else if (event.logicalKey == LogicalKeyboardKey.keyZ &&
                  !isShift) {
                _undo();
                return KeyEventResult.handled;
              } else if (event.logicalKey == LogicalKeyboardKey.keyZ &&
                  isShift) {
                _redo();
                return KeyEventResult.handled;
              }
            }
          }
          return KeyEventResult.ignored;
        },
        child: Stack(
          children: [
            Scaffold(
              backgroundColor: CsvTheme.backgroundColor,
              appBar: AppBar(
                backgroundColor: CsvTheme.surfaceColor,
                elevation: 0,
                leading: IconButton(
                  icon: const Icon(Icons.arrow_back),
                  tooltip: 'Back to Main Screen',
                  onPressed: () {
                    Navigator.of(context).pop();
                  },
                ),
                actions: [
                  if (_fileName != null)
                    IconButton(
                      icon: Icon(
                        _compactMode ? Icons.unfold_more : Icons.unfold_less,
                        size: 18,
                      ),
                      tooltip: _compactMode
                          ? 'Expand Rows (Show Full Text)'
                          : 'Compact Mode (Collapse Rows)',
                      onPressed: () {
                        setState(() {
                          _compactMode = !_compactMode;
                        });
                      },
                    ),
                  if (_fileName != null)
                    IconButton(
                      icon: Icon(
                        _showHistoryBoard
                            ? Icons.history_toggle_off
                            : Icons.history,
                        size: 16,
                        color: _showHistoryBoard ? CsvTheme.primaryColor : null,
                      ),
                      tooltip:
                          _showHistoryBoard ? 'Close History' : 'View History',
                      onPressed: () {
                        setState(() {
                          _showHistoryBoard = !_showHistoryBoard;
                        });
                      },
                    ),
                  IconButton(
                    icon: const Icon(Icons.open_in_full, size: 15),
                    tooltip: 'Maximize Window',
                    onPressed: () async {
                      await WindowManagerService.instance.maximizeWindow();
                      if (mounted) setState(() {});
                    },
                  ),
                  const SizedBox(width: 8),
                ],
              ),
              body: Column(
                children: [
                  // Modern Toolbar
                  CsvToolbar(
                    fileName: _fileName,
                    hasUnsavedChanges: _hasUnsavedChanges,
                    canUndo: _canUndo,
                    canRedo: _canRedo,
                    selectedCellsCount: _selectedCells.length,
                    selectedRowsCount: _selectedRowIndices.length,
                    showCheckboxes: _showCheckboxes,
                    onNewFile: _pickAndReadCsvFile,
                    onSave: _saveToFile,
                    onUndo: _undo,
                    onRedo: _redo,
                    onAddRow: _fileName != null ? _addNewRow : null,
                    onAddColumn: _fileName != null ? () => _addColumn() : null,
                    onDeleteRows: _selectedRowIndices.isNotEmpty
                        ? _deleteSelectedRows
                        : null,
                    onMergeRows: _selectedRowIndices.length >= 2
                        ? _mergeSelectedRows
                        : null,
                    onSplitCells:
                        _selectedCells.isNotEmpty ? _splitCells : null,
                    onSplitRows:
                        _selectedRowIndices.isNotEmpty ? _splitRows : null,
                    onBulkEdit: _bulkEditCells,
                    onClearCellSelection: () {
                      setState(() {
                        _selectedCells.clear();
                      });
                    },
                    onToggleCheckboxes: () {
                      setState(() {
                        _showCheckboxes = !_showCheckboxes;
                        if (!_showCheckboxes) {
                          _selectedRowIndices.clear();
                          _selectedCells.clear();
                        }
                      });
                    },
                    onChangeEncoding: _currentFile != null
                        ? _reloadWithDifferentEncoding
                        : null,
                    onCleanupAction: (value) {
                      if (value == 'empty_rows') {
                        _deleteEmptyRows();
                      } else if (value == 'empty_columns') {
                        _deleteEmptyColumns();
                      } else if (value == 'duplicate_rows') {
                        _removeDuplicateRows();
                      }
                    },
                  ),

                  // Search Bar
                  if (_fileName != null)
                    CsvSearchBar(
                      onSearch: _filterData,
                      onToggleAdvanced: () {
                        setState(() {
                          _showAdvancedSearch = !_showAdvancedSearch;
                        });
                      },
                      onResetFilters: _resetFilters,
                      showAdvanced: _showAdvancedSearch,
                      hasActiveFilters: _selectedSearchColumns.isNotEmpty ||
                          _rowRangeStart != null ||
                          _rowRangeEnd != null ||
                          _caseSensitive ||
                          _useRegex,
                    ),

                  // Advanced Search Panel
                  if (_showAdvancedSearch && _fileName != null)
                    CsvAdvancedSearch(
                      headers: _headers,
                      selectedColumns: _selectedSearchColumns,
                      onColumnToggle: (index) {
                        setState(() {
                          if (_selectedSearchColumns.contains(index)) {
                            _selectedSearchColumns.remove(index);
                          } else {
                            _selectedSearchColumns.add(index);
                          }
                          _filterData(_searchQuery);
                        });
                      },
                      onCaseSensitiveChange: (value) {
                        setState(() {
                          _caseSensitive = value;
                          _filterData(_searchQuery);
                        });
                      },
                      onRegexChange: (value) {
                        setState(() {
                          _useRegex = value;
                          _filterData(_searchQuery);
                        });
                      },
                      onRowRangeStartChange: (value) {
                        setState(() {
                          _rowRangeStart = int.tryParse(value);
                          _filterData(_searchQuery);
                        });
                      },
                      onRowRangeEndChange: (value) {
                        setState(() {
                          _rowRangeEnd = int.tryParse(value);
                          _filterData(_searchQuery);
                        });
                      },
                      caseSensitive: _caseSensitive,
                      useRegex: _useRegex,
                      totalRows: _totalRows,
                    ),

                  // CSV Table or Empty State
                  Expanded(
                    child: _isLoading
                        ? Center(
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const CircularProgressIndicator(
                                  valueColor: AlwaysStoppedAnimation<Color>(
                                      CsvTheme.primaryColor),
                                ),
                                const SizedBox(height: CsvTheme.spacingLg),
                                Text(
                                  'Loading CSV file...',
                                  style: CsvTheme.bodyMedium.copyWith(
                                    color: CsvTheme.textSecondary,
                                  ),
                                ),
                              ],
                            ),
                          )
                        : _allCsvData.isEmpty
                            ? _buildEmptyState()
                            : Center(child: _buildTable()),
                  ),

                  // Status Bar
                  if (_fileName != null)
                    CsvStatusBar(
                      fileName: _fileName,
                      totalRows: _totalRows,
                      filteredRows: _filteredData.length,
                      columnCount: _headers.length,
                      selectedRowsCount: _selectedRowIndices.length,
                      encoding: 'UTF-8',
                    ),
                ],
              ),
            ),

            // Drag overlay
            if (_isDragging) _buildDragOverlay(),

            // History Board Overlay
            if (_showHistoryBoard)
              Positioned.fill(
                child: GestureDetector(
                  onTap: () {
                    setState(() {
                      _showHistoryBoard = false;
                    });
                  },
                  child: Container(
                    color: Colors.black.withOpacity(0.5),
                    child: Center(
                      child: GestureDetector(
                        onTap: () {}, // Prevent closing when clicking on panel
                        child: CsvHistoryBoard(
                          onRestore: _restoreFromHistory,
                          onClose: () {
                            setState(() {
                              _showHistoryBoard = false;
                            });
                          },
                        ),
                      ),
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Container(
        constraints: const BoxConstraints(maxWidth: 400),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(CsvTheme.spacing2xl),
              decoration: BoxDecoration(
                color: CsvTheme.primaryLight,
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.table_chart_outlined,
                size: 64,
                color: CsvTheme.primaryColor,
              ),
            ),
            const SizedBox(height: CsvTheme.spacingXl),
            Text(
              'No CSV file loaded',
              style: CsvTheme.headingLarge,
            ),
            const SizedBox(height: CsvTheme.spacingMd),
            Text(
              'Click the button below or drag & drop a CSV file to get started',
              style: CsvTheme.bodyMedium.copyWith(
                color: CsvTheme.textSecondary,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: CsvTheme.spacing2xl),
            ElevatedButton.icon(
              onPressed: _pickAndReadCsvFile,
              icon: const Icon(Icons.upload_file, size: 20),
              label: const Text('Open CSV File'),
              style: CsvTheme.primaryButtonStyle.copyWith(
                padding: const WidgetStatePropertyAll(
                  EdgeInsets.symmetric(
                    horizontal: CsvTheme.spacingXl,
                    vertical: CsvTheme.spacingMd,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTable() {
    final calculatedWidth = _columnWidths.isNotEmpty
        ? _columnWidths.reduce((a, b) => a + b) + (_showCheckboxes ? 48 : 0)
        : 848.0;

    final screenWidth = MediaQuery.of(context).size.width;
    final maxTableWidth = screenWidth - (CsvTheme.spacingMd * 2);

    // Use the larger of calculated width or max screen width to ensure table fills screen
    final tableWidth =
        calculatedWidth > maxTableWidth ? calculatedWidth : maxTableWidth;

    return Container(
      width: tableWidth,
      margin: const EdgeInsets.symmetric(vertical: CsvTheme.spacingMd),
      decoration: BoxDecoration(
        color: CsvTheme.surfaceColor,
        borderRadius: BorderRadius.circular(CsvTheme.radiusLg),
        border: Border.all(color: CsvTheme.borderColor),
        boxShadow: const [CsvTheme.shadowMd],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(CsvTheme.radiusLg),
        child: Scrollbar(
          controller: _horizontalScrollController,
          thumbVisibility: true,
          child: SingleChildScrollView(
            controller: _horizontalScrollController,
            scrollDirection: Axis.horizontal,
            child: SizedBox(
              width: tableWidth,
              child: Column(
                children: [
                  _buildTableHeader(),
                  Expanded(
                    child: Scrollbar(
                      controller: _verticalScrollController,
                      thumbVisibility: true,
                      child: _buildTableBody(),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildTableHeader() {
    return Container(
      decoration: const BoxDecoration(
        color: CsvTheme.tableHeaderBg,
        border: Border(
          bottom: BorderSide(color: CsvTheme.tableCellBorder, width: 1),
        ),
      ),
      child: Row(
        children: [
          if (_showCheckboxes)
            SizedBox(
              width: 48,
              height: 32,
              child: Checkbox(
                value: _selectedRowIndices.length == _allCsvData.length &&
                    _allCsvData.isNotEmpty,
                tristate: true,
                onChanged: (value) {
                  setState(() {
                    if (_selectedRowIndices.length == _allCsvData.length) {
                      _selectedRowIndices.clear();
                    } else {
                      _selectedRowIndices.clear();
                      _selectedRowIndices
                          .addAll(List.generate(_allCsvData.length, (i) => i));
                    }
                  });
                },
              ),
            ),
          _buildHeaderCell('#', 0, isPrimary: true),
          ..._headers
              .asMap()
              .entries
              .map((entry) => _buildHeaderCell(entry.value, entry.key + 1)),
        ],
      ),
    );
  }

  Widget _buildTableBody() {
    return ListView.builder(
      key: _listKey,
      controller: _verticalScrollController,
      itemCount: _filteredData.length,
      cacheExtent: 1000,
      addRepaintBoundaries: true,
      itemBuilder: (context, filteredIndex) {
        final row = _filteredData[filteredIndex];
        final originalIndex =
            _filteredIndexToOriginalIndex[filteredIndex] ?? filteredIndex;
        final lineNumber = originalIndex + 1;
        return Container(
          key: ValueKey('row_$originalIndex'),
          child: _buildDataRow(lineNumber, row, filteredIndex),
        );
      },
    );
  }

  // ... Continue with _buildHeaderCell, _buildDataRow, and _buildDragOverlay methods
  // (These would be similar to the original but with modern styling)

  Widget _buildHeaderCell(String text, int columnIndex,
      {bool isPrimary = false}) {
    final width = _columnWidths.isNotEmpty && columnIndex < _columnWidths.length
        ? _columnWidths[columnIndex]
        : 150.0;

    final dataColumnIndex = columnIndex - 1;
    final isDragging = _draggingColumnIndex == dataColumnIndex;

    return DragTarget<int>(
      onWillAccept: (draggedIndex) => !isPrimary && draggedIndex != null,
      onAccept: (draggedIndex) {
        if (!isPrimary && draggedIndex != dataColumnIndex) {
          _reorderColumn(draggedIndex, dataColumnIndex);
        }
      },
      builder: (context, candidateData, rejectedData) {
        final isHovering = candidateData.isNotEmpty;

        return SizedBox(
          width: width,
          height: 32,
          child: Material(
            color: Colors.transparent,
            child: Stack(
              children: [
                Container(
                  decoration: BoxDecoration(
                    color: isHovering
                        ? CsvTheme.primaryLight.withOpacity(0.3)
                        : isDragging
                            ? CsvTheme.primaryLight.withOpacity(0.5)
                            : Colors.transparent,
                    border: Border(
                      right: const BorderSide(
                          color: CsvTheme.tableCellBorder, width: 1),
                      left: isHovering
                          ? const BorderSide(
                              color: CsvTheme.primaryColor, width: 2)
                          : BorderSide.none,
                    ),
                  ),
                  child: !isPrimary
                      ? Draggable<int>(
                          data: dataColumnIndex,
                          feedback: Material(
                            elevation: 4,
                            child: Container(
                              width: width,
                              height: 32,
                              padding: const EdgeInsets.symmetric(
                                horizontal: CsvTheme.spacingMd,
                                vertical: CsvTheme.spacingSm,
                              ),
                              decoration: BoxDecoration(
                                color: CsvTheme.primaryColor.withOpacity(0.9),
                                border: Border.all(
                                    color: CsvTheme.primaryColor, width: 2),
                              ),
                              child: Text(
                                text,
                                style: CsvTheme.labelMedium.copyWith(
                                  color: Colors.white,
                                  fontWeight: FontWeight.w600,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ),
                          childWhenDragging: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: CsvTheme.spacingMd,
                              vertical: CsvTheme.spacingSm,
                            ),
                            child: Text(
                              text,
                              style: CsvTheme.labelMedium.copyWith(
                                color: CsvTheme.textSecondary.withOpacity(0.3),
                                fontWeight: FontWeight.w600,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          onDragStarted: () {
                            setState(() {
                              _draggingColumnIndex = dataColumnIndex;
                            });
                          },
                          onDragEnd: (details) {
                            setState(() {
                              _draggingColumnIndex = null;
                            });
                          },
                          child: InkWell(
                            onDoubleTap: () =>
                                _renameColumn(dataColumnIndex, text),
                            onSecondaryTapDown: (details) {
                              _showHeaderContextMenu(
                                  details, dataColumnIndex, text);
                            },
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: CsvTheme.spacingMd,
                                vertical: CsvTheme.spacingSm,
                              ),
                              alignment: Alignment.centerLeft,
                              child: Row(
                                children: [
                                  Icon(
                                    Icons.drag_indicator,
                                    size: 16,
                                    color: CsvTheme.textTertiary,
                                  ),
                                  const SizedBox(width: 4),
                                  Expanded(
                                    child: Text(
                                      text,
                                      style: CsvTheme.labelMedium.copyWith(
                                        color: CsvTheme.textSecondary,
                                        fontWeight: FontWeight.w600,
                                      ),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        )
                      : InkWell(
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: CsvTheme.spacingMd,
                              vertical: CsvTheme.spacingSm,
                            ),
                            alignment: Alignment.center,
                            child: Text(
                              text,
                              style: CsvTheme.labelMedium.copyWith(
                                color: CsvTheme.primaryColor,
                                fontWeight: FontWeight.w600,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ),
                ),
                // Resize handle
                if (!isPrimary)
                  Positioned(
                    right: 0,
                    top: 0,
                    bottom: 0,
                    child: MouseRegion(
                      cursor: SystemMouseCursors.resizeColumn,
                      child: GestureDetector(
                        onHorizontalDragUpdate: (details) {
                          setState(() {
                            if (_columnWidths.isNotEmpty &&
                                columnIndex < _columnWidths.length) {
                              final newWidth =
                                  _columnWidths[columnIndex] + details.delta.dx;
                              _columnWidths[columnIndex] =
                                  newWidth.clamp(50.0, 800.0);
                            }
                          });
                        },
                        child: Container(
                          width: 8,
                          color: Colors.transparent,
                          child: Center(
                            child: Container(
                              width: 1,
                              color: CsvTheme.tableCellBorder,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        );
      },
    );
  }

  void _showHeaderContextMenu(
      TapDownDetails details, int columnIndex, String text) {
    showMenu(
      context: context,
      position: RelativeRect.fromLTRB(
        details.globalPosition.dx,
        details.globalPosition.dy,
        details.globalPosition.dx,
        details.globalPosition.dy,
      ),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(CsvTheme.radiusLg),
      ),
      items: [
        _buildContextMenuItem(Icons.edit_outlined, 'Rename Column', 'rename'),
        _buildContextMenuItem(
            Icons.add_box_outlined, 'Add Column After', 'add_after'),
        _buildContextMenuItem(
            Icons.content_copy, 'Duplicate Column', 'duplicate'),
        _buildContextMenuItem(Icons.delete_outline, 'Delete Column', 'delete'),
      ],
    ).then((value) {
      if (value == 'rename') {
        _renameColumn(columnIndex, text);
      } else if (value == 'add_after') {
        _addColumn(afterIndex: columnIndex);
      } else if (value == 'duplicate') {
        _addColumn(
            duplicate: true,
            duplicateIndex: columnIndex,
            afterIndex: columnIndex);
      } else if (value == 'delete') {
        _deleteColumn(columnIndex);
      }
    });
  }

  PopupMenuItem<String> _buildContextMenuItem(
      IconData icon, String label, String value) {
    return PopupMenuItem(
      value: value,
      height: 40,
      child: Row(
        children: [
          Icon(icon, size: 18, color: CsvTheme.textSecondary),
          const SizedBox(width: CsvTheme.spacingMd),
          Text(label, style: CsvTheme.bodyMedium),
        ],
      ),
    );
  }

  Widget _buildDataRow(int lineNumber, List<String> row, int filteredIndex) {
    final originalRowIndex = lineNumber - 1;
    final isSelected = _selectedRowIndices.contains(originalRowIndex);
    final isEvenRow = originalRowIndex % 2 == 0;
    final baseColor = isEvenRow ? CsvTheme.tableRowEven : CsvTheme.tableRowOdd;
    final isDragging = _draggingRowIndex == originalRowIndex;

    return DragTarget<int>(
      onWillAccept: (draggedIndex) => draggedIndex != null,
      onAccept: (draggedIndex) {
        if (draggedIndex != originalRowIndex) {
          _reorderRow(draggedIndex, originalRowIndex);
        }
      },
      builder: (context, candidateData, rejectedData) {
        final isHovering = candidateData.isNotEmpty;

        return Draggable<int>(
          data: originalRowIndex,
          feedback: Material(
            elevation: 4,
            child: Container(
              width: MediaQuery.of(context).size.width * 0.8,
              height: 32,
              decoration: BoxDecoration(
                color: CsvTheme.primaryColor.withOpacity(0.9),
                border: Border.all(color: CsvTheme.primaryColor, width: 2),
              ),
              child: Row(
                children: [
                  Container(
                    width: 60,
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                    child: Text(
                      lineNumber.toString(),
                      style: CsvTheme.bodySmall.copyWith(
                        color: Colors.white,
                        fontWeight: FontWeight.w600,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ),
                  Expanded(
                    child: Text(
                      row.take(3).join(' | '),
                      style: CsvTheme.bodySmall.copyWith(
                        color: Colors.white,
                        fontWeight: FontWeight.w500,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ),
          ),
          childWhenDragging: Opacity(
            opacity: 0.3,
            child: _buildRowContent(
              lineNumber,
              row,
              filteredIndex,
              originalRowIndex,
              isSelected,
              baseColor,
              false,
            ),
          ),
          onDragStarted: () {
            setState(() {
              _draggingRowIndex = originalRowIndex;
            });
          },
          onDragEnd: (details) {
            setState(() {
              _draggingRowIndex = null;
            });
          },
          child: Container(
            decoration: BoxDecoration(
              border: Border(
                bottom:
                    const BorderSide(color: CsvTheme.tableCellBorder, width: 1),
                top: isHovering
                    ? const BorderSide(color: CsvTheme.primaryColor, width: 2)
                    : BorderSide.none,
              ),
              color: isHovering
                  ? CsvTheme.primaryLight.withOpacity(0.3)
                  : isDragging
                      ? CsvTheme.primaryLight.withOpacity(0.5)
                      : null,
            ),
            child: _buildRowContent(
              lineNumber,
              row,
              filteredIndex,
              originalRowIndex,
              isSelected,
              baseColor,
              isHovering,
            ),
          ),
        );
      },
    );
  }

  Widget _buildRowContent(
    int lineNumber,
    List<String> row,
    int filteredIndex,
    int originalRowIndex,
    bool isSelected,
    Color baseColor,
    bool isHovering,
  ) {
    return Material(
      color: isSelected ? CsvTheme.tableRowSelected : baseColor,
      child: InkWell(
        onHover: (hovering) {
          // Add subtle hover effect
        },
        child: Container(
          constraints: BoxConstraints(
            minHeight: _compactMode ? 32 : 32,
            maxHeight: _compactMode ? 32 : double.infinity,
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              if (_showCheckboxes)
                GestureDetector(
                  onSecondaryTapDown: (details) {
                    _showRowContextMenu(details, originalRowIndex);
                  },
                  child: SizedBox(
                    width: 48,
                    child: Center(
                      child: Checkbox(
                        value: isSelected,
                        onChanged: (value) {
                          _toggleRowSelection(originalRowIndex);
                        },
                      ),
                    ),
                  ),
                ),
              _buildLineNumberCell(lineNumber),
              ...List.generate(_headers.length, (colIndex) {
                final cell = colIndex < row.length ? row[colIndex] : '';
                return _buildDataCell(
                  cell,
                  filteredIndex,
                  colIndex,
                  originalRowIndex,
                );
              }),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildLineNumberCell(int lineNumber) {
    final width =
        _columnWidths.isNotEmpty ? _columnWidths[0] : _lineNumberColumnWidth;
    final originalRowIndex = lineNumber - 1;

    return GestureDetector(
      onSecondaryTapDown: (details) {
        _showRowContextMenu(details, originalRowIndex);
      },
      child: Container(
        width: width,
        padding: const EdgeInsets.symmetric(
          horizontal: CsvTheme.spacingMd,
          vertical: CsvTheme.spacingSm,
        ),
        decoration: const BoxDecoration(
          border: Border(
            right: BorderSide(color: CsvTheme.tableCellBorder, width: 1),
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.drag_indicator,
              size: 16,
              color: CsvTheme.textTertiary,
            ),
            const SizedBox(width: 4),
            Text(
              lineNumber.toString(),
              style: CsvTheme.bodyExtraSmall.copyWith(
                color: CsvTheme.textTertiary,
                fontWeight: FontWeight.w500,
                fontFeatures: const [FontFeature.tabularFigures()],
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showRowContextMenu(TapDownDetails details, int rowIndex) {
    showMenu<String>(
      context: context,
      position: RelativeRect.fromLTRB(
        details.globalPosition.dx,
        details.globalPosition.dy,
        details.globalPosition.dx,
        details.globalPosition.dy,
      ),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(CsvTheme.radiusLg),
      ),
      items: <PopupMenuEntry<String>>[
        _buildContextMenuItem(
            Icons.arrow_upward, 'Insert Row Before', 'insert_before'),
        _buildContextMenuItem(
            Icons.arrow_downward, 'Insert Row After', 'insert_after'),
        _buildContextMenuItem(Icons.content_copy, 'Duplicate Row', 'duplicate'),
        const PopupMenuDivider(height: 1),
        _buildContextMenuItem(Icons.delete_outline, 'Delete Row', 'delete'),
      ],
    ).then((value) {
      if (value == 'insert_before') {
        insertRowBefore(rowIndex);
      } else if (value == 'insert_after') {
        insertRowAfter(rowIndex);
      } else if (value == 'duplicate') {
        _duplicateRow(rowIndex);
      } else if (value == 'delete') {
        setState(() {
          _selectedRowIndices.clear();
          _selectedRowIndices.add(rowIndex);
        });
        _deleteSelectedRows();
      }
    });
  }

  void _duplicateRow(int rowIndex) {
    if (rowIndex < 0 || rowIndex >= _allCsvData.length) return;

    // Create a copy of the row
    final duplicatedRow = List<String>.from(_allCsvData[rowIndex]);

    // Insert the duplicated row right after the original
    final action = AddRowAction(
      _allCsvData,
      rowIndex + 1,
      duplicatedRow,
    );

    setState(() {
      action.redo();
      _addAction(action);
      _totalRows = _allCsvData.length;
      _filteredData = List.from(_allCsvData);
      _rebuildFilteredIndexMapping();
      _listKey = UniqueKey();
      _hasUnsavedChanges = true;
    });

    _showSnackBar(
      'Row #${rowIndex + 1} duplicated',
      type: SnackBarType.success,
    );
  }

  Widget _buildDataCell(
      String content, int rowIndex, int colIndex, int originalRowIndex) {
    final columnIndex = colIndex + 1;
    final width = _columnWidths.isNotEmpty && columnIndex < _columnWidths.length
        ? _columnWidths[columnIndex]
        : 150.0;
    final cellKey = '$originalRowIndex:$colIndex';
    final isCellSelected = _selectedCells.contains(cellKey);

    return GestureDetector(
      onTap: () {
        if (HardwareKeyboard.instance.isMetaPressed ||
            HardwareKeyboard.instance.isControlPressed) {
          _toggleCellSelection(originalRowIndex, colIndex);
        }
      },
      onDoubleTap: () {
        _startEditing(rowIndex, colIndex, content);
      },
      child: Container(
        width: width,
        constraints: _compactMode
            ? const BoxConstraints(maxHeight: 32)
            : null, // Collapsed height in compact mode
        padding: const EdgeInsets.symmetric(
          horizontal: CsvTheme.spacingSm,
          vertical: 4, // Reduced vertical padding for compact rows
        ),
        decoration: BoxDecoration(
          color: isCellSelected ? CsvTheme.primaryLight : null,
          border: Border(
            right: const BorderSide(color: CsvTheme.tableCellBorder, width: 1),
            left: isCellSelected
                ? const BorderSide(color: CsvTheme.primaryColor, width: 2)
                : BorderSide.none,
            top: isCellSelected
                ? const BorderSide(color: CsvTheme.primaryColor, width: 2)
                : BorderSide.none,
            bottom: isCellSelected
                ? const BorderSide(color: CsvTheme.primaryColor, width: 2)
                : BorderSide.none,
          ),
        ),
        child: Align(
          alignment: Alignment.centerLeft,
          child: _compactMode
              ? Text(
                  content,
                  style: CsvTheme.bodyExtraSmall.copyWith(
                    color: CsvTheme.textPrimary,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                )
              : HighlightedText(
                  text: content,
                  searchQuery: _searchQuery,
                  caseSensitive: _caseSensitive,
                  useRegex: _useRegex,
                ),
        ),
      ),
    );
  }

  Widget _buildDragOverlay() {
    return Container(
      color: CsvTheme.primaryColor.withOpacity(0.05),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 2, sigmaY: 2),
        child: Center(
          child: Container(
            padding: const EdgeInsets.all(CsvTheme.spacing2xl * 2),
            decoration: BoxDecoration(
              color: CsvTheme.surfaceColor,
              borderRadius: BorderRadius.circular(CsvTheme.radiusXl),
              border: Border.all(
                color: CsvTheme.primaryColor,
                width: 2,
              ),
              boxShadow: const [CsvTheme.shadowLg],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  padding: const EdgeInsets.all(CsvTheme.spacingXl),
                  decoration: BoxDecoration(
                    color: CsvTheme.primaryLight,
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    Icons.upload_file,
                    size: 64,
                    color: CsvTheme.primaryColor,
                  ),
                ),
                const SizedBox(height: CsvTheme.spacingXl),
                Text(
                  'Drop CSV file here',
                  style: CsvTheme.headingLarge.copyWith(
                    color: CsvTheme.primaryColor,
                  ),
                ),
                const SizedBox(height: CsvTheme.spacingSm),
                Text(
                  'Release to load the file',
                  style: CsvTheme.bodyLarge.copyWith(
                    color: CsvTheme.textSecondary,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ============================================================================
// Helper classes for background CSV parsing with Isolate
// ============================================================================

/// Parameters for CSV parsing in isolate
class _CsvParseParams {
  final String filePath;
  final Encoding encoding;
  final SendPort sendPort;

  _CsvParseParams({
    required this.filePath,
    required this.encoding,
    required this.sendPort,
  });
}

/// Headers message
class CsvParseHeaders {
  final List<String> headers;
  CsvParseHeaders(this.headers);
}

/// Progress update message
class CsvParseProgress {
  final int rowsLoaded;
  CsvParseProgress(this.rowsLoaded);
}

/// Data chunk message
class CsvParseChunk {
  final List<List<String>> chunk;
  final int startIndex;
  CsvParseChunk(this.chunk, this.startIndex);
}

/// Completion message
class CsvParseComplete {
  final int totalRows;
  CsvParseComplete(this.totalRows);
}

/// Error message
class CsvParseError {
  final String error;
  final bool isEncodingError;

  CsvParseError(this.error, this.isEncodingError);
}

/// Loading progress dialog
class _LoadingProgressDialog extends StatefulWidget {
  final Stream<int> progressStream;
  final String fileName;

  const _LoadingProgressDialog({
    required this.progressStream,
    required this.fileName,
  });

  @override
  State<_LoadingProgressDialog> createState() => _LoadingProgressDialogState();
}

class _LoadingProgressDialogState extends State<_LoadingProgressDialog> {
  int _rowsLoaded = 0;
  StreamSubscription<int>? _subscription;

  @override
  void initState() {
    super.initState();
    _subscription = widget.progressStream.listen((rowsLoaded) {
      if (mounted) {
        setState(() {
          _rowsLoaded = rowsLoaded;
        });
      }
    });
  }

  @override
  void dispose() {
    _subscription?.cancel();
    super.dispose();
  }

  String _formatNumber(int number) {
    return number.toString().replaceAllMapped(
          RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'),
          (Match m) => '${m[1]},',
        );
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(
              width: 40,
              height: 40,
              child: CircularProgressIndicator(strokeWidth: 3),
            ),
            const SizedBox(height: 20),
            Text(
              'Loading CSV File',
              style: CsvTheme.headingSmall.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              widget.fileName,
              style: CsvTheme.bodyMedium.copyWith(
                color: CsvTheme.textSecondary,
              ),
              textAlign: TextAlign.center,
            ),
            if (_rowsLoaded > 0) ...[
              const SizedBox(height: 16),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: CsvTheme.primaryLight,
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.table_rows,
                        color: CsvTheme.primaryColor, size: 18),
                    const SizedBox(width: 8),
                    Text(
                      '${_formatNumber(_rowsLoaded)} rows loaded...',
                      style: CsvTheme.labelMedium.copyWith(
                        color: CsvTheme.primaryColor,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            ],
            const SizedBox(height: 16),
            Text(
              'Processing in background thread...',
              style: CsvTheme.bodySmall.copyWith(
                color: CsvTheme.textTertiary,
                fontStyle: FontStyle.italic,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Animated loading dialog with continuous animation
class _AnimatedLoadingDialog extends StatefulWidget {
  final String fileName;

  const _AnimatedLoadingDialog({required this.fileName});

  @override
  State<_AnimatedLoadingDialog> createState() => _AnimatedLoadingDialogState();
}

class _AnimatedLoadingDialogState extends State<_AnimatedLoadingDialog>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scaleAnimation;
  int _dotCount = 0;
  Timer? _dotTimer;

  final List<String> _loadingMessages = [
    'Reading file',
    'Parsing CSV data',
    'Processing rows',
    'Almost there',
  ];
  int _messageIndex = 0;
  Timer? _messageTimer;

  @override
  void initState() {
    super.initState();

    // Pulse animation for the icon
    _controller = AnimationController(
      duration: const Duration(milliseconds: 1200),
      vsync: this,
    )..repeat(reverse: true);

    _scaleAnimation = Tween<double>(begin: 0.95, end: 1.05).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
    );

    // Animated dots
    _dotTimer = Timer.periodic(const Duration(milliseconds: 500), (timer) {
      if (mounted) {
        setState(() {
          _dotCount = (_dotCount + 1) % 4;
        });
      }
    });

    // Rotate messages
    _messageTimer = Timer.periodic(const Duration(seconds: 2), (timer) {
      if (mounted) {
        setState(() {
          _messageIndex = (_messageIndex + 1) % _loadingMessages.length;
        });
      }
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    _dotTimer?.cancel();
    _messageTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      elevation: 8,
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Animated icon
            ScaleTransition(
              scale: _scaleAnimation,
              child: Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: CsvTheme.primaryLight,
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.analytics_outlined,
                  size: 48,
                  color: CsvTheme.primaryColor,
                ),
              ),
            ),
            const SizedBox(height: 24),

            // Spinning progress indicator
            const SizedBox(
              width: 32,
              height: 32,
              child: CircularProgressIndicator(
                strokeWidth: 3,
                valueColor:
                    AlwaysStoppedAnimation<Color>(CsvTheme.primaryColor),
              ),
            ),
            const SizedBox(height: 20),

            // Title
            Text(
              'Loading Large CSV File',
              style: CsvTheme.headingSmall.copyWith(
                fontWeight: FontWeight.bold,
                color: CsvTheme.textPrimary,
              ),
            ),
            const SizedBox(height: 8),

            // Filename
            Text(
              widget.fileName,
              style: CsvTheme.bodyMedium.copyWith(
                color: CsvTheme.textSecondary,
                fontWeight: FontWeight.w500,
              ),
              textAlign: TextAlign.center,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 20),

            // Animated loading message with dots
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              decoration: BoxDecoration(
                color: CsvTheme.primaryLight.withOpacity(0.3),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                '${_loadingMessages[_messageIndex]}${"." * _dotCount}',
                style: CsvTheme.bodySmall.copyWith(
                  color: CsvTheme.primaryColor,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 0.3,
                ),
                textAlign: TextAlign.center,
              ),
            ),
            const SizedBox(height: 16),

            // Helpful tip
            Text(
              '💡 Tip: Click "Ignore" if macOS shows a warning',
              style: CsvTheme.bodyExtraSmall.copyWith(
                color: CsvTheme.textTertiary,
                fontStyle: FontStyle.italic,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}

enum SnackBarType { success, error, warning, info }
