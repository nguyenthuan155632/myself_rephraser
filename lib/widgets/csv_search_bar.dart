import 'package:flutter/material.dart';
import '../theme/csv_theme.dart';

class CsvSearchBar extends StatelessWidget {
  final Function(String) onSearch;
  final VoidCallback? onToggleAdvanced;
  final VoidCallback? onResetFilters;
  final bool showAdvanced;
  final bool hasActiveFilters;

  const CsvSearchBar({
    super.key,
    required this.onSearch,
    this.onToggleAdvanced,
    this.onResetFilters,
    this.showAdvanced = false,
    this.hasActiveFilters = false,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: CsvTheme.spacingLg,
        vertical: CsvTheme.spacingSm,
      ),
      decoration: const BoxDecoration(
        color: CsvTheme.surfaceColor,
        border: Border(
          bottom: BorderSide(color: CsvTheme.borderColorLight, width: 1),
        ),
      ),
      child: Row(
        children: [
          Expanded(
            child: Container(
              height: 36,
              decoration: BoxDecoration(
                color: CsvTheme.backgroundColor,
                borderRadius: BorderRadius.circular(CsvTheme.radiusMd),
                border: Border.all(color: CsvTheme.borderColor),
              ),
              alignment: Alignment.center,
              child: TextField(
                onChanged: onSearch,
                style: CsvTheme.bodyMedium.copyWith(fontSize: 13),
                textAlignVertical: TextAlignVertical.center,
                decoration: InputDecoration(
                  hintText: 'Search in table...',
                  hintStyle: CsvTheme.bodyMedium.copyWith(
                    color: CsvTheme.textTertiary,
                    fontSize: 13,
                  ),
                  prefixIcon: const Icon(
                    Icons.search,
                    size: 18,
                    color: CsvTheme.textTertiary,
                  ),
                  prefixIconConstraints: const BoxConstraints(
                    minWidth: 40,
                    minHeight: 36,
                  ),
                  suffixIcon: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (hasActiveFilters)
                        IconButton(
                          icon: const Icon(Icons.clear, size: 16),
                          onPressed: onResetFilters,
                          tooltip: 'Clear filters',
                          color: CsvTheme.textSecondary,
                          padding: const EdgeInsets.all(6),
                          constraints: const BoxConstraints(),
                        ),
                      IconButton(
                        icon: Icon(
                          showAdvanced ? Icons.expand_less : Icons.tune,
                          size: 18,
                        ),
                        onPressed: onToggleAdvanced,
                        tooltip: 'Advanced search',
                        color: showAdvanced
                            ? CsvTheme.primaryColor
                            : CsvTheme.textSecondary,
                        padding: const EdgeInsets.all(6),
                        constraints: const BoxConstraints(),
                      ),
                      const SizedBox(width: CsvTheme.spacingSm),
                    ],
                  ),
                  border: InputBorder.none,
                  contentPadding: const EdgeInsets.only(
                    left: CsvTheme.spacingMd,
                    right: CsvTheme.spacingMd,
                    top: 8,
                    bottom: 8,
                  ),
                  isDense: true,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class CsvAdvancedSearch extends StatelessWidget {
  final List<String> headers;
  final Set<int> selectedColumns;
  final Function(int) onColumnToggle;
  final Function(bool) onCaseSensitiveChange;
  final Function(bool) onRegexChange;
  final Function(String) onRowRangeStartChange;
  final Function(String) onRowRangeEndChange;
  final bool caseSensitive;
  final bool useRegex;
  final int totalRows;

  const CsvAdvancedSearch({
    super.key,
    required this.headers,
    required this.selectedColumns,
    required this.onColumnToggle,
    required this.onCaseSensitiveChange,
    required this.onRegexChange,
    required this.onRowRangeStartChange,
    required this.onRowRangeEndChange,
    this.caseSensitive = false,
    this.useRegex = false,
    this.totalRows = 0,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.fromLTRB(
        CsvTheme.spacingLg,
        0,
        CsvTheme.spacingLg,
        CsvTheme.spacingMd,
      ),
      padding: const EdgeInsets.all(CsvTheme.spacingMd),
      decoration: BoxDecoration(
        color: CsvTheme.surfaceColor,
        borderRadius: BorderRadius.circular(CsvTheme.radiusLg),
        border: Border.all(color: CsvTheme.borderColor),
        boxShadow: const [CsvTheme.shadowSm],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Advanced Search Options',
            style: CsvTheme.headingSmall,
          ),
          const SizedBox(height: CsvTheme.spacingMd),

          // Search options
          Wrap(
            spacing: CsvTheme.spacingMd,
            runSpacing: CsvTheme.spacingSm,
            children: [
              _buildFilterChip(
                label: 'Case sensitive',
                selected: caseSensitive,
                onSelected: onCaseSensitiveChange,
              ),
              _buildFilterChip(
                label: 'Use regex',
                selected: useRegex,
                onSelected: onRegexChange,
              ),
            ],
          ),

          const SizedBox(height: CsvTheme.spacingLg),

          // Row range filter
          Text(
            'Row Range',
            style: CsvTheme.bodySmall.copyWith(
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: CsvTheme.spacingSm),
          Row(
            children: [
              Expanded(
                child: _buildTextField(
                  label: 'From Row',
                  hint: '1',
                  onChanged: onRowRangeStartChange,
                ),
              ),
              const SizedBox(width: CsvTheme.spacingMd),
              Expanded(
                child: _buildTextField(
                  label: 'To Row',
                  hint: '$totalRows',
                  onChanged: onRowRangeEndChange,
                ),
              ),
            ],
          ),

          const SizedBox(height: CsvTheme.spacingLg),

          // Column selector
          Text(
            'Search in columns',
            style: CsvTheme.bodySmall.copyWith(
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: CsvTheme.spacingSm),
          Wrap(
            spacing: CsvTheme.spacingSm,
            runSpacing: CsvTheme.spacingSm,
            children: [
              _buildFilterChip(
                label: 'All',
                selected: selectedColumns.isEmpty,
                onSelected: (selected) {
                  if (selected) {
                    // Clear all selections
                    for (int i = headers.length - 1; i >= 0; i--) {
                      if (selectedColumns.contains(i)) {
                        onColumnToggle(i);
                      }
                    }
                  }
                },
              ),
              ...headers.asMap().entries.map((entry) {
                final colIndex = entry.key;
                final colName = entry.value;
                return _buildFilterChip(
                  label: colName,
                  selected: selectedColumns.contains(colIndex),
                  onSelected: (_) => onColumnToggle(colIndex),
                );
              }),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildFilterChip({
    required String label,
    required bool selected,
    required Function(bool) onSelected,
  }) {
    return FilterChip(
      label: Text(label),
      labelStyle: CsvTheme.bodySmall.copyWith(
        color: selected ? CsvTheme.primaryColor : CsvTheme.textSecondary,
        fontWeight: selected ? FontWeight.w500 : FontWeight.w400,
      ),
      selected: selected,
      onSelected: onSelected,
      backgroundColor: CsvTheme.surfaceColor,
      selectedColor: CsvTheme.primaryLight,
      checkmarkColor: CsvTheme.primaryColor,
      side: BorderSide(
        color: selected ? CsvTheme.primaryColor : CsvTheme.borderColor,
        width: 1,
      ),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(CsvTheme.radiusMd),
      ),
      padding: const EdgeInsets.symmetric(
        horizontal: CsvTheme.spacingSm,
        vertical: CsvTheme.spacingXs,
      ),
    );
  }

  Widget _buildTextField({
    required String label,
    required String hint,
    required Function(String) onChanged,
  }) {
    return TextField(
      decoration: InputDecoration(
        labelText: label,
        labelStyle: CsvTheme.bodySmall,
        hintText: hint,
        hintStyle: CsvTheme.bodySmall.copyWith(color: CsvTheme.textTertiary),
        isDense: true,
        filled: true,
        fillColor: CsvTheme.backgroundColor,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: CsvTheme.spacingMd,
          vertical: CsvTheme.spacingSm,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(CsvTheme.radiusMd),
          borderSide: const BorderSide(color: CsvTheme.borderColor),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(CsvTheme.radiusMd),
          borderSide: const BorderSide(color: CsvTheme.borderColor),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(CsvTheme.radiusMd),
          borderSide:
              const BorderSide(color: CsvTheme.primaryColor, width: 1.5),
        ),
      ),
      style: CsvTheme.bodyMedium,
      keyboardType: TextInputType.number,
      onChanged: onChanged,
    );
  }
}
