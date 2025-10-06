import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:file_picker/file_picker.dart';
import 'dart:io';
import 'dart:convert';
import 'package:desktop_drop/desktop_drop.dart';
import 'dart:ui';

// Import refactored components
import '../models/csv_undoable_actions.dart';
import '../services/csv_file_service.dart';
import '../widgets/csv_dialogs.dart';
import '../widgets/csv_table_widgets.dart';
import '../mixins/csv_operations_mixin.dart';
import '../mixins/csv_undo_redo_mixin.dart';

class CsvReaderScreen extends StatefulWidget {
  const CsvReaderScreen({super.key});

  @override
  State<CsvReaderScreen> createState() => _CsvReaderScreenState();
}

class _CsvReaderScreenState extends State<CsvReaderScreen>
    with CsvOperationsMixin, CsvUndoRedoMixin {
  List<List<String>> _allCsvData = []; // All data in memory
  List<String> _headers = [];
  bool _isLoading = false;
  String? _fileName;
  int _totalRows = 0;
  bool _isDragging = false; // Track drag hover state
  File? _currentFile;
  final ScrollController _horizontalScrollController = ScrollController();
  final ScrollController _verticalScrollController = ScrollController();
  List<List<String>> _filteredData = [];
  Key _listKey = UniqueKey(); // Force rebuild when needed
  final Map<int, int> _filteredIndexToOriginalIndex =
      {}; // filteredIndex -> originalIndex

  // Editing state
  bool _hasUnsavedChanges = false;
  bool _showCheckboxes = true; // Toggle for showing/hiding checkboxes

  // Column widths (index 0 is line number column)
  final List<double> _columnWidths = [];
  int? _resizingColumnIndex;
  double _resizeStartX = 0;
  double _resizeStartWidth = 0;

  // Row selection and actions
  final Set<int> _selectedRowIndices = {};
  final Set<String> _selectedCells =
      {}; // Set of "rowIndex:colIndex" for multi-cell selection
  final List<UndoableAction> _actionHistory = [];
  int _currentActionIndex = -1;

  // Advanced search/filter state
  final Set<int> _selectedSearchColumns = {}; // Column indices to search in
  int? _rowRangeStart;
  int? _rowRangeEnd;
  bool _caseSensitive = false;
  bool _useRegex = false;
  bool _showAdvancedSearch = false;
  String _searchQuery = '';

  // Drag & drop state
  int? _dropTargetColumnIndex;
  int? _dropTargetRowIndex;

  // Calculate line number column width based on number of rows
  double get _lineNumberColumnWidth {
    if (_totalRows == 0) return 60;
    final digits = _totalRows.toString().length;
    // Base width + extra width per digit
    return 40 + (digits * 10.0);
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
  }

  @override
  void dispose() {
    _verticalScrollController.removeListener(_onScroll);
    _horizontalScrollController.dispose();
    _verticalScrollController.dispose();
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
    // Line number column uses dynamic width
    _columnWidths.add(_lineNumberColumnWidth);
    // Data columns default to 150px
    for (int i = 0; i < _headers.length; i++) {
      _columnWidths.add(150);
    }
  }

  void _startResize(int columnIndex, double startX) {
    setState(() {
      _resizingColumnIndex = columnIndex;
      _resizeStartX = startX;
      _resizeStartWidth = _columnWidths[columnIndex];
    });
  }

  void _updateResize(double currentX) {
    if (_resizingColumnIndex != null) {
      final delta = currentX - _resizeStartX;
      final newWidth = (_resizeStartWidth + delta).clamp(60.0, 500.0);
      setState(() {
        _columnWidths[_resizingColumnIndex!] = newWidth;
      });
    }
  }

  void _endResize() {
    setState(() {
      _resizingColumnIndex = null;
    });
  }

  // Wrapper methods for compatibility with existing code
  void _addAction(UndoableAction action) => addAction(action);
  void _undo() => undo();
  void _redo() => redo();

  void _toggleRowSelection(int rowIndex) {
    setState(() {
      if (_selectedRowIndices.contains(rowIndex)) {
        _selectedRowIndices.remove(rowIndex);
      } else {
        _selectedRowIndices.add(rowIndex);
      }
    });
  }

  // Wrapper methods for mixin operations
  void _addNewRow() => addNewRow();
  void _insertRowAfter(int rowIndex) => insertRowAfter(rowIndex);
  void _insertRowBefore(int rowIndex) => insertRowBefore(rowIndex);

  void _addColumn(
      {int? afterIndex, bool duplicate = false, int? duplicateIndex}) {
    // Add to column widths first
    if (afterIndex != null && _columnWidths.length > afterIndex + 1) {
      _columnWidths.insert(
          afterIndex + 2, 150.0); // +1 for checkbox, +1 for after
    } else {
      _columnWidths.add(150.0);
    }

    // Call mixin method
    addColumn(
        afterIndex: afterIndex,
        duplicate: duplicate,
        duplicateIndex: duplicateIndex);
  }

  void _deleteColumn(int columnIndex) {
    // Remove from column widths first
    if (_columnWidths.length > columnIndex + 1) {
      _columnWidths.removeAt(columnIndex + 1); // +1 for checkbox column
    }

    // Call mixin method
    deleteColumn(columnIndex);
  }

  void _renameColumn(int columnIndex, String currentName) {
    showDialog(
      context: context,
      builder: (context) => RenameColumnDialog(
        currentName: currentName,
        onSave: (newName) => renameColumn(columnIndex, newName),
      ),
    );
  }

  void _reorderColumn(int oldIndex, int newIndex) {
    // Reorder column widths (remember index 0 is checkbox, index 1 is line number)
    if (_columnWidths.length > oldIndex + 1) {
      final width = _columnWidths.removeAt(oldIndex + 1);
      _columnWidths.insert(newIndex + 1, width);
    }

    // Call mixin method
    reorderColumn(oldIndex, newIndex);
  }

  void _reorderRow(int oldIndex, int newIndex) =>
      reorderRow(oldIndex, newIndex);

  void _deleteSelectedRows() {
    deleteRows(_selectedRowIndices);
    setState(() {
      _selectedRowIndices.clear();
    });
  }

  void _mergeSelectedRows() {
    if (_selectedRowIndices.length < 2) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please select at least 2 rows to merge'),
          duration: Duration(seconds: 2),
        ),
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

          // Create merged row by combining content from all selected rows
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
            // Join non-empty values with separator
            mergedRow.add(cellValues.join(separator));
          }

          // Backup all affected rows
          final Map<int, List<String>> deletedRows = {};
          for (final index in sortedIndices) {
            deletedRows[index] = List.from(_allCsvData[index]);
          }

          // Create action with sorted ascending indices
          final action = MergeRowsAction(
            _allCsvData,
            targetIndex,
            sortedIndices, // Pass ascending indices
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
            _listKey = UniqueKey(); // Force rebuild
            _hasUnsavedChanges = true;
          });

          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Merged ${sortedIndices.length} rows'),
              backgroundColor: Colors.green,
              duration: const Duration(seconds: 2),
            ),
          );
        },
      ),
    );
  }

  void _deleteEmptyRows() => deleteEmptyRows();
  void _removeDuplicateRows() => removeDuplicateRows();

  void _deleteEmptyColumns() {
    // Call mixin method
    deleteEmptyColumns();

    // Clean up column widths that may have been orphaned
    setState(() {
      // Ensure column widths match header count + 1 (for line number column)
      while (_columnWidths.length > _headers.length + 1) {
        _columnWidths.removeLast();
      }
    });
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

    // Get the first cell's value as the initial value
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
            _selectedCells.clear(); // Clear selection after edit
          });
        },
      ),
    );
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
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Changes saved successfully!'),
            backgroundColor: Colors.green,
            duration: Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error saving file: $e'),
            backgroundColor: Colors.red,
          ),
        );
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
      );

      if (result != null && result.files.single.path != null) {
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

        final file = File(result.files.single.path!);
        _currentFile = file;

        // Load entire file at once
        await _readCsvFileGradually(file);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error loading file: $e')),
        );
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
      }
    } catch (e) {
      // Handle encoding errors
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
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Error loading CSV: $e'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    }
  }

  void _rebuildFilteredIndexMapping() {
    _filteredIndexToOriginalIndex.clear();
    if (_filteredData.isEmpty) return;

    // Build mapping from filtered index to original index
    for (int filteredIdx = 0;
        filteredIdx < _filteredData.length;
        filteredIdx++) {
      final row = _filteredData[filteredIdx];
      // Find this row's index in _allCsvData using identity check
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
    setState(() {
      _searchQuery = query; // Store for highlighting

      if (query.isEmpty &&
          _selectedSearchColumns.isEmpty &&
          _rowRangeStart == null &&
          _rowRangeEnd == null) {
        _filteredData = _allCsvData;
        _rebuildFilteredIndexMapping();
        return;
      }

      _filteredData = _allCsvData
          .asMap()
          .entries
          .where((entry) {
            final rowIndex = entry.key;
            final row = entry.value;

            // Apply row range filter
            if (_rowRangeStart != null && rowIndex < _rowRangeStart! - 1) {
              return false;
            }
            if (_rowRangeEnd != null && rowIndex > _rowRangeEnd! - 1) {
              return false;
            }

            // If no search query, just apply row range
            if (query.isEmpty) {
              return true;
            }

            // Determine which columns to search
            final columnsToSearch = _selectedSearchColumns.isEmpty
                ? List.generate(row.length, (i) => i) // Search all columns
                : _selectedSearchColumns.toList();

            // Apply text search with options
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
              // If regex fails, fall back to normal search
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
        // Handle dropped files
        for (final file in details.files) {
          if (file.path.toLowerCase().endsWith('.csv')) {
            setState(() {
              clearHistory();
              _hasUnsavedChanges = false;
              _selectedRowIndices.clear();
              _selectedCells.clear();
            });
            await _readCsvFileGradually(File(file.path));
            break; // Only load the first CSV file
          }
        }
      },
      child: KeyboardListener(
        focusNode: FocusNode(),
        autofocus: true,
        onKeyEvent: (event) {
          if (event is KeyDownEvent) {
            final isCmdOrCtrl = HardwareKeyboard.instance.isMetaPressed ||
                HardwareKeyboard.instance.isControlPressed;
            final isShift = HardwareKeyboard.instance.isShiftPressed;

            if (isCmdOrCtrl) {
              // Cmd+S / Ctrl+S - Save
              if (event.logicalKey == LogicalKeyboardKey.keyS) {
                _saveToFile();
              }
              // Cmd+Z / Ctrl+Z - Undo
              else if (event.logicalKey == LogicalKeyboardKey.keyZ &&
                  !isShift) {
                _undo();
              }
              // Cmd+Shift+Z / Ctrl+Shift+Z - Redo
              else if (event.logicalKey == LogicalKeyboardKey.keyZ && isShift) {
                _redo();
              }
            }
          }
        },
        child: Stack(
          children: [
            Scaffold(
              appBar: AppBar(
                title: Row(
                  children: [
                    const Text('CSV File Reader'),
                    if (_hasUnsavedChanges) ...[
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: Colors.orange,
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: const Text(
                          'Unsaved',
                          style: TextStyle(fontSize: 12, color: Colors.white),
                        ),
                      ),
                    ],
                  ],
                ),
                actions: [
                  if (_fileName != null) ...[
                    // Undo button
                    IconButton(
                      icon: const Icon(Icons.undo),
                      onPressed: _canUndo ? _undo : null,
                      tooltip: 'Undo (Cmd+Z)',
                    ),
                    // Redo button
                    IconButton(
                      icon: const Icon(Icons.redo),
                      onPressed: _canRedo ? _redo : null,
                      tooltip: 'Redo (Cmd+Shift+Z)',
                    ),
                    const SizedBox(width: 8),
                    // Bulk edit button
                    if (_selectedCells.isNotEmpty) ...[
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: Theme.of(context).colorScheme.primaryContainer,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Row(
                          children: [
                            Text(
                              '${_selectedCells.length} cells',
                              style: TextStyle(
                                color: Theme.of(context)
                                    .colorScheme
                                    .onPrimaryContainer,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(width: 4),
                            IconButton(
                              icon: const Icon(Icons.edit, size: 18),
                              onPressed: _bulkEditCells,
                              tooltip: 'Bulk Edit Selected Cells',
                              padding: EdgeInsets.zero,
                              constraints: const BoxConstraints(),
                              iconSize: 18,
                            ),
                            IconButton(
                              icon: const Icon(Icons.clear, size: 18),
                              onPressed: () {
                                setState(() {
                                  _selectedCells.clear();
                                });
                              },
                              tooltip: 'Clear Selection',
                              padding: EdgeInsets.zero,
                              constraints: const BoxConstraints(),
                              iconSize: 18,
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 8),
                    ],
                    // Toggle checkboxes visibility
                    IconButton(
                      icon: Icon(_showCheckboxes
                          ? Icons.check_box
                          : Icons.check_box_outline_blank),
                      onPressed: () {
                        setState(() {
                          _showCheckboxes = !_showCheckboxes;
                          // Clear selections when hiding checkboxes
                          if (!_showCheckboxes) {
                            _selectedRowIndices.clear();
                            _selectedCells.clear();
                          }
                        });
                      },
                      tooltip: _showCheckboxes
                          ? 'Hide Checkboxes'
                          : 'Show Checkboxes',
                      color: _showCheckboxes
                          ? Theme.of(context).colorScheme.primary
                          : null,
                    ),
                    const SizedBox(width: 8),
                    // Add row button
                    IconButton(
                      icon: const Icon(Icons.add),
                      onPressed: _addNewRow,
                      tooltip: 'Add New Row',
                    ),
                    // Merge rows button (only show when multiple rows selected)
                    if (_selectedRowIndices.length >= 2)
                      IconButton(
                        icon: const Icon(Icons.merge),
                        onPressed: _mergeSelectedRows,
                        tooltip: 'Merge Selected Rows',
                        color: Theme.of(context).colorScheme.primary,
                      ),
                    // Add new column button
                    IconButton(
                      icon: const Icon(Icons.view_column),
                      onPressed: () => _addColumn(),
                      tooltip: 'Add New Column',
                    ),
                    // Delete selected rows button
                    IconButton(
                      icon: const Icon(Icons.delete),
                      onPressed: _selectedRowIndices.isNotEmpty
                          ? _deleteSelectedRows
                          : null,
                      tooltip: 'Delete Selected Rows',
                    ),
                    // Change encoding button
                    IconButton(
                      icon: const Icon(Icons.translate),
                      onPressed: _currentFile != null
                          ? _reloadWithDifferentEncoding
                          : null,
                      tooltip: 'Change Encoding',
                    ),
                    // Cleanup menu
                    PopupMenuButton<String>(
                      icon: const Icon(Icons.cleaning_services),
                      tooltip: 'Clean up data',
                      onSelected: (value) {
                        if (value == 'empty_rows') {
                          _deleteEmptyRows();
                        } else if (value == 'empty_columns') {
                          _deleteEmptyColumns();
                        } else if (value == 'duplicate_rows') {
                          _removeDuplicateRows();
                        }
                      },
                      itemBuilder: (context) => [
                        const PopupMenuItem(
                          value: 'empty_rows',
                          child: Row(
                            children: [
                              Icon(Icons.delete_sweep),
                              SizedBox(width: 8),
                              Text('Delete Empty Rows'),
                            ],
                          ),
                        ),
                        const PopupMenuItem(
                          value: 'empty_columns',
                          child: Row(
                            children: [
                              Icon(Icons.view_column),
                              SizedBox(width: 8),
                              Text('Delete Empty Columns'),
                            ],
                          ),
                        ),
                        const PopupMenuItem(
                          value: 'duplicate_rows',
                          child: Row(
                            children: [
                              Icon(Icons.content_copy),
                              SizedBox(width: 8),
                              Text('Remove Duplicate Rows'),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(width: 8),
                  ],
                  if (_hasUnsavedChanges)
                    IconButton(
                      icon: const Icon(Icons.save),
                      onPressed: _saveToFile,
                      tooltip: 'Save Changes (Cmd+S)',
                    ),
                  if (_fileName != null)
                    Padding(
                      padding: const EdgeInsets.only(right: 16),
                      child: Center(
                        child: Text(
                          '${_filteredData.length} / $_totalRows rows${_selectedRowIndices.isNotEmpty ? " (${_selectedRowIndices.length} selected)" : ""}',
                          style: Theme.of(context).textTheme.bodyMedium,
                        ),
                      ),
                    ),
                ],
              ),
              body: Column(
                children: [
                  // Header with file info and search
                  if (_fileName != null)
                    Container(
                      padding: const EdgeInsets.all(16),
                      color: Theme.of(context)
                          .colorScheme
                          .primaryContainer
                          .withOpacity(0.3),
                      child: Column(
                        children: [
                          Row(
                            children: [
                              Icon(
                                Icons.insert_drive_file,
                                color: Theme.of(context).colorScheme.primary,
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  _fileName!,
                                  style: Theme.of(context)
                                      .textTheme
                                      .titleMedium
                                      ?.copyWith(
                                        fontWeight: FontWeight.bold,
                                      ),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              IconButton(
                                icon: const Icon(Icons.refresh),
                                onPressed: _pickAndReadCsvFile,
                                tooltip: 'Load another file',
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          // Search bar with advanced options
                          Row(
                            children: [
                              Expanded(
                                child: TextField(
                                  decoration: InputDecoration(
                                    hintText: 'Search in table...',
                                    prefixIcon: const Icon(Icons.search),
                                    suffixIcon: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        if (_selectedSearchColumns.isNotEmpty ||
                                            _rowRangeStart != null ||
                                            _rowRangeEnd != null ||
                                            _caseSensitive ||
                                            _useRegex)
                                          IconButton(
                                            icon: const Icon(Icons.clear),
                                            onPressed: _resetFilters,
                                            tooltip: 'Clear filters',
                                          ),
                                        IconButton(
                                          icon: Icon(_showAdvancedSearch
                                              ? Icons.expand_less
                                              : Icons.tune),
                                          onPressed: () {
                                            setState(() {
                                              _showAdvancedSearch =
                                                  !_showAdvancedSearch;
                                            });
                                          },
                                          tooltip: 'Advanced search',
                                        ),
                                      ],
                                    ),
                                    border: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    filled: true,
                                    fillColor:
                                        Theme.of(context).colorScheme.surface,
                                  ),
                                  onChanged: _filterData,
                                ),
                              ),
                            ],
                          ),
                          // Advanced search options
                          if (_showAdvancedSearch) ...[
                            const SizedBox(height: 12),
                            Container(
                              padding: const EdgeInsets.all(16),
                              decoration: BoxDecoration(
                                color: Theme.of(context).colorScheme.surface,
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(
                                  color: Theme.of(context)
                                      .colorScheme
                                      .outline
                                      .withOpacity(0.2),
                                ),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Advanced Search Options',
                                    style: Theme.of(context)
                                        .textTheme
                                        .titleSmall
                                        ?.copyWith(fontWeight: FontWeight.bold),
                                  ),
                                  const SizedBox(height: 12),
                                  // Search options
                                  Wrap(
                                    spacing: 12,
                                    runSpacing: 8,
                                    children: [
                                      FilterChip(
                                        label: const Text('Case sensitive'),
                                        selected: _caseSensitive,
                                        onSelected: (selected) {
                                          setState(() {
                                            _caseSensitive = selected;
                                            _filterData(''); // Reapply filter
                                          });
                                        },
                                      ),
                                      FilterChip(
                                        label: const Text('Use regex'),
                                        selected: _useRegex,
                                        onSelected: (selected) {
                                          setState(() {
                                            _useRegex = selected;
                                            _filterData(''); // Reapply filter
                                          });
                                        },
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 12),
                                  // Row range filter
                                  Row(
                                    children: [
                                      Expanded(
                                        child: TextField(
                                          decoration: InputDecoration(
                                            labelText: 'From Row',
                                            hintText: '1',
                                            isDense: true,
                                            border: OutlineInputBorder(
                                              borderRadius:
                                                  BorderRadius.circular(8),
                                            ),
                                          ),
                                          keyboardType: TextInputType.number,
                                          onChanged: (value) {
                                            setState(() {
                                              _rowRangeStart =
                                                  int.tryParse(value);
                                              _filterData('');
                                            });
                                          },
                                        ),
                                      ),
                                      const SizedBox(width: 12),
                                      Expanded(
                                        child: TextField(
                                          decoration: InputDecoration(
                                            labelText: 'To Row',
                                            hintText: '$_totalRows',
                                            isDense: true,
                                            border: OutlineInputBorder(
                                              borderRadius:
                                                  BorderRadius.circular(8),
                                            ),
                                          ),
                                          keyboardType: TextInputType.number,
                                          onChanged: (value) {
                                            setState(() {
                                              _rowRangeEnd =
                                                  int.tryParse(value);
                                              _filterData('');
                                            });
                                          },
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 12),
                                  // Column selector
                                  Text(
                                    'Search in columns:',
                                    style:
                                        Theme.of(context).textTheme.bodySmall,
                                  ),
                                  const SizedBox(height: 8),
                                  Wrap(
                                    spacing: 8,
                                    runSpacing: 8,
                                    children: [
                                      FilterChip(
                                        label: const Text('All'),
                                        selected:
                                            _selectedSearchColumns.isEmpty,
                                        onSelected: (selected) {
                                          setState(() {
                                            _selectedSearchColumns.clear();
                                            _filterData('');
                                          });
                                        },
                                      ),
                                      ..._headers.asMap().entries.map((entry) {
                                        final colIndex = entry.key;
                                        final colName = entry.value;
                                        return FilterChip(
                                          label: Text(colName),
                                          selected: _selectedSearchColumns
                                              .contains(colIndex),
                                          onSelected: (selected) {
                                            setState(() {
                                              if (selected) {
                                                _selectedSearchColumns
                                                    .add(colIndex);
                                              } else {
                                                _selectedSearchColumns
                                                    .remove(colIndex);
                                              }
                                              _filterData('');
                                            });
                                          },
                                        );
                                      }),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),

                  // CSV Table
                  Expanded(
                    child: _isLoading
                        ? const Center(child: CircularProgressIndicator())
                        : _allCsvData.isEmpty
                            ? Center(
                                child: Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Icon(
                                      Icons.table_chart_outlined,
                                      size: 80,
                                      color: Theme.of(context)
                                          .colorScheme
                                          .primary
                                          .withOpacity(0.5),
                                    ),
                                    const SizedBox(height: 16),
                                    Text(
                                      'No CSV file loaded',
                                      style: Theme.of(context)
                                          .textTheme
                                          .titleLarge,
                                    ),
                                    const SizedBox(height: 8),
                                    Text(
                                      'Click the button below or drag & drop a CSV file',
                                      style: Theme.of(context)
                                          .textTheme
                                          .bodyMedium
                                          ?.copyWith(
                                            color: Theme.of(context)
                                                .colorScheme
                                                .onSurface
                                                .withOpacity(0.6),
                                          ),
                                    ),
                                    const SizedBox(height: 24),
                                    ElevatedButton.icon(
                                      onPressed: _pickAndReadCsvFile,
                                      icon: const Icon(Icons.upload_file),
                                      label: const Text('Load CSV File'),
                                      style: ElevatedButton.styleFrom(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 24,
                                          vertical: 16,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              )
                            : Row(
                                children: [
                                  // Table area with horizontal scroll
                                  Expanded(
                                    child: Scrollbar(
                                      controller: _horizontalScrollController,
                                      thumbVisibility: true,
                                      child: SingleChildScrollView(
                                        controller: _horizontalScrollController,
                                        scrollDirection: Axis.horizontal,
                                        child: SizedBox(
                                          width: _columnWidths.isNotEmpty
                                              ? _columnWidths
                                                      .reduce((a, b) => a + b) +
                                                  (_showCheckboxes
                                                      ? 48
                                                      : 0) // +48 for checkbox column if shown
                                              : 848,
                                          child: Column(
                                            children: [
                                              // Fixed header
                                              SizedBox(
                                                width: _columnWidths.isNotEmpty
                                                    ? _columnWidths.reduce(
                                                            (a, b) => a + b) +
                                                        (_showCheckboxes
                                                            ? 48
                                                            : 0)
                                                    : null,
                                                child: Container(
                                                  decoration:
                                                      const BoxDecoration(
                                                    color: Color(
                                                        0xFFF8F8F8), // Light gray header like Easy CSV Editor
                                                    border: Border(
                                                      bottom: BorderSide(
                                                        color: Color(
                                                            0xFFDDDDDD), // Slightly darker border
                                                      ),
                                                    ),
                                                  ),
                                                  child: Row(
                                                    children: [
                                                      // Select all checkbox (conditionally shown)
                                                      if (_showCheckboxes)
                                                        SizedBox(
                                                          width: 48,
                                                          height: 48,
                                                          child: Checkbox(
                                                            value: _selectedRowIndices
                                                                        .length ==
                                                                    _allCsvData
                                                                        .length &&
                                                                _allCsvData
                                                                    .isNotEmpty,
                                                            tristate: true,
                                                            onChanged: (value) {
                                                              setState(() {
                                                                if (_selectedRowIndices
                                                                        .length ==
                                                                    _allCsvData
                                                                        .length) {
                                                                  _selectedRowIndices
                                                                      .clear();
                                                                } else {
                                                                  _selectedRowIndices
                                                                      .clear();
                                                                  _selectedRowIndices.addAll(List.generate(
                                                                      _allCsvData
                                                                          .length,
                                                                      (i) =>
                                                                          i));
                                                                }
                                                              });
                                                            },
                                                          ),
                                                        ),
                                                      // Line number header
                                                      _buildHeaderCell('#', 0,
                                                          isPrimary: true),
                                                      // Data headers
                                                      ..._headers
                                                          .asMap()
                                                          .entries
                                                          .map((entry) =>
                                                              _buildHeaderCell(
                                                                  entry.value,
                                                                  entry.key +
                                                                      1)),
                                                    ],
                                                  ),
                                                ),
                                              ),
                                              // Virtualized body
                                              Expanded(
                                                child: ListView.builder(
                                                  key:
                                                      _listKey, // Force rebuild on key change
                                                  controller:
                                                      _verticalScrollController,
                                                  itemCount:
                                                      _filteredData.length,
                                                  // Increase cache for smoother performance
                                                  cacheExtent: 1000,
                                                  // Add repaint boundaries for better performance
                                                  addRepaintBoundaries: true,
                                                  itemBuilder:
                                                      (context, filteredIndex) {
                                                    final row = _filteredData[
                                                        filteredIndex];
                                                    // Get original index from mapping (O(1) lookup)
                                                    final originalIndex =
                                                        _filteredIndexToOriginalIndex[
                                                                filteredIndex] ??
                                                            filteredIndex;
                                                    final lineNumber =
                                                        originalIndex + 1;
                                                    return Container(
                                                      key: ValueKey(
                                                          'row_$originalIndex'), // Unique key per row
                                                      child: _buildDataRow(
                                                          lineNumber,
                                                          row,
                                                          filteredIndex),
                                                    );
                                                  },
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                      ),
                                    ),
                                  ),
                                  // Vertical scrollbar on the right edge of screen
                                  RawScrollbar(
                                    controller: _verticalScrollController,
                                    thumbVisibility: true,
                                    thickness: 12,
                                    radius: const Radius.circular(6),
                                    thumbColor: Theme.of(context)
                                        .colorScheme
                                        .primary
                                        .withOpacity(0.7),
                                    child: const SizedBox(width: 16),
                                  ),
                                ],
                              ),
                  ),
                ],
              ),
              floatingActionButton: _fileName == null
                  ? null
                  : FloatingActionButton.extended(
                      onPressed: _pickAndReadCsvFile,
                      icon: const Icon(Icons.upload_file),
                      label: const Text('Load New File'),
                    ),
            ),
            // Drag overlay
            if (_isDragging)
              Container(
                color: Theme.of(context).colorScheme.primary.withOpacity(0.1),
                child: Center(
                  child: Container(
                    padding: const EdgeInsets.all(48),
                    decoration: BoxDecoration(
                      color: Theme.of(context).colorScheme.surface,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: Theme.of(context).colorScheme.primary,
                        width: 3,
                        strokeAlign: BorderSide.strokeAlignInside,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.2),
                          blurRadius: 20,
                          spreadRadius: 5,
                        ),
                      ],
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.upload_file,
                          size: 80,
                          color: Theme.of(context).colorScheme.primary,
                        ),
                        const SizedBox(height: 24),
                        Text(
                          'Drop CSV file here',
                          style: Theme.of(context)
                              .textTheme
                              .headlineSmall
                              ?.copyWith(
                                color: Theme.of(context).colorScheme.primary,
                                fontWeight: FontWeight.bold,
                              ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Release to load the file',
                          style:
                              Theme.of(context).textTheme.bodyLarge?.copyWith(
                                    color: Theme.of(context)
                                        .colorScheme
                                        .onSurface
                                        .withOpacity(0.7),
                                  ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeaderCell(String text, int columnIndex,
      {bool isPrimary = false}) {
    final width = _columnWidths.isNotEmpty && columnIndex < _columnWidths.length
        ? _columnWidths[columnIndex]
        : 150.0;

    // Column index in data (subtract 1 because index 0 is line number)
    final dataColumnIndex = columnIndex - 1;
    final isDropTarget = _dropTargetColumnIndex == dataColumnIndex;

    Widget headerContent = SizedBox(
      width: width,
      height: 48,
      child: Stack(
        children: [
          // Header content with context menu
          GestureDetector(
            onSecondaryTapDown: !isPrimary
                ? (details) {
                    showMenu(
                      context: context,
                      position: RelativeRect.fromLTRB(
                        details.globalPosition.dx,
                        details.globalPosition.dy,
                        details.globalPosition.dx,
                        details.globalPosition.dy,
                      ),
                      items: [
                        const PopupMenuItem(
                          value: 'rename',
                          child: Row(
                            children: [
                              Icon(Icons.edit),
                              SizedBox(width: 8),
                              Text('Rename Column'),
                            ],
                          ),
                        ),
                        const PopupMenuItem(
                          value: 'add_after',
                          child: Row(
                            children: [
                              Icon(Icons.add_box),
                              SizedBox(width: 8),
                              Text('Add Column After'),
                            ],
                          ),
                        ),
                        const PopupMenuItem(
                          value: 'duplicate',
                          child: Row(
                            children: [
                              Icon(Icons.content_copy),
                              SizedBox(width: 8),
                              Text('Duplicate Column'),
                            ],
                          ),
                        ),
                        const PopupMenuItem(
                          value: 'delete',
                          child: Row(
                            children: [
                              Icon(Icons.delete),
                              SizedBox(width: 8),
                              Text('Delete Column'),
                            ],
                          ),
                        ),
                      ],
                    ).then((value) {
                      if (value == 'rename') {
                        _renameColumn(dataColumnIndex, text);
                      } else if (value == 'add_after') {
                        _addColumn(afterIndex: dataColumnIndex);
                      } else if (value == 'duplicate') {
                        _addColumn(
                            duplicate: true,
                            duplicateIndex: dataColumnIndex,
                            afterIndex: dataColumnIndex);
                      } else if (value == 'delete') {
                        _deleteColumn(dataColumnIndex);
                      }
                    });
                  }
                : null,
            onDoubleTap: !isPrimary
                ? () {
                    _renameColumn(dataColumnIndex, text);
                  }
                : null,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              alignment:
                  isPrimary ? Alignment.centerRight : Alignment.centerLeft,
              decoration: BoxDecoration(
                border: Border(
                  right: BorderSide(
                    color:
                        Theme.of(context).colorScheme.outline.withOpacity(0.2),
                  ),
                ),
              ),
              child: Text(
                text,
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color:
                      isPrimary ? Theme.of(context).colorScheme.primary : null,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ),
          // Resize handle
          Positioned(
            right: 0,
            top: 0,
            bottom: 0,
            child: MouseRegion(
              cursor: SystemMouseCursors.resizeColumn,
              child: GestureDetector(
                onPanStart: (details) {
                  _startResize(columnIndex, details.globalPosition.dx);
                },
                onPanUpdate: (details) {
                  _updateResize(details.globalPosition.dx);
                },
                onPanEnd: (details) {
                  _endResize();
                },
                child: Container(
                  width: 8,
                  color: Colors.transparent,
                  child: Center(
                    child: Container(
                      width: 2,
                      color: _resizingColumnIndex == columnIndex
                          ? Theme.of(context).colorScheme.primary
                          : Theme.of(context)
                              .colorScheme
                              .outline
                              .withOpacity(0.3),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );

    // Don't add drag for primary (line number) column
    if (isPrimary) {
      return headerContent;
    }

    // Wrap with drag & drop
    return LongPressDraggable<int>(
      data: dataColumnIndex,
      onDragStarted: () {
        setState(() {
          // Column drag started
        });
      },
      onDragEnd: (_) {
        setState(() {
          _dropTargetColumnIndex = null;
        });
      },
      feedback: Material(
        elevation: 8,
        child: Opacity(
          opacity: 0.8,
          child: Container(
            width: width,
            height: 48,
            color: Theme.of(context).colorScheme.primaryContainer,
            padding: const EdgeInsets.all(12),
            child: Text(
              text,
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
          ),
        ),
      ),
      childWhenDragging: Container(
        width: width,
        height: 48,
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
      ),
      child: DragTarget<int>(
        onWillAcceptWithDetails: (details) {
          setState(() {
            _dropTargetColumnIndex = dataColumnIndex;
          });
          return true;
        },
        onLeave: (_) {
          setState(() {
            _dropTargetColumnIndex = null;
          });
        },
        onAcceptWithDetails: (details) {
          final fromIndex = details.data;
          final toIndex = dataColumnIndex;
          _reorderColumn(fromIndex, toIndex);
          setState(() {
            _dropTargetColumnIndex = null;
          });
        },
        builder: (context, candidateData, rejectedData) {
          return Container(
            decoration: isDropTarget
                ? BoxDecoration(
                    border: Border.all(
                      color: Theme.of(context).colorScheme.primary,
                      width: 2,
                    ),
                  )
                : null,
            child: headerContent,
          );
        },
      ),
    );
  }

  // Use HighlightedText widget
  Widget _buildHighlightedText(String text) {
    return HighlightedText(
      text: text,
      searchQuery: _searchQuery,
      caseSensitive: _caseSensitive,
      useRegex: _useRegex,
    );
  }

  Widget _buildDataRow(int lineNumber, List<String> row, int filteredIndex) {
    final rowIndex = filteredIndex; // Use passed index in filtered data
    // lineNumber is already calculated from originalIndex, so convert back
    final originalRowIndex = lineNumber - 1;
    final isSelected = _selectedRowIndices.contains(originalRowIndex);
    final isDropTarget = _dropTargetRowIndex == originalRowIndex;

    // Alternating row colors (like Easy CSV Editor)
    final bool isEvenRow = originalRowIndex % 2 == 0;
    final Color baseColor = isEvenRow
        ? Colors.white
        : const Color(0xFFF5F5F5); // Light gray for odd rows

    Widget rowContent = Container(
      constraints: const BoxConstraints(minHeight: 48),
      decoration: BoxDecoration(
        color: isSelected
            ? Theme.of(context).colorScheme.primaryContainer.withOpacity(0.5)
            : isDropTarget
                ? Theme.of(context)
                    .colorScheme
                    .primaryContainer
                    .withOpacity(0.3)
                : baseColor, // Use alternating color
        border: Border(
          bottom: BorderSide(
            color: Theme.of(context).colorScheme.outline.withOpacity(0.1),
          ),
          left: isDropTarget
              ? BorderSide(
                  color: Theme.of(context).colorScheme.primary,
                  width: 3,
                )
              : BorderSide.none,
        ),
      ),
      child: IntrinsicHeight(
        child: SizedBox(
          width: _columnWidths.isNotEmpty
              ? _columnWidths.reduce((a, b) => a + b) +
                  (_showCheckboxes ? 48 : 0)
              : 848,
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Checkbox for row selection with context menu (conditionally shown)
              if (_showCheckboxes)
                GestureDetector(
                  onSecondaryTapDown: (details) {
                    showMenu(
                      context: context,
                      position: RelativeRect.fromLTRB(
                        details.globalPosition.dx,
                        details.globalPosition.dy,
                        details.globalPosition.dx,
                        details.globalPosition.dy,
                      ),
                      items: [
                        const PopupMenuItem(
                          value: 'insert_before',
                          child: Row(
                            children: [
                              Icon(Icons.arrow_upward),
                              SizedBox(width: 8),
                              Text('Insert Row Before'),
                            ],
                          ),
                        ),
                        const PopupMenuItem(
                          value: 'insert_after',
                          child: Row(
                            children: [
                              Icon(Icons.arrow_downward),
                              SizedBox(width: 8),
                              Text('Insert Row After'),
                            ],
                          ),
                        ),
                        const PopupMenuItem(
                          value: 'delete',
                          child: Row(
                            children: [
                              Icon(Icons.delete),
                              SizedBox(width: 8),
                              Text('Delete Row'),
                            ],
                          ),
                        ),
                      ],
                    ).then((value) {
                      if (value == 'insert_before') {
                        _insertRowBefore(originalRowIndex);
                      } else if (value == 'insert_after') {
                        _insertRowAfter(originalRowIndex);
                      } else if (value == 'delete') {
                        setState(() {
                          _selectedRowIndices.clear();
                          _selectedRowIndices.add(originalRowIndex);
                        });
                        _deleteSelectedRows();
                      }
                    });
                  },
                  child: SizedBox(
                    width: 48,
                    child: Center(
                      child: Checkbox(
                        key: ValueKey(
                            'checkbox_$originalRowIndex'), // Unique key
                        value: isSelected,
                        onChanged: (value) {
                          _toggleRowSelection(originalRowIndex);
                        },
                      ),
                    ),
                  ),
                ),
              // Line number cell with context menu
              GestureDetector(
                onSecondaryTapDown: (details) {
                  showMenu(
                    context: context,
                    position: RelativeRect.fromLTRB(
                      details.globalPosition.dx,
                      details.globalPosition.dy,
                      details.globalPosition.dx,
                      details.globalPosition.dy,
                    ),
                    items: [
                      const PopupMenuItem(
                        value: 'insert_before',
                        child: Row(
                          children: [
                            Icon(Icons.arrow_upward),
                            SizedBox(width: 8),
                            Text('Insert Row Before'),
                          ],
                        ),
                      ),
                      const PopupMenuItem(
                        value: 'insert_after',
                        child: Row(
                          children: [
                            Icon(Icons.arrow_downward),
                            SizedBox(width: 8),
                            Text('Insert Row After'),
                          ],
                        ),
                      ),
                      const PopupMenuItem(
                        value: 'delete',
                        child: Row(
                          children: [
                            Icon(Icons.delete),
                            SizedBox(width: 8),
                            Text('Delete Row'),
                          ],
                        ),
                      ),
                    ],
                  ).then((value) {
                    if (value == 'insert_before') {
                      _insertRowBefore(originalRowIndex);
                    } else if (value == 'insert_after') {
                      _insertRowAfter(originalRowIndex);
                    } else if (value == 'delete') {
                      setState(() {
                        _selectedRowIndices.clear();
                        _selectedRowIndices.add(originalRowIndex);
                      });
                      _deleteSelectedRows();
                    }
                  });
                },
                child: Container(
                  width: _columnWidths.isNotEmpty
                      ? _columnWidths[0]
                      : _lineNumberColumnWidth,
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  alignment: Alignment.centerRight,
                  decoration: BoxDecoration(
                    border: Border(
                      right: BorderSide(
                        color: Theme.of(context)
                            .colorScheme
                            .outline
                            .withOpacity(0.2),
                      ),
                    ),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      // Drag handle indicator
                      MouseRegion(
                        cursor: SystemMouseCursors.grab,
                        child: Icon(
                          Icons.drag_indicator,
                          size: 16,
                          color: Theme.of(context)
                              .colorScheme
                              .onSurface
                              .withOpacity(0.3),
                        ),
                      ),
                      const SizedBox(width: 4),
                      Text(
                        lineNumber.toString(),
                        style: TextStyle(
                          color: Theme.of(context)
                              .colorScheme
                              .onSurface
                              .withOpacity(0.6),
                          fontWeight: FontWeight.w500,
                          fontSize: 13,
                          fontFeatures: const [FontFeature.tabularFigures()],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              // Data cells - editable with dialog, multi-line support
              // Ensure we only display as many cells as there are headers
              ...List.generate(_headers.length, (colIndex) {
                final cell = colIndex < row.length ? row[colIndex] : '';
                final columnIndex =
                    colIndex + 1; // +1 because index 0 is line number
                final width = _columnWidths.isNotEmpty &&
                        columnIndex < _columnWidths.length
                    ? _columnWidths[columnIndex]
                    : 150.0;
                final cellKey = '$originalRowIndex:$colIndex';
                final isCellSelected = _selectedCells.contains(cellKey);

                return GestureDetector(
                  onTap: () {
                    // Check if Cmd/Ctrl is pressed for multi-select
                    if (HardwareKeyboard.instance.isMetaPressed ||
                        HardwareKeyboard.instance.isControlPressed) {
                      _toggleCellSelection(originalRowIndex, colIndex);
                    } else {
                      _startEditing(rowIndex, colIndex, cell);
                    }
                  },
                  child: Container(
                    width: width,
                    padding:
                        const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    decoration: BoxDecoration(
                      color: isCellSelected
                          ? Theme.of(context)
                              .colorScheme
                              .primaryContainer
                              .withOpacity(0.5)
                          : null,
                      border: Border(
                        right: BorderSide(
                          color: Theme.of(context)
                              .colorScheme
                              .outline
                              .withOpacity(0.2),
                        ),
                        top: isCellSelected
                            ? BorderSide(
                                color: Theme.of(context).colorScheme.primary,
                                width: 2,
                              )
                            : BorderSide.none,
                        bottom: isCellSelected
                            ? BorderSide(
                                color: Theme.of(context).colorScheme.primary,
                                width: 2,
                              )
                            : BorderSide.none,
                        left: isCellSelected
                            ? BorderSide(
                                color: Theme.of(context).colorScheme.primary,
                                width: 2,
                              )
                            : BorderSide.none,
                      ),
                    ),
                    child: Align(
                      alignment: Alignment.centerLeft,
                      child: _buildHighlightedText(cell),
                    ),
                  ),
                );
              }),
            ],
          ), // closes Row
        ), // closes SizedBox
      ), // closes IntrinsicHeight
    ); // closes Container - ends rowContent assignment

    // Wrap with row drag & drop
    return LongPressDraggable<int>(
      data: originalRowIndex,
      delay: const Duration(milliseconds: 300), // Shorter delay for easier drag
      hapticFeedbackOnStart: true,
      onDragStarted: () {
        setState(() {
          // Row drag started
        });
      },
      onDragEnd: (_) {
        setState(() {
          _dropTargetRowIndex = null;
        });
      },
      feedback: Material(
        elevation: 12,
        borderRadius: BorderRadius.circular(8),
        child: Opacity(
          opacity: 0.9,
          child: Container(
            constraints: const BoxConstraints(minHeight: 48, maxWidth: 800),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.primaryContainer,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color: Theme.of(context).colorScheme.primary,
                width: 2,
              ),
            ),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.drag_indicator,
                    color: Theme.of(context).colorScheme.primary),
                const SizedBox(width: 12),
                Text(
                  'Moving Row #$lineNumber',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: Theme.of(context).colorScheme.onPrimaryContainer,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
      childWhenDragging: Opacity(
        opacity: 0.3,
        child: Container(
          constraints: const BoxConstraints(minHeight: 48),
          color: Theme.of(context)
              .colorScheme
              .surfaceContainerHighest
              .withOpacity(0.3),
        ),
      ),
      child: DragTarget<int>(
        onWillAcceptWithDetails: (details) {
          setState(() {
            _dropTargetRowIndex = originalRowIndex;
          });
          return true;
        },
        onLeave: (_) {
          setState(() {
            _dropTargetRowIndex = null;
          });
        },
        onAcceptWithDetails: (details) {
          final fromIndex = details.data;
          final toIndex = originalRowIndex;
          _reorderRow(fromIndex, toIndex);
          setState(() {
            _dropTargetRowIndex = null;
          });
        },
        builder: (context, candidateData, rejectedData) {
          return rowContent;
        },
      ),
    );
  }
}
