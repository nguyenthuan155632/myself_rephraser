import 'dart:io';
import 'dart:convert';
import 'package:csv/csv.dart';

/// Service for handling CSV file operations
class CsvFileService {
  /// Read CSV file with specified encoding
  static Future<CsvFileData> readCsvFile(File file,
      {Encoding? encoding}) async {
    final bytes = await file.readAsBytes();
    String input;

    if (encoding != null) {
      input = encoding.decode(bytes);
    } else {
      // Try UTF-8 first with malformed byte handling
      try {
        input = const Utf8Decoder(allowMalformed: false).convert(bytes);
      } catch (e) {
        // If strict UTF-8 fails, try lenient UTF-8
        input = const Utf8Decoder(allowMalformed: true).convert(bytes);
      }
    }

    // Use the CSV package for proper parsing
    const csvConverter = CsvToListConverter(
      eol: '\n',
      shouldParseNumbers: false, // Keep everything as strings
    );

    final rows = csvConverter.convert(input);

    if (rows.isEmpty) {
      return CsvFileData(headers: [], data: []);
    }

    // Convert all rows to List<String>
    final allRows = rows
        .map((row) => row.map((cell) => cell?.toString() ?? '').toList())
        .toList();

    // Extract header
    final headers = allRows.first;

    // Extract data rows and pad/truncate to match header length
    final allData = <List<String>>[];
    for (int i = 1; i < allRows.length; i++) {
      final row = allRows[i];
      // Ensure row has exactly the same number of columns as headers
      final paddedRow = List<String>.filled(headers.length, '');
      for (int j = 0; j < headers.length && j < row.length; j++) {
        paddedRow[j] = row[j];
      }
      allData.add(paddedRow);
    }

    return CsvFileData(headers: headers, data: allData);
  }

  /// Save CSV data to file
  static Future<void> saveCsvFile(
    File file,
    List<String> headers,
    List<List<String>> data,
  ) async {
    final csvContent = StringBuffer();

    // Write header
    csvContent.writeln(headers.join(','));

    // Write data rows
    for (var row in data) {
      // Escape cells that contain commas or quotes
      final escapedRow = row.map((cell) {
        if (cell.contains(',') || cell.contains('"') || cell.contains('\n')) {
          return '"${cell.replaceAll('"', '""')}"';
        }
        return cell;
      }).join(',');
      csvContent.writeln(escapedRow);
    }

    // Write to file
    await file.writeAsString(csvContent.toString());
  }

  /// Get encoding from string name
  static Encoding getEncodingFromString(String encodingName) {
    switch (encodingName) {
      case 'utf8':
        return utf8;
      case 'utf8lenient':
        return const Utf8Codec(allowMalformed: true);
      case 'latin1':
        return latin1;
      case 'windows1252':
        // Windows-1252 is similar to Latin-1 but with more characters in 128-159 range
        // For en-dash (–) and em-dash (—), use Latin-1 as closest match
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

/// Data class for CSV file content
class CsvFileData {
  final List<String> headers;
  final List<List<String>> data;

  CsvFileData({required this.headers, required this.data});
}
