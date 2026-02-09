/// Cocoon join screen.
///
/// Allows users to join an existing space with an invite code.
/// Uses social auth (Google/Apple) and then collects profile info.
library;

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:go_router/go_router.dart';

import '../models/avatar_data.dart';
import '../theme/app_colors.dart';
import '../services/auth_service.dart';
import '../services/firestore_service.dart';
import '../widgets/avatar_selector.dart';

class JoinScreen extends StatefulWidget {
  const JoinScreen({super.key, required this.inviteCode});

  final String inviteCode;

  @override
  State<JoinScreen> createState() => _JoinScreenState();
}

class _JoinScreenState extends State<JoinScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _authService = AuthService();
  final _firestoreService = FirestoreService();

  bool _isLoading = false;
  bool _isJoining = false;

  bool get _isAuthenticated => _authService.currentUser != null;

  AvatarData? _selectedAvatar;
  AvatarColor _selectedColor = AvatarColor.blue;

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  Future<void> _handleGoogleSignIn() async {
    setState(() => _isLoading = true);
    try {
      final credential = await _authService.signInWithGoogle();
      if (credential == null) {
        if (mounted) setState(() => _isLoading = false);
        return;
      }
      if (mounted) setState(() {});
    } on FirebaseAuthException catch (e) {
      _showError(_authService.getErrorMessage(e));
    } catch (e) {
      _showError('Sign in failed. Please try again.');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _handleAppleSignIn() async {
    _showError('Apple Sign-In requires a paid Apple Developer account');
  }

  Future<void> _handleJoin() async {
    if (!_formKey.currentState!.validate()) return;
    if (_selectedAvatar == null) {
      _showError('Please select an avatar');
      return;
    }

    setState(() => _isJoining = true);
    try {
      final userId = _authService.currentUser?.uid;
      if (userId == null) throw Exception('Not authenticated');

      final avatarKey = _selectedAvatar!.getAvatarKey(_selectedColor);
      final userName = _nameController.text.trim();
      final result = await _firestoreService.joinSpace(
        inviteCode: widget.inviteCode,
        userId: userId,
        userName: userName,
        avatarKey: avatarKey,
      );

      if (!mounted) return;

      if (result == JoinResult.success) {
        final profile = await _firestoreService.getUserProfile(userId);
        final spaceId = profile?['spaceId'] as String?;
        
        // Log space joined activity
        if (spaceId != null) {
          await _firestoreService.logSpaceJoinedActivity(
            spaceId: spaceId,
            userId: userId,
            userName: userName,
          );
        }
        
        if (mounted && spaceId != null) {
          context.go('/dashboard/$spaceId');
        }
      } else {
        _showError(result.message);
      }
    } on FirebaseAuthException catch (e) {
      _showError(_authService.getErrorMessage(e));
    } catch (e) {
      _showError('Error: ${e.toString()}');
    } finally {
      if (mounted) setState(() => _isJoining = false);
    }
  }

  void _showError(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.pureBlack,
      body: SafeArea(
        child: _isAuthenticated ? _buildProfileStep() : _buildAuthStep(),
      ),
    );
  }

  Widget _buildAuthStep() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 32),
      child: Column(
        children: [
          const Spacer(flex: 2),
          _buildLogo(),
          const SizedBox(height: 24),
          _buildTitle('Join a Space'),
          const SizedBox(height: 12),
          _buildSubtitle('Sign in to accept the invitation'),
          const SizedBox(height: 20),
          _buildInviteBadge(),
          const Spacer(flex: 2),
          _buildContinueWith(),
          const SizedBox(height: 20),
          _buildSocialButtons(),
          const SizedBox(height: 40),
          _buildBackLink(),
          const SizedBox(height: 32),
        ],
      ),
    );
  }

  Widget _buildProfileStep() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(32),
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const SizedBox(height: 20),
            _buildLogo(),
            const SizedBox(height: 24),
            _buildTitle('Complete Your Profile'),
            const SizedBox(height: 12),
            _buildSubtitle('Set up your name and avatar to join'),
            const SizedBox(height: 32),
            _buildInviteBadge(),
            const SizedBox(height: 32),
            _buildNameField(),
            const SizedBox(height: 24),
            _buildAvatarSection(),
            const SizedBox(height: 32),
            _buildJoinButton(),
            const SizedBox(height: 16),
            _buildSwitchAccountLink(),
            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }

  Widget _buildLogo() {
    return Container(
      width: 80,
      height: 80,
      decoration: BoxDecoration(
        gradient: RadialGradient(
          colors: [
            AppColors.refinedRed.withValues(alpha: 0.15),
            AppColors.accentPurple.withValues(alpha: 0.08),
            Colors.transparent,
          ],
        ),
        shape: BoxShape.circle,
      ),
      child: Center(
        child: SvgPicture.asset(
          'assets/icons/cocoon_logo.svg',
          width: 50,
          height: 50,
        ),
      ),
    );
  }

  Widget _buildTitle(String text) {
    return Text(
      text,
      style: TextStyle(
        fontFamily: 'Oswald',
        fontSize: 28,
        fontWeight: FontWeight.w600,
        color: AppColors.lightText,
        letterSpacing: 1,
      ),
      textAlign: TextAlign.center,
    );
  }

  Widget _buildSubtitle(String text) {
    return Text(
      text,
      style: TextStyle(
        fontFamily: 'Cormorant Garamond',
        fontSize: 16,
        fontStyle: FontStyle.italic,
        color: AppColors.subtleText,
      ),
      textAlign: TextAlign.center,
    );
  }

  Widget _buildInviteBadge() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            AppColors.accentPurple.withValues(alpha: 0.15),
            AppColors.refinedRed.withValues(alpha: 0.1),
          ],
        ),
        borderRadius: BorderRadius.circular(30),
        border: Border.all(color: AppColors.refinedRed.withValues(alpha: 0.2)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.favorite_rounded, size: 18, color: AppColors.refinedRed),
          const SizedBox(width: 10),
          Text(
            'Code: ${widget.inviteCode}',
            style: TextStyle(
              color: AppColors.brightRed,
              fontWeight: FontWeight.w500,
              fontSize: 14,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildContinueWith() {
    return Text(
      'Enter your space',
      style: TextStyle(
        fontSize: 13,
        fontWeight: FontWeight.w500,
        color: AppColors.dimText,
        letterSpacing: 1,
      ),
    );
  }

  Widget _buildSocialButtons() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        _SocialButton(isGoogle: true, isLoading: _isLoading, onPressed: _handleGoogleSignIn),
        const SizedBox(width: 24),
        _SocialButton(isGoogle: false, isLoading: false, onPressed: _handleAppleSignIn),
      ],
    );
  }

  Widget _buildBackLink() {
    return TextButton(
      onPressed: () => context.go('/login'),
      child: Text('Cancel', style: TextStyle(color: AppColors.dimText, fontSize: 16)),
    );
  }

  Widget _buildNameField() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Your Name',
          style: TextStyle(color: AppColors.lightText, fontSize: 16, fontWeight: FontWeight.w600),
        ),
        const SizedBox(height: 12),
        TextFormField(
          controller: _nameController,
          textCapitalization: TextCapitalization.words,
          style: TextStyle(color: AppColors.lightText, fontSize: 16),
          decoration: InputDecoration(
            hintText: 'Enter your name',
            hintStyle: TextStyle(color: AppColors.dimText.withValues(alpha: 0.5)),
            prefixIcon: Icon(Icons.person_outline, color: AppColors.dimText),
          ),
          validator: (value) {
            if (value == null || value.isEmpty) return 'Please enter your name';
            return null;
          },
        ),
      ],
    );
  }

  Widget _buildAvatarSection() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.cardSurface,
        borderRadius: BorderRadius.circular(20),
      ),
      child: AvatarSelector(
        selectedAvatar: _selectedAvatar,
        selectedColor: _selectedColor,
        onAvatarSelected: (avatar) => setState(() => _selectedAvatar = avatar),
        onColorSelected: (color) => setState(() => _selectedColor = color),
      ),
    );
  }

  Widget _buildJoinButton() {
    return FilledButton(
      onPressed: _isJoining ? null : _handleJoin,
      child: _isJoining
          ? const SizedBox(
              width: 24,
              height: 24,
              child: CircularProgressIndicator(strokeWidth: 2.5, color: Colors.black),
            )
          : const Text('Join Space →'),
    );
  }

  Widget _buildSwitchAccountLink() {
    return TextButton(
      onPressed: () async {
        await _authService.signOut();
        if (mounted) setState(() {});
      },
      child: Text('Use a different account', style: TextStyle(color: AppColors.dimText, fontSize: 14)),
    );
  }
}

class _SocialButton extends StatefulWidget {
  const _SocialButton({required this.isGoogle, required this.isLoading, required this.onPressed});

  final bool isGoogle;
  final bool isLoading;
  final VoidCallback onPressed;

  @override
  State<_SocialButton> createState() => _SocialButtonState();
}

class _SocialButtonState extends State<_SocialButton> {
  bool _isPressed = false;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (_) => setState(() => _isPressed = true),
      onTapUp: (_) {
        setState(() => _isPressed = false);
        if (!widget.isLoading) widget.onPressed();
      },
      onTapCancel: () => setState(() => _isPressed = false),
      child: AnimatedScale(
        scale: _isPressed ? 0.93 : 1.0,
        duration: const Duration(milliseconds: 100),
        child: Container(
          width: 56,
          height: 56,
          decoration: BoxDecoration(
            color: AppColors.darkGlass,
            shape: BoxShape.circle,
            border: Border.all(color: AppColors.refinedRed.withValues(alpha: 0.15), width: 1),
            boxShadow: [
              BoxShadow(
                color: AppColors.refinedRed.withValues(alpha: 0.1),
                blurRadius: 12,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Center(
            child: widget.isLoading
                ? SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.refinedRed),
                  )
                : SvgPicture.asset(
                    widget.isGoogle ? 'assets/icons/google_logo.svg' : 'assets/icons/apple_logo.svg',
                    width: 26,
                    height: 26,
                  ),
          ),
        ),
      ),
    );
  }
}
