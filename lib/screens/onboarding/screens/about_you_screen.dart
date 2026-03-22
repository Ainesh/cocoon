/// Screen 2 — You: set your name and select pulse attributes.
///
/// Cinematic staggered entrance. Name input followed by attribute selection
/// using the same visual pattern as moment type selection (glowing cards).
/// Saves name + pulse attributes + creates space on "tap to continue".
library;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../models/pulse_config.dart';
import '../../../services/auth_service.dart';
import '../../../services/firestore_service.dart';
import '../../../theme/app_colors.dart';
import '../../../theme/app_spacing.dart';
import '../../../theme/app_typography.dart';

class AboutYouScreen extends StatefulWidget {
  const AboutYouScreen({
    super.key,
    required this.spaceName,
    required this.onSpaceCreated,
    this.onStartExit,
  });

  final String spaceName;
  final void Function(String spaceId, String inviteCode, String userName)
  onSpaceCreated;

  /// Called immediately on continue tap so the parent can start tile fill
  /// while the API call runs in parallel.
  final VoidCallback? onStartExit;

  @override
  State<AboutYouScreen> createState() => _AboutYouScreenState();
}

class _AboutYouScreenState extends State<AboutYouScreen>
    with TickerProviderStateMixin {
  final _authService = AuthService();
  final _firestoreService = FirestoreService();
  final _nameController = TextEditingController();
  final _focusNode = FocusNode();

  late final AnimationController _taglineController;
  late final AnimationController _continueController;

  // Stagger phases
  double _titleOp = 0;
  double _subtitle1Op = 0;
  double _promptOp = 0;

  bool _isFocused = false;
  bool _hasName = false;
  bool _showAttributes = false;
  bool _isCreating = false;
  bool _isExiting = false;

  // Attribute selection
  final _selectedAttrs = <String>{};

  // Phase tracking
  // Phase 0: title + subtitle + prompt1 appear staggered
  // Phase 1: user types name, unfocuses → prompt2 + attributes appear
  // Phase 2: user selects attributes → overlap subtitle + "tap to continue"
  double _prompt2Op = 0;
  double _attrsOp = 0;
  double _overlapSubOp = 0;

  // ---------------------------------------------------------------------------
  // Lifecycle
  // ---------------------------------------------------------------------------

  @override
  void initState() {
    super.initState();
    _taglineController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    );
    _continueController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );
    _focusNode.addListener(_onFocusChange);
    _runEntrance();
  }

  @override
  void dispose() {
    _focusNode.removeListener(_onFocusChange);
    _focusNode.dispose();
    _nameController.dispose();
    _taglineController.dispose();
    _continueController.dispose();
    super.dispose();
  }

  // ---------------------------------------------------------------------------
  // Entrance sequence
  // ---------------------------------------------------------------------------

  Future<void> _runEntrance() async {
    await Future.delayed(const Duration(milliseconds: 600));
    if (!mounted) return;
    setState(() => _titleOp = 1);

    await Future.delayed(const Duration(milliseconds: 2500));
    if (!mounted) return;
    setState(() => _subtitle1Op = 1);

    await Future.delayed(const Duration(milliseconds: 1800));
    if (!mounted) return;
    setState(() => _promptOp = 1);
  }

  // ---------------------------------------------------------------------------
  // State
  // ---------------------------------------------------------------------------

  void _onFocusChange() {
    if (_isExiting) return;
    final wasFocused = _isFocused;
    setState(() => _isFocused = _focusNode.hasFocus);

    if (wasFocused && !_focusNode.hasFocus && _hasName && !_showAttributes) {
      _showAttributePhase();
    }
  }

  Future<void> _showAttributePhase() async {
    final isReEntry = _taglineController.isCompleted;

    setState(() => _showAttributes = true);

    if (isReEntry) {
      setState(() {
        _prompt2Op = _selectedAttrs.isEmpty ? 1.0 : 0.0;
        _overlapSubOp = _selectedAttrs.length == 3 ? 1.0 : 0.0;
        _attrsOp = 1;
      });
      if (_selectedAttrs.isNotEmpty) _continueController.forward();
      return;
    }

    _taglineController.forward();

    await Future.delayed(const Duration(milliseconds: 600));
    if (!mounted) return;
    setState(() => _prompt2Op = 1);

    await Future.delayed(const Duration(milliseconds: 1200));
    if (!mounted) return;
    setState(() => _attrsOp = 1);
  }

  void _onTextChanged(String _) {
    final hasName = _nameController.text.trim().isNotEmpty;
    if (hasName == _hasName) return;
    setState(() {
      _hasName = hasName;
      if (!hasName && _showAttributes) {
        _showAttributes = false;
        _selectedAttrs.clear();
        _taglineController.reset();
        _continueController.reset();
        _prompt2Op = 0;
        _attrsOp = 0;
        _overlapSubOp = 0;
      }
    });
  }

  void _toggleAttribute(String id) {
    HapticFeedback.selectionClick();
    setState(() {
      if (_selectedAttrs.contains(id)) {
        _selectedAttrs.remove(id);
      } else if (_selectedAttrs.length < 3) {
        _selectedAttrs.add(id);
      }

      _prompt2Op = _selectedAttrs.isEmpty ? 1.0 : 0.0;
      _overlapSubOp = _selectedAttrs.length == 3 ? 1.0 : 0.0;

      if (_selectedAttrs.isNotEmpty) {
        _continueController.forward();
      } else {
        _continueController.reverse();
      }
    });
  }

  // ---------------------------------------------------------------------------
  // Actions
  // ---------------------------------------------------------------------------

  void _tapPrompt() {
    if (_isExiting) return;
    setState(() {
      _isFocused = true;
      if (_showAttributes) _showAttributes = false;
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _focusNode.requestFocus();
    });
  }

  Future<void> _continue() async {
    FocusScope.of(context).unfocus();
    if (!_hasName || _selectedAttrs.isEmpty || _isCreating) return;
    setState(() {
      _isCreating = true;
      _isExiting = true;
    });

    // Start tile fill immediately so the transition masks the API call
    widget.onStartExit?.call();

    final userName = _nameController.text.trim();
    final picks = _selectedAttrs.toList();

    try {
      final userId = _authService.currentUser?.uid;
      if (userId == null) throw Exception('Not logged in');

      final result = await _firestoreService.createSpace(
        userId: userId,
        spaceName: widget.spaceName,
        userName: userName,
        avatarKey: 'default',
      );

      await Future.wait([
        _firestoreService.logSpaceCreatedActivity(
          spaceId: result.spaceId,
          userId: userId,
          userName: userName,
          spaceName: widget.spaceName,
        ),
        _firestoreService.updateUserPicks(
          spaceId: result.spaceId,
          userId: userId,
          picks: picks,
        ),
      ]);

      if (!mounted) return;
      widget.onSpaceCreated(result.spaceId, result.inviteCode, userName);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isCreating = false;
        _isExiting = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error: $e'),
          backgroundColor: AppColors.error,
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  // ---------------------------------------------------------------------------
  // Build
  // ---------------------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    final keyboardHeight = MediaQuery.viewInsetsOf(context).bottom;
    final showField = _isFocused || _hasName;
    final bottomPad = MediaQuery.paddingOf(context).bottom;

    return GestureDetector(
      onTap: () => FocusScope.of(context).unfocus(),
      behavior: HitTestBehavior.opaque,
      child: Stack(
        fit: StackFit.expand,
        children: [
          SafeArea(
            child: AnimatedPadding(
              padding: EdgeInsets.only(bottom: keyboardHeight),
              duration: const Duration(milliseconds: 250),
              curve: Curves.easeOut,
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.screenPadding,
                ),
                child: Column(
                  children: [
                    const Spacer(flex: 4),

                    // --- Title (always visible once entrance completes) ---
                    AnimatedOpacity(
                      duration: const Duration(milliseconds: 800),
                      opacity: _titleOp,
                      child: Text(
                        'You',
                        textAlign: TextAlign.center,
                        style: GoogleFonts.outfit(
                          fontSize: 56,
                          fontWeight: FontWeight.w700,
                          color: AppColors.lightText,
                          height: 1.0,
                        ),
                      ),
                    ),

                    const Spacer(flex: 1),

                    // --- Middle slot ---
                    Expanded(
                      flex: 10,
                      child: SingleChildScrollView(
                        physics: const ClampingScrollPhysics(),
                        child: _buildMiddleContent(showField),
                      ),
                    ),

                    const Spacer(flex: 3),
                  ],
                ),
              ),
            ),
          ),

          // --- Advance ---
          Positioned(
            left: 0,
            right: 0,
            bottom: bottomPad + 32,
            child: FadeTransition(
              opacity: CurvedAnimation(
                parent: _continueController,
                curve: Curves.easeOut,
              ),
              child: GestureDetector(
                onTap: _hasName && _selectedAttrs.isNotEmpty && !_isCreating
                    ? _continue
                    : null,
                child: Text(
                  'tap to continue',
                  textAlign: TextAlign.center,
                  style: GoogleFonts.outfit(
                    fontSize: 15,
                    fontWeight: FontWeight.w500,
                    color: AppColors.warmDim,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMiddleContent(bool showField) {
    // Phase 0: subtitle + prompt (before name)
    if (!_showAttributes && !showField) {
      return Column(
        children: [
          AnimatedOpacity(
            duration: const Duration(milliseconds: 600),
            opacity: _subtitle1Op,
            child: SizedBox(
              width: 280,
              child: Text(
                "Next, establish your\npresence in the space",
                textAlign: TextAlign.center,
                style: AppTypography.bodyLarge(color: AppColors.warmDim),
              ),
            ),
          ),
          const SizedBox(height: AppSpacing.xxxl),
          AnimatedOpacity(
            duration: const Duration(milliseconds: 600),
            opacity: _promptOp,
            child: GestureDetector(
              onTap: _tapPrompt,
              child: Text(
                'tap to enter your name',
                textAlign: TextAlign.center,
                style: AppTypography.bodyLarge(color: AppColors.refinedRed),
              ),
            ),
          ),
        ],
      );
    }

    // Phase 1: typing name
    if (!_showAttributes && showField) {
      return SizedBox(
        width: 220,
        child: TextFormField(
          controller: _nameController,
          focusNode: _focusNode,
          textAlign: TextAlign.center,
          autofocus: true,
          textCapitalization: TextCapitalization.words,
          cursorColor: AppColors.refinedRed,
          style: GoogleFonts.drSugiyama(
            fontSize: 38,
            color: AppColors.refinedRed,
          ),
          decoration: const InputDecoration(
            isDense: true,
            filled: false,
            border: InputBorder.none,
            focusedBorder: UnderlineInputBorder(
              borderSide: BorderSide(color: AppColors.refinedRed, width: 1.5),
            ),
            enabledBorder: InputBorder.none,
            contentPadding: EdgeInsets.only(bottom: 8),
          ),
          onChanged: _onTextChanged,
        ),
      );
    }

    // Phase 2: name entered → show name + attribute selection + overlap subtitle
    return FadeTransition(
      opacity: CurvedAnimation(
        parent: _taglineController,
        curve: Curves.easeOut,
      ),
      child: Column(
        children: [
          GestureDetector(
            onTap: _isExiting ? null : _tapPrompt,
            child: Text(
              _nameController.text.trim(),
              textAlign: TextAlign.center,
              style: GoogleFonts.drSugiyama(
                fontSize: 38,
                color: AppColors.refinedRed,
              ),
            ),
          ),
          const SizedBox(height: AppSpacing.xxl),

          AnimatedOpacity(
            duration: const Duration(milliseconds: 600),
            opacity: _prompt2Op,
            child: SizedBox(
              width: 280,
              child: Text(
                'Select what pulse attributes\nare the most important\nto you',
                textAlign: TextAlign.center,
                style: AppTypography.bodyLarge(color: AppColors.warmDim),
              ),
            ),
          ),
          const SizedBox(height: AppSpacing.xl),

          AnimatedOpacity(
            duration: const Duration(milliseconds: 600),
            opacity: _attrsOp,
            child: _buildAttributeGrid(),
          ),

          // Overlap subtitle — appears when 3/3 selected
          AnimatedOpacity(
            duration: const Duration(milliseconds: 600),
            opacity: _overlapSubOp,
            child: Padding(
              padding: const EdgeInsets.only(top: AppSpacing.lg),
              child: SizedBox(
                width: 280,
                child: Text(
                  'All members get to pick these.\nOverlapping attributes are\nconsidered more important',
                  textAlign: TextAlign.center,
                  style: GoogleFonts.inter(
                    fontSize: 16,
                    fontWeight: FontWeight.w500,
                    color: AppColors.lightText,
                    height: 1.6,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Attribute grid — same visual pattern as moment type selection
  // ---------------------------------------------------------------------------

  Widget _buildAttributeGrid() {
    final attrs = PulseAttribute.values;
    return Column(
      children: [
        Row(
          children: [
            for (int i = 0; i < 4 && i < attrs.length; i++) ...[
              if (i > 0) const SizedBox(width: 10),
              Expanded(child: _buildAttributeChip(attrs[i])),
            ],
          ],
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            for (int i = 4; i < 8 && i < attrs.length; i++) ...[
              if (i > 4) const SizedBox(width: 10),
              Expanded(child: _buildAttributeChip(attrs[i])),
            ],
          ],
        ),
        const SizedBox(height: AppSpacing.md),
        Text(
          '${_selectedAttrs.length} of 3',
          style: AppTypography.bodySmall(
            color: _selectedAttrs.length == 3
                ? AppColors.refinedRed
                : AppColors.warmMuted,
          ),
        ),
      ],
    );
  }

  Widget _buildAttributeChip(PulseAttribute attr) {
    final isSelected = _selectedAttrs.contains(attr.id);
    final isFull = _selectedAttrs.length >= 3;
    final isFaded = isFull && !isSelected;

    return GestureDetector(
      onTap: isFaded ? null : () => _toggleAttribute(attr.id),
      child: AnimatedOpacity(
        duration: const Duration(milliseconds: 200),
        opacity: isFaded ? 0.3 : 1.0,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(vertical: 14),
          decoration: BoxDecoration(
            color: isSelected ? AppColors.accentRed : AppColors.cardVariant,
            borderRadius: BorderRadius.circular(14),
            boxShadow: isSelected
                ? [
                    BoxShadow(
                      color: AppColors.accentRed.withValues(alpha: 0.4),
                      blurRadius: 12,
                      spreadRadius: 1,
                    ),
                  ]
                : null,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              attr.buildIcon(
                color: isSelected ? AppColors.pureBlack : AppColors.warmMuted,
                size: 22,
              ),
              const SizedBox(height: 4),
              Text(
                attr.displayName,
                style: GoogleFonts.outfit(
                  fontSize: 10,
                  fontWeight: FontWeight.w600,
                  color: isSelected ? AppColors.pureBlack : AppColors.warmMuted,
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
