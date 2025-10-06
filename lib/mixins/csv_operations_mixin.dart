import 'package:flutter/material.dart';
import '../models/csv_undoable_actions.dart';

/// Mixin for CSV row and column operations
mixin CsvOperationsMixin<T extends StatefulWidget> on State<T> {
  // These getters must be implemented by the widget state
  List<List<String>> get csvData;
  List<String> get headers;
  List<UndoableAction> get actionHistory;
  int get currentActionIndex;

  set csvData(List<List<String>> value);
  set headers(List<String> value);
  set currentActionIndex(int value);

  void addAction(UndoableAction action);
  void rebuildFilteredData();
  void markUnsavedChanges();

  /// Add a new row at the end
  void addNewRow() {
    final newRow = List<String>.filled(headers.length, '');
    final action = AddRowAction(csvData, csvData.length, newRow);

    setState(() {
      action.redo();
      addAction(action);
      rebuildFilteredData();
      markUnsavedChanges();
    });
  }

  /// Insert a row after the specified index
  void insertRowAfter(int rowIndex) {
    final newRow = List<String>.filled(headers.length, '');
    final insertIndex = rowIndex + 1;
    final action = AddRowAction(csvData, insertIndex, newRow);

    setState(() {
      action.redo();
      addAction(action);
      rebuildFilteredData();
      markUnsavedChanges();
    });

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Row inserted'),
        duration: Duration(seconds: 1),
      ),
    );
  }

  /// Insert a row before the specified index
  void insertRowBefore(int rowIndex) {
    final newRow = List<String>.filled(headers.length, '');
    final action = AddRowAction(csvData, rowIndex, newRow);

    setState(() {
      action.redo();
      addAction(action);
      rebuildFilteredData();
      markUnsavedChanges();
    });

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Row inserted'),
        duration: Duration(seconds: 1),
      ),
    );
  }

  /// Delete multiple rows by indices
  void deleteRows(Set<int> rowIndices) {
    if (rowIndices.isEmpty) return;

    final Map<int, List<String>> deletedRows = {};
    for (final index in rowIndices) {
      deletedRows[index] = List.from(csvData[index]);
    }

    final action = DeleteRowsAction(csvData, deletedRows);

    setState(() {
      action.redo();
      addAction(action);
      rebuildFilteredData();
      markUnsavedChanges();
    });
  }

  /// Delete empty rows (all cells are whitespace or empty)
  void deleteEmptyRows() {
    final Map<int, List<String>> emptyRows = {};

    for (int i = 0; i < csvData.length; i++) {
      final row = csvData[i];
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

    final action = DeleteRowsAction(csvData, emptyRows);

    setState(() {
      action.redo();
      addAction(action);
      rebuildFilteredData();
      markUnsavedChanges();
    });

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Deleted ${emptyRows.length} empty row(s)'),
        backgroundColor: Colors.green,
        duration: const Duration(seconds: 2),
      ),
    );
  }

  /// Remove duplicate rows
  void removeDuplicateRows() {
    final Map<int, List<String>> duplicateRows = {};
    final Set<String> seenRows = {};

    for (int i = 0; i < csvData.length; i++) {
      final row = csvData[i];
      final rowSignature = row.join('|');

      if (seenRows.contains(rowSignature)) {
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

    final action = DeleteRowsAction(csvData, duplicateRows);

    setState(() {
      action.redo();
      addAction(action);
      rebuildFilteredData();
      markUnsavedChanges();
    });

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Deleted ${duplicateRows.length} duplicate row(s)'),
        backgroundColor: Colors.green,
        duration: const Duration(seconds: 2),
      ),
    );
  }

  /// Add a new column
  void addColumn(
      {int? afterIndex, bool duplicate = false, int? duplicateIndex}) {
    setState(() {
      headers = List<String>.from(headers);
      String newColumnName;

      if (duplicate && duplicateIndex != null) {
        newColumnName = '${headers[duplicateIndex]}_copy';
      } else {
        newColumnName = 'Column ${headers.length + 1}';
      }

      if (afterIndex != null) {
        headers.insert(afterIndex + 1, newColumnName);
      } else {
        headers.add(newColumnName);
      }

      for (int i = 0; i < csvData.length; i++) {
        var row = List<String>.from(csvData[i]);
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
        csvData[i] = row;
      }

      rebuildFilteredData();
      markUnsavedChanges();
    });

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(duplicate ? 'Column duplicated' : 'Column added'),
        backgroundColor: Colors.green,
        duration: const Duration(seconds: 1),
      ),
    );
  }

  /// Delete a column by index
  void deleteColumn(int columnIndex) {
    if (headers.length <= 1) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Cannot delete the last column'),
          duration: Duration(seconds: 2),
        ),
      );
      return;
    }

    setState(() {
      headers = List<String>.from(headers);
      headers.removeAt(columnIndex);

      for (int i = 0; i < csvData.length; i++) {
        var row = List<String>.from(csvData[i]);
        if (columnIndex < row.length) {
          row.removeAt(columnIndex);
        }
        csvData[i] = row;
      }

      rebuildFilteredData();
      markUnsavedChanges();
    });

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Column deleted'),
        backgroundColor: Colors.green,
        duration: Duration(seconds: 1),
      ),
    );
  }

  /// Delete empty columns (empty header and all cells empty)
  void deleteEmptyColumns() {
    if (headers.isEmpty) return;

    final List<int> emptyColumnIndices = [];

    for (int colIndex = 0; colIndex < headers.length; colIndex++) {
      if (headers[colIndex].trim().isNotEmpty) {
        continue;
      }

      bool isEmpty = true;
      for (var row in csvData) {
        if (colIndex < row.length && row[colIndex].trim().isNotEmpty) {
          isEmpty = false;
          break;
        }
      }

      if (isEmpty) {
        emptyColumnIndices.add(colIndex);
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

    setState(() {
      headers = List<String>.from(headers);
      for (int i = emptyColumnIndices.length - 1; i >= 0; i--) {
        final colIndex = emptyColumnIndices[i];
        headers.removeAt(colIndex);
      }

      for (int rowIdx = 0; rowIdx < csvData.length; rowIdx++) {
        var row = List<String>.from(csvData[rowIdx]);
        for (int i = emptyColumnIndices.length - 1; i >= 0; i--) {
          final colIndex = emptyColumnIndices[i];
          if (colIndex < row.length) {
            row.removeAt(colIndex);
          }
        }
        csvData[rowIdx] = row;
      }

      rebuildFilteredData();
      markUnsavedChanges();
    });

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Deleted ${emptyColumnIndices.length} empty column(s)'),
        backgroundColor: Colors.green,
        duration: const Duration(seconds: 2),
      ),
    );
  }

  /// Rename a column
  void renameColumn(int columnIndex, String newName) {
    if (newName == headers[columnIndex]) return;

    setState(() {
      headers = List<String>.from(headers);
      final action = RenameColumnAction(
          headers, columnIndex, headers[columnIndex], newName);
      action.redo();
      addAction(action);
      rebuildFilteredData();
      markUnsavedChanges();
    });

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Column renamed'),
        backgroundColor: Colors.green,
        duration: Duration(seconds: 1),
      ),
    );
  }

  /// Reorder a column
  void reorderColumn(int oldIndex, int newIndex) {
    if (oldIndex == newIndex) return;

    final action = ReorderColumnAction(csvData, headers, oldIndex, newIndex);

    setState(() {
      headers = List<String>.from(headers);
      action.redo();
      addAction(action);
      rebuildFilteredData();
      markUnsavedChanges();
    });
  }

  /// Reorder a row
  void reorderRow(int oldIndex, int newIndex) {
    if (oldIndex == newIndex) return;

    final action = ReorderRowAction(csvData, oldIndex, newIndex);

    setState(() {
      action.redo();
      addAction(action);
      rebuildFilteredData();
      markUnsavedChanges();
    });
  }

  /// Edit a single cell
  void editCell(int rowIndex, int colIndex, String newValue) {
    if (rowIndex >= csvData.length || colIndex >= csvData[rowIndex].length) {
      return;
    }

    final oldValue = csvData[rowIndex][colIndex];
    if (oldValue == newValue) return;

    final action =
        EditCellAction(csvData, rowIndex, colIndex, oldValue, newValue);

    setState(() {
      action.redo();
      addAction(action);
      markUnsavedChanges();
    });
  }

  /// Bulk edit multiple cells
  void bulkEditCells(Set<String> cellKeys, String newValue) {
    final Map<String, String> oldValues = {};
    final Map<String, String> newValues = {};

    for (final cellKey in cellKeys) {
      final parts = cellKey.split(':');
      final r = int.parse(parts[0]);
      final c = int.parse(parts[1]);

      if (r < csvData.length && c < csvData[r].length) {
        oldValues[cellKey] = csvData[r][c];
        newValues[cellKey] = newValue;
      }
    }

    if (oldValues.isEmpty) return;

    final action = BulkEditAction(csvData, oldValues, newValues);

    setState(() {
      action.redo();
      addAction(action);
      markUnsavedChanges();
    });
  }
}
