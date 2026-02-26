/// Splash screen for Kairos app.
///
/// Displays app branding while determining the initial navigation destination
/// based on authentication state and space membership.
library;

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../services/auth_service.dart';
import '../services/firestore_service.dart';

/// Initial screen that checks auth status and navigates to the appropriate destination.
///
/// Navigation Logic:
/// - No user → `/login`
/// - User with space → `/dashboard/:spaceId`
/// - User without space → `/onboarding`
class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  final _authService = AuthService();
  final _firestoreService = FirestoreService();

  @override
  void initState() {
    super.initState();
    _determineInitialRoute();
  }

  /// Checks authentication and space status, then navigates accordingly.
  Future<void> _determineInitialRoute() async {
    // Brief delay for splash effect
    await Future.delayed(const Duration(milliseconds: 500));
    if (!mounted) return;

    final user = _authService.currentUser;

    // Not logged in → Login
    if (user == null) {
      context.go('/login');
      return;
    }

    // Logged in → Check for existing space
    try {
      final spaceId = await _firestoreService.getUserSpaceId(user.uid);
      if (!mounted) return;

      if (spaceId != null) {
        // Has space → Dashboard
        context.go('/dashboard/$spaceId');
      } else {
        // No space → Onboarding
        context.go('/onboarding');
      }
    } catch (e) {
      debugPrint('Error checking space: $e');
      if (mounted) context.go('/onboarding');
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      backgroundColor: theme.colorScheme.surface,
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // App Icon
            Icon(
              Icons.favorite_rounded,
              size: 80,
              color: theme.colorScheme.primary,
            ),
            const SizedBox(height: 24),

            // App Name
            Text(
              'Kairos',
              style: theme.textTheme.headlineMedium?.copyWith(
                fontWeight: FontWeight.bold,
                color: theme.colorScheme.onSurface,
              ),
            ),
            const SizedBox(height: 32),

            // Loading Indicator
            SizedBox(
              width: 32,
              height: 32,
              child: CircularProgressIndicator(
                strokeWidth: 3,
                color: theme.colorScheme.primary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
