/// Integrations list bottom sheet.
///
/// Shows available integrations with toggles. Currently supports Calendar only.
library;

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../models/integration_config.dart';
import '../../services/calendar_service.dart';
import '../../services/firestore_service.dart';
import '../../theme/theme.dart';
import 'calendar_link_sheet.dart';

/// Bottom sheet showing the list of available integrations.
class IntegrationsSheet extends StatefulWidget {
  const IntegrationsSheet({
    super.key,
    required this.userId,
    required this.spaceName,
  });

  final String userId;
  final String spaceName;

  @override
  State<IntegrationsSheet> createState() => _IntegrationsSheetState();
}

class _IntegrationsSheetState extends State<IntegrationsSheet> {
  final _firestore = FirestoreService();
  final _calendarService = CalendarService();
  StreamSubscription<IntegrationConfig>? _configSub;
  IntegrationConfig _config = IntegrationConfig.empty;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _configSub = _firestore.watchIntegrationConfig(widget.userId).listen(
      (config) {
        if (!mounted) return;
        setState(() {
          _config = config;
          _isLoading = false;
        });
      },
      onError: (_) {
        if (!mounted) return;
        setState(() => _isLoading = false);
      },
    );
  }

  @override
  void dispose() {
    _configSub?.cancel();
    super.dispose();
  }

  // ---------------------------------------------------------------------------
  // Actions
  // ---------------------------------------------------------------------------

  Future<void> _toggleCalendar(bool enabled) async {
    HapticFeedback.selectionClick();
    if (enabled) {
      if (!mounted) return;
      final result = await showModalBottomSheet<CalendarIntegration>(
        context: context,
        backgroundColor: AppColors.darkCardLight,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        builder: (_) => CalendarLinkSheet(
          userId: widget.userId,
          spaceName: widget.spaceName,
          calendarService: _calendarService,
        ),
      );
      if (result == null && mounted) {
        setState(() {});
      }
    } else {
      final confirm = await _showUnlinkConfirmation();
      if (confirm == true) {
        await _calendarService.unlink(widget.userId);
      }
    }
  }

  Future<void> _toggleDriveStorage(bool enabled) async {
    HapticFeedback.selectionClick();
    if (enabled) {
      try {
        // Trigger Google Sign-In with drive.file scope via DriveStorageService
        // The sign-in prompt is handled inside _getDriveApi()
        await _firestore.saveDriveStorageIntegration(
          widget.userId,
          DriveStorageIntegration(
            enabled: true,
            linkedAt: DateTime.now(),
          ),
        );
      } catch (_) {
        // User cancelled or auth failed
      }
    } else {
      final confirm = await _showDriveUnlinkConfirmation();
      if (confirm == true) {
        await _firestore.removeDriveStorageIntegration(widget.userId);
      }
    }
  }

  Future<bool?> _showDriveUnlinkConfirmation() {
    return showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.darkCardLight,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text(
          'Disconnect Google Drive?',
          style: GoogleFonts.outfit(
            color: AppColors.warmLight,
            fontWeight: FontWeight.w600,
          ),
        ),
        content: Text(
          'Existing photos on Drive will remain, but new memories will use app storage.',
          style: GoogleFonts.inter(color: AppColors.warmDim, fontSize: 14),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text('Cancel',
                style: GoogleFonts.inter(color: AppColors.warmMuted)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text('Disconnect',
                style: GoogleFonts.inter(color: AppColors.accentRed)),
          ),
        ],
      ),
    );
  }

  Future<bool?> _showUnlinkConfirmation() {
    return showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.darkCardLight,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text(
          'Disconnect calendar?',
          style: GoogleFonts.outfit(
            color: AppColors.warmLight,
            fontWeight: FontWeight.w600,
          ),
        ),
        content: Text(
          'Synced events will remain on your calendar but new moments won\'t sync.',
          style: GoogleFonts.inter(color: AppColors.warmDim, fontSize: 14),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text('Cancel',
                style: GoogleFonts.inter(color: AppColors.warmMuted)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text('Disconnect',
                style: GoogleFonts.inter(color: AppColors.accentRed)),
          ),
        ],
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Build
  // ---------------------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
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
            'Integrations',
            style: GoogleFonts.outfit(
              fontSize: 20,
              fontWeight: FontWeight.w600,
              color: AppColors.warmLight,
            ),
          ),
          const SizedBox(height: 24),
          if (_isLoading)
            const Padding(
              padding: EdgeInsets.all(24),
              child: CircularProgressIndicator(
                color: AppColors.accentRed,
                strokeWidth: 2,
              ),
            )
          else ...[
            _buildCalendarRow(),
            const SizedBox(height: 12),
            _buildDriveStorageRow(),
          ],
          const SizedBox(height: 16),
        ],
      ),
    );
  }

  Widget _buildDriveStorageRow() {
    final drive = _config.driveStorage;
    final isEnabled = drive?.enabled ?? false;
    final subtitle = isEnabled
        ? 'Connected — unlimited photo memories'
        : 'Store memory photos in your Google Drive';

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: AppColors.cardVariant,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          Icon(Icons.cloud_outlined, color: AppColors.accentRed, size: 22),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Google Drive',
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
          Switch.adaptive(
            value: isEnabled,
            onChanged: _toggleDriveStorage,
            activeColor: AppColors.accentRed,
            activeTrackColor: AppColors.accentRed.withValues(alpha: 0.3),
          ),
        ],
      ),
    );
  }

  Widget _buildCalendarRow() {
    final cal = _config.calendar;
    final isEnabled = cal?.enabled ?? false;

    String subtitle;
    if (isEnabled && cal != null) {
      subtitle = cal.provider == CalendarProvider.google
          ? 'Connected to ${cal.email ?? "Google Calendar"}'
          : 'Connected to Apple Calendar';
    } else {
      subtitle = 'Sync moments to your calendar';
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: AppColors.cardVariant,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          Icon(Icons.calendar_today_rounded, color: AppColors.accentRed, size: 22),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Calendar',
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
          Switch.adaptive(
            value: isEnabled,
            onChanged: _toggleCalendar,
            activeColor: AppColors.accentRed,
            activeTrackColor: AppColors.accentRed.withValues(alpha: 0.3),
          ),
        ],
      ),
    );
  }
}
