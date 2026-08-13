import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// The colours that change between themes.
///
/// These live in a [ThemeExtension] rather than as static constants so a single
/// widget tree can be repainted for light or dark without any global mutable
/// state. Read one with `context.palette`.
///
/// Status colours are in here too: `present` at its dark-theme value is far too
/// pale to read as text on a white card, so light gets its own, darker set.
@immutable
class AppPalette extends ThemeExtension<AppPalette> {
  const AppPalette({
    required this.brightness,
    required this.canvas,
    required this.surface,
    required this.surfaceHigh,
    required this.surfaceHigher,
    required this.outline,
    required this.outlineSoft,
    required this.accent,
    required this.accentSoft,
    required this.cyan,
    required this.textPrimary,
    required this.textSecondary,
    required this.textTertiary,
    required this.present,
    required this.absent,
    required this.cancelled,
    required this.warning,
  });

  final Brightness brightness;

  final Color canvas;
  final Color surface;
  final Color surfaceHigh;
  final Color surfaceHigher;
  final Color outline;
  final Color outlineSoft;

  final Color accent;
  final Color accentSoft;
  final Color cyan;

  final Color textPrimary;
  final Color textSecondary;
  final Color textTertiary;

  final Color present;
  final Color absent;
  final Color cancelled;
  final Color warning;

  bool get isDark => brightness == Brightness.dark;

  /// The original near-black canvas with layered surfaces for elevation.
  static const AppPalette dark = AppPalette(
    brightness: Brightness.dark,
    canvas: Color(0xFF0A0A0E),
    surface: Color(0xFF121218),
    surfaceHigh: Color(0xFF1A1A23),
    surfaceHigher: Color(0xFF23232E),
    outline: Color(0xFF2C2C39),
    outlineSoft: Color(0xFF1F1F29),
    accent: Color(0xFF7C6BFF),
    accentSoft: Color(0xFF2A2352),
    cyan: Color(0xFF4FD6D2),
    textPrimary: Color(0xFFF2F2F7),
    textSecondary: Color(0xFFA3A3B2),
    textTertiary: Color(0xFF6E6E80),
    present: Color(0xFF3DD68C),
    absent: Color(0xFFE87C7C),
    cancelled: Color(0xFF8A8A9E),
    // A muted sand rather than alarm-orange: "tight" means pay attention, not
    // panic, and this colour fills a whole meter bar.
    warning: Color(0xFFDFB57C),
  );

  /// Light is not an inversion of dark. Elevation runs the other way — the
  /// canvas is the *tinted* layer and cards sit on white above it — and every
  /// accent and status colour is darkened until it carries its meaning against
  /// a white card rather than glowing on black.
  static const AppPalette light = AppPalette(
    brightness: Brightness.light,
    canvas: Color(0xFFF4F4F8),
    surface: Color(0xFFFFFFFF),
    surfaceHigh: Color(0xFFF7F7FB),
    surfaceHigher: Color(0xFFEDEDF3),
    outline: Color(0xFFDCDCE6),
    outlineSoft: Color(0xFFE9E9F0),
    accent: Color(0xFF5B45E0),
    accentSoft: Color(0xFFE8E4FF),
    cyan: Color(0xFF0E9B96),
    textPrimary: Color(0xFF14141B),
    textSecondary: Color(0xFF5A5A6E),
    textTertiary: Color(0xFF8B8B9E),
    present: Color(0xFF12A05F),
    absent: Color(0xFFC0504E),
    cancelled: Color(0xFF77778C),
    // Bronze rather than the previous hot orange-brown. On white a warning
    // colour has to be dark to stay legible, so the calm comes from dropping
    // saturation instead of lightening it.
    warning: Color(0xFF8F6B33),
  );

  @override
  AppPalette copyWith({
    Brightness? brightness,
    Color? canvas,
    Color? surface,
    Color? surfaceHigh,
    Color? surfaceHigher,
    Color? outline,
    Color? outlineSoft,
    Color? accent,
    Color? accentSoft,
    Color? cyan,
    Color? textPrimary,
    Color? textSecondary,
    Color? textTertiary,
    Color? present,
    Color? absent,
    Color? cancelled,
    Color? warning,
  }) {
    return AppPalette(
      brightness: brightness ?? this.brightness,
      canvas: canvas ?? this.canvas,
      surface: surface ?? this.surface,
      surfaceHigh: surfaceHigh ?? this.surfaceHigh,
      surfaceHigher: surfaceHigher ?? this.surfaceHigher,
      outline: outline ?? this.outline,
      outlineSoft: outlineSoft ?? this.outlineSoft,
      accent: accent ?? this.accent,
      accentSoft: accentSoft ?? this.accentSoft,
      cyan: cyan ?? this.cyan,
      textPrimary: textPrimary ?? this.textPrimary,
      textSecondary: textSecondary ?? this.textSecondary,
      textTertiary: textTertiary ?? this.textTertiary,
      present: present ?? this.present,
      absent: absent ?? this.absent,
      cancelled: cancelled ?? this.cancelled,
      warning: warning ?? this.warning,
    );
  }

  @override
  AppPalette lerp(ThemeExtension<AppPalette>? other, double t) {
    if (other is! AppPalette) return this;
    return AppPalette(
      // Brightness cannot be interpolated, so it flips at the midpoint rather
      // than producing a nonsensical in-between value.
      brightness: t < 0.5 ? brightness : other.brightness,
      canvas: Color.lerp(canvas, other.canvas, t)!,
      surface: Color.lerp(surface, other.surface, t)!,
      surfaceHigh: Color.lerp(surfaceHigh, other.surfaceHigh, t)!,
      surfaceHigher: Color.lerp(surfaceHigher, other.surfaceHigher, t)!,
      outline: Color.lerp(outline, other.outline, t)!,
      outlineSoft: Color.lerp(outlineSoft, other.outlineSoft, t)!,
      accent: Color.lerp(accent, other.accent, t)!,
      accentSoft: Color.lerp(accentSoft, other.accentSoft, t)!,
      cyan: Color.lerp(cyan, other.cyan, t)!,
      textPrimary: Color.lerp(textPrimary, other.textPrimary, t)!,
      textSecondary: Color.lerp(textSecondary, other.textSecondary, t)!,
      textTertiary: Color.lerp(textTertiary, other.textTertiary, t)!,
      present: Color.lerp(present, other.present, t)!,
      absent: Color.lerp(absent, other.absent, t)!,
      cancelled: Color.lerp(cancelled, other.cancelled, t)!,
      warning: Color.lerp(warning, other.warning, t)!,
    );
  }
}

extension AppPaletteContext on BuildContext {
  /// The palette for the current theme. Falls back to dark rather than
  /// throwing, so a widget pumped in a bare `MaterialApp` in a test still
  /// renders.
  AppPalette get palette =>
      Theme.of(this).extension<AppPalette>() ?? AppPalette.dark;
}

/// Theme-independent design data.
class AppColors {
  const AppColors._();

  /// Palette offered when creating a subject.
  ///
  /// Stored as raw ARGB ints because that is exactly what goes into the
  /// database — it avoids any `Color.value` / `Color.toARGB32()` API churn
  /// between Flutter versions. Subject colours are the user's choice and are
  /// deliberately identical in both themes so a subject stays recognisable.
  static const List<int> subjectPalette = <int>[
    0xFF7C6BFF,
    0xFF4FD6D2,
    0xFFFF7A9A,
    0xFFFFB84D,
    0xFF3DD68C,
    0xFF6BA8FF,
    0xFFD68CFF,
    0xFFFF9066,
    0xFF9BE36D,
    0xFF5CCFFF,
  ];

  static const int defaultSubjectColor = 0xFF7C6BFF;
}

/// Shared spacing / radius scale so layouts stay rhythmically consistent.
class AppSpacing {
  const AppSpacing._();

  static const double xs = 4;
  static const double sm = 8;
  static const double md = 12;
  static const double lg = 16;
  static const double xl = 24;
  static const double xxl = 32;

  static const double radiusSm = 10;
  static const double radiusMd = 16;
  static const double radiusLg = 22;
  static const double radiusXl = 28;
}

class AppTheme {
  const AppTheme._();

  /// System bars follow the palette, so the status bar icons stay legible when
  /// the theme flips.
  static SystemUiOverlayStyle overlayStyleFor(AppPalette p) {
    final Brightness icons = p.isDark ? Brightness.light : Brightness.dark;
    return SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: icons,
      statusBarBrightness: p.brightness,
      systemNavigationBarColor: p.canvas,
      systemNavigationBarIconBrightness: icons,
    );
  }

  static ThemeData dark() => _build(AppPalette.dark);

  static ThemeData light() => _build(AppPalette.light);

  /// One builder for both themes. Everything below reads from [p], so a colour
  /// can never be right in one theme and hard-coded wrong in the other.
  static ThemeData _build(AppPalette p) {
    final bool isDark = p.isDark;

    final ColorScheme scheme = ColorScheme(
      brightness: p.brightness,
      primary: p.accent,
      onPrimary: Colors.white,
      primaryContainer: p.accentSoft,
      onPrimaryContainer: isDark ? p.textPrimary : p.accent,
      secondary: p.cyan,
      onSecondary: isDark ? const Color(0xFF04302F) : Colors.white,
      secondaryContainer:
          isDark ? const Color(0xFF16403F) : const Color(0xFFD7F3F1),
      onSecondaryContainer: isDark ? p.textPrimary : const Color(0xFF06403D),
      error: p.absent,
      onError: Colors.white,
      errorContainer:
          isDark ? const Color(0xFF4A1F22) : const Color(0xFFFBE0E0),
      onErrorContainer: isDark ? p.textPrimary : const Color(0xFF5C1616),
      surface: p.surface,
      onSurface: p.textPrimary,
      onSurfaceVariant: p.textSecondary,
      surfaceContainerLowest: p.canvas,
      surfaceContainerLow: p.surface,
      surfaceContainer: p.surfaceHigh,
      surfaceContainerHigh: p.surfaceHigher,
      surfaceContainerHighest: p.surfaceHigher,
      outline: p.outline,
      outlineVariant: p.outlineSoft,
      inverseSurface: p.textPrimary,
      onInverseSurface: p.canvas,
      inversePrimary: p.accentSoft,
      shadow: Colors.black,
      scrim: Colors.black,
    );

    final ThemeData base = ThemeData(
      useMaterial3: true,
      brightness: p.brightness,
      colorScheme: scheme,
      scaffoldBackgroundColor: p.canvas,
      canvasColor: p.canvas,
      splashFactory: InkSparkle.splashFactory,
      visualDensity: VisualDensity.standard,
      extensions: <ThemeExtension<dynamic>>[p],
    );

    return base.copyWith(
      textTheme: _textTheme(base.textTheme, p),
      // Flutter 3.35 normalised component themes: ThemeData now takes the
      // *ThemeData variants of these two.
      appBarTheme: AppBarThemeData(
        backgroundColor: p.canvas,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
        systemOverlayStyle: overlayStyleFor(p),
        titleTextStyle: TextStyle(
          color: p.textPrimary,
          fontSize: 22,
          fontWeight: FontWeight.w700,
          letterSpacing: -0.4,
        ),
      ),
      dividerTheme: DividerThemeData(
        color: p.outlineSoft,
        thickness: 1,
        space: 1,
      ),
      bottomNavigationBarTheme: BottomNavigationBarThemeData(
        backgroundColor: p.surface,
        selectedItemColor: p.accent,
        unselectedItemColor: p.textTertiary,
        type: BottomNavigationBarType.fixed,
        elevation: 0,
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: p.surface,
        surfaceTintColor: Colors.transparent,
        indicatorColor: p.accentSoft,
        elevation: 0,
        height: 68,
        labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
        iconTheme: WidgetStateProperty.resolveWith<IconThemeData>((states) {
          final bool selected = states.contains(WidgetState.selected);
          return IconThemeData(
            size: 24,
            color: selected ? p.accent : p.textTertiary,
          );
        }),
        labelTextStyle: WidgetStateProperty.resolveWith<TextStyle>((states) {
          final bool selected = states.contains(WidgetState.selected);
          return TextStyle(
            fontSize: 11.5,
            fontWeight: selected ? FontWeight.w600 : FontWeight.w500,
            color: selected ? p.accent : p.textTertiary,
          );
        }),
      ),
      inputDecorationTheme: InputDecorationThemeData(
        filled: true,
        fillColor: p.surfaceHigh,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.lg,
          vertical: AppSpacing.lg,
        ),
        hintStyle: TextStyle(color: p.textTertiary),
        labelStyle: TextStyle(color: p.textSecondary),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
          borderSide: BorderSide(color: p.outline),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
          borderSide: BorderSide(color: p.outline),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
          borderSide: BorderSide(color: p.accent, width: 1.6),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
          borderSide: BorderSide(color: p.absent),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
          borderSide: BorderSide(color: p.absent, width: 1.6),
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: p.accent,
          foregroundColor: Colors.white,
          minimumSize: const Size(0, 52),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
          ),
          textStyle: const TextStyle(
            fontSize: 15.5,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: p.accent,
          textStyle: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: p.textPrimary,
          minimumSize: const Size(0, 52),
          side: BorderSide(color: p.outline),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
          ),
        ),
      ),
      floatingActionButtonTheme: FloatingActionButtonThemeData(
        backgroundColor: p.accent,
        foregroundColor: Colors.white,
        elevation: 0,
        focusElevation: 0,
        hoverElevation: 0,
        highlightElevation: 0,
      ),
      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: p.surface,
        surfaceTintColor: Colors.transparent,
        modalBackgroundColor: p.surface,
        showDragHandle: true,
        dragHandleColor: p.outline,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(
            top: Radius.circular(AppSpacing.radiusXl),
          ),
        ),
      ),
      snackBarTheme: SnackBarThemeData(
        // Dark keeps a raised surface; light needs a dark chip or the snackbar
        // vanishes into the page.
        backgroundColor: isDark ? p.surfaceHigher : const Color(0xFF23232E),
        contentTextStyle:
            TextStyle(color: isDark ? p.textPrimary : Colors.white),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
        ),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: p.surfaceHigh,
        surfaceTintColor: Colors.transparent,
      ),
      switchTheme: SwitchThemeData(
        thumbColor: WidgetStateProperty.resolveWith<Color>((states) {
          if (states.contains(WidgetState.selected)) return Colors.white;
          return isDark ? p.textTertiary : Colors.white;
        }),
        trackColor: WidgetStateProperty.resolveWith<Color>((states) {
          return states.contains(WidgetState.selected)
              ? p.accent
              : p.surfaceHigher;
        }),
        trackOutlineColor: WidgetStateProperty.all<Color>(
          isDark ? Colors.transparent : p.outline,
        ),
      ),
      listTileTheme: ListTileThemeData(
        iconColor: p.textSecondary,
        textColor: p.textPrimary,
      ),
      chipTheme: ChipThemeData(
        backgroundColor: p.surfaceHigh,
        side: BorderSide(color: p.outline),
        labelStyle: TextStyle(
          color: p.textSecondary,
          fontSize: 13,
          fontWeight: FontWeight.w500,
        ),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppSpacing.radiusSm),
        ),
      ),
      progressIndicatorTheme: ProgressIndicatorThemeData(
        color: p.accent,
        linearTrackColor: p.surfaceHigher,
        circularTrackColor: p.surfaceHigher,
      ),
    );
  }

  static TextTheme _textTheme(TextTheme base, AppPalette p) {
    return base
        .copyWith(
          displaySmall: base.displaySmall?.copyWith(
            fontWeight: FontWeight.w700,
            letterSpacing: -1.2,
          ),
          headlineMedium: base.headlineMedium?.copyWith(
            fontWeight: FontWeight.w700,
            letterSpacing: -0.8,
          ),
          headlineSmall: base.headlineSmall?.copyWith(
            fontWeight: FontWeight.w700,
            letterSpacing: -0.6,
          ),
          titleLarge: base.titleLarge?.copyWith(
            fontWeight: FontWeight.w700,
            letterSpacing: -0.4,
          ),
          titleMedium: base.titleMedium?.copyWith(
            fontWeight: FontWeight.w600,
            letterSpacing: -0.2,
          ),
          bodyMedium: base.bodyMedium?.copyWith(height: 1.35),
          labelLarge: base.labelLarge?.copyWith(fontWeight: FontWeight.w600),
        )
        .apply(bodyColor: p.textPrimary, displayColor: p.textPrimary);
  }
}
