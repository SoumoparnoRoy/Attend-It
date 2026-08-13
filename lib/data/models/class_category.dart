import 'package:flutter/foundation.dart';

import '../../core/date_utils.dart';

/// A kind of class — Theory, Lab, Tutorial, Seminar — that the user defines.
///
/// Its only job is to carry a sensible default length, so that picking a start
/// time fills the end time in automatically. A two-hour lab and a one-hour
/// lecture stop being the same amount of typing.
///
/// Named `ClassCategory` rather than `Category` because `package:flutter/
/// foundation.dart` already exports a `Category` annotation.
@immutable
class ClassCategory {
  const ClassCategory({
    this.id,
    required this.name,
    required this.defaultDurationMinutes,
    this.createdAt,
  });

  final int? id;
  final String name;
  final int defaultDurationMinutes;
  final DateTime? createdAt;

  String get durationLabel => Clock.formatDuration(defaultDurationMinutes);

  ClassCategory copyWith({
    int? id,
    String? name,
    int? defaultDurationMinutes,
    DateTime? createdAt,
  }) {
    return ClassCategory(
      id: id ?? this.id,
      name: name ?? this.name,
      defaultDurationMinutes:
          defaultDurationMinutes ?? this.defaultDurationMinutes,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  Map<String, Object?> toMap() => <String, Object?>{
        if (id != null) 'id': id,
        'name': name,
        'default_minutes': defaultDurationMinutes,
        'created_at': (createdAt ?? DateTime.now()).millisecondsSinceEpoch,
      };

  factory ClassCategory.fromMap(Map<String, Object?> map) {
    return ClassCategory(
      id: map['id'] as int?,
      name: (map['name'] as String?) ?? '',
      defaultDurationMinutes: (map['default_minutes'] as int?) ?? 60,
      createdAt: map['created_at'] == null
          ? null
          : DateTime.fromMillisecondsSinceEpoch(map['created_at']! as int),
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) || (other is ClassCategory && other.id == id);

  @override
  int get hashCode => id.hashCode;
}
