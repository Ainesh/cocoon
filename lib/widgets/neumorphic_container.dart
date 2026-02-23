/// Neumorphic container widgets for premium dark UI effects.
///
/// Provides dark neumorphic cards with red glow and micro-interactions.
library;

import 'package:flutter/material.dart';

import '../theme/app_colors.dart';

// ---------------------------------------------------------------------------
// Premium Neumorphic Card
// ---------------------------------------------------------------------------

/// A premium dark neumorphic card with red glow and micro-interactions.
///
/// Features:
/// - Dark glass background with red glow shadow
/// - Scale animation on tap (0.98)
/// - Brighter glow on press
/// - Consistent styling across the app
class PremiumCard extends StatefulWidget {
  const PremiumCard({
    super.key,
    required this.child,
    this.onTap,
    this.padding = const EdgeInsets.all(20),
    this.margin = const EdgeInsets.only(bottom: 16),
    this.borderRadius = 24,
    this.glowIntensity = 1.0,
    this.enableInteraction = true,
  });

  final Widget child;
  final VoidCallback? onTap;
  final EdgeInsetsGeometry padding;
  final EdgeInsetsGeometry margin;
  final double borderRadius;
  final double glowIntensity;
  final bool enableInteraction;

  @override
  State<PremiumCard> createState() => _PremiumCardState();
}

class _PremiumCardState extends State<PremiumCard>
    with SingleTickerProviderStateMixin {
  bool _isPressed = false;
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    final isActive = _isPressed || _isHovered;
    final glowMultiplier = isActive ? 1.5 : 1.0;
    final elevation = isActive ? 8.0 : 4.0;

    return Padding(
      padding: widget.margin,
      child: MouseRegion(
        onEnter: (_) => setState(() => _isHovered = true),
        onExit: (_) => setState(() => _isHovered = false),
        child: GestureDetector(
          onTapDown: widget.enableInteraction
              ? (_) => setState(() => _isPressed = true)
              : null,
          onTapUp: widget.enableInteraction
              ? (_) {
                  setState(() => _isPressed = false);
                  widget.onTap?.call();
                }
              : null,
          onTapCancel: widget.enableInteraction
              ? () => setState(() => _isPressed = false)
              : null,
          onTap: !widget.enableInteraction ? widget.onTap : null,
          child: AnimatedScale(
            scale: _isPressed ? 0.98 : 1.0,
            duration: const Duration(milliseconds: 100),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 150),
              decoration: BoxDecoration(
                color: AppColors.darkCardLight,
                borderRadius: BorderRadius.circular(widget.borderRadius),
                border: Border.all(
                  color: AppColors.refinedRed.withValues(
                    alpha: isActive ? 0.3 : 0.1,
                  ),
                  width: 1,
                ),
                boxShadow: [
                  // Red glow
                  BoxShadow(
                    color: AppColors.refinedRed.withValues(
                      alpha: 0.15 * widget.glowIntensity * glowMultiplier,
                    ),
                    offset: Offset(0, isActive ? 6 : 4),
                    blurRadius: isActive ? 30 : 20,
                    spreadRadius: isActive ? 0 : -2,
                  ),
                  // Dark shadow
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.5),
                    offset: Offset(0, elevation),
                    blurRadius: 24,
                    spreadRadius: -4,
                  ),
                ],
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(widget.borderRadius),
                child: Padding(padding: widget.padding, child: widget.child),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Card Content Helpers
// ---------------------------------------------------------------------------

/// Card headline text style (20px bold white).
TextStyle cardHeadline(BuildContext context) {
  return const TextStyle(
    fontSize: 20,
    fontWeight: FontWeight.w700,
    color: AppColors.lightText,
    height: 1.2,
  );
}

/// Card title text style (16px semibold white).
TextStyle cardTitle(BuildContext context) {
  return const TextStyle(
    fontSize: 16,
    fontWeight: FontWeight.w600,
    color: AppColors.lightText,
  );
}

/// Card body text style (16px regular gray).
TextStyle cardBody(BuildContext context) {
  return const TextStyle(
    fontSize: 16,
    fontWeight: FontWeight.w400,
    color: AppColors.bodyGray,
  );
}

/// Card caption text style (14px gray).
TextStyle cardCaption(BuildContext context) {
  return const TextStyle(
    fontSize: 14,
    fontWeight: FontWeight.w400,
    color: AppColors.mutedText,
  );
}

/// Card icon with red color and 20px size.
Widget cardIcon(IconData icon, {double size = 20, Color? color}) {
  return Icon(icon, size: size, color: color ?? AppColors.refinedRed);
}

/// Red filled button for cards.
Widget cardButton({
  required String label,
  required VoidCallback onPressed,
  IconData? icon,
}) {
  return FilledButton(
    onPressed: onPressed,
    style: FilledButton.styleFrom(
      backgroundColor: AppColors.refinedRed,
      foregroundColor: Colors.white,
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
    ),
    child: icon != null
        ? Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 18),
              const SizedBox(width: 8),
              Text(label, style: const TextStyle(fontWeight: FontWeight.w600)),
            ],
          )
        : Text(label, style: const TextStyle(fontWeight: FontWeight.w600)),
  );
}

/// Outlined button for cards.
Widget cardOutlinedButton({
  required String label,
  required VoidCallback onPressed,
  IconData? icon,
}) {
  return OutlinedButton(
    onPressed: onPressed,
    style: OutlinedButton.styleFrom(
      foregroundColor: AppColors.refinedRed,
      side: BorderSide(color: AppColors.refinedRed.withValues(alpha: 0.5)),
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
    ),
    child: icon != null
        ? Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 18),
              const SizedBox(width: 8),
              Text(label, style: const TextStyle(fontWeight: FontWeight.w600)),
            ],
          )
        : Text(label, style: const TextStyle(fontWeight: FontWeight.w600)),
  );
}

// ---------------------------------------------------------------------------
// Metric Display
// ---------------------------------------------------------------------------

/// A metric display widget with emoji, value, and optional trend.
class MetricDisplay extends StatelessWidget {
  const MetricDisplay({
    super.key,
    required this.emoji,
    required this.label,
    required this.value,
    this.trend,
  });

  final String emoji;
  final String label;
  final String value;
  final double? trend;

  @override
  Widget build(BuildContext context) {
    IconData? trendIcon;
    Color? trendColor;

    if (trend != null) {
      if (trend! > 0.05) {
        trendIcon = Icons.trending_up;
        trendColor = AppColors.success;
      } else if (trend! < -0.05) {
        trendIcon = Icons.trending_down;
        trendColor = AppColors.refinedRed;
      } else {
        trendIcon = Icons.trending_flat;
        trendColor = AppColors.mutedText;
      }
    }

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.cardVariant,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.refinedRed.withValues(alpha: 0.1)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(emoji, style: const TextStyle(fontSize: 16)),
              const SizedBox(width: 6),
              Text(
                label,
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                  color: AppColors.mutedText,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Text(
                value,
                style: const TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.w700,
                  color: AppColors.lightText,
                ),
              ),
              if (trendIcon != null) ...[
                const SizedBox(width: 8),
                Icon(trendIcon, color: trendColor, size: 24),
              ],
            ],
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Score Badge
// ---------------------------------------------------------------------------

/// A compact score badge with emoji.
class ScoreBadge extends StatelessWidget {
  const ScoreBadge({super.key, required this.emoji, required this.score});

  final String emoji;
  final int score;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: AppColors.cardVariant,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppColors.refinedRed.withValues(alpha: 0.1)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(emoji, style: const TextStyle(fontSize: 14)),
          const SizedBox(width: 4),
          Text(
            score.toString(),
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w700,
              color: AppColors.lightText,
            ),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Event Item
// ---------------------------------------------------------------------------

/// An event list item with emoji, title, and subtitle.
class EventItem extends StatelessWidget {
  const EventItem({
    super.key,
    required this.emoji,
    required this.title,
    required this.subtitle,
    this.onTap,
  });

  final String emoji;
  final String title;
  final String subtitle;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 10),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: AppColors.cardVariant,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: AppColors.refinedRed.withValues(alpha: 0.1),
                ),
              ),
              child: Text(emoji, style: const TextStyle(fontSize: 20)),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Text(
                title,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w500,
                  color: AppColors.lightText,
                ),
              ),
            ),
            Text(
              subtitle,
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w500,
                color: AppColors.mutedText,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Activity Item
// ---------------------------------------------------------------------------

/// An activity list item for check-in timeline.
class ActivityItem extends StatelessWidget {
  const ActivityItem({
    super.key,
    required this.title,
    required this.subtitle,
    required this.scores,
    this.isCurrentUser = false,
  });

  final String title;
  final String subtitle;
  final List<Widget> scores;
  final bool isCurrentUser;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: isCurrentUser
                  ? AppColors.refinedRed.withValues(alpha: 0.15)
                  : AppColors.cardVariant,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: isCurrentUser
                    ? AppColors.refinedRed.withValues(alpha: 0.3)
                    : AppColors.refinedRed.withValues(alpha: 0.1),
              ),
            ),
            child: Icon(
              Icons.check_circle_outline_rounded,
              color: AppColors.refinedRed,
              size: 20,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w500,
                    color: AppColors.lightText,
                  ),
                ),
                Text(
                  subtitle,
                  style: const TextStyle(
                    fontSize: 14,
                    color: AppColors.mutedText,
                  ),
                ),
              ],
            ),
          ),
          Row(children: scores),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Section Header
// ---------------------------------------------------------------------------

/// A section header with icon and title.
class SectionHeader extends StatelessWidget {
  const SectionHeader({
    super.key,
    required this.icon,
    required this.title,
    this.trailing,
  });

  final IconData icon;
  final String title;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, color: AppColors.refinedRed, size: 24),
        const SizedBox(width: 10),
        Text(
          title,
          style: const TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w700,
            color: AppColors.lightText,
          ),
        ),
        if (trailing != null) ...[const Spacer(), trailing!],
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// Empty State
// ---------------------------------------------------------------------------

/// An empty state widget with icon, title, and optional action.
class EmptyState extends StatelessWidget {
  const EmptyState({
    super.key,
    required this.icon,
    required this.title,
    this.subtitle,
    this.actionLabel,
    this.onAction,
  });

  final IconData icon;
  final String title;
  final String? subtitle;
  final String? actionLabel;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: AppColors.cardVariant,
            shape: BoxShape.circle,
            border: Border.all(
              color: AppColors.refinedRed.withValues(alpha: 0.2),
            ),
          ),
          child: Icon(icon, size: 48, color: AppColors.mutedText),
        ),
        const SizedBox(height: 20),
        Text(
          title,
          style: const TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.w700,
            color: AppColors.lightText,
          ),
        ),
        if (subtitle != null) ...[
          const SizedBox(height: 8),
          Text(
            subtitle!,
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 16, color: AppColors.bodyGray),
          ),
        ],
        if (actionLabel != null && onAction != null) ...[
          const SizedBox(height: 20),
          cardButton(label: actionLabel!, onPressed: onAction!),
        ],
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// Legacy Support
// ---------------------------------------------------------------------------

/// Legacy neumorphic container (for backwards compatibility).
class NeumorphicContainer extends StatelessWidget {
  const NeumorphicContainer({
    super.key,
    required this.child,
    this.borderRadius = 24,
    this.padding,
    this.margin,
    this.width,
    this.height,
    this.isPressed = false,
    this.glowColor,
    this.intensity = 1.0,
  });

  final Widget child;
  final double borderRadius;
  final EdgeInsetsGeometry? padding;
  final EdgeInsetsGeometry? margin;
  final double? width;
  final double? height;
  final bool isPressed;
  final Color? glowColor;
  final double intensity;

  @override
  Widget build(BuildContext context) {
    final glow = glowColor ?? AppColors.refinedRed;

    return Container(
      width: width,
      height: height,
      margin: margin,
      decoration: BoxDecoration(
        color: AppColors.darkCardLight,
        borderRadius: BorderRadius.circular(borderRadius),
        border: Border.all(
          color: glow.withValues(alpha: 0.1 * intensity),
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: glow.withValues(alpha: 0.15 * intensity),
            offset: const Offset(0, 4),
            blurRadius: 20,
            spreadRadius: -2,
          ),
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.5 * intensity),
            offset: const Offset(0, 8),
            blurRadius: 24,
            spreadRadius: -4,
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(borderRadius),
        child: Container(padding: padding, child: child),
      ),
    );
  }
}

/// Alias for PremiumCard.
typedef NeumorphicCard = PremiumCard;

/// Alias for PremiumCard.
typedef GlassCard = PremiumCard;
