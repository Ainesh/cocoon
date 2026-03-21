/// Dashboard card prompting users about past moments.
///
/// Swipe-to-reveal pattern:
/// - Swipe RIGHT → reveals "Lived it" behind the card → creates memory
/// - Swipe LEFT  → reveals "Missed it" behind the card → creates memory
///
/// The card slides straight horizontally (no rotation). Action zones with
/// icons and labels are revealed underneath as the card moves.
/// Shows a first-time hint nudge animation until the user interacts.
library;

import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../models/moment.dart';
import '../../../theme/app_colors.dart';
import '../../../theme/app_typography.dart';
import '../../../utils/date_utils.dart';
import '../../../widgets/moment_type_icon.dart';

const _kHasSwipedPromptKey = 'has_swiped_prompt';
const _kCommitThreshold = 0.35;

class MemoryPromptCard extends StatefulWidget {
  const MemoryPromptCard({
    super.key,
    required this.moment,
    required this.onLived,
    required this.onMissed,
  });

  final Moment moment;
  final VoidCallback onLived;
  final VoidCallback onMissed;

  @override
  State<MemoryPromptCard> createState() => _MemoryPromptCardState();
}

class _MemoryPromptCardState extends State<MemoryPromptCard>
    with TickerProviderStateMixin {
  // ---------------------------------------------------------------------------
  // Controllers
  // ---------------------------------------------------------------------------

  late final AnimationController _springController;
  late final AnimationController _hintController;

  // ---------------------------------------------------------------------------
  // State
  // ---------------------------------------------------------------------------

  double _dragOffset = 0;
  double _cardWidth = 1;
  bool _committed = false;
  bool _pastThreshold = false;
  bool _showHint = false;
  bool _hintDismissed = false;

  // ---------------------------------------------------------------------------
  // Lifecycle
  // ---------------------------------------------------------------------------

  @override
  void initState() {
    super.initState();
    _springController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 250),
    );

    _hintController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2400),
    );
    _hintController.addListener(_onHintTick);

    _checkFirstTime();
  }

  @override
  void dispose() {
    _springController.dispose();
    _hintController.removeListener(_onHintTick);
    _hintController.dispose();
    super.dispose();
  }

  // ---------------------------------------------------------------------------
  // First-time hint
  // ---------------------------------------------------------------------------

  Future<void> _checkFirstTime() async {
    final prefs = await SharedPreferences.getInstance();
    if (!mounted) return;
    final hasSwiped = prefs.getBool(_kHasSwipedPromptKey) ?? false;
    if (!hasSwiped) {
      setState(() => _showHint = true);
      await Future.delayed(const Duration(milliseconds: 800));
      if (mounted && _showHint && !_hintDismissed) {
        _hintController.repeat();
      }
    }
  }

  void _onHintTick() {
    if (!mounted || _hintDismissed) return;
    setState(() {});
  }

  void _dismissHint() {
    if (!_showHint || _hintDismissed) return;
    _hintDismissed = true;
    _hintController.stop();
    _hintController.reset();
    setState(() => _showHint = false);
  }

  double get _hintOffset {
    if (!_showHint || _hintDismissed) return 0;
    final t = _hintController.value;
    if (t < 0.25) {
      return math.sin(t / 0.25 * math.pi / 2) * 40;
    } else if (t < 0.5) {
      return math.cos((t - 0.25) / 0.25 * math.pi / 2) * 40;
    } else if (t < 0.75) {
      return -math.sin((t - 0.5) / 0.25 * math.pi / 2) * 40;
    } else {
      return -math.cos((t - 0.75) / 0.25 * math.pi / 2) * 40;
    }
  }

  // ---------------------------------------------------------------------------
  // Haptics
  // ---------------------------------------------------------------------------

  void _playLivedHaptic() {
    HapticFeedback.lightImpact();
    Future.delayed(
        const Duration(milliseconds: 60), HapticFeedback.lightImpact);
    Future.delayed(
        const Duration(milliseconds: 120), HapticFeedback.lightImpact);
  }

  void _playMissedHaptic() {
    HapticFeedback.heavyImpact();
    Future.delayed(
        const Duration(milliseconds: 150), HapticFeedback.heavyImpact);
  }

  // ---------------------------------------------------------------------------
  // Drag handling
  // ---------------------------------------------------------------------------

  void _onDragStart(DragStartDetails _) {
    _dismissHint();
    _springController.stop();
  }

  void _onDragUpdate(DragUpdateDetails details) {
    if (_committed) return;
    setState(() => _dragOffset += details.delta.dx);

    final fraction = (_dragOffset.abs() / _cardWidth);
    final nowPastThreshold = fraction >= _kCommitThreshold;
    if (nowPastThreshold && !_pastThreshold) {
      HapticFeedback.selectionClick();
    }
    _pastThreshold = nowPastThreshold;
  }

  void _onDragEnd(DragEndDetails details) {
    if (_committed) return;
    final fraction = _dragOffset / _cardWidth;
    final velocity = details.primaryVelocity ?? 0;

    // Commit on threshold OR strong fling
    if (fraction.abs() >= _kCommitThreshold ||
        velocity.abs() > 800) {
      final direction = fraction != 0 ? fraction > 0 : velocity > 0;
      _commit(direction);
    } else {
      _springBack();
    }
  }

  void _springBack() {
    _pastThreshold = false;
    final start = _dragOffset;
    _springController.reset();
    _springController.duration = const Duration(milliseconds: 250);
    _springController.forward();

    late final VoidCallback listener;
    listener = () {
      if (!mounted) return;
      setState(() {
        _dragOffset =
            start * (1 - Curves.easeOutCubic.transform(
                _springController.value));
      });
      if (_springController.isCompleted) {
        _springController.removeListener(listener);
      }
    };
    _springController.addListener(listener);
  }

  Future<void> _commit(bool isLived) async {
    _committed = true;

    if (isLived) {
      _playLivedHaptic();
    } else {
      _playMissedHaptic();
    }

    SharedPreferences.getInstance().then((prefs) {
      prefs.setBool(_kHasSwipedPromptKey, true);
    });

    final target = isLived ? _cardWidth * 1.3 : -_cardWidth * 1.3;
    final start = _dragOffset;
    _springController.reset();
    _springController.duration = const Duration(milliseconds: 200);
    _springController.forward();

    late final VoidCallback listener;
    listener = () {
      if (!mounted) return;
      setState(() {
        _dragOffset = start +
            (target - start) *
                Curves.easeIn.transform(_springController.value);
      });
      if (_springController.isCompleted) {
        _springController.removeListener(listener);
        if (isLived) {
          widget.onLived();
        } else {
          widget.onMissed();
        }
      }
    };
    _springController.addListener(listener);
  }

  // ---------------------------------------------------------------------------
  // Build
  // ---------------------------------------------------------------------------

  double get _effectiveOffset => _dragOffset + _hintOffset;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        _cardWidth = constraints.maxWidth;
        final fraction =
            _cardWidth > 0 ? (_effectiveOffset / _cardWidth).clamp(-1.0, 1.0) : 0.0;
        final livedReveal = (fraction * 2.5).clamp(0.0, 1.0);
        final missedReveal = (-fraction * 2.5).clamp(0.0, 1.0);

        return ClipRRect(
          borderRadius: BorderRadius.circular(20),
          child: SizedBox(
            width: double.infinity,
            child: Stack(
              children: [
                // Background action zones (revealed behind the card)
                Positioned.fill(
                  child: Row(
                    children: [
                      // Left zone — "Lived it" (revealed on right swipe)
                      Expanded(
                        child: Container(
                          color: Color.lerp(
                            AppColors.darkCardLight,
                            AppColors.accentRed.withValues(alpha: 0.15),
                            livedReveal,
                          ),
                          alignment: Alignment.centerLeft,
                          padding: const EdgeInsets.only(left: 24),
                          child: Opacity(
                            opacity: livedReveal,
                            child: Transform.scale(
                              scale: 0.8 + livedReveal * 0.2,
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(
                                    Icons.favorite_rounded,
                                    color: AppColors.accentRed,
                                    size: 20 + livedReveal * 4,
                                  ),
                                  const SizedBox(width: 8),
                                  Text(
                                    'Lived it',
                                    style: GoogleFonts.outfit(
                                      color: AppColors.accentRed,
                                      fontSize: 14,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ),
                      // Right zone — "Missed it" (revealed on left swipe)
                      Expanded(
                        child: Container(
                          color: Color.lerp(
                            AppColors.darkCardLight,
                            AppColors.warmMuted.withValues(alpha: 0.12),
                            missedReveal,
                          ),
                          alignment: Alignment.centerRight,
                          padding: const EdgeInsets.only(right: 24),
                          child: Opacity(
                            opacity: missedReveal,
                            child: Transform.scale(
                              scale: 0.8 + missedReveal * 0.2,
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Text(
                                    'Missed it',
                                    style: GoogleFonts.outfit(
                                      color: AppColors.warmMuted,
                                      fontSize: 14,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Icon(
                                    Icons.close_rounded,
                                    color: AppColors.warmMuted,
                                    size: 20 + missedReveal * 4,
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

                // Foreground card (slides horizontally)
                GestureDetector(
                  onHorizontalDragStart: _onDragStart,
                  onHorizontalDragUpdate: _onDragUpdate,
                  onHorizontalDragEnd: _onDragEnd,
                  child: Transform.translate(
                    offset: Offset(_effectiveOffset, 0),
                    child: Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: AppColors.darkCardLight,
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                          color: _borderColor(livedReveal, missedReveal),
                        ),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            'HOW WAS IT?',
                            style: GoogleFonts.outfit(
                              color: AppColors.accentRed,
                              fontSize: 10,
                              fontWeight: FontWeight.w600,
                              letterSpacing: 1.5,
                            ),
                          ),
                          const SizedBox(height: 12),
                          Row(
                            children: [
                              getMomentTypeIconWidget(
                                  widget.moment.type,
                                  size: 28),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment:
                                      CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      widget.moment.name,
                                      style:
                                          AppTypography.headlineSmall(),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      AppDateFormat.short(
                                          widget.moment.startDate),
                                      style: AppTypography.bodySmall(
                                          color: AppColors.warmDim),
                                    ),
                                  ],
                                ),
                              ),
                              // Directional arrow hint
                              Icon(
                                Icons.swap_horiz_rounded,
                                color: AppColors.warmMuted
                                    .withValues(alpha: 0.3),
                                size: 20,
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Color _borderColor(double livedReveal, double missedReveal) {
    if (livedReveal > 0.1) {
      return AppColors.accentRed.withValues(alpha: livedReveal * 0.4);
    }
    if (missedReveal > 0.1) {
      return AppColors.warmMuted.withValues(alpha: missedReveal * 0.3);
    }
    return Colors.transparent;
  }
}
