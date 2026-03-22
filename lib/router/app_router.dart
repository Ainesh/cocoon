/// Application router configuration for Couple Space app.
///
/// Uses GoRouter for declarative, URL-based navigation with auth guards
/// and custom page transitions.
library;

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../models/memory.dart';
import '../models/moment.dart';
import '../screens/checkin/checkin_screen.dart';
import '../screens/join_screen.dart';
import '../screens/login_screen.dart';
import '../screens/main_shell.dart';
import '../screens/memory/create_memory_screen.dart';
import '../screens/memory/edit_memory_screen.dart';
import '../screens/memory/memory_detail_page.dart';
import '../screens/moment/edit_moment_screen.dart';
import '../screens/moment/plan_moment_screen.dart';
import '../screens/onboarding/onboarding_flow.dart';
import '../screens/splash_screen.dart';
import '../services/auth_service.dart';
import '../services/firestore_service.dart';

/// Centralized router configuration for the app.
///
/// Routes:
/// - `/` - Splash screen (determines initial destination)
/// - `/login` - Welcome screen with social login (optional `code` query param for invite)
/// - `/join` - Join space screen (requires `code` query param)
/// - `/onboarding` - Create space onboarding flow
/// - `/dashboard/:spaceId` - Main dashboard for a couple space
///
/// Route Guards:
/// - Unauthenticated users are redirected to `/login`
/// - Authenticated users on auth routes are redirected based on space status
/// - `/join` route is accessible to all (handles auth internally)
abstract final class AppRouter {
  // Services for auth state checks
  static final _authService = AuthService();
  static final _firestoreService = FirestoreService();

  /// The main router instance for the app.
  static final GoRouter router = GoRouter(
    initialLocation: '/',
    redirect: _handleRedirect,
    routes: _routes,
    errorPageBuilder: _errorPageBuilder,
  );

  // ---------------------------------------------------------------------------
  // Route Definitions
  // ---------------------------------------------------------------------------

  static final List<RouteBase> _routes = [
    // Splash - Simple heart icon
    GoRoute(
      path: '/',
      name: 'splash',
      pageBuilder: (context, state) =>
          _fadeTransition(state, const SplashScreen()),
    ),

    // Login - Welcome screen with social login
    GoRoute(
      path: '/login',
      name: 'login',
      pageBuilder: (context, state) {
        final inviteCode = state.uri.queryParameters['code'];
        return _fadeTransition(state, LoginScreen(inviteCode: inviteCode));
      },
    ),

    // Join - Join existing space with invite code
    GoRoute(
      path: '/join',
      name: 'join',
      pageBuilder: (context, state) {
        final code = state.uri.queryParameters['code'] ?? '';
        return _fadeTransition(state, JoinScreen(inviteCode: code));
      },
    ),

    // Onboarding - Create new couple space
    GoRoute(
      path: '/onboarding',
      name: 'onboarding',
      pageBuilder: (context, state) =>
          _fadeTransition(state, const OnboardingFlow()),
    ),

    // Dashboard - Main app screen (with bottom navigation)
    GoRoute(
      path: '/dashboard/:spaceId',
      name: 'dashboard',
      pageBuilder: (context, state) {
        final spaceId = state.pathParameters['spaceId'] ?? '';
        return _fadeTransition(state, MainShell(spaceId: spaceId));
      },
    ),

    // Check-in - Submit relationship check-in
    GoRoute(
      path: '/checkin/:spaceId',
      name: 'checkin',
      pageBuilder: (context, state) {
        final spaceId = state.pathParameters['spaceId'] ?? '';
        return _slideTransition(state, CheckInScreen(spaceId: spaceId));
      },
    ),

    // Plan a Moment - Create new moment
    GoRoute(
      path: '/moment/:spaceId',
      name: 'moment',
      pageBuilder: (context, state) {
        final spaceId = state.pathParameters['spaceId'] ?? '';
        return _slideTransition(state, PlanMomentScreen(spaceId: spaceId));
      },
    ),

    // Create Memory - Seal a new memory (moment passed via extra for linked)
    GoRoute(
      path: '/memory/:spaceId/create',
      name: 'createMemory',
      pageBuilder: (context, state) {
        final spaceId = state.pathParameters['spaceId'] ?? '';
        final moment = state.extra as Moment?;
        return _slideTransition(
          state,
          CreateMemoryScreen(spaceId: spaceId, moment: moment),
        );
      },
    ),

    // Memory Detail - View memory (loaded by ID, opens detail sheet)
    GoRoute(
      path: '/memory/:spaceId/:memoryId',
      name: 'memoryDetail',
      pageBuilder: (context, state) {
        final spaceId = state.pathParameters['spaceId'] ?? '';
        final memoryId = state.pathParameters['memoryId'] ?? '';
        return _fadeTransition(
          state,
          MemoryDetailPage(spaceId: spaceId, memoryId: memoryId),
        );
      },
    ),

    // Edit Memory - Edit existing memory (memory passed via extra)
    GoRoute(
      path: '/memory/:spaceId/:memoryId/edit',
      name: 'editMemory',
      pageBuilder: (context, state) {
        final spaceId = state.pathParameters['spaceId'] ?? '';
        final memory = state.extra as Memory;
        return _slideUpTransition(
          state,
          EditMemoryScreen(spaceId: spaceId, memory: memory),
        );
      },
    ),

    // Edit Moment - Edit existing moment (moment passed via extra)
    GoRoute(
      path: '/moment/:spaceId/edit',
      name: 'editMoment',
      pageBuilder: (context, state) {
        final spaceId = state.pathParameters['spaceId'] ?? '';
        final moment = state.extra as Moment;
        final focusParam = state.uri.queryParameters['focus'] ?? 'none';
        final initialFocus = switch (focusParam) {
          'date' => EditMomentFocus.date,
          'time' => EditMomentFocus.time,
          'notes' => EditMomentFocus.notes,
          _ => EditMomentFocus.none,
        };
        return _slideUpTransition(
          state,
          EditMomentScreen(
            spaceId: spaceId,
            moment: moment,
            initialFocus: initialFocus,
          ),
        );
      },
    ),
  ];

  // ---------------------------------------------------------------------------
  // Route Guards
  // ---------------------------------------------------------------------------

  /// Handles authentication-based redirects.
  static Future<String?> _handleRedirect(
    BuildContext context,
    GoRouterState state,
  ) async {
    final isLoggedIn = _authService.currentUser != null;
    final currentPath = state.matchedLocation;
    final uri = state.uri;

    // Allow join route for everyone - handles auth internally
    if (currentPath.startsWith('/join')) {
      return null;
    }

    // Allow splash to handle its own routing logic
    if (currentPath == '/') {
      return null;
    }

    // Check if on auth route
    final isAuthRoute = currentPath == '/login';

    // Redirect unauthenticated users to login (preserve invite code if present)
    if (!isLoggedIn && !isAuthRoute) {
      final inviteCode = uri.queryParameters['code'];
      if (inviteCode != null && inviteCode.isNotEmpty) {
        return '/join?code=$inviteCode';
      }
      return '/login';
    }

    // Redirect authenticated users away from auth routes
    if (isLoggedIn && isAuthRoute) {
      final userId = _authService.currentUser!.uid;
      final spaceId = await _firestoreService.getUserSpaceId(userId);
      return spaceId != null ? '/dashboard/$spaceId' : '/onboarding';
    }

    // Validate dashboard access - user must be a member of the space
    if (isLoggedIn && currentPath.startsWith('/dashboard/')) {
      final userId = _authService.currentUser!.uid;
      final requestedSpaceId = state.pathParameters['spaceId'];

      if (requestedSpaceId != null && requestedSpaceId.isNotEmpty) {
        // Get the user's actual space ID
        final userSpaceId = await _firestoreService.getUserSpaceId(userId);

        // If user has no space, redirect to onboarding
        if (userSpaceId == null) {
          return '/onboarding';
        }

        // If user is trying to access a different space, redirect to their space
        if (userSpaceId != requestedSpaceId) {
          return '/dashboard/$userSpaceId';
        }
      }
    }

    return null; // No redirect needed
  }

  // ---------------------------------------------------------------------------
  // Page Transitions
  // ---------------------------------------------------------------------------

  /// Creates a fade transition for the given page.
  static CustomTransitionPage<void> _fadeTransition(
    GoRouterState state,
    Widget child,
  ) {
    return CustomTransitionPage(
      key: state.pageKey,
      child: child,
      transitionsBuilder: (context, animation, secondaryAnimation, child) {
        return FadeTransition(opacity: animation, child: child);
      },
    );
  }

  /// Creates a horizontal slide transition for the given page.
  static CustomTransitionPage<void> _slideTransition(
    GoRouterState state,
    Widget child,
  ) {
    return CustomTransitionPage(
      key: state.pageKey,
      child: child,
      transitionsBuilder: (context, animation, secondaryAnimation, child) {
        return SlideTransition(
          position:
              Tween<Offset>(
                begin: const Offset(1.0, 0.0),
                end: Offset.zero,
              ).animate(
                CurvedAnimation(parent: animation, curve: Curves.easeInOut),
              ),
          child: child,
        );
      },
    );
  }

  /// Creates a vertical slide-up transition (for modal-style screens).
  static CustomTransitionPage<void> _slideUpTransition(
    GoRouterState state,
    Widget child,
  ) {
    return CustomTransitionPage(
      key: state.pageKey,
      child: child,
      transitionsBuilder: (context, animation, secondaryAnimation, child) {
        return SlideTransition(
          position:
              Tween<Offset>(
                begin: const Offset(0.0, 1.0),
                end: Offset.zero,
              ).animate(
                CurvedAnimation(parent: animation, curve: Curves.easeOutCubic),
              ),
          child: child,
        );
      },
    );
  }

  // ---------------------------------------------------------------------------
  // Error Handling
  // ---------------------------------------------------------------------------

  /// Builds the error page for invalid routes.
  static MaterialPage<void> _errorPageBuilder(
    BuildContext context,
    GoRouterState state,
  ) {
    return MaterialPage(
      key: state.pageKey,
      child: Scaffold(
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.error_outline_rounded,
                size: 64,
                color: Theme.of(context).colorScheme.error,
              ),
              const SizedBox(height: 16),
              Text(
                '404',
                style: Theme.of(
                  context,
                ).textTheme.displaySmall?.copyWith(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              Text(
                'Page not found',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 24),
              FilledButton.icon(
                onPressed: () => context.go('/'),
                icon: const Icon(Icons.home_rounded),
                label: const Text('Go Home'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
