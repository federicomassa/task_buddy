import 'package:cloud_firestore/cloud_firestore.dart';

/// A window of active/working hours, stored as minutes since midnight.
class TimeRange {
  final int startMinutes;
  final int endMinutes;

  const TimeRange({required this.startMinutes, required this.endMinutes});

  factory TimeRange.fromMap(Map<String, dynamic> map) {
    return TimeRange(
      startMinutes: map['start'] as int,
      endMinutes: map['end'] as int,
    );
  }

  Map<String, dynamic> toMap() => {'start': startMinutes, 'end': endMinutes};

  @override
  bool operator ==(Object other) =>
      other is TimeRange && other.startMinutes == startMinutes && other.endMinutes == endMinutes;

  @override
  int get hashCode => Object.hash(startMinutes, endMinutes);
}

const defaultActiveHourRanges = [
  TimeRange(startMinutes: 9 * 60, endMinutes: 12 * 60),
  TimeRange(startMinutes: 13 * 60, endMinutes: 18 * 60),
];

/// WSJF priority weights for the four Eisenhower matrix quadrants. A task's
/// WSJF score is `weight / durationMinutes`, so higher weights are scheduled
/// first among tasks of similar duration.
class WsjfWeights {
  final int importantUrgent;
  final int urgentOnly;
  final int importantOnly;
  final int neither;

  const WsjfWeights({
    this.importantUrgent = 10,
    this.urgentOnly = 5,
    this.importantOnly = 3,
    this.neither = 1,
  });

  factory WsjfWeights.fromMap(Map<String, dynamic>? map) {
    if (map == null) return const WsjfWeights();
    const defaults = WsjfWeights();
    return WsjfWeights(
      importantUrgent: map['importantUrgent'] as int? ?? defaults.importantUrgent,
      urgentOnly: map['urgentOnly'] as int? ?? defaults.urgentOnly,
      importantOnly: map['importantOnly'] as int? ?? defaults.importantOnly,
      neither: map['neither'] as int? ?? defaults.neither,
    );
  }

  Map<String, dynamic> toMap() => {
        'importantUrgent': importantUrgent,
        'urgentOnly': urgentOnly,
        'importantOnly': importantOnly,
        'neither': neither,
      };
}

class UserSettings {
  static const defaultReminderMinutes = 20 * 60;

  final bool reminderEnabled;
  final int reminderMinutes;
  final List<TimeRange> activeHourRanges;
  final WsjfWeights wsjfWeights;

  const UserSettings({
    this.reminderEnabled = false,
    this.reminderMinutes = defaultReminderMinutes,
    this.activeHourRanges = defaultActiveHourRanges,
    this.wsjfWeights = const WsjfWeights(),
  });

  factory UserSettings.fromFirestore(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data();
    if (data == null) return const UserSettings();
    final ranges = (data['activeHourRanges'] as List<dynamic>?)
        ?.map((r) => TimeRange.fromMap(Map<String, dynamic>.from(r as Map)))
        .toList();
    return UserSettings(
      reminderEnabled: data['reminderEnabled'] as bool? ?? false,
      reminderMinutes: data['reminderMinutes'] as int? ?? defaultReminderMinutes,
      activeHourRanges: ranges ?? defaultActiveHourRanges,
      wsjfWeights: WsjfWeights.fromMap(data['wsjfWeights'] as Map<String, dynamic>?),
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'reminderEnabled': reminderEnabled,
      'reminderMinutes': reminderMinutes,
      'activeHourRanges': activeHourRanges.map((r) => r.toMap()).toList(),
      'wsjfWeights': wsjfWeights.toMap(),
    };
  }

  UserSettings copyWith({
    bool? reminderEnabled,
    int? reminderMinutes,
    List<TimeRange>? activeHourRanges,
    WsjfWeights? wsjfWeights,
  }) {
    return UserSettings(
      reminderEnabled: reminderEnabled ?? this.reminderEnabled,
      reminderMinutes: reminderMinutes ?? this.reminderMinutes,
      activeHourRanges: activeHourRanges ?? this.activeHourRanges,
      wsjfWeights: wsjfWeights ?? this.wsjfWeights,
    );
  }
}
