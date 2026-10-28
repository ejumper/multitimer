import 'dart:ui' as ui;

import 'package:flutter/material.dart';

/// Bundled font families (registered in pubspec.yaml; local-only assets).
abstract final class AppFonts {
  /// UI text font.
  static const String ui = 'ProLisa';

  /// Timer/number readouts — monospace so digits don't jitter.
  static const String digits = 'MonoLisa';
}

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
  /// (black @ ~22%; halved from 0x73 per acceptance — "too high, cut it in
  /// half". Tunable for legibility.)
  static const Color card = Color(0x39000000);

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

  /// Exit curve: completes in the first half of the transition — a screen
  /// going AWAY fades out twice as fast as one coming in.
  static const Curve _fastOut = Interval(0.0, 0.5, curve: Curves.easeOut);

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
        reverseCurve: _fastOut,
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

  /// The covered route fades OUT (double speed) as the route above comes in
  /// and back IN (normal speed) when it pops — [ReverseAnimation] flips the
  /// status, so the covered exit lands on `reverseCurve` and the uncover on
  /// `curve`.
  static Animation<double> coverFade(Animation<double> secondary) =>
      CurvedAnimation(
        parent: ReverseAnimation(secondary),
        curve: Curves.easeOut,
        reverseCurve: _fastOut,
      );
}

/// Wraps modal content in a full-screen blur layer (acceptance: "blur the
/// UI elements behind overlays" for readability).
Widget blurredBackdrop(Widget dialog, {double sigma = 8}) {
  return Stack(
    fit: StackFit.expand,
    children: [
      BackdropFilter(
        filter: ui.ImageFilter.blur(sigmaX: sigma, sigmaY: sigma),
        child: const SizedBox.expand(),
      ),
      Center(child: dialog),
    ],
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
