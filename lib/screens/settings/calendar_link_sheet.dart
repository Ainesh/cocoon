/// Calendar provider picker bottom sheet.
///
/// Shown when the user toggles Calendar integration ON.
/// Lets them choose Google Calendar or Apple Calendar.
library;

import 'dart:io' show Platform;

import 'package:device_calendar/device_calendar.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../models/integration_config.dart';
import '../../services/calendar_service.dart';
import '../../theme/theme.dart';

/// Bottom sheet for choosing a calendar provider (Google or Apple).
///
/// Returns the [CalendarIntegration] on success, or null on cancel.
class CalendarLinkSheet extends StatefulWidget {
  const CalendarLinkSheet({
    super.key,
    required this.userId,
    required this.calendarService,
  });

  final String userId;
  final CalendarService calendarService;

  @override
  State<CalendarLinkSheet> createState() => _CalendarLinkSheetState();
}

class _CalendarLinkSheetState extends State<CalendarLinkSheet> {
  bool _isLinking = false;

  // ---------------------------------------------------------------------------
  // Actions
  // ---------------------------------------------------------------------------

  Future<void> _linkGoogle() async {
    setState(() => _isLinking = true);
    HapticFeedback.mediumImpact();

    final result = await widget.calendarService.linkGoogle(
      userId: widget.userId,
    );

    if (!mounted) return;
    setState(() => _isLinking = false);

    if (result != null) {
      Navigator.pop(context, result);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Could not connect to Google Calendar'),
          backgroundColor: AppColors.error,
        ),
      );
    }
  }

  Future<void> _linkApple() async {
    setState(() => _isLinking = true);
    HapticFeedback.mediumImpact();

    final calendars = await widget.calendarService.getDeviceCalendars();

    if (!mounted) return;

    if (calendars.isEmpty) {
      setState(() => _isLinking = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('No calendars found or permission denied'),
          backgroundColor: AppColors.error,
        ),
      );
      return;
    }

    final selected = await _showCalendarPicker(calendars);
    if (selected == null || !mounted) {
      setState(() => _isLinking = false);
      return;
    }

    final result = await widget.calendarService.linkApple(
      userId: widget.userId,
      calendarId: selected.id!,
      calendarName: selected.name,
    );

    if (!mounted) return;
    setState(() => _isLinking = false);

    if (result != null) {
      Navigator.pop(context, result);
    }
  }

  Future<Calendar?> _showCalendarPicker(List<Calendar> calendars) {
    return showModalBottomSheet<Calendar>(
      context: context,
      backgroundColor: AppColors.darkCardLight,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Choose a calendar',
              style: GoogleFonts.outfit(
                fontSize: 18,
                fontWeight: FontWeight.w600,
                color: AppColors.warmLight,
              ),
            ),
            const SizedBox(height: 16),
            ...calendars
                .where((c) => c.id != null && c.name != null)
                .map(
                  (c) => ListTile(
                    title: Text(
                      c.name!,
                      style: GoogleFonts.inter(color: AppColors.warmLight),
                    ),
                    leading: Icon(
                      Icons.calendar_today_rounded,
                      color: AppColors.accentRed,
                      size: 20,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    onTap: () => Navigator.pop(ctx, c),
                  ),
                ),
          ],
        ),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Build
  // ---------------------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    final showApple = !kIsWeb && Platform.isIOS;

    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: AppColors.warmMuted.withValues(alpha: 0.5),
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(height: 24),
          Text(
            'Connect a calendar',
            style: GoogleFonts.outfit(
              fontSize: 20,
              fontWeight: FontWeight.w600,
              color: AppColors.warmLight,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Choose which calendar to sync moments to',
            style: GoogleFonts.inter(
              fontSize: 14,
              color: AppColors.warmMuted,
            ),
          ),
          const SizedBox(height: 24),

          if (_isLinking)
            const Padding(
              padding: EdgeInsets.all(24),
              child: CircularProgressIndicator(
                color: AppColors.accentRed,
                strokeWidth: 2,
              ),
            )
          else ...[
            _buildProviderOption(
              icon: FontAwesomeIcons.google,
              label: 'Google Calendar',
              subtitle: 'Sign in with your Google account',
              onTap: _linkGoogle,
            ),
            if (showApple) ...[
              const SizedBox(height: 12),
              _buildProviderOption(
                icon: FontAwesomeIcons.apple,
                label: 'Apple Calendar',
                subtitle: 'Use your device calendar',
                onTap: _linkApple,
              ),
            ],
          ],
          const SizedBox(height: 16),
        ],
      ),
    );
  }

  Widget _buildProviderOption({
    required IconData icon,
    required String label,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: AppColors.cardVariant,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Row(
          children: [
            Icon(icon, color: AppColors.accentRed, size: 22),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: GoogleFonts.inter(
                      color: AppColors.warmLight,
                      fontSize: 15,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: GoogleFonts.inter(
                      color: AppColors.warmMuted,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
            Icon(Icons.chevron_right_rounded,
                color: AppColors.warmMuted, size: 20),
          ],
        ),
      ),
    );
  }
}
