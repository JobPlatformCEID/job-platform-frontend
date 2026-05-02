import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class AppTheme {
  AppTheme._();

  // ─── Color palette (dark) ─────────────────────────────────────────
  static const Color background = Color(0xFF0D1117);
  static const Color surface = Color(0xFF161B22);
  static const Color surfaceAlt = Color(0xFF1C2333);
  static const Color primary = Color(0xFF4F8EF7);
  static const Color primaryDark = Color(0xFF2563EB);
  static const Color accent = Color(0xFF7C3AED);
  static const Color success = Color(0xFF22C55E);
  static const Color warning = Color(0xFFF59E0B);
  static const Color error = Color(0xFFEF4444);
  static const Color textPrimary = Color(0xFFF0F6FC);
  static const Color textSecondary = Color(0xFF8B949E);
  static const Color divider = Color(0xFF30363D);
  static const Color cardBorder = Color(0xFF21262D);

  // ─── Border radius tokens ────────────────────────────────────────
  static const double radiusSmall = 8;
  static const double radiusMedium = 14;
  static const double radiusLarge = 20;
  static const double radiusPill = 50;

  // ─── Dark theme (primary) ────────────────────────────────────────
  static final ThemeData dark = _buildDark();

  // ─── Light theme (derived from dark palette for consistency) ──────
  static final ThemeData light = _buildLight();

  static ThemeData _buildDark() {
    final colorScheme = ColorScheme(
      brightness: Brightness.dark,
      primary: primary,
      onPrimary: Colors.white,
      primaryContainer: primary.withValues(alpha: 0.15),
      onPrimaryContainer: primary,
      secondary: accent,
      onSecondary: Colors.white,
      secondaryContainer: accent.withValues(alpha: 0.15),
      onSecondaryContainer: accent,
      tertiary: success,
      onTertiary: Colors.white,
      tertiaryContainer: success.withValues(alpha: 0.15),
      onTertiaryContainer: success,
      error: error,
      onError: Colors.white,
      errorContainer: error.withAlpha((0.15 * 255).round()),
      onErrorContainer: error,
      surface: surface,
      onSurface: textPrimary,
      surfaceContainerHighest: surfaceAlt,
      surfaceContainerLow: surface,
      surfaceContainerLowest: background,
      onSurfaceVariant: textSecondary,
      outline: divider,
      outlineVariant: cardBorder,
      inverseSurface: textPrimary,
      onInverseSurface: background,
      inversePrimary: primaryDark,
      shadow: Colors.black,
      scrim: Colors.black,
    );

    return _buildFromColorScheme(colorScheme, Brightness.dark);
  }

  static ThemeData _buildLight() {
    final colorScheme = ColorScheme(
      brightness: Brightness.light,
      primary: primaryDark,
      onPrimary: Colors.white,
      primaryContainer: primary.withAlpha((0.12 * 255).round()),
      onPrimaryContainer: primaryDark,
      secondary: accent,
      onSecondary: Colors.white,
      secondaryContainer: accent.withAlpha((0.12 * 255).round()),
      onSecondaryContainer: accent,
      tertiary: success,
      onTertiary: Colors.white,
      tertiaryContainer: success.withAlpha((0.12 * 255).round()),
      onTertiaryContainer: success,
      error: error,
      onError: Colors.white,
      errorContainer: error.withAlpha((0.12 * 255).round()),
      onErrorContainer: error,
      surface: const Color(0xFFF8FAFC),
      onSurface: const Color(0xFF1E293B),
      surfaceContainerHighest: const Color(0xFFF1F5F9),
      surfaceContainerLow: const Color(0xFFF1F5F9),
      surfaceContainerLowest: Colors.white,
      onSurfaceVariant: const Color(0xFF64748B),
      outline: const Color(0xFFCBD5E1),
      outlineVariant: const Color(0xFFE2E8F0),
      inverseSurface: const Color(0xFF1E293B),
      onInverseSurface: const Color(0xFFF8FAFC),
      inversePrimary: primary,
      shadow: Colors.black.withValues(alpha: 0.08),
      scrim: Colors.black,
    );

    return _buildFromColorScheme(colorScheme, Brightness.light);
  }

  static ThemeData _buildFromColorScheme(ColorScheme colorScheme, Brightness brightness) {
    final isDark = brightness == Brightness.dark;
    final poppins = GoogleFonts.poppinsTextTheme();

    return ThemeData(
      useMaterial3: true,
      colorScheme: colorScheme,
      brightness: brightness,

      // ── Scaffold ────────────────────────────────────────────────
      scaffoldBackgroundColor: isDark ? background : colorScheme.surface,

      // ── AppBar ──────────────────────────────────────────────────
      appBarTheme: AppBarTheme(
        centerTitle: true,
        elevation: 0,
        scrolledUnderElevation: 0,
        backgroundColor: isDark ? surface : colorScheme.surface,
        foregroundColor: isDark ? textPrimary : colorScheme.onSurface,
        titleTextStyle: poppins.titleMedium?.copyWith(
          color: isDark ? textPrimary : colorScheme.onSurface,
          fontWeight: FontWeight.w600,
        ),
        shape: Border(
          bottom: BorderSide(
            color: isDark ? divider : colorScheme.outlineVariant,
            width: 1,
          ),
        ),
      ),

      // ── Cards ───────────────────────────────────────────────────
      cardTheme: CardThemeData(
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(radiusMedium),
          side: BorderSide(color: isDark ? cardBorder : colorScheme.outlineVariant),
        ),
        color: isDark ? surface : Colors.white,
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
        shadowColor: isDark ? Colors.black.withValues(alpha: 0.12) : null,
      ),

      // ── Elevated buttons ────────────────────────────────────────
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: colorScheme.primary,
          foregroundColor: colorScheme.onPrimary,
          elevation: 0,
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(radiusPill),
          ),
          textStyle: poppins.labelLarge,
        ),
      ),

      // ── Filled buttons (primary actions) ─────────────────────────
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: colorScheme.primary,
          foregroundColor: colorScheme.onPrimary,
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(radiusPill),
          ),
          minimumSize: const Size.fromHeight(48),
          textStyle: poppins.labelLarge,
        ),
      ),

      // ── Outlined buttons ────────────────────────────────────────
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: colorScheme.primary,
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(radiusPill),
          ),
          side: BorderSide(color: colorScheme.primary),
          minimumSize: const Size.fromHeight(48),
          textStyle: poppins.labelLarge,
        ),
      ),

      // ── Text buttons ────────────────────────────────────────────
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: colorScheme.primary,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(radiusPill),
          ),
          textStyle: poppins.labelLarge,
        ),
      ),

      // ── FAB ─────────────────────────────────────────────────────
      floatingActionButtonTheme: FloatingActionButtonThemeData(
        backgroundColor: colorScheme.primary,
        foregroundColor: colorScheme.onPrimary,
        elevation: 2,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(radiusLarge),
        ),
      ),

      // ── Input fields ────────────────────────────────────────────
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: isDark ? surfaceAlt : colorScheme.surfaceContainerHighest,
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: isDark ? cardBorder : colorScheme.outlineVariant),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: isDark ? cardBorder : colorScheme.outlineVariant),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: colorScheme.primary, width: 2),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: colorScheme.error),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: colorScheme.error, width: 2),
        ),
        labelStyle: TextStyle(
          color: colorScheme.onSurfaceVariant,
          fontWeight: FontWeight.w500,
        ),
        hintStyle: TextStyle(
          color: colorScheme.onSurfaceVariant.withValues(alpha: 0.6),
        ),
        prefixIconColor: colorScheme.onSurfaceVariant,
      ),

      // ── Chips (skills, tags, filters) ───────────────────────────
      chipTheme: ChipThemeData(
        backgroundColor: isDark ? surfaceAlt : colorScheme.surfaceContainerLow,
        selectedColor: colorScheme.primaryContainer,
        labelStyle: poppins.labelSmall?.copyWith(
          color: isDark ? textSecondary : colorScheme.onSurface,
          fontSize: 11,
          fontWeight: FontWeight.w500,
        ),
        side: BorderSide(color: isDark ? cardBorder : colorScheme.outlineVariant),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(radiusPill),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      ),

      // ── Bottom navigation ───────────────────────────────────────
      navigationBarTheme: NavigationBarThemeData(
        elevation: 0,
        backgroundColor: isDark ? surface : colorScheme.surface,
        indicatorColor: colorScheme.primaryContainer,
        iconTheme: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return IconThemeData(color: colorScheme.primary);
          }
          return IconThemeData(color: isDark ? textSecondary : colorScheme.onSurfaceVariant);
        }),
        labelTextStyle: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return poppins.labelSmall?.copyWith(
              color: colorScheme.primary,
              fontWeight: FontWeight.w600,
            );
          }
          return poppins.labelSmall?.copyWith(
            color: isDark ? textSecondary : colorScheme.onSurfaceVariant,
          );
        }),
        height: 64,
        labelBehavior: NavigationDestinationLabelBehavior.onlyShowSelected,
      ),

      // ── Navigation rail (tablet / desktop) ──────────────────────
      navigationRailTheme: NavigationRailThemeData(
        backgroundColor: isDark ? surface : colorScheme.surface,
        indicatorColor: colorScheme.primaryContainer,
        selectedIconTheme: IconThemeData(color: colorScheme.primary),
        unselectedIconTheme: IconThemeData(color: isDark ? textSecondary : colorScheme.onSurfaceVariant),
        selectedLabelTextStyle: poppins.labelSmall?.copyWith(
          color: colorScheme.primary,
          fontWeight: FontWeight.w600,
        ),
        unselectedLabelTextStyle: poppins.labelSmall?.copyWith(
          color: isDark ? textSecondary : colorScheme.onSurfaceVariant,
        ),
      ),

      // ── Drawer ──────────────────────────────────────────────────
      drawerTheme: DrawerThemeData(
        backgroundColor: isDark ? surface : colorScheme.surface,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.horizontal(right: Radius.circular(radiusLarge)),
        ),
      ),

      // ── Bottom sheets ───────────────────────────────────────────
      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: isDark ? surface : colorScheme.surface,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(radiusLarge)),
        ),
        showDragHandle: true,
        dragHandleColor: colorScheme.onSurfaceVariant.withValues(alpha: 0.4),
      ),

      // ── Dialogs ─────────────────────────────────────────────────
      dialogTheme: DialogThemeData(
        backgroundColor: isDark ? surface : colorScheme.surface,
        elevation: 6,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(radiusLarge),
        ),
        titleTextStyle: poppins.titleLarge?.copyWith(
          color: isDark ? textPrimary : colorScheme.onSurface,
        ),
      ),

      // ── Snackbar ────────────────────────────────────────────────
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        backgroundColor: isDark ? surfaceAlt : colorScheme.inverseSurface,
        contentTextStyle: TextStyle(color: isDark ? textPrimary : colorScheme.onInverseSurface),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(radiusMedium),
        ),
      ),

      // ── Dividers ────────────────────────────────────────────────
      dividerTheme: DividerThemeData(
        color: isDark ? divider : colorScheme.outlineVariant,
        thickness: 1,
        space: 1,
      ),

      // ── List tiles ──────────────────────────────────────────────
      listTileTheme: ListTileThemeData(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(radiusMedium),
        ),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        iconColor: colorScheme.primary,
        tileColor: isDark ? surface : null,
        selectedTileColor: colorScheme.primary.withValues(alpha: 0.1),
        titleTextStyle: poppins.bodyLarge?.copyWith(
          fontWeight: FontWeight.w500,
          color: isDark ? textPrimary : colorScheme.onSurface,
        ),
        subtitleTextStyle: poppins.bodyMedium?.copyWith(
          color: isDark ? textSecondary : colorScheme.onSurfaceVariant,
        ),
      ),

      // ── Tabs ────────────────────────────────────────────────────
      tabBarTheme: TabBarThemeData(
        labelColor: colorScheme.primary,
        unselectedLabelColor: isDark ? textSecondary : colorScheme.onSurfaceVariant,
        indicatorColor: colorScheme.primary,
        dividerColor: isDark ? divider : colorScheme.outlineVariant,
        labelStyle: poppins.labelLarge?.copyWith(fontWeight: FontWeight.w600),
        unselectedLabelStyle: poppins.labelLarge?.copyWith(fontWeight: FontWeight.w500),
      ),

      // ── Search bar ──────────────────────────────────────────────
      searchBarTheme: SearchBarThemeData(
        backgroundColor: WidgetStatePropertyAll(
          isDark ? surfaceAlt : colorScheme.surfaceContainerHigh,
        ),
        elevation: const WidgetStatePropertyAll(0),
        shape: WidgetStatePropertyAll(
          RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(radiusPill),
          ),
        ),
        padding: const WidgetStatePropertyAll(
          EdgeInsets.symmetric(horizontal: 16),
        ),
        hintStyle: WidgetStatePropertyAll(
          TextStyle(
            color: isDark ? textSecondary : colorScheme.onSurfaceVariant,
          ),
        ),
        textStyle: WidgetStatePropertyAll(
          isDark
              ? poppins.bodyMedium?.copyWith(color: textPrimary)
              : poppins.bodyMedium,
        ),
      ),

      // ── Switches / checkboxes / radios ──────────────────────────
      switchTheme: SwitchThemeData(
        thumbColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) return colorScheme.onPrimary;
          return colorScheme.outline;
        }),
        trackColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) return colorScheme.primary;
          return isDark ? surfaceAlt : colorScheme.surfaceContainerHighest;
        }),
      ),

      checkboxTheme: CheckboxThemeData(
        fillColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) return colorScheme.primary;
          return Colors.transparent;
        }),
        checkColor: WidgetStatePropertyAll(colorScheme.onPrimary),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(radiusSmall / 2),
        ),
      ),

      radioTheme: RadioThemeData(
        fillColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) return colorScheme.primary;
          return colorScheme.onSurfaceVariant;
        }),
      ),

      // ── Progress indicators ─────────────────────────────────────
      progressIndicatorTheme: ProgressIndicatorThemeData(
        color: colorScheme.primary,
        linearTrackColor: colorScheme.primaryContainer,
        circularTrackColor: colorScheme.primaryContainer,
      ),

      // ── Badges ──────────────────────────────────────────────────
      badgeTheme: BadgeThemeData(
        backgroundColor: colorScheme.error,
        textColor: colorScheme.onError,
      ),

      // ── Tooltips ────────────────────────────────────────────────
      tooltipTheme: TooltipThemeData(
        decoration: BoxDecoration(
          color: isDark ? surfaceAlt : colorScheme.inverseSurface,
          borderRadius: BorderRadius.circular(radiusSmall),
        ),
        textStyle: TextStyle(
          color: isDark ? textPrimary : colorScheme.onInverseSurface,
          fontSize: 12,
        ),
      ),

      // ── Text theme (Poppins) ────────────────────────────────────
      textTheme: poppins.copyWith(
        displayLarge: poppins.displayLarge?.copyWith(fontWeight: FontWeight.w400, letterSpacing: -0.25),
        displayMedium: poppins.displayMedium?.copyWith(fontWeight: FontWeight.w400),
        displaySmall: poppins.displaySmall?.copyWith(fontWeight: FontWeight.w400),
        headlineLarge: poppins.headlineLarge?.copyWith(fontWeight: FontWeight.w500, letterSpacing: -0.25),
        headlineMedium: poppins.headlineMedium?.copyWith(fontWeight: FontWeight.w500),
        headlineSmall: poppins.headlineSmall?.copyWith(fontWeight: FontWeight.w500),
        titleLarge: poppins.titleLarge?.copyWith(fontWeight: FontWeight.w600, letterSpacing: 0.15),
        titleMedium: poppins.titleMedium?.copyWith(fontWeight: FontWeight.w600, letterSpacing: 0.15),
        titleSmall: poppins.titleSmall?.copyWith(fontWeight: FontWeight.w600, letterSpacing: 0.1),
        bodyLarge: poppins.bodyLarge?.copyWith(fontWeight: FontWeight.w400, letterSpacing: 0.15),
        bodyMedium: poppins.bodyMedium?.copyWith(fontWeight: FontWeight.w400, letterSpacing: 0.25),
        bodySmall: poppins.bodySmall?.copyWith(fontWeight: FontWeight.w400, letterSpacing: 0.4),
        labelLarge: poppins.labelLarge?.copyWith(fontWeight: FontWeight.w600, letterSpacing: 0.4),
        labelMedium: poppins.labelMedium?.copyWith(fontWeight: FontWeight.w600, letterSpacing: 0.5),
        labelSmall: poppins.labelSmall?.copyWith(fontWeight: FontWeight.w600, letterSpacing: 0.5),
      ),

      // ── Page transitions ────────────────────────────────────────
      pageTransitionsTheme: const PageTransitionsTheme(
        builders: {
          TargetPlatform.android: PredictiveBackPageTransitionsBuilder(),
          TargetPlatform.iOS: CupertinoPageTransitionsBuilder(),
          TargetPlatform.macOS: CupertinoPageTransitionsBuilder(),
          TargetPlatform.windows: FadeUpwardsPageTransitionsBuilder(),
          TargetPlatform.linux: FadeUpwardsPageTransitionsBuilder(),
        },
      ),

      // ── Visual density ──────────────────────────────────────────
      visualDensity: VisualDensity.adaptivePlatformDensity,
    );
  }

  // ─── Helper: card decoration ─────────────────────────────────────
  static BoxDecoration cardDecoration({Color? color, Color? borderColor}) {
    return BoxDecoration(
      color: color ?? surface,
      border: Border.all(color: borderColor ?? cardBorder),
      borderRadius: BorderRadius.circular(radiusMedium),
      boxShadow: [
        BoxShadow(
          color: Colors.black.withValues(alpha: 0.12),
          offset: const Offset(0, 4),
          blurRadius: 24,
        ),
      ],
    );
  }

  // ─── Helper: pill tag decoration ─────────────────────────────────
  static BoxDecoration pillTagDecoration({Color? bgColor}) {
    return BoxDecoration(
      color: bgColor ?? surfaceAlt,
      borderRadius: BorderRadius.circular(radiusPill),
    );
  }
}