import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../theme/csv_theme.dart';
import '../services/csv_database_service.dart';

/// Virtual scrolling table for large CSV files
/// Loads only visible rows for optimal performance with 320k+ rows
class VirtualCsvTable extends StatefulWidget {
  final String sessionId;
  final List<String> headers;
  final int totalRows;
  final bool showCheckboxes;
  final bool compactMode;
  final String searchQuery;
  final bool caseSensitive;
  final List<int> searchResults;
  final Set<int> selectedRowIndices;
  final Set<String> selectedCells;
  final Function(int rowIndex) onRowSelectionToggle;
  final Function(int rowIndex, int colIndex) onCellSelectionToggle;
  final Function(int rowIndex, int colIndex, String currentValue) onCellEdit;
  final Function(int columnIndex, String currentName) onColumnRename;
  final Function(int columnIndex) onColumnDelete;
  final Function(int columnIndex)? onColumnDuplicate;
  final Function(int columnIndex)? onColumnAddAfter;
  final Function(int fromIndex, int toIndex) onColumnReorder;
  final Function(int rowIndex) onRowDelete;
  final Function(int rowIndex)? onRowDuplicate;
  final Function(int rowIndex)? onRowInsertBefore;
  final Function(int rowIndex)? onRowInsertAfter;
  final Function(int fromIndex, int toIndex)? onRowReorder;
  final Function(TapDownDetails details, int columnIndex, String text)
      onHeaderContextMenu;
  final Function(TapDownDetails details, int rowIndex) onRowContextMenu;

  const VirtualCsvTable({
    super.key,
    required this.sessionId,
    required this.headers,
    required this.totalRows,
    this.showCheckboxes = false,
    this.compactMode = false,
    this.searchQuery = '',
    this.caseSensitive = false,
    this.searchResults = const [],
    required this.selectedRowIndices,
    required this.selectedCells,
    required this.onRowSelectionToggle,
    required this.onCellSelectionToggle,
    required this.onCellEdit,
    required this.onColumnRename,
    required this.onColumnDelete,
    this.onColumnDuplicate,
    this.onColumnAddAfter,
    required this.onColumnReorder,
    required this.onRowDelete,
    this.onRowDuplicate,
    this.onRowInsertBefore,
    this.onRowInsertAfter,
    this.onRowReorder,
    required this.onHeaderContextMenu,
    required this.onRowContextMenu,
  });

  @override
  State<VirtualCsvTable> createState() => _VirtualCsvTableState();
}

class _VirtualCsvTableState extends State<VirtualCsvTable> {
  final ScrollController _verticalScrollController = ScrollController();
  final ScrollController _horizontalScrollController = ScrollController();
  final List<double> _columnWidths = [];
  double _currentTableWidth = 0;

  // Virtual scrolling state
  final Map<int, List<String>> _rowCache = {};
  static const int _cacheSize = 200; // Cache 200 rows
  static const int _loadAhead = 50; // Load 50 rows ahead
  int _visibleStart = 0;
  int _visibleEnd = 100;
  bool _isLoadingRows = false;
  bool _initialized = false;

  double get _lineNumberColumnWidth {
    if (widget.totalRows == 0) return 60;
    final digits = widget.totalRows.toString().length;
    return (40 + (digits * 10.0)).clamp(60.0, 120.0);
  }

  double get _rowHeight => widget.compactMode ? 32.0 : 72.0;

  @override
  void initState() {
    super.initState();
    _verticalScrollController.addListener(_onScroll);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_initialized) {
      _initializeColumnWidths();
      _loadVisibleRows();
      _initialized = true;
    }
  }

  @override
  void dispose() {
    _verticalScrollController.removeListener(_onScroll);
    _verticalScrollController.dispose();
    _horizontalScrollController.dispose();
    super.dispose();
  }

  @override
  void didUpdateWidget(VirtualCsvTable oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.headers.length != widget.headers.length ||
        _columnWidths.length - 1 != widget.headers.length) {
      _initializeColumnWidths();
    }
    if (oldWidget.sessionId != widget.sessionId ||
        oldWidget.totalRows != widget.totalRows ||
        oldWidget.searchResults != widget.searchResults) {
      _rowCache.clear();
      _loadVisibleRows();
    }
  }

  /// Clear cache and reload - call this after edit operations
  void refreshData() {
    _rowCache.clear();
    _loadVisibleRows();
  }

  void _initializeColumnWidths() {
    _columnWidths.clear();
    _columnWidths.add(_lineNumberColumnWidth);

    final screenWidth = MediaQuery.of(context).size.width;
    final availableWidth = screenWidth -
        (CsvTheme.spacingMd * 2) -
        _lineNumberColumnWidth -
        (widget.showCheckboxes ? 48 : 0) -
        24;

    const minColumnWidth = 150.0;
    final numColumns = widget.headers.length;
    if (numColumns == 0) return;

    final defaultTotalWidth = numColumns * minColumnWidth;
    double columnWidth;

    if (defaultTotalWidth < availableWidth) {
      columnWidth = availableWidth / numColumns;
      columnWidth = columnWidth.clamp(minColumnWidth, 600.0);
    } else {
      columnWidth = minColumnWidth;
    }

    for (int i = 0; i < widget.headers.length; i++) {
      _columnWidths.add(columnWidth);
    }
  }

  void _onScroll() {
    if (_isLoadingRows) return;

    final rowHeight = widget.compactMode ? _rowHeight : 56.0;
    final scrollOffset = _verticalScrollController.offset;
    final viewportHeight = _verticalScrollController.position.viewportDimension;

    final newVisibleStart = (scrollOffset / rowHeight).floor();
    final newVisibleEnd =
        ((scrollOffset + viewportHeight) / rowHeight).ceil() + _loadAhead;

    if (newVisibleStart != _visibleStart || newVisibleEnd != _visibleEnd) {
      setState(() {
        _visibleStart = newVisibleStart.clamp(0, widget.totalRows);
        _visibleEnd = newVisibleEnd.clamp(0, widget.totalRows);
      });
      _loadVisibleRows();
    }
  }

  Future<void> _loadVisibleRows() async {
    if (_isLoadingRows) return;
    _isLoadingRows = true;

    try {
      // Calculate which rows need to be loaded
      final rowsToLoad = <int>[];

      if (widget.searchResults.isNotEmpty) {
        // For filtered results, load based on visible filtered indices
        final filteredRows = widget.searchResults;
        for (int i = _visibleStart;
            i < _visibleEnd && i < filteredRows.length;
            i++) {
          final actualRowIndex = filteredRows[i];
          if (!_rowCache.containsKey(actualRowIndex)) {
            rowsToLoad.add(actualRowIndex);
          }
        }
        debugPrint(
            'Loading filtered rows: visible=$_visibleStart-$_visibleEnd, rowsToLoad=$rowsToLoad');
      } else {
        // For normal view, load sequential range
        for (int i = _visibleStart; i < _visibleEnd; i++) {
          if (!_rowCache.containsKey(i)) {
            rowsToLoad.add(i);
          }
        }
      }

      if (rowsToLoad.isEmpty) {
        _isLoadingRows = false;
        return;
      }

      // Load rows individually to avoid batch issues with non-sequential indices
      for (final rowIndex in rowsToLoad) {
        try {
          final rows = await CsvDatabaseService.getRows(
            widget.sessionId,
            offset: rowIndex,
            limit: 1,
          );

          if (mounted && rows.isNotEmpty) {
            setState(() {
              _rowCache[rowIndex] = rows[0];
            });
          }
        } catch (e) {
          debugPrint('Error loading row $rowIndex: $e');
        }
      }

      // Trim cache if it's too large
      if (_rowCache.length > _cacheSize) {
        _trimCache();
      }
    } catch (e) {
      debugPrint('Error loading rows: $e');
    } finally {
      _isLoadingRows = false;
    }
  }

  void _trimCache() {
    if (_rowCache.length <= _cacheSize) return;

    final keysToRemove = <int>[];
    for (final key in _rowCache.keys) {
      if (key < _visibleStart - _loadAhead || key > _visibleEnd + _loadAhead) {
        keysToRemove.add(key);
      }
    }

    for (final key in keysToRemove) {
      _rowCache.remove(key);
    }
  }

  @override
  Widget build(BuildContext context) {
    final calculatedWidth = _columnWidths.isNotEmpty
        ? _columnWidths.reduce((a, b) => a + b) +
            (widget.showCheckboxes ? 48 : 0)
        : 848.0;

    final screenWidth = MediaQuery.of(context).size.width;
    final maxTableWidth = screenWidth - (CsvTheme.spacingMd * 2);
    final tableWidth =
        calculatedWidth > maxTableWidth ? calculatedWidth : maxTableWidth;
    _currentTableWidth = tableWidth;

    return Container(
      width: tableWidth,
      margin: const EdgeInsets.symmetric(vertical: CsvTheme.spacingMd),
      decoration: BoxDecoration(
        color: CsvTheme.surfaceColor,
        borderRadius: BorderRadius.circular(CsvTheme.radiusLg),
        border: Border.all(color: CsvTheme.borderColor),
        boxShadow: const [CsvTheme.shadowMd],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(CsvTheme.radiusLg),
        child: Scrollbar(
          controller: _horizontalScrollController,
          thumbVisibility: true,
          child: SingleChildScrollView(
            controller: _horizontalScrollController,
            scrollDirection: Axis.horizontal,
            child: SizedBox(
              width: tableWidth,
              child: Column(
                children: [
                  _buildTableHeader(),
                  Expanded(
                    child: Scrollbar(
                      controller: _verticalScrollController,
                      thumbVisibility: true,
                      child: _buildVirtualList(),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildTableHeader() {
    return Container(
      decoration: const BoxDecoration(
        color: CsvTheme.tableHeaderBg,
        border: Border(
          bottom: BorderSide(color: CsvTheme.tableCellBorder, width: 1),
        ),
      ),
      child: Row(
        children: [
          if (widget.showCheckboxes)
            SizedBox(
              width: 48,
              height: 32,
              child: Checkbox(
                value: widget.selectedRowIndices.length == widget.totalRows &&
                    widget.totalRows > 0,
                tristate: true,
                onChanged: (value) {
                  // Toggle all rows (expensive for large datasets, consider alternative)
                },
              ),
            ),
          _buildHeaderCell('#', 0, isPrimary: true),
          ...widget.headers
              .asMap()
              .entries
              .map((entry) => _buildHeaderCell(entry.value, entry.key + 1)),
        ],
      ),
    );
  }

  Widget _buildHeaderCell(String text, int columnIndex,
      {bool isPrimary = false}) {
    final width = _columnWidths.isNotEmpty && columnIndex < _columnWidths.length
        ? _columnWidths[columnIndex]
        : 150.0;

    final dataColumnIndex = columnIndex - 1;

    return DragTarget<int>(
      onWillAccept: (dragged) =>
          !isPrimary && dragged != null && dragged != dataColumnIndex,
      onAccept: (dragged) {
        if (!isPrimary && dragged != dataColumnIndex) {
          widget.onColumnReorder(dragged, dataColumnIndex);
        }
      },
      builder: (context, candidateData, rejectedData) {
        final isHovering = candidateData.isNotEmpty;
        return SizedBox(
          width: width,
          height: 32,
          child: Stack(
            children: [
              Positioned.fill(
                child: Container(
                  decoration: BoxDecoration(
                    color: isHovering
                        ? CsvTheme.primaryLight.withOpacity(0.4)
                        : Colors.transparent,
                    border: Border(
                      right: const BorderSide(
                          color: CsvTheme.tableCellBorder, width: 1),
                      left: isHovering
                          ? const BorderSide(
                              color: CsvTheme.primaryColor, width: 2)
                          : BorderSide.none,
                    ),
                  ),
                  child: isPrimary
                      ? Center(
                          child: Text(
                            text,
                            style: CsvTheme.labelMedium.copyWith(
                              color: CsvTheme.primaryColor,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        )
                      : LongPressDraggable<int>(
                          data: dataColumnIndex,
                          feedback: Material(
                            elevation: 4,
                            child: Container(
                              width: width,
                              height: 32,
                              padding: const EdgeInsets.symmetric(
                                horizontal: CsvTheme.spacingMd,
                                vertical: CsvTheme.spacingSm,
                              ),
                              color: CsvTheme.surfaceColor,
                              child: Row(
                                children: [
                                  Icon(
                                    Icons.drag_indicator,
                                    size: 16,
                                    color: CsvTheme.textTertiary,
                                  ),
                                  const SizedBox(width: 4),
                                  Expanded(
                                    child: Text(
                                      text,
                                      style: CsvTheme.labelMedium.copyWith(
                                        color: CsvTheme.textSecondary,
                                        fontWeight: FontWeight.w600,
                                      ),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                          childWhenDragging: Opacity(
                            opacity: 0.4,
                            child: _buildHeaderContent(text),
                          ),
                          child: InkWell(
                            onDoubleTap: () =>
                                widget.onColumnRename(dataColumnIndex, text),
                            onSecondaryTapDown: (details) =>
                                widget.onHeaderContextMenu(
                                    details, dataColumnIndex, text),
                            child: _buildHeaderContent(text),
                          ),
                        ),
                ),
              ),
              if (!isPrimary)
                Positioned(
                  right: 0,
                  top: 0,
                  bottom: 0,
                  child: MouseRegion(
                    cursor: SystemMouseCursors.resizeColumn,
                    child: GestureDetector(
                      behavior: HitTestBehavior.translucent,
                      onHorizontalDragUpdate: (details) {
                        if (columnIndex < _columnWidths.length) {
                          setState(() {
                            final newWidth =
                                _columnWidths[columnIndex] + details.delta.dx;
                            _columnWidths[columnIndex] =
                                newWidth.clamp(80.0, 800.0);
                          });
                        }
                      },
                      child: Container(
                        width: 8,
                        alignment: Alignment.center,
                        child: Container(
                          width: 1,
                          color: CsvTheme.tableCellBorder,
                        ),
                      ),
                    ),
                  ),
                ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildHeaderContent(String text) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: CsvTheme.spacingMd,
        vertical: CsvTheme.spacingSm,
      ),
      alignment: Alignment.centerLeft,
      child: Row(
        children: [
          Icon(
            Icons.drag_indicator,
            size: 16,
            color: CsvTheme.textTertiary,
          ),
          const SizedBox(width: 4),
          Expanded(
            child: Text(
              text,
              style: CsvTheme.labelMedium.copyWith(
                color: CsvTheme.textSecondary,
                fontWeight: FontWeight.w600,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildVirtualList() {
    // Filter rows based on search results
    final filteredRows = widget.searchResults.isNotEmpty
        ? widget.searchResults
        : List.generate(widget.totalRows, (i) => i);

    return ListView.builder(
      key: ValueKey<bool>(widget.compactMode),
      controller: _verticalScrollController,
      itemCount: filteredRows.length,
      itemExtent: widget.compactMode ? _rowHeight : null,
      cacheExtent: 1000,
      addRepaintBoundaries: true,
      itemBuilder: (context, index) {
        final actualRowIndex = filteredRows[index];
        final lineNumber = actualRowIndex + 1;
        final row = _rowCache[actualRowIndex];

        if (row == null) {
          // Show placeholder while loading
          return _buildPlaceholderRow(lineNumber);
        }

        return _buildDataRow(lineNumber, row, actualRowIndex);
      },
    );
  }

  Widget _buildPlaceholderRow(int lineNumber) {
    final isEvenRow = (lineNumber - 1) % 2 == 0;
    final baseColor = isEvenRow ? CsvTheme.tableRowEven : CsvTheme.tableRowOdd;

    return Container(
      constraints: widget.compactMode
          ? BoxConstraints.tightFor(height: _rowHeight)
          : const BoxConstraints(minHeight: 56.0),
      color: baseColor,
      child: Row(
        children: [
          if (widget.showCheckboxes) const SizedBox(width: 48),
          _buildLineNumberCell(lineNumber),
          Expanded(
            child: Center(
              child: SizedBox(
                width: 16,
                height: 16,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  valueColor:
                      AlwaysStoppedAnimation<Color>(CsvTheme.textTertiary),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDataRow(int lineNumber, List<String> row, int rowIndex) {
    final canReorderRows = widget.onRowReorder != null;

    Widget buildRow({bool isHovering = false}) {
      final isSelected = widget.selectedRowIndices.contains(rowIndex);
      final isEvenRow = rowIndex % 2 == 0;
      Color backgroundColor = isSelected
          ? CsvTheme.tableRowSelected
          : isEvenRow
              ? CsvTheme.tableRowEven
              : CsvTheme.tableRowOdd;

      if (isHovering && !isSelected) {
        backgroundColor = CsvTheme.tableRowHover;
      }

      return Container(
        height: widget.compactMode ? _rowHeight : null,
        constraints: widget.compactMode
            ? null
            : const BoxConstraints(minHeight: 56.0),
        decoration: BoxDecoration(
          color: backgroundColor,
          border: const Border(
            bottom: BorderSide(color: CsvTheme.tableCellBorder, width: 1),
          ),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            if (widget.showCheckboxes)
              SizedBox(
                width: 48,
                child: Center(
                  child: Checkbox(
                    value: isSelected,
                    onChanged: (value) {
                      widget.onRowSelectionToggle(rowIndex);
                    },
                  ),
                ),
              ),
            _buildLineNumberCell(lineNumber),
            ...List.generate(widget.headers.length, (colIndex) {
              final cell = colIndex < row.length ? row[colIndex] : '';
              return _buildDataCell(cell, rowIndex, colIndex);
            }),
          ],
        ),
      );
    }

    if (!canReorderRows) {
      return buildRow();
    }

    return DragTarget<int>(
      onWillAccept: (dragged) => dragged != null && dragged != rowIndex,
      onAccept: (dragged) {
        if (dragged != rowIndex) {
          widget.onRowReorder?.call(dragged, rowIndex);
        }
      },
      builder: (context, candidate, rejected) {
        final isHovering = candidate.isNotEmpty;
        final rowWidget = buildRow(isHovering: isHovering);

        return LongPressDraggable<int>(
          data: rowIndex,
          axis: Axis.vertical,
          feedback: Material(
            elevation: 6,
            child: ConstrainedBox(
              constraints: BoxConstraints(
                minWidth: _currentTableWidth,
                maxWidth: _currentTableWidth,
              ),
              child: buildRow(),
            ),
          ),
          childWhenDragging: Opacity(
            opacity: 0.4,
            child: buildRow(),
          ),
          child: rowWidget,
        );
      },
    );
  }

  Widget _buildLineNumberCell(int lineNumber) {
    final width =
        _columnWidths.isNotEmpty ? _columnWidths[0] : _lineNumberColumnWidth;
    final verticalPadding = widget.compactMode ? 4.0 : 12.0;

    return GestureDetector(
      onSecondaryTapDown: (details) {
        widget.onRowContextMenu(details, lineNumber - 1);
      },
      child: Container(
        width: width,
        padding: EdgeInsets.symmetric(
          horizontal: CsvTheme.spacingMd,
          vertical: verticalPadding,
        ),
        decoration: const BoxDecoration(
          border: Border(
            right: BorderSide(color: CsvTheme.tableCellBorder, width: 1),
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.drag_indicator,
              size: 16,
              color: CsvTheme.textTertiary,
            ),
            const SizedBox(width: 4),
            Text(
              lineNumber.toString(),
              style: CsvTheme.bodyExtraSmall.copyWith(
                color: CsvTheme.textTertiary,
                fontWeight: FontWeight.w500,
                fontFeatures: const [FontFeature.tabularFigures()],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDataCell(String content, int rowIndex, int colIndex) {
    final columnIndex = colIndex + 1;
    final width = _columnWidths.isNotEmpty && columnIndex < _columnWidths.length
        ? _columnWidths[columnIndex]
        : 150.0;
    final cellKey = '$rowIndex:$colIndex';
    final isCellSelected = widget.selectedCells.contains(cellKey);

    // Check if this cell matches search query
    final hasSearchMatch =
        widget.searchQuery.isNotEmpty && _cellMatchesSearch(content);

    final verticalPadding = widget.compactMode ? 4.0 : 12.0;
    final textStyle = CsvTheme.bodyExtraSmall.copyWith(
      color: CsvTheme.textPrimary,
    );
    final maxLines = widget.compactMode ? 1 : null;
    final overflow = widget.compactMode
        ? TextOverflow.ellipsis
        : TextOverflow.visible;

    return GestureDetector(
      onTap: () {
        if (HardwareKeyboard.instance.isMetaPressed ||
            HardwareKeyboard.instance.isControlPressed) {
          widget.onCellSelectionToggle(rowIndex, colIndex);
        }
      },
      onDoubleTap: () {
        widget.onCellEdit(rowIndex, colIndex, content);
      },
      child: Container(
        width: width,
        padding: EdgeInsets.symmetric(
          horizontal: CsvTheme.spacingSm,
          vertical: verticalPadding,
        ),
        decoration: BoxDecoration(
          color: isCellSelected
              ? CsvTheme.primaryLight
              : hasSearchMatch
                  ? CsvTheme.warningLight
                  : null,
          border: Border(
            right: const BorderSide(color: CsvTheme.tableCellBorder, width: 1),
            left: isCellSelected
                ? const BorderSide(color: CsvTheme.primaryColor, width: 2)
                : hasSearchMatch
                    ? const BorderSide(color: CsvTheme.warningColor, width: 2)
                    : BorderSide.none,
            top: isCellSelected
                ? const BorderSide(color: CsvTheme.primaryColor, width: 2)
                : BorderSide.none,
            bottom: isCellSelected
                ? const BorderSide(color: CsvTheme.primaryColor, width: 2)
                : BorderSide.none,
          ),
        ),
        child: Align(
          alignment: Alignment.centerLeft,
          child: Text(
            content,
            style: textStyle,
            maxLines: maxLines,
            overflow: overflow,
            softWrap: true,
          ),
        ),
      ),
    );
  }

  bool _cellMatchesSearch(String content) {
    if (widget.searchQuery.isEmpty) return false;

    final searchTerm = widget.caseSensitive
        ? widget.searchQuery
        : widget.searchQuery.toLowerCase();
    final cellContent = widget.caseSensitive ? content : content.toLowerCase();

    return cellContent.contains(searchTerm);
  }
}
