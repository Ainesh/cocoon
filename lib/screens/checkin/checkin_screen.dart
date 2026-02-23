/// Check-in screen for Couple Space app.
///
/// Allows users to submit relationship check-ins with scores
/// for connection, intimacy, and peace levels. Matches the health
/// card and health details sheet design language.
library;

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../models/user_checkin.dart';
import '../../services/auth_service.dart';
import '../../services/firestore_service.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_typography.dart';
import '../../widgets/active_card.dart';
import '../../widgets/dotted_slider.dart' show VerticalBarSlider;
import '../../widgets/painters/voronoi_mosaic_painter.dart';
import '../../widgets/slide_to_action.dart';

/// Check-in screen for submitting relationship scores.
class CheckInScreen extends StatefulWidget {
  const CheckInScreen({super.key, required this.spaceId});

  final String spaceId;

  @override
  State<CheckInScreen> createState() => _CheckInScreenState();
}

class _CheckInScreenState extends State<CheckInScreen>
    with TickerProviderStateMixin {
  // Services
  final _authService = AuthService();
  final _firestoreService = FirestoreService();

  // Tile entrance — slow staggered appearance like health card
  late AnimationController _tileController;
  // Bar entrance — quick settle from max
  late AnimationController _barController;

  // Form state - will be initialized from last check-in
  double _connection = 5;
  double _intimacy = 5;
  double _peace = 5;
  final _notesController = TextEditingController();
  final _notesFocusNode = FocusNode();
  bool _isNotesFocused = false;
  bool _hasLoadedDefaults = false;

  // Loading state
  bool _isSubmitting = false;

  // History data
  StreamSubscription<List<UserCheckIn>>? _checkInsSubscription;
  List<UserCheckIn> _recentCheckIns = [];
  String? _currentUserId;

  // Fixed seed for the Voronoi mosaic — set once, stable across rebuilds
  late final int _mosaicSeed = DateTime.now().millisecondsSinceEpoch;

  @override
  void initState() {
    super.initState();
    _currentUserId = _authService.currentUser?.uid;

    _tileController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2000),
    );
    _barController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );

    _subscribeToCheckIns();

    // Listen for notes focus changes
    _notesFocusNode.addListener(() {
      setState(() => _isNotesFocused = _notesFocusNode.hasFocus);
    });

    // Listen for notes text changes to update active state
    _notesController.addListener(() {
      setState(() {});
    });

    // Kick off entrance animations after first frame
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        _tileController.forward();
        _barController.forward();
      }
    });
  }

  @override
  void dispose() {
    _tileController.dispose();
    _barController.dispose();
    _checkInsSubscription?.cancel();
    _notesController.dispose();
    _notesFocusNode.dispose();
    super.dispose();
  }

  // ---------------------------------------------------------------------------
  // Data Loading
  // ---------------------------------------------------------------------------

  void _subscribeToCheckIns() {
    _checkInsSubscription?.cancel();
    _checkInsSubscription = _firestoreService
        .watchRecentCheckIns(widget.spaceId, daysBack: 30)
        .listen(
          (checkIns) {
            setState(() {
              _recentCheckIns = checkIns;

              // Set defaults from last check-in (only once)
              if (!_hasLoadedDefaults && _myCheckIns.isNotEmpty) {
                final lastCheckIn = _myCheckIns.first;
                _connection = lastCheckIn.connection.toDouble();
                _intimacy = lastCheckIn.intimacy.toDouble();
                _peace = lastCheckIn.peace.toDouble();

                _hasLoadedDefaults = true;
              }
            });
          },
          onError: (error) {
            debugPrint('Error loading check-ins: $error');
            setState(() {});
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
      final checkInId = await _firestoreService.submitCheckIn(
        spaceId: widget.spaceId,
        userId: userId,
        connection: _connection.round(),
        intimacy: _intimacy.round(),
        peace: _peace.round(),
        notes: _notesController.text.trim(),
      );

      // Log activity
      final profile = await _firestoreService.getUserProfile(userId);
      final userName = profile?['name'] as String? ?? 'Someone';

      await _firestoreService.logCheckInActivity(
        spaceId: widget.spaceId,
        userId: userId,
        userName: userName,
        checkInId: checkInId,
        connection: _connection.round(),
        intimacy: _intimacy.round(),
        peace: _peace.round(),
        notes: _notesController.text.trim(),
      );

      if (mounted) {
        context.pop();
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

  // ---------------------------------------------------------------------------
  // UI Build Methods
  // ---------------------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      // Tap anywhere to unfocus text fields
      onTap: () => FocusScope.of(context).unfocus(),
      // Swipe right to go back
      onHorizontalDragEnd: (details) {
        if (details.primaryVelocity != null && details.primaryVelocity! > 300) {
          HapticFeedback.lightImpact();
          context.pop();
        }
      },
      child: Scaffold(
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
            icon: const Icon(
              Icons.arrow_back_rounded,
              color: AppColors.lightText,
            ),
            onPressed: () => context.pop(),
          ),
        ),
        bottomNavigationBar: SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 12),
            child: SlideToAction(
              label: 'Slide to save',
              loadingLabel: 'Saving...',
              onConfirm: _submitCheckIn,
              isLoading: _isSubmitting,
              enabled: true,
            ),
          ),
        ),
        body: SingleChildScrollView(
          physics: const ClampingScrollPhysics(),
          keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [_buildCheckInForm(), const SizedBox(height: 24)],
          ),
        ),
      ),
    );
  }

  /// Bar fill during entrance: lerp from 1.0 (full) down to actual progress.
  double _barFill(double value, double ease) {
    final target = (value - 1) / 9;
    return 1.0 + (target - 1.0) * ease; // 1.0 → target
  }

  /// Compute a colour from a 1–10 value on the blue→red spectrum.
  Color _scoreColor(double value) =>
      Color.lerp(
        AppColors.morningColor,
        AppColors.nightColor,
        (value - 1) / 9,
      ) ??
      AppColors.nightColor;

  Widget _buildPulseCard() {
    // Listen to both controllers — tiles (slow) and bars (fast)
    return AnimatedBuilder(
      animation: Listenable.merge([_tileController, _barController]),
      builder: (context, _) {
        final tileAnim = _tileController.value;
        final connColor = _scoreColor(_connection);
        final intColor = _scoreColor(_intimacy);
        final peaceColor = _scoreColor(_peace);

        // Bars: quick settle from max to actual value
        final barEase = Curves.easeOutCubic.transform(_barController.value);
        final connFill = barEase < 1.0 ? _barFill(_connection, barEase) : null;
        final intFill = barEase < 1.0 ? _barFill(_intimacy, barEase) : null;
        final peaceFill = barEase < 1.0 ? _barFill(_peace, barEase) : null;

        return Container(
          decoration: BoxDecoration(
            color: AppColors.darkCardLight,
            borderRadius: BorderRadius.circular(16),
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // ---- Top: Voronoi mosaic with grouped colours + header ----
                Stack(
                  children: [
                    RepaintBoundary(
                      child: SizedBox(
                        height: 180,
                        width: double.infinity,
                        child: RepaintBoundary(
                          child: CustomPaint(
                            painter: VoronoiGroupedPainter(
                              groupColors: [connColor, intColor, peaceColor],
                              seed: _mosaicSeed,
                              animationProgress: tileAnim,
                              tileCount: 60,
                              backgroundColor: AppColors.darkCardLight,
                              staggerSpread: 0.4,
                            ),
                          ),
                        ),
                      ),
                    ),
                    // Header label
                    Padding(
                      padding: const EdgeInsets.all(14),
                      child: Text(
                        'PULSE CHECK',
                        style: GoogleFonts.outfit(
                          color: Colors.white.withValues(alpha: 0.9),
                          fontSize: 10,
                          fontWeight: FontWeight.w600,
                          letterSpacing: 1.5,
                          shadows: [
                            Shadow(
                              color: Colors.black.withValues(alpha: 0.6),
                              blurRadius: 4,
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),

                // Helper text
                Padding(
                  padding: const EdgeInsets.fromLTRB(14, 10, 14, 0),
                  child: Text(
                    'Slide the bars to express. Starting from your last check-in.',
                    style: GoogleFonts.inter(
                      color: AppColors.warmMuted.withValues(alpha: 0.7),
                      fontSize: 12,
                    ),
                  ),
                ),

                // ---- Bottom: 3 vertical bar sliders ----
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 12, 20, 16),
                  child: SizedBox(
                    height: 265,
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Expanded(
                          child: VerticalBarSlider(
                            value: _connection,
                            onChanged: (v) => setState(() => _connection = v),
                            icon: Icons.favorite_rounded,
                            label: 'Connection',
                            displayProgress: connFill,
                          ),
                        ),
                        const SizedBox(width: 24),
                        Expanded(
                          child: VerticalBarSlider(
                            value: _intimacy,
                            onChanged: (v) => setState(() => _intimacy = v),
                            iconAsset: 'assets/icons/flame.svg',
                            label: 'Intimacy',
                            displayProgress: intFill,
                          ),
                        ),
                        const SizedBox(width: 24),
                        Expanded(
                          child: VerticalBarSlider(
                            value: _peace,
                            onChanged: (v) => setState(() => _peace = v),
                            iconAsset: 'assets/icons/peace.svg',
                            label: 'Peace',
                            displayProgress: peaceFill,
                          ),
                        ),
                      ],
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

  Widget _buildCheckInForm() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Mosaic + 3 vertical bar sliders
        _buildPulseCard(),
        const SizedBox(height: 12),

        // Notes field - tapping anywhere focuses the text field
        GestureDetector(
          onTap: () => _notesFocusNode.requestFocus(),
          behavior: HitTestBehavior.opaque,
          child: ActiveCard(
            heading: 'Reflection',
            isActive: true,
            helperText:
                'Got something on your mind? Use this space to share your thoughts.',
            hideHelperWhenActive: false,
            showBorder: _isNotesFocused,
            child: TextField(
              controller: _notesController,
              focusNode: _notesFocusNode,
              style: AppTypography.bodyMedium(color: AppColors.warmDim),
              cursorColor: AppColors.accentRed,
              decoration: const InputDecoration(
                filled: false,
                border: InputBorder.none,
                focusedBorder: InputBorder.none,
                enabledBorder: InputBorder.none,
                contentPadding: EdgeInsets.zero,
                isDense: true,
              ),
              maxLines: 3,
              minLines: 1,
            ),
          ),
        ),
      ],
    );
  }
}
