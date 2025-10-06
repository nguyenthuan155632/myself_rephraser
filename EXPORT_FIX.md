# Export Snapshot Permission Fix

## Issue
The export snapshot feature was failing with "Operation not permitted" error when trying to copy files directly to the Desktop on macOS. This is due to strict sandboxing and permission requirements in macOS.

## Root Cause
The original implementation attempted to programmatically write files to `~/Desktop/` without user permission:

```dart
final exportPath = '$homeDir/Desktop/csv_snapshot_$timestamp.csv';
await _historyService.exportSnapshot(entry.id, exportPath);
```

macOS requires explicit user permission to write to protected directories like Desktop, Documents, Downloads, etc.

## Solution
Changed the export functionality to use `FilePicker.platform.saveFile()` which:
1. Shows a native file picker dialog
2. Lets the user choose where to save the file
3. Automatically grants the app permission to write to the chosen location
4. Provides better UX by giving users control over the save location

### Updated Code
```dart
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
      _showSnackBar('Exported successfully to: ${outputPath.split('/').last}');
    }
  } catch (e) {
    if (mounted) {
      _showSnackBar('Export failed: $e', isError: true);
    }
  }
}
```

## Benefits
1. **No Permission Issues**: User explicitly grants permission by choosing the save location
2. **Better UX**: Users can choose exactly where to save the file
3. **Cross-Platform**: Works consistently on macOS, Windows, and Linux
4. **Native Dialogs**: Uses native OS file picker dialogs
5. **Follows Best Practices**: Standard approach for file operations in modern apps

## Files Modified
- `lib/widgets/csv_history_board.dart` - Updated export functionality
- `docs/CSV_HISTORY_FEATURE.md` - Updated documentation

## Testing
Tested on macOS with the following scenarios:
- ✅ Export to Desktop (user chooses location)
- ✅ Export to Documents
- ✅ Export to custom folders
- ✅ Cancel operation (graceful handling)
- ✅ Overwrite existing file (with OS confirmation)

## Additional Notes
The `file_picker` package is already included in `pubspec.yaml` as it's used for opening CSV files, so no new dependencies were needed.

