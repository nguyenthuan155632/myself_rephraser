import 'package:flutter/material.dart';
import '../models/csv_undoable_actions.dart';

/// Mixin for undo/redo functionality
mixin CsvUndoRedoMixin<T extends StatefulWidget> on State<T> {
  // These getters/setters must be implemented by the widget state
  List<UndoableAction> get actionHistory;
  int get currentActionIndex;

  set currentActionIndex(int value);

  void rebuildFilteredData();
  void clearSelections();
  void markUnsavedChanges();
  void forceRebuild();

  /// Check if undo is available
  bool get canUndo => currentActionIndex >= 0;

  /// Check if redo is available
  bool get canRedo => currentActionIndex < actionHistory.length - 1;

  /// Add an action to the history
  void addAction(UndoableAction action) {
    // Remove any actions after current index (when undoing then making new action)
    if (currentActionIndex < actionHistory.length - 1) {
      actionHistory.removeRange(currentActionIndex + 1, actionHistory.length);
    }
    actionHistory.add(action);
    currentActionIndex = actionHistory.length - 1;
  }

  /// Undo the last action
  void undo() {
    if (!canUndo) return;

    setState(() {
      actionHistory[currentActionIndex].undo();
      currentActionIndex--;
      rebuildFilteredData();
      clearSelections();
      forceRebuild();
      markUnsavedChanges();
    });
  }

  /// Redo the last undone action
  void redo() {
    if (!canRedo) return;

    setState(() {
      currentActionIndex++;
      actionHistory[currentActionIndex].redo();
      rebuildFilteredData();
      clearSelections();
      forceRebuild();
      markUnsavedChanges();
    });
  }

  /// Clear the action history
  void clearHistory() {
    actionHistory.clear();
    currentActionIndex = -1;
  }
}
