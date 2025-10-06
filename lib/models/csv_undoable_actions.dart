// Undoable action classes for CSV operations
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

class SplitCellsAction extends UndoableAction {
  final List<List<String>> data;
  final List<String> headers;
  final List<List<String>> oldData;
  final List<String> oldHeaders;
  final List<List<String>> newData;
  final List<String> newHeaders;

  SplitCellsAction({
    required this.data,
    required this.headers,
    required this.oldData,
    required this.oldHeaders,
    required this.newData,
    required this.newHeaders,
  });

  @override
  void undo() {
    data.clear();
    data.addAll(oldData.map((row) => List<String>.from(row)));
    headers.clear();
    headers.addAll(oldHeaders);
  }

  @override
  void redo() {
    data.clear();
    data.addAll(newData.map((row) => List<String>.from(row)));
    headers.clear();
    headers.addAll(newHeaders);
  }
}

class SplitRowsAction extends UndoableAction {
  final List<List<String>> data;
  final List<List<String>> oldData;
  final List<List<String>> newData;

  SplitRowsAction({
    required this.data,
    required this.oldData,
    required this.newData,
  });

  @override
  void undo() {
    data.clear();
    data.addAll(oldData.map((row) => List<String>.from(row)));
  }

  @override
  void redo() {
    data.clear();
    data.addAll(newData.map((row) => List<String>.from(row)));
  }
}
