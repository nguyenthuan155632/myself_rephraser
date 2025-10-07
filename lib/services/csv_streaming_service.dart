import 'dart:io';
import 'dart:convert';
import 'package:csv/csv.dart';
import 'csv_database_service.dart';

/// Streaming CSV service for loading large files progressively
/// Optimized for files with 320k+ rows
class CsvStreamingService {
  static const int _batchSize = 5000; // Insert in batches of 5000

  /// Load CSV file with streaming and progress callback
  static Future<CsvLoadResult> loadCsvFile(
    File file, {
    Encoding? encoding,
    Function(double progress, int rowsLoaded)? onProgress,
  }) async {
    final sessionId = await CsvDatabaseService.startNewSession(file.path);

    try {
      // Read file as bytes
      final bytes = await file.readAsBytes();

      // Decode bytes
      String input;
      if (encoding != null) {
        input = encoding.decode(bytes);
      } else {
        try {
          input = const Utf8Decoder(allowMalformed: false).convert(bytes);
        } catch (e) {
          input = const Utf8Decoder(allowMalformed: true).convert(bytes);
        }
      }

      // Parse CSV
      const csvConverter = CsvToListConverter(
        eol: '\n',
        shouldParseNumbers: false,
      );

      final rows = csvConverter.convert(input);

      if (rows.isEmpty) {
        return CsvLoadResult(
          sessionId: sessionId,
          headers: [],
          totalRows: 0,
          fileName: file.path.split('/').last,
        );
      }

      // Extract headers
      final headers = rows.first.map((cell) => cell?.toString() ?? '').toList();
      await CsvDatabaseService.insertHeaders(sessionId, headers);

      // Process data rows in batches
      final totalDataRows = rows.length - 1;
      final List<List<String>> batchBuffer = [];
      int currentIndex = 0;

      for (int i = 1; i < rows.length; i++) {
        final row = rows[i];

        // Ensure row has exactly the same number of columns as headers
        final paddedRow = List<String>.filled(headers.length, '');
        for (int j = 0; j < headers.length && j < row.length; j++) {
          paddedRow[j] = row[j]?.toString() ?? '';
        }

        batchBuffer.add(paddedRow);

        // Insert batch when buffer is full
        if (batchBuffer.length >= _batchSize) {
          await CsvDatabaseService.insertRowsBatch(
            sessionId,
            batchBuffer,
            currentIndex,
          );

          currentIndex += batchBuffer.length;
          final progress = currentIndex / totalDataRows;

          onProgress?.call(progress, currentIndex);

          batchBuffer.clear();
        }
      }

      // Insert remaining rows
      if (batchBuffer.isNotEmpty) {
        await CsvDatabaseService.insertRowsBatch(
          sessionId,
          batchBuffer,
          currentIndex,
        );
        currentIndex += batchBuffer.length;
        onProgress?.call(1.0, currentIndex);
      }

      return CsvLoadResult(
        sessionId: sessionId,
        headers: headers,
        totalRows: totalDataRows,
        fileName: file.path.split('/').last,
      );
    } catch (e) {
      // Clean up on error
      await CsvDatabaseService.clearSession(sessionId);
      rethrow;
    }
  }

  /// Export CSV data from database to file
  static Future<void> exportToFile(
    String sessionId,
    File outputFile,
    List<String> headers, {
    Function(double progress)? onProgress,
  }) async {
    final sink = outputFile.openWrite();

    try {
      // Write headers
      final headerLine = _escapeRow(headers);
      sink.writeln(headerLine);

      final totalRows = await CsvDatabaseService.getRowCount(sessionId);
      int processedRows = 0;

      // Write data in chunks
      await for (final chunk in CsvDatabaseService.getAllRowsStream(
        sessionId,
        chunkSize: 1000,
      )) {
        for (final row in chunk) {
          final rowLine = _escapeRow(row);
          sink.writeln(rowLine);
          processedRows++;

          if (processedRows % 1000 == 0) {
            onProgress?.call(processedRows / totalRows);
          }
        }
      }

      onProgress?.call(1.0);
    } finally {
      await sink.close();
    }
  }

  /// Escape CSV row properly
  static String _escapeRow(List<String> row) {
    return row.map((cell) {
      if (cell.contains(',') || cell.contains('"') || cell.contains('\n')) {
        return '"${cell.replaceAll('"', '""')}"';
      }
      return cell;
    }).join(',');
  }

  /// Get encoding from string
  static Encoding getEncodingFromString(String encodingName) {
    switch (encodingName) {
      case 'utf8':
        return utf8;
      case 'utf8lenient':
        return const Utf8Codec(allowMalformed: true);
      case 'latin1':
        return latin1;
      case 'windows1252':
        return latin1;
      case 'utf16':
        return const Utf8Codec(allowMalformed: true);
      case 'ascii':
        return ascii;
      default:
        return utf8;
    }
  }
}

/// Result of CSV load operation
class CsvLoadResult {
  final String sessionId;
  final List<String> headers;
  final int totalRows;
  final String fileName;

  CsvLoadResult({
    required this.sessionId,
    required this.headers,
    required this.totalRows,
    required this.fileName,
  });
}
