import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'adapters/ports.dart';
import 'keyboard_nav.dart';
import 'theme.dart';

/// The end-alert sound picker (P4.3, UI-REFERENCE item 11): a full-screen
/// list of the `.mp3` files in the sounds directory — "No alert" first,
/// then the files alphabetically (compared WITHOUT the extension), each
/// with a ▶ preview and a checkmark on the current selection.
///
/// The listing is captured ONCE at open (rescan happens in
/// [soundListing]); an empty directory shows an explanatory state pointing
/// at [soundsDir]. Selection: `stop()` first (a running preview is cut on
/// every selection change), then the pick is reported via [onSelected] —
/// selecting does NOT auto-play, only ▶ does; the preview also auto-stops
/// when the screen is disposed. NOTE: rows do not pop the screen — the
/// pusher keeps its own copy up to date through [onSelected].
class AlertSelectorScreen extends StatefulWidget {
  const AlertSelectorScreen({
    super.key,
    required this.soundsDir,
    required this.soundListing,
    required this.player,
    required this.selected,
    required this.onSelected,
  });

  /// Sounds directory — previews play `'$soundsDir/$filename'`.
  final String soundsDir;

  /// Rescan-on-demand file-name listing of [soundsDir].
  final List<String> Function() soundListing;

  /// Preview player (play + stop hooks).
  final SoundPlayer player;

  /// Currently selected file name, or null = "No alert".
  final String? selected;

  /// Fired on every selection change with the new value (null = no alert).
  final void Function(String?) onSelected;

  @override
  State<AlertSelectorScreen> createState() => _AlertSelectorScreenState();
}

class _AlertSelectorScreenState extends State<AlertSelectorScreen> {
  /// Keyboard model (acceptance): up/down walks the alerts, Right plays
  /// the preview, Left stops it, Enter selects, Escape = back.
  final ScreenNav _nav = ScreenNav(sections: const []);

  KeyEventResult? _onKey(KeyEvent event) {
    if (event is! KeyDownEvent) return null;
    final key = event.logicalKey;
    if (key == LogicalKeyboardKey.arrowRight) {
      final idx = _nav.focusedCell?.row;
      final file = (idx == null || idx < 1 || idx > _files.length)
          ? null
          : _files[idx - 1];
      if (file != null) _preview(file);
      return KeyEventResult.handled;
    }
    if (key == LogicalKeyboardKey.arrowLeft) {
      unawaited(widget.player.stop());
      return KeyEventResult.handled;
    }
    if (key == LogicalKeyboardKey.escape) {
      Navigator.of(context).pop(); // = the back button (acceptance)
      return KeyEventResult.handled;
    }
    return null; // up/down/Home/End/Enter -> shared model
  }

  List<NavSection> _alertSections() {
    return [
      NavSection(id: 'top', cells: [
        NavCell(
          id: 'alert-back',
          row: 0,
          col: 0,
          activate: () => Navigator.of(context).pop(),
        ),
      ]),
      NavSection(id: 'alerts', cells: [
        NavCell(
          id: 'alert-none',
          row: 0,
          col: 0,
          activate: () => _select(null),
        ),
        for (var i = 0; i < _files.length; i++)
          NavCell(
            id: 'alert-$i',
            row: i + 1,
            col: 0,
            activate: () => _select(_files[i]),
          ),
      ]),
    ];
  }

  /// Files captured ONCE at open: `.mp3` only (case-insensitive), sorted
  /// alphabetically by the name WITHOUT its extension.
  late final List<String> _files;

  /// Live selection, seeded from [AlertSelectorScreen.selected]: kept
  /// locally because the pushing screen does not rebuild this route.
  String? _selected;

  @override
  void initState() {
    super.initState();
    // Focus starts in the ALERT LIST (acceptance), not on the back button.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && _nav.sections.length > 1) _nav.focusSection(1);
    });
    _selected = widget.selected;
    final files = [
      for (final name in widget.soundListing())
        if (name.toLowerCase().endsWith('.mp3')) name,
    ];
    files.sort((a, b) => _baseName(a).compareTo(_baseName(b)));
    _files = List<String>.unmodifiable(files);
  }

  @override
  void dispose() {
    // Preview auto-stops on exit.
    unawaited(widget.player.stop());
    super.dispose();
  }

  /// One selection: stop any running preview FIRST (auto-stop on selection
  /// change), commit locally, report the pick, and CLOSE (acceptance:
  /// "Auto closing End Alert UI when a sound is selected"). Selection
  /// never auto-plays.
  void _select(String? file) {
    unawaited(widget.player.stop());
    setState(() => _selected = file);
    widget.onSelected(file);
    Navigator.of(context).pop();
  }

  /// ▶ on a row: preview that file (the only way a preview starts).
  void _preview(String file) {
    unawaited(widget.player.play('${widget.soundsDir}/$file'));
  }



  @override
  Widget build(BuildContext context) {
    _nav.updateSections(_alertSections());
    return ListenableBuilder(
      listenable: _nav,
      builder: (context, _) => Scaffold(
      backgroundColor: Colors.transparent,
      body: SafeArea(
        child: NavKeyboard(
          nav: _nav,
          onKey: _onKey,
          // Centered content block like every other view (acceptance: "End
          // Alert placement" — the old Expanded empty-state forced the column
          // full-height, pinning the content to the top); scrolls when long.
          child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 520),
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(16, 10, 16, 24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _header(context),
                  const SizedBox(height: 10),
                  if (_files.isEmpty) _emptyState() else _list(),
                ],
              ),
            ),
          ),
        ),
        ),
      ),
      ),
    );
  }

  /// Outlined back circle | centered "End Alert" title.
  Widget _header(BuildContext context) {
    return Row(
      children: [
        FocusRing(
          focused: _nav.isFocused('alert-back'),
          circular: true,
          child: _BackCircle(
            key: const Key('as-back'),
            onPressed: () => Navigator.of(context).pop(),
          ),
        ),
        const Expanded(
          child: Text(
            'End Alert',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontFamily: AppFonts.ui,
              fontSize: 17,
              fontWeight: FontWeight.w700,
              color: AppColors.text,
            ),
          ),
        ),
        const SizedBox(width: 48), // balances the back circle for centering
      ],
    );
  }

  /// "No alert" first, then one card row per file.
  Widget _list() {
    return ListView(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      children: [
        FocusRing(
          focused: _nav.isFocused('alert-none'),
          child: _noneRow(),
        ),
        const SizedBox(height: 8),
        for (var i = 0; i < _files.length; i++) ...[
          FocusRing(
            focused: _nav.isFocused('alert-$i'),
            child: _fileRow(_files[i]),
          ),
          const SizedBox(height: 8),
        ],
      ],
    );
  }

  /// The null option: tap → onSelected(null); shows the check when nothing
  /// is selected.
  Widget _noneRow() {
    return GestureDetector(
      key: const Key('as-none'),
      behavior: HitTestBehavior.opaque,
      onTap: () => _select(null),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: AppDecorations.card,
        child: Row(
          children: [
            const Expanded(
              child: Text(
                'No alert',
                style: TextStyle(
                  fontFamily: AppFonts.ui,
                  fontSize: 15,
                  color: AppColors.text,
                ),
              ),
            ),
            if (_selected == null)
              const Icon(Icons.check, size: 20, color: AppColors.text),
          ],
        ),
      ),
    );
  }

  /// One file: label (minus extension) | check when selected | ▶ preview.
  /// Tapping the ROW selects; tapping ▶ only previews — the inner button
  /// wins the gesture arena over the row's tap.
  Widget _fileRow(String file) {
    return GestureDetector(
      key: Key('as-row-$file'),
      behavior: HitTestBehavior.opaque,
      onTap: () => _select(file),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
        decoration: AppDecorations.card,
        child: Row(
          children: [
            Expanded(
              child: Text(
                _baseName(file),
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontFamily: AppFonts.ui,
                  fontSize: 15,
                  color: AppColors.text,
                ),
              ),
            ),
            if (_selected == file)
              const Icon(Icons.check, size: 20, color: AppColors.text),
            IconButton(
              key: Key('as-play-$file'),
              icon: const Icon(Icons.play_arrow_outlined),
              tooltip: 'Preview',
              onPressed: () => _preview(file),
            ),
          ],
        ),
      ),
    );
  }

  /// Empty sounds directory: the explanatory state pointing at the path.
  Widget _emptyState() {
    return Column(
      key: const Key('as-empty'),
      mainAxisSize: MainAxisSize.min,
      children: [
        const Text(
          'No sounds found',
          textAlign: TextAlign.center,
          style: TextStyle(
            fontFamily: AppFonts.ui,
            fontSize: 15,
            color: AppColors.dimmed,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          'Drop .mp3 files into ${widget.soundsDir} and reopen.',
          textAlign: TextAlign.center,
          style: const TextStyle(
            fontFamily: AppFonts.ui,
            fontSize: 13,
            color: AppColors.dimmed,
          ),
        ),
      ],
    );
  }
}

/// Circular outlined button — the mock board's `_RoundOutlineButton` style,
/// used here for the header's back affordance.
class _BackCircle extends StatelessWidget {
  const _BackCircle({super.key, required this.onPressed});

  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return OutlinedButton(
      style: OutlinedButton.styleFrom(
        shape: const CircleBorder(),
        side: const BorderSide(
          color: AppColors.outline,
          width: AppDecorations.borderWidth,
        ),
        padding: const EdgeInsets.all(12),
      ),
      onPressed: onPressed,
      child: const Icon(Icons.arrow_back, size: 22, color: AppColors.text),
    );
  }
}

/// `chime.mp3` → `chime`: the row label / check display drops the extension.
String _baseName(String file) {
  final dot = file.lastIndexOf('.');
  return dot > 0 ? file.substring(0, dot) : file;
}
