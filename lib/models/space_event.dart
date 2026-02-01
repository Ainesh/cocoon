/// Event model for Couple Space app.
///
/// Represents scheduled events within a couple space such as
/// date nights, check-ins, and special occasions.
library;

import 'package:cloud_firestore/cloud_firestore.dart';

/// Types of events that can be created in a couple space.
enum EventType {
  dateNight('date_night', 'Date Night', '❤️'),
  checkIn('check_in', 'Weekly Check-in', '✓'),
  special('special', 'Special Day', '🌟');

  const EventType(this.value, this.label, this.emoji);

  /// Firestore storage value.
  final String value;

  /// Human-readable label.
  final String label;

  /// Emoji for display.
  final String emoji;

  /// Creates an EventType from its Firestore value.
  static EventType fromValue(String value) {
    return EventType.values.firstWhere(
      (e) => e.value == value,
      orElse: () => EventType.special,
    );
  }
}

/// Represents a scheduled event in a couple space.
@immutable()
class SpaceEvent {
  const SpaceEvent({
    required this.id,
    required this.title,
    required this.type,
    required this.scheduledAt,
    required this.createdBy,
    this.createdAt,
    this.updatedAt,
  });

  /// Unique identifier (Firestore document ID).
  final String id;

  /// Event title.
  final String title;

  /// Event type (date_night, check_in, special).
  final EventType type;

  /// When the event is scheduled.
  final DateTime scheduledAt;

  /// User ID who created this event.
  final String createdBy;

  /// When the event was created.
  final DateTime? createdAt;

  /// When the event was last updated.
  final DateTime? updatedAt;

  /// Creates a SpaceEvent from Firestore document data.
  factory SpaceEvent.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return SpaceEvent.fromJson(doc.id, data);
  }

  /// Creates a SpaceEvent from JSON data.
  factory SpaceEvent.fromJson(String id, Map<String, dynamic> json) {
    return SpaceEvent(
      id: id,
      title: json['title'] as String? ?? '',
      type: EventType.fromValue(json['type'] as String? ?? 'special'),
      scheduledAt: (json['scheduledAt'] as Timestamp).toDate(),
      createdBy: json['createdBy'] as String? ?? '',
      createdAt: json['createdAt'] != null
          ? (json['createdAt'] as Timestamp).toDate()
          : null,
      updatedAt: json['updatedAt'] != null
          ? (json['updatedAt'] as Timestamp).toDate()
          : null,
    );
  }

  /// Converts this event to JSON for Firestore storage.
  Map<String, dynamic> toJson() {
    return {
      'title': title,
      'type': type.value,
      'scheduledAt': Timestamp.fromDate(scheduledAt),
      'createdBy': createdBy,
      'createdAt': createdAt != null
          ? Timestamp.fromDate(createdAt!)
          : FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    };
  }

  /// Returns the display title with emoji.
  String get displayTitle => '${type.emoji} $title';

  /// Returns true if this event is today.
  bool get isToday {
    final now = DateTime.now();
    return scheduledAt.year == now.year &&
        scheduledAt.month == now.month &&
        scheduledAt.day == now.day;
  }

  /// Returns true if this event is in the past.
  bool get isPast => scheduledAt.isBefore(DateTime.now());

  /// Creates a copy with updated fields.
  SpaceEvent copyWith({
    String? id,
    String? title,
    EventType? type,
    DateTime? scheduledAt,
    String? createdBy,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return SpaceEvent(
      id: id ?? this.id,
      title: title ?? this.title,
      type: type ?? this.type,
      scheduledAt: scheduledAt ?? this.scheduledAt,
      createdBy: createdBy ?? this.createdBy,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}

/// Annotation for immutable classes.
class immutable {
  const immutable();
}
