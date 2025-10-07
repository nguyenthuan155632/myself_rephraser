# Million-Row CSV Performance Improvement Plan

## Problem Analysis

The current CSV reader crashes on files with 1 million+ rows due to several critical memory and performance issues:

### 1. Memory Overload
- **Issue**: `file.readAsBytes()` loads entire file into RAM at once
- **Impact**: 1M row CSV files (several GB) exceed available memory
- **Location**: `lib/services/csv_streaming_service.dart:21`

### 2. Synchronous Processing
- **Issue**: Entire CSV parsed in memory before database operations
- **Impact**: Memory usage spikes to 3-4x file size during parsing
- **Location**: `lib/services/csv_streaming_service.dart:41`

### 3. History Snapshot Memory
- **Issue**: `_createHistorySnapshot()` stores complete dataset in memory
- **Impact**: For 1M rows = storing entire file again in RAM
- **Location**: `lib/screens/csv_reader_screen_optimized.dart:760-767`

### 4. UI Thread Blocking
- **Issue**: Excessive progress updates and synchronous operations
- **Impact**: UI freezes, appears as crash
- **Location**: Progress callbacks throughout loading process

### 5. Database Transaction Scope
- **Issue**: Long-running operations without intermediate commits
- **Impact**: Transaction timeouts and memory buildup
- **Location**: Database insertion loops

## Solution Strategy

Implement **true streaming architecture** that maintains zero-impact on existing business logic while enabling million-row file support.

## Implementation Phases

### Phase 1: True Streaming File Parser
**Objective**: Eliminate memory overload during file reading
**Impact**: Reduce memory usage from 3-4x file size to < 50MB constant

#### Implementation Steps:

1. **Replace Memory-Intensive Loading**
   ```dart
   // BEFORE (Current):
   final bytes = await file.readAsBytes(); // Loads entire file
   final input = encoding.decode(bytes);   // Decodes entire file
   final rows = csvConverter.convert(input); // Parses entire file

   // AFTER (Streaming):
   await for (final chunk in file.openRead()) {
     // Process chunk by chunk
   }
   ```

2. **Implement Line-by-Line Streaming**
   - Use `File.openRead()` for chunked file access
   - Apply `utf8.decoder.bind()` for encoding handling
   - Implement `LineSplitter` for CSV line boundaries
   - Handle multi-line quoted fields properly

3. **Custom CSV Parser for Streaming**
   - Parse CSV incrementally without loading all data
   - Handle quoted fields, commas, and newlines correctly
   - Maintain same `CsvLoadResult` output format
   - Preserve existing progress callback API

4. **Maintain Existing Database Integration**
   - Keep batch insertion of 5000 rows unchanged
   - Preserve same progress reporting structure
   - Maintain all error handling patterns

#### Files to Modify:
- `lib/services/csv_streaming_service.dart`

### Phase 2: Memory-Efficient History System
**Objective**: Enable undo/redo for million-row files without memory overflow
**Impact**: Reduce history memory from O(rows) to O(1) for large files

#### Implementation Strategy:

1. **Smart Snapshot Thresholding**
   ```dart
   // Full snapshots for < 100k rows (current behavior)
   if (totalRows < 100000) {
     // Store complete dataset (existing logic)
   }
   // Sample-based snapshots for >= 100k rows
   else {
     // Store headers + sample indices + metadata
   }
   ```

2. **Sampling-Based History**
   - Store full headers and row count
   - Store sample row indices for representative data
   - Use database as source-of-truth for full restores
   - Implement delta-based changes tracking

3. **Preserve Undo/Redo API**
   - Keep existing `_canUndo`, `_canRedo` getters
   - Maintain `_historyCursor` navigation
   - Preserve `_handleUndo()`, `_handleRedo()` methods
   - Same user experience for all file sizes

4. **Backward Compatibility**
   - Small files (< 100k rows) work identically to current behavior
   - Large files get optimized history automatically
   - No changes to toolbar undo/redo buttons

#### Files to Modify:
- `lib/screens/csv_reader_screen_optimized.dart`
- `lib/services/csv_history_service.dart`

### Phase 3: UI Responsiveness Improvements
**Objective**: Prevent UI freezing during large file operations
**Impact**: Maintain responsive interface regardless of file size

#### Implementation Steps:

1. **Throttled Progress Updates**
   ```dart
   // Current: Update UI every batch (thousands of times)
   // Improved: Update UI maximum once per second
   DateTime _lastProgressUpdate = DateTime.now();

   void reportProgress(double progress, int rowsLoaded) {
     final now = DateTime.now();
     if (now.difference(_lastProgressUpdate).inMilliseconds >= 1000) {
       setState(() { /* update UI */ });
       _lastProgressUpdate = now;
     }
   }
   ```

2. **Background Isolate Processing**
   - Move CSV parsing to background isolates using `compute()`
   - Keep UI thread free for user interactions
   - Maintain same callback patterns and error handling

3. **Debounced UI State Updates**
   - Batch multiple state changes into single updates
   - Use `WidgetsBinding.instance.addPostFrameCallback` for scheduling
   - Prevent excessive widget rebuilds

4. **Preserve User Experience**
   - Same loading screens and progress indicators
   - Identical error messages and handling
   - No changes to toolbar or status bar behavior

#### Files to Modify:
- `lib/screens/csv_reader_screen_optimized.dart`
- `lib/services/csv_streaming_service.dart`

### Phase 4: Database Transaction Optimizations
**Objective**: Prevent database timeouts and optimize performance
**Impact**: Enable reliable processing of million-row files

#### Implementation Steps:

1. **Chunked Transaction Commits**
   ```dart
   // Insert rows in smaller chunks with intermediate commits
   const transactionChunkSize = 50000;

   for (int i = 0; i < totalBatches; i += transactionChunkSize) {
     final batch = getBatch(i, transactionChunkSize);
     await db.transaction((txn) async {
       for (final row in batch) {
         await txn.insert('csv_data', row);
       }
     });
     // Commit checkpoint
     onProgress?.call(i / totalBatches);
   }
   ```

2. **Optimize SQLite Configuration**
   - Leverage existing WAL mode configuration
   - Adjust cache size for large files
   - Optimize synchronous mode for bulk operations
   - Monitor and adjust based on performance

3. **Progress Persistence**
   - Save loading progress to database
   - Enable resume after app crashes
   - Track failed chunks for retry logic
   - Maintain same progress reporting API

4. **Index Optimization**
   - Preserve existing indexes for query performance
   - Consider deferred index creation for large imports
   - Maintain all existing query methods unchanged

#### Files to Modify:
- `lib/services/csv_database_service.dart`

### Phase 5: Resource Management and Monitoring
**Objective**: Add intelligent resource handling for extreme file sizes
**Impact**: Graceful handling of files up to 10M+ rows

#### Implementation Steps:

1. **Memory Pressure Detection**
   ```dart
   // Monitor available system memory
   final memoryInfo = await getMemoryInfo();
   if (memoryInfo.available < requiredMemory) {
     // Switch to ultra-low-memory mode
   }
   ```

2. **Adaptive Processing Modes**
   - **Normal Mode**: < 500k rows (current behavior)
   - **Optimized Mode**: 500k - 2M rows (streaming + sampling)
   - **Ultra Mode**: > 2M rows (minimal memory + chunked processing)

3. **Pause/Resume Functionality**
   - Allow users to pause large file processing
   - Save state for later resumption
   - Background processing when app is minimized
   - Maintain same loading UI with pause controls

4. **File Size Warnings and Recommendations**
   - Pre-scan files to estimate processing time
   - Warn users about extremely large files
   - Recommend hardware requirements
   - Provide cancelation options

#### Files to Modify:
- `lib/screens/csv_reader_screen_optimized.dart`
- Add new resource monitoring service

## Implementation Guidelines

### Key Principles

1. **Zero Business Logic Changes**
   - All existing APIs preserved exactly
   - Same callbacks, parameters, and return types
   - Identical error handling patterns
   - No changes to user-facing behavior

2. **Backward Compatibility**
   - Current 320k row files work identically
   - All existing features function unchanged
   - Same toolbar, dialogs, and interactions
   - No regression in current functionality

3. **Progressive Enhancement**
   - Large files automatically get optimizations
   - Small files maintain current performance
   - Graceful fallback if optimizations fail
   - Transparent to end users

4. **Memory Efficiency**
   - Constant memory usage regardless of file size
   - Maximum 500MB memory footprint for any file
   - Intelligent garbage collection management
   - Resource cleanup on errors

### Testing Strategy

1. **File Size Testing**
   - 100k rows: Verify identical performance to current
   - 500k rows: Confirm streaming optimizations work
   - 1M rows: Validate no crashes and reasonable performance
   - 2M+ rows: Test ultra-low-memory modes

2. **Memory Profiling**
   - Monitor memory usage throughout loading process
   - Confirm constant memory usage (< 500MB)
   - Test memory cleanup on errors and cancellation
   - Validate no memory leaks in repeated operations

3. **Feature Validation**
   - Undo/redo functionality works for all file sizes
   - Search and filtering operate identically
   - Cell editing and bulk operations unchanged
   - Export functionality preserves all optimizations

4. **Error Handling**
   - Graceful degradation on streaming failures
   - Proper cleanup on partial loading failures
   - Resume capability after crashes
   - User-friendly error messages

## Success Metrics

1. **Performance**
   - 1M row files load without crashing
   - Memory usage stays < 500MB regardless of file size
   - Loading completes in reasonable time (< 5 minutes for 1M rows)

2. **User Experience**
   - UI remains responsive during loading
   - All existing features work identically
   - No regression in current functionality
   - Smooth progress indicators and feedback

3. **Reliability**
   - Graceful handling of corrupted files
   - Recovery from partial loading failures
   - Consistent performance across different systems
   - Robust error handling and recovery

## Timeline

- **Phase 1**: 2-3 days (Streaming parser implementation)
- **Phase 2**: 2-3 days (Memory-efficient history)
- **Phase 3**: 1-2 days (UI responsiveness)
- **Phase 4**: 1-2 days (Database optimizations)
- **Phase 5**: 2-3 days (Resource management)
- **Testing & Refinement**: 3-5 days

**Total Estimated Time**: 11-18 days

This plan ensures million-row CSV support while maintaining complete backward compatibility and zero impact on existing business logic.