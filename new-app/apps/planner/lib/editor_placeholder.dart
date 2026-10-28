import 'package:flutter/material.dart';

import 'theme.dart';

/// Placeholder for the interval editor (P4.1): the board's dial right-click
/// routes here. Renders a card with a "coming soon" note and a close button
/// — nothing editable yet.
class EditorPlaceholderScreen extends StatelessWidget {
  const EditorPlaceholderScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      key: const Key('editor-placeholder'),
      backgroundColor: Colors.transparent,
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            IconButton(
              icon: const Icon(Icons.close),
              color: AppColors.lightBlue,
              onPressed: () => Navigator.of(context).pop(),
            ),
            const Expanded(
              child: Center(
                child: Padding(
                  padding: EdgeInsets.all(24),
                  child: Card(
                    color: AppColors.card,
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.all(Radius.circular(14)),
                    ),
                    child: Padding(
                      padding: EdgeInsets.symmetric(
                        horizontal: 24,
                        vertical: 18,
                      ),
                      child: Text(
                        'Timer editor — coming in P4.1',
                        style: TextStyle(
                          fontFamily: AppFonts.ui,
                          fontSize: 17,
                          color: AppColors.text,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
