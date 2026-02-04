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

import '../../models/user_checkin.dart';
import '../../services/auth_service.dart';
import '../../services/firestore_service.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_typography.dart';
import '../../widgets/active_card.dart';
import '../../widgets/dotted_slider.dart' show ScoreSelector;
import '../../widgets/slide_to_action.dart';
import 'widgets/partner_checkins.dart';
import 'widgets/your_trend.dart';

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
  final _notesFocusNode = FocusNode();
  bool _isNotesFocused = false;
  bool _hasLoadedDefaults = false;
  
  // Track initial values to detect modifications
  double _initialConnection = 5;
  double _initialIntimacy = 5;
  double _initialPeace = 5;
  
  // Active state tracking
  bool get _isPulseModified => 
      _connection != _initialConnection ||
      _intimacy != _initialIntimacy ||
      _peace != _initialPeace;
  
  bool get _isReflectionActive => 
      _isNotesFocused || _notesController.text.isNotEmpty;
  
  /// Whether any changes have been made (pulse or reflection)
  /// Used to enable/disable the save slider
  bool get _hasChanges => _isPulseModified || _notesController.text.isNotEmpty;

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
    
    // Listen for notes focus changes
    _notesFocusNode.addListener(() {
      setState(() => _isNotesFocused = _notesFocusNode.hasFocus);
    });
    
    // Listen for notes text changes to update active state
    _notesController.addListener(() {
      setState(() {}); // Trigger rebuild for _isReflectionActive
    });
  }

  @override
  void dispose() {
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
            
            // Store initial values to detect modifications
            _initialConnection = _connection;
            _initialIntimacy = _intimacy;
            _initialPeace = _peace;
            
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

  List<UserCheckIn> get _partnerCheckIns =>
      _recentCheckIns.where((c) => c.userId != _currentUserId).take(5).toList();

  // ---------------------------------------------------------------------------
  // UI Build Methods
  // ---------------------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
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
            icon: const Icon(Icons.arrow_back_rounded, color: AppColors.lightText),
            onPressed: () => context.pop(),
          ),
        ),
        body: SingleChildScrollView(
          keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildCheckInForm(),
              const SizedBox(height: 16),
              YourTrendChart(checkIns: _myCheckIns),
              const SizedBox(height: 16),
              PartnerCheckIns(
                checkIns: _partnerCheckIns,
                partnerName: _partnerName,
                isLoading: _isLoadingHistory,
              ),
              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCheckInForm() {
    final hasLastCheckIn = _hasLoadedDefaults && _myCheckIns.isNotEmpty;
    
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Three score selectors in a single card
        ActiveCard(
          heading: 'Pulse Check',
          isActive: _isPulseModified,
          helperText: hasLastCheckIn 
              ? 'Starting from your last check-in'
              : 'Rate each area from 1-10',
          hideHelperWhenActive: true,
          child: Column(
            children: [
              ScoreSelector(
                value: _connection,
                onChanged: (v) => setState(() => _connection = v),
                label: 'Connection',
                icon: Icons.favorite_rounded,
                embedded: true,
              ),
              Divider(color: AppColors.cardVariant, height: 24),
              ScoreSelector(
                value: _intimacy,
                onChanged: (v) => setState(() => _intimacy = v),
                label: 'Intimacy',
                iconAsset: 'assets/icons/flame.svg',
                embedded: true,
              ),
              Divider(color: AppColors.cardVariant, height: 24),
              ScoreSelector(
                value: _peace,
                onChanged: (v) => setState(() => _peace = v),
                label: 'Peace',
                iconAsset: 'assets/icons/peace.svg',
                embedded: true,
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),

        // Notes field - tapping anywhere focuses the text field
        GestureDetector(
          onTap: () => _notesFocusNode.requestFocus(),
          behavior: HitTestBehavior.opaque,
          child: ActiveCard(
            heading: 'Reflection',
            isActive: _isReflectionActive,
            helperText: 'Got something on your mind? Use this space to share your thoughts.',
            hideHelperWhenActive: true,
            shrinkWhenActive: true, // Card shrinks when helper disappears
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
        const SizedBox(height: 20),

        // Submit button - slide to confirm (enabled only when changes made)
        SlideToAction(
          label: 'Slide to save',
          loadingLabel: 'Saving...',
          onConfirm: _submitCheckIn,
          isLoading: _isSubmitting,
          enabled: _hasChanges,
        ),
      ],
    );
  }
}
