import 'package:flutter/material.dart';
import '../theme/csv_theme.dart';

/// Dialog for editing cell content with multi-line support
class EditCellDialog extends StatefulWidget {
  final String initialValue;
  final String columnName;
  final Function(String) onSave;

  const EditCellDialog({
    super.key,
    required this.initialValue,
    required this.columnName,
    required this.onSave,
  });

  @override
  State<EditCellDialog> createState() => _EditCellDialogState();
}

class _EditCellDialogState extends State<EditCellDialog> {
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
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(CsvTheme.radiusXl),
      ),
      elevation: 8,
      child: Container(
        width: 600,
        constraints: const BoxConstraints(maxHeight: 500),
        padding: const EdgeInsets.all(CsvTheme.spacingXl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: CsvTheme.primaryLight,
                    borderRadius: BorderRadius.circular(CsvTheme.radiusMd),
                  ),
                  child: const Icon(
                    Icons.edit_outlined,
                    color: CsvTheme.primaryColor,
                    size: 20,
                  ),
                ),
                const SizedBox(width: CsvTheme.spacingMd),
                Expanded(
                  child: Text(
                    'Edit: ${widget.columnName}',
                    style: CsvTheme.headingMedium,
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close, size: 20),
                  onPressed: () => Navigator.of(context).pop(),
                  color: CsvTheme.textSecondary,
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

/// Dialog for renaming column headers
class RenameColumnDialog extends StatefulWidget {
  final String currentName;
  final Function(String) onSave;

  const RenameColumnDialog({
    super.key,
    required this.currentName,
    required this.onSave,
  });

  @override
  State<RenameColumnDialog> createState() => _RenameColumnDialogState();
}

class _RenameColumnDialogState extends State<RenameColumnDialog> {
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

/// Bulk Edit Dialog
class BulkEditDialog extends StatefulWidget {
  final String initialValue;
  final int cellCount;
  final Function(String) onSave;

  const BulkEditDialog({
    super.key,
    required this.initialValue,
    required this.cellCount,
    required this.onSave,
  });

  @override
  State<BulkEditDialog> createState() => _BulkEditDialogState();
}

class _BulkEditDialogState extends State<BulkEditDialog> {
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

/// Merge Rows Dialog
class MergeRowsDialog extends StatefulWidget {
  final int selectedCount;
  final Function(String separator, bool keepFirst) onMerge;

  const MergeRowsDialog({
    super.key,
    required this.selectedCount,
    required this.onMerge,
  });

  @override
  State<MergeRowsDialog> createState() => _MergeRowsDialogState();
}

class _MergeRowsDialogState extends State<MergeRowsDialog> {
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

/// Dialog for selecting file encoding
class EncodingSelectionDialog extends StatelessWidget {
  const EncodingSelectionDialog({super.key});

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
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
    );
  }
}

/// Dialog for splitting cells/rows
class SplitDialog extends StatefulWidget {
  final String mode; // 'cells' or 'rows'
  final int selectionCount;
  final Function(String delimiter) onSplit;

  const SplitDialog({
    super.key,
    required this.mode,
    required this.selectionCount,
    required this.onSplit,
  });

  @override
  State<SplitDialog> createState() => _SplitDialogState();
}

class _SplitDialogState extends State<SplitDialog> {
  final TextEditingController _delimiterController =
      TextEditingController(text: ',');

  @override
  void dispose() {
    _delimiterController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Row(
        children: [
          Icon(Icons.call_split, color: CsvTheme.primaryColor),
          const SizedBox(width: CsvTheme.spacingMd),
          Text(
            widget.mode == 'cells' ? 'Split Cells' : 'Split Rows',
            style: CsvTheme.headingMedium,
          ),
        ],
      ),
      content: Container(
        constraints: const BoxConstraints(maxWidth: 400),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.all(CsvTheme.spacingMd),
              decoration: BoxDecoration(
                color: CsvTheme.infoColor.withOpacity(0.1),
                borderRadius: BorderRadius.circular(CsvTheme.radiusMd),
                border: Border.all(color: CsvTheme.infoColor.withOpacity(0.3)),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.info_outline,
                    size: 20,
                    color: CsvTheme.infoColor,
                  ),
                  const SizedBox(width: CsvTheme.spacingMd),
                  Expanded(
                    child: Text(
                      widget.mode == 'cells'
                          ? 'Split ${widget.selectionCount} selected cells'
                          : 'Split ${widget.selectionCount} selected rows',
                      style: CsvTheme.bodySmall.copyWith(
                        color: CsvTheme.textSecondary,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: CsvTheme.spacingLg),
            Text(
              'Delimiter',
              style: CsvTheme.labelMedium.copyWith(
                fontWeight: FontWeight.w600,
                color: CsvTheme.textSecondary,
              ),
            ),
            const SizedBox(height: CsvTheme.spacingSm),
            TextField(
              controller: _delimiterController,
              decoration: InputDecoration(
                hintText: 'Enter delimiter (e.g., comma, semicolon)',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(CsvTheme.radiusMd),
                ),
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: CsvTheme.spacingMd,
                  vertical: CsvTheme.spacingSm,
                ),
              ),
            ),
            const SizedBox(height: CsvTheme.spacingMd),
            Row(
              children: [
                TextButton.icon(
                  onPressed: () {
                    _delimiterController.text = ',';
                  },
                  icon: const Icon(Icons.add, size: 16),
                  label: const Text('Comma'),
                  style: TextButton.styleFrom(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  ),
                ),
                TextButton.icon(
                  onPressed: () {
                    _delimiterController.text = ';';
                  },
                  icon: const Icon(Icons.add, size: 16),
                  label: const Text('Semicolon'),
                  style: TextButton.styleFrom(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  ),
                ),
                TextButton.icon(
                  onPressed: () {
                    _delimiterController.text = '|';
                  },
                  icon: const Icon(Icons.add, size: 16),
                  label: const Text('Pipe'),
                  style: TextButton.styleFrom(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  ),
                ),
              ],
            ),
            const SizedBox(height: CsvTheme.spacingLg),
            Container(
              padding: const EdgeInsets.all(CsvTheme.spacingMd),
              decoration: BoxDecoration(
                color: CsvTheme.primaryLight.withOpacity(0.3),
                borderRadius: BorderRadius.circular(CsvTheme.radiusMd),
                border:
                    Border.all(color: CsvTheme.primaryColor.withOpacity(0.3)),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.splitscreen_outlined,
                    size: 20,
                    color: CsvTheme.primaryColor,
                  ),
                  const SizedBox(width: CsvTheme.spacingMd),
                  Expanded(
                    child: Text(
                      'Each value will be split into a new row',
                      style: CsvTheme.bodySmall.copyWith(
                        color: CsvTheme.textSecondary,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        ElevatedButton.icon(
          onPressed: () {
            if (_delimiterController.text.isEmpty) {
              return;
            }
            widget.onSplit(_delimiterController.text);
            Navigator.of(context).pop();
          },
          icon: const Icon(Icons.call_split, size: 18),
          label: const Text('Split'),
          style: CsvTheme.primaryButtonStyle,
        ),
      ],
    );
  }
}
