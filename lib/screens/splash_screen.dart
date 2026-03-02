/// Splash screen for Kairos app.
///
/// Displays the Kairos logo + tagline on a black background — visually
/// identical to onboarding Screen 0 so the transition is seamless.
/// Determines the initial navigation destination based on auth state.
library;

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';

import '../services/auth_service.dart';
import '../services/firestore_service.dart';
import '../theme/app_colors.dart';

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

  Future<void> _determineInitialRoute() async {
    await Future.delayed(const Duration(milliseconds: 500));
    if (!mounted) return;

    final user = _authService.currentUser;

    if (user == null) {
      context.go('/login');
      return;
    }

    try {
      final spaceId = await _firestoreService.getUserSpaceId(user.uid);
      if (!mounted) return;

      if (spaceId != null) {
        context.go('/dashboard/$spaceId');
      } else {
        context.go('/onboarding');
      }
    } catch (e) {
      debugPrint('Error checking space: $e');
      if (mounted) context.go('/onboarding');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.pureBlack,
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Kairos',
              style: GoogleFonts.drSugiyama(
                fontSize: 52,
                color: AppColors.refinedRed,
                height: 1.2,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'This is the moment',
              style: GoogleFonts.outfit(
                fontSize: 16,
                fontWeight: FontWeight.w500,
                color: AppColors.lightText,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
