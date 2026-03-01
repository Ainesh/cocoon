/// Screen 2 — About You: name, avatar, and space creation.
///
/// Creates the space on submit and shows a brief celebration
/// before auto-advancing.
library;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../models/avatar_data.dart';
import '../../../services/auth_service.dart';
import '../../../services/firestore_service.dart';
import '../../../theme/app_colors.dart';
import '../../../theme/app_spacing.dart';
import '../../../theme/app_typography.dart';
import '../../../widgets/avatar_selector.dart';

class AboutYouScreen extends StatefulWidget {
  const AboutYouScreen({
    super.key,
    required this.spaceName,
    required this.onSpaceCreated,
  });

  final String spaceName;
  final void Function(String spaceId, String inviteCode, String userName)
      onSpaceCreated;

  @override
  State<AboutYouScreen> createState() => _AboutYouScreenState();
}

class _AboutYouScreenState extends State<AboutYouScreen>
    with TickerProviderStateMixin {
  final _authService = AuthService();
  final _firestoreService = FirestoreService();
  final _nameController = TextEditingController();

  AvatarData? _selectedAvatar;
  AvatarColor _selectedColor = AvatarColor.blue;
  bool _isCreating = false;
  bool _showCeremony = false;

  late final AnimationController _ceremonyController;
  late final Animation<double> _ceremonyScale;
  late final Animation<double> _ceremonyFade;

  @override
  void initState() {
    super.initState();
    _ceremonyController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1600),
    );
    _ceremonyScale = Tween<double>(begin: 0.6, end: 1.0).animate(
      CurvedAnimation(
        parent: _ceremonyController,
        curve: const Interval(0.0, 0.6, curve: Curves.elasticOut),
      ),
    );
    _ceremonyFade = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _ceremonyController,
        curve: const Interval(0.0, 0.25, curve: Curves.easeOut),
      ),
    );
  }

  @override
  void dispose() {
    _nameController.dispose();
    _ceremonyController.dispose();
    super.dispose();
  }

  bool get _canCreate =>
      _nameController.text.trim().isNotEmpty && _selectedAvatar != null;

  // ---------------------------------------------------------------------------
  // Actions
  // ---------------------------------------------------------------------------

  Future<void> _createSpace() async {
    FocusScope.of(context).unfocus();
    if (!_canCreate) return;
    setState(() => _isCreating = true);

    try {
      final userId = _authService.currentUser?.uid;
      if (userId == null) throw Exception('Not logged in');

      final avatarKey = _selectedAvatar!.getAvatarKey(_selectedColor);
      final userName = _nameController.text.trim();

      final result = await _firestoreService.createSpace(
        userId: userId,
        spaceName: widget.spaceName,
        userName: userName,
        avatarKey: avatarKey,
      );

      await _firestoreService.logSpaceCreatedActivity(
        spaceId: result.spaceId,
        userId: userId,
        userName: userName,
        spaceName: widget.spaceName,
      );

      if (!mounted) return;

      setState(() => _showCeremony = true);
      HapticFeedback.heavyImpact();
      _ceremonyController.forward();

      await Future.delayed(const Duration(milliseconds: 2000));
      if (!mounted) return;
      widget.onSpaceCreated(result.spaceId, result.inviteCode, userName);
    } catch (e) {
      if (!mounted) return;
      setState(() => _isCreating = false);
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
    if (_showCeremony) return _buildCeremony();

    return GestureDetector(
      onTap: () => FocusScope.of(context).unfocus(),
      behavior: HitTestBehavior.opaque,
      child: Container(
        color: AppColors.pureBlack,
        child: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.screenPadding,
              vertical: AppSpacing.lg,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const SizedBox(height: AppSpacing.xxl),
                Text(
                  'Who are you?',
                  style: AppTypography.headlineLarge(
                    color: AppColors.lightText,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: AppSpacing.sm),
                Text(
                  'Set up your profile for "${widget.spaceName}"',
                  style: AppTypography.bodyLarge(color: AppColors.warmDim),
                  textAlign: TextAlign.center,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: AppSpacing.xxxl),

                // Name
                Text('YOUR NAME', style: AppTypography.cardLabel()),
                const SizedBox(height: AppSpacing.sm),
                TextFormField(
                  controller: _nameController,
                  textCapitalization: TextCapitalization.words,
                  style: AppTypography.titleLarge(color: AppColors.lightText),
                  decoration: InputDecoration(
                    hintText: 'What should we call you?',
                    hintStyle: AppTypography.titleLarge(
                      color: AppColors.warmMuted,
                    ),
                    filled: true,
                    fillColor: AppColors.darkCardLight,
                    border: OutlineInputBorder(
                      borderRadius:
                          BorderRadius.circular(AppSpacing.cardRadius),
                      borderSide: BorderSide.none,
                    ),
                    contentPadding: const EdgeInsets.symmetric(
                      vertical: AppSpacing.lg,
                      horizontal: AppSpacing.lg,
                    ),
                  ),
                  onChanged: (_) => setState(() {}),
                ),
                const SizedBox(height: AppSpacing.xxxl),

                // Avatar
                AvatarSelector(
                  selectedAvatar: _selectedAvatar,
                  selectedColor: _selectedColor,
                  onAvatarSelected: (a) =>
                      setState(() => _selectedAvatar = a),
                  onColorSelected: (c) =>
                      setState(() => _selectedColor = c),
                ),
                const SizedBox(height: AppSpacing.xxxl),

                // Create button
                AnimatedOpacity(
                  duration: const Duration(milliseconds: 200),
                  opacity: _canCreate ? 1.0 : 0.35,
                  child: GestureDetector(
                    onTap: _canCreate && !_isCreating ? _createSpace : null,
                    child: Container(
                      height: AppSpacing.buttonHeightLarge,
                      decoration: BoxDecoration(
                        color: AppColors.refinedRed,
                        borderRadius:
                            BorderRadius.circular(AppSpacing.cardRadius),
                      ),
                      alignment: Alignment.center,
                      child: _isCreating
                          ? const SizedBox(
                              width: 24,
                              height: 24,
                              child: CircularProgressIndicator(
                                strokeWidth: 2.5,
                                color: AppColors.pureBlack,
                              ),
                            )
                          : Text(
                              'Create Space',
                              style: AppTypography.titleMedium(
                                color: AppColors.pureBlack,
                              ),
                            ),
                    ),
                  ),
                ),
                const SizedBox(height: AppSpacing.xxxl),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildCeremony() {
    return Container(
      color: AppColors.pureBlack,
      child: Center(
        child: AnimatedBuilder(
          animation: _ceremonyController,
          builder: (context, _) => Opacity(
            opacity: _ceremonyFade.value,
            child: Transform.scale(
              scale: _ceremonyScale.value,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 80,
                    height: 80,
                    decoration: BoxDecoration(
                      color: AppColors.refinedRed.withValues(alpha: 0.1),
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: AppColors.refinedRed.withValues(alpha: 0.3),
                      ),
                    ),
                    child: const Icon(
                      Icons.home_rounded,
                      size: 36,
                      color: AppColors.refinedRed,
                    ),
                  ),
                  const SizedBox(height: 24),
                  Text(
                    widget.spaceName,
                    style: AppTypography.headlineLarge(
                      color: AppColors.lightText,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'your space is ready',
                    style: AppTypography.tagline(color: AppColors.warmDim),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
