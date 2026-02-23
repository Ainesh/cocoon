/// Avatar data models for Couple Space app.
///
/// Defines the avatar system including selectable avatars and color themes.
library;

import 'package:flutter/material.dart';

/// Represents a selectable avatar with an icon and display name.
///
/// Avatars are displayed as icons within colored circular containers.
/// The [id] is used for persistence and the [icon] for display.
@immutable
class AvatarData {
  const AvatarData({required this.id, required this.name, required this.icon});

  /// Unique identifier for persistence (e.g., "avatar_1").
  final String id;

  /// Display name shown to users (e.g., "Happy").
  final String name;

  /// Material icon to display for this avatar.
  final IconData icon;

  /// Creates a storage key combining avatar ID and color name.
  ///
  /// Example: "avatar_1_blue"
  String getAvatarKey(AvatarColor color) => '${id}_${color.name}';
}

/// Color themes available for avatar customization.
///
/// Each color includes the actual [Color] value and a human-readable [label].
enum AvatarColor {
  blue(Color(0xFF1565C0), 'Blue'),
  green(Color(0xFF2E7D32), 'Green'),
  orange(Color(0xFFE65100), 'Orange'),
  purple(Color(0xFF6A1B9A), 'Purple'),
  gray(Color(0xFF546E7A), 'Gray');

  const AvatarColor(this.color, this.label);

  /// The actual color value to display.
  final Color color;

  /// Human-readable label for display.
  final String label;
}

/// Represents a user's complete avatar selection (avatar + color).
@immutable
class AvatarSelection {
  const AvatarSelection({required this.avatar, required this.color});

  final AvatarData avatar;
  final AvatarColor color;

  /// The combined key for storage (e.g., "avatar_1_blue").
  String get key => avatar.getAvatarKey(color);
}

/// Collection of predefined avatars available for selection.
///
/// Uses Material Icons to represent different personality types/moods.
abstract final class PredefinedAvatars {
  /// All available avatars for user selection.
  static const List<AvatarData> all = [
    AvatarData(
      id: 'avatar_1',
      name: 'Happy',
      icon: Icons.sentiment_very_satisfied,
    ),
    AvatarData(
      id: 'avatar_2',
      name: 'Cool',
      icon: Icons.face_retouching_natural,
    ),
    AvatarData(
      id: 'avatar_3',
      name: 'Smile',
      icon: Icons.sentiment_satisfied_alt,
    ),
    AvatarData(id: 'avatar_4', name: 'Star', icon: Icons.star_outline),
    AvatarData(id: 'avatar_5', name: 'Heart', icon: Icons.favorite_outline),
    AvatarData(id: 'avatar_6', name: 'Sunny', icon: Icons.wb_sunny_outlined),
    AvatarData(id: 'avatar_7', name: 'Nature', icon: Icons.eco_outlined),
    AvatarData(id: 'avatar_8', name: 'Music', icon: Icons.music_note_outlined),
    AvatarData(id: 'avatar_9', name: 'Spark', icon: Icons.auto_awesome),
    AvatarData(id: 'avatar_10', name: 'Cozy', icon: Icons.local_cafe_outlined),
    AvatarData(
      id: 'avatar_11',
      name: 'Adventure',
      icon: Icons.explore_outlined,
    ),
    AvatarData(id: 'avatar_12', name: 'Creative', icon: Icons.palette_outlined),
  ];

  /// Backwards compatibility alias for [all].
  @Deprecated('Use PredefinedAvatars.all instead')
  static const List<AvatarData> avatars = all;
}
