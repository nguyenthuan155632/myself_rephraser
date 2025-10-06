# CSV Reader Virtualization TODO

## Current Problem
The DataTable widget renders ALL rows at once, which causes severe performance issues with large files (55k+ rows). The app becomes laggy and unresponsive.

## Solution: Replace DataTable with Custom Virtualized Table

DataTable doesn't support virtualization. We need to build a custom table using `ListView.builder` which only renders visible rows.

### Implementation Steps:

1. **Replace DataTable with ListView.builder**
   - Only renders visible rows (automatic virtualization)
   - Smooth scrolling even with millions of rows
   
2. **Custom Row Widget**
   - Create a `_buildTableRow()` method
   - Use `Container` with borders to mimic table cells
   
3. **Fixed Header**
   - Keep header sticky at top using `Column` with fixed header + scrollable body

### Quick Fix Code Structure:

```dart
// Replace the DataTable section (lines ~304-401) with:

Column(
  children: [
    // Fixed Header
    Container(
      height: 48,
      color: Theme.of(context).colorScheme.primaryContainer.withOpacity(0.5),
      child: Row(
        children: [
          _buildHeaderCell('#', 60),
          ..._headers.map((h) => _buildHeaderCell(h, 150)),
        ],
      ),
    ),
    // Virtualized Body
    Expanded(
      child: ListView.builder(
        controller: _verticalScrollController,
        itemCount: _filteredData.length,
        itemBuilder: (context, index) {
          final row = _filteredData[index];
          final lineNumber = _allCsvData.indexOf(row) + 1;
          return _buildTableRow(lineNumber, row);
        },
      ),
    ),
  ],
)
```

### Benefits:
- ✅ Renders only ~20 visible rows at a time
- ✅ Smooth scrolling with 100k+ rows
- ✅ Low memory footprint
- ✅ Native Flutter virtualization

### Alternative: Use data_table_2 package
- `pub add data_table_2`
- Supports virtualization out of the box
- Drop-in replacement for DataTable

## Current Status
- Data loading: ✅ FIXED (loads all at once, fast)
- Rendering: ✅ FIXED (ListView.builder with virtualization)

## ✅ COMPLETED - Virtualization Implemented!

Replaced DataTable with custom virtualized table using `ListView.builder`:
- Only renders ~20 visible rows at a time
- Smooth scrolling with 100k+ rows
- Fixed header that stays visible
- Synchronized horizontal scrolling
- Line numbers column preserved
- Works perfectly with 55k+ row files

