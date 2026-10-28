import 'package:flutter/material.dart';
import 'package:planner_engine/planner_engine.dart';

import 'app_controller.dart';
import 'theme.dart';

/// TEMPORARY debug screen (replaced by the real board in P3.1): snapshot
/// readout, run controls, and adapter smoke buttons. Boring and readable on
/// purpose — it exists to exercise the AppController end-to-end.
class DebugScreen extends StatelessWidget {
  const DebugScreen(this.controller, {super.key});

  final AppController controller;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: SafeArea(
        child: Center(
          child: ListenableBuilder(
            listenable: controller,
            builder: (context, _) {
              final s = controller.snapshot;
              final soundFiles = controller.soundListing();
              final firstSound = soundFiles.isEmpty
                  ? null
                  : '${controller.soundsDir}/${soundFiles.first}';
              return Container(
                width: 400,
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: AppColors.card,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _readout('State', s.state.name),
                    _readout(
                      'Interval',
                      s.ordinal == null ? '-' : '${s.ordinal! + 1}',
                    ),
                    _readout('Label', s.currentLabel ?? '<unnamed>'),
                    _readout('Remaining', _mmss(s.remaining)),
                    _readout('Total remaining', _mmss(s.totalRemaining)),
                    _readout('Total planned', _mmss(s.totalPlanned)),
                    const SizedBox(height: 16),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        _button(
                          'Start',
                          controller.start,
                          enabled: s.state == SessionState.notStarted,
                        ),
                        _button(
                          'Pause',
                          controller.pause,
                          enabled: s.state == SessionState.running,
                        ),
                        _button(
                          'Resume',
                          controller.resume,
                          enabled: s.state == SessionState.paused,
                        ),
                        _button(
                          'Skip',
                          controller.skipNext,
                          enabled: s.state != SessionState.notStarted,
                        ),
                        _button(
                          'Reset',
                          controller.reset,
                          enabled: s.state != SessionState.notStarted,
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    const Divider(color: AppColors.outline, height: 12),
                    const SizedBox(height: 4),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        ElevatedButton(
                          onPressed: () {
                            controller.notifier.show(
                              title: 'Planner',
                              body: 'Test notification',
                            );
                          },
                          child: const Text('Test notification'),
                        ),
                        ElevatedButton(
                          onPressed: firstSound == null
                              ? null
                              : () => controller.player.play(firstSound),
                          child: const Text('Test sound'),
                        ),
                      ],
                    ),
                  ],
                ),
              );
            },
          ),
        ),
      ),
    );
  }

  /// Label + value line; the value uses the digits font so numbers don't
  /// jitter as they tick down.
  Widget _readout(String label, String value) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 3),
    child: Row(
      children: [
        SizedBox(
          width: 150,
          child: Text(label, style: const TextStyle(color: AppColors.dimmed)),
        ),
        Expanded(
          child: Text(
            value,
            style: const TextStyle(
              fontFamily: AppFonts.digits,
              fontSize: 16,
              color: AppColors.text,
            ),
          ),
        ),
      ],
    ),
  );

  Widget _button(String label, VoidCallback onPressed, {required bool enabled}) =>
      ElevatedButton(
        onPressed: enabled ? onPressed : null,
        child: Text(label),
      );

  /// `mm:ss` of a duration (null → `-`); minutes run past 99 if needed.
  static String _mmss(Duration? d) {
    if (d == null) return '-';
    final m = d.inMinutes.toString().padLeft(2, '0');
    final s = (d.inSeconds % 60).toString().padLeft(2, '0');
    return '$m:$s';
  }
}
