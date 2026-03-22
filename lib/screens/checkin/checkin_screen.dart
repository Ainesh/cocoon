/// Check-in screen for Couple Space app.
///
/// Allows users to submit relationship check-ins with dynamic pulse
/// attribute scores on a 1-100 scale. The active attributes are determined
/// by the space's pulse configuration.
library;

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../models/pulse_config.dart';
import '../../models/user_checkin.dart';
import '../../scoring/score_models.dart';
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

  // Dynamic form state — keyed by attribute ID, values 1-100
  final Map<String, double> _scores = {};
  final _notesController = TextEditingController();
  final _notesFocusNode = FocusNode();
  bool _isNotesFocused = false;
  bool _hasLoadedDefaults = false;

  // Pulse config
  PulseConfig? _pulseConfig;
  StreamSubscription<PulseConfig>? _configSubscription;

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

    _subscribeToPulseConfig();
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
    _configSubscription?.cancel();
    _notesController.dispose();
    _notesFocusNode.dispose();
    super.dispose();
  }

  // ---------------------------------------------------------------------------
  // Data Loading
  // ---------------------------------------------------------------------------

  void _subscribeToPulseConfig() {
    _configSubscription = _firestoreService
        .watchPulseConfig(widget.spaceId)
        .listen((config) {
          if (!mounted) return;
          setState(() {
            _pulseConfig = config;
            // Initialize scores for any new attributes with default 50
            for (final attrId in config.activeAttributes) {
              _scores.putIfAbsent(attrId, () => 50);
            }
          });
        });
  }

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
                for (final entry in lastCheckIn.scores.entries) {
                  _scores[entry.key] = entry.value.toDouble();
                }
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
    final config = _pulseConfig;
    if (userId == null || config == null) return;

    setState(() => _isSubmitting = true);

    try {
      // Build scores map (only active attributes)
      final activeScores = <String, int>{};
      for (final attrId in config.activeAttributes) {
        activeScores[attrId] = (_scores[attrId] ?? 50).round();
      }

      // Build config snapshot
      final snapshot = ConfigSnapshot(
        activeAttributes: config.activeAttributes,
        weights: config.weights,
      );

      final checkInId = await _firestoreService.submitCheckIn(
        spaceId: widget.spaceId,
        userId: userId,
        scores: activeScores,
        configSnapshot: snapshot,
        notes: _notesController.text.trim(),
      );

      // Build compact scores for activity log
      final compactScores = <String, dynamic>{};
      for (final attr in activeScores.keys) {
        compactScores[attr] = {
          'value': activeScores[attr],
          'weight': snapshot.weights[attr] ?? 0,
        };
      }

      final profile = await _firestoreService.getUserProfile(userId);
      final userName = profile?['name'] as String? ?? 'Someone';

      await _firestoreService.logCheckInActivity(
        spaceId: widget.spaceId,
        userId: userId,
        userName: userName,
        checkInId: checkInId,
        compactScores: compactScores,
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

  List<PulseAttribute> get _activeAttributes =>
      _pulseConfig?.activeAttributeEnums ?? [];

  /// Compute a colour from a 1-100 value on the blue→red spectrum.
  Color _scoreColor(double value) =>
      Color.lerp(
        AppColors.morningColor,
        AppColors.nightColor,
        ((value - 1) / 99).clamp(0.0, 1.0),
      ) ??
      AppColors.nightColor;

  /// Bar fill during entrance: lerp from 1.0 (full) down to actual progress.
  double _barFill(double value, double ease) {
    final target = ((value - 1) / 99).clamp(0.0, 1.0);
    return 1.0 + (target - 1.0) * ease; // 1.0 → target
  }

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
              enabled: _pulseConfig != null,
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

  Widget _buildPulseCard() {
    final attrs = _activeAttributes;
    if (attrs.isEmpty) {
      return const SizedBox.shrink();
    }

    // Listen to both controllers — tiles (slow) and bars (fast)
    return AnimatedBuilder(
      animation: Listenable.merge([_tileController, _barController]),
      builder: (context, _) {
        final tileAnim = _tileController.value;
        final barEase = Curves.easeOutCubic.transform(_barController.value);

        // Build group colors from active attributes
        final groupColors = attrs
            .map((a) => _scoreColor(_scores[a.id] ?? 50))
            .toList();

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
                              groupColors: groupColors,
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

                // ---- Bottom: Dynamic vertical bar sliders ----
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
                  child: SizedBox(
                    height: 265,
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        for (int i = 0; i < attrs.length; i++) ...[
                          if (i > 0)
                            SizedBox(width: attrs.length <= 3 ? 24 : 12),
                          Expanded(
                            child: VerticalBarSlider(
                              value: _scores[attrs[i].id] ?? 50,
                              onChanged: (v) =>
                                  setState(() => _scores[attrs[i].id] = v),
                              icon: attrs[i].icon,
                              iconAsset: attrs[i].iconAsset,
                              label: attrs[i].displayName,
                              displayProgress: barEase < 1.0
                                  ? _barFill(
                                      _scores[attrs[i].id] ?? 50,
                                      barEase,
                                    )
                                  : null,
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
      },
    );
  }

  Widget _buildCheckInForm() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Mosaic + dynamic vertical bar sliders
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
