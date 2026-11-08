/// v2 (user request): the app paints a SOLID background instead of the
/// transparent-window look. The root wraps the navigator in a
/// [ColoredBox] driven by this notifier; the settings toggle (and the
/// boot seed in main.dart) write it. Default: transparent (the v1 look).
library;

import 'package:flutter/material.dart';

/// The solid alternative (a near-black matching the design language).
const Color solidBackgroundColor = Color(0xFF161616);

/// The app's current background paint — [Colors.transparent] unless the
/// settings toggle is on. Top-level: the root, the settings page, and
/// the boot seed all share it.
final ValueNotifier<Color> appBackground = ValueNotifier(Colors.transparent);
