/// Main shell screen with stretchy tab navigation for Couple Space app.
library;

import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';

import '../models/pulse_config.dart';
import '../services/auth_service.dart';
import '../services/firestore_service.dart';
import '../services/notification_service.dart';
import 'dashboard/dashboard_tab.dart';
import 'memories/memories_tab.dart';
import 'moments/moments_tab.dart';
import 'settings/integrations_sheet.dart';

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
      MomentsTab(spaceId: widget.spaceId),
      MemoriesTab(spaceId: widget.spaceId),
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
          _selectedTab == 1 ? 'Moments' : (_spaceName ?? 'Home'),
          style: GoogleFonts.outfit(
            fontWeight: FontWeight.w700,
            fontSize: 22,
            color: _lightText,
          ),
        ),
        centerTitle: true,
        actions: [
          if (_selectedTab == 0)
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
            )
          else if (_selectedTab == 1)
            Container(
              margin: const EdgeInsets.only(right: 8),
              child: IconButton(
                icon: const Icon(
                  Icons.add_circle_rounded,
                  color: _refinedRed,
                ),
                tooltip: 'Plan a moment',
                onPressed: () => context.push('/moment/${widget.spaceId}'),
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

  /// 5 visual slots in the nav bar. Slots 0-1 map to tabs 0-1.
  /// Slots 2-4 all map to tab 2 (Coming Soon) as one wide region.
  static const _slotIcons = [
    Icons.space_dashboard_rounded,
    Icons.calendar_today_rounded,
    Icons.auto_stories_rounded,
    Icons.auto_stories_rounded,
    Icons.auto_stories_rounded,
  ];

  /// Maps a visual slot index to the logical tab index.
  static int _slotToTab(int slot) => slot >= 2 ? 2 : slot;

  Widget _buildNavBar() {
    const slotCount = 5;
    const height = 48.0;
    const gap = 4.0;

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
        child: LayoutBuilder(
          builder: (context, constraints) {
            final totalWidth = constraints.maxWidth;
            final slotWidth =
                (totalWidth - gap * (slotCount - 1)) / slotCount;

            int slotForX(double x) {
              for (int i = 0; i < slotCount; i++) {
                final left = i * (slotWidth + gap);
                if (x < left + slotWidth + gap / 2) return i;
              }
              return slotCount - 1;
            }

            // Compute highlight position. Tabs 0 and 1 span 1 slot each.
            // Tab 2 spans slots 2-4 (the full remaining width).
            double leftForTab(int tab) {
              if (tab <= 1) return tab * (slotWidth + gap);
              return 2 * (slotWidth + gap);
            }

            double widthForTab(int tab) {
              if (tab <= 1) return slotWidth;
              return slotWidth * 3 + gap * 2;
            }

            final isDragging = _dragPosition != null;
            double highlightLeft;
            double highlightWidth;

            if (isDragging) {
              final dragSlot = slotForX(_dragPosition!);
              final dragTab = _slotToTab(dragSlot);
              highlightLeft = leftForTab(dragTab);
              highlightWidth = widthForTab(dragTab);
              final tabCenter = highlightLeft + highlightWidth / 2;
              if (_dragPosition! < tabCenter) {
                final newLeft =
                    _dragPosition!.clamp(0.0, highlightLeft);
                highlightWidth += (highlightLeft - newLeft);
                highlightLeft = newLeft;
              } else {
                final newRight = _dragPosition!.clamp(
                  highlightLeft + highlightWidth,
                  totalWidth,
                );
                highlightWidth = newRight - highlightLeft;
              }
            } else {
              highlightLeft = leftForTab(_selectedTab);
              highlightWidth = widthForTab(_selectedTab);
            }

            return GestureDetector(
              onHorizontalDragStart: (d) {
                setState(
                  () => _dragPosition =
                      d.localPosition.dx.clamp(0, totalWidth),
                );
              },
              onHorizontalDragUpdate: (d) {
                final pos = d.localPosition.dx.clamp(0.0, totalWidth);
                setState(() => _dragPosition = pos);

                final newTab = _slotToTab(slotForX(pos));
                if (_selectedTab != newTab) {
                  HapticFeedback.selectionClick();
                  setState(() => _selectedTab = newTab);
                }
              },
              onHorizontalDragEnd: (_) {
                setState(() => _dragPosition = null);
              },
              onTapDown: (d) {
                final newTab = _slotToTab(slotForX(d.localPosition.dx));
                if (_selectedTab != newTab) {
                  HapticFeedback.selectionClick();
                  setState(() => _selectedTab = newTab);
                }
              },
              child: SizedBox(
                height: height,
                child: Stack(
                  children: [
                    AnimatedPositioned(
                      duration: Duration(
                        milliseconds: isDragging ? 80 : 350,
                      ),
                      curve:
                          isDragging ? Curves.easeOut : Curves.easeOutCubic,
                      left: highlightLeft,
                      top: 0,
                      bottom: 0,
                      width: highlightWidth,
                      child: AnimatedContainer(
                        duration: Duration(
                          milliseconds: isDragging ? 80 : 300,
                        ),
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
                    Row(
                      children: List.generate(slotCount, (i) {
                        final tab = _slotToTab(i);
                        return Expanded(
                          child: Padding(
                            padding: EdgeInsets.only(
                              left: i == 0 ? 0 : gap / 2,
                              right:
                                  i == slotCount - 1 ? 0 : gap / 2,
                            ),
                            child: Center(
                              child: Icon(
                                _slotIcons[i],
                                color: _selectedTab == tab
                                    ? _pureBlack
                                    : _dimText,
                                size: 20,
                              ),
                            ),
                          ),
                        );
                      }),
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
            // Pulse attributes
            _buildSettingsItem(
              icon: Icons.tune_rounded,
              title: 'Pulse attributes',
              onTap: () {
                Navigator.pop(context);
                _showPulseAttributePicker(context);
              },
            ),
            const SizedBox(height: 12),
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
            // Integrations
            _buildSettingsItem(
              icon: Icons.extension_rounded,
              title: 'Integrations',
              onTap: () {
                Navigator.pop(context);
                _showIntegrations(context);
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

  void _showIntegrations(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: _darkGlass,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) => IntegrationsSheet(
        userId: _authService.currentUser!.uid,
        spaceName: _spaceName ?? 'Cocoon',
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

  void _showPulseAttributePicker(BuildContext context) {
    final userId = _authService.currentUser?.uid;
    if (userId == null) return;

    showModalBottomSheet(
      context: context,
      backgroundColor: _darkGlass,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => _PulseAttributePickerSheet(
        spaceId: widget.spaceId,
        userId: userId,
        firestoreService: _firestoreService,
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

/// Pulse attribute picker — each user picks up to 3 of 5.
class _PulseAttributePickerSheet extends StatefulWidget {
  const _PulseAttributePickerSheet({
    required this.spaceId,
    required this.userId,
    required this.firestoreService,
  });

  final String spaceId;
  final String userId;
  final FirestoreService firestoreService;

  @override
  State<_PulseAttributePickerSheet> createState() =>
      _PulseAttributePickerSheetState();
}

class _PulseAttributePickerSheetState
    extends State<_PulseAttributePickerSheet> {
  PulseConfig? _config;
  List<String> _myPicks = [];
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _loadConfig();
  }

  Future<void> _loadConfig() async {
    final config =
        await widget.firestoreService.getPulseConfig(widget.spaceId);
    if (!mounted) return;
    setState(() {
      _config = config;
      _myPicks = List.from(
        config.userPicks[widget.userId] ?? ['connection', 'intimacy', 'peace'],
      );
    });
  }

  Future<void> _save() async {
    if (_myPicks.isEmpty || _myPicks.length > 3) return;
    setState(() => _isSaving = true);
    try {
      await widget.firestoreService.updateUserPicks(
        spaceId: widget.spaceId,
        userId: widget.userId,
        picks: _myPicks,
      );
      if (mounted) Navigator.pop(context);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to save: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  void _toggle(String attrId) {
    setState(() {
      if (_myPicks.contains(attrId)) {
        if (_myPicks.length > 1) _myPicks.remove(attrId);
      } else {
        if (_myPicks.length < 3) _myPicks.add(attrId);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_config == null) {
      return const SizedBox(
        height: 200,
        child: Center(
          child: CircularProgressIndicator(color: _refinedRed),
        ),
      );
    }

    // Get partner's picks for display
    final partnerPicks = _config!.userPicks.entries
        .where((e) => e.key != widget.userId)
        .expand((e) => e.value)
        .toSet();

    return Padding(
      padding: EdgeInsets.fromLTRB(
        24,
        16,
        24,
        MediaQuery.of(context).viewInsets.bottom + 24,
      ),
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
          const SizedBox(height: 20),
          Text(
            'Pulse Attributes',
            style: GoogleFonts.outfit(
              fontSize: 20,
              fontWeight: FontWeight.w600,
              color: _lightText,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Pick up to 3 attributes that matter to you',
            style: GoogleFonts.inter(fontSize: 13, color: _dimText),
          ),
          const SizedBox(height: 24),

          // Attribute pills
          Wrap(
            spacing: 12,
            runSpacing: 12,
            alignment: WrapAlignment.center,
            children: [
              for (final attr in PulseAttribute.values)
                _buildPill(attr, partnerPicks.contains(attr.id)),
            ],
          ),

          const SizedBox(height: 28),
          // Save button — matches SlideToAction style
          GestureDetector(
            onTap: _isSaving ? null : _save,
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 16),
              decoration: BoxDecoration(
                color: _refinedRed,
                borderRadius: BorderRadius.circular(16),
              ),
              child: Center(
                child: _isSaving
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          color: Colors.white,
                          strokeWidth: 2,
                        ),
                      )
                    : Text(
                        'Save (${_myPicks.length}/3)',
                        style: GoogleFonts.outfit(
                          color: Colors.white,
                          fontWeight: FontWeight.w600,
                          fontSize: 16,
                        ),
                      ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPill(PulseAttribute attr, bool partnerPicked) {
    final isSelected = _myPicks.contains(attr.id);
    final canSelect = _myPicks.length < 3 || isSelected;
    final pillColor = isSelected ? _refinedRed : _dimText;

    return GestureDetector(
      onTap: canSelect
          ? () {
              HapticFeedback.selectionClick();
              _toggle(attr.id);
            }
          : null,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
        decoration: BoxDecoration(
          color: isSelected
              ? _refinedRed.withValues(alpha: 0.12)
              : _cardVariant,
          borderRadius: BorderRadius.circular(40),
          border: Border.all(
            color: isSelected
                ? _refinedRed.withValues(alpha: 0.5)
                : _dimText.withValues(alpha: 0.15),
            width: 1.5,
          ),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: _refinedRed.withValues(alpha: 0.25),
                    blurRadius: 16,
                    spreadRadius: 0,
                  ),
                ]
              : null,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Use the same SVG/icon as check-in bars
            attr.buildIcon(color: pillColor, size: 18),
            const SizedBox(width: 10),
            Text(
              attr.displayName,
              style: GoogleFonts.outfit(
                color: isSelected ? _lightText : _dimText,
                fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
                fontSize: 15,
              ),
            ),
            if (partnerPicked) ...[
              const SizedBox(width: 8),
              Container(
                width: 6,
                height: 6,
                decoration: BoxDecoration(
                  color: _refinedRed.withValues(alpha: 0.8),
                  shape: BoxShape.circle,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

