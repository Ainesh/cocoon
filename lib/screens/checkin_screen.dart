/// Check-in screen for Couple Space app.
///
/// Allows users to submit relationship check-ins with scores
/// for connection, intimacy, and peace levels. Matches the health
/// card and health details sheet design language.
library;

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';

import '../models/user_checkin.dart';
import '../services/auth_service.dart';
import '../services/firestore_service.dart';
import '../theme/app_colors.dart';
import '../theme/app_typography.dart';

/// Check-in screen for submitting relationship scores.
class CheckInScreen extends StatefulWidget {
  const CheckInScreen({
    super.key,
    required this.spaceId,
  });

  final String spaceId;

  @override
  State<CheckInScreen> createState() => _CheckInScreenState();
}

class _CheckInScreenState extends State<CheckInScreen> {
  // Services
  final _authService = AuthService();
  final _firestoreService = FirestoreService();

  // Form state - will be initialized from last check-in
  double _connection = 5;
  double _intimacy = 5;
  double _peace = 5; // Higher = more peaceful (converted to stress when submitting)
  final _notesController = TextEditingController();
  bool _hasLoadedDefaults = false;

  // Loading state
  bool _isSubmitting = false;
  bool _isLoadingHistory = true;

  // History data
  StreamSubscription<List<UserCheckIn>>? _checkInsSubscription;
  List<UserCheckIn> _recentCheckIns = [];
  String? _currentUserId;
  
  // Partner info
  String? _partnerName;

  @override
  void initState() {
    super.initState();
    _currentUserId = _authService.currentUser?.uid;
    _subscribeToCheckIns();
    _loadPartnerInfo();
  }

  @override
  void dispose() {
    _checkInsSubscription?.cancel();
    _notesController.dispose();
    super.dispose();
  }

  // ---------------------------------------------------------------------------
  // Data Loading
  // ---------------------------------------------------------------------------

  void _subscribeToCheckIns() {
    _checkInsSubscription?.cancel();
    setState(() => _isLoadingHistory = true);

    _checkInsSubscription = _firestoreService
        .watchRecentCheckIns(widget.spaceId, daysBack: 30)
        .listen(
      (checkIns) {
        setState(() {
          _recentCheckIns = checkIns;
          _isLoadingHistory = false;
          
          // Set defaults from last check-in (only once)
          if (!_hasLoadedDefaults && _myCheckIns.isNotEmpty) {
            final lastCheckIn = _myCheckIns.first;
            _connection = lastCheckIn.connection.toDouble();
            _intimacy = lastCheckIn.intimacy.toDouble();
            _peace = (10 - lastCheckIn.stress).toDouble(); // Convert stress to peace
            _hasLoadedDefaults = true;
          }
        });
      },
      onError: (error) {
        debugPrint('Error loading check-ins: $error');
        setState(() => _isLoadingHistory = false);
      },
    );
  }

  Future<void> _loadPartnerInfo() async {
    try {
      final space = await _firestoreService.getSpaceWithMembers(widget.spaceId);
      if (space != null) {
        final members = space['members'] as List? ?? [];
        for (final member in members) {
          final userId = member['userId'] as String?;
          if (userId != null && userId != _currentUserId) {
            setState(() {
              _partnerName = member['name'] as String? ?? 'Partner';
            });
            break;
          }
        }
      }
    } catch (e) {
      debugPrint('Error loading partner info: $e');
    }
  }

  // ---------------------------------------------------------------------------
  // Submit Check-in
  // ---------------------------------------------------------------------------

  Future<void> _submitCheckIn() async {
    final userId = _currentUserId;
    if (userId == null) return;

    setState(() => _isSubmitting = true);

    try {
      // Convert peace to stress (inverse relationship)
      final stress = (11 - _peace).round().clamp(1, 10);
      
      await _firestoreService.submitCheckIn(
        spaceId: widget.spaceId,
        userId: userId,
        connection: _connection.round(),
        intimacy: _intimacy.round(),
        stress: stress,
        notes: _notesController.text.trim(),
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Check-in submitted!',
              style: AppTypography.bodyMedium(color: AppColors.lightText),
            ),
            backgroundColor: AppColors.accentRed,
            behavior: SnackBarBehavior.floating,
            duration: const Duration(seconds: 2),
          ),
        );

        // Auto-close after brief delay to show success feedback
        await Future.delayed(const Duration(milliseconds: 500));
        if (mounted) context.pop();
      }
    } catch (e) {
      debugPrint('Error submitting check-in: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to submit: $e'),
            backgroundColor: AppColors.error,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  // ---------------------------------------------------------------------------
  // Helpers
  // ---------------------------------------------------------------------------

  List<UserCheckIn> get _myCheckIns =>
      _recentCheckIns.where((c) => c.userId == _currentUserId).toList();

  List<UserCheckIn> get _partnerCheckIns =>
      _recentCheckIns.where((c) => c.userId != _currentUserId).take(5).toList();

  String _getScoreLabel(double value) {
    if (value <= 2) return 'Low';
    if (value <= 4) return 'Fair';
    if (value <= 6) return 'Good';
    if (value <= 8) return 'Great';
    return 'Amazing';
  }

  Color _getScoreColor(double value) {
    if (value <= 3) return AppColors.error;
    if (value <= 5) return AppColors.warning;
    if (value <= 7) return const Color(0xFFFFB347);
    return AppColors.success;
  }

  // ---------------------------------------------------------------------------
  // UI Build Methods
  // ---------------------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.pureBlack,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: Text(
          'Check-in',
          style: AppTypography.appBarTitle(weight: FontWeight.w600),
        ),
        centerTitle: true,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded, color: AppColors.lightText),
          onPressed: () => context.pop(),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildCheckInForm(),
            const SizedBox(height: 16),
            _buildTrendChart(),
            const SizedBox(height: 16),
            _buildPartnerCheckIns(),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Check-in Form
  // ---------------------------------------------------------------------------

  Widget _buildCheckInForm() {
    final hasLastCheckIn = _hasLoadedDefaults && _myCheckIns.isNotEmpty;
    
    return _buildCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildSectionHeader(
            icon: Icons.edit_note_rounded,
            title: 'How are things?',
          ),
          const SizedBox(height: 8),
          Text(
            hasLastCheckIn 
                ? 'Starting from your last check-in • Rate 1-10'
                : 'Rate each area from 1-10',
            style: AppTypography.bodySmall(color: AppColors.warmMuted),
          ),
          const SizedBox(height: 24),

          // Connection Slider
          _buildSlider(
            label: 'Connection',
            iconWidget: Icon(Icons.favorite_rounded, color: AppColors.accentRed, size: 20),
            value: _connection,
            onChanged: (v) => setState(() => _connection = v),
          ),
          const SizedBox(height: 20),

          // Intimacy Slider
          _buildSlider(
            label: 'Intimacy',
            iconWidget: SvgPicture.asset(
              'assets/icons/flame.svg',
              width: 20,
              height: 20,
              colorFilter: ColorFilter.mode(AppColors.accentRed, BlendMode.srcIn),
            ),
            value: _intimacy,
            onChanged: (v) => setState(() => _intimacy = v),
          ),
          const SizedBox(height: 20),

          // Peace Slider (higher = more peaceful)
          _buildSlider(
            label: 'Peace',
            iconWidget: SvgPicture.asset(
              'assets/icons/peace.svg',
              width: 20,
              height: 20,
              colorFilter: ColorFilter.mode(AppColors.accentRed, BlendMode.srcIn),
            ),
            value: _peace,
            onChanged: (v) => setState(() => _peace = v),
          ),
          const SizedBox(height: 24),

          // Notes field
          TextField(
            controller: _notesController,
            style: AppTypography.bodyMedium(color: AppColors.lightText),
            decoration: InputDecoration(
              labelText: 'Notes (optional)',
              labelStyle: AppTypography.bodyMedium(color: AppColors.warmMuted),
              hintText: 'How I\'m feeling / One appreciation...',
              hintStyle: AppTypography.bodySmall(color: AppColors.warmMuted),
              filled: true,
              fillColor: AppColors.cardVariant,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
                borderSide: BorderSide(color: AppColors.border(0.2)),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
                borderSide: BorderSide(color: AppColors.border(0.1)),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
                borderSide: const BorderSide(color: AppColors.accentRed, width: 2),
              ),
              alignLabelWithHint: true,
              counterStyle: AppTypography.labelSmall(color: AppColors.warmMuted),
            ),
            maxLines: 3,
            maxLength: 500,
          ),
          const SizedBox(height: 16),

          // Submit button
          SizedBox(
            width: double.infinity,
            child: _buildSubmitButton(),
          ),
        ],
      ),
    );
  }

  Widget _buildSlider({
    required String label,
    required Widget iconWidget,
    required double value,
    required ValueChanged<double> onChanged,
  }) {
    final color = _getScoreColor(value);
    final scoreLabel = _getScoreLabel(value);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            iconWidget,
            const SizedBox(width: 8),
            Text(
              label,
              style: AppTypography.titleMedium(color: AppColors.warmLight),
            ),
            const Spacer(),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: color.withValues(alpha: 0.3)),
              ),
              child: Text(
                '${value.round()} · $scoreLabel',
                style: GoogleFonts.outfit(
                  fontSize: 14,
                  color: color,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        SliderTheme(
          data: SliderTheme.of(context).copyWith(
            activeTrackColor: color,
            thumbColor: color,
            inactiveTrackColor: AppColors.cardVariant,
            overlayColor: color.withValues(alpha: 0.2),
            trackHeight: 6,
            thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 10),
          ),
          child: Slider(
            value: value,
            min: 1,
            max: 10,
            divisions: 9,
            onChanged: onChanged,
          ),
        ),
      ],
    );
  }

  Widget _buildSubmitButton() {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: _isSubmitting ? null : _submitCheckIn,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 24),
          decoration: BoxDecoration(
            color: AppColors.accentRed,
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: AppColors.redGlow(0.3),
                blurRadius: 12,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (_isSubmitting)
                const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(
                    color: AppColors.pureBlack,
                    strokeWidth: 2,
                  ),
                )
              else ...[
                Icon(Icons.check_rounded, color: AppColors.pureBlack, size: 20),
                const SizedBox(width: 8),
              ],
              Text(
                _isSubmitting ? 'Submitting...' : 'Submit Check-in',
                style: GoogleFonts.outfit(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: AppColors.pureBlack,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Trend Chart
  // ---------------------------------------------------------------------------

  Widget _buildTrendChart() {
    final myCheckIns = _myCheckIns.take(8).toList().reversed.toList();

    if (myCheckIns.isEmpty) {
      return const SizedBox.shrink();
    }

    final connectionValues = myCheckIns.map((c) => c.connection.toDouble()).toList();
    final intimacyValues = myCheckIns.map((c) => c.intimacy.toDouble()).toList();

    return _buildCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildSectionHeader(
            icon: Icons.trending_up_rounded,
            title: 'Your Trend',
          ),
          const SizedBox(height: 8),
          Text(
            'Last ${myCheckIns.length} check-ins',
            style: AppTypography.labelSmall(color: AppColors.warmMuted),
          ),
          const SizedBox(height: 20),
          SizedBox(
            height: 100,
            child: CustomPaint(
              size: const Size(double.infinity, 100),
              painter: _TrendChartPainter(
                connectionValues: connectionValues,
                intimacyValues: intimacyValues,
              ),
            ),
          ),
          const SizedBox(height: 16),
          // Legend
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _buildLegendItem(
                Icon(Icons.favorite_rounded, color: AppColors.accentRed, size: 14),
                'Connection',
                AppColors.accentRed,
              ),
              const SizedBox(width: 24),
              _buildLegendItem(
                SvgPicture.asset(
                  'assets/icons/flame.svg',
                  width: 14,
                  height: 14,
                  colorFilter: const ColorFilter.mode(Color(0xFF60A5FA), BlendMode.srcIn),
                ),
                'Intimacy',
                const Color(0xFF60A5FA),
              ),
            ],
          ),
          const SizedBox(height: 12),
          // X-axis labels
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                DateFormat('M/d').format(myCheckIns.first.timestamp),
                style: AppTypography.labelSmall(color: AppColors.warmMuted),
              ),
              Text(
                'Latest',
                style: AppTypography.labelSmall(color: AppColors.warmLight),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildLegendItem(Widget icon, String label, Color color) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(4),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.15),
            borderRadius: BorderRadius.circular(6),
          ),
          child: icon,
        ),
        const SizedBox(width: 6),
        Text(
          label,
          style: AppTypography.labelMedium(color: AppColors.warmLight),
        ),
      ],
    );
  }

  // ---------------------------------------------------------------------------
  // Partner Check-ins - Simplified timeline design
  // ---------------------------------------------------------------------------

  Widget _buildPartnerCheckIns() {
    if (_isLoadingHistory) {
      return _buildCard(
        child: const Center(
          child: Padding(
            padding: EdgeInsets.all(32),
            child: CircularProgressIndicator(color: AppColors.accentRed, strokeWidth: 2),
          ),
        ),
      );
    }

    if (_partnerCheckIns.isEmpty) {
      return _buildCard(
        child: Column(
          children: [
            const SizedBox(height: 16),
            Icon(Icons.people_outline_rounded, color: AppColors.warmMuted, size: 48),
            const SizedBox(height: 16),
            Text(
              'No partner check-ins yet',
              style: AppTypography.titleMedium(color: AppColors.warmLight),
            ),
            const SizedBox(height: 8),
            Text(
              'When your partner checks in, you\'ll see their scores here.',
              style: AppTypography.bodySmall(color: AppColors.warmMuted),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
          ],
        ),
      );
    }

    return _buildCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header with partner's avatar and name
          Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: AppColors.accentRed.withValues(alpha: 0.15),
                  shape: BoxShape.circle,
                ),
                child: Center(
                  child: Icon(
                    Icons.favorite_rounded,
                    color: AppColors.accentRed,
                    size: 20,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Text(
                _partnerName ?? 'Partner',
                style: AppTypography.headlineSmall(color: AppColors.warmLight),
              ),
            ],
          ),
          const SizedBox(height: 20),
          
          // Simple timeline list
          ..._partnerCheckIns.asMap().entries.map((entry) {
            final index = entry.key;
            final checkIn = entry.value;
            final isLast = index == _partnerCheckIns.length - 1;
            return _buildTimelineItem(checkIn, isLast: isLast);
          }),
        ],
      ),
    );
  }

  Widget _buildTimelineItem(UserCheckIn checkIn, {bool isLast = false}) {
    final connectionPct = checkIn.connection * 10;
    final intimacyPct = checkIn.intimacy * 10;
    final peacePct = (10 - checkIn.stress) * 10;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Timeline dot and line
        Column(
          children: [
            Container(
              width: 8,
              height: 8,
              decoration: BoxDecoration(
                color: AppColors.accentRed,
                shape: BoxShape.circle,
              ),
            ),
            if (!isLast)
              Container(
                width: 1,
                height: 52,
                color: AppColors.cardVariant,
              ),
          ],
        ),
        const SizedBox(width: 16),
        
        // Content
        Expanded(
          child: Padding(
            padding: EdgeInsets.only(bottom: isLast ? 0 : 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Time
                Text(
                  checkIn.timeAgo,
                  style: AppTypography.labelSmall(color: AppColors.warmMuted),
                ),
                const SizedBox(height: 8),
                // Scores inline
                Row(
                  children: [
                    _buildInlineScore(Icons.favorite_rounded, connectionPct.round()),
                    const SizedBox(width: 16),
                    _buildInlineScoreSvg('assets/icons/flame.svg', intimacyPct.round()),
                    const SizedBox(width: 16),
                    _buildInlineScoreSvg('assets/icons/peace.svg', peacePct.round()),
                  ],
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildInlineScore(IconData icon, int score) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, color: AppColors.accentRed, size: 16),
        const SizedBox(width: 4),
        Text(
          '$score',
          style: GoogleFonts.outfit(
            fontSize: 15,
            fontWeight: FontWeight.w600,
            color: AppColors.warmLight,
          ),
        ),
      ],
    );
  }

  Widget _buildInlineScoreSvg(String svgPath, int score) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        SvgPicture.asset(
          svgPath,
          width: 16,
          height: 16,
          colorFilter: ColorFilter.mode(AppColors.accentRed, BlendMode.srcIn),
        ),
        const SizedBox(width: 4),
        Text(
          '$score',
          style: GoogleFonts.outfit(
            fontSize: 15,
            fontWeight: FontWeight.w600,
            color: AppColors.warmLight,
          ),
        ),
      ],
    );
  }

  // ---------------------------------------------------------------------------
  // Common Widgets
  // ---------------------------------------------------------------------------

  Widget _buildCard({required Widget child}) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.darkCard,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.border(0.1)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.2),
            blurRadius: 8,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: child,
    );
  }

  Widget _buildSectionHeader({required IconData icon, required String title}) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: AppColors.accentRed.withValues(alpha: 0.15),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(icon, color: AppColors.accentRed, size: 20),
        ),
        const SizedBox(width: 12),
        Text(
          title,
          style: AppTypography.headlineSmall(color: AppColors.warmLight),
        ),
      ],
    );
  }
}

// -----------------------------------------------------------------------------
// Custom Trend Chart Painter
// -----------------------------------------------------------------------------

class _TrendChartPainter extends CustomPainter {
  _TrendChartPainter({
    required this.connectionValues,
    required this.intimacyValues,
  });

  final List<double> connectionValues;
  final List<double> intimacyValues;

  @override
  void paint(Canvas canvas, Size size) {
    if (connectionValues.isEmpty) return;
    
    // Draw connection line (red)
    _drawCurveLine(
      canvas,
      size,
      connectionValues,
      AppColors.accentRed,
    );
    
    // Draw intimacy line (blue)
    _drawCurveLine(
      canvas,
      size,
      intimacyValues,
      const Color(0xFF60A5FA),
    );
  }

  void _drawCurveLine(
    Canvas canvas,
    Size size,
    List<double> values,
    Color color,
  ) {
    if (values.isEmpty) return;

    final count = values.length;
    final points = <Offset>[];
    
    for (int i = 0; i < count; i++) {
      final x = count == 1 ? size.width / 2 : (i / (count - 1)) * size.width;
      final y = size.height - ((values[i] / 10) * size.height * 0.9);
      points.add(Offset(x, y));
    }

    if (points.length < 2) {
      // Just draw a dot
      final dotPaint = Paint()
        ..color = color
        ..style = PaintingStyle.fill;
      canvas.drawCircle(points.first, 4, dotPaint);
      return;
    }

    // Create smooth curve path
    final path = Path();
    path.moveTo(points.first.dx, points.first.dy);

    for (int i = 0; i < points.length - 1; i++) {
      final p0 = i > 0 ? points[i - 1] : points[i];
      final p1 = points[i];
      final p2 = points[i + 1];
      final p3 = i < points.length - 2 ? points[i + 2] : p2;

      final cp1x = p1.dx + (p2.dx - p0.dx) / 4;
      final cp1y = p1.dy + (p2.dy - p0.dy) / 4;
      final cp2x = p2.dx - (p3.dx - p1.dx) / 4;
      final cp2y = p2.dy - (p3.dy - p1.dy) / 4;

      path.cubicTo(cp1x, cp1y, cp2x, cp2y, p2.dx, p2.dy);
    }

    // Fill under curve
    final fillPath = Path.from(path);
    fillPath.lineTo(points.last.dx, size.height);
    fillPath.lineTo(points.first.dx, size.height);
    fillPath.close();

    final fillPaint = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [
          color.withValues(alpha: 0.25),
          color.withValues(alpha: 0.02),
        ],
      ).createShader(Rect.fromLTWH(0, 0, size.width, size.height))
      ..style = PaintingStyle.fill;

    canvas.drawPath(fillPath, fillPaint);

    // Draw line
    final linePaint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.5
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    canvas.drawPath(path, linePaint);

    // Draw dot at the last point
    final dotPaint = Paint()
      ..color = color
      ..style = PaintingStyle.fill;
    canvas.drawCircle(points.last, 4, dotPaint);
  }

  @override
  bool shouldRepaint(covariant _TrendChartPainter oldDelegate) {
    return connectionValues != oldDelegate.connectionValues ||
        intimacyValues != oldDelegate.intimacyValues;
  }
}
