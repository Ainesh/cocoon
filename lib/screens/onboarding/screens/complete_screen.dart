/// Screen 4 — Almost There: invite partner + notification permission.
///
/// Combines invite code sharing and the notification emotional hook
/// into a single scrollable screen.
library;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:share_plus/share_plus.dart';

import '../../../services/notification_service.dart';
import '../../../theme/app_colors.dart';
import '../../../theme/app_spacing.dart';
import '../../../theme/app_typography.dart';
import '../../../widgets/onboarding/desaturating_mosaic.dart';

class CompleteScreen extends StatefulWidget {
  const CompleteScreen({
    super.key,
    required this.inviteCode,
    required this.onFinish,
  });

  final String inviteCode;
  final VoidCallback onFinish;

  @override
  State<CompleteScreen> createState() => _CompleteScreenState();
}

class _CompleteScreenState extends State<CompleteScreen> {
  bool _codeCopied = false;
  bool _isDesaturated = false;
  bool _notifRequested = false;
  bool _isRequestingNotif = false;

  @override
  void initState() {
    super.initState();
    _runDesaturation();
  }

  Future<void> _runDesaturation() async {
    await Future.delayed(const Duration(milliseconds: 1500));
    if (!mounted) return;
    setState(() => _isDesaturated = true);
    HapticFeedback.lightImpact();
  }

  void _copyCode() {
    Clipboard.setData(ClipboardData(text: widget.inviteCode));
    HapticFeedback.mediumImpact();
    setState(() => _codeCopied = true);
    Future.delayed(const Duration(seconds: 2), () {
      if (mounted) setState(() => _codeCopied = false);
    });
  }

  void _shareCode() {
    HapticFeedback.lightImpact();
    Share.share(
      'Join my space on Kairos! Use code: ${widget.inviteCode}',
      subject: 'Kairos Invite',
    );
  }

  Future<void> _allowNotifications() async {
    setState(() => _isRequestingNotif = true);
    try {
      final notificationService = NotificationService();
      await notificationService.requestPermissionAgain();
    } catch (_) {}

    if (!mounted) return;
    setState(() {
      _isDesaturated = false;
      _isRequestingNotif = false;
      _notifRequested = true;
    });
    HapticFeedback.heavyImpact();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      color: AppColors.pureBlack,
      child: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.screenPadding,
                ),
                child: Column(
                  children: [
                    const SizedBox(height: AppSpacing.xxl),
                    Text(
                      'Almost there.',
                      style: AppTypography.headlineLarge(
                        color: AppColors.lightText,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: AppSpacing.xxxl),

                    // --- Invite section ---
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(AppSpacing.xl),
                      decoration: BoxDecoration(
                        color: AppColors.darkCardLight,
                        borderRadius: BorderRadius.circular(
                          AppSpacing.cardRadiusLarge,
                        ),
                        border: Border.all(
                          color: AppColors.refinedRed.withValues(alpha: 0.1),
                        ),
                      ),
                      child: Column(
                        children: [
                          Text(
                            'INVITE YOUR PARTNER',
                            style: AppTypography.cardLabel(),
                          ),
                          const SizedBox(height: AppSpacing.sm),
                          Text(
                            'Share this code to join your space.',
                            style: AppTypography.bodyMedium(
                              color: AppColors.warmDim,
                            ),
                          ),
                          const SizedBox(height: AppSpacing.lg),
                          SelectableText(
                            widget.inviteCode,
                            style: AppTypography.displaySmall(
                              color: AppColors.refinedRed,
                            ).copyWith(letterSpacing: 8),
                          ),
                          const SizedBox(height: AppSpacing.lg),
                          Row(
                            children: [
                              Expanded(
                                child: _ActionChip(
                                  icon: _codeCopied
                                      ? Icons.check_rounded
                                      : Icons.copy_rounded,
                                  label: _codeCopied ? 'Copied!' : 'Copy',
                                  onTap: _copyCode,
                                ),
                              ),
                              const SizedBox(width: AppSpacing.md),
                              Expanded(
                                child: _ActionChip(
                                  icon: Icons.share_rounded,
                                  label: 'Share',
                                  onTap: _shareCode,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: AppSpacing.xxl),

                    // --- Notification section ---
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(AppSpacing.xl),
                      decoration: BoxDecoration(
                        color: AppColors.darkCardLight,
                        borderRadius: BorderRadius.circular(
                          AppSpacing.cardRadiusLarge,
                        ),
                      ),
                      child: Column(
                        children: [
                          Center(
                            child: DesaturatingMosaic(
                              score: 0.72,
                              isDesaturated: _isDesaturated,
                              size: const Size(220, 100),
                              tileCount: 35,
                            ),
                          ),
                          const SizedBox(height: AppSpacing.lg),
                          AnimatedSwitcher(
                            duration: const Duration(milliseconds: 400),
                            child: _notifRequested
                                ? Text(
                                    'You\'re all set.',
                                    key: const ValueKey('done'),
                                    style: AppTypography.titleMedium(
                                      color: AppColors.success,
                                    ),
                                    textAlign: TextAlign.center,
                                  )
                                : _isDesaturated
                                    ? Text(
                                        'Without you, the colors fade.',
                                        key: const ValueKey('fade'),
                                        style: AppTypography.titleMedium(
                                          color: AppColors.warmMuted,
                                        ),
                                        textAlign: TextAlign.center,
                                      )
                                    : Text(
                                        'Stay present. Stay vivid.',
                                        key: const ValueKey('vivid'),
                                        style: AppTypography.titleMedium(
                                          color: AppColors.lightText,
                                        ),
                                        textAlign: TextAlign.center,
                                      ),
                          ),
                          const SizedBox(height: AppSpacing.sm),
                          if (!_notifRequested)
                            Text(
                              'A gentle nudge when it\'s time to check in.',
                              style: AppTypography.bodySmall(
                                color: AppColors.warmDim,
                              ),
                              textAlign: TextAlign.center,
                            ),
                          if (!_notifRequested) ...[
                            const SizedBox(height: AppSpacing.lg),
                            GestureDetector(
                              onTap: !_isRequestingNotif
                                  ? _allowNotifications
                                  : null,
                              child: Container(
                                height: 44,
                                decoration: BoxDecoration(
                                  color: AppColors.refinedRed,
                                  borderRadius: BorderRadius.circular(
                                    AppSpacing.radiusMedium,
                                  ),
                                ),
                                alignment: Alignment.center,
                                child: _isRequestingNotif
                                    ? const SizedBox(
                                        width: 20,
                                        height: 20,
                                        child: CircularProgressIndicator(
                                          strokeWidth: 2,
                                          color: AppColors.pureBlack,
                                        ),
                                      )
                                    : Row(
                                        mainAxisAlignment:
                                            MainAxisAlignment.center,
                                        children: [
                                          const Icon(
                                            Icons
                                                .notifications_active_rounded,
                                            size: 18,
                                            color: AppColors.pureBlack,
                                          ),
                                          const SizedBox(width: 8),
                                          Text(
                                            'Keep My Mosaic Alive',
                                            style:
                                                AppTypography.labelLarge(
                                              color: AppColors.pureBlack,
                                            ),
                                          ),
                                        ],
                                      ),
                              ),
                            ),
                            const SizedBox(height: AppSpacing.sm),
                            GestureDetector(
                              onTap: () {
                                HapticFeedback.lightImpact();
                                setState(() => _notifRequested = true);
                              },
                              child: Text(
                                'I\'ll do it later',
                                style: AppTypography.labelSmall(
                                  color: AppColors.warmMuted,
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                    const SizedBox(height: AppSpacing.xxl),
                  ],
                ),
              ),
            ),

            // Start button
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 16),
              child: GestureDetector(
                onTap: () {
                  HapticFeedback.heavyImpact();
                  widget.onFinish();
                },
                child: Container(
                  height: AppSpacing.buttonHeightLarge,
                  decoration: BoxDecoration(
                    color: AppColors.refinedRed,
                    borderRadius:
                        BorderRadius.circular(AppSpacing.cardRadius),
                  ),
                  alignment: Alignment.center,
                  child: Text(
                    'Start',
                    style: AppTypography.titleMedium(
                      color: AppColors.pureBlack,
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

class _ActionChip extends StatelessWidget {
  const _ActionChip({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: 44,
        decoration: BoxDecoration(
          color: AppColors.cardVariant,
          borderRadius: BorderRadius.circular(AppSpacing.radiusMedium),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 16, color: AppColors.lightText),
            const SizedBox(width: 8),
            Text(label, style: AppTypography.labelLarge()),
          ],
        ),
      ),
    );
  }
}
