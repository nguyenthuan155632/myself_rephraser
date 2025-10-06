import 'dart:io';

/// Model representing a single history entry/snapshot
class CsvHistoryEntry {
  /// Unique identifier for this snapshot
  final String id;

  /// Timestamp when this snapshot was created
  final DateTime timestamp;

  /// Path to the snapshot CSV file
  final String filePath;

  /// Description of the action that led to this snapshot
  final String actionDescription;

  /// Type of action (e.g., 'edit', 'delete', 'add', 'merge', 'split')
  final String actionType;

  /// Number of rows in this snapshot
  final int rowCount;

  /// Number of columns in this snapshot
  final int columnCount;

  /// Optional metadata
  final Map<String, dynamic>? metadata;

  CsvHistoryEntry({
    required this.id,
    required this.timestamp,
    required this.filePath,
    required this.actionDescription,
    required this.actionType,
    required this.rowCount,
    required this.columnCount,
    this.metadata,
  });

  /// Get formatted timestamp for display
  String get formattedTimestamp {
    final now = DateTime.now();
    final difference = now.difference(timestamp);

    if (difference.inSeconds < 60) {
      return 'Just now';
    } else if (difference.inMinutes < 60) {
      return '${difference.inMinutes}m ago';
    } else if (difference.inHours < 24) {
      return '${difference.inHours}h ago';
    } else if (difference.inDays < 7) {
      return '${difference.inDays}d ago';
    } else {
      // Format as date
      return '${timestamp.day}/${timestamp.month}/${timestamp.year} ${timestamp.hour}:${timestamp.minute.toString().padLeft(2, '0')}';
    }
  }

  /// Get a more detailed timestamp
  String get detailedTimestamp {
    return '${timestamp.day}/${timestamp.month}/${timestamp.year} '
        '${timestamp.hour}:${timestamp.minute.toString().padLeft(2, '0')}:'
        '${timestamp.second.toString().padLeft(2, '0')}';
  }

  /// Get file size information (if available)
  Future<String> getFileSize() async {
    try {
      final file = _getFile();
      final bytes = await file.length();
      return _formatBytes(bytes);
    } catch (e) {
      return 'Unknown';
    }
  }

  File _getFile() {
    return File(filePath);
  }

  String _formatBytes(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
  }

  /// Copy with method for creating modified copies
  CsvHistoryEntry copyWith({
    String? id,
    DateTime? timestamp,
    String? filePath,
    String? actionDescription,
    String? actionType,
    int? rowCount,
    int? columnCount,
    Map<String, dynamic>? metadata,
  }) {
    return CsvHistoryEntry(
      id: id ?? this.id,
      timestamp: timestamp ?? this.timestamp,
      filePath: filePath ?? this.filePath,
      actionDescription: actionDescription ?? this.actionDescription,
      actionType: actionType ?? this.actionType,
      rowCount: rowCount ?? this.rowCount,
      columnCount: columnCount ?? this.columnCount,
      metadata: metadata ?? this.metadata,
    );
  }

  @override
  String toString() {
    return 'CsvHistoryEntry(id: $id, timestamp: $timestamp, action: $actionDescription)';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is CsvHistoryEntry && other.id == id;
  }

  @override
  int get hashCode => id.hashCode;
}
