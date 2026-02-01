/// Avatar selection widget for Couple Space app.
///
/// Provides a premium neumorphic UI for selecting an avatar and color theme.
library;

import 'package:flutter/material.dart';

import '../models/avatar_data.dart';

// Theme constants for premium styling
const _refinedRed = Color(0xFFFF4444);
const _lightText = Color(0xFFF5F5F5);
const _bodyGray = Color(0xFFD1D5DB);
const _cardVariant = Color(0xFF2A2A2A);
const _darkGlass = Color(0xFF1E1E1E);

/// A widget that allows users to select an avatar and color theme.
///
/// Displays:
/// - Large preview of the selected avatar (when one is selected)
/// - Row of color options
/// - Grid of available avatars
///
/// Usage:
/// ```dart
/// AvatarSelector(
///   selectedAvatar: _selectedAvatar,
///   selectedColor: _selectedColor,
///   onAvatarSelected: (avatar) => setState(() => _selectedAvatar = avatar),
///   onColorSelected: (color) => setState(() => _selectedColor = color),
/// )
/// ```
class AvatarSelector extends StatelessWidget {
  const AvatarSelector({
    super.key,
    required this.selectedAvatar,
    required this.selectedColor,
    required this.onAvatarSelected,
    required this.onColorSelected,
  });

  /// Currently selected avatar, or null if none selected.
  final AvatarData? selectedAvatar;

  /// Currently selected color theme.
  final AvatarColor selectedColor;

  /// Callback when an avatar is tapped.
  final ValueChanged<AvatarData> onAvatarSelected;

  /// Callback when a color is tapped.
  final ValueChanged<AvatarColor> onColorSelected;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Selected Avatar Preview
        if (selectedAvatar != null) _buildAvatarPreview(),

        // Color Picker
        _buildColorPicker(),
        const SizedBox(height: 24),

        // Avatar Grid
        _buildAvatarGrid(),
      ],
    );
  }

  /// Builds the large preview of the selected avatar.
  Widget _buildAvatarPreview() {
    return Column(
      children: [
        Center(
          child: Container(
            width: 100,
            height: 100,
            decoration: BoxDecoration(
              color: selectedColor.color.withValues(alpha: 0.15),
              shape: BoxShape.circle,
              border: Border.all(
                color: selectedColor.color,
                width: 3,
              ),
              boxShadow: [
                BoxShadow(
                  color: selectedColor.color.withValues(alpha: 0.3),
                  blurRadius: 20,
                  spreadRadius: 2,
                ),
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.4),
                  blurRadius: 16,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Icon(
              selectedAvatar!.icon,
              size: 56,
              color: selectedColor.color,
            ),
          ),
        ),
        const SizedBox(height: 8),
        Center(
          child: Text(
            selectedAvatar!.name,
            style: TextStyle(
              fontSize: 16,
              color: selectedColor.color,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
        const SizedBox(height: 20),
      ],
    );
  }

  /// Builds the horizontal color picker row.
  Widget _buildColorPicker() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Choose color',
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w500,
            color: _bodyGray,
          ),
        ),
        const SizedBox(height: 12),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: AvatarColor.values.map((color) {
            return _ColorOption(
              color: color,
              isSelected: color == selectedColor,
              onTap: () => onColorSelected(color),
            );
          }).toList(),
        ),
      ],
    );
  }

  /// Builds the avatar selection grid.
  Widget _buildAvatarGrid() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Choose avatar',
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w500,
            color: _bodyGray,
          ),
        ),
        const SizedBox(height: 12),
        GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 4,
            crossAxisSpacing: 12,
            mainAxisSpacing: 12,
          ),
          itemCount: PredefinedAvatars.all.length,
          itemBuilder: (context, index) {
            final avatar = PredefinedAvatars.all[index];
            return _AvatarOption(
              avatar: avatar,
              isSelected: selectedAvatar?.id == avatar.id,
              selectedColor: selectedColor,
              onTap: () => onAvatarSelected(avatar),
            );
          },
        ),
      ],
    );
  }
}

/// Color option button with micro-interactions.
class _ColorOption extends StatefulWidget {
  const _ColorOption({
    required this.color,
    required this.isSelected,
    required this.onTap,
  });

  final AvatarColor color;
  final bool isSelected;
  final VoidCallback onTap;

  @override
  State<_ColorOption> createState() => _ColorOptionState();
}

class _ColorOptionState extends State<_ColorOption> {
  bool _isPressed = false;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (_) => setState(() => _isPressed = true),
      onTapUp: (_) {
        setState(() => _isPressed = false);
        widget.onTap();
      },
      onTapCancel: () => setState(() => _isPressed = false),
      child: AnimatedScale(
        scale: _isPressed ? 0.9 : 1.0,
        duration: const Duration(milliseconds: 100),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          width: widget.isSelected ? 48 : 40,
          height: widget.isSelected ? 48 : 40,
          decoration: BoxDecoration(
            color: widget.color.color,
            shape: BoxShape.circle,
            border: Border.all(
              color: widget.isSelected ? _lightText : Colors.transparent,
              width: 3,
            ),
            boxShadow: widget.isSelected
                ? [
                    BoxShadow(
                      color: widget.color.color.withValues(alpha: 0.5),
                      blurRadius: 12,
                      spreadRadius: 2,
                    ),
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.3),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ]
                : [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.3),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ],
          ),
          child: widget.isSelected
              ? const Icon(Icons.check, color: Colors.white, size: 24)
              : null,
        ),
      ),
    );
  }
}

/// Avatar option tile with micro-interactions.
class _AvatarOption extends StatefulWidget {
  const _AvatarOption({
    required this.avatar,
    required this.isSelected,
    required this.selectedColor,
    required this.onTap,
  });

  final AvatarData avatar;
  final bool isSelected;
  final AvatarColor selectedColor;
  final VoidCallback onTap;

  @override
  State<_AvatarOption> createState() => _AvatarOptionState();
}

class _AvatarOptionState extends State<_AvatarOption> {
  bool _isPressed = false;
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    final isActive = _isPressed || _isHovered;
    final accentColor = widget.selectedColor.color;

    return MouseRegion(
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      child: GestureDetector(
        onTapDown: (_) => setState(() => _isPressed = true),
        onTapUp: (_) {
          setState(() => _isPressed = false);
          widget.onTap();
        },
        onTapCancel: () => setState(() => _isPressed = false),
        child: AnimatedScale(
          scale: _isPressed ? 0.95 : 1.0,
          duration: const Duration(milliseconds: 100),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            decoration: BoxDecoration(
              color: widget.isSelected
                  ? accentColor.withValues(alpha: 0.2)
                  : isActive
                      ? _cardVariant
                      : _darkGlass,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: widget.isSelected
                    ? accentColor
                    : isActive
                        ? _refinedRed.withValues(alpha: 0.3)
                        : _cardVariant,
                width: widget.isSelected ? 2.5 : 1,
              ),
              boxShadow: widget.isSelected
                  ? [
                      BoxShadow(
                        color: accentColor.withValues(alpha: 0.3),
                        blurRadius: 12,
                        spreadRadius: 0,
                      ),
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.3),
                        blurRadius: 8,
                        offset: const Offset(0, 2),
                      ),
                    ]
                  : isActive
                      ? [
                          BoxShadow(
                            color: _refinedRed.withValues(alpha: 0.15),
                            blurRadius: 12,
                          ),
                        ]
                      : null,
            ),
            child: Icon(
              widget.avatar.icon,
              size: 32,
              color: widget.isSelected ? accentColor : _bodyGray,
            ),
          ),
        ),
      ),
    );
  }
}
