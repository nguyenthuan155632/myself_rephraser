import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'dart:ui';
import '../theme/csv_theme.dart';

/// Helper widgets for CSV table rendering

/// Builds highlighted text with search query highlighting
class HighlightedText extends StatelessWidget {
  final String text;
  final String searchQuery;
  final bool caseSensitive;
  final bool useRegex;

  const HighlightedText({
    super.key,
    required this.text,
    required this.searchQuery,
    this.caseSensitive = false,
    this.useRegex = false,
  });

  @override
  Widget build(BuildContext context) {
    if (searchQuery.isEmpty || text.isEmpty) {
      return Text(
        text,
        softWrap: true,
        style: CsvTheme.bodyExtraSmall,
      );
    }

    try {
      List<TextSpan> spans = [];
      String searchPattern = searchQuery;
      String textToSearch = text;

      if (!caseSensitive) {
        searchPattern = searchPattern.toLowerCase();
        textToSearch = textToSearch.toLowerCase();
      }

      int lastMatchEnd = 0;

      if (useRegex) {
        final regex = RegExp(searchPattern, caseSensitive: caseSensitive);
        for (final match in regex.allMatches(textToSearch)) {
          if (match.start > lastMatchEnd) {
            spans
                .add(TextSpan(text: text.substring(lastMatchEnd, match.start)));
          }
          spans.add(TextSpan(
            text: text.substring(match.start, match.end),
            style: const TextStyle(
              backgroundColor: Color(0xFFFFEB3B), // Bright yellow highlight
              fontWeight: FontWeight.w600,
              color: CsvTheme.textPrimary,
            ),
          ));
          lastMatchEnd = match.end;
        }
      } else {
        int startIndex = 0;
        while (true) {
          final index = textToSearch.indexOf(searchPattern, startIndex);
          if (index == -1) break;

          if (index > lastMatchEnd) {
            spans.add(TextSpan(text: text.substring(lastMatchEnd, index)));
          }
          spans.add(TextSpan(
            text: text.substring(index, index + searchQuery.length),
            style: const TextStyle(
              backgroundColor: Color(0xFFFFEB3B), // Bright yellow highlight
              fontWeight: FontWeight.w600,
              color: CsvTheme.textPrimary,
            ),
          ));
          lastMatchEnd = index + searchQuery.length;
          startIndex = lastMatchEnd;
        }
      }

      if (lastMatchEnd < text.length) {
        spans.add(TextSpan(text: text.substring(lastMatchEnd)));
      }

      return RichText(
        text: TextSpan(
          style: CsvTheme.bodyExtraSmall,
          children: spans.isEmpty ? [TextSpan(text: text)] : spans,
        ),
      );
    } catch (e) {
      return Text(
        text,
        softWrap: true,
        style: CsvTheme.bodyExtraSmall,
      );
    }
  }
}

/// Header cell widget for CSV table
class HeaderCell extends StatelessWidget {
  final String text;
  final int columnIndex;
  final double width;
  final bool isPrimary;
  final bool isResizing;
  final bool isDropTarget;
  final Function(int, double)? onResizeStart;
  final Function(double)? onResizeUpdate;
  final Function()? onResizeEnd;
  final VoidCallback? onRename;
  final VoidCallback? onAddAfter;
  final VoidCallback? onDuplicate;
  final VoidCallback? onDelete;

  const HeaderCell({
    super.key,
    required this.text,
    required this.columnIndex,
    required this.width,
    this.isPrimary = false,
    this.isResizing = false,
    this.isDropTarget = false,
    this.onResizeStart,
    this.onResizeUpdate,
    this.onResizeEnd,
    this.onRename,
    this.onAddAfter,
    this.onDuplicate,
    this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    Widget headerContent = SizedBox(
      width: width,
      height: 48,
      child: Stack(
        children: [
          // Header content with context menu
          GestureDetector(
            onSecondaryTapDown: !isPrimary
                ? (details) {
                    showMenu(
                      context: context,
                      position: RelativeRect.fromLTRB(
                        details.globalPosition.dx,
                        details.globalPosition.dy,
                        details.globalPosition.dx,
                        details.globalPosition.dy,
                      ),
                      items: [
                        const PopupMenuItem(
                          value: 'rename',
                          child: Row(
                            children: [
                              Icon(Icons.edit),
                              SizedBox(width: 8),
                              Text('Rename Column'),
                            ],
                          ),
                        ),
                        const PopupMenuItem(
                          value: 'add_after',
                          child: Row(
                            children: [
                              Icon(Icons.add_box),
                              SizedBox(width: 8),
                              Text('Add Column After'),
                            ],
                          ),
                        ),
                        const PopupMenuItem(
                          value: 'duplicate',
                          child: Row(
                            children: [
                              Icon(Icons.content_copy),
                              SizedBox(width: 8),
                              Text('Duplicate Column'),
                            ],
                          ),
                        ),
                        const PopupMenuItem(
                          value: 'delete',
                          child: Row(
                            children: [
                              Icon(Icons.delete),
                              SizedBox(width: 8),
                              Text('Delete Column'),
                            ],
                          ),
                        ),
                      ],
                    ).then((value) {
                      if (value == 'rename') onRename?.call();
                      if (value == 'add_after') onAddAfter?.call();
                      if (value == 'duplicate') onDuplicate?.call();
                      if (value == 'delete') onDelete?.call();
                    });
                  }
                : null,
            onDoubleTap: !isPrimary ? onRename : null,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              alignment:
                  isPrimary ? Alignment.centerRight : Alignment.centerLeft,
              decoration: BoxDecoration(
                border: Border(
                  right: BorderSide(
                    color:
                        Theme.of(context).colorScheme.outline.withOpacity(0.2),
                  ),
                ),
              ),
              child: Text(
                text,
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color:
                      isPrimary ? Theme.of(context).colorScheme.primary : null,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ),
          // Resize handle
          if (!isPrimary)
            Positioned(
              right: 0,
              top: 0,
              bottom: 0,
              child: MouseRegion(
                cursor: SystemMouseCursors.resizeColumn,
                child: GestureDetector(
                  onPanStart: (details) => onResizeStart?.call(
                      columnIndex, details.globalPosition.dx),
                  onPanUpdate: (details) =>
                      onResizeUpdate?.call(details.globalPosition.dx),
                  onPanEnd: (details) => onResizeEnd?.call(),
                  child: Container(
                    width: 8,
                    color: Colors.transparent,
                    child: Center(
                      child: Container(
                        width: 2,
                        color: isResizing
                            ? Theme.of(context).colorScheme.primary
                            : Theme.of(context)
                                .colorScheme
                                .outline
                                .withOpacity(0.3),
                      ),
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );

    if (isDropTarget) {
      return Container(
        decoration: BoxDecoration(
          border: Border.all(
            color: Theme.of(context).colorScheme.primary,
            width: 2,
          ),
        ),
        child: headerContent,
      );
    }

    return headerContent;
  }
}

/// Data cell widget for CSV table
class DataCell extends StatelessWidget {
  final String text;
  final double width;
  final bool isSelected;
  final String searchQuery;
  final bool caseSensitive;
  final bool useRegex;
  final VoidCallback? onTap;

  const DataCell({
    super.key,
    required this.text,
    required this.width,
    this.isSelected = false,
    this.searchQuery = '',
    this.caseSensitive = false,
    this.useRegex = false,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: width,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected
              ? Theme.of(context).colorScheme.primaryContainer.withOpacity(0.5)
              : null,
          border: Border(
            right: BorderSide(
              color: Theme.of(context).colorScheme.outline.withOpacity(0.2),
            ),
            top: isSelected
                ? BorderSide(
                    color: Theme.of(context).colorScheme.primary,
                    width: 2,
                  )
                : BorderSide.none,
            bottom: isSelected
                ? BorderSide(
                    color: Theme.of(context).colorScheme.primary,
                    width: 2,
                  )
                : BorderSide.none,
            left: isSelected
                ? BorderSide(
                    color: Theme.of(context).colorScheme.primary,
                    width: 2,
                  )
                : BorderSide.none,
          ),
        ),
        child: Align(
          alignment: Alignment.centerLeft,
          child: HighlightedText(
            text: text,
            searchQuery: searchQuery,
            caseSensitive: caseSensitive,
            useRegex: useRegex,
          ),
        ),
      ),
    );
  }
}

/// Line number cell widget
class LineNumberCell extends StatelessWidget {
  final int lineNumber;
  final double width;
  final VoidCallback? onInsertBefore;
  final VoidCallback? onInsertAfter;
  final VoidCallback? onDelete;

  const LineNumberCell({
    super.key,
    required this.lineNumber,
    required this.width,
    this.onInsertBefore,
    this.onInsertAfter,
    this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onSecondaryTapDown: (details) {
        showMenu(
          context: context,
          position: RelativeRect.fromLTRB(
            details.globalPosition.dx,
            details.globalPosition.dy,
            details.globalPosition.dx,
            details.globalPosition.dy,
          ),
          items: [
            const PopupMenuItem(
              value: 'insert_before',
              child: Row(
                children: [
                  Icon(Icons.arrow_upward),
                  SizedBox(width: 8),
                  Text('Insert Row Before'),
                ],
              ),
            ),
            const PopupMenuItem(
              value: 'insert_after',
              child: Row(
                children: [
                  Icon(Icons.arrow_downward),
                  SizedBox(width: 8),
                  Text('Insert Row After'),
                ],
              ),
            ),
            const PopupMenuItem(
              value: 'delete',
              child: Row(
                children: [
                  Icon(Icons.delete),
                  SizedBox(width: 8),
                  Text('Delete Row'),
                ],
              ),
            ),
          ],
        ).then((value) {
          if (value == 'insert_before') onInsertBefore?.call();
          if (value == 'insert_after') onInsertAfter?.call();
          if (value == 'delete') onDelete?.call();
        });
      },
      child: Container(
        width: width,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        alignment: Alignment.centerRight,
        decoration: BoxDecoration(
          border: Border(
            right: BorderSide(
              color: Theme.of(context).colorScheme.outline.withOpacity(0.2),
            ),
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // Drag handle indicator
            MouseRegion(
              cursor: SystemMouseCursors.grab,
              child: Icon(
                Icons.drag_indicator,
                size: 16,
                color: Theme.of(context).colorScheme.onSurface.withOpacity(0.3),
              ),
            ),
            const SizedBox(width: 4),
            Text(
              lineNumber.toString(),
              style: TextStyle(
                color: Theme.of(context).colorScheme.onSurface.withOpacity(0.6),
                fontWeight: FontWeight.w500,
                fontSize: 13,
                fontFeatures: const [FontFeature.tabularFigures()],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
