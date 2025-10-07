# Testing Large CSV Performance

## Quick Start Guide

### Testing with Your 320k+ Row CSV File

1. **Build and Run the Application**
   ```bash
   cd /Users/thuan.nv/workspaces/myself_rephraser
   flutter run -d macos
   ```

2. **Open CSV Reader**
   - Click on "CSV File Reader" button in the main screen
   - Or navigate to Tools → CSV File Reader

3. **Load Your Large CSV File**
   - Click "Open CSV File" or drag & drop your CSV file
   - Watch the progress bar - it will show:
     - Percentage loaded (0% - 100%)
     - Number of rows loaded in real-time
   - For 320k rows, expect ~30 seconds load time

4. **Verify Optimized Mode**
   - Once loaded, look for the green "OPTIMIZED MODE" badge in the title bar
   - This confirms the optimized engine is active

### Performance Testing Checklist

#### ✅ Loading Performance
- [ ] File loads with visible progress bar
- [ ] UI remains responsive during loading
- [ ] Progress updates smoothly (no freezing)
- [ ] Memory usage stays under 100MB (check Activity Monitor)

#### ✅ Scrolling Performance
- [ ] Scroll to top of file - should be instant
- [ ] Scroll to middle (row ~160k) - should be smooth
- [ ] Scroll to bottom (row 320k) - should be instant
- [ ] Use scroll bar to jump to random positions - no lag
- [ ] FPS should stay at 60 (use Flutter DevTools)

#### ✅ Data Operations
- [ ] Double-click a cell to edit - opens dialog instantly
- [ ] Edit cell value and save - updates immediately
- [ ] Select multiple cells with Cmd+Click - no delay
- [ ] Search for a term - results appear quickly
- [ ] Toggle compact mode - instant refresh

#### ✅ Memory Efficiency
- [ ] Initial load memory spike < 200MB
- [ ] Stable memory usage after load (~40-60MB)
- [ ] Scrolling doesn't increase memory significantly
- [ ] Memory stays constant even after 5+ minutes of use

### Performance Benchmarks (Expected)

| Operation | Expected Time | Pass Criteria |
|-----------|--------------|---------------|
| Load 320k rows | 25-40s | Progress visible, no freeze |
| Scroll to row 1 | <100ms | Instant |
| Scroll to row 320k | <100ms | Instant |
| Jump to middle | <200ms | Smooth transition |
| Edit single cell | <500ms | Dialog opens immediately |
| Search 320k rows | <2s | Results visible |
| Save file | 30-60s | Progress visible |

### Comparison Test

To see the improvement, you can compare with the old implementation:

1. **Old Implementation** (for files <100k rows only):
   - Edit `lib/screens/main_screen.dart`
   - Change import to `csv_reader_screen_modern.dart`
   - Try loading a 50k row file - notice the delay

2. **New Implementation** (current):
   - Handles 320k+ rows effortlessly
   - Same responsive behavior for any file size

### Generating Test CSV Files

If you need test files of specific sizes:

**Option 1: Online Generator**
- Visit: https://www.mockaroo.com/
- Set rows to 320,000
- Add 10-20 columns with various data types
- Download as CSV

**Option 2: Python Script**
```python
import csv
import random
import string

def generate_csv(filename, rows=320000, cols=10):
    with open(filename, 'w', newline='') as f:
        writer = csv.writer(f)
        
        # Headers
        headers = [f'Column_{i+1}' for i in range(cols)]
        writer.writerow(headers)
        
        # Data
        for _ in range(rows):
            row = [
                ''.join(random.choices(string.ascii_letters + string.digits, k=20))
                for _ in range(cols)
            ]
            writer.writerow(row)
    
    print(f"Generated {filename} with {rows} rows")

# Generate test file
generate_csv('test_320k.csv', 320000, 15)
```

**Option 3: Command Line (macOS/Linux)**
```bash
# Generate 320k row CSV with 10 columns
seq 1 320000 | awk '{printf "%d", $1; for(i=2;i<=10;i++) printf ",%d", int(rand()*1000); print ""}' > test_320k.csv
```

### Memory Monitoring

**Using Activity Monitor (macOS):**
1. Open Activity Monitor
2. Find "myself_rephraser" or "flutter" process
3. Watch "Memory" column during:
   - Initial load
   - Scrolling
   - Editing operations
4. Expected: 40-80MB stable, peaks to 150MB during load

**Using Flutter DevTools:**
```bash
# Open DevTools
flutter pub global activate devtools
flutter pub global run devtools

# Run app with DevTools
flutter run -d macos --observatory-port=9100
```
Then open browser to http://localhost:9100 and monitor:
- Memory timeline
- Widget rebuild count
- FPS during scrolling

### Known Limitations in Optimized Mode

The following features are **not yet implemented** in optimized mode:

- ❌ Column deletion (shows message)
- ❌ Row insertion (shows message)
- ❌ Undo/Redo (disabled)
- ❌ Merge rows (disabled)
- ❌ Split rows (disabled)
- ❌ Bulk operations (disabled)

These work fine in the old mode for smaller files (<100k rows).

### Troubleshooting

**Problem: "Loading CSV file..." stuck at 0%**
- Solution: Check file permissions, try different file
- Check: Terminal/console for error messages

**Problem: High memory usage (>500MB)**
- Solution: Close and reopen app
- Check: Are multiple CSV files open?

**Problem: Scrolling is laggy**
- Solution: Toggle compact mode, restart app
- Check: Is search filter active? Clear filters

**Problem: "OPTIMIZED MODE" badge not showing**
- Solution: File might be <100k rows (both modes work)
- Check: Status bar shows total row count

**Problem: Can't save changes**
- Solution: Make sure file is not read-only
- Check: File permissions in Finder

### Reporting Performance Issues

If you encounter performance issues, please provide:

1. **File Details**
   - Number of rows
   - Number of columns
   - File size in MB
   - Any special characters or encoding

2. **System Info**
   - macOS version
   - Available RAM
   - CPU model

3. **Performance Metrics**
   - Load time
   - Memory usage (Activity Monitor)
   - Specific operation that's slow

4. **Screenshots**
   - Progress bar (if stuck)
   - Memory usage graph
   - Any error messages

### Success Criteria

Your implementation is working correctly if:

✅ 320k row file loads in under 60 seconds  
✅ Memory stays under 100MB after loading  
✅ Scrolling is smooth (60 FPS) at any position  
✅ Cell editing opens dialog in under 500ms  
✅ Application remains responsive during all operations  
✅ No crashes or freezes during normal use  

## Additional Resources

- **Main Documentation**: `LARGE_CSV_OPTIMIZATION.md`
- **Architecture**: See database schema in documentation
- **Code**: Check `lib/services/csv_database_service.dart` for implementation details

---

**Happy Testing! 🚀**

If you successfully load and interact with a 320k+ row CSV file smoothly, the optimization is working as designed!
