/// Main shell screen with stretchy tab navigation for Couple Space app.
library;

import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';

import '../services/auth_service.dart';
import '../services/firestore_service.dart';
import '../services/notification_service.dart';
import 'dashboard/dashboard_tab.dart';

// Theme constants for premium styling
const _refinedRed = Color(0xFFFF4444);
const _lightText = Color(0xFFF5F5F5);
const _dimText = Color(0xFF9CA3AF);
const _cardVariant = Color(0xFF2A2A2A);
const _darkGlass = Color(0xFF1E1E1E);
const _pureBlack = Color(0xFF0A0A0A);

/// Main shell with bottom navigation.
class MainShell extends StatefulWidget {
  const MainShell({super.key, required this.spaceId});

  final String spaceId;

  @override
  State<MainShell> createState() => _MainShellState();
}

class _MainShellState extends State<MainShell> {
  final _authService = AuthService();
  final _firestoreService = FirestoreService();
  String? _spaceName;
  int _selectedTab = 0;
  double? _dragPosition;
  StreamSubscription<NotificationNavigation>? _notificationSub;
  final _dashboardKey = GlobalKey<DashboardTabState>();

  late final List<Widget> _tabs;

  @override
  void initState() {
    super.initState();
    _tabs = [
      DashboardTab(key: _dashboardKey, spaceId: widget.spaceId),
      const _ComingSoonPage(),
    ];
    _loadSpaceName();
    _registerFcmToken();
    _listenForNotificationTaps();
  }

  @override
  void dispose() {
    _notificationSub?.cancel();
    super.dispose();
  }

  /// Register FCM token for push notifications.
  Future<void> _registerFcmToken() async {
    try {
      final userId = _authService.currentUser?.uid;
      if (userId == null) return;

      final notificationService = NotificationService.instance;
      final token = notificationService.fcmToken;

      if (token != null) {
        await _firestoreService.storeFcmToken(
          userId: userId,
          token: token,
          deviceInfo: notificationService.getDeviceInfo(),
        );
        debugPrint('FCM token registered for user: $userId');
      }
    } catch (e) {
      debugPrint('Error registering FCM token: $e');
    }
  }

  /// Listen for notification taps and navigate to the relevant screen.
  void _listenForNotificationTaps() {
    final notifService = NotificationService.instance;

    // Listen for live notification taps (foreground + some background cases)
    _notificationSub = notifService.onNotificationTap.listen((nav) {
      if (!mounted) return;
      debugPrint('Notification navigation (stream): $nav');
      // Consume pending to prevent double navigation
      notifService.consumePendingNavigation();
      _handleNotificationNavigation(nav);
    });

    // Check for pending navigation (background resume / terminated launch)
    // Delayed to ensure widget tree + GoRouter are fully ready
    Future.delayed(const Duration(milliseconds: 800), () {
      if (!mounted) return;
      final pending = notifService.consumePendingNavigation();
      if (pending != null) {
        debugPrint('Notification navigation (pending): $pending');
        _handleNotificationNavigation(pending);
      }
    });
  }

  /// Navigate based on notification data.
  void _handleNotificationNavigation(NotificationNavigation nav) {
    final spaceId = nav.spaceId.isNotEmpty ? nav.spaceId : widget.spaceId;
    debugPrint(
      'Navigating for notification: type=${nav.type}, spaceId=$spaceId',
    );

    if (nav.isCheckIn) {
      // Check-in notification → open check-in screen
      context.push('/checkin/$spaceId');
    } else if (nav.isMoment && nav.entityId.isNotEmpty) {
      // Moment notification → switch to dashboard tab and open moment details
      if (_selectedTab != 0) {
        setState(() => _selectedTab = 0);
      }
      // Small delay to ensure dashboard is visible before showing sheet
      Future.delayed(const Duration(milliseconds: 300), () {
        if (!mounted) return;
        _dashboardKey.currentState?.openEntityById(
          entityType: nav.entityType,
          entityId: nav.entityId,
        );
      });
    } else {
      // Default: go to dashboard
      if (_selectedTab != 0) {
        setState(() => _selectedTab = 0);
      }
    }
  }

  Future<void> _loadSpaceName() async {
    try {
      final space = await _firestoreService.getSpaceWithMembers(widget.spaceId);
      if (mounted) {
        setState(() {
          _spaceName = space?['name'] as String?;
        });
      }
    } catch (e) {
      // Use default name
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _pureBlack,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: Text(
          _spaceName ?? 'Home',
          style: GoogleFonts.outfit(
            fontWeight: FontWeight.w700,
            fontSize: 22,
            color: _lightText,
          ),
        ),
        centerTitle: true,
        actions: [
          Container(
            margin: const EdgeInsets.only(right: 8),
            child: IconButton(
              icon: const Icon(Icons.settings_rounded, color: _dimText),
              tooltip: 'Settings',
              onPressed: () => _showSettings(context),
              style: IconButton.styleFrom(
                backgroundColor: _cardVariant,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
          ),
        ],
      ),
      body: IndexedStack(index: _selectedTab, children: _tabs),
      bottomNavigationBar: _buildNavBar(),
    );
  }

  Widget _buildNavBar() {
    const height = 48.0;

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
        child: LayoutBuilder(
          builder: (context, constraints) {
            final totalWidth = constraints.maxWidth;
            const dashWidth = 52.0;
            final comingSoonWidth = totalWidth - dashWidth - 8;

            final isDragging = _dragPosition != null;
            double highlightLeft;
            double highlightWidth;

            if (isDragging) {
              final dragX = _dragPosition!;
              final overSecond = dragX > dashWidth + 4;
              if (overSecond) {
                highlightLeft = dashWidth + 8;
                highlightWidth = comingSoonWidth;
              } else {
                highlightLeft = 0;
                highlightWidth = dashWidth;
              }
              // Stretch toward drag
              final tabCenter = highlightLeft + highlightWidth / 2;
              if (dragX < tabCenter) {
                final newLeft = dragX.clamp(0.0, highlightLeft);
                highlightWidth += (highlightLeft - newLeft);
                highlightLeft = newLeft;
              } else {
                final newRight = dragX.clamp(
                  highlightLeft + highlightWidth,
                  totalWidth,
                );
                highlightWidth = newRight - highlightLeft;
              }
            } else {
              if (_selectedTab == 0) {
                highlightLeft = 0;
                highlightWidth = dashWidth;
              } else {
                highlightLeft = dashWidth + 8;
                highlightWidth = comingSoonWidth;
              }
            }

            return GestureDetector(
              onHorizontalDragStart: (d) {
                setState(
                  () => _dragPosition = d.localPosition.dx.clamp(0, totalWidth),
                );
              },
              onHorizontalDragUpdate: (d) {
                final pos = d.localPosition.dx.clamp(0.0, totalWidth);
                setState(() => _dragPosition = pos);

                final newTab = pos > dashWidth + 4 ? 1 : 0;
                if (_selectedTab != newTab) {
                  HapticFeedback.selectionClick();
                  setState(() => _selectedTab = newTab);
                }
              },
              onHorizontalDragEnd: (_) {
                setState(() => _dragPosition = null);
              },
              onTapDown: (d) {
                final newTab = d.localPosition.dx > dashWidth + 4 ? 1 : 0;
                if (_selectedTab != newTab) {
                  HapticFeedback.selectionClick();
                  setState(() => _selectedTab = newTab);
                }
              },
              child: SizedBox(
                height: height,
                child: Stack(
                  children: [
                    // Stretchy highlight — solid red, same as time selector
                    AnimatedPositioned(
                      duration: Duration(milliseconds: isDragging ? 80 : 350),
                      curve: isDragging ? Curves.easeOut : Curves.easeOutCubic,
                      left: highlightLeft,
                      top: 0,
                      bottom: 0,
                      width: highlightWidth,
                      child: AnimatedContainer(
                        duration: Duration(milliseconds: isDragging ? 80 : 300),
                        curve: isDragging
                            ? Curves.easeOut
                            : Curves.easeOutCubic,
                        decoration: BoxDecoration(
                          color: _refinedRed,
                          borderRadius: BorderRadius.circular(14),
                          boxShadow: [
                            BoxShadow(
                              color: _refinedRed.withValues(alpha: 0.4),
                              blurRadius: 12,
                            ),
                          ],
                        ),
                      ),
                    ),
                    // Tab labels
                    Row(
                      children: [
                        // Dashboard icon
                        SizedBox(
                          width: dashWidth,
                          child: Center(
                            child: Icon(
                              Icons.space_dashboard_rounded,
                              color: _selectedTab == 0 ? _pureBlack : _dimText,
                              size: 22,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        // Coming Soon
                        Expanded(
                          child: Center(
                            child: Icon(
                              Icons.hardware_rounded,
                              color: _selectedTab == 1 ? _pureBlack : _dimText,
                              size: 22,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  void _showSettings(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: _darkGlass,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) => Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Handle
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: _dimText.withValues(alpha: 0.5),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 24),
            // Settings title
            Text(
              'Settings',
              style: GoogleFonts.outfit(
                fontSize: 20,
                fontWeight: FontWeight.w600,
                color: _lightText,
              ),
            ),
            const SizedBox(height: 24),
            // Change space name
            _buildSettingsItem(
              icon: Icons.edit_rounded,
              title: 'Change space name',
              onTap: () {
                Navigator.pop(context);
                _showChangeSpaceNameDialog(context);
              },
            ),
            const SizedBox(height: 12),
            // Logout
            _buildSettingsItem(
              icon: Icons.logout_rounded,
              title: 'Sign out',
              isDestructive: true,
              onTap: () {
                Navigator.pop(context);
                _signOut();
              },
            ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }

  Widget _buildSettingsItem({
    required IconData icon,
    required String title,
    required VoidCallback onTap,
    bool isDestructive = false,
  }) {
    final color = isDestructive ? Colors.red.shade400 : _lightText;
    final iconColor = isDestructive ? Colors.red.shade400 : _refinedRed;

    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: _cardVariant,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Row(
          children: [
            Icon(icon, color: iconColor, size: 22),
            const SizedBox(width: 16),
            Expanded(
              child: Text(
                title,
                style: GoogleFonts.inter(
                  color: color,
                  fontSize: 15,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
            Icon(Icons.chevron_right_rounded, color: _dimText, size: 20),
          ],
        ),
      ),
    );
  }

  void _showChangeSpaceNameDialog(BuildContext context) {
    final controller = TextEditingController(text: _spaceName ?? '');

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: _darkGlass,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text(
          'Change Space Name',
          style: GoogleFonts.outfit(
            color: _lightText,
            fontWeight: FontWeight.w600,
          ),
        ),
        content: TextField(
          controller: controller,
          autofocus: true,
          style: TextStyle(color: _lightText),
          decoration: InputDecoration(
            hintText: 'Enter new name',
            hintStyle: TextStyle(color: _dimText),
            filled: true,
            fillColor: _cardVariant,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide.none,
            ),
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 16,
              vertical: 14,
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text('Cancel', style: TextStyle(color: _dimText)),
          ),
          FilledButton(
            onPressed: () async {
              final newName = controller.text.trim();
              if (newName.isNotEmpty) {
                await _firestoreService.updateSpaceName(
                  widget.spaceId,
                  newName,
                );
                if (mounted) {
                  setState(() => _spaceName = newName);
                }
              }
              if (ctx.mounted) Navigator.pop(ctx);
            },
            style: FilledButton.styleFrom(
              backgroundColor: _refinedRed,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }

  Future<void> _signOut() async {
    await _authService.signOut();
    if (mounted) context.go('/login');
  }
}

/// Coming Soon placeholder page.
class _ComingSoonPage extends StatelessWidget {
  const _ComingSoonPage();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 40),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.hardware_rounded,
              color: _refinedRed.withValues(alpha: 0.6),
              size: 48,
            ),
            const SizedBox(height: 20),
            Text(
              'More features are\non the way',
              textAlign: TextAlign.center,
              style: GoogleFonts.outfit(
                color: _lightText,
                fontSize: 22,
                fontWeight: FontWeight.w600,
                height: 1.3,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              'The team is working on new features to help you grow together. Look out for updates!',
              textAlign: TextAlign.center,
              style: GoogleFonts.inter(
                color: _dimText,
                fontSize: 14,
                height: 1.5,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
