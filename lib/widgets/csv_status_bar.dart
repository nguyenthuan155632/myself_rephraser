import 'package:flutter/material.dart';
import '../theme/csv_theme.dart';

class CsvStatusBar extends StatelessWidget {
  final String? fileName;
  final int totalRows;
  final int filteredRows;
  final int columnCount;
  final int selectedRowsCount;
  final String? encoding;

  const CsvStatusBar({
    super.key,
    this.fileName,
    this.totalRows = 0,
    this.filteredRows = 0,
    this.columnCount = 0,
    this.selectedRowsCount = 0,
    this.encoding,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 32,
      decoration: const BoxDecoration(
        color: CsvTheme.tableHeaderBg,
        border: Border(
          top: BorderSide(color: CsvTheme.borderColor, width: 1),
        ),
      ),
      padding: const EdgeInsets.symmetric(horizontal: CsvTheme.spacingLg),
      child: Row(
        children: [
          // File name
          if (fileName != null) ...[
            Icon(
              Icons.insert_drive_file_outlined,
              size: 14,
              color: CsvTheme.textTertiary,
            ),
            const SizedBox(width: CsvTheme.spacingSm),
            Flexible(
              child: Text(
                fileName!,
                style: CsvTheme.labelMedium,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            _buildDivider(),
          ],

          // Rows count
          _buildStatusItem(
            icon: Icons.table_rows_outlined,
            label: _getRowsLabel(),
            tooltip: filteredRows < totalRows
                ? 'Showing $filteredRows of $totalRows rows'
                : '$totalRows total rows',
          ),

          _buildDivider(),

          // Columns count
          _buildStatusItem(
            icon: Icons.view_column_outlined,
            label: '$columnCount ${columnCount == 1 ? 'column' : 'columns'}',
            tooltip: '$columnCount columns',
          ),

          // Selected rows
          if (selectedRowsCount > 0) ...[
            _buildDivider(),
            _buildStatusItem(
              icon: Icons.check_box_outlined,
              label: '$selectedRowsCount selected',
              tooltip: '$selectedRowsCount rows selected',
              color: CsvTheme.primaryColor,
            ),
          ],

          // Encoding
          if (encoding != null) ...[
            _buildDivider(),
            _buildStatusItem(
              icon: Icons.text_fields,
              label: encoding!,
              tooltip: 'File encoding: $encoding',
            ),
          ],

          const Spacer(),

          // Help text
          Text(
            'Click cell to edit • Right-click for options',
            style: CsvTheme.caption.copyWith(
              fontStyle: FontStyle.italic,
            ),
          ),
        ],
      ),
    );
  }

  String _getRowsLabel() {
    if (filteredRows < totalRows) {
      return '$filteredRows / $totalRows rows';
    }
    return '$totalRows ${totalRows == 1 ? 'row' : 'rows'}';
  }

  Widget _buildStatusItem({
    required IconData icon,
    required String label,
    String? tooltip,
    Color? color,
  }) {
    final widget = Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(
          icon,
          size: 14,
          color: color ?? CsvTheme.textTertiary,
        ),
        const SizedBox(width: 4),
        Text(
          label,
          style: CsvTheme.labelMedium.copyWith(
            color: color ?? CsvTheme.textSecondary,
          ),
        ),
      ],
    );

    if (tooltip != null) {
      return Tooltip(
        message: tooltip,
        child: widget,
      );
    }

    return widget;
  }

  Widget _buildDivider() {
    return Container(
      height: 16,
      width: 1,
      margin: const EdgeInsets.symmetric(horizontal: CsvTheme.spacingMd),
      color: CsvTheme.borderColorLight,
    );
  }
}
