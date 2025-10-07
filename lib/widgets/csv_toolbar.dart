import 'package:flutter/material.dart';
import '../theme/csv_theme.dart';

class CsvToolbar extends StatelessWidget {
  final String? fileName;
  final bool hasUnsavedChanges;
  final bool canUndo;
  final bool canRedo;
  final int selectedCellsCount;
  final int selectedRowsCount;
  final bool showCheckboxes;

  final VoidCallback? onNewFile;
  final VoidCallback? onSave;
  final VoidCallback? onUndo;
  final VoidCallback? onRedo;
  final VoidCallback? onAddRow;
  final VoidCallback? onAddColumn;
  final VoidCallback? onDeleteRows;
  final VoidCallback? onMergeRows;
  final VoidCallback? onSplitCells;
  final VoidCallback? onSplitRows;
  final VoidCallback? onBulkEdit;
  final VoidCallback? onClearCellSelection;
  final VoidCallback? onToggleCheckboxes;
  final VoidCallback? onChangeEncoding;
  final Function(String)? onCleanupAction;

  const CsvToolbar({
    super.key,
    this.fileName,
    this.hasUnsavedChanges = false,
    this.canUndo = false,
    this.canRedo = false,
    this.selectedCellsCount = 0,
    this.selectedRowsCount = 0,
    this.showCheckboxes = false,
    this.onNewFile,
    this.onSave,
    this.onUndo,
    this.onRedo,
    this.onAddRow,
    this.onAddColumn,
    this.onDeleteRows,
    this.onMergeRows,
    this.onSplitCells,
    this.onSplitRows,
    this.onBulkEdit,
    this.onClearCellSelection,
    this.onToggleCheckboxes,
    this.onChangeEncoding,
    this.onCleanupAction,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 36,
      decoration: BoxDecoration(
        color: CsvTheme.surfaceColor,
        border: const Border(
          bottom: BorderSide(color: CsvTheme.borderColor, width: 1),
        ),
        boxShadow: const [CsvTheme.shadowSm],
      ),
      child: LayoutBuilder(
        builder: (context, constraints) => SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: ConstrainedBox(
            constraints: BoxConstraints(minWidth: constraints.maxWidth),
            child: Row(
              children: [
                const SizedBox(width: CsvTheme.spacingMd),

                // File actions
                _buildToolbarSection([
                  _buildIconButton(
                    icon: Icons.folder_open_outlined,
                    tooltip: 'Open File',
                    onPressed: onNewFile,
                  ),
                  if (hasUnsavedChanges)
                    _buildIconButton(
                      icon: Icons.save_outlined,
                      tooltip: 'Save (Cmd+S)',
                      onPressed: onSave,
                      color: CsvTheme.primaryColor,
                      isActive: true,
                    ),
                ]),

                _buildDivider(),

                // Undo/Redo
                _buildToolbarSection([
                  _buildIconButton(
                    icon: Icons.undo_rounded,
                    tooltip: 'Undo (Cmd+Z)',
                    onPressed: canUndo ? onUndo : null,
                  ),
                  _buildIconButton(
                    icon: Icons.redo_rounded,
                    tooltip: 'Redo (Cmd+Shift+Z)',
                    onPressed: canRedo ? onRedo : null,
                  ),
                ]),

                _buildDivider(),

                // Row/Column actions
                _buildToolbarSection([
                  _buildIconButton(
                    icon: Icons.add_box_outlined,
                    tooltip: 'Add New Row',
                    onPressed: onAddRow,
                  ),
                  _buildIconButton(
                    icon: Icons.view_column_outlined,
                    tooltip: 'Add New Column',
                    onPressed: onAddColumn,
                  ),
                  if (selectedRowsCount > 0)
                    _buildIconButton(
                      icon: Icons.delete_outline,
                      tooltip: 'Delete Selected Rows ($selectedRowsCount)',
                      onPressed: onDeleteRows,
                      color: CsvTheme.errorColor,
                    ),
                  if (selectedRowsCount >= 2)
                    _buildIconButton(
                      icon: Icons.merge_outlined,
                      tooltip: 'Merge Selected Rows',
                      onPressed: onMergeRows,
                      color: CsvTheme.primaryColor,
                    ),
                  if (selectedRowsCount > 0 || selectedCellsCount > 0)
                    _buildSplitMenu(),
                ]),

                _buildDivider(),

                // Checkbox toggle
                _buildIconButton(
                  icon: showCheckboxes
                      ? Icons.check_box_outlined
                      : Icons.check_box_outline_blank,
                  tooltip: showCheckboxes ? 'Hide Selection' : 'Show Selection',
                  onPressed: onToggleCheckboxes,
                  isActive: showCheckboxes,
                ),

                // Cleanup menu
                _buildCleanupMenu(),

                // Encoding
                _buildIconButton(
                  icon: Icons.translate_outlined,
                  tooltip: 'Change Encoding',
                  onPressed: onChangeEncoding,
                ),

                const SizedBox(width: CsvTheme.spacingLg),

                // Cell selection indicator
                if (selectedCellsCount > 0) ...[
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: CsvTheme.spacingMd,
                      vertical: CsvTheme.spacingSm,
                    ),
                    decoration: BoxDecoration(
                      color: CsvTheme.primaryLight,
                      borderRadius: BorderRadius.circular(CsvTheme.radiusMd),
                      border: Border.all(
                          color: CsvTheme.primaryColor.withOpacity(0.2)),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          '$selectedCellsCount cells selected',
                          style: CsvTheme.bodySmall.copyWith(
                            color: CsvTheme.primaryColor,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        const SizedBox(width: CsvTheme.spacingSm),
                        InkWell(
                          onTap: onBulkEdit,
                          borderRadius: BorderRadius.circular(
                              CsvTheme.radiusSm),
                          child: Padding(
                            padding: const EdgeInsets.all(2),
                            child: Icon(
                              Icons.edit_outlined,
                              size: 16,
                              color: CsvTheme.primaryColor,
                            ),
                          ),
                        ),
                        const SizedBox(width: CsvTheme.spacingXs),
                        InkWell(
                          onTap: onClearCellSelection,
                          borderRadius: BorderRadius.circular(
                              CsvTheme.radiusSm),
                          child: Padding(
                            padding: const EdgeInsets.all(2),
                            child: Icon(
                              Icons.close,
                              size: 16,
                              color: CsvTheme.primaryColor,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: CsvTheme.spacingMd),
                ],

                // Unsaved indicator
                if (hasUnsavedChanges && selectedCellsCount == 0) ...[
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: CsvTheme.spacingMd,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: CsvTheme.warningColor.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(CsvTheme.radiusSm),
                      border: Border.all(
                        color: CsvTheme.warningColor.withOpacity(0.3),
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          width: 6,
                          height: 6,
                          decoration: const BoxDecoration(
                            color: CsvTheme.warningColor,
                            shape: BoxShape.circle,
                          ),
                        ),
                        const SizedBox(width: 6),
                        Text(
                          'Unsaved',
                          style: CsvTheme.labelMedium.copyWith(
                            color: CsvTheme.warningColor,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: CsvTheme.spacingMd),
                ],

                const SizedBox(width: CsvTheme.spacingLg),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildToolbarSection(List<Widget> children) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: children
          .map((child) => Padding(
                padding: const EdgeInsets.only(right: CsvTheme.spacingXs),
                child: child,
              ))
          .toList(),
    );
  }

  Widget _buildIconButton({
    required IconData icon,
    required String tooltip,
    required VoidCallback? onPressed,
    Color? color,
    bool isActive = false,
  }) {
    final isEnabled = onPressed != null;

    return Tooltip(
      message: tooltip,
      waitDuration: const Duration(milliseconds: 500),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onPressed,
          borderRadius: BorderRadius.circular(CsvTheme.radiusMd),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 150),
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: isActive ? CsvTheme.primaryLight : Colors.transparent,
              borderRadius: BorderRadius.circular(CsvTheme.radiusMd),
            ),
            child: Icon(
              icon,
              size: 20,
              color: !isEnabled
                  ? CsvTheme.textTertiary
                  : (color ??
                      (isActive
                          ? CsvTheme.primaryColor
                          : CsvTheme.textSecondary)),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildDivider() {
    return Container(
      height: 24,
      width: 1,
      margin: const EdgeInsets.symmetric(horizontal: CsvTheme.spacingMd),
      color: CsvTheme.borderColorLight,
    );
  }

  Widget _buildCleanupMenu() {
    return PopupMenuButton<String>(
      icon: Icon(
        Icons.clean_hands,
        size: 20,
        color: CsvTheme.textSecondary,
      ),
      tooltip: 'Cleanup Data',
      offset: const Offset(0, 8),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(CsvTheme.radiusLg),
        side: const BorderSide(color: CsvTheme.borderColor),
      ),
      elevation: 8,
      onSelected: onCleanupAction,
      itemBuilder: (context) => [
        _buildPopupMenuItem(
          value: 'empty_rows',
          icon: Icons.delete_sweep_outlined,
          label: 'Delete Empty Rows',
        ),
        _buildPopupMenuItem(
          value: 'empty_columns',
          icon: Icons.view_column_outlined,
          label: 'Delete Empty Columns',
        ),
        _buildPopupMenuItem(
          value: 'duplicate_rows',
          icon: Icons.content_copy,
          label: 'Remove Duplicates',
        ),
      ],
    );
  }

  PopupMenuItem<String> _buildPopupMenuItem({
    required String value,
    required IconData icon,
    required String label,
  }) {
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

  Widget _buildSplitMenu() {
    return PopupMenuButton<String>(
      icon: const Icon(Icons.call_split, size: 20),
      tooltip: 'Split Options',
      onSelected: (value) {
        if (value == 'split_cells' && onSplitCells != null) {
          onSplitCells!();
        } else if (value == 'split_rows' && onSplitRows != null) {
          onSplitRows!();
        }
      },
      itemBuilder: (context) => [
        if (selectedCellsCount > 0)
          PopupMenuItem(
            value: 'split_cells',
            height: 40,
            child: Row(
              children: [
                Icon(
                  Icons.call_split,
                  size: 18,
                  color: CsvTheme.textSecondary,
                ),
                const SizedBox(width: CsvTheme.spacingMd),
                Text(
                  'Split Cells ($selectedCellsCount)',
                  style: CsvTheme.bodyMedium,
                ),
              ],
            ),
          ),
        if (selectedRowsCount > 0)
          PopupMenuItem(
            value: 'split_rows',
            height: 40,
            child: Row(
              children: [
                Icon(
                  Icons.splitscreen,
                  size: 18,
                  color: CsvTheme.textSecondary,
                ),
                const SizedBox(width: CsvTheme.spacingMd),
                Text(
                  'Split Rows ($selectedRowsCount)',
                  style: CsvTheme.bodyMedium,
                ),
              ],
            ),
          ),
      ],
    );
  }
}
