/// Notification preferences model for Cocoon app.
///
/// Provides configurable notification settings per activity type,
/// allowing users to control priority levels and enable/disable
/// notifications for specific activities.
library;

import 'activity.dart';

// =============================================================================
// Enums
// =============================================================================

/// Priority levels for notifications.
/// Higher priority = more intrusive notification behavior.
enum NotificationPriority {
  /// Silent - no sound, no vibration, may not show on lock screen
  silent('silent'),

  /// Low - gentle notification, may be grouped
  low('low'),

  /// Normal - standard notification with sound
  normal('normal'),

  /// High - appears immediately, sound + vibration
  high('high'),

  /// Critical - bypasses DND (use sparingly, iOS requires entitlement)
  critical('critical');

  const NotificationPriority(this.value);

  /// Firestore storage value.
  final String value;

  /// Creates a NotificationPriority from its Firestore value.
  static NotificationPriority fromValue(String value) {
    return NotificationPriority.values.firstWhere(
      (e) => e.value == value,
      orElse: () => NotificationPriority.normal,
    );
  }

  /// Display name for UI.
  String get displayName {
    switch (this) {
      case NotificationPriority.silent:
        return 'Silent';
      case NotificationPriority.low:
        return 'Low';
      case NotificationPriority.normal:
        return 'Normal';
      case NotificationPriority.high:
        return 'High';
      case NotificationPriority.critical:
        return 'Critical';
    }
  }
}

// =============================================================================
// Activity Notification Config
// =============================================================================

/// Configuration for a single activity type's notifications.
class ActivityNotificationConfig {
  const ActivityNotificationConfig({
    required this.activityType,
    this.enabled = true,
    this.priority = NotificationPriority.normal,
  });

  /// The activity type this config applies to.
  final ActivityType activityType;

  /// Whether notifications are enabled for this activity type.
  final bool enabled;

  /// The priority level for notifications of this type.
  final NotificationPriority priority;

  /// Converts to JSON for Firestore storage.
  Map<String, dynamic> toJson() => {
        'enabled': enabled,
        'priority': priority.value,
      };

  /// Creates from Firestore JSON data.
  factory ActivityNotificationConfig.fromJson(
    ActivityType type,
    Map<String, dynamic> json,
  ) {
    return ActivityNotificationConfig(
      activityType: type,
      enabled: json['enabled'] as bool? ?? true,
      priority: NotificationPriority.fromValue(
        json['priority'] as String? ?? 'normal',
      ),
    );
  }

  /// Creates a copy with updated fields.
  ActivityNotificationConfig copyWith({
    bool? enabled,
    NotificationPriority? priority,
  }) {
    return ActivityNotificationConfig(
      activityType: activityType,
      enabled: enabled ?? this.enabled,
      priority: priority ?? this.priority,
    );
  }

  @override
  String toString() =>
      'ActivityNotificationConfig(${activityType.value}, enabled: $enabled, priority: ${priority.value})';
}

// =============================================================================
// Notification Preferences
// =============================================================================

/// Complete notification preferences for a user.
///
/// Stores both a global enable/disable switch and per-activity-type
/// configurations with priority levels.
///
/// Example:
/// ```dart
/// final prefs = NotificationPreferences();
///
/// // Check if should notify
/// if (prefs.shouldNotify(ActivityType.checkin)) {
///   final priority = prefs.getPriority(ActivityType.checkin);
///   // Send notification with appropriate priority
/// }
///
/// // Update a preference
/// final updated = prefs.updateActivityConfig(
///   ActivityType.momentEdited,
///   enabled: false,
/// );
/// ```
class NotificationPreferences {
  NotificationPreferences({
    this.globalEnabled = true,
    Map<ActivityType, ActivityNotificationConfig>? activityConfigs,
  }) : activityConfigs = activityConfigs ?? _defaultConfigs();

  /// Master switch - disables all notifications when false.
  final bool globalEnabled;

  /// Per-activity-type configuration map.
  final Map<ActivityType, ActivityNotificationConfig> activityConfigs;

  // ---------------------------------------------------------------------------
  // Default Configurations
  // ---------------------------------------------------------------------------

  /// Default configurations with sensible priorities based on activity importance.
  static Map<ActivityType, ActivityNotificationConfig> _defaultConfigs() {
    return {
      // Check-in: Normal priority - partner shared their feelings
      ActivityType.checkin: const ActivityNotificationConfig(
        activityType: ActivityType.checkin,
        enabled: true,
        priority: NotificationPriority.normal,
      ),

      // Moment planned: Normal - good news to share
      ActivityType.momentPlanned: const ActivityNotificationConfig(
        activityType: ActivityType.momentPlanned,
        enabled: true,
        priority: NotificationPriority.normal,
      ),

      // Moment edited: Low - minor update, not urgent
      ActivityType.momentEdited: const ActivityNotificationConfig(
        activityType: ActivityType.momentEdited,
        enabled: true,
        priority: NotificationPriority.low,
      ),

      // Moment deleted: Normal - they should know about cancellation
      ActivityType.momentDeleted: const ActivityNotificationConfig(
        activityType: ActivityType.momentDeleted,
        enabled: true,
        priority: NotificationPriority.normal,
      ),

      // Moment completed: Low - informational
      ActivityType.momentCompleted: const ActivityNotificationConfig(
        activityType: ActivityType.momentCompleted,
        enabled: true,
        priority: NotificationPriority.low,
      ),

      // Space joined: High - exciting, partner connected!
      ActivityType.spaceJoined: const ActivityNotificationConfig(
        activityType: ActivityType.spaceJoined,
        enabled: true,
        priority: NotificationPriority.high,
      ),

      // Space created: Disabled - actor just did this themselves
      ActivityType.spaceCreated: const ActivityNotificationConfig(
        activityType: ActivityType.spaceCreated,
        enabled: false,
        priority: NotificationPriority.silent,
      ),

      // Space renamed: Low - minor change
      ActivityType.spaceRenamed: const ActivityNotificationConfig(
        activityType: ActivityType.spaceRenamed,
        enabled: true,
        priority: NotificationPriority.low,
      ),

      // Invite sent: Disabled - actor's own action
      ActivityType.inviteSent: const ActivityNotificationConfig(
        activityType: ActivityType.inviteSent,
        enabled: false,
        priority: NotificationPriority.silent,
      ),

      // Invite accepted: High - partner action, exciting!
      ActivityType.inviteAccepted: const ActivityNotificationConfig(
        activityType: ActivityType.inviteAccepted,
        enabled: true,
        priority: NotificationPriority.high,
      ),
    };
  }

  // ---------------------------------------------------------------------------
  // Accessors
  // ---------------------------------------------------------------------------

  /// Get configuration for a specific activity type.
  /// Returns default config if not found.
  ActivityNotificationConfig getConfig(ActivityType type) {
    return activityConfigs[type] ??
        ActivityNotificationConfig(
          activityType: type,
          enabled: true,
          priority: NotificationPriority.normal,
        );
  }

  /// Check if notifications should be sent for this activity type.
  /// Returns false if global switch is off or activity type is disabled.
  bool shouldNotify(ActivityType type) {
    if (!globalEnabled) return false;
    return getConfig(type).enabled;
  }

  /// Get priority for an activity type.
  NotificationPriority getPriority(ActivityType type) {
    return getConfig(type).priority;
  }

  /// Get all activity types that have notifications enabled.
  List<ActivityType> get enabledActivityTypes {
    if (!globalEnabled) return [];
    return activityConfigs.entries
        .where((e) => e.value.enabled)
        .map((e) => e.key)
        .toList();
  }

  // ---------------------------------------------------------------------------
  // Firestore Serialization
  // ---------------------------------------------------------------------------

  /// Converts to Firestore document format.
  Map<String, dynamic> toFirestore() => {
        'globalEnabled': globalEnabled,
        'activityConfigs': activityConfigs.map(
          (type, config) => MapEntry(type.value, config.toJson()),
        ),
      };

  /// Creates from Firestore document data.
  factory NotificationPreferences.fromFirestore(Map<String, dynamic>? data) {
    if (data == null) return NotificationPreferences();

    final configsData =
        data['activityConfigs'] as Map<String, dynamic>? ?? {};
    final configs = <ActivityType, ActivityNotificationConfig>{};

    // Initialize with defaults first
    final defaults = _defaultConfigs();
    for (final type in ActivityType.values) {
      final typeData = configsData[type.value] as Map<String, dynamic>?;
      configs[type] = typeData != null
          ? ActivityNotificationConfig.fromJson(type, typeData)
          : defaults[type] ??
              ActivityNotificationConfig(activityType: type);
    }

    return NotificationPreferences(
      globalEnabled: data['globalEnabled'] as bool? ?? true,
      activityConfigs: configs,
    );
  }

  // ---------------------------------------------------------------------------
  // Copy With
  // ---------------------------------------------------------------------------

  /// Creates a copy with updated fields.
  NotificationPreferences copyWith({
    bool? globalEnabled,
    Map<ActivityType, ActivityNotificationConfig>? activityConfigs,
  }) {
    return NotificationPreferences(
      globalEnabled: globalEnabled ?? this.globalEnabled,
      activityConfigs: activityConfigs ?? this.activityConfigs,
    );
  }

  /// Update a single activity type's configuration.
  NotificationPreferences updateActivityConfig(
    ActivityType type, {
    bool? enabled,
    NotificationPriority? priority,
  }) {
    final newConfigs =
        Map<ActivityType, ActivityNotificationConfig>.from(activityConfigs);
    final current = newConfigs[type] ??
        ActivityNotificationConfig(activityType: type);
    newConfigs[type] = current.copyWith(
      enabled: enabled,
      priority: priority,
    );
    return copyWith(activityConfigs: newConfigs);
  }

  /// Toggle global notifications on/off.
  NotificationPreferences toggleGlobal() {
    return copyWith(globalEnabled: !globalEnabled);
  }

  /// Toggle a specific activity type on/off.
  NotificationPreferences toggleActivityType(ActivityType type) {
    final current = getConfig(type);
    return updateActivityConfig(type, enabled: !current.enabled);
  }

  @override
  String toString() =>
      'NotificationPreferences(global: $globalEnabled, configs: ${activityConfigs.length})';
}
