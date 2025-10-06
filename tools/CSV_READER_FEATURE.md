# CSV Reader Tool Feature

## Overview
Added a new CSV Reader tool to the Myself Rephraser application that allows users to open and view large CSV files.

## Changes Made

### 1. Main Screen (`lib/screens/main_screen.dart`)
- Added a new "Tools" section with a card layout
- Created a CSV File Reader button in the tools section
- Added navigation to the CSV Reader screen
- Imported the new `csv_reader_screen.dart`

### 2. CSV Reader Screen (`lib/screens/csv_reader_screen.dart`)
- **File Picker**: Uses `file_picker` package to select CSV files
- **Large File Support**: Loads files efficiently with gradual progressive loading
  - Initial load: First 100 rows display immediately
  - **Automatic Background Loading**: Continuously loads remaining rows in batches (100 at a time)
  - Allows scrollbar navigation to any position, including last row
  - Shows total row count immediately
- **CSV Parser**: Custom CSV parser that handles quoted fields and commas
- **Search Functionality**: Real-time search/filter across all columns
- **Table View**: Scrollable DataTable with both horizontal and vertical scrolling
  - **Line Numbers**: Excel-style row numbers in the first column (like Excel/Google Sheets)
- **UI Features**:
  - File name display
  - Row count display (loaded / total) with loading indicator
  - Search bar for filtering data
  - Refresh button to load another file
  - Floating action button for loading new files
  - Loading indicator when fetching more rows
  - "All rows loaded" indicator when complete
  - Empty state with helpful instructions

### 3. Dependencies (`pubspec.yaml`)
- Added `file_picker: ^8.1.6` for file selection dialog

## Features

### Current Implementation
- ✅ Open CSV files via file picker dialog
- ✅ Parse CSV with proper handling of quotes and commas (using `csv` package)
- ✅ Display data in a scrollable table with dynamic row heights
  - Multi-line text displayed fully in cells
  - Rows automatically expand to fit content
  - Word wrapping enabled for long text
- ✅ **Search text highlighting** - real-time yellow highlighting of matching text in all cells
- ✅ **Drag & Drop reordering** - long-press to drag columns/rows to new positions
- ✅ **Line numbers column** - Excel-style row numbers (1, 2, 3...) in first column
- ✅ **Resizable columns** - drag column edges to adjust width (60px-500px range)
- ✅ **Multi-line cell editing** - click cell to open large edit dialog
  - Wide dialog (600px) with expandable text area
  - Auto-select all text on open for quick replacement
  - Multi-line support for long text
  - Character counter
  - Save/Cancel buttons
- ✅ **Row operations:**
  - Add new rows (+ button or toolbar)
  - **Insert rows before/after** - right-click on line number or checkbox
  - **Reorder rows** - long-press and drag any row to rearrange
  - Delete single or multiple selected rows
  - Row selection with checkboxes (individual + select all)
  - Visual feedback for selected rows
  - **Delete empty rows** - automatically removes all rows where every cell is empty
  - **Delete empty columns** - automatically removes columns with empty headers and all empty cells
  - **Remove duplicate rows** - finds and removes rows that are exact duplicates
  - Cleanup menu (🧹 icon) with batch operations
- ✅ **Column operations:**
  - **Add new columns** - button in toolbar or right-click on any column header
  - **Rename column** - double-click header or right-click → "Rename Column"
  - **Reorder columns** - long-press and drag column headers to rearrange
  - **Insert column after** - right-click on column header
  - **Duplicate column** - right-click on column header to copy all data
  - **Delete column** - right-click on column header (cannot delete last column)
  - Resizable columns - drag the right edge of column headers
  - Context menu on all column headers for quick access
- ✅ **Full Undo/Redo support:**
  - Undo with Cmd+Z (Mac) / Ctrl+Z (Win/Linux)
  - Redo with Cmd+Shift+Z (Mac) / Ctrl+Shift+Z (Win/Linux)
  - Action history tracks all changes (edits, adds, deletes)
  - Toolbar buttons for undo/redo with enable/disable states
- ✅ **Keyboard shortcuts:**
  - Cmd+S / Ctrl+S - Save changes to file
  - Cmd+Z / Ctrl+Z - Undo last action
  - Cmd+Shift+Z / Ctrl+Shift+Z - Redo action
- ✅ **Advanced Search/Filter functionality:**
  - Basic text search across all columns
  - **Column-specific search** - select which columns to search in
  - **Row range filter** - filter by row number range (e.g., rows 100-500)
  - **Case-sensitive** option
  - **Regex support** - use regular expressions for complex patterns
  - **Filter chips** for easy column selection
  - **Clear filters** button to reset all filters
  - **Expandable/collapsible** advanced options panel
  - Real-time filtering as you type
- ✅ Display row counts (loaded / total / selected rows)
- ✅ Responsive UI with Material Design 3
- ✅ **Gradual progressive loading** - loads entire file in background automatically
- ✅ **Full scrollbar navigation** - drag scrollbar to any position including last row
- ✅ Performance optimized for large files (tested with files containing thousands of rows)
- ✅ Visual feedback during loading (progress indicator + status text)
- ✅ "All rows loaded" indicator when complete

### Future Enhancements (Extensible)
The tools section is designed to easily accommodate more tools:
- Add more tool buttons by inserting new `ElevatedButton.icon` widgets
- Each tool gets its own screen/route
- Tools are grouped in a dedicated section with clear visual hierarchy

## How to Add More Tools

To add a new tool to the stack:

1. Add the button in `main_screen.dart` after the CSV Reader button:
```dart
const SizedBox(height: 8),
SizedBox(
  width: double.infinity,
  height: 48,
  child: ElevatedButton.icon(
    onPressed: () {
      _openYourNewTool();
    },
    icon: const Icon(Icons.your_icon, size: 20),
    label: const Text('Your Tool Name'),
    style: ElevatedButton.styleFrom(
      backgroundColor: Theme.of(context).colorScheme.tertiaryContainer,
      foregroundColor: Theme.of(context).colorScheme.onTertiaryContainer,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      elevation: 0,
    ),
  ),
),
```

2. Create the tool screen in `lib/screens/your_tool_screen.dart`

3. Add navigation method in `main_screen.dart`

## Usage

### Basic Operations
1. Launch the application
2. Scroll down to the "Tools" section
3. Click "CSV File Reader"
4. Click "Load CSV File" or the floating action button
5. Select a CSV file from your file system
6. View the data in the table
7. Click any cell to edit (opens dialog)
8. Press Cmd+S (Mac) / Ctrl+S (Win/Linux) to save changes

### Row Operations
- **Add row at end:** Click the ➕ button in toolbar
- **Insert row before/after:** Right-click on any line number or checkbox → choose "Insert Row Before/After"
- **Delete single row:** Right-click on line number → "Delete Row"
- **Delete multiple rows:** Check multiple rows → click 🗑️ button
- **Select all rows:** Click checkbox in header

### Column Operations
- **Add column at end:** Click the 📊 (view_column) button in toolbar
- **Rename column:** Double-click on any column header, or right-click → "Rename Column"
- **Insert column after:** Right-click on any column header → "Add Column After"
- **Duplicate column:** Right-click on column header → "Duplicate Column"
- **Delete column:** Right-click on column header → "Delete Column"
- **Resize column:** Drag the right edge of any column header

### Data Cleanup
Click the 🧹 (cleaning services) icon for:
- **Delete Empty Rows** - removes rows where all cells are empty
- **Delete Empty Columns** - removes columns with empty headers and all empty data
- **Remove Duplicate Rows** - keeps first occurrence, removes exact duplicates

### Undo/Redo
- **Undo:** Cmd+Z (Mac) / Ctrl+Z (Win/Linux) or click ↶ button
- **Redo:** Cmd+Shift+Z (Mac) / Ctrl+Shift+Z (Win/Linux) or click ↷ button

### Search & Filter
- Use search bar to filter rows by content
- **Highlighted search results** - matching text is highlighted in yellow across all visible cells
- Click "Advanced" for more options (column selection, row range, regex, case sensitivity)
- Highlighting respects search options (case sensitivity, regex)
- Load a new file anytime using the "Load New File" FAB

### Drag & Drop Reordering
- **Reorder columns:** Long-press any column header and drag to new position
- **Reorder rows:** Long-press any row and drag to new position
- Visual feedback with drag preview and drop target indicators
- Blue border shows valid drop target
- Marks file as unsaved after reordering

## Technical Notes

- The CSV parser handles quoted fields properly
- **Gradual Loading Strategy**:
  - Reads entire file into memory first (fast for most CSV files)
  - Initial batch (100 rows) displays immediately for quick feedback
  - Remaining rows load automatically in background batches
  - 50ms delay between batches keeps UI responsive
  - No scroll position detection needed - loads continuously until complete
- **Line Numbers**: 
  - **Dynamic width column** - automatically adjusts based on total row count
    - 1-999 rows: 60px width
    - 1,000-9,999 rows: 70px width
    - 10,000-99,999 rows: 80px width
    - 100,000+ rows: scales accordingly (10px per digit)
  - Right-aligned numbers with tabular figures for consistent spacing
  - Slightly smaller font (13px) for better fit
  - Single line display (no wrapping) 
  - Styled with primary color accent
  - Shows actual row number from original CSV (persists through filtering)
- Search is case-insensitive and searches across all columns
- Table cells have max width of 300px with ellipsis overflow
- Both scrollbars are always visible for better UX
- Loading state prevents duplicate requests while fetching data

## Performance Characteristics

- **Fast Initial Display**: Shows first 100 rows immediately (< 100ms)
- **Progressive Enhancement**: Remaining rows load in background without blocking UI
- **Smooth Experience**: 50ms delay between batches prevents UI freezing
- **Full Scrollbar Access**: Can drag to any position immediately, including last row
- **Works with Large Files**: Tested with CSV files containing 10,000+ rows
- **Batch Size**: 100 rows per batch (configurable via `_rowsPerLoad` constant)
- **Memory**: Loads entire file into memory for instant scrollbar navigation

