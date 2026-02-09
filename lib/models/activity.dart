/// Activity model for Cocoon app.
///
/// Tracks all activities within a couple space for the activity trail.
/// Supports various activity types with entity linking for deep navigation.
library;

import 'package:cloud_firestore/cloud_firestore.dart';

// =============================================================================
// Enums
// =============================================================================

/// Types of activities that can be tracked.
enum ActivityType {
  // Check-in activities
  checkin('checkin', 'checked in'),

  // Moment activities
  momentPlanned('moment_planned', 'planned'),
  momentEdited('moment_edited', 'updated'),
  momentDeleted('moment_deleted', 'cancelled'),
  momentCompleted('moment_completed', 'completed'),

  // Space activities
  spaceCreated('space_created', 'created the space'),
  spaceJoined('space_joined', 'joined the space'),
  spaceRenamed('space_renamed', 'renamed the space'),
  
  // Future activities
  inviteSent('invite_sent', 'sent an invite'),
  inviteAccepted('invite_accepted', 'accepted the invite');

  const ActivityType(this.value, this.actionText);

  /// Firestore storage value.
  final String value;

  /// Human-readable action text (e.g., "planned", "checked in").
  final String actionText;

  /// Creates an ActivityType from its Firestore value.
  static ActivityType fromValue(String value) {
    return ActivityType.values.firstWhere(
      (e) => e.value == value,
      orElse: () => ActivityType.checkin,
    );
  }

  /// Whether this activity is related to moments.
  bool get isMomentActivity => [
        ActivityType.momentPlanned,
        ActivityType.momentEdited,
        ActivityType.momentDeleted,
        ActivityType.momentCompleted,
      ].contains(this);

  /// Whether this activity is related to the space itself.
  bool get isSpaceActivity => [
        ActivityType.spaceCreated,
        ActivityType.spaceJoined,
        ActivityType.spaceRenamed,
        ActivityType.inviteSent,
        ActivityType.inviteAccepted,
      ].contains(this);
}

/// Types of entities that activities can reference.
enum EntityType {
  checkin('checkin'),
  moment('moment'),
  space('space');

  const EntityType(this.value);

  final String value;

  static EntityType fromValue(String value) {
    return EntityType.values.firstWhere(
      (e) => e.value == value,
      orElse: () => EntityType.space,
    );
  }
}

// =============================================================================
// Activity Model
// =============================================================================

/// Represents an activity event within a couple space.
///
/// Activities are tracked to show a timeline of actions taken by both partners,
/// fostering transparency and shared experience.
///
/// Example:
/// ```dart
/// final activity = Activity(
///   id: 'act_123',
///   type: ActivityType.momentPlanned,
///   actorId: 'user_456',
///   actorName: 'Alex',
///   timestamp: DateTime.now(),
///   entityType: EntityType.moment,
///   entityId: 'mom_789',
///   metadata: {
///     'momentName': 'Date Night',
///     'momentType': 'connect',
///   },
/// );
/// ```
class Activity {
  const Activity({
    required this.id,
    required this.type,
    required this.actorId,
    required this.actorName,
    required this.timestamp,
    this.entityType,
    this.entityId,
    this.metadata,
  });

  // ---------------------------------------------------------------------------
  // Fields
  // ---------------------------------------------------------------------------

  /// Unique identifier for the activity.
  final String id;

  /// Type of activity (checkin, moment planned, etc.).
  final ActivityType type;

  /// User ID of the person who performed the action.
  final String actorId;

  /// Display name of the actor (denormalized for quick display).
  final String actorName;

  /// When the activity occurred.
  final DateTime timestamp;

  /// Type of entity this activity relates to (for deep linking).
  final EntityType? entityType;

  /// ID of the related entity (checkin ID, moment ID, etc.).
  final String? entityId;

  /// Additional metadata about the activity.
  /// 
  /// For moments: { momentName, momentType, momentDate }
  /// For check-ins: { connection, intimacy, peace }
  /// For space: { oldName, newName }
  final Map<String, dynamic>? metadata;

  // ---------------------------------------------------------------------------
  // Computed Properties
  // ---------------------------------------------------------------------------

  /// Returns a human-readable description of the activity.
  String get description {
    switch (type) {
      case ActivityType.checkin:
        // Simple text - detailed scores are rendered by UI
        return 'checked in';

      case ActivityType.momentPlanned:
      case ActivityType.momentDeleted:
      case ActivityType.momentCompleted:
        final name = metadata?['momentName'] as String?;
        return name != null ? '${type.actionText} "$name"' : type.actionText;

      case ActivityType.momentEdited:
        final name = metadata?['momentName'] as String?;
        return name != null ? 'updated "$name"' : 'updated a moment';

      case ActivityType.spaceRenamed:
        final newName = metadata?['newName'] as String?;
        return newName != null ? 'renamed space to "$newName"' : type.actionText;

      default:
        return type.actionText;
    }
  }
  
  /// Returns the list of changed fields for edited moments.
  List<String> get changedFields {
    if (type != ActivityType.momentEdited) return [];
    final fields = metadata?['changedFields'];
    if (fields is List) {
      return fields.cast<String>();
    }
    return [];
  }

  /// Returns a relative time string (e.g., "2h ago", "Yesterday").
  String get relativeTime {
    final now = DateTime.now();
    final diff = now.difference(timestamp);

    if (diff.inMinutes < 1) return 'Just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    if (diff.inDays == 1) return 'Yesterday';
    if (diff.inDays < 7) return '${diff.inDays}d ago';
    if (diff.inDays < 30) return '${(diff.inDays / 7).floor()}w ago';
    return '${(diff.inDays / 30).floor()}mo ago';
  }

  /// Whether this activity can be tapped to navigate to the entity.
  /// Check-in navigation disabled until check-in details sheet is implemented.
  bool get isNavigable => entityId != null && 
      type != ActivityType.momentDeleted &&
      type != ActivityType.checkin;

  // ---------------------------------------------------------------------------
  // Firestore Serialization
  // ---------------------------------------------------------------------------

  /// Creates an Activity from a Firestore document.
  factory Activity.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return Activity(
      id: doc.id,
      type: ActivityType.fromValue(data['type'] as String? ?? 'checkin'),
      actorId: data['actorId'] as String? ?? '',
      actorName: data['actorName'] as String? ?? 'Unknown',
      timestamp: (data['timestamp'] as Timestamp?)?.toDate() ?? DateTime.now(),
      entityType: data['entityType'] != null
          ? EntityType.fromValue(data['entityType'] as String)
          : null,
      entityId: data['entityId'] as String?,
      metadata: data['metadata'] as Map<String, dynamic>?,
    );
  }

  /// Converts the Activity to a Firestore document.
  Map<String, dynamic> toFirestore() {
    return {
      'type': type.value,
      'actorId': actorId,
      'actorName': actorName,
      'timestamp': Timestamp.fromDate(timestamp),
      if (entityType != null) 'entityType': entityType!.value,
      if (entityId != null) 'entityId': entityId,
      if (metadata != null) 'metadata': metadata,
    };
  }

  // ---------------------------------------------------------------------------
  // Copy With
  // ---------------------------------------------------------------------------

  Activity copyWith({
    String? id,
    ActivityType? type,
    String? actorId,
    String? actorName,
    DateTime? timestamp,
    EntityType? entityType,
    String? entityId,
    Map<String, dynamic>? metadata,
  }) {
    return Activity(
      id: id ?? this.id,
      type: type ?? this.type,
      actorId: actorId ?? this.actorId,
      actorName: actorName ?? this.actorName,
      timestamp: timestamp ?? this.timestamp,
      entityType: entityType ?? this.entityType,
      entityId: entityId ?? this.entityId,
      metadata: metadata ?? this.metadata,
    );
  }

  @override
  String toString() => 'Activity($id, $type, $actorName: $description)';
}
