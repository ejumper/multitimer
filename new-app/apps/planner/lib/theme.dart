import 'package:flutter/material.dart';

/// Bundled font families (registered in pubspec.yaml; local-only assets).
abstract final class AppFonts {
  /// UI text font.
  static const String ui = 'ProLisa';

  /// Timer/number readouts — monospace so digits don't jitter.
  static const String digits = 'MonoLisa';
}

/// The selected-swatch dot color: black on light swatches (white /
/// near-white — and anything else too luminous for a white dot, e.g.
/// lime), white otherwise. Perceptual-luminance threshold at 0.5.
Color contrastDot(Color background) =>
    background.computeLuminance() > 0.5 ? Colors.black : Colors.white;

/// v1 color tokens (OUTLINE.md D11).
abstract final class AppColors {
  /// Text/foreground.
  static const Color text = Color(0xFFF2F2F2);

/// Preset accent swatches (interval/timer colors).
  static const Color magenta = Color(0xFFFF00B1);
  static const Color violet = Color(0xFF4800FF);
  static const Color blue = Color(0xFF0055FF);
  static const Color lightBlue = Color(0xFF00A8FF);
  static const Color green = Color(0xFF00AD6B);
  static const Color lime = Color(0xFFB8FF00);

  /// Semi-transparent dark "card" background — legible over compositor blur.
  /// (black @ ~11%; halved twice per acceptance — "still too prominent,
  /// half again". Tunable for legibility.)
  static const Color card = Color(0x1D000000);

  /// Border around the card-colored surfaces: the same black, 25% more
  /// opaque than [card] (acceptance) — a hairline slightly stronger than
  /// the fill.
  static const Color cardBorder = Color(0x24000000);

  /// Dimmed/disabled content.
  static const Color dimmed = Color(0x66F2F2F2);

  /// Hairlines, brackets, outlines.
  static const Color outline = Color(0x40F2F2F2);

  /// Destructive actions (delete, reset) — the ONLY UI color besides the
  /// timer/interval swatch colors (greyscale-UI rule).
  static const Color danger = Color(0xFFFF4D4D);
}

/// Symmetric cross-fade route transition (all platforms).
///
/// Replaces Flutter's default [ZoomPageTransitionsBuilder] on this app for
/// two reasons (the acceptance "forward-route transition glitch"):
///  - the zoom builder fades in a `colorScheme.surface` SCRIM behind the
///    entering route — on this theme that is the semi-transparent card
///    color, i.e. a full-window grey wash on a transparent window;
///  - it animates routes as rasterized snapshots (SnapshotWidget), whose
///    stale composite froze behind the new route on forward pushes until
///    the next happenstance frame.
/// This builder uses neither — just opacity: the route fades in on its own
/// [animation] and out on its [secondaryAnimation] when covered, so push
/// and pop are the same clean cross-fade in both directions.
class CrossFadePageTransitionsBuilder extends PageTransitionsBuilder {
  const CrossFadePageTransitionsBuilder();

  /// Exit curve, written against the DECREASING value axis of a reverse
  /// animation: Interval(0.5, 1.0) = the value's TOP half = the exit's
  /// FIRST half (gone by halfway ≈ 75ms of the 150ms transition), and
  /// easeIn = the fast initial drop — the screen going away is the snappy
  /// direction (acceptance: fade-out must be faster than fade-in).
  static const Curve _exitFade = Interval(0.5, 1.0, curve: Curves.easeIn);

  @override
  Widget buildTransitions<T>(
    PageRoute<T> route,
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
    Widget child,
  ) {
    return FadeTransition(
      // reverseCurve = the route POPPING (its own exit).
      opacity: CurvedAnimation(
        parent: animation,
        curve: Curves.easeOut,
        reverseCurve: _exitFade,
      ),
      child: FadeTransition(
        opacity: coverFade(secondaryAnimation),
        child: child,
      ),
    );
  }

  /// Lets routes built by OTHER builders cover this one the same way.
  @override
  DelegatedTransitionBuilder? get delegatedTransition =>
      (context, animation, secondaryAnimation, allowSnapshotting, child) =>
          FadeTransition(opacity: coverFade(secondaryAnimation), child: child);

  /// The covered route fades OUT (fast — first half of the transition) as
  /// the route above comes in and back IN (normal) when it pops —
  /// [ReverseAnimation] flips the status, so the covered exit lands on
  /// `reverseCurve` and the uncover on `curve`.
  static Animation<double> coverFade(Animation<double> secondary) =>
      CurvedAnimation(
        parent: ReverseAnimation(secondary),
        curve: Curves.easeOut,
        reverseCurve: _exitFade,
      );
}

/// App page route: the theme's cross-fade at HALF the stock duration
/// (acceptance: "cut both the fade times by half" — snappy page changes;
/// fades-in run the full 150ms, fades-out are gone by ~75ms).
class AppPageRoute<T> extends MaterialPageRoute<T> {
  AppPageRoute({required super.builder, super.settings});

  @override
  Duration get transitionDuration => const Duration(milliseconds: 150);
}

/// Preset accent swatches — D11 colors plus the grey scale (acceptance),
/// in row order. Shared by the timer and interval editors.
const List<String> kPresetSwatches = [
  '#e2e2e2',
  '#5d5d5d',
  '#080808',
  '#ff00b1',
  '#4800ff',
  '#0055ff',
  '#00a8ff',
  '#00ad6b',
  '#b8ff00',
];

/// The unified shape system (acceptance "unify the UI elements") — exactly
/// TWO corner radii and ONE border width everywhere:
///  - PILL (stadium) — done button, toggle, group bars;
///  - [rectRadius] rectangle — every semi-transparent background, interval
///    chip, duration setter and menu (the cards' "slightly more" value the
///    user picked over the chips' old 10);
///  - [borderWidth] — the intervals' 1.4, now the only border thickness.
abstract final class AppDecorations {
  static const double rectRadius = 14;
  static const double borderWidth = 1.4;

  /// Shared card background (translucent + hairline border).
  static const BoxDecoration card = BoxDecoration(
    color: AppColors.card,
    border: Border.fromBorderSide(
      BorderSide(color: AppColors.cardBorder, width: borderWidth),
    ),
    borderRadius: BorderRadius.all(Radius.circular(rectRadius)),
  );

  /// Shared dialog/menu shape — rectangle radius + unified border.
  static const ShapeBorder menuShape = RoundedRectangleBorder(
    borderRadius: BorderRadius.all(Radius.circular(rectRadius)),
    side: BorderSide(color: AppColors.cardBorder, width: borderWidth),
  );

  /// The hairline separator inside joined cards (border's own style).
  static const BorderSide divider = BorderSide(
    color: AppColors.cardBorder,
    width: borderWidth,
  );
}

/// App theme: transparent scaffold over the compositor's blur, dark content.
ThemeData buildPlannerTheme() {
  final base = ThemeData.dark(useMaterial3: true);
  return base.copyWith(
    // Fully transparent window background — the compositor supplies blur.
    scaffoldBackgroundColor: const Color(0x00000000),
    colorScheme: base.colorScheme.copyWith(
      primary: AppColors.blue,
      secondary: AppColors.lightBlue,
      surface: AppColors.card,
      onSurface: AppColors.text,
    ),
    textTheme: base.textTheme.apply(
      bodyColor: AppColors.text,
      displayColor: AppColors.text,
      fontFamily: AppFonts.ui,
    ),
    // Greyscale UI rule: chrome icons use the text color — the only
    // colored UI is destructive red and the timer/interval swatches.
    iconTheme: const IconThemeData(color: AppColors.text, size: 26),
    splashFactory: InkSparkle.splashFactory,
    // Plain cross-fade route transitions (see CrossFadePageTransitionsBuilder
    // — the default zoom builder paints a surface scrim and rasterizes
    // routes, which washed and froze the window on forward pushes).
    pageTransitionsTheme: const PageTransitionsTheme(
      builders: {
        TargetPlatform.android: CrossFadePageTransitionsBuilder(),
        TargetPlatform.fuchsia: CrossFadePageTransitionsBuilder(),
        TargetPlatform.iOS: CrossFadePageTransitionsBuilder(),
        TargetPlatform.linux: CrossFadePageTransitionsBuilder(),
        TargetPlatform.macOS: CrossFadePageTransitionsBuilder(),
        TargetPlatform.windows: CrossFadePageTransitionsBuilder(),
      },
    ),
  );
}
