/// Pulse attribute configuration for a couple space.
///
/// Each user picks up to 3 attributes from a pool of 5. The active set
/// is the union of both users' picks. Attributes picked by both users
/// receive 2× weight; attributes picked by one get 1×.
library;

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

// ---------------------------------------------------------------------------
// Pulse attribute enum
// ---------------------------------------------------------------------------

/// The 5 available pulse attributes.
enum PulseAttribute {
  connection(
    id: 'connection',
    displayName: 'Connection',
    emoji: '❤️',
    iconAsset: null,
    icon: Icons.favorite_rounded,
  ),
  intimacy(
    id: 'intimacy',
    displayName: 'Intimacy',
    emoji: '🔥',
    iconAsset: 'assets/icons/flame.svg',
    icon: null,
  ),
  peace(
    id: 'peace',
    displayName: 'Peace',
    emoji: '☮️',
    iconAsset: 'assets/icons/peace.svg',
    icon: null,
  ),
  trust(
    id: 'trust',
    displayName: 'Trust',
    emoji: '🤝',
    iconAsset: null,
    icon: Icons.handshake_rounded,
  ),
  communication(
    id: 'communication',
    displayName: 'Expression',
    emoji: '💬',
    iconAsset: null,
    icon: Icons.chat_bubble_rounded,
  ),
  growth(
    id: 'growth',
    displayName: 'Growth',
    emoji: '📈',
    iconAsset: null,
    icon: Icons.trending_up_rounded,
  ),
  fun(
    id: 'fun',
    displayName: 'Fun',
    emoji: '🎉',
    iconAsset: null,
    icon: Icons.celebration_rounded,
  ),
  support(
    id: 'support',
    displayName: 'Support',
    emoji: '🛡️',
    iconAsset: null,
    icon: Icons.shield_rounded,
  );

  /// Max characters for displayName to prevent UI overflow in bar sliders.
  /// All names must be ≤ 10 chars.
  static const int maxDisplayNameLength = 10;

  const PulseAttribute({
    required this.id,
    required this.displayName,
    required this.emoji,
    required this.iconAsset,
    required this.icon,
  }) : assert(
         displayName.length <= maxDisplayNameLength,
         'displayName "$displayName" exceeds $maxDisplayNameLength chars — '
         'will overflow in slider labels',
       );

  /// Stable string identifier stored in Firestore.
  final String id;

  /// Human-readable label (≤ 10 chars to fit bar slider width).
  final String displayName;

  /// Emoji representation.
  final String emoji;

  /// Path to an SVG asset, or null if using a Material icon.
  final String? iconAsset;

  /// Material icon, or null if using an SVG asset.
  final IconData? icon;

  /// Builds the icon widget for this attribute at the given [size] and [color].
  /// Use this everywhere instead of manual switch statements.
  Widget buildIcon({required Color color, double size = 18}) {
    if (iconAsset != null) {
      return SvgPicture.asset(
        iconAsset!,
        width: size,
        height: size,
        colorFilter: ColorFilter.mode(color, BlendMode.srcIn),
      );
    }
    return Icon(icon ?? Icons.circle, color: color, size: size);
  }

  /// Look up a [PulseAttribute] by its stable [id].
  static PulseAttribute? fromId(String id) {
    for (final attr in values) {
      if (attr.id == id) return attr;
    }
    return null;
  }
}

// ---------------------------------------------------------------------------
// Pulse config model
// ---------------------------------------------------------------------------

/// Space-level pulse configuration.
///
/// Stored as `pulseConfig` field in the space document:
/// ```
/// spaces/{spaceId}.pulseConfig = {
///   "userPicks": { "uid_a": ["connection","trust","communication"], ... },
///   "updatedAt": Timestamp
/// }
/// ```
class PulseConfig {
  const PulseConfig({
    required this.userPicks,
    this.updatedAt,
  });

  /// Each user's selected attribute IDs. Key = userId, value = list of
  /// attribute IDs (1-3 items per user).
  final Map<String, List<String>> userPicks;

  /// When the config was last modified.
  final DateTime? updatedAt;

  // -------------------------------------------------------------------------
  // Computed properties
  // -------------------------------------------------------------------------

  /// The active attribute IDs — union of all users' picks.
  List<String> get activeAttributes {
    final all = <String>{};
    for (final picks in userPicks.values) {
      all.addAll(picks);
    }
    // Return in the canonical enum order for deterministic UI rendering.
    final ordered = PulseAttribute.values
        .where((a) => all.contains(a.id))
        .map((a) => a.id)
        .toList();
    return ordered;
  }

  /// Normalised weights. Attributes picked by 2 users get 2× raw weight.
  ///
  /// Returns a map where values sum to 1.0.
  Map<String, double> get weights {
    final rawWeights = <String, int>{};
    for (final picks in userPicks.values) {
      for (final attrId in picks) {
        rawWeights[attrId] = (rawWeights[attrId] ?? 0) + 1;
      }
    }
    if (rawWeights.isEmpty) return {};
    final total = rawWeights.values.fold(0, (acc, w) => acc + w);
    return rawWeights.map((k, v) => MapEntry(k, v / total));
  }

  /// The [PulseAttribute] enums for all active attributes.
  List<PulseAttribute> get activeAttributeEnums {
    return activeAttributes
        .map((id) => PulseAttribute.fromId(id))
        .whereType<PulseAttribute>()
        .toList();
  }

  // -------------------------------------------------------------------------
  // Validation
  // -------------------------------------------------------------------------

  /// Validates that a single user's picks are legal (1-3 items, all valid IDs).
  static bool isValidUserPicks(List<String> picks) {
    if (picks.isEmpty || picks.length > 3) return false;
    final validIds = PulseAttribute.values.map((a) => a.id).toSet();
    return picks.every((id) => validIds.contains(id)) &&
        picks.toSet().length == picks.length; // no duplicates
  }

  // -------------------------------------------------------------------------
  // Serialisation
  // -------------------------------------------------------------------------

  Map<String, dynamic> toJson() {
    return {
      'userPicks': userPicks.map(
        (uid, picks) => MapEntry(uid, picks),
      ),
      if (updatedAt != null) 'updatedAt': Timestamp.fromDate(updatedAt!),
    };
  }

  factory PulseConfig.fromJson(Map<String, dynamic> json) {
    final rawPicks = json['userPicks'] as Map<String, dynamic>? ?? {};
    final userPicks = rawPicks.map(
      (uid, picks) => MapEntry(uid, List<String>.from(picks as List)),
    );
    DateTime? updatedAt;
    if (json['updatedAt'] != null) {
      updatedAt = (json['updatedAt'] as Timestamp).toDate();
    }
    return PulseConfig(userPicks: userPicks, updatedAt: updatedAt);
  }

  /// Default config when no pulse config exists on the space.
  /// Uses the original 3 attributes with equal weight.
  static PulseConfig defaultConfig({List<String> memberIds = const []}) {
    final defaultPicks = ['connection', 'intimacy', 'peace'];
    final picks = <String, List<String>>{};
    for (final uid in memberIds) {
      picks[uid] = List.from(defaultPicks);
    }
    return PulseConfig(userPicks: picks);
  }

  /// Creates a copy with one user's picks updated.
  PulseConfig copyWithUserPicks(String userId, List<String> picks) {
    return PulseConfig(
      userPicks: {...userPicks, userId: picks},
      updatedAt: DateTime.now(),
    );
  }

  @override
  String toString() =>
      'PulseConfig(picks=$userPicks, active=$activeAttributes)';
}
