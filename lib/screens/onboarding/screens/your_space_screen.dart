/// Screen 1 — Your Space: guided space-naming experience.
///
/// Three elements (Title, Middle, Prompt) are evenly distributed within
/// the center zone between the mosaic bands. The middle slot transitions
/// between subtitle → hidden → tagline based on interaction state.
library;

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../theme/app_colors.dart';
import '../../../theme/app_spacing.dart';
import '../../../theme/app_typography.dart';

class YourSpaceScreen extends StatefulWidget {
  const YourSpaceScreen({
    super.key,
    required this.initialName,
    required this.onContinue,
  });

  final String initialName;
  final void Function(String spaceName) onContinue;

  @override
  State<YourSpaceScreen> createState() => _YourSpaceScreenState();
}

class _YourSpaceScreenState extends State<YourSpaceScreen>
    with TickerProviderStateMixin {
  late final TextEditingController _nameController;
  late final AnimationController _taglineController;
  late final AnimationController _continueController;
  final _focusNode = FocusNode();

  double _titleOp = 0;
  double _subtitle1Op = 0;
  double _subtitle2Op = 0;
  double _promptOp = 0;

  bool _isFocused = false;
  bool _hasText = false;
  bool _showTagline = false;
  bool _isExiting = false;

  // ---------------------------------------------------------------------------
  // Lifecycle
  // ---------------------------------------------------------------------------

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController();
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

    await Future.delayed(const Duration(milliseconds: 3800));
    if (!mounted) return;
    setState(() => _subtitle2Op = 1);

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

    // Unfocused with text → show tagline, then advance after 2s
    if (wasFocused && !_focusNode.hasFocus && _hasText && !_showTagline) {
      setState(() => _showTagline = true);
      _taglineController.forward();
      Future.delayed(const Duration(milliseconds: 2000), () {
        if (!mounted) return;
        _continueController.forward();
      });
    }
  }

  void _onTextChanged(String _) {
    final hasText = _nameController.text.trim().isNotEmpty;
    if (hasText == _hasText) return;
    setState(() {
      _hasText = hasText;
      if (!hasText && _showTagline) {
        _showTagline = false;
        _taglineController.reset();
        _continueController.reset();
      }
    });
  }

  // ---------------------------------------------------------------------------
  // Actions
  // ---------------------------------------------------------------------------

  void _tapPrompt() {
    if (_isExiting) return;
    setState(() => _isFocused = true);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _focusNode.requestFocus();
    });
  }

  void _continue() {
    FocusScope.of(context).unfocus();
    if (!_hasText || _isExiting) return;
    setState(() {
      _isExiting = true;
      _titleOp = 0;
    });
    widget.onContinue(_nameController.text.trim());
  }

  // ---------------------------------------------------------------------------
  // Middle slot: subtitle / hidden / tagline
  // ---------------------------------------------------------------------------

  double get _middleOpacity {
    if (_showTagline && !_isFocused) return 1.0;
    if (_isFocused) return 0.0;
    return _subtitle1Op;
  }

  // ---------------------------------------------------------------------------
  // Build
  // ---------------------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    final keyboardHeight = MediaQuery.viewInsetsOf(context).bottom;
    final showField = _isFocused || _hasText;
    final bottomPad = MediaQuery.paddingOf(context).bottom;

    return GestureDetector(
      onTap: () => FocusScope.of(context).unfocus(),
      behavior: HitTestBehavior.opaque,
      child: Stack(
        fit: StackFit.expand,
        children: [
          // Main content
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
                    // Top zone (bands + padding)
                    const Spacer(flex: 6),

                    // --- Title ---
                    AnimatedOpacity(
                      duration: Duration(milliseconds: _isFocused ? 0 : 800),
                      opacity: _isFocused ? 0.0 : _titleOp,
                      child: Text(
                        'Space',
                        textAlign: TextAlign.center,
                        style: GoogleFonts.outfit(
                          fontSize: 56,
                          fontWeight: FontWeight.w700,
                          color: AppColors.lightText,
                          height: 1.0,
                        ),
                      ),
                    ),

                    const Spacer(flex: 2),

                    // --- Middle slot: subtitle → input (typing) → name (done) ---
                    AnimatedSwitcher(
                      duration: Duration(milliseconds: _isFocused ? 0 : 600),
                      child: _showTagline && !_isFocused
                          ? FadeTransition(
                              key: const ValueKey('name'),
                              opacity: CurvedAnimation(
                                parent: _taglineController,
                                curve: Curves.easeOut,
                              ),
                              child: AnimatedOpacity(
                                duration: const Duration(milliseconds: 2500),
                                opacity: _isExiting ? 0.0 : 1.0,
                                child: AnimatedScale(
                                  duration: const Duration(milliseconds: 2500),
                                  scale: _isExiting ? 1.3 : 1.0,
                                  curve: Curves.easeIn,
                                  child: GestureDetector(
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
                                ),
                              ),
                            )
                          : showField
                          ? SizedBox(
                              key: const ValueKey('input'),
                              width: 220,
                              child: TextFormField(
                                controller: _nameController,
                                focusNode: _focusNode,
                                textAlign: TextAlign.center,
                                autofocus: true,
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
                                    borderSide: BorderSide(
                                      color: AppColors.refinedRed,
                                      width: 1.5,
                                    ),
                                  ),
                                  enabledBorder: InputBorder.none,
                                  contentPadding: EdgeInsets.only(bottom: 8),
                                ),
                                onChanged: _onTextChanged,
                              ),
                            )
                          : AnimatedOpacity(
                              key: const ValueKey('subtitle'),
                              duration: Duration(
                                milliseconds: _isFocused ? 0 : 600,
                              ),
                              opacity: _middleOpacity,
                              child: SizedBox(
                                width: 280,
                                child: Column(
                                  children: [
                                    Text(
                                      'Your journey starts by\ncreating a shared space\nfor your relationship',
                                      textAlign: TextAlign.center,
                                      style: AppTypography.bodyLarge(
                                        color: AppColors.warmDim,
                                      ),
                                    ),
                                    const SizedBox(height: AppSpacing.lg),
                                    AnimatedOpacity(
                                      duration: Duration(
                                        milliseconds: _isFocused ? 0 : 600,
                                      ),
                                      opacity: _isFocused ? 0.0 : _subtitle2Op,
                                      child: Text(
                                        'This is where you\ngrow, together',
                                        textAlign: TextAlign.center,
                                        style: GoogleFonts.inter(
                                          fontSize: 16,
                                          fontWeight: FontWeight.w500,
                                          color: AppColors.lightText,
                                          height: 1.6,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                    ),

                    const Spacer(flex: 2),

                    // --- Bottom slot: prompt → tagline (after naming) ---
                    AnimatedSwitcher(
                      duration: Duration(milliseconds: _isFocused ? 0 : 600),
                      child: _isExiting
                          ? const SizedBox.shrink(key: ValueKey('exit'))
                          : _showTagline && !_isFocused
                          ? FadeTransition(
                              key: const ValueKey('tagline'),
                              opacity: CurvedAnimation(
                                parent: _taglineController,
                                curve: Curves.easeOut,
                              ),
                              child: SizedBox(
                                width: 280,
                                child: Text(
                                  'Your personal, intimate, and\nsafe place to express\nand build memories',
                                  textAlign: TextAlign.center,
                                  style: GoogleFonts.inter(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w500,
                                    color: AppColors.lightText,
                                    height: 1.6,
                                  ),
                                ),
                              ),
                            )
                          : AnimatedOpacity(
                              key: const ValueKey('prompt'),
                              duration: Duration(
                                milliseconds: _isFocused ? 0 : 600,
                              ),
                              opacity: _isFocused ? 0.0 : _promptOp,
                              child: GestureDetector(
                                onTap: _tapPrompt,
                                child: Text(
                                  'tap to name your space',
                                  textAlign: TextAlign.center,
                                  style: GoogleFonts.outfit(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w400,
                                    color: AppColors.refinedRed,
                                  ),
                                ),
                              ),
                            ),
                    ),

                    // Bottom zone (bands + padding)
                    const Spacer(flex: 6),
                  ],
                ),
              ),
            ),
          ),

          // --- Advance: "tap to continue" pinned at bottom ---
          Positioned(
            left: 0,
            right: 0,
            bottom: bottomPad + 32,
            child: AnimatedOpacity(
              duration: Duration.zero,
              opacity: _isExiting ? 0.0 : 1.0,
              child: FadeTransition(
                opacity: CurvedAnimation(
                  parent: _continueController,
                  curve: Curves.easeOut,
                ),
                child: GestureDetector(
                  onTap: _hasText && !_isExiting ? _continue : null,
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
          ),
        ],
      ),
    );
  }
}
