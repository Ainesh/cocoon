/// Cocoon welcome screen.
///
/// Login with email/password or social auth (Google/Apple).
library;

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:go_router/go_router.dart';

import '../main.dart';
import '../services/auth_service.dart';
import '../services/firestore_service.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key, this.inviteCode});

  final String? inviteCode;

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _authService = AuthService();
  final _firestoreService = FirestoreService();

  bool _isLoading = false;
  bool _isGoogleLoading = false;
  bool _isSignUp = false;
  bool _obscurePassword = true;

  bool get _hasInviteCode =>
      widget.inviteCode != null && widget.inviteCode!.isNotEmpty;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  // ---------------------------------------------------------------------------
  // Auth Logic
  // ---------------------------------------------------------------------------

  Future<void> _handleEmailAuth() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    try {
      UserCredential credential;
      if (_isSignUp) {
        credential = await _authService.signUp(
          email: _emailController.text.trim(),
          password: _passwordController.text,
        );
      } else {
        credential = await _authService.signIn(
          email: _emailController.text.trim(),
          password: _passwordController.text,
        );
      }

      if (!mounted) return;
      await _handleSuccessfulAuth(credential.user?.uid);
    } on FirebaseAuthException catch (e) {
      _showError(_authService.getErrorMessage(e));
    } catch (e) {
      _showError('Authentication failed. Please try again.');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _handleGoogleSignIn() async {
    setState(() => _isGoogleLoading = true);

    try {
      final credential = await _authService.signInWithGoogle();
      if (credential == null) {
        if (mounted) setState(() => _isGoogleLoading = false);
        return;
      }

      if (!mounted) return;
      await _handleSuccessfulAuth(credential.user?.uid);
    } on FirebaseAuthException catch (e) {
      _showError(_authService.getErrorMessage(e));
    } catch (e) {
      _showError('Sign in failed. Please try again.');
    } finally {
      if (mounted) setState(() => _isGoogleLoading = false);
    }
  }

  Future<void> _handleAppleSignIn() async {
    _showError('Apple Sign-In requires a paid Apple Developer account');
  }

  Future<void> _handleSuccessfulAuth(String? userId) async {
    if (userId == null) return;

    if (_hasInviteCode) {
      final existingSpaceId = await _firestoreService.getUserSpaceId(userId);
      if (!mounted) return;

      if (existingSpaceId != null) {
        final shouldSwitch = await _showSpaceSwitchDialog();
        if (shouldSwitch == true && mounted) {
          await _firestoreService.clearSavedSpaceId();
          context.go('/join?code=${widget.inviteCode}');
        } else if (mounted) {
          context.go('/dashboard/$existingSpaceId');
        }
      } else {
        context.go('/join?code=${widget.inviteCode}');
      }
    } else {
      context.go('/');
    }
  }

  Future<bool?> _showSpaceSwitchDialog() {
    return showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Join New Space?'),
        content: const Text(
          'You\'re already nurturing a space. Would you like to join this new one instead?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Stay'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Join New'),
          ),
        ],
      ),
    );
  }

  void _showError(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  // ---------------------------------------------------------------------------
  // UI
  // ---------------------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: CocoonColors.pureBlack,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 32),
          child: Column(
            children: [
              const SizedBox(height: 60),
              _buildLogo(),
              const SizedBox(height: 24),
              _buildTitle(),
              const SizedBox(height: 8),
              _buildTagline(),
              if (_hasInviteCode) ...[
                const SizedBox(height: 20),
                _buildInviteBadge(),
              ],
              const SizedBox(height: 40),
              _buildEmailForm(),
              const SizedBox(height: 24),
              _buildDivider(),
              const SizedBox(height: 24),
              _buildSocialButtons(),
              const SizedBox(height: 32),
              _buildToggleAuthMode(),
              const SizedBox(height: 40),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildLogo() {
    return SvgPicture.asset(
      'assets/icons/cocoon_logo.svg',
      width: 70,
      height: 70,
    );
  }

  Widget _buildTitle() {
    return Text(
      'Cocoon',
      style: TextStyle(
        fontFamily: 'Oswald',
        fontSize: 38,
        fontWeight: FontWeight.w600,
        color: CocoonColors.lightText,
        letterSpacing: 3,
      ),
    );
  }

  Widget _buildTagline() {
    return Text(
      'Grow together, intentionally',
      style: TextStyle(
        fontFamily: 'Cormorant Garamond',
        fontSize: 16,
        fontWeight: FontWeight.w400,
        fontStyle: FontStyle.italic,
        color: CocoonColors.subtleText,
        letterSpacing: 0.5,
      ),
    );
  }

  Widget _buildInviteBadge() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(
        color: CocoonColors.refinedRed.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: CocoonColors.refinedRed.withValues(alpha: 0.2)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.favorite_rounded, size: 16, color: CocoonColors.refinedRed),
          const SizedBox(width: 8),
          Text(
            'You\'ve been invited to a space',
            style: TextStyle(
              color: CocoonColors.refinedRed,
              fontWeight: FontWeight.w500,
              fontSize: 13,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmailForm() {
    return Form(
      key: _formKey,
      child: Column(
        children: [
          // Email field
          TextFormField(
            controller: _emailController,
            keyboardType: TextInputType.emailAddress,
            style: TextStyle(color: CocoonColors.lightText),
            decoration: InputDecoration(
              labelText: 'Email',
              prefixIcon: Icon(Icons.email_outlined, color: CocoonColors.dimText),
            ),
            validator: (value) {
              if (value == null || value.isEmpty) return 'Please enter your email';
              if (!value.contains('@')) return 'Please enter a valid email';
              return null;
            },
          ),
          const SizedBox(height: 16),
          // Password field
          TextFormField(
            controller: _passwordController,
            obscureText: _obscurePassword,
            style: TextStyle(color: CocoonColors.lightText),
            decoration: InputDecoration(
              labelText: 'Password',
              prefixIcon: Icon(Icons.lock_outline, color: CocoonColors.dimText),
              suffixIcon: IconButton(
                icon: Icon(
                  _obscurePassword ? Icons.visibility_off : Icons.visibility,
                  color: CocoonColors.dimText,
                ),
                onPressed: () => setState(() => _obscurePassword = !_obscurePassword),
              ),
            ),
            validator: (value) {
              if (value == null || value.isEmpty) return 'Please enter your password';
              if (_isSignUp && value.length < 6) return 'Password must be at least 6 characters';
              return null;
            },
          ),
          const SizedBox(height: 24),
          // Submit button
          SizedBox(
            width: double.infinity,
            child: FilledButton(
              onPressed: _isLoading ? null : _handleEmailAuth,
              child: _isLoading
                  ? SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: CocoonColors.pureBlack,
                      ),
                    )
                  : Text(_isSignUp ? 'Create Account' : 'Sign In'),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDivider() {
    return Row(
      children: [
        Expanded(child: Divider(color: CocoonColors.dimText.withValues(alpha: 0.3))),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Text(
            'or continue with',
            style: TextStyle(color: CocoonColors.dimText, fontSize: 13),
          ),
        ),
        Expanded(child: Divider(color: CocoonColors.dimText.withValues(alpha: 0.3))),
      ],
    );
  }

  Widget _buildSocialButtons() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        _SocialButton(
          isGoogle: true,
          isLoading: _isGoogleLoading,
          onPressed: _handleGoogleSignIn,
        ),
        const SizedBox(width: 20),
        _SocialButton(
          isGoogle: false,
          isLoading: false,
          onPressed: _handleAppleSignIn,
        ),
      ],
    );
  }

  Widget _buildToggleAuthMode() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Text(
          _isSignUp ? 'Already have an account?' : 'Don\'t have an account?',
          style: TextStyle(color: CocoonColors.dimText, fontSize: 14),
        ),
        TextButton(
          onPressed: () => setState(() => _isSignUp = !_isSignUp),
          child: Text(
            _isSignUp ? 'Sign In' : 'Sign Up',
            style: TextStyle(
              color: CocoonColors.refinedRed,
              fontWeight: FontWeight.w600,
              fontSize: 14,
            ),
          ),
        ),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// Social Button
// ---------------------------------------------------------------------------

class _SocialButton extends StatefulWidget {
  const _SocialButton({
    required this.isGoogle,
    required this.isLoading,
    required this.onPressed,
  });

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
            color: CocoonColors.darkGlass,
            shape: BoxShape.circle,
            border: Border.all(
              color: CocoonColors.refinedRed.withValues(alpha: 0.15),
              width: 1,
            ),
            boxShadow: [
              BoxShadow(
                color: CocoonColors.refinedRed.withValues(alpha: 0.1),
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
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: CocoonColors.refinedRed,
                    ),
                  )
                : SvgPicture.asset(
                    widget.isGoogle
                        ? 'assets/icons/google_logo.svg'
                        : 'assets/icons/apple_logo.svg',
                    width: 26,
                    height: 26,
                  ),
          ),
        ),
      ),
    );
  }
}
