/// Moment details bottom sheet showing full moment information.
library;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../models/moment.dart';
import '../../theme/theme.dart';

/// Shows moment details in a modal bottom sheet.
void showMomentDetailsSheet({
  required BuildContext context,
  required Moment moment,
  VoidCallback? onEdit,
  VoidCallback? onDelete,
}) {
  HapticFeedback.mediumImpact();
  showModalBottomSheet(
    context: context,
    backgroundColor: Colors.transparent,
    isScrollControlled: true,
    builder: (context) => _MomentDetailsContent(
      moment: moment,
      onEdit: onEdit,
      onDelete: onDelete,
    ),
  );
}

class _MomentDetailsContent extends StatelessWidget {
  const _MomentDetailsContent({
    required this.moment,
    this.onEdit,
    this.onDelete,
  });

  final Moment moment;
  final VoidCallback? onEdit;
  final VoidCallback? onDelete;

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.75,
      ),
      decoration: const BoxDecoration(
        color: AppColors.darkCard,
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
              padding: const EdgeInsets.all(24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  // Type badge with icon
                  _buildTypeBadge(),
                  const SizedBox(height: 20),
                  
                  // Moment name - large and prominent
                  Text(
                    moment.name,
                    style: GoogleFonts.outfit(
                      color: AppColors.warmLight,
                      fontSize: 32,
                      fontWeight: FontWeight.w700,
                      height: 1.1,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 8),
                  
                  // Flowing hint under name
                  Text(
                    _getTypeHint(),
                    style: GoogleFonts.cormorantGaramond(
                      color: AppColors.warmDim,
                      fontSize: 20,
                      fontWeight: FontWeight.w500,
                      fontStyle: FontStyle.italic,
                    ),
                  ),
                  const SizedBox(height: 32),
                  
                  // Info cards row
                  _buildInfoRow(),
                  
                  // Notes section (if available)
                  if (moment.notes != null && moment.notes!.isNotEmpty) ...[
                    const SizedBox(height: 20),
                    _buildNotesSection(),
                  ],
                  
                  const SizedBox(height: 32),
                  
                  // Action buttons
                  _buildActions(context),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTypeBadge() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(
        color: AppColors.accentRed,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: AppColors.accentRed.withValues(alpha: 0.4),
            blurRadius: 16,
            spreadRadius: 0,
          ),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            _getTypeIcon(),
            color: AppColors.pureBlack,
            size: 18,
          ),
          const SizedBox(width: 8),
          Text(
            moment.type.label,
            style: GoogleFonts.outfit(
              color: AppColors.pureBlack,
              fontSize: 14,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  IconData _getTypeIcon() {
    return switch (moment.type) {
      MomentType.celebrate => Icons.auto_awesome_rounded,
      MomentType.connect => Icons.power_rounded,
      MomentType.escape => Icons.flight_rounded,
    };
  }

  String _getTypeHint() {
    return switch (moment.type) {
      MomentType.celebrate => 'a special day to remember',
      MomentType.connect => 'time together',
      MomentType.escape => 'an adventure awaits',
    };
  }

  Widget _buildInfoRow() {
    return Row(
      children: [
        // Date card
        Expanded(child: _buildDateCard()),
        const SizedBox(width: 12),
        // Time/Duration card
        Expanded(child: _buildSecondaryCard()),
      ],
    );
  }

  Widget _buildDateCard() {
    final isEscape = moment.type == MomentType.escape;
    
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.darkCardLight,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: AppColors.accentRed.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(
                  Icons.calendar_today_rounded,
                  color: AppColors.accentRed,
                  size: 18,
                ),
              ),
              const SizedBox(width: 12),
              Text(
                isEscape ? 'DATES' : 'DATE',
                style: GoogleFonts.inter(
                  color: AppColors.warmMuted,
                  fontSize: 10,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 1.5,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          if (isEscape && moment.endDate != null) ...[
            Text(
              _formatDateShort(moment.startDate),
              style: GoogleFonts.outfit(
                color: AppColors.warmLight,
                fontSize: 18,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 4),
            Row(
              children: [
                Icon(Icons.arrow_downward_rounded, color: AppColors.warmMuted, size: 14),
                const SizedBox(width: 4),
                Text(
                  _formatDateShort(moment.endDate!),
                  style: GoogleFonts.outfit(
                    color: AppColors.warmLight,
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ] else ...[
            Text(
              _formatDateFull(moment.startDate),
              style: GoogleFonts.outfit(
                color: AppColors.warmLight,
                fontSize: 18,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              _getRelativeDate(),
              style: GoogleFonts.inter(
                color: AppColors.accentRed,
                fontSize: 13,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildSecondaryCard() {
    // For Connect: show time slot
    // For Escape: show duration
    // For Celebrate: show countdown or status
    
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.darkCardLight,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: AppColors.accentRed.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(
                  _getSecondaryIcon(),
                  color: AppColors.accentRed,
                  size: 18,
                ),
              ),
              const SizedBox(width: 12),
              Text(
                _getSecondaryLabel(),
                style: GoogleFonts.inter(
                  color: AppColors.warmMuted,
                  fontSize: 10,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 1.5,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            _getSecondaryValue(),
            style: GoogleFonts.outfit(
              color: AppColors.warmLight,
              fontSize: 18,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            _getSecondarySubtext(),
            style: GoogleFonts.inter(
              color: AppColors.warmMuted,
              fontSize: 13,
            ),
          ),
        ],
      ),
    );
  }

  IconData _getSecondaryIcon() {
    return switch (moment.type) {
      MomentType.connect => Icons.schedule_rounded,
      MomentType.escape => Icons.nights_stay_rounded,
      MomentType.celebrate => Icons.timer_outlined,
    };
  }

  String _getSecondaryLabel() {
    return switch (moment.type) {
      MomentType.connect => 'TIME',
      MomentType.escape => 'DURATION',
      MomentType.celebrate => 'STATUS',
    };
  }

  String _getSecondaryValue() {
    return switch (moment.type) {
      MomentType.connect => moment.timeSlot?.label ?? 'Anytime',
      MomentType.escape => _getDurationText(),
      MomentType.celebrate => _getStatusText(),
    };
  }

  String _getSecondarySubtext() {
    return switch (moment.type) {
      MomentType.connect => moment.timeSlot?.timeRange ?? 'Flexible timing',
      MomentType.escape => _getNightsText(),
      MomentType.celebrate => _getCountdownText(),
    };
  }

  String _getDurationText() {
    if (moment.endDate == null) return '1 day';
    final days = moment.endDate!.difference(moment.startDate).inDays + 1;
    return '$days days';
  }

  String _getNightsText() {
    if (moment.endDate == null) return 'Day trip';
    final nights = moment.endDate!.difference(moment.startDate).inDays;
    return nights == 1 ? '1 night away' : '$nights nights away';
  }

  String _getStatusText() {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final momentDate = DateTime(moment.startDate.year, moment.startDate.month, moment.startDate.day);
    
    if (momentDate.isBefore(today)) return 'Celebrated';
    if (momentDate.isAtSameMomentAs(today)) return 'Today!';
    return 'Coming up';
  }

  String _getCountdownText() {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final momentDate = DateTime(moment.startDate.year, moment.startDate.month, moment.startDate.day);
    final diff = momentDate.difference(today).inDays;
    
    if (diff < 0) return 'Already happened';
    if (diff == 0) return "It's the day!";
    if (diff == 1) return 'Tomorrow';
    if (diff < 7) return 'In $diff days';
    if (diff < 30) return 'In ${(diff / 7).ceil()} weeks';
    return 'In ${(diff / 30).ceil()} months';
  }

  String _getRelativeDate() {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final momentDate = DateTime(moment.startDate.year, moment.startDate.month, moment.startDate.day);
    final diff = momentDate.difference(today).inDays;
    
    if (diff < 0) return 'Past';
    if (diff == 0) return 'Today';
    if (diff == 1) return 'Tomorrow';
    if (diff < 7) return 'In $diff days';
    return 'In ${(diff / 7).ceil()} weeks';
  }

  Widget _buildNotesSection() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.darkCardLight,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 28,
                height: 28,
                decoration: BoxDecoration(
                  color: AppColors.accentRed.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(
                  Icons.notes_rounded,
                  color: AppColors.accentRed,
                  size: 14,
                ),
              ),
              const SizedBox(width: 10),
              Text(
                'NOTES',
                style: GoogleFonts.inter(
                  color: AppColors.warmMuted,
                  fontSize: 10,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 1.5,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            moment.notes!,
            style: GoogleFonts.inter(
              color: AppColors.warmDim,
              fontSize: 14,
              height: 1.5,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActions(BuildContext context) {
    return Row(
      children: [
        // Edit button
        if (onEdit != null)
          Expanded(
            child: _buildActionButton(
              icon: Icons.edit_rounded,
              label: 'Edit',
              onTap: () {
                Navigator.of(context).pop();
                onEdit!();
              },
              isPrimary: false,
            ),
          ),
        if (onEdit != null && onDelete != null) const SizedBox(width: 12),
        // Delete button
        if (onDelete != null)
          Expanded(
            child: _buildActionButton(
              icon: Icons.delete_outline_rounded,
              label: 'Delete',
              onTap: () => _confirmDelete(context),
              isPrimary: false,
              isDanger: true,
            ),
          ),
      ],
    );
  }

  Widget _buildActionButton({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
    bool isPrimary = false,
    bool isDanger = false,
  }) {
    final color = isDanger 
        ? const Color(0xFFF87171) 
        : (isPrimary ? AppColors.accentRed : AppColors.warmMuted);
    
    return GestureDetector(
      onTap: () {
        HapticFeedback.lightImpact();
        onTap();
      },
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 14),
        decoration: BoxDecoration(
          color: isPrimary 
              ? AppColors.accentRed 
              : (isDanger 
                  ? const Color(0xFFF87171).withValues(alpha: 0.15)
                  : AppColors.darkCardLight),
          borderRadius: BorderRadius.circular(14),
          border: isDanger 
              ? Border.all(color: const Color(0xFFF87171).withValues(alpha: 0.3))
              : null,
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              icon,
              color: isPrimary ? AppColors.pureBlack : color,
              size: 18,
            ),
            const SizedBox(width: 8),
            Text(
              label,
              style: GoogleFonts.outfit(
                color: isPrimary ? AppColors.pureBlack : color,
                fontSize: 15,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _confirmDelete(BuildContext context) {
    showDialog(
      context: context,
      builder: (dialogContext) => Dialog(
        backgroundColor: AppColors.darkCard,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 56,
                height: 56,
                decoration: BoxDecoration(
                  color: const Color(0xFFF87171).withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: const Icon(
                  Icons.delete_outline_rounded,
                  color: Color(0xFFF87171),
                  size: 28,
                ),
              ),
              const SizedBox(height: 20),
              Text(
                'Delete Moment?',
                style: GoogleFonts.outfit(
                  color: AppColors.warmLight,
                  fontSize: 20,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'This will permanently remove "${moment.name}" from your calendar.',
                textAlign: TextAlign.center,
                style: GoogleFonts.inter(
                  color: AppColors.warmDim,
                  fontSize: 14,
                  height: 1.4,
                ),
              ),
              const SizedBox(height: 24),
              Row(
                children: [
                  Expanded(
                    child: TextButton(
                      onPressed: () => Navigator.of(dialogContext).pop(),
                      style: TextButton.styleFrom(
                        backgroundColor: AppColors.darkCardLight,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: Text(
                        'Cancel',
                        style: GoogleFonts.outfit(
                          color: AppColors.warmMuted,
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: TextButton(
                      onPressed: () {
                        Navigator.of(dialogContext).pop();
                        Navigator.of(context).pop();
                        onDelete!();
                      },
                      style: TextButton.styleFrom(
                        backgroundColor: const Color(0xFFF87171),
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: Text(
                        'Delete',
                        style: GoogleFonts.outfit(
                          color: Colors.white,
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _formatDateShort(DateTime date) {
    const months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
    return '${months[date.month - 1]} ${date.day}';
  }

  String _formatDateFull(DateTime date) {
    const months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
    const days = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
    return '${days[date.weekday - 1]}, ${months[date.month - 1]} ${date.day}';
  }
}
