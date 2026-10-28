import 'package:flutter/material.dart';

import 'theme.dart';

/// Stub for the per-interval editor (P4.3 replaces this): pushed by the
/// timer editor's "+" toolbar button and by the empty-state add affordance.
/// Transparent scaffold over a centered card with the coming-soon note and
/// a close button.
class IntervalEditorPlaceholderScreen extends StatelessWidget {
  const IntervalEditorPlaceholderScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      key: const Key('interval-editor-placeholder'),
      backgroundColor: Colors.transparent,
      body: SafeArea(
        child: Center(
          child: Card(
            color: AppColors.card,
            elevation: 0,
            shape: const RoundedRectangleBorder(
              borderRadius: BorderRadius.all(Radius.circular(14)),
            ),
            child: Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: 24,
                vertical: 12,
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text(
                    'Interval editor — coming in P4.3',
                    style: TextStyle(
                      fontFamily: AppFonts.ui,
                      fontSize: 17,
                      color: AppColors.text,
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close),
                    color: AppColors.lightBlue,
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
