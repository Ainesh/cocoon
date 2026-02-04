/// Main shell screen with bottom navigation for Couple Space app.
///
/// Wraps all main screens (Dashboard, Calendar, Check-ins, Agreements)
/// with a premium neumorphic bottom navigation bar using IndexedStack for state preservation.
library;

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';

import '../services/auth_service.dart';
import '../services/firestore_service.dart';
import 'agreements_tab.dart';
import 'calendar_tab.dart';
import 'checkins_tab.dart';
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
  const MainShell({
    super.key,
    required this.spaceId,
  });

  final String spaceId;

  @override
  State<MainShell> createState() => _MainShellState();
}

class _MainShellState extends State<MainShell> {
  final _authService = AuthService();
  final _firestoreService = FirestoreService();
  int _currentIndex = 0;
  String? _spaceName;

  late final List<Widget> _tabs;

  @override
  void initState() {
    super.initState();
    _tabs = [
      DashboardTab(spaceId: widget.spaceId),
      CalendarTab(spaceId: widget.spaceId),
      CheckInsTab(spaceId: widget.spaceId),
      AgreementsTab(spaceId: widget.spaceId),
    ];
    _loadSpaceName();
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
          _getTitle(),
          style: GoogleFonts.outfit(
            fontWeight: _currentIndex == 0 ? FontWeight.w700 : FontWeight.w500,
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
      body: IndexedStack(
        index: _currentIndex,
        children: _tabs,
      ),
      floatingActionButton: _buildFab(),
      bottomNavigationBar: _buildBottomNav(),
    );
  }

  Widget _buildBottomNav() {
    return Container(
      decoration: BoxDecoration(
        color: _darkGlass,
        border: Border(
          top: BorderSide(
            color: _refinedRed.withValues(alpha: 0.1),
            width: 1,
          ),
        ),
        boxShadow: [
          BoxShadow(
            color: _refinedRed.withValues(alpha: 0.1),
            offset: const Offset(0, -4),
            blurRadius: 20,
          ),
        ],
      ),
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _buildNavItem(0, Icons.home_outlined, Icons.home_rounded),
              _buildNavItem(1, Icons.event_outlined, Icons.event_rounded),
              _buildNavItem(2, Icons.edit_note_outlined, Icons.edit_note_rounded),
              _buildNavItem(3, Icons.handshake_outlined, Icons.handshake_rounded),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildNavItem(int index, IconData icon, IconData selectedIcon) {
    final isSelected = _currentIndex == index;

    return GestureDetector(
      onTap: () => setState(() => _currentIndex = index),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
        decoration: BoxDecoration(
          color: isSelected ? _refinedRed.withValues(alpha: 0.15) : Colors.transparent,
          borderRadius: BorderRadius.circular(16),
          border: isSelected
              ? Border.all(color: _refinedRed.withValues(alpha: 0.3))
              : null,
        ),
        child: Icon(
          isSelected ? selectedIcon : icon,
          color: isSelected ? _refinedRed : _dimText,
          size: 26,
        ),
      ),
    );
  }

  String _getTitle() {
    return switch (_currentIndex) {
      0 => _spaceName ?? 'Home',
      1 => 'Events',
      2 => 'Check-ins',
      3 => 'Agreements',
      _ => 'Home',
    };
  }

  Widget? _buildFab() {
    return switch (_currentIndex) {
      0 => _buildPremiumFab(
          icon: Icons.add_rounded,
          label: 'Add event',
          onPressed: () => _showAddMoment(context),
        ),
      1 => _buildPremiumFab(
          icon: Icons.add_rounded,
          label: 'Add event',
          onPressed: () => _showAddMoment(context),
        ),
      2 => _buildPremiumFab(
          icon: Icons.edit_note_rounded,
          label: 'Check-in now',
          onPressed: () => context.push('/checkin/${widget.spaceId}'),
        ),
      3 => _buildPremiumFab(
          icon: Icons.add_rounded,
          label: 'Add agreement',
          onPressed: () {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Agreements coming soon!'),
                backgroundColor: _refinedRed,
                behavior: SnackBarBehavior.floating,
              ),
            );
          },
        ),
      _ => null,
    };
  }

  Widget _buildPremiumFab({
    required IconData icon,
    required String label,
    required VoidCallback onPressed,
  }) {
    return _PremiumFab(
      icon: icon,
      label: label,
      onPressed: onPressed,
    );
  }

  void _showAddMoment(BuildContext context) {
    // Navigate to Plan a Moment screen
    context.push('/moment/${widget.spaceId}');
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
            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
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
                await _firestoreService.updateSpaceName(widget.spaceId, newName);
                if (mounted) {
                  setState(() => _spaceName = newName);
                }
              }
              if (ctx.mounted) Navigator.pop(ctx);
            },
            style: FilledButton.styleFrom(
              backgroundColor: _refinedRed,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
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

/// Premium FAB with micro-interactions.
class _PremiumFab extends StatefulWidget {
  const _PremiumFab({
    required this.icon,
    required this.label,
    required this.onPressed,
  });

  final IconData icon;
  final String label;
  final VoidCallback onPressed;

  @override
  State<_PremiumFab> createState() => _PremiumFabState();
}

class _PremiumFabState extends State<_PremiumFab> {
  bool _isPressed = false;
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    final isActive = _isPressed || _isHovered;

    return MouseRegion(
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      child: GestureDetector(
        onTapDown: (_) => setState(() => _isPressed = true),
        onTapUp: (_) {
          setState(() => _isPressed = false);
          widget.onPressed();
        },
        onTapCancel: () => setState(() => _isPressed = false),
        child: AnimatedScale(
          scale: _isPressed ? 0.95 : 1.0,
          duration: const Duration(milliseconds: 100),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 150),
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
            decoration: BoxDecoration(
              color: _refinedRed,
              borderRadius: BorderRadius.circular(20),
              boxShadow: [
                BoxShadow(
                  color: _refinedRed.withValues(alpha: isActive ? 0.5 : 0.3),
                  offset: Offset(0, isActive ? 8 : 4),
                  blurRadius: isActive ? 24 : 16,
                  spreadRadius: isActive ? 0 : -2,
                ),
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.3),
                  offset: const Offset(0, 2),
                  blurRadius: 8,
                ),
              ],
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(widget.icon, color: Colors.white, size: 20),
                const SizedBox(width: 8),
                Text(
                  widget.label,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
