/// Moment model for Cocoon app.
///
/// Represents planned moments within a couple space:
/// - **Celebrate**: Special occasions (birthdays, anniversaries)
/// - **Connect**: Quality time together (dates, coffee, brunch)
/// - **Escape**: Multi-day getaways (vacations, trips)
library;

import 'package:cloud_firestore/cloud_firestore.dart';

// =============================================================================
// Enums
// =============================================================================

/// Types of moments that can be planned.
enum MomentType {
  celebrate('celebrate', 'Celebrate', '🎉'),
  connect('connect', 'Connect', '💕'),
  escape('escape', 'Escape', '✈️');

  const MomentType(this.value, this.label, this.emoji);

  /// Firestore storage value.
  final String value;

  /// Human-readable label.
  final String label;

  /// Emoji for display.
  final String emoji;

  /// Creates a MomentType from its Firestore value.
  static MomentType fromValue(String value) {
    return MomentType.values.firstWhere(
      (e) => e.value == value,
      orElse: () => MomentType.connect,
    );
  }
}

/// Time slots for Connect moments.
enum TimeSlot {
  morning('morning', 'Morning', '🌅', '6 AM - 12 PM'),
  afternoon('afternoon', 'Afternoon', '☀️', '12 PM - 5 PM'),
  evening('evening', 'Evening', '🌆', '5 PM - 9 PM'),
  night('night', 'Night', '🌙', '9 PM +');

  const TimeSlot(this.value, this.label, this.emoji, this.timeRange);

  final String value;
  final String label;
  final String emoji;
  final String timeRange;

  static TimeSlot fromValue(String value) {
    return TimeSlot.values.firstWhere(
      (e) => e.value == value,
      orElse: () => TimeSlot.evening,
    );
  }
}

/// Repeat schedule options.
enum RepeatSchedule {
  never('never', 'Never'),
  daily('daily', 'Daily'),
  weekly('weekly', 'Weekly'),
  monthly('monthly', 'Monthly'),
  yearly('yearly', 'Yearly');

  const RepeatSchedule(this.value, this.label);

  final String value;
  final String label;

  static RepeatSchedule fromValue(String value) {
    return RepeatSchedule.values.firstWhere(
      (e) => e.value == value,
      orElse: () => RepeatSchedule.never,
    );
  }
}

// =============================================================================
// Preset Options
// =============================================================================

/// Common preset options for Celebrate moments.
class CelebratePresets {
  static const List<String> options = [
    'Birthday',
    'Anniversary',
    'Baby Shower',
    'Promotion',
    'Holiday',
    'Graduation',
    'Engagement',
    'New Home',
  ];
}

/// Common preset options for Connect moments.
class ConnectPresets {
  static const List<String> options = [
    'Date Night',
    'Coffee',
    'Brunch',
    'Movie',
    'Shopping',
    'Dinner',
    'Walk',
    'Game Night',
  ];
}

/// Common preset options for Escape moments.
class EscapePresets {
  static const List<String> options = [
    'Weekend Getaway',
    'Beach Trip',
    'Mountain Retreat',
    'City Break',
    'Staycation',
    'Road Trip',
    'Camping',
    'Spa Retreat',
  ];
}

// =============================================================================
// Moment Model
// =============================================================================

/// Represents a planned moment in a couple space.
class Moment {
  const Moment({
    required this.id,
    required this.name,
    required this.type,
    required this.startDate,
    required this.createdBy,
    this.endDate,
    this.timeSlot,
    this.repeatSchedule = RepeatSchedule.never,
    this.notes,
    this.createdAt,
    this.updatedAt,
    this.version = 1,
  });

  /// Unique identifier (Firestore document ID).
  final String id;

  /// Moment name/title.
  final String name;

  /// Moment type (celebrate, connect, escape).
  final MomentType type;

  /// Start date of the moment.
  final DateTime startDate;

  /// End date (only for Escape moments, null otherwise).
  final DateTime? endDate;

  /// Time slot (only for Connect moments).
  final TimeSlot? timeSlot;

  /// Repeat schedule.
  final RepeatSchedule repeatSchedule;

  /// Optional notes about the moment.
  final String? notes;

  /// User ID who created this moment.
  final String createdBy;

  /// When the moment was created.
  final DateTime? createdAt;

  /// When the moment was last updated.
  final DateTime? updatedAt;

  /// Optimistic lock version — incremented on each update.
  final int version;

  // ---------------------------------------------------------------------------
  // Factory Constructors
  // ---------------------------------------------------------------------------

  /// Creates a Moment from Firestore document.
  factory Moment.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return Moment.fromJson(doc.id, data);
  }

  /// Creates a Moment from JSON data.
  factory Moment.fromJson(String id, Map<String, dynamic> json) {
    return Moment(
      id: id,
      name: json['name'] as String? ?? '',
      type: MomentType.fromValue(json['type'] as String? ?? 'connect'),
      startDate: json['startDate'] != null
          ? _toUtcDate((json['startDate'] as Timestamp).toDate())
          : DateTime.now().toUtc(),
      endDate: json['endDate'] != null
          ? _toUtcDate((json['endDate'] as Timestamp).toDate())
          : null,
      timeSlot: json['timeSlot'] != null
          ? TimeSlot.fromValue(json['timeSlot'] as String)
          : null,
      repeatSchedule: RepeatSchedule.fromValue(
        json['repeatSchedule'] as String? ?? 'never',
      ),
      notes: json['notes'] as String?,
      createdBy: json['createdBy'] as String? ?? '',
      createdAt: json['createdAt'] != null
          ? (json['createdAt'] as Timestamp).toDate()
          : null,
      updatedAt: json['updatedAt'] != null
          ? (json['updatedAt'] as Timestamp).toDate()
          : null,
      version: json['version'] as int? ?? 1,
    );
  }

  // ---------------------------------------------------------------------------
  // Serialization
  // ---------------------------------------------------------------------------

  /// Converts this moment to JSON for Firestore storage.
  Map<String, dynamic> toJson() {
    return {
      'name': name,
      'type': type.value,
      'startDate': Timestamp.fromDate(startDate),
      'endDate': endDate != null ? Timestamp.fromDate(endDate!) : null,
      'timeSlot': timeSlot?.value,
      'repeatSchedule': repeatSchedule.value,
      'notes': notes,
      'createdBy': createdBy,
      'createdAt': createdAt != null
          ? Timestamp.fromDate(createdAt!)
          : FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
      'version': version,
    };
  }

  // ---------------------------------------------------------------------------
  // Computed Properties
  // ---------------------------------------------------------------------------

  /// Returns the display title with emoji.
  String get displayTitle => '${type.emoji} $name';

  /// Returns true if this moment is today (UTC comparison).
  bool get isToday {
    final today = _todayUtc();
    return startDate.year == today.year &&
        startDate.month == today.month &&
        startDate.day == today.day;
  }

  /// Returns true if this moment spans today (for multi-day escapes).
  bool get spansToday {
    if (endDate == null) return isToday;
    final today = _todayUtc();
    return !today.isBefore(startDate) && !today.isAfter(endDate!);
  }

  /// Returns true if this moment is in the past (UTC comparison).
  bool get isPast {
    final compareDate = endDate ?? startDate;
    return compareDate.isBefore(_todayUtc());
  }

  static DateTime _todayUtc() {
    final now = DateTime.now();
    return DateTime.utc(now.year, now.month, now.day);
  }

  /// Returns true if this moment is upcoming (in the future).
  bool get isUpcoming => !isPast;

  /// Returns the duration in days (for Escape moments).
  int get durationDays {
    if (endDate == null) return 1;
    return endDate!.difference(startDate).inDays + 1;
  }

  /// Returns the number of nights (for Escape moments).
  int get nights {
    if (endDate == null) return 0;
    return endDate!.difference(startDate).inDays;
  }

  /// Returns a human-readable date string.
  String get dateDisplay {
    if (type == MomentType.escape && endDate != null) {
      return '${_formatDate(startDate)} - ${_formatDate(endDate!)}';
    }
    return _formatDate(startDate);
  }

  /// Returns a human-readable time display (for Connect moments).
  String get timeDisplay {
    if (timeSlot == null) return '';
    return '${timeSlot!.emoji} ${timeSlot!.label}';
  }

  /// Returns relative time description (Tomorrow, In 3 days, Next week, etc.)
  String get relativeDate {
    final today = _todayUtc();
    final momentDate = _toUtcDate(startDate);
    final diff = momentDate.difference(today).inDays;

    // Past dates
    if (diff < 0) {
      if (diff == -1) return 'Yesterday';
      if (diff > -7) return '${-diff} days ago';
      return _formatDate(startDate);
    }

    // Today/Tomorrow
    if (diff == 0) return 'Today';
    if (diff == 1) return 'Tomorrow';

    // This week (2-6 days)
    if (diff < 7) return 'In $diff days';

    // Weeks (7-29 days)
    if (diff < 30) {
      final weeks = (diff / 7).floor();
      if (weeks == 1) return 'Next week';
      return 'In $weeks weeks';
    }

    // Months (30+ days)
    final months = (diff / 30).floor();
    if (months == 1) return 'Next month';
    if (months < 12) return 'In $months months';

    // Years
    final years = (diff / 365).floor();
    if (years == 1) return 'Next year';
    return 'In $years years';
  }

  String _formatDate(DateTime date) {
    const months = [
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec',
    ];
    return '${months[date.month - 1]} ${date.day}';
  }

  // ---------------------------------------------------------------------------
  // Copy With
  // ---------------------------------------------------------------------------

  /// Creates a copy with updated fields.
  Moment copyWith({
    String? id,
    String? name,
    MomentType? type,
    DateTime? startDate,
    DateTime? endDate,
    TimeSlot? timeSlot,
    RepeatSchedule? repeatSchedule,
    String? createdBy,
    DateTime? createdAt,
    DateTime? updatedAt,
    int? version,
  }) {
    return Moment(
      id: id ?? this.id,
      name: name ?? this.name,
      type: type ?? this.type,
      startDate: startDate ?? this.startDate,
      endDate: endDate ?? this.endDate,
      timeSlot: timeSlot ?? this.timeSlot,
      repeatSchedule: repeatSchedule ?? this.repeatSchedule,
      createdBy: createdBy ?? this.createdBy,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      version: version ?? this.version,
    );
  }

  @override
  String toString() => 'Moment($name, $type, $startDate)';

  /// Normalizes any DateTime to UTC midnight.
  ///
  /// All moment dates are stored and compared as UTC midnight.
  /// Uses UTC components to avoid timezone day-shift.
  static DateTime _toUtcDate(DateTime dt) {
    final utc = dt.toUtc();
    return DateTime.utc(utc.year, utc.month, utc.day);
  }
}
