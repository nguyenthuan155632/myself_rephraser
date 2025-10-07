import 'package:flutter/material.dart';

/// Modern theme constants inspired by Notion, TablePlus, and Airtable
class CsvTheme {
  // Color palette - Soft, neutral tones
  static const Color backgroundColor = Color(0xFFF7F8FA);
  static const Color surfaceColor = Color(0xFFFFFFFF);
  static const Color borderColor = Color(0xFFE5E7EB);
  static const Color borderColorLight = Color(0xFFF3F4F6);

  // Accent colors
  static const Color primaryColor = Color(0xFF6366F1); // Indigo
  static const Color primaryLight = Color(0xFFEEF2FF);
  static const Color primaryDark = Color(0xFF4F46E5);

  // Text colors
  static const Color textPrimary = Color(0xFF111827);
  static const Color textSecondary = Color(0xFF6B7280);
  static const Color textTertiary = Color(0xFF9CA3AF);

  // Status colors
  static const Color successColor = Color(0xFF10B981);
  static const Color warningColor = Color(0xFFF59E0B);
  static const Color warningLight = Color(0xFFFEF3C7);
  static const Color errorColor = Color(0xFFEF4444);
  static const Color infoColor = Color(0xFF3B82F6);

  // Table colors
  static const Color tableHeaderBg = Color(0xFFFAFAFB);
  static const Color tableRowEven = Color(0xFFFFFFFF);
  static const Color tableRowOdd = Color(0xFFFBFBFC);
  static const Color tableRowHover = Color(0xFFF3F4F6);
  static const Color tableRowSelected = Color(0xFFEEF2FF);
  static const Color tableCellBorder = Color(0xFFE5E7EB);

  // Shadows
  static const BoxShadow shadowSm = BoxShadow(
    color: Color(0x0A000000),
    offset: Offset(0, 1),
    blurRadius: 3,
  );

  static const BoxShadow shadowMd = BoxShadow(
    color: Color(0x0D000000),
    offset: Offset(0, 4),
    blurRadius: 6,
    spreadRadius: -1,
  );

  static const BoxShadow shadowLg = BoxShadow(
    color: Color(0x14000000),
    offset: Offset(0, 10),
    blurRadius: 15,
    spreadRadius: -3,
  );

  // Border radius
  static const double radiusSm = 4.0;
  static const double radiusMd = 6.0;
  static const double radiusLg = 8.0;
  static const double radiusXl = 12.0;

  // Spacing
  static const double spacingXs = 4.0;
  static const double spacingSm = 8.0;
  static const double spacingMd = 12.0;
  static const double spacingLg = 16.0;
  static const double spacingXl = 24.0;
  static const double spacing2xl = 32.0;

  // Typography
  static const TextStyle headingLarge = TextStyle(
    fontSize: 24,
    fontWeight: FontWeight.w600,
    color: textPrimary,
    letterSpacing: -0.5,
  );

  static const TextStyle headingMedium = TextStyle(
    fontSize: 18,
    fontWeight: FontWeight.w600,
    color: textPrimary,
    letterSpacing: -0.3,
  );

  static const TextStyle headingSmall = TextStyle(
    fontSize: 14,
    fontWeight: FontWeight.w600,
    color: textPrimary,
    letterSpacing: -0.1,
  );

  static const TextStyle bodyLarge = TextStyle(
    fontSize: 15,
    fontWeight: FontWeight.w400,
    color: textPrimary,
    height: 1.5,
  );

  static const TextStyle bodyMedium = TextStyle(
    fontSize: 14,
    fontWeight: FontWeight.w400,
    color: textPrimary,
    height: 1.5,
  );

  static const TextStyle bodySmall = TextStyle(
    fontSize: 13,
    fontWeight: FontWeight.w400,
    color: textSecondary,
    height: 1.4,
  );

  // Extra small text for compact table rows
  static const TextStyle bodyExtraSmall = TextStyle(
    fontSize: 11,
    fontWeight: FontWeight.w400,
    color: textPrimary,
    height: 1.3,
  );

  static const TextStyle labelMedium = TextStyle(
    fontSize: 12,
    fontWeight: FontWeight.w500,
    color: textSecondary,
    letterSpacing: 0.3,
  );

  static const TextStyle caption = TextStyle(
    fontSize: 11,
    fontWeight: FontWeight.w400,
    color: textTertiary,
    letterSpacing: 0.2,
  );

  // Button styles
  static ButtonStyle primaryButtonStyle = ElevatedButton.styleFrom(
    backgroundColor: primaryColor,
    foregroundColor: Colors.white,
    elevation: 0,
    shadowColor: Colors.transparent,
    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(radiusMd),
    ),
    textStyle: const TextStyle(
      fontSize: 14,
      fontWeight: FontWeight.w500,
      letterSpacing: 0,
    ),
  );

  static ButtonStyle secondaryButtonStyle = OutlinedButton.styleFrom(
    foregroundColor: textPrimary,
    side: const BorderSide(color: borderColor, width: 1),
    backgroundColor: surfaceColor,
    elevation: 0,
    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(radiusMd),
    ),
    textStyle: const TextStyle(
      fontSize: 14,
      fontWeight: FontWeight.w500,
      letterSpacing: 0,
    ),
  );

  // Input decoration
  static InputDecoration searchInputDecoration({String? hintText}) {
    return InputDecoration(
      hintText: hintText ?? 'Search...',
      hintStyle: bodyMedium.copyWith(color: textTertiary),
      prefixIcon: const Icon(Icons.search, size: 18, color: textTertiary),
      filled: true,
      fillColor: surfaceColor,
      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(radiusMd),
        borderSide: const BorderSide(color: borderColor, width: 1),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(radiusMd),
        borderSide: const BorderSide(color: borderColor, width: 1),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(radiusMd),
        borderSide: const BorderSide(color: primaryColor, width: 1.5),
      ),
    );
  }

  // Icon button style
  static Widget iconButton({
    required IconData icon,
    required VoidCallback? onPressed,
    String? tooltip,
    Color? color,
    double size = 20,
    bool isActive = false,
  }) {
    return Tooltip(
      message: tooltip ?? '',
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onPressed,
          borderRadius: BorderRadius.circular(radiusMd),
          child: Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: isActive ? primaryLight : Colors.transparent,
              borderRadius: BorderRadius.circular(radiusMd),
            ),
            child: Icon(
              icon,
              size: size,
              color: color ?? (isActive ? primaryColor : textSecondary),
            ),
          ),
        ),
      ),
    );
  }
}
