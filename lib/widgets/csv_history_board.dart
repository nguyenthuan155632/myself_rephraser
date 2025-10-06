import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:file_picker/file_picker.dart';
import '../models/csv_history_entry.dart';
import '../services/csv_history_service.dart';
import '../theme/csv_theme.dart';

/// Widget displaying history board with timeline of changes
class CsvHistoryBoard extends StatefulWidget {
  final Function(String snapshotId) onRestore;
  final VoidCallback? onClose;

  const CsvHistoryBoard({
    super.key,
    required this.onRestore,
    this.onClose,
  });

  @override
  State<CsvHistoryBoard> createState() => _CsvHistoryBoardState();
}

class _CsvHistoryBoardState extends State<CsvHistoryBoard> {
  final _historyService = CsvHistoryService();
  List<CsvHistoryEntry> _entries = [];
  CsvHistoryEntry? _selectedEntry;
  int _totalSize = 0;

  @override
  void initState() {
    super.initState();
    _loadHistory();
  }

  Future<void> _loadHistory() async {
    setState(() {
      _entries = _historyService.getHistoryEntries();
    });

    // Load total size
    final size = await _historyService.getCurrentSessionSize();
    setState(() {
      _totalSize = size;
    });
  }

  Future<void> _restoreSnapshot(String snapshotId) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(CsvTheme.radiusLg),
        ),
        title: Row(
          children: [
            Icon(Icons.restore, color: CsvTheme.warningColor),
            const SizedBox(width: CsvTheme.spacingMd),
            const Text('Restore from History'),
          ],
        ),
        content: const Text(
          'This will restore the CSV data to the selected snapshot. '
          'Current changes will be added as a new snapshot.\n\n'
          'Do you want to continue?',
          style: CsvTheme.bodyMedium,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: CsvTheme.primaryButtonStyle,
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Restore'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      widget.onRestore(snapshotId);
      if (widget.onClose != null) {
        widget.onClose!();
      }
    }
  }

  Future<void> _exportSnapshot(CsvHistoryEntry entry) async {
    try {
      // Ask user where to save using file picker
      final timestamp = entry.timestamp.millisecondsSinceEpoch;
      final defaultName = 'csv_snapshot_$timestamp.csv';

      final String? outputPath = await FilePicker.platform.saveFile(
        dialogTitle: 'Export Snapshot',
        fileName: defaultName,
        type: FileType.custom,
        allowedExtensions: ['csv'],
      );

      if (outputPath == null) {
        // User cancelled
        return;
      }

      await _historyService.exportSnapshot(entry.id, outputPath);

      if (mounted) {
        _showSnackBar(
            'Exported successfully to: ${outputPath.split('/').last}');
      }
    } catch (e) {
      if (mounted) {
        _showSnackBar('Export failed: $e', isError: true);
      }
    }
  }

  Future<void> _deleteSnapshot(CsvHistoryEntry entry) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(CsvTheme.radiusLg),
        ),
        title: Row(
          children: [
            Icon(Icons.warning, color: CsvTheme.warningColor),
            const SizedBox(width: CsvTheme.spacingMd),
            const Text('Delete Snapshot'),
          ],
        ),
        content: Text(
          'Are you sure you want to delete this snapshot?\n\n'
          '${entry.actionDescription}\n'
          '${entry.formattedTimestamp}',
          style: CsvTheme.bodyMedium,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: CsvTheme.errorColor,
            ),
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      await _historyService.deleteSnapshot(entry.id);
      _loadHistory();
      _showSnackBar('Snapshot deleted');
    }
  }

  void _showSnackBar(String message, {bool isError = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: isError ? CsvTheme.errorColor : CsvTheme.successColor,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(CsvTheme.radiusMd),
        ),
      ),
    );
  }

  String _formatBytes(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 400,
      height: MediaQuery.of(context).size.height * 0.8,
      decoration: BoxDecoration(
        color: CsvTheme.surfaceColor,
        borderRadius: BorderRadius.circular(CsvTheme.radiusLg),
        border: Border.all(color: CsvTheme.borderColor),
        boxShadow: const [CsvTheme.shadowLg],
      ),
      child: Column(
        children: [
          // Header
          Container(
            padding: const EdgeInsets.all(CsvTheme.spacingLg),
            decoration: const BoxDecoration(
              color: CsvTheme.tableHeaderBg,
              borderRadius: BorderRadius.only(
                topLeft: Radius.circular(CsvTheme.radiusLg),
                topRight: Radius.circular(CsvTheme.radiusLg),
              ),
              border: Border(
                bottom: BorderSide(color: CsvTheme.borderColor),
              ),
            ),
            child: Row(
              children: [
                Icon(Icons.history, color: CsvTheme.primaryColor, size: 24),
                const SizedBox(width: CsvTheme.spacingMd),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'History Board',
                        style: CsvTheme.headingMedium.copyWith(
                          color: CsvTheme.textPrimary,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        '${_entries.length} ${_entries.length == 1 ? 'snapshot' : 'snapshots'} • ${_formatBytes(_totalSize)}',
                        style: CsvTheme.bodySmall.copyWith(
                          color: CsvTheme.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: widget.onClose,
                  tooltip: 'Close',
                ),
              ],
            ),
          ),

          // Info Banner
          Container(
            padding: const EdgeInsets.all(CsvTheme.spacingMd),
            color: CsvTheme.infoColor.withOpacity(0.1),
            child: Row(
              children: [
                Icon(
                  Icons.info_outline,
                  size: 16,
                  color: CsvTheme.infoColor,
                ),
                const SizedBox(width: CsvTheme.spacingSm),
                Expanded(
                  child: Text(
                    'Every change creates a safe snapshot. Click to restore.',
                    style: CsvTheme.bodySmall.copyWith(
                      color: CsvTheme.infoColor,
                    ),
                  ),
                ),
              ],
            ),
          ),

          // History Timeline
          Expanded(
            child: _entries.isEmpty ? _buildEmptyState() : _buildTimeline(),
          ),

          // Footer actions
          Container(
            padding: const EdgeInsets.all(CsvTheme.spacingMd),
            decoration: const BoxDecoration(
              border: Border(
                top: BorderSide(color: CsvTheme.borderColor),
              ),
            ),
            child: Row(
              children: [
                TextButton.icon(
                  icon: const Icon(Icons.delete_sweep, size: 18),
                  label: const Text('Clear All'),
                  onPressed: _entries.isEmpty
                      ? null
                      : () async {
                          final confirmed = await showDialog<bool>(
                            context: context,
                            builder: (context) => AlertDialog(
                              title: const Text('Clear All History'),
                              content: const Text(
                                'This will permanently delete all history snapshots. '
                                'This action cannot be undone.',
                              ),
                              actions: [
                                TextButton(
                                  onPressed: () =>
                                      Navigator.pop(context, false),
                                  child: const Text('Cancel'),
                                ),
                                ElevatedButton(
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: CsvTheme.errorColor,
                                  ),
                                  onPressed: () => Navigator.pop(context, true),
                                  child: const Text('Clear All'),
                                ),
                              ],
                            ),
                          );

                          if (confirmed == true) {
                            await _historyService.clearCurrentSession();
                            _loadHistory();
                            _showSnackBar('All history cleared');
                          }
                        },
                ),
                const Spacer(),
                Text(
                  'Auto-saved to /tmp',
                  style: CsvTheme.bodySmall.copyWith(
                    color: CsvTheme.textTertiary,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.history_outlined,
            size: 64,
            color: CsvTheme.textTertiary,
          ),
          const SizedBox(height: CsvTheme.spacingLg),
          Text(
            'No History Yet',
            style: CsvTheme.headingMedium.copyWith(
              color: CsvTheme.textSecondary,
            ),
          ),
          const SizedBox(height: CsvTheme.spacingSm),
          Text(
            'Make changes to create history snapshots',
            style: CsvTheme.bodySmall.copyWith(
              color: CsvTheme.textTertiary,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTimeline() {
    return ListView.builder(
      padding: const EdgeInsets.all(CsvTheme.spacingMd),
      itemCount: _entries.length,
      reverse: true, // Show newest first
      itemBuilder: (context, index) {
        final reversedIndex = _entries.length - 1 - index;
        final entry = _entries[reversedIndex];
        final isSelected = _selectedEntry?.id == entry.id;
        final isFirst = reversedIndex == _entries.length - 1;

        return _buildTimelineEntry(entry, isFirst, isSelected);
      },
    );
  }

  Widget _buildTimelineEntry(
      CsvHistoryEntry entry, bool isFirst, bool isSelected) {
    return Container(
      margin: const EdgeInsets.only(bottom: CsvTheme.spacingMd),
      child: Material(
        color: isSelected
            ? CsvTheme.primaryLight.withOpacity(0.2)
            : CsvTheme.backgroundColor,
        borderRadius: BorderRadius.circular(CsvTheme.radiusMd),
        child: InkWell(
          onTap: () {
            setState(() {
              _selectedEntry = entry;
            });
          },
          borderRadius: BorderRadius.circular(CsvTheme.radiusMd),
          child: Container(
            padding: const EdgeInsets.all(CsvTheme.spacingMd),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(CsvTheme.radiusMd),
              border: Border.all(
                color:
                    isSelected ? CsvTheme.primaryColor : CsvTheme.borderColor,
                width: isSelected ? 2 : 1,
              ),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Timeline indicator
                Column(
                  children: [
                    Container(
                      width: 32,
                      height: 32,
                      decoration: BoxDecoration(
                        color: isFirst
                            ? CsvTheme.successColor
                            : CsvTheme.primaryColor.withOpacity(0.1),
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: isFirst
                              ? CsvTheme.successColor
                              : CsvTheme.primaryColor,
                          width: 2,
                        ),
                      ),
                      child: Icon(
                        _getActionIcon(entry.actionType),
                        size: 16,
                        color: isFirst ? Colors.white : CsvTheme.primaryColor,
                      ),
                    ),
                  ],
                ),
                const SizedBox(width: CsvTheme.spacingMd),

                // Content
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              entry.actionDescription,
                              style: CsvTheme.bodyMedium.copyWith(
                                fontWeight: FontWeight.w600,
                                color: CsvTheme.textPrimary,
                              ),
                            ),
                          ),
                          if (isFirst)
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: CsvTheme.spacingSm,
                                vertical: 2,
                              ),
                              decoration: BoxDecoration(
                                color: CsvTheme.successColor,
                                borderRadius:
                                    BorderRadius.circular(CsvTheme.radiusSm),
                              ),
                              child: Text(
                                'Current',
                                style: CsvTheme.bodySmall.copyWith(
                                  color: Colors.white,
                                  fontSize: 10,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        entry.formattedTimestamp,
                        style: CsvTheme.bodySmall.copyWith(
                          color: CsvTheme.textSecondary,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          Icon(
                            Icons.table_rows,
                            size: 12,
                            color: CsvTheme.textTertiary,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            '${entry.rowCount} rows',
                            style: CsvTheme.bodySmall.copyWith(
                              color: CsvTheme.textTertiary,
                              fontSize: 11,
                            ),
                          ),
                          const SizedBox(width: CsvTheme.spacingMd),
                          Icon(
                            Icons.view_column,
                            size: 12,
                            color: CsvTheme.textTertiary,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            '${entry.columnCount} cols',
                            style: CsvTheme.bodySmall.copyWith(
                              color: CsvTheme.textTertiary,
                              fontSize: 11,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),

                // Actions
                PopupMenuButton<String>(
                  icon: const Icon(Icons.more_vert, size: 18),
                  tooltip: 'Actions',
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(CsvTheme.radiusMd),
                  ),
                  onSelected: (value) {
                    if (value == 'restore') {
                      _restoreSnapshot(entry.id);
                    } else if (value == 'export') {
                      _exportSnapshot(entry);
                    } else if (value == 'delete' && !isFirst) {
                      _deleteSnapshot(entry);
                    }
                  },
                  itemBuilder: (context) => [
                    const PopupMenuItem(
                      value: 'restore',
                      child: Row(
                        children: [
                          Icon(Icons.restore, size: 18),
                          SizedBox(width: CsvTheme.spacingSm),
                          Text('Restore to this version'),
                        ],
                      ),
                    ),
                    const PopupMenuItem(
                      value: 'export',
                      child: Row(
                        children: [
                          Icon(Icons.file_download, size: 18),
                          SizedBox(width: CsvTheme.spacingSm),
                          Text('Export snapshot'),
                        ],
                      ),
                    ),
                    if (!isFirst) ...[
                      const PopupMenuDivider(),
                      const PopupMenuItem(
                        value: 'delete',
                        child: Row(
                          children: [
                            Icon(Icons.delete,
                                size: 18, color: CsvTheme.errorColor),
                            SizedBox(width: CsvTheme.spacingSm),
                            Text('Delete snapshot',
                                style: TextStyle(color: CsvTheme.errorColor)),
                          ],
                        ),
                      ),
                    ],
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  IconData _getActionIcon(String actionType) {
    switch (actionType) {
      case 'add':
        return Icons.add;
      case 'delete':
        return Icons.delete;
      case 'edit':
        return Icons.edit;
      case 'merge':
        return Icons.merge;
      case 'split':
        return Icons.call_split;
      case 'initial':
        return Icons.file_open;
      default:
        return Icons.change_history;
    }
  }
}
