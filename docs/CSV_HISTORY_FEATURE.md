# CSV History Board Feature

## Overview

The CSV History Board is a comprehensive version control system for CSV editing operations. Every change made to the CSV file is automatically saved as a temporary snapshot in the system's temporary directory, allowing users to safely revert to any previous state.

## Key Features

### 1. **Automatic Snapshot Creation**
- Every edit, add, delete, merge, split, or reorder operation creates a snapshot
- Snapshots are stored in `/tmp/csv_rephraser_history/`
- Each file session has its own unique directory
- Maximum of 50 snapshots per session (oldest are automatically pruned)

### 2. **History Timeline View**
- Visual timeline showing all changes in chronological order
- Each entry displays:
  - Action description (e.g., "Deleted 3 rows", "Merged 5 rows")
  - Timestamp (relative time like "5m ago" or exact date/time)
  - Row and column count for that snapshot
  - Action type indicator with color-coded icons

### 3. **Safe Restore Functionality**
- One-click restore to any previous version
- Confirmation dialog before restoring
- Current state is automatically saved before restoring
- After restore, a new snapshot is created

### 4. **History Management**
- **Export Snapshot**: Save any snapshot as a permanent CSV file
- **Delete Snapshot**: Remove individual snapshots (except current state)
- **Clear All History**: Remove all snapshots for the current session
- Automatic cleanup of old sessions (7+ days)

## Usage

### Opening History Board
1. Open a CSV file
2. Click the **History** icon (clock icon) in the app bar
3. The History Board appears as an overlay panel

### Restoring to a Previous Version
1. Open the History Board
2. Browse the timeline of changes
3. Click the **⋮** menu on the desired snapshot
4. Select **"Restore to this version"**
5. Confirm the restoration

### Exporting a Snapshot
1. Open the History Board
2. Find the snapshot you want to export
3. Click the **⋮** menu
4. Select **"Export snapshot"**
5. Choose where to save the file using the file picker dialog
6. The snapshot is saved to your chosen location

## Technical Architecture

### Components

#### 1. `CsvHistoryService`
- **Location**: `lib/services/csv_history_service.dart`
- **Responsibilities**:
  - Managing history sessions
  - Creating and storing CSV snapshots
  - Reading and restoring from snapshots
  - Cleanup of old sessions
  - File size tracking

#### 2. `CsvHistoryEntry`
- **Location**: `lib/models/csv_history_entry.dart`
- **Responsibilities**:
  - Data model for a single history entry
  - Metadata: timestamp, action description, row/column counts
  - Helper methods for formatting timestamps and file sizes

#### 3. `CsvHistoryBoard`
- **Location**: `lib/widgets/csv_history_board.dart`
- **Responsibilities**:
  - UI for displaying history timeline
  - User interactions (restore, export, delete)
  - Visual feedback and confirmations

### Storage Structure

```
/tmp/csv_rephraser_history/
├── {sanitized_filename}_{timestamp}/
│   ├── snapshot_{timestamp1}.csv
│   ├── snapshot_{timestamp2}.csv
│   ├── snapshot_{timestamp3}.csv
│   └── ...
└── {another_file}_{timestamp}/
    └── ...
```

### Snapshot Lifecycle

1. **Creation**:
   - Triggered after every data modification
   - Headers and data are written to a CSV file
   - Metadata is stored in memory

2. **Storage**:
   - Each snapshot is a complete copy of the CSV state
   - Stored in a session-specific directory
   - Limited to 50 snapshots per session

3. **Cleanup**:
   - Old snapshots removed when limit is exceeded
   - Session directories older than 7 days are deleted on startup
   - Manual cleanup via "Clear All History" button

## Tracked Actions

The following operations create history snapshots:

### Row Operations
- ✅ Add new row
- ✅ Delete rows (single or multiple)
- ✅ Merge rows
- ✅ Split rows
- ✅ Duplicate row
- ✅ Reorder rows
- ✅ Delete empty rows
- ✅ Remove duplicate rows

### Column Operations
- ✅ Add new column
- ✅ Delete column
- ✅ Rename column
- ✅ Duplicate column
- ✅ Reorder columns
- ✅ Delete empty columns

### Cell Operations
- ✅ Edit single cell
- ✅ Bulk edit cells
- ✅ Split cells

### File Operations
- ✅ Initial file load
- ✅ Restore from history

## Safety Features

### 1. **Immutable Snapshots**
- Each snapshot is a complete, independent copy
- No risk of corrupted undo/redo chains
- Can restore to any point without affecting other snapshots

### 2. **Pre-Restore Backup**
- Current state is always saved before restoration
- Never lose work, even when restoring old versions

### 3. **Confirmation Dialogs**
- Restore operations require user confirmation
- Delete and clear operations are protected
- Clear messaging about what will happen

### 4. **Automatic Cleanup**
- Old sessions auto-deleted after 7 days
- Prevents temp directory bloat
- Configurable retention policy

## Performance Considerations

### Storage Efficiency
- Snapshots are stored as compressed CSV files
- Average snapshot: 10-500 KB depending on data size
- 50 snapshots typically use 500 KB - 25 MB

### Memory Usage
- Only metadata kept in memory (lightweight)
- Full CSV data loaded only when restoring
- Minimal impact on application performance

### I/O Optimization
- Asynchronous snapshot creation
- Non-blocking UI during save operations
- Background cleanup of old sessions

## Future Enhancements

### Potential Improvements
1. **Differential Snapshots**: Store only changes instead of full copies
2. **Compression**: Add gzip compression for snapshots
3. **Cloud Sync**: Optional backup to cloud storage
4. **Visual Diff**: Show changes between two snapshots
5. **Snapshot Notes**: Allow users to add custom notes to snapshots
6. **Branching**: Create multiple history branches from a snapshot
7. **Search**: Search through history by action type or content
8. **Comparison Mode**: Side-by-side view of two versions

## Comparison with Undo/Redo

| Feature | Undo/Redo | History Board |
|---------|-----------|---------------|
| **Persistence** | In-memory only | Saved to disk |
| **Survives app restart** | ❌ No | ✅ Yes |
| **Data safety** | Can be lost | ✅ Permanent snapshots |
| **Jump to any version** | ❌ Sequential only | ✅ Direct access |
| **View timeline** | ❌ No | ✅ Full visual timeline |
| **Export versions** | ❌ No | ✅ Yes |
| **Storage** | Memory only | Disk-based |
| **Performance** | Fastest | Fast (async) |

## Best Practices

### For Users
1. Check history board before making major changes
2. Export important snapshots as backups
3. Use descriptive action names when possible
4. Clear history periodically for large files
5. Verify restored data before continuing edits

### For Developers
1. Always call `_createHistorySnapshot()` after state changes
2. Provide clear, descriptive action descriptions
3. Use appropriate action types for better filtering
4. Handle snapshot creation errors gracefully
5. Test restoration with various data sizes

## Troubleshooting

### History Board Not Showing
- Ensure a CSV file is loaded
- Check that history service is initialized
- Look for errors in console logs

### Snapshots Not Being Created
- Verify `_createHistorySnapshot()` is called
- Check file permissions for `/tmp` directory
- Ensure enough disk space available

### Restore Fails
- Snapshot file may have been manually deleted
- Corrupted snapshot file
- Check console for specific error messages

### Performance Issues
- Large CSV files (1M+ rows) may be slow
- Consider reducing snapshot frequency
- Clear old snapshots more aggressively
- Check available disk space

## Implementation Details

### Integration Points

The history feature integrates with existing CSV operations:

```dart
// Example: Adding history tracking to an operation
void _deleteSelectedRows() {
  final count = _selectedRowIndices.length;
  deleteRows(_selectedRowIndices);
  setState(() {
    _selectedRowIndices.clear();
  });
  // History snapshot automatically created
  _createHistorySnapshot('Deleted $count row${count > 1 ? 's' : ''}', actionType: 'delete');
}
```

### Key Methods

- `_createHistorySnapshot(description, {actionType})`: Create a new snapshot
- `_restoreFromHistory(snapshotId)`: Restore to a specific snapshot
- `_historyService.getHistoryEntries()`: Get all snapshots for current session
- `_historyService.clearCurrentSession()`: Delete all snapshots

## Conclusion

The History Board feature provides professional-grade version control for CSV editing, ensuring that users never lose data due to mistakes or unexpected changes. It complements the existing undo/redo system by providing persistent, disk-based snapshots that survive application restarts and allow non-linear navigation through the edit history.

