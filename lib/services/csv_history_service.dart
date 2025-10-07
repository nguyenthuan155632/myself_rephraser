import 'dart:io';
import 'dart:convert';
import 'package:path/path.dart' as path;
import '../models/csv_history_entry.dart';

/// Service for managing CSV history snapshots in temporary storage
class CsvHistoryService {
  static final CsvHistoryService _instance = CsvHistoryService._internal();
  factory CsvHistoryService() => _instance;
  CsvHistoryService._internal();

  /// Base directory for history storage
  late final Directory _historyBaseDir;

  /// Current session directory
  Directory? _currentSessionDir;

  /// History entries for current session
  final List<CsvHistoryEntry> _historyEntries = [];

  /// Maximum number of history entries to keep
  static const int maxHistoryEntries = 50;

  bool _isInitialized = false;

  /// Initialize history service
  Future<void> initialize() async {
    if (_isInitialized) {
      return;
    }

    // Get system temp directory
    final tempDir = Directory.systemTemp;
    _historyBaseDir =
        Directory(path.join(tempDir.path, 'csv_rephraser_history'));

    // Create base directory if it doesn't exist
    if (!await _historyBaseDir.exists()) {
      await _historyBaseDir.create(recursive: true);
    }

    // Clean up old session directories (older than 7 days)
    await _cleanOldSessions();

    _isInitialized = true;
  }

  /// Remove history entries after the provided index
  Future<void> truncateAfter(int index) async {
    if (index >= _historyEntries.length - 1) {
      return;
    }

    int start = index + 1;
    if (start < 0) {
      start = 0;
    }
    if (start >= _historyEntries.length) {
      return;
    }

    final removed = _historyEntries.sublist(start).toList();
    _historyEntries.removeRange(start, _historyEntries.length);

    for (final entry in removed) {
      await _deleteSnapshot(entry.filePath);
    }
  }

  /// Start a new history session for a CSV file
  Future<void> startNewSession(String fileName) async {
    // Create unique session directory
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    final sessionName = '${_sanitizeFileName(fileName)}_$timestamp';
    _currentSessionDir =
        Directory(path.join(_historyBaseDir.path, sessionName));

    if (!await _currentSessionDir!.exists()) {
      await _currentSessionDir!.create(recursive: true);
    }

    // Clear history entries
    _historyEntries.clear();

    // Save initial snapshot
    print('Started new history session: ${_currentSessionDir!.path}');
  }

  /// Create a snapshot of current CSV state
  Future<CsvHistoryEntry> createSnapshot({
    required List<String> headers,
    required List<List<String>> data,
    required String actionDescription,
    String? actionType,
  }) async {
    if (_currentSessionDir == null) {
      throw StateError(
          'No active history session. Call startNewSession first.');
    }

    // Create snapshot file
    final timestamp = DateTime.now();
    final snapshotId = timestamp.millisecondsSinceEpoch.toString();
    final snapshotFile = File(
      path.join(_currentSessionDir!.path, 'snapshot_$snapshotId.csv'),
    );

    // Write CSV data to snapshot file
    await _writeCsvSnapshot(snapshotFile, headers, data);

    // Create history entry
    final entry = CsvHistoryEntry(
      id: snapshotId,
      timestamp: timestamp,
      filePath: snapshotFile.path,
      actionDescription: actionDescription,
      actionType: actionType ?? 'edit',
      rowCount: data.length,
      columnCount: headers.length,
    );

    // Add to history
    _historyEntries.add(entry);

    // Enforce max history limit
    if (_historyEntries.length > maxHistoryEntries) {
      final oldEntry = _historyEntries.removeAt(0);
      await _deleteSnapshot(oldEntry.filePath);
    }

    return entry;
  }

  /// Get all history entries for current session
  List<CsvHistoryEntry> getHistoryEntries() {
    return List.unmodifiable(_historyEntries);
  }

  /// Restore CSV data from a history snapshot
  Future<HistoryRestoreResult> restoreFromSnapshot(String snapshotId) async {
    final entry = _historyEntries.firstWhere(
      (e) => e.id == snapshotId,
      orElse: () => throw ArgumentError('Snapshot not found: $snapshotId'),
    );

    final file = File(entry.filePath);
    if (!await file.exists()) {
      throw FileSystemException('Snapshot file not found', entry.filePath);
    }

    // Read CSV data from snapshot
    final result = await _readCsvSnapshot(file);

    return HistoryRestoreResult(
      headers: result.headers,
      data: result.data,
      entry: entry,
    );
  }

  /// Clear current session history
  Future<void> clearCurrentSession() async {
    if (_currentSessionDir != null && await _currentSessionDir!.exists()) {
      await _currentSessionDir!.delete(recursive: true);
    }
    _historyEntries.clear();
    _currentSessionDir = null;
  }

  /// Get total size of history files for current session
  Future<int> getCurrentSessionSize() async {
    if (_currentSessionDir == null) return 0;

    int totalSize = 0;
    await for (final entity in _currentSessionDir!.list(recursive: true)) {
      if (entity is File) {
        totalSize += await entity.length();
      }
    }
    return totalSize;
  }

  /// Get history entry by index (0 = oldest, -1 = newest)
  CsvHistoryEntry? getEntryAt(int index) {
    if (index < 0) {
      final actualIndex = _historyEntries.length + index;
      if (actualIndex < 0 || actualIndex >= _historyEntries.length) return null;
      return _historyEntries[actualIndex];
    }
    if (index >= _historyEntries.length) return null;
    return _historyEntries[index];
  }

  /// Delete a specific snapshot
  Future<void> deleteSnapshot(String snapshotId) async {
    final index = _historyEntries.indexWhere((e) => e.id == snapshotId);
    if (index == -1) return;

    final entry = _historyEntries.removeAt(index);
    await _deleteSnapshot(entry.filePath);
  }

  /// Export history entry to a permanent location
  Future<void> exportSnapshot(String snapshotId, String destinationPath) async {
    final entry = _historyEntries.firstWhere(
      (e) => e.id == snapshotId,
      orElse: () => throw ArgumentError('Snapshot not found: $snapshotId'),
    );

    final sourceFile = File(entry.filePath);
    if (!await sourceFile.exists()) {
      throw FileSystemException('Snapshot file not found', entry.filePath);
    }

    await sourceFile.copy(destinationPath);
  }

  // Private helper methods

  Future<void> _writeCsvSnapshot(
    File file,
    List<String> headers,
    List<List<String>> data,
  ) async {
    final csvContent = StringBuffer();

    // Write header
    csvContent.writeln(_escapeRow(headers).join(','));

    // Write data rows
    for (var row in data) {
      csvContent.writeln(_escapeRow(row).join(','));
    }

    await file.writeAsString(csvContent.toString());
  }

  List<String> _escapeRow(List<String> row) {
    return row.map((cell) {
      if (cell.contains(',') || cell.contains('"') || cell.contains('\n')) {
        return '"${cell.replaceAll('"', '""')}"';
      }
      return cell;
    }).toList();
  }

  Future<_CsvSnapshotData> _readCsvSnapshot(File file) async {
    final content = await file.readAsString();
    final lines = const LineSplitter().convert(content);

    if (lines.isEmpty) {
      return _CsvSnapshotData(headers: [], data: []);
    }

    // Parse CSV (simple implementation)
    final rows = <List<String>>[];
    for (final line in lines) {
      if (line.trim().isEmpty) continue;
      rows.add(_parseCsvLine(line));
    }

    if (rows.isEmpty) {
      return _CsvSnapshotData(headers: [], data: []);
    }

    final headers = rows.first;
    final data = rows.sublist(1);

    return _CsvSnapshotData(headers: headers, data: data);
  }

  List<String> _parseCsvLine(String line) {
    final result = <String>[];
    final buffer = StringBuffer();
    bool inQuotes = false;

    for (int i = 0; i < line.length; i++) {
      final char = line[i];

      if (char == '"') {
        if (inQuotes && i + 1 < line.length && line[i + 1] == '"') {
          // Escaped quote
          buffer.write('"');
          i++; // Skip next quote
        } else {
          // Toggle quote mode
          inQuotes = !inQuotes;
        }
      } else if (char == ',' && !inQuotes) {
        // Field separator
        result.add(buffer.toString());
        buffer.clear();
      } else {
        buffer.write(char);
      }
    }

    // Add last field
    result.add(buffer.toString());

    return result;
  }

  Future<void> _deleteSnapshot(String filePath) async {
    try {
      final file = File(filePath);
      if (await file.exists()) {
        await file.delete();
      }
    } catch (e) {
      print('Error deleting snapshot $filePath: $e');
    }
  }

  Future<void> _cleanOldSessions() async {
    try {
      final now = DateTime.now();
      final sevenDaysAgo = now.subtract(const Duration(days: 7));

      await for (final entity in _historyBaseDir.list()) {
        if (entity is Directory) {
          final stat = await entity.stat();
          if (stat.modified.isBefore(sevenDaysAgo)) {
            await entity.delete(recursive: true);
            print('Cleaned old session: ${entity.path}');
          }
        }
      }
    } catch (e) {
      print('Error cleaning old sessions: $e');
    }
  }

  String _sanitizeFileName(String fileName) {
    // Remove extension and special characters
    final nameWithoutExt = path.basenameWithoutExtension(fileName);
    return nameWithoutExt.replaceAll(RegExp(r'[^\w\-]'), '_');
  }
}

class _CsvSnapshotData {
  final List<String> headers;
  final List<List<String>> data;

  _CsvSnapshotData({required this.headers, required this.data});
}

/// Result of restoring from history
class HistoryRestoreResult {
  final List<String> headers;
  final List<List<String>> data;
  final CsvHistoryEntry entry;

  HistoryRestoreResult({
    required this.headers,
    required this.data,
    required this.entry,
  });
}
