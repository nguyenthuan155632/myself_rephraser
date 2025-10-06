import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:file_picker/file_picker.dart';
import 'dart:io';
import 'dart:convert';
import 'package:csv/csv.dart';
import 'package:desktop_drop/desktop_drop.dart';

// Action types for undo/redo
abstract class UndoableAction {
  void undo();
  void redo();
}

class AddRowAction extends UndoableAction {
  final List<List<String>> data;
  final int index;
  final List<String> row;

  AddRowAction(this.data, this.index, this.row);

  @override
  void undo() {
    data.removeAt(index);
  }

  @override
  void redo() {
    data.insert(index, row);
  }
}

class DeleteRowsAction extends UndoableAction {
  final List<List<String>> data;
  final Map<int, List<String>> deletedRows; // index -> row

  DeleteRowsAction(this.data, this.deletedRows);

  @override
  void undo() {
    // Restore rows in reverse order to maintain indices
    final sortedIndices = deletedRows.keys.toList()..sort();
    for (final index in sortedIndices) {
      data.insert(index, deletedRows[index]!);
    }
  }

  @override
  void redo() {
    // Delete rows in reverse order to maintain indices
    final sortedIndices = deletedRows.keys.toList()
      ..sort((a, b) => b.compareTo(a));
    for (final index in sortedIndices) {
      data.removeAt(index);
    }
  }
}

class EditCellAction extends UndoableAction {
  final List<List<String>> data;
  final int rowIndex;
  final int colIndex;
  final String oldValue;
  final String newValue;

  EditCellAction(
      this.data, this.rowIndex, this.colIndex, this.oldValue, this.newValue);

  @override
  void undo() {
    data[rowIndex][colIndex] = oldValue;
  }

  @override
  void redo() {
    data[rowIndex][colIndex] = newValue;
  }
}

class BulkEditAction extends UndoableAction {
  final List<List<String>> data;
  final Map<String, String> oldValues; // "rowIndex:colIndex" -> old value
  final Map<String, String> newValues; // "rowIndex:colIndex" -> new value

  BulkEditAction(this.data, this.oldValues, this.newValues);

  @override
  void undo() {
    oldValues.forEach((key, value) {
      final parts = key.split(':');
      final rowIndex = int.parse(parts[0]);
      final colIndex = int.parse(parts[1]);
      if (rowIndex < data.length && colIndex < data[rowIndex].length) {
        data[rowIndex][colIndex] = value;
      }
    });
  }

  @override
  void redo() {
    newValues.forEach((key, value) {
      final parts = key.split(':');
      final rowIndex = int.parse(parts[0]);
      final colIndex = int.parse(parts[1]);
      if (rowIndex < data.length && colIndex < data[rowIndex].length) {
        data[rowIndex][colIndex] = value;
      }
    });
  }
}

class AddColumnAction extends UndoableAction {
  final List<List<String>> data;
  final List<String> headers;
  final int columnIndex;
  final String columnName;

  AddColumnAction(this.data, this.headers, this.columnIndex, this.columnName);

  @override
  void undo() {
    headers.removeAt(columnIndex);
    for (var row in data) {
      if (columnIndex < row.length) {
        row.removeAt(columnIndex);
      }
    }
  }

  @override
  void redo() {
    headers.insert(columnIndex, columnName);
    for (var row in data) {
      row.insert(columnIndex, '');
    }
  }
}

class DeleteColumnAction extends UndoableAction {
  final List<List<String>> data;
  final List<String> headers;
  final int columnIndex;
  final String oldColumnName;
  final List<String> oldColumnData; // Values from deleted column

  DeleteColumnAction(this.data, this.headers, this.columnIndex,
      this.oldColumnName, this.oldColumnData);

  @override
  void undo() {
    headers.insert(columnIndex, oldColumnName);
    for (int i = 0; i < data.length; i++) {
      final value = i < oldColumnData.length ? oldColumnData[i] : '';
      data[i].insert(columnIndex, value);
    }
  }

  @override
  void redo() {
    headers.removeAt(columnIndex);
    for (var row in data) {
      if (columnIndex < row.length) {
        row.removeAt(columnIndex);
      }
    }
  }
}

class RenameColumnAction extends UndoableAction {
  final List<String> headers;
  final int columnIndex;
  final String oldName;
  final String newName;

  RenameColumnAction(
      this.headers, this.columnIndex, this.oldName, this.newName);

  @override
  void undo() {
    headers[columnIndex] = oldName;
  }

  @override
  void redo() {
    headers[columnIndex] = newName;
  }
}

class ReorderColumnAction extends UndoableAction {
  final List<List<String>> data;
  final List<String> headers;
  final int oldIndex;
  final int newIndex;

  ReorderColumnAction(this.data, this.headers, this.oldIndex, this.newIndex);

  @override
  void undo() {
    // Move from newIndex back to oldIndex
    final header = headers.removeAt(newIndex);
    headers.insert(oldIndex, header);
    for (var row in data) {
      if (newIndex < row.length) {
        final value = row.removeAt(newIndex);
        row.insert(oldIndex, value);
      }
    }
  }

  @override
  void redo() {
    // Move from oldIndex to newIndex
    final header = headers.removeAt(oldIndex);
    headers.insert(newIndex, header);
    for (var row in data) {
      if (oldIndex < row.length) {
        final value = row.removeAt(oldIndex);
        row.insert(newIndex, value);
      }
    }
  }
}

class ReorderRowAction extends UndoableAction {
  final List<List<String>> data;
  final int oldIndex;
  final int newIndex;

  ReorderRowAction(this.data, this.oldIndex, this.newIndex);

  @override
  void undo() {
    final row = data.removeAt(newIndex);
    data.insert(oldIndex, row);
  }

  @override
  void redo() {
    final row = data.removeAt(oldIndex);
    data.insert(newIndex, row);
  }
}

class MergeRowsAction extends UndoableAction {
  final List<List<String>> data;
  final int targetRowIndex; // Where merged row goes
  final List<int>
      sourceRowIndices; // All original row indices (sorted ascending)
  final List<String> mergedRow;
  final Map<int, List<String>> deletedRows; // Backup of deleted rows

  MergeRowsAction(this.data, this.targetRowIndex, this.sourceRowIndices,
      this.mergedRow, this.deletedRows);

  @override
  void undo() {
    // Restore all rows at their original positions
    // We insert from highest to lowest index to avoid shifting issues
    final sortedDescending = sourceRowIndices.toList()
      ..sort((a, b) => b.compareTo(a));

    for (final index in sortedDescending) {
      if (index == targetRowIndex) {
        // Just replace the merged row with original
        data[targetRowIndex] = List.from(deletedRows[targetRowIndex]!);
      } else {
        // Insert deleted rows back at their original positions
        // Since we're going from high to low, indices don't shift
        data.insert(index, List.from(deletedRows[index]!));
      }
    }
  }

  @override
  void redo() {
    // Delete source rows in descending order to avoid index shifting
    final sortedDescending = sourceRowIndices.toList()
      ..sort((a, b) => b.compareTo(a));
    for (final index in sortedDescending) {
      if (index != targetRowIndex) {
        data.removeAt(index);
      }
    }

    // Set merged content
    data[targetRowIndex] = List.from(mergedRow);
  }
}

class CsvReaderScreen extends StatefulWidget {
  const CsvReaderScreen({super.key});

  @override
  State<CsvReaderScreen> createState() => _CsvReaderScreenState();
}

class _CsvReaderScreenState extends State<CsvReaderScreen> {
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
  int? _draggingColumnIndex;
  int? _draggingRowIndex;
  int? _dropTargetColumnIndex;
  int? _dropTargetRowIndex;

  // Calculate line number column width based on number of rows
  double get _lineNumberColumnWidth {
    if (_totalRows == 0) return 60;
    final digits = _totalRows.toString().length;
    // Base width + extra width per digit
    return 40 + (digits * 10.0);
  }

  bool get _canUndo => _currentActionIndex >= 0;
  bool get _canRedo => _currentActionIndex < _actionHistory.length - 1;

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
      builder: (context) => AlertDialog(
        title: const Text('Select File Encoding'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'The file could not be decoded as UTF-8. Please select the correct encoding:',
              style: TextStyle(fontSize: 14),
            ),
            const SizedBox(height: 16),
            ListTile(
              title: const Text('UTF-8'),
              subtitle: const Text('Modern standard (default)'),
              onTap: () => Navigator.of(context).pop('utf8'),
            ),
            ListTile(
              title: const Text('Latin-1 (ISO-8859-1)'),
              subtitle: const Text('Western European'),
              onTap: () => Navigator.of(context).pop('latin1'),
            ),
            ListTile(
              title: const Text('UTF-8 (Lenient)'),
              subtitle: const Text('UTF-8 that replaces invalid bytes'),
              onTap: () => Navigator.of(context).pop('utf8lenient'),
            ),
            ListTile(
              title: const Text('Windows-1252 (CP1252)'),
              subtitle: const Text('Windows Western European, Excel default'),
              onTap: () => Navigator.of(context).pop('windows1252'),
            ),
            ListTile(
              title: const Text('UTF-16'),
              subtitle: const Text('Unicode with BOM'),
              onTap: () => Navigator.of(context).pop('utf16'),
            ),
            ListTile(
              title: const Text('ASCII'),
              subtitle: const Text('Basic English only'),
              onTap: () => Navigator.of(context).pop('ascii'),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
        ],
      ),
    );
  }

  Encoding _getEncodingFromString(String encodingName) {
    switch (encodingName) {
      case 'utf8':
        return utf8;
      case 'utf8lenient':
        return const Utf8Codec(allowMalformed: true);
      case 'latin1':
        return latin1;
      case 'windows1252':
        // Windows-1252 is similar to Latin-1 but with more characters in 128-159 range
        // For en-dash (–) and em-dash (—), use Latin-1 as closest match
        return latin1;
      case 'utf16':
        return const Utf8Codec(allowMalformed: true);
      case 'ascii':
        return ascii;
      default:
        return utf8;
    }
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

  void _addAction(UndoableAction action) {
    // Remove any actions after current index (when undoing then making new action)
    if (_currentActionIndex < _actionHistory.length - 1) {
      _actionHistory.removeRange(
          _currentActionIndex + 1, _actionHistory.length);
    }
    _actionHistory.add(action);
    _currentActionIndex = _actionHistory.length - 1;
  }

  void _undo() {
    if (_canUndo) {
      setState(() {
        _actionHistory[_currentActionIndex].undo();
        _currentActionIndex--;
        _totalRows = _allCsvData.length;
        _filteredData = List.from(_allCsvData); // Update BEFORE mapping
        _rebuildFilteredIndexMapping(); // Then rebuild mapping
        _selectedRowIndices.clear(); // Clear selection after undo
        _selectedCells.clear(); // Clear cell selection too
        _listKey = UniqueKey(); // Force complete rebuild
        _hasUnsavedChanges = true;
        print(
            'DEBUG: Undo executed. Selections cleared. Total rows now: $_totalRows');
      });
    }
  }

  void _redo() {
    if (_canRedo) {
      setState(() {
        _currentActionIndex++;
        _actionHistory[_currentActionIndex].redo();
        _totalRows = _allCsvData.length;
        _filteredData = List.from(_allCsvData); // Update BEFORE mapping
        _rebuildFilteredIndexMapping(); // Then rebuild mapping
        _selectedRowIndices.clear(); // Clear selection after redo
        _selectedCells.clear(); // Clear cell selection too
        _listKey = UniqueKey(); // Force complete rebuild
        _hasUnsavedChanges = true;
      });
    }
  }

  void _toggleRowSelection(int rowIndex) {
    setState(() {
      if (_selectedRowIndices.contains(rowIndex)) {
        _selectedRowIndices.remove(rowIndex);
        print('DEBUG: Deselected row $rowIndex. Current: $_selectedRowIndices');
      } else {
        _selectedRowIndices.add(rowIndex);
        print('DEBUG: Selected row $rowIndex. Current: $_selectedRowIndices');
      }
    });
  }

  void _addNewRow() {
    final newRow = List<String>.filled(_headers.length, '');
    final action = AddRowAction(_allCsvData, _allCsvData.length, newRow);

    setState(() {
      action.redo();
      _addAction(action);
      _totalRows = _allCsvData.length;
      _filteredData = List.from(_allCsvData);
      _rebuildFilteredIndexMapping();
      _listKey = UniqueKey(); // Force rebuild
      _hasUnsavedChanges = true;
    });
  }

  void _insertRowAfter(int rowIndex) {
    final newRow = List<String>.filled(_headers.length, '');
    final insertIndex = rowIndex + 1;
    final action = AddRowAction(_allCsvData, insertIndex, newRow);

    setState(() {
      action.redo();
      _addAction(action);
      _totalRows = _allCsvData.length;
      _filteredData = List.from(_allCsvData);
      _rebuildFilteredIndexMapping();
      _listKey = UniqueKey(); // Force rebuild
      _hasUnsavedChanges = true;
    });

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Row inserted'),
        duration: Duration(seconds: 1),
      ),
    );
  }

  void _insertRowBefore(int rowIndex) {
    final newRow = List<String>.filled(_headers.length, '');
    final action = AddRowAction(_allCsvData, rowIndex, newRow);

    setState(() {
      action.redo();
      _addAction(action);
      _totalRows = _allCsvData.length;
      _filteredData = List.from(_allCsvData);
      _rebuildFilteredIndexMapping();
      _listKey = UniqueKey(); // Force rebuild
      _hasUnsavedChanges = true;
    });

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Row inserted'),
        duration: Duration(seconds: 1),
      ),
    );
  }

  void _addColumn(
      {int? afterIndex, bool duplicate = false, int? duplicateIndex}) {
    setState(() {
      // Add to headers
      _headers = List<String>.from(_headers);
      String newColumnName;

      if (duplicate && duplicateIndex != null) {
        newColumnName = '${_headers[duplicateIndex]}_copy';
      } else {
        newColumnName = 'Column ${_headers.length + 1}';
      }

      if (afterIndex != null) {
        _headers.insert(afterIndex + 1, newColumnName);
      } else {
        _headers.add(newColumnName);
      }

      // Add to column widths
      if (afterIndex != null && _columnWidths.length > afterIndex + 1) {
        _columnWidths.insert(
            afterIndex + 2, 150.0); // +1 for checkbox, +1 for after
      } else {
        _columnWidths.add(150.0);
      }

      // Add to all data rows
      for (int i = 0; i < _allCsvData.length; i++) {
        var row = List<String>.from(_allCsvData[i]);
        String newValue = '';

        if (duplicate &&
            duplicateIndex != null &&
            duplicateIndex < row.length) {
          newValue = row[duplicateIndex];
        }

        if (afterIndex != null) {
          row.insert(afterIndex + 1, newValue);
        } else {
          row.add(newValue);
        }
        _allCsvData[i] = row;
      }

      _filteredData = List.from(_allCsvData);
      _rebuildFilteredIndexMapping();
      _hasUnsavedChanges = true;
    });

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(duplicate ? 'Column duplicated' : 'Column added'),
        backgroundColor: Colors.green,
        duration: const Duration(seconds: 1),
      ),
    );
  }

  void _deleteColumn(int columnIndex) {
    if (_headers.length <= 1) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Cannot delete the last column'),
          duration: Duration(seconds: 2),
        ),
      );
      return;
    }

    setState(() {
      // Remove from headers
      _headers = List<String>.from(_headers);
      _headers.removeAt(columnIndex);

      // Remove from column widths
      if (_columnWidths.length > columnIndex + 1) {
        _columnWidths.removeAt(columnIndex + 1); // +1 for checkbox column
      }

      // Remove from all data rows
      for (int i = 0; i < _allCsvData.length; i++) {
        var row = List<String>.from(_allCsvData[i]);
        if (columnIndex < row.length) {
          row.removeAt(columnIndex);
        }
        _allCsvData[i] = row;
      }

      _filteredData = List.from(_allCsvData);
      _rebuildFilteredIndexMapping();
      _hasUnsavedChanges = true;
    });

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Column deleted'),
        backgroundColor: Colors.green,
        duration: Duration(seconds: 1),
      ),
    );
  }

  void _renameColumn(int columnIndex, String currentName) {
    showDialog(
      context: context,
      builder: (context) => _RenameColumnDialog(
        currentName: currentName,
        onSave: (newName) {
          if (newName == currentName) return; // No change

          final action =
              RenameColumnAction(_headers, columnIndex, currentName, newName);

          setState(() {
            _headers = List<String>.from(_headers);
            action.redo();
            _addAction(action);
            _hasUnsavedChanges = true;
          });

          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Column renamed'),
              backgroundColor: Colors.green,
              duration: Duration(seconds: 1),
            ),
          );
        },
      ),
    );
  }

  void _reorderColumn(int oldIndex, int newIndex) {
    if (oldIndex == newIndex) return;

    final action =
        ReorderColumnAction(_allCsvData, _headers, oldIndex, newIndex);

    setState(() {
      // Reorder headers
      _headers = List<String>.from(_headers);

      // Reorder column widths (remember index 0 is checkbox, index 1 is line number)
      if (_columnWidths.length > oldIndex + 1) {
        final width = _columnWidths.removeAt(oldIndex + 1);
        _columnWidths.insert(newIndex + 1, width);
      }

      action.redo();
      _addAction(action);
      _filteredData = List.from(_allCsvData);
      _rebuildFilteredIndexMapping();
      _hasUnsavedChanges = true;
    });
  }

  void _reorderRow(int oldIndex, int newIndex) {
    if (oldIndex == newIndex) return;

    final action = ReorderRowAction(_allCsvData, oldIndex, newIndex);

    setState(() {
      action.redo();
      _addAction(action);
      _filteredData = List.from(_allCsvData);
      _rebuildFilteredIndexMapping();
      _hasUnsavedChanges = true;
    });
  }

  void _deleteSelectedRows() {
    if (_selectedRowIndices.isEmpty) return;

    final Map<int, List<String>> deletedRows = {};
    for (final index in _selectedRowIndices) {
      deletedRows[index] = List.from(_allCsvData[index]);
    }

    final action = DeleteRowsAction(_allCsvData, deletedRows);

    setState(() {
      action.redo();
      _addAction(action);
      _selectedRowIndices.clear();
      _totalRows = _allCsvData.length;
      _filteredData = List.from(_allCsvData); // Update BEFORE mapping
      _rebuildFilteredIndexMapping(); // Then rebuild mapping
      _listKey = UniqueKey(); // Force rebuild after delete
      _hasUnsavedChanges = true;
      print(
          'DEBUG: Deleted rows. Selections cleared. Total rows now: $_totalRows');
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
      builder: (context) => _MergeRowsDialog(
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

  void _deleteEmptyRows() {
    final Map<int, List<String>> emptyRows = {};

    // Find all empty rows (all cells are empty or whitespace)
    for (int i = 0; i < _allCsvData.length; i++) {
      final row = _allCsvData[i];
      if (row.every((cell) => cell.trim().isEmpty)) {
        emptyRows[i] = List.from(row);
      }
    }

    if (emptyRows.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('No empty rows found'),
          duration: Duration(seconds: 2),
        ),
      );
      return;
    }

    final action = DeleteRowsAction(_allCsvData, emptyRows);

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
        content: Text('Deleted ${emptyRows.length} empty row(s)'),
        backgroundColor: Colors.green,
        duration: const Duration(seconds: 2),
      ),
    );
  }

  void _removeDuplicateRows() {
    final Map<int, List<String>> duplicateRows = {};
    final Set<String> seenRows = {};

    // Find all duplicate rows
    for (int i = 0; i < _allCsvData.length; i++) {
      final row = _allCsvData[i];
      // Create a signature for the row by joining all cells
      final rowSignature = row.join('|');

      if (seenRows.contains(rowSignature)) {
        // This is a duplicate
        duplicateRows[i] = List.from(row);
      } else {
        seenRows.add(rowSignature);
      }
    }

    if (duplicateRows.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('No duplicate rows found'),
          duration: Duration(seconds: 2),
        ),
      );
      return;
    }

    final action = DeleteRowsAction(_allCsvData, duplicateRows);

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
        content: Text('Deleted ${duplicateRows.length} duplicate row(s)'),
        backgroundColor: Colors.green,
        duration: const Duration(seconds: 2),
      ),
    );
  }

  void _deleteEmptyColumns() {
    if (_headers.isEmpty) return;

    final List<int> emptyColumnIndices = [];

    // Check each column
    for (int colIndex = 0; colIndex < _headers.length; colIndex++) {
      // Skip if header is not empty - only delete columns with empty headers
      if (_headers[colIndex].trim().isNotEmpty) {
        continue;
      }

      // Check if all cells in this column are empty
      bool isEmpty = true;

      for (var row in _allCsvData) {
        if (colIndex < row.length && row[colIndex].trim().isNotEmpty) {
          isEmpty = false;
          break;
        }
      }

      if (isEmpty) {
        emptyColumnIndices.add(colIndex);
        print(
            'Found empty column at index $colIndex (empty header and all cells empty)');
      }
    }

    if (emptyColumnIndices.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('No empty columns found'),
          duration: Duration(seconds: 2),
        ),
      );
      return;
    }

    // Remove columns in reverse order to maintain indices
    setState(() {
      // Convert headers to growable list and remove columns
      _headers = List<String>.from(_headers);
      for (int i = emptyColumnIndices.length - 1; i >= 0; i--) {
        final colIndex = emptyColumnIndices[i];
        _headers.removeAt(colIndex);

        // Remove from column widths
        if (_columnWidths.length > colIndex + 1) {
          _columnWidths.removeAt(colIndex + 1); // +1 for checkbox column
        }
      }

      // Convert all data rows to growable lists and remove columns
      for (int rowIdx = 0; rowIdx < _allCsvData.length; rowIdx++) {
        var row = List<String>.from(_allCsvData[rowIdx]);
        for (int i = emptyColumnIndices.length - 1; i >= 0; i--) {
          final colIndex = emptyColumnIndices[i];
          if (colIndex < row.length) {
            row.removeAt(colIndex);
          }
        }
        _allCsvData[rowIdx] = row;
      }

      _filteredData = List.from(_allCsvData);
      _rebuildFilteredIndexMapping();
      _hasUnsavedChanges = true;
    });

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Deleted ${emptyColumnIndices.length} empty column(s)'),
        backgroundColor: Colors.green,
        duration: const Duration(seconds: 2),
      ),
    );
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
      builder: (context) => _BulkEditDialog(
        initialValue: initialValue,
        cellCount: _selectedCells.length,
        onSave: (newValue) {
          final Map<String, String> oldValues = {};
          final Map<String, String> newValues = {};

          for (final cellKey in _selectedCells) {
            final parts = cellKey.split(':');
            final r = int.parse(parts[0]);
            final c = int.parse(parts[1]);

            if (r < _allCsvData.length && c < _allCsvData[r].length) {
              oldValues[cellKey] = _allCsvData[r][c];
              newValues[cellKey] = newValue;
            }
          }

          if (oldValues.isNotEmpty) {
            final action = BulkEditAction(_allCsvData, oldValues, newValues);
            setState(() {
              action.redo();
              _addAction(action);
              _hasUnsavedChanges = true;
              _selectedCells.clear(); // Clear selection after edit
            });
          }
        },
      ),
    );
  }

  void _startEditing(int rowIndex, int colIndex, String currentValue) {
    showDialog(
      context: context,
      builder: (context) => _EditCellDialog(
        initialValue: currentValue,
        columnName: _headers.isNotEmpty && colIndex < _headers.length
            ? _headers[colIndex]
            : 'Column ${colIndex + 1}',
        onSave: (newValue) {
          final row = _filteredData[rowIndex];
          final originalRowIndex = _allCsvData.indexOf(row);

          if (originalRowIndex != -1) {
            final oldValue = _allCsvData[originalRowIndex][colIndex];

            // Only create action if value actually changed
            if (oldValue != newValue) {
              final action = EditCellAction(
                _allCsvData,
                originalRowIndex,
                colIndex,
                oldValue,
                newValue,
              );

              setState(() {
                action.redo();
                _addAction(action);
                _filteredData[rowIndex][colIndex] = newValue;
                _hasUnsavedChanges = true;
              });
            }
          }
        },
      ),
    );
  }

  Future<void> _saveToFile() async {
    if (!_hasUnsavedChanges || _currentFile == null) return;

    try {
      // Create CSV content
      final csvContent = StringBuffer();

      // Write header
      csvContent.writeln(_headers.join(','));

      // Write data rows
      for (var row in _allCsvData) {
        // Escape cells that contain commas or quotes
        final escapedRow = row.map((cell) {
          if (cell.contains(',') || cell.contains('"') || cell.contains('\n')) {
            return '"${cell.replaceAll('"', '""')}"';
          }
          return cell;
        }).join(',');
        csvContent.writeln(escapedRow);
      }

      // Write to file
      await _currentFile!.writeAsString(csvContent.toString());

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
      // Clear undo/redo history when reloading with different encoding
      _actionHistory.clear();
      _currentActionIndex = -1;
      // Clear unsaved changes flag and selections
      _hasUnsavedChanges = false;
      _selectedRowIndices.clear();
      _selectedCells.clear();
    });

    final selectedEncoding = _getEncodingFromString(encodingName);
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
          // Clear undo/redo history when opening a new file
          _actionHistory.clear();
          _currentActionIndex = -1;
          // Clear unsaved changes flag and selections
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
      // Read file with specified encoding or show dialog to choose
      final bytes = await file.readAsBytes();
      String input;

      if (encoding != null) {
        input = encoding.decode(bytes);
      } else {
        // Try UTF-8 first with malformed byte handling
        try {
          input = const Utf8Decoder(allowMalformed: false).convert(bytes);
        } catch (e) {
          // If strict UTF-8 fails, try lenient UTF-8
          try {
            input = const Utf8Decoder(allowMalformed: true).convert(bytes);
            // Show a warning that some characters might be replaced
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text(
                      'File contains non-UTF-8 characters. Some characters may display incorrectly. Select encoding if needed.'),
                  duration: Duration(seconds: 4),
                  backgroundColor: Colors.orange,
                ),
              );
            }
          } catch (e2) {
            // If UTF-8 completely fails, ask user to choose encoding
            if (mounted) {
              final encodingName = await _showEncodingDialog();
              if (encodingName == null) {
                setState(() {
                  _isLoading = false;
                });
                return;
              }
              final selectedEncoding = _getEncodingFromString(encodingName);
              input = selectedEncoding.decode(bytes);
            } else {
              return;
            }
          }
        }
      }

      // Use the CSV package for proper parsing
      const csvConverter = CsvToListConverter(
        eol: '\n',
        shouldParseNumbers: false, // Keep everything as strings
      );

      final rows = csvConverter.convert(input);

      if (rows.isEmpty) return;

      // Convert all rows to List<String>
      final allRows = rows
          .map((row) => row.map((cell) => cell?.toString() ?? '').toList())
          .toList();

      // Extract header
      _headers = allRows.first;

      // Extract data rows and pad/truncate to match header length
      final allData = <List<String>>[];
      for (int i = 1; i < allRows.length; i++) {
        final row = allRows[i];
        // Ensure row has exactly the same number of columns as headers
        final paddedRow = List<String>.filled(_headers.length, '');
        for (int j = 0; j < _headers.length && j < row.length; j++) {
          paddedRow[j] = row[j];
        }
        allData.add(paddedRow);
      }

      if (mounted) {
        setState(() {
          _currentFile = file; // Store file reference for saving
          _fileName = file.path.split('/').last; // Store filename
          _allCsvData = allData;
          _filteredData = allData;
          _totalRows = allData.length;
          _rebuildFilteredIndexMapping(); // Build cache for O(1) lookups
          _initializeColumnWidths();
          _isLoading = false;
        });
      }
    } catch (e) {
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

  void _rebuildFilteredIndexMapping() {
    _filteredIndexToOriginalIndex.clear();
    if (_filteredData.isEmpty) return;

    int unmappedCount = 0;
    // Build mapping from filtered index to original index
    for (int filteredIdx = 0;
        filteredIdx < _filteredData.length;
        filteredIdx++) {
      final row = _filteredData[filteredIdx];
      // Find this row's index in _allCsvData using identity check
      bool found = false;
      for (int originalIdx = 0;
          originalIdx < _allCsvData.length;
          originalIdx++) {
        if (identical(row, _allCsvData[originalIdx])) {
          _filteredIndexToOriginalIndex[filteredIdx] = originalIdx;
          found = true;
          break;
        }
      }
      if (!found) {
        unmappedCount++;
        print(
            'DEBUG MAPPING: filteredIdx=$filteredIdx NOT FOUND in _allCsvData!');
      }
    }
    if (unmappedCount > 0) {
      print('DEBUG MAPPING: $unmappedCount rows could not be mapped!');
    }
    print('DEBUG MAPPING: Built mapping for ${_filteredData.length} rows');
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
            // Clear undo/redo history when opening a new file
            setState(() {
              _actionHistory.clear();
              _currentActionIndex = -1;
              // Clear unsaved changes flag and selections
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
                  if (_allCsvData.isNotEmpty) ...[
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
                  if (_allCsvData.isNotEmpty)
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
                                                  decoration: BoxDecoration(
                                                    color: const Color(
                                                        0xFFF8F8F8), // Light gray header like Easy CSV Editor
                                                    border: Border(
                                                      bottom: BorderSide(
                                                        color: const Color(
                                                            0xFFDDDDDD), // Slightly darker border
                                                        width: 1,
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
              floatingActionButton: _allCsvData.isEmpty
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
          _draggingColumnIndex = dataColumnIndex;
        });
      },
      onDragEnd: (_) {
        setState(() {
          _draggingColumnIndex = null;
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

  // Helper to build highlighted text
  Widget _buildHighlightedText(String text) {
    if (_searchQuery.isEmpty || text.isEmpty) {
      return Text(
        text,
        softWrap: true,
        style: const TextStyle(fontSize: 14),
      );
    }

    try {
      List<TextSpan> spans = [];
      String searchPattern = _searchQuery;
      String textToSearch = text;

      if (!_caseSensitive) {
        searchPattern = searchPattern.toLowerCase();
        textToSearch = textToSearch.toLowerCase();
      }

      int lastMatchEnd = 0;

      if (_useRegex) {
        final regex = RegExp(searchPattern, caseSensitive: _caseSensitive);
        for (final match in regex.allMatches(textToSearch)) {
          if (match.start > lastMatchEnd) {
            spans
                .add(TextSpan(text: text.substring(lastMatchEnd, match.start)));
          }
          spans.add(TextSpan(
            text: text.substring(match.start, match.end),
            style: TextStyle(
              backgroundColor: Theme.of(context).colorScheme.secondaryContainer,
              fontWeight: FontWeight.bold,
              color: Theme.of(context).colorScheme.onSecondaryContainer,
            ),
          ));
          lastMatchEnd = match.end;
        }
      } else {
        int startIndex = 0;
        while (true) {
          final index = textToSearch.indexOf(searchPattern, startIndex);
          if (index == -1) break;

          if (index > lastMatchEnd) {
            spans.add(TextSpan(text: text.substring(lastMatchEnd, index)));
          }
          spans.add(TextSpan(
            text: text.substring(index, index + _searchQuery.length),
            style: TextStyle(
              backgroundColor: Theme.of(context).colorScheme.secondaryContainer,
              fontWeight: FontWeight.bold,
              color: Theme.of(context).colorScheme.onSecondaryContainer,
            ),
          ));
          lastMatchEnd = index + _searchQuery.length;
          startIndex = lastMatchEnd;
        }
      }

      if (lastMatchEnd < text.length) {
        spans.add(TextSpan(text: text.substring(lastMatchEnd)));
      }

      return RichText(
        text: TextSpan(
          style: const TextStyle(fontSize: 14, color: Colors.black87),
          children: spans.isEmpty ? [TextSpan(text: text)] : spans,
        ),
      );
    } catch (e) {
      return Text(
        text,
        softWrap: true,
        style: const TextStyle(fontSize: 14),
      );
    }
  }

  Widget _buildDataRow(int lineNumber, List<String> row, int filteredIndex) {
    final rowIndex = filteredIndex; // Use passed index in filtered data
    // lineNumber is already calculated from originalIndex, so convert back
    final originalRowIndex = lineNumber - 1;
    final isSelected = _selectedRowIndices.contains(originalRowIndex);
    final isDropTarget = _dropTargetRowIndex == originalRowIndex;

    // Debug: Print SELECTED rows
    if (isSelected) {
      final firstCell = row.isNotEmpty ? row[0] : 'EMPTY';
      print(
          'DEBUG BUILD SELECTED: filteredIndex=$filteredIndex, lineNumber=$lineNumber, originalRowIndex=$originalRowIndex, isSelected=TRUE, mapping=${_filteredIndexToOriginalIndex[filteredIndex]}, firstCell="$firstCell"');
    }

    // Debug: Print every 10th row to avoid spam
    if (originalRowIndex % 10 == 0) {
      print(
          'DEBUG BUILD: Row $originalRowIndex, isSelected=$isSelected, _selectedRowIndices=$_selectedRowIndices');
    }

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
                          print(
                              'DEBUG: Checkbox $originalRowIndex clicked. isSelected=$isSelected, new value=$value');
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
          _draggingRowIndex = originalRowIndex;
        });
      },
      onDragEnd: (_) {
        setState(() {
          _draggingRowIndex = null;
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

// Dialog for editing cell content with multi-line support
class _EditCellDialog extends StatefulWidget {
  final String initialValue;
  final String columnName;
  final Function(String) onSave;

  const _EditCellDialog({
    required this.initialValue,
    required this.columnName,
    required this.onSave,
  });

  @override
  State<_EditCellDialog> createState() => _EditCellDialogState();
}

class _EditCellDialogState extends State<_EditCellDialog> {
  late final TextEditingController _controller;
  late final FocusNode _focusNode;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.initialValue);
    _focusNode = FocusNode();
    // Auto-focus after dialog opens
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _focusNode.requestFocus();
      _controller.selection = TextSelection(
        baseOffset: 0,
        extentOffset: _controller.text.length,
      );
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  void _save() {
    widget.onSave(_controller.text);
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      child: Container(
        width: 600,
        constraints: const BoxConstraints(maxHeight: 500),
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Row(
              children: [
                Icon(
                  Icons.edit,
                  color: Theme.of(context).colorScheme.primary,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'Edit: ${widget.columnName}',
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: () => Navigator.of(context).pop(),
                ),
              ],
            ),
            const SizedBox(height: 16),
            const Divider(),
            const SizedBox(height: 16),
            // Multi-line text field
            Expanded(
              child: TextField(
                controller: _controller,
                focusNode: _focusNode,
                maxLines: null,
                expands: true,
                textAlignVertical: TextAlignVertical.top,
                style: const TextStyle(fontSize: 16),
                decoration: InputDecoration(
                  hintText: 'Enter cell content...',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                  filled: true,
                  fillColor: Theme.of(context)
                      .colorScheme
                      .surfaceContainerHighest
                      .withOpacity(0.3),
                  contentPadding: const EdgeInsets.all(16),
                ),
              ),
            ),
            const SizedBox(height: 16),
            // Character count
            Text(
              '${_controller.text.length} characters',
              style: Theme.of(context).textTheme.bodySmall,
            ),
            const SizedBox(height: 16),
            // Action buttons
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text('Cancel'),
                ),
                const SizedBox(width: 8),
                FilledButton.icon(
                  onPressed: _save,
                  icon: const Icon(Icons.check),
                  label: const Text('Save'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

// Dialog for renaming column headers
class _RenameColumnDialog extends StatefulWidget {
  final String currentName;
  final Function(String) onSave;

  const _RenameColumnDialog({
    required this.currentName,
    required this.onSave,
  });

  @override
  State<_RenameColumnDialog> createState() => _RenameColumnDialogState();
}

class _RenameColumnDialogState extends State<_RenameColumnDialog> {
  late TextEditingController _controller;
  late FocusNode _focusNode;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.currentName);
    _focusNode = FocusNode();

    // Auto-select all text when dialog opens
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _focusNode.requestFocus();
      _controller.selection = TextSelection(
        baseOffset: 0,
        extentOffset: _controller.text.length,
      );
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  void _save() {
    final newName = _controller.text.trim();
    if (newName.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Column name cannot be empty'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    Navigator.of(context).pop();
    widget.onSave(newName);
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      child: Container(
        width: 400,
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Title
            const Row(
              children: [
                Icon(Icons.edit),
                SizedBox(width: 8),
                Text(
                  'Rename Column',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            // Text field
            TextField(
              controller: _controller,
              focusNode: _focusNode,
              autofocus: true,
              decoration: InputDecoration(
                labelText: 'Column Name',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
                filled: true,
              ),
              onSubmitted: (_) => _save(),
            ),
            const SizedBox(height: 24),
            // Buttons
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text('Cancel'),
                ),
                const SizedBox(width: 8),
                FilledButton(
                  onPressed: _save,
                  child: const Text('Save'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

// Bulk Edit Dialog
class _BulkEditDialog extends StatefulWidget {
  final String initialValue;
  final int cellCount;
  final Function(String) onSave;

  const _BulkEditDialog({
    required this.initialValue,
    required this.cellCount,
    required this.onSave,
  });

  @override
  State<_BulkEditDialog> createState() => _BulkEditDialogState();
}

class _BulkEditDialogState extends State<_BulkEditDialog> {
  late TextEditingController _controller;
  late FocusNode _focusNode;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.initialValue);
    _focusNode = FocusNode();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _focusNode.requestFocus();
      _controller.selection = TextSelection(
        baseOffset: 0,
        extentOffset: _controller.text.length,
      );
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  void _save() {
    Navigator.of(context).pop();
    widget.onSave(_controller.text);
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      child: Container(
        width: 600,
        constraints: const BoxConstraints(maxHeight: 500),
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.edit_note,
                    color: Theme.of(context).colorScheme.primary, size: 28),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Bulk Edit Cells',
                          style: Theme.of(context)
                              .textTheme
                              .titleLarge
                              ?.copyWith(fontWeight: FontWeight.bold)),
                      Text('Editing ${widget.cellCount} cells',
                          style: Theme.of(context)
                              .textTheme
                              .bodyMedium
                              ?.copyWith(
                                  color: Theme.of(context)
                                      .colorScheme
                                      .onSurface
                                      .withOpacity(0.6))),
                    ],
                  ),
                ),
                IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () => Navigator.of(context).pop()),
              ],
            ),
            const SizedBox(height: 24),
            Expanded(
              child: TextField(
                controller: _controller,
                focusNode: _focusNode,
                maxLines: null,
                expands: true,
                textAlignVertical: TextAlignVertical.top,
                decoration: InputDecoration(
                  hintText: 'Enter new value for all selected cells...',
                  border: const OutlineInputBorder(),
                  filled: true,
                  fillColor:
                      Theme.of(context).colorScheme.surface.withOpacity(0.5),
                ),
                style: const TextStyle(fontSize: 14),
              ),
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Theme.of(context)
                    .colorScheme
                    .primaryContainer
                    .withOpacity(0.3),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                    color:
                        Theme.of(context).colorScheme.primary.withOpacity(0.3)),
              ),
              child: Row(
                children: [
                  Icon(Icons.info_outline,
                      size: 20, color: Theme.of(context).colorScheme.primary),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                        'This will replace the content of all ${widget.cellCount} selected cells with the value above.',
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: Theme.of(context)
                                .colorScheme
                                .onSurface
                                .withOpacity(0.8))),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton(
                    onPressed: () => Navigator.of(context).pop(),
                    child: const Text('Cancel')),
                const SizedBox(width: 8),
                ElevatedButton.icon(
                  onPressed: _save,
                  icon: const Icon(Icons.check),
                  label: const Text('Apply to All'),
                  style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 24, vertical: 12)),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

// Merge Rows Dialog
class _MergeRowsDialog extends StatefulWidget {
  final int selectedCount;
  final Function(String separator, bool keepFirst) onMerge;

  const _MergeRowsDialog({
    required this.selectedCount,
    required this.onMerge,
  });

  @override
  State<_MergeRowsDialog> createState() => _MergeRowsDialogState();
}

class _MergeRowsDialogState extends State<_MergeRowsDialog> {
  String _separator = ', ';
  bool _keepFirst = true;

  @override
  Widget build(BuildContext context) {
    return Dialog(
      child: Container(
        width: 500,
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.merge,
                    color: Theme.of(context).colorScheme.primary, size: 28),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Merge Rows',
                          style: Theme.of(context)
                              .textTheme
                              .titleLarge
                              ?.copyWith(fontWeight: FontWeight.bold)),
                      Text('Merging ${widget.selectedCount} rows',
                          style: Theme.of(context)
                              .textTheme
                              .bodyMedium
                              ?.copyWith(
                                  color: Theme.of(context)
                                      .colorScheme
                                      .onSurface
                                      .withOpacity(0.6))),
                    ],
                  ),
                ),
                IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () => Navigator.of(context).pop()),
              ],
            ),
            const SizedBox(height: 24),
            Text('Separator', style: Theme.of(context).textTheme.titleSmall),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: TextEditingController(text: _separator),
                    decoration: const InputDecoration(
                      border: OutlineInputBorder(),
                      hintText: 'Enter separator...',
                    ),
                    onChanged: (value) => setState(() => _separator = value),
                  ),
                ),
                const SizedBox(width: 8),
                ...['  ', ', ', ' | ', ' / ', '\n'].map((sep) => Padding(
                      padding: const EdgeInsets.only(left: 4),
                      child: OutlinedButton(
                        onPressed: () => setState(() => _separator = sep),
                        child: Text(sep == '\n' ? '\\n' : '"$sep"',
                            style: const TextStyle(fontFamily: 'monospace')),
                      ),
                    )),
              ],
            ),
            const SizedBox(height: 16),
            Text('Target Row Position',
                style: Theme.of(context).textTheme.titleSmall),
            const SizedBox(height: 8),
            SegmentedButton<bool>(
              segments: const [
                ButtonSegment(
                    value: true,
                    label: Text('Keep First Row'),
                    icon: Icon(Icons.arrow_upward)),
                ButtonSegment(
                    value: false,
                    label: Text('Keep Last Row'),
                    icon: Icon(Icons.arrow_downward)),
              ],
              selected: {_keepFirst},
              onSelectionChanged: (Set<bool> selection) {
                setState(() => _keepFirst = selection.first);
              },
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Theme.of(context)
                    .colorScheme
                    .secondaryContainer
                    .withOpacity(0.3),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(Icons.info_outline,
                          size: 20,
                          color: Theme.of(context).colorScheme.secondary),
                      const SizedBox(width: 8),
                      Text('How it works:',
                          style: Theme.of(context).textTheme.titleSmall),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                      '• Each column will combine values from all selected rows',
                      style: Theme.of(context).textTheme.bodySmall),
                  Text('• Empty cells are skipped',
                      style: Theme.of(context).textTheme.bodySmall),
                  Text('• Values are joined with your chosen separator',
                      style: Theme.of(context).textTheme.bodySmall),
                  Text('• Other rows will be deleted',
                      style: Theme.of(context).textTheme.bodySmall),
                ],
              ),
            ),
            const SizedBox(height: 24),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton(
                    onPressed: () => Navigator.of(context).pop(),
                    child: const Text('Cancel')),
                const SizedBox(width: 8),
                ElevatedButton.icon(
                  onPressed: () {
                    Navigator.of(context).pop();
                    widget.onMerge(_separator, _keepFirst);
                  },
                  icon: const Icon(Icons.merge),
                  label: const Text('Merge Rows'),
                  style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 24, vertical: 12)),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
