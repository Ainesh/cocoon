/// Onboarding screen for Couple Space app.
///
/// Three-step wizard for creating a new couple space:
/// 1. Name your space
/// 2. Your details (name + avatar)
/// 3. Invite your partner
library;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:share_plus/share_plus.dart';

import '../models/avatar_data.dart';
import '../services/auth_service.dart';
import '../services/firestore_service.dart';
import '../widgets/avatar_selector.dart';

/// Multi-step onboarding wizard for creating a couple space.
class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  // Controllers
  final _pageController = PageController();
  final _spaceNameController = TextEditingController(text: 'Us ❤️');
  final _partnerNameController = TextEditingController();

  // Services
  final _authService = AuthService();
  final _firestoreService = FirestoreService();

  // State
  int _currentPage = 0;
  AvatarData? _selectedAvatar;
  AvatarColor _selectedColor = AvatarColor.blue;
  bool _isLoading = false;

  // Result from space creation
  String? _spaceId;
  String? _inviteCode;

  @override
  void dispose() {
    _pageController.dispose();
    _spaceNameController.dispose();
    _partnerNameController.dispose();
    super.dispose();
  }

  // ---------------------------------------------------------------------------
  // Navigation
  // ---------------------------------------------------------------------------

  void _nextPage() {
    if (_currentPage < 2) {
      _pageController.nextPage(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
    }
  }

  void _previousPage() {
    if (_currentPage > 0) {
      _pageController.previousPage(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
    }
  }

  bool _canProceedFromPage(int page) {
    return switch (page) {
      0 => _spaceNameController.text.trim().isNotEmpty,
      1 => _partnerNameController.text.trim().isNotEmpty && _selectedAvatar != null,
      _ => true,
    };
  }

  // ---------------------------------------------------------------------------
  // Space Creation
  // ---------------------------------------------------------------------------

  Future<void> _createSpace() async {
    if (!_canProceedFromPage(1)) return;

    setState(() => _isLoading = true);

    try {
      final userId = _authService.currentUser?.uid;
      if (userId == null) throw Exception('User not logged in');

      final avatarKey = _selectedAvatar!.getAvatarKey(_selectedColor);
      final spaceName = _spaceNameController.text.trim();
      final userName = _partnerNameController.text.trim();

      final result = await _firestoreService.createSpace(
        userId: userId,
        spaceName: spaceName,
        userName: userName,
        avatarKey: avatarKey,
      );

      // Log space created activity
      await _firestoreService.logSpaceCreatedActivity(
        spaceId: result.spaceId,
        userId: userId,
        userName: userName,
        spaceName: spaceName,
      );

      setState(() {
        _spaceId = result.spaceId;
        _inviteCode = result.inviteCode;
      });

      _nextPage();
    } catch (e) {
      _showError('Error: ${e.toString()}');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  // ---------------------------------------------------------------------------
  // Invite Actions
  // ---------------------------------------------------------------------------

  void _copyInviteCode() {
    if (_inviteCode == null) return;

    Clipboard.setData(ClipboardData(text: _inviteCode!));
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: const Text('Invite code copied!'),
        backgroundColor: Theme.of(context).colorScheme.primary,
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 2),
      ),
    );
  }

  void _shareInviteCode() {
    if (_inviteCode == null) return;

    Share.share(
      'Join my couple space! Use code: $_inviteCode',
      subject: 'Couple Space Invite',
    );
  }

  void _goToDashboard() {
    if (_spaceId != null) {
      context.go('/dashboard/$_spaceId');
    }
  }

  // ---------------------------------------------------------------------------
  // Error Handling
  // ---------------------------------------------------------------------------

  void _showError(String message) {
    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Theme.of(context).colorScheme.error,
        behavior: SnackBarBehavior.floating,
        duration: const Duration(days: 1),
        showCloseIcon: true,
        closeIconColor: Colors.white,
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // UI Build Methods
  // ---------------------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      backgroundColor: theme.colorScheme.surface,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: _currentPage > 0 && _currentPage < 2
            ? IconButton(
                icon: const Icon(Icons.arrow_back_rounded),
                onPressed: _previousPage,
              )
            : null,
        title: Text(
          'Create Your Space',
          style: TextStyle(
            color: theme.colorScheme.onSurface,
            fontWeight: FontWeight.w600,
          ),
        ),
        centerTitle: true,
      ),
      body: Column(
        children: [
          _buildProgressIndicator(theme),
          Expanded(
            child: PageView(
              controller: _pageController,
              physics: const NeverScrollableScrollPhysics(),
              onPageChanged: (page) => setState(() => _currentPage = page),
              children: [
                _buildNameSpacePage(theme),
                _buildYourDetailsPage(theme),
                _buildInvitePartnerPage(theme),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildProgressIndicator(ThemeData theme) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
      child: Row(
        children: List.generate(3, (index) {
          final isActive = index <= _currentPage;
          return Expanded(
            child: Container(
              margin: EdgeInsets.only(right: index < 2 ? 8 : 0),
              height: 4,
              decoration: BoxDecoration(
                color: isActive
                    ? theme.colorScheme.primary
                    : theme.colorScheme.outline.withValues(alpha: 0.3),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          );
        }),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Page 1: Name Space
  // ---------------------------------------------------------------------------

  Widget _buildNameSpacePage(ThemeData theme) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const SizedBox(height: 20),
          Icon(Icons.home_rounded, size: 56, color: theme.colorScheme.primary),
          const SizedBox(height: 16),
          Text(
            'Name your space',
            style: theme.textTheme.headlineSmall?.copyWith(
              fontWeight: FontWeight.bold,
              color: theme.colorScheme.onSurface,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 8),
          Text(
            'Give your couple space a special name',
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 40),
          TextFormField(
            controller: _spaceNameController,
            textAlign: TextAlign.center,
            style: theme.textTheme.headlineMedium?.copyWith(
              fontWeight: FontWeight.w600,
            ),
            decoration: InputDecoration(
              hintText: 'Us ❤️',
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(20)),
              filled: true,
              fillColor: theme.colorScheme.surfaceContainerLowest,
            ),
            onChanged: (_) => setState(() {}),
          ),
          const SizedBox(height: 16),
          Wrap(
            alignment: WrapAlignment.center,
            spacing: 8,
            children: ['❤️', '💕', '🏠', '✨', '💫', '🌟'].map((emoji) {
              return ActionChip(
                label: Text(emoji, style: const TextStyle(fontSize: 20)),
                onPressed: () {
                  _spaceNameController.text += emoji;
                  _spaceNameController.selection = TextSelection.fromPosition(
                    TextPosition(offset: _spaceNameController.text.length),
                  );
                  setState(() {});
                },
                backgroundColor: theme.colorScheme.surfaceContainerLow,
                side: BorderSide.none,
              );
            }).toList(),
          ),
          const SizedBox(height: 48),
          FilledButton(
            onPressed: _canProceedFromPage(0) ? _nextPage : null,
            style: FilledButton.styleFrom(
              minimumSize: const Size.fromHeight(56),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            ),
            child: const Text(
              'Continue',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Page 2: Your Details
  // ---------------------------------------------------------------------------

  Widget _buildYourDetailsPage(ThemeData theme) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'Your details',
            style: theme.textTheme.headlineSmall?.copyWith(
              fontWeight: FontWeight.bold,
              color: theme.colorScheme.onSurface,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 8),
          Text(
            'Tell us about yourself',
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 32),
          Text(
            'Your name',
            style: theme.textTheme.labelLarge?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 8),
          TextFormField(
            controller: _partnerNameController,
            textCapitalization: TextCapitalization.words,
            decoration: InputDecoration(
              hintText: 'Enter your name',
              prefixIcon: const Icon(Icons.person_outline),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(16)),
              filled: true,
              fillColor: theme.colorScheme.surfaceContainerLowest,
            ),
            onChanged: (_) => setState(() {}),
          ),
          const SizedBox(height: 32),
          AvatarSelector(
            selectedAvatar: _selectedAvatar,
            selectedColor: _selectedColor,
            onAvatarSelected: (avatar) => setState(() => _selectedAvatar = avatar),
            onColorSelected: (color) => setState(() => _selectedColor = color),
          ),
          const SizedBox(height: 32),
          FilledButton(
            onPressed: _canProceedFromPage(1) && !_isLoading ? _createSpace : null,
            style: FilledButton.styleFrom(
              minimumSize: const Size.fromHeight(56),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            ),
            child: _isLoading
                ? SizedBox(
                    height: 24,
                    width: 24,
                    child: CircularProgressIndicator(
                      strokeWidth: 2.5,
                      color: theme.colorScheme.onPrimary,
                    ),
                  )
                : const Text(
                    'Create Space',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                  ),
          ),
        ],
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Page 3: Invite Partner
  // ---------------------------------------------------------------------------

  Widget _buildInvitePartnerPage(ThemeData theme) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const SizedBox(height: 20),
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: theme.colorScheme.primaryContainer,
              shape: BoxShape.circle,
            ),
            child: Icon(
              Icons.celebration_rounded,
              size: 48,
              color: theme.colorScheme.onPrimaryContainer,
            ),
          ),
          const SizedBox(height: 24),
          Text(
            'Invite your partner',
            style: theme.textTheme.headlineSmall?.copyWith(
              fontWeight: FontWeight.bold,
              color: theme.colorScheme.onSurface,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 8),
          Text(
            'Share this code with your partner to join your space',
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 40),
          Container(
            padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 32),
            decoration: BoxDecoration(
              color: theme.colorScheme.surfaceContainerLow,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: theme.colorScheme.outline.withValues(alpha: 0.3),
              ),
            ),
            child: Column(
              children: [
                Text(
                  'Your invite code',
                  style: theme.textTheme.labelMedium?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: 12),
                SelectableText(
                  _inviteCode ?? '------',
                  style: theme.textTheme.displaySmall?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: theme.colorScheme.primary,
                    letterSpacing: 8,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
          OutlinedButton.icon(
            onPressed: _copyInviteCode,
            icon: const Icon(Icons.copy_rounded),
            label: const Text('Copy Code'),
            style: OutlinedButton.styleFrom(
              minimumSize: const Size.fromHeight(52),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            ),
          ),
          const SizedBox(height: 12),
          OutlinedButton.icon(
            onPressed: _shareInviteCode,
            icon: const Icon(Icons.share_rounded),
            label: const Text('Share via Messages'),
            style: OutlinedButton.styleFrom(
              minimumSize: const Size.fromHeight(52),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            ),
          ),
          const SizedBox(height: 32),
          FilledButton(
            onPressed: _goToDashboard,
            style: FilledButton.styleFrom(
              minimumSize: const Size.fromHeight(56),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            ),
            child: const Text(
              'Continue to Dashboard',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );
  }
}
