import 'dart:io';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:path/path.dart' as p;

/// High-performance database service for large CSV files
/// Uses SQLite with indexing for fast queries on 320k+ rows
class CsvDatabaseService {
  static Database? _database;
  static String? _currentSessionId;

  /// Initialize the database for desktop platforms
  static Future<void> initialize() async {
    if (Platform.isWindows || Platform.isLinux || Platform.isMacOS) {
      sqfliteFfiInit();
      databaseFactory = databaseFactoryFfi;
    }
  }

  /// Get or create database instance
  static Future<Database> get database async {
    if (_database != null) return _database!;

    final dbPath = await _getDatabasePath();
    _database = await databaseFactory.openDatabase(
      dbPath,
      options: OpenDatabaseOptions(
        version: 1,
        onCreate: _onCreate,
        onConfigure: _onConfigure,
      ),
    );
    return _database!;
  }

  /// Configure database for performance
  static Future<void> _onConfigure(Database db) async {
    // Enable Write-Ahead Logging for better concurrent access
    await db.execute('PRAGMA journal_mode=WAL');
    // Increase cache size (10MB)
    await db.execute('PRAGMA cache_size=10000');
    // Use memory for temp storage
    await db.execute('PRAGMA temp_store=MEMORY');
    // Disable synchronous mode for faster writes
    await db.execute('PRAGMA synchronous=NORMAL');
  }

  /// Create database tables
  static Future<void> _onCreate(Database db, int version) async {
    // Main data table
    await db.execute('''
      CREATE TABLE csv_data (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        session_id TEXT NOT NULL,
        row_index INTEGER NOT NULL,
        row_data TEXT NOT NULL,
        search_text TEXT
      )
    ''');

    // Headers table
    await db.execute('''
      CREATE TABLE csv_headers (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        session_id TEXT NOT NULL,
        headers TEXT NOT NULL,
        created_at INTEGER NOT NULL
      )
    ''');

    // Create indexes for fast queries
    await db.execute(
        'CREATE INDEX idx_session_row ON csv_data(session_id, row_index)');
    await db.execute('CREATE INDEX idx_search ON csv_data(search_text)');
    await db.execute('CREATE INDEX idx_session_id ON csv_data(session_id)');
  }

  /// Get database path
  static Future<String> _getDatabasePath() async {
    final dbDir = await _getDatabaseDirectory();
    return p.join(dbDir, 'csv_large_data.db');
  }

  /// Get database directory
  static Future<String> _getDatabaseDirectory() async {
    if (Platform.isWindows) {
      final appData = Platform.environment['APPDATA'] ?? '';
      final dir = Directory(p.join(appData, 'MyselfRephraser'));
      if (!await dir.exists()) {
        await dir.create(recursive: true);
      }
      return dir.path;
    } else if (Platform.isMacOS) {
      final home = Platform.environment['HOME'] ?? '';
      final dir = Directory(
          p.join(home, 'Library', 'Application Support', 'MyselfRephraser'));
      if (!await dir.exists()) {
        await dir.create(recursive: true);
      }
      return dir.path;
    } else {
      final home = Platform.environment['HOME'] ?? '';
      final dir = Directory(p.join(home, '.myself_rephraser'));
      if (!await dir.exists()) {
        await dir.create(recursive: true);
      }
      return dir.path;
    }
  }

  /// Start a new session for a CSV file
  static Future<String> startNewSession(String fileName) async {
    final db = await database;
    _currentSessionId = DateTime.now().millisecondsSinceEpoch.toString();

    // Clean up old sessions (keep only last 3)
    await _cleanupOldSessions(db);

    return _currentSessionId!;
  }

  /// Insert headers for the current session
  static Future<void> insertHeaders(
      String sessionId, List<String> headers) async {
    final db = await database;
    await db.insert('csv_headers', {
      'session_id': sessionId,
      'headers': headers.join('|~|'),
      'created_at': DateTime.now().millisecondsSinceEpoch,
    });
  }

  /// Get headers for a session
  static Future<List<String>> getHeaders(String sessionId) async {
    final db = await database;
    final result = await db.query(
      'csv_headers',
      where: 'session_id = ?',
      whereArgs: [sessionId],
      limit: 1,
    );

    if (result.isEmpty) return [];
    return (result.first['headers'] as String).split('|~|');
  }

  /// Insert rows in batch (highly optimized)
  static Future<void> insertRowsBatch(
    String sessionId,
    List<List<String>> rows,
    int startIndex,
  ) async {
    final db = await database;

    final batch = db.batch();
    for (int i = 0; i < rows.length; i++) {
      final row = rows[i];
      final searchText = row.join(' ').toLowerCase();

      batch.insert('csv_data', {
        'session_id': sessionId,
        'row_index': startIndex + i,
        'row_data': row.join('|~|'),
        'search_text': searchText,
      });
    }

    await batch.commit(noResult: true);
  }

  /// Get total row count for a session
  static Future<int> getRowCount(String sessionId) async {
    final db = await database;
    final result = await db.rawQuery(
      'SELECT COUNT(*) as count FROM csv_data WHERE session_id = ?',
      [sessionId],
    );
    return result.first['count'] as int;
  }

  /// Get rows with pagination
  static Future<List<List<String>>> getRows(
    String sessionId, {
    int offset = 0,
    int limit = 100,
  }) async {
    final db = await database;
    final result = await db.query(
      'csv_data',
      columns: ['row_data'],
      where: 'session_id = ?',
      whereArgs: [sessionId],
      orderBy: 'row_index ASC',
      offset: offset,
      limit: limit,
    );

    return result.map((row) {
      final rowData = row['row_data'] as String;
      return rowData.split('|~|');
    }).toList();
  }

  /// Get a single row by index
  static Future<List<String>?> getRow(String sessionId, int rowIndex) async {
    final db = await database;
    final result = await db.query(
      'csv_data',
      columns: ['row_data'],
      where: 'session_id = ? AND row_index = ?',
      whereArgs: [sessionId, rowIndex],
      limit: 1,
    );

    if (result.isEmpty) return null;
    return (result.first['row_data'] as String).split('|~|');
  }

  /// Update a single row
  static Future<void> updateRow(
    String sessionId,
    int rowIndex,
    List<String> newRow,
  ) async {
    final db = await database;
    final searchText = newRow.join(' ').toLowerCase();

    await db.update(
      'csv_data',
      {
        'row_data': newRow.join('|~|'),
        'search_text': searchText,
      },
      where: 'session_id = ? AND row_index = ?',
      whereArgs: [sessionId, rowIndex],
    );
  }

  /// Delete rows by indices
  static Future<void> deleteRows(String sessionId, List<int> rowIndices) async {
    final db = await database;

    final batch = db.batch();
    for (final index in rowIndices) {
      batch.delete(
        'csv_data',
        where: 'session_id = ? AND row_index = ?',
        whereArgs: [sessionId, index],
      );
    }
    await batch.commit(noResult: true);

    // Reindex remaining rows
    await _reindexRows(db, sessionId);
  }

  /// Insert a new row
  static Future<void> insertRow(
    String sessionId,
    int rowIndex,
    List<String> row,
  ) async {
    final db = await database;

    // Shift indices of rows after insertion point
    await db.rawUpdate(
      'UPDATE csv_data SET row_index = row_index + 1 WHERE session_id = ? AND row_index >= ?',
      [sessionId, rowIndex],
    );

    // Insert new row
    final searchText = row.join(' ').toLowerCase();
    await db.insert('csv_data', {
      'session_id': sessionId,
      'row_index': rowIndex,
      'row_data': row.join('|~|'),
      'search_text': searchText,
    });
  }

  /// Update column name in headers
  static Future<void> updateColumnName(
    String sessionId,
    int columnIndex,
    String newName,
  ) async {
    // For now, just return success - the headers are managed in memory
    // In a full implementation, you'd store headers in a separate table
    // or update the session metadata
    return;
  }

  /// Duplicate column data in database
  static Future<void> duplicateColumn(
    String sessionId,
    int sourceColumnIndex,
    int targetColumnIndex,
  ) async {
    final db = await database;

    // Get all rows for this session
    final rows = await db.query(
      'csv_data',
      where: 'session_id = ?',
      whereArgs: [sessionId],
      orderBy: 'row_index ASC',
    );

    // Update each row to duplicate the column data
    for (final row in rows) {
      final rowData = (row['row_data'] as String).split('|~|');

      // Insert the duplicated column value at the target position
      if (sourceColumnIndex < rowData.length) {
        final duplicatedValue = rowData[sourceColumnIndex];
        rowData.insert(targetColumnIndex, duplicatedValue);

        // Update the row in database
        await db.update(
          'csv_data',
          {
            'row_data': rowData.join('|~|'),
            'search_text': rowData.join(' ').toLowerCase(),
          },
          where: 'id = ?',
          whereArgs: [row['id']],
        );
      }
    }
  }

  /// Insert a new empty column at the target index for all rows
  static Future<void> insertEmptyColumn(
    String sessionId,
    int targetColumnIndex,
  ) async {
    final db = await database;

    final rows = await db.query(
      'csv_data',
      where: 'session_id = ?',
      whereArgs: [sessionId],
      orderBy: 'row_index ASC',
    );

    for (final row in rows) {
      final rowData = (row['row_data'] as String).split('|~|');

      if (targetColumnIndex <= rowData.length) {
        rowData.insert(targetColumnIndex, '');
      } else {
        while (rowData.length < targetColumnIndex) {
          rowData.add('');
        }
        rowData.add('');
      }

      await db.update(
        'csv_data',
        {
          'row_data': rowData.join('|~|'),
          'search_text': rowData.join(' ').toLowerCase(),
        },
        where: 'id = ?',
        whereArgs: [row['id']],
      );
    }
  }

  /// Remove a column at the specified index for all rows
  static Future<void> deleteColumn(
    String sessionId,
    int columnIndex,
  ) async {
    final db = await database;

    final rows = await db.query(
      'csv_data',
      where: 'session_id = ?',
      whereArgs: [sessionId],
      orderBy: 'row_index ASC',
    );

    for (final row in rows) {
      final rowData = (row['row_data'] as String).split('|~|');

      if (columnIndex < rowData.length) {
        rowData.removeAt(columnIndex);
      }

      await db.update(
        'csv_data',
        {
          'row_data': rowData.join('|~|'),
          'search_text': rowData.join(' ').toLowerCase(),
        },
        where: 'id = ?',
        whereArgs: [row['id']],
      );
    }
  }

  /// Find indices of columns that have an empty header and all empty values
  static Future<List<int>> findEmptyColumnIndices(
    String sessionId,
    List<String> headers,
  ) async {
    if (headers.isEmpty) return const <int>[];

    final candidateFlags = List<bool>.generate(
      headers.length,
      (index) => headers[index].trim().isEmpty,
    );

    if (!candidateFlags.contains(true)) {
      return const <int>[];
    }

    final db = await database;
    const chunkSize = 1000;
    int offset = 0;

    while (candidateFlags.contains(true)) {
      final rows = await db.query(
        'csv_data',
        columns: ['row_data'],
        where: 'session_id = ?',
        whereArgs: [sessionId],
        orderBy: 'row_index ASC',
        limit: chunkSize,
        offset: offset,
      );

      if (rows.isEmpty) {
        break;
      }

      for (final row in rows) {
        final rowData = (row['row_data'] as String).split('|~|');

        for (int i = 0; i < candidateFlags.length; i++) {
          if (!candidateFlags[i]) continue;

          if (i < rowData.length && rowData[i].trim().isNotEmpty) {
            candidateFlags[i] = false;
          }
        }

        if (!candidateFlags.contains(true)) {
          break;
        }
      }

      offset += rows.length;
      if (rows.length < chunkSize) {
        break;
      }
    }

    final emptyIndices = <int>[];
    for (int i = 0; i < candidateFlags.length; i++) {
      if (candidateFlags[i]) {
        emptyIndices.add(i);
      }
    }

    return emptyIndices;
  }

  /// Reorder column data for all rows
  static Future<void> reorderColumn(
    String sessionId,
    int fromIndex,
    int toIndex,
  ) async {
    if (fromIndex == toIndex) return;

    final db = await database;

    final rows = await db.query(
      'csv_data',
      where: 'session_id = ?',
      whereArgs: [sessionId],
      orderBy: 'row_index ASC',
    );

    for (final row in rows) {
      final rowData = (row['row_data'] as String).split('|~|');

      if (fromIndex >= rowData.length) {
        continue;
      }

      final value = rowData.removeAt(fromIndex);
      var targetIndex = toIndex;
      if (targetIndex < 0) {
        targetIndex = 0;
      } else if (targetIndex > rowData.length) {
        targetIndex = rowData.length;
      }
      rowData.insert(targetIndex, value);

      await db.update(
        'csv_data',
        {
          'row_data': rowData.join('|~|'),
          'search_text': rowData.join(' ').toLowerCase(),
        },
        where: 'id = ?',
        whereArgs: [row['id']],
      );
    }
  }

  /// Reorder rows by updating row_index values
  static Future<void> reorderRow(
    String sessionId,
    int fromIndex,
    int toIndex,
  ) async {
    if (fromIndex == toIndex) return;

    final db = await database;

    await db.transaction((txn) async {
      await txn.update(
        'csv_data',
        {'row_index': -1},
        where: 'session_id = ? AND row_index = ?',
        whereArgs: [sessionId, fromIndex],
      );

      if (fromIndex < toIndex) {
        await txn.rawUpdate(
          'UPDATE csv_data SET row_index = row_index - 1 '
          'WHERE session_id = ? AND row_index > ? AND row_index <= ?',
          [sessionId, fromIndex, toIndex],
        );
      } else {
        await txn.rawUpdate(
          'UPDATE csv_data SET row_index = row_index + 1 '
          'WHERE session_id = ? AND row_index >= ? AND row_index < ?',
          [sessionId, toIndex, fromIndex],
        );
      }

      await txn.update(
        'csv_data',
        {'row_index': toIndex},
        where: 'session_id = ? AND row_index = -1',
        whereArgs: [sessionId],
      );
    });
  }

  /// Replace entire session data with provided rows
  static Future<void> replaceSessionData(
    String sessionId,
    List<List<String>> rows,
  ) async {
    final db = await database;

    await db.transaction((txn) async {
      await txn.delete(
        'csv_data',
        where: 'session_id = ?',
        whereArgs: [sessionId],
      );

      final batch = txn.batch();
      for (int i = 0; i < rows.length; i++) {
        final row = List<String>.from(rows[i]);
        final searchText = row.join(' ').toLowerCase();

        batch.insert('csv_data', {
          'session_id': sessionId,
          'row_index': i,
          'row_data': row.join('|~|'),
          'search_text': searchText,
        });
      }

      await batch.commit(noResult: true);
    });
  }

  /// Advanced search with column filtering and row range
  static Future<List<CsvSearchResult>> searchRowsAdvanced(
    String sessionId,
    String query, {
    int limit = 1000,
    bool caseSensitive = false,
    List<int>? selectedColumns,
    int? rowRangeStart,
    int? rowRangeEnd,
  }) async {
    final db = await database;

    // Build WHERE clause for row range
    final whereConditions = <String>['session_id = ?'];
    final whereArgs = <dynamic>[sessionId];

    if (rowRangeStart != null) {
      whereConditions.add('row_index >= ?');
      whereArgs.add(rowRangeStart);
    }
    if (rowRangeEnd != null) {
      whereConditions.add('row_index <= ?');
      whereArgs.add(rowRangeEnd);
    }

    // Get all rows in range first
    final result = await db.query(
      'csv_data',
      columns: ['row_index', 'row_data'],
      where: whereConditions.join(' AND '),
      whereArgs: whereArgs,
      orderBy: 'row_index ASC',
    );

    // Filter in memory for column-specific search
    final filteredResults = <CsvSearchResult>[];
    final searchQuery = caseSensitive ? query : query.toLowerCase();

    for (final row in result) {
      final rowIndex = row['row_index'] as int;
      final rowData = (row['row_data'] as String).split('|~|');

      bool matches = false;

      if (query.isEmpty) {
        // No search query, just row range filter
        matches = true;
      } else if (selectedColumns != null && selectedColumns.isNotEmpty) {
        // Search in specific columns
        for (final colIndex in selectedColumns) {
          if (colIndex < rowData.length) {
            final cellValue = caseSensitive
                ? rowData[colIndex]
                : rowData[colIndex].toLowerCase();
            if (cellValue.contains(searchQuery)) {
              matches = true;
              break;
            }
          }
        }
      } else {
        // Search in all columns
        for (final cell in rowData) {
          final cellValue = caseSensitive ? cell : cell.toLowerCase();
          if (cellValue.contains(searchQuery)) {
            matches = true;
            break;
          }
        }
      }

      if (matches) {
        filteredResults.add(CsvSearchResult(
          rowIndex: rowIndex,
          rowData: rowData,
        ));

        if (filteredResults.length >= limit) break;
      }
    }

    return filteredResults;
  }

  /// Get all data for export (in chunks)
  static Stream<List<List<String>>> getAllRowsStream(
    String sessionId, {
    int chunkSize = 1000,
  }) async* {
    final totalCount = await getRowCount(sessionId);
    int offset = 0;

    while (offset < totalCount) {
      final rows = await getRows(
        sessionId,
        offset: offset,
        limit: chunkSize,
      );
      yield rows;
      offset += chunkSize;
    }
  }

  /// Reindex rows after deletion
  static Future<void> _reindexRows(Database db, String sessionId) async {
    final rows = await db.query(
      'csv_data',
      columns: ['id'],
      where: 'session_id = ?',
      whereArgs: [sessionId],
      orderBy: 'row_index ASC',
    );

    final batch = db.batch();
    for (int i = 0; i < rows.length; i++) {
      batch.update(
        'csv_data',
        {'row_index': i},
        where: 'id = ?',
        whereArgs: [rows[i]['id']],
      );
    }
    await batch.commit(noResult: true);
  }

  /// Clean up old sessions (keep only last 3)
  static Future<void> _cleanupOldSessions(Database database) async {
    final headers = await database.query(
      'csv_headers',
      orderBy: 'created_at DESC',
      limit: 3,
    );

    if (headers.length < 3) return;

    final keepSessionIds = headers.map((h) => h['session_id']).toList();
    final placeholders = List.filled(keepSessionIds.length, '?').join(',');

    await database.delete(
      'csv_data',
      where: 'session_id NOT IN ($placeholders)',
      whereArgs: keepSessionIds,
    );

    await database.delete(
      'csv_headers',
      where: 'session_id NOT IN ($placeholders)',
      whereArgs: keepSessionIds,
    );
  }

  /// Clear all data for a session
  static Future<void> clearSession(String sessionId) async {
    final db = await database;
    await db
        .delete('csv_data', where: 'session_id = ?', whereArgs: [sessionId]);
    await db
        .delete('csv_headers', where: 'session_id = ?', whereArgs: [sessionId]);
  }

  /// Close database connection
  static Future<void> close() async {
    if (_database != null) {
      await _database!.close();
      _database = null;
    }
  }

  /// Get current session ID
  static String? get currentSessionId => _currentSessionId;
}

/// Search result model
class CsvSearchResult {
  final int rowIndex;
  final List<String> rowData;

  CsvSearchResult({
    required this.rowIndex,
    required this.rowData,
  });
}
