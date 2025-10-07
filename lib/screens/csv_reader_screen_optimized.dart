import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:file_picker/file_picker.dart';
import 'dart:io';
import 'dart:convert';
import 'dart:async';
import 'package:desktop_drop/desktop_drop.dart';
import 'dart:ui';

import '../services/csv_database_service.dart';
import '../services/csv_history_service.dart';
import '../services/csv_streaming_service.dart';
import '../services/window_manager_service.dart';
import '../widgets/virtual_csv_table.dart';
import '../widgets/csv_toolbar.dart';
import '../widgets/csv_status_bar.dart';
import '../widgets/csv_search_bar.dart';
import '../widgets/csv_dialogs.dart';
import '../widgets/csv_history_board.dart';
import '../theme/csv_theme.dart';

/// Optimized CSV Reader for large files (320k+ rows)
/// Uses database backend and virtual scrolling for maximum performance
class CsvReaderScreenOptimized extends StatefulWidget {
  const CsvReaderScreenOptimized({super.key});

  @override
  State<CsvReaderScreenOptimized> createState() =>
      _CsvReaderScreenOptimizedState();
}

class _CsvReaderScreenOptimizedState extends State<CsvReaderScreenOptimized> {
  // Core data
  String? _sessionId;
  List<String> _headers = [];
  int _totalRows = 0;
  String? _fileName;
  File? _currentFile;

  // Loading state
  bool _isLoading = false;
  double _loadingProgress = 0.0;
  int _loadedRows = 0;

  // UI state
  bool _isDragging = false;
  bool _showCheckboxes = false;
  bool _compactMode = false;
  bool _hasUnsavedChanges = false;
  final FocusNode _keyboardFocusNode = FocusNode();
  final CsvHistoryService _historyService = CsvHistoryService();
  bool _showHistoryBoard = false;
  Future<void> _snapshotChain = Future.value();
  int _historyCursor = -1;

  // Selection state
  final Set<int> _selectedRowIndices = {};
  final Set<String> _selectedCells = {};

  // Search state
  bool _showAdvancedSearch = false;
  String _searchQuery = '';
  bool _caseSensitive = false;
  bool _useRegex = false;
  List<int> _searchResults = [];
  final Set<int> _selectedSearchColumns = {};
  Timer? _searchDebounceTimer;
  int? _rowRangeStart;
  int? _rowRangeEnd;

  // Remember last directory
  String? _lastDirectoryPath;

  // Key for forcing table rebuild
  Key _tableKey = UniqueKey();

  @override
  void initState() {
    super.initState();
    _initializeDatabase();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _keyboardFocusNode.requestFocus();
    });
  }

  Future<void> _ensureHistoryInitialized() async {
    await _historyService.initialize();
  }

  Future<void> _initializeDatabase() async {
    await CsvDatabaseService.initialize();
  }

  @override
  void dispose() {
    _searchDebounceTimer?.cancel();
    _keyboardFocusNode.dispose();
    super.dispose();
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

        _lastDirectoryPath = file.parent.path;

        setState(() {
          _isLoading = true;
          _loadingProgress = 0.0;
          _loadedRows = 0;
          _fileName = result.files.single.name;
          _selectedRowIndices.clear();
          _selectedCells.clear();
        });

        _currentFile = file;
        await _loadCsvFile(file);
      }
    } catch (e) {
      if (mounted) {
        _showSnackBar('Error loading file: $e', type: SnackBarType.error);
      }
    }
  }

  Future<void> _loadCsvFile(File file, {Encoding? encoding}) async {
    try {
      final result = await CsvStreamingService.loadCsvFile(
        file,
        encoding: encoding,
        onProgress: (progress, rowsLoaded) {
          if (mounted) {
            setState(() {
              _loadingProgress = progress;
              _loadedRows = rowsLoaded;
            });
          }
        },
      );

      if (mounted) {
        setState(() {
          _sessionId = result.sessionId;
          _headers = result.headers;
          _totalRows = result.totalRows;
          _fileName = result.fileName;
          _isLoading = false;
          _hasUnsavedChanges = false;
        });

        _showSnackBar(
          'Loaded ${_formatNumber(_totalRows)} rows successfully!',
          type: SnackBarType.success,
        );

        if (_fileName != null) {
          unawaited(() async {
            await _ensureHistoryInitialized();
            await _historyService.startNewSession(_fileName!);
            if (mounted) {
              setState(() {
                _historyCursor = -1;
              });
            } else {
              _historyCursor = -1;
            }
            await _createHistorySnapshot(
              'Loaded file: $_fileName',
              actionType: 'initial',
            );
          }());
        }
      }
    } catch (e) {
      if (e.toString().contains('decode') && encoding == null) {
        if (mounted) {
          final encodingName = await _showEncodingDialog();
          if (encodingName == null) {
            setState(() => _isLoading = false);
            return;
          }
          final selectedEncoding =
              CsvStreamingService.getEncodingFromString(encodingName);
          await _loadCsvFile(file, encoding: selectedEncoding);
        }
      } else {
        if (mounted) {
          setState(() => _isLoading = false);
          _showSnackBar('Error loading CSV: $e', type: SnackBarType.error);
        }
      }
    }
  }

  Future<String?> _showEncodingDialog() async {
    return showDialog<String>(
      context: context,
      builder: (context) => const EncodingSelectionDialog(),
    );
  }

  Future<void> _reloadWithDifferentEncoding() async {
    if (_currentFile == null) return;

    final encodingName = await _showEncodingDialog();
    if (encodingName == null) return;

    setState(() {
      _isLoading = true;
      _loadingProgress = 0.0;
      _loadedRows = 0;
    });

    final selectedEncoding =
        CsvStreamingService.getEncodingFromString(encodingName);
    await _loadCsvFile(_currentFile!, encoding: selectedEncoding);
  }

  Future<void> _saveToFile() async {
    if (!_hasUnsavedChanges || _currentFile == null || _sessionId == null) {
      return;
    }

    try {
      setState(() => _isLoading = true);

      await CsvStreamingService.exportToFile(
        _sessionId!,
        _currentFile!,
        _headers,
        onProgress: (progress) {
          if (mounted) {
            setState(() => _loadingProgress = progress);
          }
        },
      );

      setState(() {
        _hasUnsavedChanges = false;
        _isLoading = false;
      });

      _showSnackBar('Changes saved successfully!', type: SnackBarType.success);
    } catch (e) {
      setState(() => _isLoading = false);
      _showSnackBar('Error saving file: $e', type: SnackBarType.error);
    }
  }

  void _handleCellEdit(int rowIndex, int colIndex, String currentValue) {
    showDialog(
      context: context,
      builder: (context) => EditCellDialog(
        initialValue: currentValue,
        columnName: _headers.isNotEmpty && colIndex < _headers.length
            ? _headers[colIndex]
            : 'Column ${colIndex + 1}',
        onSave: (newValue) async {
          if (_sessionId == null) return;

          // Get current row
          final row = await CsvDatabaseService.getRow(_sessionId!, rowIndex);
          if (row == null) return;

          // Update cell
          row[colIndex] = newValue;

          // Save to database
          await CsvDatabaseService.updateRow(_sessionId!, rowIndex, row);

          _scheduleHistorySnapshot(
            'Edited cell (${rowIndex + 1}, ${colIndex + 1})',
            actionType: 'edit',
          );

          setState(() {
            _hasUnsavedChanges = true;
            _tableKey = UniqueKey(); // Force table refresh
          });

          _showSnackBar('Cell updated', type: SnackBarType.success);
        },
      ),
    );
  }

  void _handleColumnRename(int columnIndex, String currentName) {
    showDialog(
      context: context,
      builder: (context) => RenameColumnDialog(
        currentName: currentName,
        onSave: (newName) {
          setState(() {
            _headers[columnIndex] = newName;
            _hasUnsavedChanges = true;
          });
          _scheduleHistorySnapshot(
            'Renamed column to $newName',
            actionType: 'column-rename',
          );
          _showSnackBar('Column renamed', type: SnackBarType.success);
        },
      ),
    );
  }

  void _handleColumnDelete(int columnIndex) {
    unawaited(_deleteColumn(columnIndex));
  }

  void _handleAddColumn() async {
    if (_sessionId == null) return;

    try {
      setState(() => _isLoading = true);

      final newColumnName = 'Column ${_headers.length + 1}';
      final totalRows = await CsvDatabaseService.getRowCount(_sessionId!);
      final chunkSize = 1000;

      for (int offset = 0; offset < totalRows; offset += chunkSize) {
        final rows = await CsvDatabaseService.getRows(
          _sessionId!,
          offset: offset,
          limit: chunkSize,
        );

        for (int i = 0; i < rows.length; i++) {
          final row = rows[i];
          row.add('');
          await CsvDatabaseService.updateRow(_sessionId!, offset + i, row);
        }

        setState(() {
          _loadingProgress = (offset + rows.length) / totalRows;
        });
      }

      setState(() {
        _headers.add(newColumnName);
        _hasUnsavedChanges = true;
        _isLoading = false;
        _tableKey = UniqueKey(); // Force table refresh
      });

      _showSnackBar('Column added', type: SnackBarType.success);
    } catch (e) {
      setState(() => _isLoading = false);
      _showSnackBar('Error adding column: $e', type: SnackBarType.error);
    }
  }

  void _handleMergeRows() {
    if (_selectedRowIndices.length < 2) {
      _showSnackBar(
        'Please select at least 2 rows to merge',
        type: SnackBarType.info,
      );
      return;
    }

    if (_sessionId == null) return;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => MergeRowsDialog(
        selectedCount: _selectedRowIndices.length,
        onMerge: (separator, keepFirst) {
          final normalized =
              _normalizeDelimiter(separator, defaultValue: ', ');
          unawaited(_performMergeRows(normalized, keepFirst));
        },
      ),
    );
  }

  Future<void> _performMergeRows(String separator, bool keepFirst) async {
    if (_sessionId == null) return;

    setState(() => _isLoading = true);

    try {
      final sortedIndices = _selectedRowIndices.toList()..sort();
      final targetIndex = keepFirst ? sortedIndices.first : sortedIndices.last;

      final rowsToMerge = <List<String>>[];
      for (final index in sortedIndices) {
        final row = await CsvDatabaseService.getRow(_sessionId!, index);
        if (row != null) {
          while (row.length < _headers.length) {
            row.add('');
          }
          rowsToMerge.add(row);
        }
      }

      if (rowsToMerge.isEmpty) {
        setState(() => _isLoading = false);
        return;
      }

      final effectiveSeparator = _materializeDelimiter(separator);
      final mergedRow = List<String>.filled(_headers.length, '');
      for (int col = 0; col < _headers.length; col++) {
        final cellValues = <String>[];
        for (final row in rowsToMerge) {
          if (col < row.length) {
            final value = row[col].trim();
            if (value.isNotEmpty) {
              cellValues.add(value);
            }
          }
        }
        mergedRow[col] = cellValues.join(effectiveSeparator);
      }

      await CsvDatabaseService.updateRow(_sessionId!, targetIndex, mergedRow);

      final rowsToDelete = sortedIndices.where((i) => i != targetIndex).toList();
      if (rowsToDelete.isNotEmpty) {
        await CsvDatabaseService.deleteRows(_sessionId!, rowsToDelete);
      }

      await _createHistorySnapshot(
        'Merged ${sortedIndices.length} rows',
        actionType: 'merge',
      );

      setState(() {
        _totalRows -= rowsToDelete.length;
        _hasUnsavedChanges = true;
        _isLoading = false;
        _selectedRowIndices.clear();
        _selectedCells.clear();
        _tableKey = UniqueKey();
      });

      await _refreshFilteredView();

      _showSnackBar(
        'Merged ${sortedIndices.length} row${sortedIndices.length == 1 ? '' : 's'}',
        type: SnackBarType.success,
      );
    } catch (e) {
      setState(() => _isLoading = false);
      _showSnackBar('Error merging rows: $e', type: SnackBarType.error);
    }
  }

  void _handleSplitCells() {
    if (_selectedCells.isEmpty) {
      _showSnackBar(
        'Please select cells to split',
        type: SnackBarType.info,
      );
      return;
    }

    if (_sessionId == null) return;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => SplitDialog(
        mode: 'cells',
        selectionCount: _selectedCells.length,
        onSplit: (delimiter) {
          final normalized = _normalizeDelimiter(delimiter);
          unawaited(_performCellSplit(normalized));
        },
      ),
    );
  }

  Future<void> _performCellSplit(String delimiter) async {
    if (_sessionId == null) return;

    setState(() => _isLoading = true);

    try {
      final effectiveDelimiter = _materializeDelimiter(delimiter);
      final cellsByRow = <int, List<int>>{};
      for (final cellKey in _selectedCells) {
        final parts = cellKey.split(':');
        if (parts.length != 2) continue;
        final rowIndex = int.parse(parts[0]);
        final colIndex = int.parse(parts[1]);
        cellsByRow.putIfAbsent(rowIndex, () => []).add(colIndex);
      }

      if (cellsByRow.isEmpty) {
        setState(() => _isLoading = false);
        return;
      }

      final sortedRows = cellsByRow.keys.toList()..sort();
      int rowsAdded = 0;

      for (final originalRowIndex in sortedRows) {
        final currentIndex = originalRowIndex + rowsAdded;
        final row = await CsvDatabaseService.getRow(_sessionId!, currentIndex);
        if (row == null) {
          continue;
        }

        while (row.length < _headers.length) {
          row.add('');
        }

        final columns = List<int>.from(cellsByRow[originalRowIndex]!)..sort();
        int maxSplits = 1;
        for (final col in columns) {
          if (col < row.length) {
            final splits = row[col].split(effectiveDelimiter).length;
            if (splits > maxSplits) maxSplits = splits;
          }
        }

        final newRows = <List<String>>[];
        for (int splitIdx = 0; splitIdx < maxSplits; splitIdx++) {
          final newRow = List<String>.from(row);
          for (final col in columns) {
            if (col >= newRow.length) continue;
            final splits = row[col].split(effectiveDelimiter);
            if (splits.length == 1) {
              newRow[col] = splits[0].trim();
            } else {
              newRow[col] =
                  splitIdx < splits.length ? splits[splitIdx].trim() : '';
            }
          }
          newRows.add(newRow);
        }

        await CsvDatabaseService.updateRow(_sessionId!, currentIndex, newRows[0]);
        for (int i = 1; i < newRows.length; i++) {
          await CsvDatabaseService.insertRow(
            _sessionId!,
            currentIndex + i,
            newRows[i],
          );
        }

        rowsAdded += newRows.length - 1;
      }

      await _createHistorySnapshot(
        'Split ${_selectedCells.length} cell(s)',
        actionType: 'split',
      );

      setState(() {
        _totalRows += rowsAdded;
        _hasUnsavedChanges = true;
        _isLoading = false;
        _selectedCells.clear();
        _selectedRowIndices.clear();
        _tableKey = UniqueKey();
      });

      await _refreshFilteredView();

      _showSnackBar('Cells split successfully', type: SnackBarType.success);
    } catch (e) {
      setState(() => _isLoading = false);
      _showSnackBar('Error splitting cells: $e', type: SnackBarType.error);
    }
  }

  void _handleSplitRows() {
    if (_selectedRowIndices.isEmpty) {
      _showSnackBar(
        'Please select rows to split',
        type: SnackBarType.info,
      );
      return;
    }

    if (_sessionId == null) return;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => SplitDialog(
        mode: 'rows',
        selectionCount: _selectedRowIndices.length,
        onSplit: (delimiter) {
          final normalized = _normalizeDelimiter(delimiter);
          unawaited(_performRowSplit(normalized));
        },
      ),
    );
  }

  Future<void> _performRowSplit(String delimiter) async {
    if (_sessionId == null) return;

    setState(() => _isLoading = true);

    try {
      final effectiveDelimiter = _materializeDelimiter(delimiter);
      final sortedIndices = _selectedRowIndices.toList()..sort();
      int rowsAdded = 0;

      for (final originalRowIndex in sortedIndices) {
        final currentIndex = originalRowIndex + rowsAdded;
        final row = await CsvDatabaseService.getRow(_sessionId!, currentIndex);
        if (row == null) {
          continue;
        }

        while (row.length < _headers.length) {
          row.add('');
        }

        int maxSplits = 1;
        for (final cell in row) {
          final splits = cell.split(effectiveDelimiter).length;
          if (splits > maxSplits) maxSplits = splits;
        }

        final newRows = <List<String>>[];
        for (int splitIdx = 0; splitIdx < maxSplits; splitIdx++) {
          final newRow = <String>[];
          for (final cell in row) {
            final splits = cell.split(effectiveDelimiter);
            if (splits.length == 1) {
              newRow.add(splits[0].trim());
            } else {
              newRow.add(
                  splitIdx < splits.length ? splits[splitIdx].trim() : '');
            }
          }
          while (newRow.length < _headers.length) {
            newRow.add('');
          }
          newRows.add(newRow);
        }

        await CsvDatabaseService.updateRow(_sessionId!, currentIndex, newRows[0]);
        for (int i = 1; i < newRows.length; i++) {
          await CsvDatabaseService.insertRow(
            _sessionId!,
            currentIndex + i,
            newRows[i],
          );
        }

        rowsAdded += newRows.length - 1;
      }

      await _createHistorySnapshot(
        'Split ${sortedIndices.length} row(s)',
        actionType: 'split',
      );

      setState(() {
        _totalRows += rowsAdded;
        _hasUnsavedChanges = true;
        _isLoading = false;
        _selectedRowIndices.clear();
        _selectedCells.clear();
        _tableKey = UniqueKey();
      });

      await _refreshFilteredView();

      _showSnackBar('Rows split successfully', type: SnackBarType.success);
    } catch (e) {
      setState(() => _isLoading = false);
      _showSnackBar('Error splitting rows: $e', type: SnackBarType.error);
    }
  }

  Future<void> _restoreFromHistory(String snapshotId,
      {bool trackHistory = true}) async {
    if (_sessionId == null) return;

    setState(() => _isLoading = true);

    try {
      if (trackHistory) {
        await _createHistorySnapshot(
          'Before restore to snapshot',
          actionType: 'restore-pre',
        );
      }

      final result = await _historyService.restoreFromSnapshot(snapshotId);

      final targetHeaders = List<String>.from(result.headers);
      final normalizedRows = result.data.map((row) {
        final copy = List<String>.from(row);
        if (copy.length < targetHeaders.length) {
          copy.addAll(List.filled(targetHeaders.length - copy.length, ''));
        } else if (copy.length > targetHeaders.length) {
          copy.removeRange(targetHeaders.length, copy.length);
        }
        return copy;
      }).toList();

      await CsvDatabaseService.replaceSessionData(
        _sessionId!,
        normalizedRows,
      );

      setState(() {
        _headers = targetHeaders;
        _totalRows = normalizedRows.length;
        _hasUnsavedChanges = true;
        _isLoading = false;
        if (trackHistory) {
          _showHistoryBoard = false;
        }
        _selectedCells.clear();
        _selectedRowIndices.clear();
        _tableKey = UniqueKey();
      });

      await _refreshFilteredView();

      if (trackHistory) {
        await _createHistorySnapshot(
          'Restored snapshot: ${result.entry.actionDescription}',
          actionType: 'restore',
        );
      }

      final entries = _historyService.getHistoryEntries();
      final restoredIndex = entries.indexWhere((e) => e.id == result.entry.id);
      if (restoredIndex != -1 && !trackHistory) {
        if (mounted) {
          setState(() {
            _historyCursor = restoredIndex;
          });
        } else {
          _historyCursor = restoredIndex;
        }
      }

      _showSnackBar(
        'Restored to snapshot from ${result.entry.formattedTimestamp}',
        type: SnackBarType.success,
      );
    } catch (e) {
      setState(() => _isLoading = false);
      _showSnackBar('Error restoring history: $e', type: SnackBarType.error);
    }
  }

  String _normalizeDelimiter(String input, {String defaultValue = ','}) {
    return input.isEmpty ? defaultValue : input;
  }

  String _materializeDelimiter(String value) {
    final escaped = value.replaceAll('\\', r'\\').replaceAll('"', r'\"');
    try {
      return jsonDecode('"$escaped"') as String;
    } catch (_) {
      return value;
    }
  }

  Future<void> _createHistorySnapshot(String description,
      {String? actionType}) {
    if (_sessionId == null || _headers.isEmpty) {
      return _snapshotChain;
    }

    _snapshotChain = _snapshotChain.then((_) async {
      try {
        await _ensureHistoryInitialized();

        final initialLength =
            _historyService.getHistoryEntries().length;
        if (_historyCursor < initialLength - 1) {
          await _historyService.truncateAfter(_historyCursor);
        }

        final entriesPostTruncate = _historyService.getHistoryEntries();
        if (entriesPostTruncate.isEmpty) {
          _historyCursor = -1;
        } else if (_historyCursor >= entriesPostTruncate.length) {
          _historyCursor = entriesPostTruncate.length - 1;
        }

        final headersCopy = List<String>.from(_headers);
        final allRows = <List<String>>[];

        await for (final chunk
            in CsvDatabaseService.getAllRowsStream(_sessionId!)) {
          for (final row in chunk) {
            final normalized = List<String>.from(row);
            if (normalized.length < headersCopy.length) {
              normalized.addAll(List.filled(
                  headersCopy.length - normalized.length, ''));
            } else if (normalized.length > headersCopy.length) {
              normalized.removeRange(
                  headersCopy.length, normalized.length);
            }
            allRows.add(normalized);
          }
        }

        final entry = await _historyService.createSnapshot(
          headers: headersCopy,
          data: allRows,
          actionDescription: description,
          actionType: actionType,
        );

        final updatedEntries = _historyService.getHistoryEntries();
        var newCursor =
            updatedEntries.indexWhere((element) => element.id == entry.id);
        if (newCursor == -1) {
          newCursor = updatedEntries.length - 1;
        }

        if (mounted) {
          setState(() {
            _historyCursor = newCursor;
          });
        } else {
          _historyCursor = newCursor;
        }
      } catch (e) {
        debugPrint('Failed to create history snapshot: $e');
      }
    });

    return _snapshotChain;
  }

  void _scheduleHistorySnapshot(String description, {String? actionType}) {
    if (_sessionId == null) return;
    unawaited(
      _createHistorySnapshot(description, actionType: actionType),
    );
  }

  bool get _canUndo => _historyCursor > 0;
  bool get _canRedo {
    final entries = _historyService.getHistoryEntries();
    return _historyCursor >= 0 && _historyCursor < entries.length - 1;
  }

  Future<void> _handleUndo() async {
    if (!_canUndo) return;
    await _ensureHistoryInitialized();
    final entries = _historyService.getHistoryEntries();
    if (_historyCursor - 1 < 0 || _historyCursor - 1 >= entries.length) return;
    final targetEntry = entries[_historyCursor - 1];
    await _restoreFromHistory(targetEntry.id, trackHistory: false);
    final updatedEntries = _historyService.getHistoryEntries();
    var newIndex =
        updatedEntries.indexWhere((element) => element.id == targetEntry.id);
    if (newIndex == -1) {
      newIndex = (_historyCursor - 1).clamp(0, updatedEntries.length - 1);
    }
    if (mounted) {
      setState(() {
        _historyCursor = newIndex;
      });
    } else {
      _historyCursor = newIndex;
    }

    _showSnackBar(
      'Undid to "${targetEntry.actionDescription}"',
      type: SnackBarType.info,
    );
  }

  Future<void> _handleRedo() async {
    if (!_canRedo) return;
    await _ensureHistoryInitialized();
    final entries = _historyService.getHistoryEntries();
    if (_historyCursor + 1 < 0 || _historyCursor + 1 >= entries.length) return;
    final targetEntry = entries[_historyCursor + 1];
    await _restoreFromHistory(targetEntry.id, trackHistory: false);
    final updatedEntries = _historyService.getHistoryEntries();
    var newIndex =
        updatedEntries.indexWhere((element) => element.id == targetEntry.id);
    if (newIndex == -1) {
      newIndex = (_historyCursor + 1).clamp(0, updatedEntries.length - 1);
    }
    if (mounted) {
      setState(() {
        _historyCursor = newIndex;
      });
    } else {
      _historyCursor = newIndex;
    }

    _showSnackBar(
      'Redid to "${targetEntry.actionDescription}"',
      type: SnackBarType.info,
    );
  }

  Future<void> _refreshFilteredView() async {
    if (_sessionId == null) return;

    final hasFilters = _searchQuery.isNotEmpty ||
        _selectedSearchColumns.isNotEmpty ||
        _rowRangeStart != null ||
        _rowRangeEnd != null;

    if (!hasFilters) {
      setState(() => _searchResults.clear());
      return;
    }

    try {
      final results = await CsvDatabaseService.searchRowsAdvanced(
        _sessionId!,
        _searchQuery,
        caseSensitive: _caseSensitive,
        selectedColumns: _selectedSearchColumns.isNotEmpty
            ? _selectedSearchColumns.toList()
            : null,
        rowRangeStart: _rowRangeStart,
        rowRangeEnd: _rowRangeEnd,
        limit: 10000,
      );

      if (mounted) {
        setState(() {
          _searchResults = results.map((r) => r.rowIndex).toList();
        });
      }
    } catch (e) {
      if (mounted) {
        _showSnackBar('Error refreshing results: $e',
            type: SnackBarType.error);
      }
    }
  }

  Future<void> _handleSearch(String query) async {
    // Cancel previous timer
    _searchDebounceTimer?.cancel();

    // Update UI immediately for responsive feel
    setState(() {
      _searchQuery = query;
    });

    // Clear results immediately if query is empty and no advanced filters
    if (_sessionId == null ||
        (query.isEmpty &&
            _selectedSearchColumns.isEmpty &&
            _rowRangeStart == null &&
            _rowRangeEnd == null)) {
      setState(() {
        _searchResults.clear();
      });
      return;
    }

    // Debounce the actual search by 200ms
    _searchDebounceTimer = Timer(const Duration(milliseconds: 200), () async {
      try {
        final results = await CsvDatabaseService.searchRowsAdvanced(
          _sessionId!,
          query,
          caseSensitive: _caseSensitive,
          selectedColumns: _selectedSearchColumns.isNotEmpty
              ? _selectedSearchColumns.toList()
              : null,
          rowRangeStart: _rowRangeStart,
          rowRangeEnd: _rowRangeEnd,
          limit: 10000,
        );

        if (mounted) {
          setState(() {
            _searchResults = results.map((r) => r.rowIndex).toList();
          });

          _showSnackBar(
            'Found ${_searchResults.length} matching rows',
            type: SnackBarType.success,
          );
        }
      } catch (e) {
        if (mounted) {
          _showSnackBar('Error searching: $e', type: SnackBarType.error);
        }
      }
    });
  }

  void _handleDeleteEmptyRows() async {
    if (_sessionId == null) return;

    try {
      setState(() => _isLoading = true);

      final totalRows = await CsvDatabaseService.getRowCount(_sessionId!);
      final emptyIndices = <int>[];
      final chunkSize = 1000;

      for (int offset = 0; offset < totalRows; offset += chunkSize) {
        final rows = await CsvDatabaseService.getRows(
          _sessionId!,
          offset: offset,
          limit: chunkSize,
        );

        for (int i = 0; i < rows.length; i++) {
          final row = rows[i];
          if (row.every((cell) => cell.trim().isEmpty)) {
            emptyIndices.add(offset + i);
          }
        }
      }

      if (emptyIndices.isEmpty) {
        setState(() => _isLoading = false);
        _showSnackBar('No empty rows found', type: SnackBarType.info);
        return;
      }

      await CsvDatabaseService.deleteRows(_sessionId!, emptyIndices);

      _scheduleHistorySnapshot(
        'Deleted ${emptyIndices.length} empty row(s)',
        actionType: 'row-delete',
      );

      setState(() {
        _totalRows -= emptyIndices.length;
        _hasUnsavedChanges = true;
        _isLoading = false;
        _tableKey = UniqueKey(); // Force table refresh
      });

      await _refreshFilteredView();

      _showSnackBar(
        'Deleted ${emptyIndices.length} empty rows',
        type: SnackBarType.success,
      );
    } catch (e) {
      setState(() => _isLoading = false);
      _showSnackBar('Error deleting empty rows: $e', type: SnackBarType.error);
    }
  }

  void _handleRemoveDuplicates() async {
    if (_sessionId == null) return;

    try {
      setState(() => _isLoading = true);

      final totalRows = await CsvDatabaseService.getRowCount(_sessionId!);
      final seenRows = <String>{};
      final duplicateIndices = <int>[];
      final chunkSize = 1000;

      for (int offset = 0; offset < totalRows; offset += chunkSize) {
        final rows = await CsvDatabaseService.getRows(
          _sessionId!,
          offset: offset,
          limit: chunkSize,
        );

        for (int i = 0; i < rows.length; i++) {
          final rowSignature = rows[i].join('|');
          if (seenRows.contains(rowSignature)) {
            duplicateIndices.add(offset + i);
          } else {
            seenRows.add(rowSignature);
          }
        }
      }

      if (duplicateIndices.isEmpty) {
        setState(() => _isLoading = false);
        _showSnackBar('No duplicate rows found', type: SnackBarType.info);
        return;
      }

      await CsvDatabaseService.deleteRows(_sessionId!, duplicateIndices);

      _scheduleHistorySnapshot(
        'Removed ${duplicateIndices.length} duplicate row(s)',
        actionType: 'row-delete',
      );

      setState(() {
        _totalRows -= duplicateIndices.length;
        _hasUnsavedChanges = true;
        _isLoading = false;
        _tableKey = UniqueKey(); // Force table refresh
      });

      await _refreshFilteredView();

      _showSnackBar(
        'Deleted ${duplicateIndices.length} duplicate rows',
        type: SnackBarType.success,
      );
    } catch (e) {
      setState(() => _isLoading = false);
      _showSnackBar('Error removing duplicates: $e', type: SnackBarType.error);
    }
  }

  Future<void> _handleDeleteEmptyColumns() async {
    if (_sessionId == null || _headers.isEmpty) return;

    setState(() => _isLoading = true);

    try {
      final emptyColumnIndices = await CsvDatabaseService.findEmptyColumnIndices(
        _sessionId!,
        _headers,
      );

      if (emptyColumnIndices.isEmpty) {
        if (mounted) {
          setState(() => _isLoading = false);
          _showSnackBar('No empty columns found', type: SnackBarType.info);
        }
        return;
      }

      // Delete columns starting from the highest index to avoid shifting issues
      for (final columnIndex in emptyColumnIndices.toList().reversed) {
        await CsvDatabaseService.deleteColumn(_sessionId!, columnIndex);
      }

      if (mounted) {
        setState(() {
          for (final columnIndex in emptyColumnIndices.reversed) {
            if (columnIndex >= 0 && columnIndex < _headers.length) {
              _headers.removeAt(columnIndex);
            }
          }
          _hasUnsavedChanges = true;
          _isLoading = false;
          _tableKey = UniqueKey();
        });
      }

      _showSnackBar(
        'Deleted ${emptyColumnIndices.length} empty column${emptyColumnIndices.length == 1 ? '' : 's'}',
        type: SnackBarType.success,
      );
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
      }
      _showSnackBar('Error deleting empty columns: $e', type: SnackBarType.error);
    }
  }

  Future<void> _reorderColumn(int fromIndex, int toIndex) async {
    if (_sessionId == null || fromIndex == toIndex) return;

    setState(() => _isLoading = true);

    try {
      await CsvDatabaseService.reorderColumn(
        _sessionId!,
        fromIndex,
        toIndex,
      );

      await _createHistorySnapshot(
        'Reordered column ${fromIndex + 1} → ${toIndex + 1}',
        actionType: 'reorder',
      );

      setState(() {
        final header = _headers.removeAt(fromIndex);
        _headers.insert(toIndex, header);
        _hasUnsavedChanges = true;
        _isLoading = false;
        _tableKey = UniqueKey();
      });

      await _refreshFilteredView();

      _showSnackBar(
        'Moved column ${fromIndex + 1} → ${toIndex + 1}',
        type: SnackBarType.success,
      );
    } catch (e) {
      setState(() => _isLoading = false);
      _showSnackBar('Error reordering column: $e',
          type: SnackBarType.error);
    }
  }

  Future<void> _reorderRow(int fromIndex, int toIndex) async {
    if (_sessionId == null || fromIndex == toIndex) return;

    setState(() => _isLoading = true);

    try {
      await CsvDatabaseService.reorderRow(
        _sessionId!,
        fromIndex,
        toIndex,
      );

      await _createHistorySnapshot(
        'Reordered row ${fromIndex + 1} → ${toIndex + 1}',
        actionType: 'reorder',
      );

      setState(() {
        _hasUnsavedChanges = true;
        _isLoading = false;
        _selectedRowIndices.clear();
        _selectedCells.clear();
        _tableKey = UniqueKey();
      });

      await _refreshFilteredView();

      _showSnackBar(
        'Moved row ${fromIndex + 1} → ${toIndex + 1}',
        type: SnackBarType.success,
      );
    } catch (e) {
      setState(() => _isLoading = false);
      _showSnackBar('Error reordering row: $e', type: SnackBarType.error);
    }
  }

  Future<void> _handleRowDelete(int rowIndex) async {
    await _deleteSelectedRows(indices: [rowIndex]);
  }

  Future<void> _handleDeleteSelectedRows() async {
    await _deleteSelectedRows();
  }

  void _handleAddRow() async {
    if (_sessionId == null) return;

    try {
      final newRow = List<String>.filled(_headers.length, '');
      await CsvDatabaseService.insertRow(_sessionId!, _totalRows, newRow);
      setState(() {
        _totalRows++;
        _hasUnsavedChanges = true;
        _tableKey = UniqueKey(); // Force table refresh
      });
      await _refreshFilteredView();
      _scheduleHistorySnapshot('Added new row', actionType: 'row-add');
      _showSnackBar('Row added', type: SnackBarType.success);
    } catch (e) {
      _showSnackBar('Error adding row: $e', type: SnackBarType.error);
    }
  }

  void _handleBulkEdit() {
    if (_selectedCells.isEmpty) return;

    showDialog(
      context: context,
      builder: (context) => BulkEditDialog(
        initialValue: '',
        cellCount: _selectedCells.length,
        onSave: (newValue) async {
          if (_sessionId == null) return;

          try {
            // Update all selected cells
            final editedCells = _selectedCells.length;
            for (final cellKey in _selectedCells) {
              final parts = cellKey.split(':');
              final r = int.parse(parts[0]);
              final c = int.parse(parts[1]);

              final row = await CsvDatabaseService.getRow(_sessionId!, r);
              if (row != null) {
                row[c] = newValue;
                await CsvDatabaseService.updateRow(_sessionId!, r, row);
              }
            }

            _scheduleHistorySnapshot(
              'Bulk edited $editedCells cell(s)',
              actionType: 'edit',
            );

            setState(() {
              _hasUnsavedChanges = true;
              _selectedCells.clear();
              _tableKey = UniqueKey(); // Force table refresh
            });

            _showSnackBar(
              'Updated $editedCells cell(s)',
              type: SnackBarType.success,
            );
          } catch (e) {
            _showSnackBar('Error bulk editing: $e', type: SnackBarType.error);
          }
        },
      ),
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
    ).then((value) async {
      if (value == 'insert_before') {
        _insertRowBefore(rowIndex);
      } else if (value == 'insert_after') {
        _insertRowAfter(rowIndex);
      } else if (value == 'duplicate') {
        _duplicateRow(rowIndex);
      } else if (value == 'delete') {
        await _deleteSelectedRows(indices: [rowIndex]);
      }
    });
  }

  void _renameColumn(int columnIndex, String currentName) {
    showDialog(
      context: context,
      builder: (context) => RenameColumnDialog(
        currentName: currentName,
        onSave: (newName) async {
          try {
            await CsvDatabaseService.updateColumnName(
              _sessionId!,
              columnIndex,
              newName,
            );

            setState(() {
              _headers[columnIndex] = newName;
              _hasUnsavedChanges = true;
              _tableKey = UniqueKey(); // Force table refresh
            });

            _showSnackBar('Column renamed: $currentName → $newName',
                type: SnackBarType.success);
          } catch (e) {
            _showSnackBar('Error renaming column: $e',
                type: SnackBarType.error);
          }
        },
      ),
    );
  }

  void _addColumn(
      {int? afterIndex, bool duplicate = false, int? duplicateIndex}) async {
    if (_sessionId == null) return;
    final previousHeaders = List<String>.from(_headers);
    final previousHasUnsavedChanges = _hasUnsavedChanges;
    final isDuplicate = duplicate && duplicateIndex != null;
    final targetColumnIndex =
        afterIndex != null ? afterIndex + 1 : _headers.length;
    final newColumnName = isDuplicate && duplicateIndex != null
        ? '${_headers[duplicateIndex]}_copy'
        : 'New Column';

    setState(() {
      _headers.insert(targetColumnIndex, newColumnName);
      _hasUnsavedChanges = true;
      _isLoading = true;
    });

    try {
      if (isDuplicate && duplicateIndex != null) {
        await CsvDatabaseService.duplicateColumn(
          _sessionId!,
          duplicateIndex,
          targetColumnIndex,
        );
        _scheduleHistorySnapshot(
          'Duplicated column ${duplicateIndex + 1}',
          actionType: 'column-duplicate',
        );
        _showSnackBar('Column duplicated with data',
            type: SnackBarType.success);
      } else {
        await CsvDatabaseService.insertEmptyColumn(
          _sessionId!,
          targetColumnIndex,
        );
        _scheduleHistorySnapshot(
          'Added column at position ${targetColumnIndex + 1}',
          actionType: 'column-add',
        );
        _showSnackBar('Column added', type: SnackBarType.success);
      }

      if (mounted) {
        setState(() {
          _isLoading = false;
          _tableKey = UniqueKey(); // Force table refresh
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _headers = previousHeaders;
          _hasUnsavedChanges = previousHasUnsavedChanges;
          _isLoading = false;
          _tableKey = UniqueKey();
        });
      }
      _showSnackBar('Error adding column: $e', type: SnackBarType.error);
    }
  }

  Future<void> _deleteColumn(int columnIndex) async {
    if (_sessionId == null || columnIndex < 0 || columnIndex >= _headers.length) {
      return;
    }

    final previousHeaders = List<String>.from(_headers);
    final previousHasUnsavedChanges = _hasUnsavedChanges;

    setState(() {
      _headers.removeAt(columnIndex);
      _hasUnsavedChanges = true;
      _isLoading = true;
    });

    try {
      await CsvDatabaseService.deleteColumn(_sessionId!, columnIndex);

      _scheduleHistorySnapshot(
        'Deleted column ${columnIndex + 1}',
        actionType: 'column-delete',
      );

      if (mounted) {
        setState(() {
          _isLoading = false;
          _tableKey = UniqueKey(); // Force table refresh
        });
      }

      await _refreshFilteredView();

      _showSnackBar('Column deleted', type: SnackBarType.success);
    } catch (e) {
      if (mounted) {
        setState(() {
          _headers = previousHeaders;
          _hasUnsavedChanges = previousHasUnsavedChanges;
          _isLoading = false;
          _tableKey = UniqueKey();
        });
      }

      _showSnackBar('Error deleting column: $e', type: SnackBarType.error);
    }
  }

  Future<void> _insertRowBefore(int rowIndex) async {
    if (_sessionId == null) return;

    final previousHasUnsavedChanges = _hasUnsavedChanges;
    setState(() {
      _hasUnsavedChanges = true;
      _isLoading = true;
    });

    try {
      final newRow = List<String>.filled(_headers.length, '');
      await CsvDatabaseService.insertRow(_sessionId!, rowIndex, newRow);

      _scheduleHistorySnapshot(
        'Inserted row before ${rowIndex + 1}',
        actionType: 'row-insert',
      );

      if (!mounted) return;
      setState(() {
        _totalRows++;
        _isLoading = false;
        _selectedRowIndices.clear();
        _selectedCells.clear();
        _tableKey = UniqueKey(); // Force table refresh
      });

      await _refreshFilteredView();

      _showSnackBar('Row inserted before row ${rowIndex + 1}',
          type: SnackBarType.success);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _hasUnsavedChanges = previousHasUnsavedChanges;
        _isLoading = false;
        _tableKey = UniqueKey();
      });
      _showSnackBar('Error inserting row: $e', type: SnackBarType.error);
    }
  }

  Future<void> _insertRowAfter(int rowIndex) async {
    if (_sessionId == null) return;

    final previousHasUnsavedChanges = _hasUnsavedChanges;
    setState(() {
      _hasUnsavedChanges = true;
      _isLoading = true;
    });

    try {
      final insertIndex = rowIndex + 1;
      final newRow = List<String>.filled(_headers.length, '');
      await CsvDatabaseService.insertRow(_sessionId!, insertIndex, newRow);

      _scheduleHistorySnapshot(
        'Inserted row after ${rowIndex + 1}',
        actionType: 'row-insert',
      );

      if (!mounted) return;
      setState(() {
        _totalRows++;
        _isLoading = false;
        _selectedRowIndices.clear();
        _selectedCells.clear();
        _tableKey = UniqueKey();
      });

      await _refreshFilteredView();

      _showSnackBar('Row inserted after row ${rowIndex + 1}',
          type: SnackBarType.success);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _hasUnsavedChanges = previousHasUnsavedChanges;
        _isLoading = false;
        _tableKey = UniqueKey();
      });
      _showSnackBar('Error inserting row: $e', type: SnackBarType.error);
    }
  }

  Future<void> _duplicateRow(int rowIndex) async {
    if (_sessionId == null) return;

    final previousHasUnsavedChanges = _hasUnsavedChanges;
    setState(() {
      _hasUnsavedChanges = true;
      _isLoading = true;
    });

    try {
      final originalRow = await CsvDatabaseService.getRow(_sessionId!, rowIndex);
      if (originalRow == null) {
        if (!mounted) return;
        setState(() {
          _hasUnsavedChanges = previousHasUnsavedChanges;
          _isLoading = false;
        });
        _showSnackBar('Row not found for duplication',
            type: SnackBarType.error);
        return;
      }

      final newRow = List<String>.from(originalRow);
      while (newRow.length < _headers.length) {
        newRow.add('');
      }
      if (newRow.length > _headers.length) {
        newRow.removeRange(_headers.length, newRow.length);
      }

      await CsvDatabaseService.insertRow(
        _sessionId!,
        rowIndex + 1,
        newRow,
      );

      _scheduleHistorySnapshot(
        'Duplicated row ${rowIndex + 1}',
        actionType: 'row-duplicate',
      );

      if (!mounted) return;
      setState(() {
        _totalRows++;
        _isLoading = false;
        _selectedRowIndices.clear();
        _selectedCells.clear();
        _tableKey = UniqueKey();
      });

      await _refreshFilteredView();

      _showSnackBar('Row ${rowIndex + 1} duplicated',
          type: SnackBarType.success);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _hasUnsavedChanges = previousHasUnsavedChanges;
        _isLoading = false;
        _tableKey = UniqueKey();
      });
      _showSnackBar('Error duplicating row: $e', type: SnackBarType.error);
    }
  }

  Future<void> _deleteSelectedRows({List<int>? indices}) async {
    if (_sessionId == null) return;

    final rowsToDelete = indices ?? _selectedRowIndices.toList();
    if (rowsToDelete.isEmpty) return;

    final uniqueRows = rowsToDelete.toSet().toList()..sort();
    final previousHasUnsavedChanges = _hasUnsavedChanges;

    setState(() {
      _hasUnsavedChanges = true;
      _isLoading = true;
    });

    try {
      await CsvDatabaseService.deleteRows(_sessionId!, uniqueRows);
      final remainingRows = await CsvDatabaseService.getRowCount(_sessionId!);

      await _createHistorySnapshot(
        'Deleted ${uniqueRows.length} row(s)',
        actionType: 'row-delete',
      );

      if (!mounted) return;
      setState(() {
        _totalRows = remainingRows;
        _isLoading = false;
        _selectedRowIndices.clear();
        _selectedCells.clear();
        _tableKey = UniqueKey();
      });

      await _refreshFilteredView();

      final count = uniqueRows.length;
      _showSnackBar('Deleted $count row${count == 1 ? '' : 's'}',
          type: SnackBarType.success);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _hasUnsavedChanges = previousHasUnsavedChanges;
        _isLoading = false;
        _tableKey = UniqueKey();
      });
      _showSnackBar('Error deleting rows: $e', type: SnackBarType.error);
    }
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

  String _formatNumber(int number) {
    return number.toString().replaceAllMapped(
          RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'),
          (Match m) => '${m[1]},',
        );
  }

  @override
  Widget build(BuildContext context) {
    return DropTarget(
      onDragEntered: (details) => setState(() => _isDragging = true),
      onDragExited: (details) => setState(() => _isDragging = false),
      onDragDone: (details) async {
        setState(() => _isDragging = false);
        for (final file in details.files) {
          if (file.path.toLowerCase().endsWith('.csv')) {
            final csvFile = File(file.path);
            _lastDirectoryPath = csvFile.parent.path;
            await _loadCsvFile(csvFile);
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
                unawaited(_handleUndo());
                return KeyEventResult.handled;
              } else if ((event.logicalKey == LogicalKeyboardKey.keyZ &&
                      isShift) ||
                  event.logicalKey == LogicalKeyboardKey.keyY) {
                unawaited(_handleRedo());
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
                  onPressed: () => Navigator.of(context).pop(),
                ),
                title: _fileName != null
                    ? Row(
                        children: [
                          const Icon(Icons.table_chart, size: 20),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              _fileName!,
                              style: CsvTheme.bodyMedium,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          if (_totalRows > 100000)
                            Container(
                              margin: const EdgeInsets.only(left: 8),
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 4,
                              ),
                              decoration: BoxDecoration(
                                color: CsvTheme.successColor,
                                borderRadius:
                                    BorderRadius.circular(CsvTheme.radiusSm),
                              ),
                              child: Text(
                                'OPTIMIZED MODE',
                                style: CsvTheme.labelMedium.copyWith(
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 10,
                                ),
                              ),
                            ),
                        ],
                      )
                    : null,
                actions: [
                  if (_fileName != null)
                    IconButton(
                      icon: Icon(
                        _compactMode ? Icons.unfold_more : Icons.unfold_less,
                        size: 18,
                      ),
                      tooltip: _compactMode ? 'Expand Rows' : 'Compact Mode',
                      onPressed: () {
                        setState(() => _compactMode = !_compactMode);
                      },
                    ),
                  IconButton(
                    icon: Icon(
                      _showHistoryBoard
                          ? Icons.history_toggle_off
                          : Icons.history,
                      size: 18,
                      color: _showHistoryBoard ? CsvTheme.primaryColor : null,
                    ),
                    tooltip:
                        _showHistoryBoard ? 'Close History' : 'View History',
                    onPressed: _sessionId == null
                        ? null
                        : () {
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
                  // Toolbar
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
                    onUndo: _canUndo ? () => unawaited(_handleUndo()) : null,
                    onRedo: _canRedo ? () => unawaited(_handleRedo()) : null,
                    onAddRow: _fileName != null ? _handleAddRow : null,
                    onAddColumn: _fileName != null ? _handleAddColumn : null,
                    onDeleteRows: _selectedRowIndices.isNotEmpty
                        ? () {
                            _handleDeleteSelectedRows();
                          }
                        : null,
                    onMergeRows: _selectedRowIndices.length >= 2
                        ? _handleMergeRows
                        : null,
                    onSplitCells:
                        _selectedCells.isNotEmpty ? _handleSplitCells : null,
                    onSplitRows: _selectedRowIndices.isNotEmpty
                        ? _handleSplitRows
                        : null,
                    onBulkEdit:
                        _selectedCells.isNotEmpty ? _handleBulkEdit : null,
                    onClearCellSelection: () {
                      setState(() => _selectedCells.clear());
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
                        ? () => _reloadWithDifferentEncoding()
                        : null,
                    onCleanupAction: (value) {
                      if (value == 'empty_rows') {
                        _handleDeleteEmptyRows();
                      } else if (value == 'empty_columns') {
                        _handleDeleteEmptyColumns();
                      } else if (value == 'duplicate_rows') {
                        _handleRemoveDuplicates();
                      }
                    },
                  ),

                  // Search Bar
                  if (_fileName != null)
                    CsvSearchBar(
                      onSearch: _handleSearch,
                      onToggleAdvanced: () {
                        setState(() {
                          _showAdvancedSearch = !_showAdvancedSearch;
                        });
                      },
                      onResetFilters: () {
                        setState(() {
                          _searchQuery = '';
                          _caseSensitive = false;
                          _useRegex = false;
                        });
                      },
                      showAdvanced: _showAdvancedSearch,
                      hasActiveFilters: _caseSensitive ||
                          _useRegex ||
                          _selectedSearchColumns.isNotEmpty ||
                          _rowRangeStart != null ||
                          _rowRangeEnd != null,
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
                        });
                      },
                      onCaseSensitiveChange: (value) {
                        setState(() => _caseSensitive = value);
                      },
                      onRegexChange: (value) {
                        setState(() => _useRegex = value);
                      },
                      onRowRangeStartChange: (value) {
                        setState(() => _rowRangeStart = int.tryParse(value));
                      },
                      onRowRangeEndChange: (value) {
                        setState(() => _rowRangeEnd = int.tryParse(value));
                      },
                      caseSensitive: _caseSensitive,
                      useRegex: _useRegex,
                      totalRows: _totalRows,
                    ),

                  // Main content
                  Expanded(
                    child: _isLoading
                        ? _buildLoadingState()
                        : _sessionId == null
                            ? _buildEmptyState()
                            : VirtualCsvTable(
                                key: _tableKey,
                                sessionId: _sessionId!,
                                headers: _headers,
                                totalRows: _totalRows,
                                showCheckboxes: _showCheckboxes,
                                compactMode: _compactMode,
                                searchQuery: _searchQuery,
                                caseSensitive: _caseSensitive,
                                searchResults: _searchResults,
                                selectedRowIndices: _selectedRowIndices,
                                selectedCells: _selectedCells,
                                onRowSelectionToggle: (index) {
                                  setState(() {
                                    if (_selectedRowIndices.contains(index)) {
                                      _selectedRowIndices.remove(index);
                                    } else {
                                      _selectedRowIndices.add(index);
                                    }
                                  });
                                },
                                onCellSelectionToggle: (row, col) {
                                  setState(() {
                                    final key = '$row:$col';
                                    if (_selectedCells.contains(key)) {
                                      _selectedCells.remove(key);
                                    } else {
                                      _selectedCells.add(key);
                                    }
                                  });
                                },
                                onCellEdit: _handleCellEdit,
                                onColumnRename: _handleColumnRename,
                                onColumnDelete: _handleColumnDelete,
                                onColumnReorder: _reorderColumn,
                                onRowDelete: _handleRowDelete,
                                onRowDuplicate: _duplicateRow,
                                onRowInsertBefore: _insertRowBefore,
                                onRowInsertAfter: _insertRowAfter,
                                onRowReorder: _reorderRow,
                                onHeaderContextMenu: _showHeaderContextMenu,
                                onRowContextMenu: _showRowContextMenu,
                              ),
                  ),

                  // Status Bar
                  if (_fileName != null)
                    CsvStatusBar(
                      fileName: _fileName,
                      totalRows: _totalRows,
                      filteredRows: _searchResults.isNotEmpty
                          ? _searchResults.length
                          : _totalRows,
                      columnCount: _headers.length,
                      selectedRowsCount: _selectedRowIndices.length,
                      encoding: 'UTF-8',
                    ),
                ],
              ),
            ),

            // Drag overlay
            if (_isDragging) _buildDragOverlay(),

            // History board overlay
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
                        onTap: () {},
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

  Widget _buildLoadingState() {
    return Center(
      child: Container(
        constraints: const BoxConstraints(maxWidth: 400),
        padding: const EdgeInsets.all(CsvTheme.spacing2xl),
        decoration: BoxDecoration(
          color: CsvTheme.surfaceColor,
          borderRadius: BorderRadius.circular(CsvTheme.radiusLg),
          boxShadow: const [CsvTheme.shadowMd],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const CircularProgressIndicator(
              valueColor: AlwaysStoppedAnimation<Color>(CsvTheme.primaryColor),
            ),
            const SizedBox(height: CsvTheme.spacingXl),
            Text(
              'Loading CSV file...',
              style: CsvTheme.headingMedium,
            ),
            const SizedBox(height: CsvTheme.spacingMd),
            LinearProgressIndicator(
              value: _loadingProgress,
              backgroundColor: CsvTheme.borderColor,
              valueColor:
                  const AlwaysStoppedAnimation<Color>(CsvTheme.primaryColor),
            ),
            const SizedBox(height: CsvTheme.spacingMd),
            Text(
              '${(_loadingProgress * 100).toStringAsFixed(1)}% - ${_formatNumber(_loadedRows)} rows loaded',
              style: CsvTheme.bodyMedium.copyWith(
                color: CsvTheme.textSecondary,
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
            Text('No CSV file loaded', style: CsvTheme.headingLarge),
            const SizedBox(height: CsvTheme.spacingMd),
            Text(
              'Click the button below or drag & drop a CSV file\nOptimized for files with 320k+ rows',
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
              border: Border.all(color: CsvTheme.primaryColor, width: 2),
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

enum SnackBarType { success, error, warning, info }
