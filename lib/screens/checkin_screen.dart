/// Check-in screen for Couple Space app.
///
/// Allows users to submit relationship check-ins with scores
/// for connection, intimacy, and stress levels. Premium neumorphic UI.
library;

import 'dart:async';

import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../models/user_checkin.dart';
import '../services/auth_service.dart';
import '../services/firestore_service.dart';
import '../widgets/neumorphic_container.dart';

// Theme constants for premium styling
const _refinedRed = Color(0xFFFF4444);
const _lightText = Color(0xFFF5F5F5);
const _bodyGray = Color(0xFFD1D5DB);
const _dimText = Color(0xFF9CA3AF);
const _cardVariant = Color(0xFF2A2A2A);
const _darkGlass = Color(0xFF1E1E1E);
const _pureBlack = Color(0xFF0A0A0A);

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

  // Form state
  double _connection = 5;
  double _intimacy = 5;
  double _stress = 5;
  final _notesController = TextEditingController();

  // Loading state
  bool _isSubmitting = false;
  bool _isLoadingHistory = true;

  // History data
  StreamSubscription<List<UserCheckIn>>? _checkInsSubscription;
  List<UserCheckIn> _recentCheckIns = [];
  String? _currentUserId;

  @override
  void initState() {
    super.initState();
    _currentUserId = _authService.currentUser?.uid;
    _subscribeToCheckIns();
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
        });
      },
      onError: (error) {
        debugPrint('Error loading check-ins: $error');
        setState(() => _isLoadingHistory = false);
      },
    );
  }

  // ---------------------------------------------------------------------------
  // Submit Check-in
  // ---------------------------------------------------------------------------

  Future<void> _submitCheckIn() async {
    final userId = _currentUserId;
    if (userId == null) return;

    setState(() => _isSubmitting = true);

    try {
      await _firestoreService.submitCheckIn(
        spaceId: widget.spaceId,
        userId: userId,
        connection: _connection.round(),
        intimacy: _intimacy.round(),
        stress: _stress.round(),
        notes: _notesController.text.trim(),
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Check-in submitted!'),
            backgroundColor: _refinedRed,
            behavior: SnackBarBehavior.floating,
          ),
        );

        // Reset form
        setState(() {
          _connection = 5;
          _intimacy = 5;
          _stress = 5;
          _notesController.clear();
        });
      }
    } catch (e) {
      debugPrint('Error submitting check-in: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to submit: $e'),
            backgroundColor: Colors.red.shade700,
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
      _recentCheckIns.where((c) => c.userId != _currentUserId).take(7).toList();

  String _getScoreLabel(double value) {
    if (value <= 2) return 'Low';
    if (value <= 4) return 'Fair';
    if (value <= 6) return 'Good';
    if (value <= 8) return 'Great';
    return 'Amazing';
  }

  Color _getScoreColor(double value, {bool inverted = false}) {
    final effectiveValue = inverted ? 11 - value : value;
    if (effectiveValue <= 3) return Colors.red.shade400;
    if (effectiveValue <= 5) return Colors.orange.shade400;
    if (effectiveValue <= 7) return Colors.amber.shade400;
    return const Color(0xFF4ADE80);
  }

  // ---------------------------------------------------------------------------
  // UI Build Methods
  // ---------------------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _pureBlack,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: const Text(
          'Check-in',
          style: TextStyle(
            fontWeight: FontWeight.w700,
            fontSize: 20,
            color: _lightText,
          ),
        ),
        centerTitle: true,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded, color: _lightText),
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
    return PremiumCard(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SectionHeader(
            icon: Icons.edit_note_rounded,
            title: 'How are things?',
          ),
          const SizedBox(height: 8),
          const Text(
            'Rate each area from 1-10',
            style: TextStyle(fontSize: 14, color: _dimText),
          ),
          const SizedBox(height: 24),

          // Connection Slider
          _buildSlider(
            label: 'Connection',
            emoji: '💙',
            value: _connection,
            onChanged: (v) => setState(() => _connection = v),
          ),
          const SizedBox(height: 20),

          // Intimacy Slider
          _buildSlider(
            label: 'Intimacy',
            emoji: '❤️',
            value: _intimacy,
            onChanged: (v) => setState(() => _intimacy = v),
          ),
          const SizedBox(height: 20),

          // Stress Slider (inverted - lower is better)
          _buildSlider(
            label: 'Stress',
            emoji: '😰',
            value: _stress,
            onChanged: (v) => setState(() => _stress = v),
            inverted: true,
            invertedLabel: 'Lower is better',
          ),
          const SizedBox(height: 24),

          // Notes field
          TextField(
            controller: _notesController,
            style: const TextStyle(color: _lightText),
            decoration: InputDecoration(
              labelText: 'Notes (optional)',
              labelStyle: const TextStyle(color: _bodyGray),
              hintText: 'How I\'m feeling / One appreciation...',
              hintStyle: const TextStyle(color: _dimText),
              filled: true,
              fillColor: _cardVariant,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
                borderSide: BorderSide(color: _refinedRed.withValues(alpha: 0.2)),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
                borderSide: BorderSide(color: _refinedRed.withValues(alpha: 0.1)),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
                borderSide: const BorderSide(color: _refinedRed, width: 2),
              ),
              alignLabelWithHint: true,
              counterStyle: const TextStyle(color: _dimText),
            ),
            maxLines: 3,
            maxLength: 500,
          ),
          const SizedBox(height: 16),

          // Submit button
          SizedBox(
            width: double.infinity,
            child: cardButton(
              label: _isSubmitting ? 'Submitting...' : 'Submit Check-in',
              icon: Icons.check_rounded,
              onPressed: _isSubmitting ? () {} : _submitCheckIn,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSlider({
    required String label,
    required String emoji,
    required double value,
    required ValueChanged<double> onChanged,
    bool inverted = false,
    String? invertedLabel,
  }) {
    final color = _getScoreColor(value, inverted: inverted);
    final scoreLabel = inverted
        ? (value <= 3 ? 'Low' : value <= 6 ? 'Moderate' : 'High')
        : _getScoreLabel(value);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(emoji, style: const TextStyle(fontSize: 20)),
            const SizedBox(width: 8),
            Text(
              label,
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w500,
                color: _lightText,
              ),
            ),
            if (invertedLabel != null) ...[
              const SizedBox(width: 8),
              Text(
                '($invertedLabel)',
                style: const TextStyle(fontSize: 12, color: _dimText),
              ),
            ],
            const Spacer(),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: color.withValues(alpha: 0.3)),
              ),
              child: Text(
                '${value.round()} · $scoreLabel',
                style: TextStyle(
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
            inactiveTrackColor: _cardVariant,
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

  // ---------------------------------------------------------------------------
  // Trend Chart
  // ---------------------------------------------------------------------------

  Widget _buildTrendChart() {
    final myCheckIns = _myCheckIns.take(8).toList().reversed.toList();

    if (myCheckIns.isEmpty) {
      return const SizedBox.shrink();
    }

    return PremiumCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SectionHeader(
            icon: Icons.trending_up_rounded,
            title: 'Your Trend',
          ),
          const SizedBox(height: 8),
          Text(
            'Last ${myCheckIns.length} check-ins',
            style: const TextStyle(fontSize: 12, color: _dimText),
          ),
          const SizedBox(height: 20),
          SizedBox(
            height: 180,
            child: LineChart(
              LineChartData(
                gridData: FlGridData(
                  show: true,
                  drawVerticalLine: false,
                  horizontalInterval: 2,
                  getDrawingHorizontalLine: (value) => FlLine(
                    color: _cardVariant,
                    strokeWidth: 1,
                  ),
                ),
                titlesData: FlTitlesData(
                  leftTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      reservedSize: 28,
                      interval: 2,
                      getTitlesWidget: (value, meta) {
                        if (value == 0 || value > 10) return const SizedBox.shrink();
                        return Text(
                          value.toInt().toString(),
                          style: const TextStyle(fontSize: 12, color: _dimText),
                        );
                      },
                    ),
                  ),
                  rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  bottomTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      reservedSize: 24,
                      getTitlesWidget: (value, meta) {
                        final index = value.toInt();
                        if (index >= 0 && index < myCheckIns.length) {
                          final date = myCheckIns[index].timestamp;
                          return Text(
                            DateFormat('M/d').format(date),
                            style: const TextStyle(fontSize: 10, color: _dimText),
                          );
                        }
                        return const SizedBox.shrink();
                      },
                    ),
                  ),
                ),
                borderData: FlBorderData(show: false),
                minY: 0,
                maxY: 10,
                lineBarsData: [
                  // Connection line
                  _buildLineData(
                    myCheckIns,
                    (c) => c.connection.toDouble(),
                    Colors.blue,
                  ),
                  // Intimacy line
                  _buildLineData(
                    myCheckIns,
                    (c) => c.intimacy.toDouble(),
                    _refinedRed,
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _buildLegendItem('Connection', Colors.blue),
              const SizedBox(width: 24),
              _buildLegendItem('Intimacy', _refinedRed),
            ],
          ),
        ],
      ),
    );
  }

  LineChartBarData _buildLineData(
    List<UserCheckIn> checkIns,
    double Function(UserCheckIn) getValue,
    Color color,
  ) {
    return LineChartBarData(
      spots: checkIns.asMap().entries.map((e) {
        return FlSpot(e.key.toDouble(), getValue(e.value));
      }).toList(),
      isCurved: true,
      color: color,
      barWidth: 3,
      isStrokeCapRound: true,
      dotData: FlDotData(
        show: true,
        getDotPainter: (spot, percent, bar, index) => FlDotCirclePainter(
          radius: 4,
          color: color,
          strokeWidth: 2,
          strokeColor: _darkGlass,
        ),
      ),
      belowBarData: BarAreaData(
        show: true,
        color: color.withValues(alpha: 0.1),
      ),
    );
  }

  Widget _buildLegendItem(String label, Color color) {
    return Row(
      children: [
        Container(
          width: 12,
          height: 12,
          decoration: BoxDecoration(
            color: color,
            shape: BoxShape.circle,
            boxShadow: [
              BoxShadow(
                color: color.withValues(alpha: 0.4),
                blurRadius: 4,
              ),
            ],
          ),
        ),
        const SizedBox(width: 6),
        Text(
          label,
          style: const TextStyle(fontSize: 12, color: _bodyGray),
        ),
      ],
    );
  }

  // ---------------------------------------------------------------------------
  // Partner Check-ins
  // ---------------------------------------------------------------------------

  Widget _buildPartnerCheckIns() {
    if (_isLoadingHistory) {
      return PremiumCard(
        padding: const EdgeInsets.all(32),
        child: const Center(
          child: CircularProgressIndicator(color: _refinedRed, strokeWidth: 2),
        ),
      );
    }

    if (_partnerCheckIns.isEmpty) {
      return PremiumCard(
        padding: const EdgeInsets.all(24),
        child: EmptyState(
          icon: Icons.people_outline_rounded,
          title: 'No partner check-ins yet',
          subtitle: 'When your partner checks in, you\'ll see their scores here.',
        ),
      );
    }

    return PremiumCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SectionHeader(
            icon: Icons.favorite_rounded,
            title: 'Partner\'s Recent Check-ins',
          ),
          const SizedBox(height: 16),
          ..._partnerCheckIns.map((checkIn) => _buildCheckInItem(checkIn)),
        ],
      ),
    );
  }

  Widget _buildCheckInItem(UserCheckIn checkIn) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: _cardVariant,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: _refinedRed.withValues(alpha: 0.1)),
            ),
            child: const Icon(
              Icons.check_circle_outline_rounded,
              color: _refinedRed,
              size: 20,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Partner checked in',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                    color: _lightText,
                  ),
                ),
                Text(
                  checkIn.timeAgo,
                  style: const TextStyle(fontSize: 12, color: _dimText),
                ),
              ],
            ),
          ),
          Row(
            children: [
              ScoreBadge(emoji: '💙', score: checkIn.connection),
              const SizedBox(width: 8),
              ScoreBadge(emoji: '❤️', score: checkIn.intimacy),
            ],
          ),
        ],
      ),
    );
  }
}
