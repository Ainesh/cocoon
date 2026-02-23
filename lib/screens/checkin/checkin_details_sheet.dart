/// Check-in details bottom sheet — view-only.
///
/// Shows a Voronoi mosaic tile pattern at the top representing the
/// individual pulse scores, with score indicators and optional reflection.
/// Matches the Moment Details Sheet design language.
library;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';

import '../../theme/theme.dart';
import '../../widgets/painters/voronoi_mosaic_painter.dart';

/// Shows check-in details in a modal bottom sheet.
void showCheckinDetailsSheet({
  required BuildContext context,
  required String actorName,
  required DateTime timestamp,
  required int connection,
  required int intimacy,
  required int peace,
  String? notes,
}) {
  HapticFeedback.mediumImpact();
  showModalBottomSheet(
    context: context,
    backgroundColor: Colors.transparent,
    isScrollControlled: true,
    builder: (context) => _CheckinDetailsContent(
      actorName: actorName,
      timestamp: timestamp,
      connection: connection,
      intimacy: intimacy,
      peace: peace,
      notes: notes,
    ),
  );
}

class _CheckinDetailsContent extends StatelessWidget {
  const _CheckinDetailsContent({
    required this.actorName,
    required this.timestamp,
    required this.connection,
    required this.intimacy,
    required this.peace,
    this.notes,
  });

  final String actorName;
  final DateTime timestamp;
  final int connection;
  final int intimacy;
  final int peace;
  final String? notes;

  Color _scoreColor(int score) =>
      Color.lerp(
        AppColors.morningColor,
        AppColors.nightColor,
        ((score - 1) / 9).clamp(0.0, 1.0),
      ) ??
      AppColors.nightColor;

  @override
  Widget build(BuildContext context) {
    final connColor = _scoreColor(connection);
    final intColor = _scoreColor(intimacy);
    final peaceColor = _scoreColor(peace);
    final dateStr = DateFormat('EEEE, MMM d').format(timestamp);

    return GestureDetector(
      onVerticalDragEnd: (details) {
        if (details.velocity.pixelsPerSecond.dy > 300) {
          Navigator.of(context).pop();
        }
      },
      child: Container(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(context).size.height * 0.75,
        ),
        decoration: const BoxDecoration(
          color: AppColors.pureBlack,
          borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Handle
            Container(
              margin: const EdgeInsets.only(top: 12),
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: AppColors.warmMuted,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            Flexible(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(24, 16, 24, 32),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    // "Check-in" heading
                    Text(
                      'Check-in',
                      style: GoogleFonts.outfit(
                        color: AppColors.warmLight,
                        fontSize: 28,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'Checked in by $actorName on $dateStr',
                      style: GoogleFonts.inter(
                        color: AppColors.warmMuted,
                        fontSize: 13,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 24),

                    // Pulse Check card — mosaic + 3 vertical bars
                    Container(
                      decoration: BoxDecoration(
                        color: AppColors.darkCardLight,
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // Mosaic with header
                            Stack(
                              children: [
                                SizedBox(
                                  height: 140,
                                  width: double.infinity,
                                  child: CustomPaint(
                                    painter: VoronoiGroupedPainter(
                                      groupColors: [
                                        connColor,
                                        intColor,
                                        peaceColor,
                                      ],
                                      seed: timestamp.millisecondsSinceEpoch,
                                      tileCount: 60,
                                      backgroundColor: AppColors.darkCardLight,
                                    ),
                                  ),
                                ),
                                Padding(
                                  padding: const EdgeInsets.all(14),
                                  child: Text(
                                    'PULSE CHECK',
                                    style: GoogleFonts.outfit(
                                      color: Colors.white.withValues(
                                        alpha: 0.9,
                                      ),
                                      fontSize: 10,
                                      fontWeight: FontWeight.w600,
                                      letterSpacing: 1.5,
                                      shadows: [
                                        Shadow(
                                          color: Colors.black.withValues(
                                            alpha: 0.6,
                                          ),
                                          blurRadius: 4,
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ],
                            ),

                            // 3 vertical bars
                            Padding(
                              padding: const EdgeInsets.fromLTRB(20, 8, 20, 16),
                              child: SizedBox(
                                height: 220,
                                child: Row(
                                  crossAxisAlignment:
                                      CrossAxisAlignment.stretch,
                                  children: [
                                    Expanded(
                                      child: _buildStaticBar(
                                        Icons.favorite_rounded,
                                        null,
                                        'Connection',
                                        connection,
                                      ),
                                    ),
                                    const SizedBox(width: 24),
                                    Expanded(
                                      child: _buildStaticBar(
                                        null,
                                        'assets/icons/flame.svg',
                                        'Intimacy',
                                        intimacy,
                                      ),
                                    ),
                                    const SizedBox(width: 24),
                                    Expanded(
                                      child: _buildStaticBar(
                                        null,
                                        'assets/icons/peace.svg',
                                        'Peace',
                                        peace,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),

                    // Reflection card (if notes present)
                    if (notes != null && notes!.isNotEmpty) ...[
                      const SizedBox(height: 12),
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: AppColors.darkCardLight,
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'REFLECTION',
                              style: GoogleFonts.outfit(
                                color: AppColors.warmMuted,
                                fontSize: 10,
                                fontWeight: FontWeight.w600,
                                letterSpacing: 1.5,
                              ),
                            ),
                            const SizedBox(height: 10),
                            Text(
                              notes!,
                              style: GoogleFonts.inter(
                                color: AppColors.warmDim,
                                fontSize: 14,
                                height: 1.5,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Static vertical bar — same look as VerticalBarSlider but read-only.
  Widget _buildStaticBar(
    IconData? icon,
    String? svgPath,
    String label,
    int score,
  ) {
    final color = _scoreColor(score);
    final progress = ((score - 1) / 9).clamp(0.0, 1.0);
    const borderRadius = 14.0;

    return Column(
      children: [
        // Vertical bar
        Expanded(
          child: LayoutBuilder(
            builder: (context, constraints) {
              final trackHeight = constraints.maxHeight;
              return SizedBox(
                width: double.infinity,
                height: trackHeight,
                child: Stack(
                  alignment: Alignment.bottomCenter,
                  children: [
                    Container(
                      width: double.infinity,
                      height: trackHeight,
                      decoration: BoxDecoration(
                        color: AppColors.cardVariant.withValues(alpha: 0.5),
                        borderRadius: BorderRadius.circular(borderRadius),
                      ),
                    ),
                    Container(
                      width: double.infinity,
                      height: (trackHeight * progress).clamp(
                        trackHeight * 0.05,
                        trackHeight,
                      ),
                      decoration: BoxDecoration(
                        color: color,
                        borderRadius: BorderRadius.circular(borderRadius),
                        boxShadow: [
                          BoxShadow(
                            color: color.withValues(alpha: 0.4),
                            blurRadius: 10,
                            spreadRadius: 1,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
        ),
        const SizedBox(height: 12),

        // Icon
        Container(
          width: 36,
          height: 36,
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.15),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Center(
            child: icon != null
                ? Icon(icon, color: color, size: 18)
                : SvgPicture.asset(
                    svgPath!,
                    width: 18,
                    height: 18,
                    colorFilter: ColorFilter.mode(color, BlendMode.srcIn),
                  ),
          ),
        ),
        const SizedBox(height: 6),

        // Label
        Text(
          label,
          style: GoogleFonts.inter(
            fontSize: 10,
            color: AppColors.warmMuted,
            letterSpacing: 0.3,
          ),
        ),
      ],
    );
  }
}
