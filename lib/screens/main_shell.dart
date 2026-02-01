/// Main shell screen with bottom navigation for Couple Space app.
///
/// Wraps all main screens (Dashboard, Calendar, Check-ins, Agreements)
/// with a premium neumorphic bottom navigation bar using IndexedStack for state preservation.
library;

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../services/auth_service.dart';
import 'agreements_tab.dart';
import 'calendar_tab.dart';
import 'checkins_tab.dart';
import 'dashboard_tab.dart';

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
  int _currentIndex = 0;

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
          style: const TextStyle(
            fontWeight: FontWeight.w700,
            fontSize: 20,
            color: _lightText,
          ),
        ),
        centerTitle: true,
        actions: [
          Container(
            margin: const EdgeInsets.only(right: 8),
            child: IconButton(
              icon: const Icon(Icons.logout_rounded, color: _dimText),
              tooltip: 'Sign out',
              onPressed: _signOut,
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
              _buildNavItem(0, Icons.home_outlined, Icons.home_rounded, 'Home'),
              _buildNavItem(1, Icons.event_outlined, Icons.event_rounded, 'Events'),
              _buildNavItem(2, Icons.favorite_outline, Icons.favorite_rounded, 'Check-ins'),
              _buildNavItem(3, Icons.handshake_outlined, Icons.handshake_rounded, 'Agreements'),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildNavItem(int index, IconData icon, IconData selectedIcon, String label) {
    final isSelected = _currentIndex == index;

    return GestureDetector(
      onTap: () => setState(() => _currentIndex = index),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        decoration: BoxDecoration(
          color: isSelected ? _refinedRed.withValues(alpha: 0.15) : Colors.transparent,
          borderRadius: BorderRadius.circular(16),
          border: isSelected
              ? Border.all(color: _refinedRed.withValues(alpha: 0.3))
              : null,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              isSelected ? selectedIcon : icon,
              color: isSelected ? _refinedRed : _dimText,
              size: 24,
            ),
            const SizedBox(height: 4),
            Text(
              label,
              style: TextStyle(
                fontSize: 12,
                fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
                color: isSelected ? _refinedRed : _dimText,
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _getTitle() {
    return switch (_currentIndex) {
      0 => 'Home',
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
          onPressed: () => _showAddEventSheet(context),
        ),
      1 => _buildPremiumFab(
          icon: Icons.add_rounded,
          label: 'Add event',
          onPressed: () => _showAddEventSheet(context),
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

  void _showAddEventSheet(BuildContext context) {
    // Get the dashboard tab and call its method
    final dashboardTab = _tabs[0] as DashboardTab;
    dashboardTab.showCreateEventSheet(context, widget.spaceId);
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
