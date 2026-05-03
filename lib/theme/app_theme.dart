import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class AppTheme {
  AppTheme._();

  // ─── Ayu-inspired dark palette + orange ───────────────────────────
  // Ayu dark bg is #0F1419 — slightly warmed up to #111720
  static const Color _bgDark        = Color(0xFF111720);  // main scaffold
  static const Color _surfaceDark   = Color(0xFF1A2130);  // cards, sidebar
  static const Color _surfaceHigh   = Color(0xFF222D40);  // elevated, inputs
  static const Color _surfaceHigher = Color(0xFF2A3650);  // hover states

  // Orange — toned between Ayu's #FF8F40 and our #FF6B2B
  static const Color _accent        = Color(0xFFFF8F40);  // primary CTA
  static const Color _accentLight   = Color(0xFFFFAD6B);  // lighter variant
  static const Color _accentDim     = Color(0x33FF8F40);  // 20% orange for indicators

  static const Color _onAccent      = Color(0xFF0F1419);  // dark text on orange
  static const Color _textPrimary   = Color(0xFFE6E8F0);  // Ayu fg-ish
  static const Color _textSecondary = Color(0xFF6B7A99);  // muted
  static const Color _outline       = Color(0xFF1E2D42);  // borders
  static const Color _outlineVar    = Color(0xFF253350);  // slightly lighter

  // Error — Ayu uses #FF3333
  static const Color _error         = Color(0xFFFF4D4D);

  // Light seed
  static const Color _seedLight     = Color(0xFFFF8F40);

  static final ThemeData dark  = _buildDark();
  static final ThemeData light = _buildLight();

  // ─── Dark ─────────────────────────────────────────────────────────
  static ThemeData _buildDark() {
    final cs = ColorScheme(
      brightness:              Brightness.dark,
      primary:                 _accent,
      onPrimary:               _onAccent,
      primaryContainer:        _surfaceHigh,
      onPrimaryContainer:      _accentLight,
      secondary:               _accentLight,
      onSecondary:             _onAccent,
      secondaryContainer:      _accentDim,
      onSecondaryContainer:    _accentLight,
      tertiary:                const Color(0xFFFFCC66), // Ayu yellow
      onTertiary:              _onAccent,
      tertiaryContainer:       _surfaceHigh,
      onTertiaryContainer:     const Color(0xFFFFCC66),
      error:                   _error,
      onError:                 Colors.white,
      errorContainer:          const Color(0xFF5C1A1A),
      onErrorContainer:        const Color(0xFFFFB3B3),
      surface:                 _surfaceDark,
      onSurface:               _textPrimary,
      onSurfaceVariant:        _textSecondary,
      outline:                 _outline,
      outlineVariant:          _outlineVar,
      shadow:                  Colors.black,
      scrim:                   Colors.black,
      inverseSurface:          _textPrimary,
      onInverseSurface:        _bgDark,
      inversePrimary:          _accentLight,
      surfaceContainerLowest:  _bgDark,
      surfaceContainerLow:     _surfaceDark,
      surfaceContainer:        _surfaceDark,
      surfaceContainerHigh:    _surfaceHigh,
      surfaceContainerHighest: _surfaceHigher,
    );
    return _buildBase(cs, Brightness.dark);
  }

  // ─── Light ────────────────────────────────────────────────────────
  static ThemeData _buildLight() {
    final cs = ColorScheme.fromSeed(
      seedColor: _seedLight,
      brightness: Brightness.light,
    );
    return _buildBase(cs, Brightness.light);
  }

  // ─── Base ─────────────────────────────────────────────────────────
  static ThemeData _buildBase(ColorScheme cs, Brightness brightness) {
    final isDark = brightness == Brightness.dark;

    final poppins = GoogleFonts.poppinsTextTheme().copyWith(
      displayLarge:   _ts(57, FontWeight.w300),
      displayMedium:  _ts(45, FontWeight.w300),
      displaySmall:   _ts(36, FontWeight.w400),
      headlineLarge:  _ts(32, FontWeight.w600),
      headlineMedium: _ts(28, FontWeight.w600),
      headlineSmall:  _ts(24, FontWeight.w600),
      titleLarge:     _ts(22, FontWeight.w600, ls: 0.15),
      titleMedium:    _ts(16, FontWeight.w600, ls: 0.15),
      titleSmall:     _ts(14, FontWeight.w600, ls: 0.1),
      bodyLarge:      _ts(16, FontWeight.w400, ls: 0.15),
      bodyMedium:     _ts(14, FontWeight.w400, ls: 0.25),
      bodySmall:      _ts(12, FontWeight.w400, ls: 0.4),
      labelLarge:     _ts(14, FontWeight.w600, ls: 0.4),
      labelMedium:    _ts(12, FontWeight.w600, ls: 0.5),
      labelSmall:     _ts(11, FontWeight.w600, ls: 0.5),
    ).apply(bodyColor: cs.onSurface, displayColor: cs.onSurface);

    // Pressed/splash colors — orange tint instead of black ripple
    final splashColor   = _accent.withValues(alpha: 0.12);
    final highlightColor = _accent.withValues(alpha: 0.08);

    return ThemeData(
      useMaterial3: true,
      colorScheme: cs,
      brightness: brightness,
      textTheme: poppins,
      scaffoldBackgroundColor: isDark ? _bgDark : cs.surface,

      // Override ripple globally so nothing goes black on press
      splashColor: splashColor,
      highlightColor: highlightColor,
      splashFactory: InkRipple.splashFactory,

      // ── AppBar ──────────────────────────────────────────────────
      appBarTheme: AppBarTheme(
        centerTitle: false,
        elevation: 0,
        scrolledUnderElevation: 0,
        backgroundColor: isDark ? _surfaceDark : cs.surface,
        foregroundColor: cs.onSurface,
        titleTextStyle: GoogleFonts.poppins(
          fontSize: 20, fontWeight: FontWeight.w600,
          color: cs.onSurface, letterSpacing: 0.15,
        ),
      ),

      // ── Cards ───────────────────────────────────────────────────
      cardTheme: CardThemeData(
        elevation: 0,
        color: isDark ? _surfaceDark : cs.surfaceContainerLowest,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(
            color: isDark ? _outline : cs.outlineVariant.withValues(alpha: 0.4),
          ),
        ),
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      ),

      // ── Buttons ─────────────────────────────────────────────────
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: cs.primary,
          foregroundColor: cs.onPrimary,
          elevation: 0,
          overlayColor: cs.onPrimary.withValues(alpha: 0.12),
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          textStyle: GoogleFonts.poppins(fontSize: 15, fontWeight: FontWeight.w600),
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          overlayColor: cs.onPrimary.withValues(alpha: 0.12),
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          textStyle: GoogleFonts.poppins(fontSize: 15, fontWeight: FontWeight.w600),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: cs.primary,
          overlayColor: cs.primary.withValues(alpha: 0.1),
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          side: BorderSide(color: cs.primary),
          textStyle: GoogleFonts.poppins(fontSize: 15, fontWeight: FontWeight.w600),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: cs.primary,
          overlayColor: cs.primary.withValues(alpha: 0.1),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          textStyle: GoogleFonts.poppins(fontSize: 15, fontWeight: FontWeight.w600),
        ),
      ),

      // ── Icon buttons — orange ripple, never black ────────────────
      iconButtonTheme: IconButtonThemeData(
        style: IconButton.styleFrom(
          foregroundColor: cs.onSurface,
          overlayColor: _accent.withValues(alpha: 0.12),
        ),
      ),

      // ── FAB ─────────────────────────────────────────────────────
      floatingActionButtonTheme: FloatingActionButtonThemeData(
        backgroundColor: cs.primary,
        foregroundColor: cs.onPrimary,
        elevation: 4,
        splashColor: cs.onPrimary.withValues(alpha: 0.2),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      ),

      // ── Inputs ──────────────────────────────────────────────────
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: isDark ? _surfaceHigh : cs.surfaceContainerLowest,
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: isDark ? _outline : cs.outline),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: isDark ? _outline : cs.outlineVariant),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: cs.primary, width: 2),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: cs.error),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: cs.error, width: 2),
        ),
        labelStyle: GoogleFonts.poppins(color: cs.onSurfaceVariant, fontWeight: FontWeight.w500),
        hintStyle: GoogleFonts.poppins(color: cs.onSurfaceVariant.withValues(alpha: 0.6)),
        prefixIconColor: cs.onSurfaceVariant,
      ),

      // ── Chips ───────────────────────────────────────────────────
      chipTheme: ChipThemeData(
        backgroundColor: isDark ? _surfaceHigh : cs.surfaceContainerLow,
        selectedColor: _accentDim,
        labelStyle: GoogleFonts.poppins(
          color: cs.onSurface, fontSize: 13, fontWeight: FontWeight.w500,
        ),
        side: BorderSide(color: isDark ? _outline : cs.outlineVariant),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      ),

      // ── Navigation bar ──────────────────────────────────────────
      navigationBarTheme: NavigationBarThemeData(
        elevation: 0,
        backgroundColor: isDark ? _surfaceDark : cs.surface,
        indicatorColor: _accentDim,
        overlayColor: WidgetStatePropertyAll(_accent.withValues(alpha: 0.08)),
        iconTheme: WidgetStateProperty.resolveWith((states) => IconThemeData(
          color: states.contains(WidgetState.selected) ? cs.primary : cs.onSurfaceVariant,
        )),
        labelTextStyle: WidgetStatePropertyAll(
          GoogleFonts.poppins(fontSize: 12, fontWeight: FontWeight.w600, color: cs.onSurface),
        ),
      ),

      // ── Navigation rail ─────────────────────────────────────────
      navigationRailTheme: NavigationRailThemeData(
        backgroundColor: isDark ? _surfaceDark : cs.surface,
        indicatorColor: _accentDim,
        selectedIconTheme: IconThemeData(color: cs.primary),
        unselectedIconTheme: IconThemeData(color: cs.onSurfaceVariant),
      ),

      // ── Drawer ──────────────────────────────────────────────────
      drawerTheme: DrawerThemeData(
        backgroundColor: isDark ? _surfaceDark : cs.surface,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.horizontal(right: Radius.circular(16)),
        ),
      ),

      // ── Bottom sheets ───────────────────────────────────────────
      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: isDark ? _surfaceDark : cs.surface,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        showDragHandle: true,
        dragHandleColor: (isDark ? _textSecondary : cs.onSurfaceVariant).withValues(alpha: 0.4),
      ),

      // ── Dialogs ─────────────────────────────────────────────────
      dialogTheme: DialogThemeData(
        backgroundColor: isDark ? _surfaceDark : cs.surface,
        elevation: 8,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        titleTextStyle: GoogleFonts.poppins(
          fontSize: 20, fontWeight: FontWeight.w600, color: cs.onSurface,
        ),
      ),

      // ── Snackbar ────────────────────────────────────────────────
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        backgroundColor: isDark ? _surfaceHigher : cs.inverseSurface,
        contentTextStyle: GoogleFonts.poppins(
          color: isDark ? _textPrimary : cs.onInverseSurface,
        ),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        actionTextColor: cs.primary,
      ),

      // ── Dividers ────────────────────────────────────────────────
      dividerTheme: DividerThemeData(
        color: isDark ? _outline : cs.outlineVariant.withValues(alpha: 0.5),
        thickness: 1,
        space: 1,
      ),

      // ── List tiles ──────────────────────────────────────────────
      listTileTheme: ListTileThemeData(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        iconColor: cs.onSurfaceVariant,
        titleTextStyle: GoogleFonts.poppins(
          fontSize: 15, fontWeight: FontWeight.w500, color: cs.onSurface,
        ),
        subtitleTextStyle: GoogleFonts.poppins(
          fontSize: 13, color: cs.onSurfaceVariant,
        ),
      ),

      // ── Tabs ────────────────────────────────────────────────────
      tabBarTheme: TabBarThemeData(
        labelColor: cs.primary,
        unselectedLabelColor: cs.onSurfaceVariant,
        indicatorColor: cs.primary,
        overlayColor: WidgetStatePropertyAll(_accent.withValues(alpha: 0.08)),
        dividerColor: isDark ? _outline : cs.outlineVariant.withValues(alpha: 0.5),
        labelStyle: GoogleFonts.poppins(fontSize: 14, fontWeight: FontWeight.w600),
        unselectedLabelStyle: GoogleFonts.poppins(fontSize: 14, fontWeight: FontWeight.w500),
      ),

      // ── Switches ────────────────────────────────────────────────
      switchTheme: SwitchThemeData(
        thumbColor: WidgetStateProperty.resolveWith((s) =>
            s.contains(WidgetState.selected) ? cs.primary : cs.outline),
        trackColor: WidgetStateProperty.resolveWith((s) =>
            s.contains(WidgetState.selected)
                ? _accentDim
                : (isDark ? _surfaceHigh : cs.surfaceContainerHighest)),
        overlayColor: WidgetStatePropertyAll(_accent.withValues(alpha: 0.1)),
      ),

      // ── Checkboxes ──────────────────────────────────────────────
      checkboxTheme: CheckboxThemeData(
        fillColor: WidgetStateProperty.resolveWith((s) =>
            s.contains(WidgetState.selected) ? cs.primary : Colors.transparent),
        checkColor: WidgetStatePropertyAll(cs.onPrimary),
        overlayColor: WidgetStatePropertyAll(_accent.withValues(alpha: 0.1)),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
      ),

      // ── Radio ───────────────────────────────────────────────────
      radioTheme: RadioThemeData(
        fillColor: WidgetStateProperty.resolveWith((s) =>
            s.contains(WidgetState.selected) ? cs.primary : cs.onSurfaceVariant),
        overlayColor: WidgetStatePropertyAll(_accent.withValues(alpha: 0.1)),
      ),

      // ── Progress ────────────────────────────────────────────────
      progressIndicatorTheme: ProgressIndicatorThemeData(
        color: cs.primary,
        linearTrackColor: _accentDim,
        circularTrackColor: _accentDim,
      ),

      // ── Sliders ─────────────────────────────────────────────────
      sliderTheme: SliderThemeData(
        activeTrackColor: cs.primary,
        thumbColor: cs.primary,
        overlayColor: _accent.withValues(alpha: 0.12),
        inactiveTrackColor: _accentDim,
      ),

      // ── Tooltips ────────────────────────────────────────────────
      tooltipTheme: TooltipThemeData(
        decoration: BoxDecoration(
          color: isDark ? _surfaceHigher : cs.inverseSurface,
          borderRadius: BorderRadius.circular(8),
        ),
        textStyle: GoogleFonts.poppins(
          color: isDark ? _textPrimary : cs.onInverseSurface, fontSize: 12,
        ),
      ),

      // ── Badges ──────────────────────────────────────────────────
      badgeTheme: BadgeThemeData(
        backgroundColor: cs.error,
        textColor: cs.onError,
      ),

      // ── Page transitions ────────────────────────────────────────
      pageTransitionsTheme: const PageTransitionsTheme(
        builders: {
          TargetPlatform.android: PredictiveBackPageTransitionsBuilder(),
          TargetPlatform.iOS:     CupertinoPageTransitionsBuilder(),
          TargetPlatform.macOS:   CupertinoPageTransitionsBuilder(),
          TargetPlatform.windows: FadeUpwardsPageTransitionsBuilder(),
          TargetPlatform.linux:   FadeUpwardsPageTransitionsBuilder(),
        },
      ),

      visualDensity: VisualDensity.adaptivePlatformDensity,
    );
  }

  static TextStyle _ts(double size, FontWeight weight, {double ls = 0}) =>
      GoogleFonts.poppins(fontSize: size, fontWeight: weight, letterSpacing: ls);
}