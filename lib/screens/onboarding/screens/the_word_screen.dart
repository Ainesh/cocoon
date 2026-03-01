/// Screen 0 — Kairos splash text overlay.
///
/// Renders the centered logo + tagline on top of the persistent breathing
/// mosaic owned by [OnboardingFlow]. "Tap to continue" sits at the very
/// bottom of the screen, separate from the logo so it doesn't shift the
/// logo's vertical position.
library;

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../theme/app_colors.dart';

class TheWordScreen extends StatefulWidget {
  const TheWordScreen({super.key, required this.onTap});

  final VoidCallback onTap;

  @override
  State<TheWordScreen> createState() => _TheWordScreenState();
}

class _TheWordScreenState extends State<TheWordScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _textFadeController;
  bool _tapped = false;

  // ---------------------------------------------------------------------------
  // Lifecycle
  // ---------------------------------------------------------------------------

  @override
  void initState() {
    super.initState();

    _textFadeController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );
  }

  @override
  void dispose() {
    _textFadeController.dispose();
    super.dispose();
  }

  // ---------------------------------------------------------------------------
  // Actions
  // ---------------------------------------------------------------------------

  void _onTap() {
    if (_tapped) return;
    _tapped = true;
    _textFadeController.forward();
    widget.onTap();
  }

  // ---------------------------------------------------------------------------
  // Build
  // ---------------------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: _onTap,
      behavior: HitTestBehavior.opaque,
      child: AnimatedBuilder(
        animation: _textFadeController,
        builder: (context, _) {
          final textOpacity = 1.0 - _textFadeController.value;

          return Stack(
            children: [
              // Logo + tagline — exactly centered, matching splash screen
              Center(
                child: Opacity(
                  opacity: textOpacity,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        'Kairos',
                        style: GoogleFonts.drSugiyama(
                          fontSize: 52,
                          color: AppColors.refinedRed,
                          height: 1.2,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'this is the moment your journey begins',
                        style: GoogleFonts.outfit(
                          fontSize: 14,
                          color: AppColors.warmDim,
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              // "tap to continue" pinned to the bottom
              Positioned(
                left: 0,
                right: 0,
                bottom: MediaQuery.paddingOf(context).bottom + 32,
                child: Opacity(
                  opacity: textOpacity,
                  child: Text(
                    'tap to continue',
                    textAlign: TextAlign.center,
                    style: GoogleFonts.outfit(
                      fontSize: 15,
                      fontWeight: FontWeight.w500,
                      color: AppColors.warmDim,
                    ),
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}
