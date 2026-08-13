import 'package:flutter/foundation.dart';

import '../../core/date_utils.dart';

/// A day with no classes — a public holiday, a strike, a mid-term break day.
/// Recurring slots do not generate occurrences on these dates.
@immutable
class Holiday {
  const Holiday({this.id, required this.date, required this.name});

  final int? id;
  final DateTime date;
  final String name;

  Holiday copyWith({int? id, DateTime? date, String? name}) => Holiday(
        id: id ?? this.id,
        date: date ?? this.date,
        name: name ?? this.name,
      );

  Map<String, Object?> toMap() => <String, Object?>{
        if (id != null) 'id': id,
        'date': Dates.keyOf(date),
        'name': name,
      };

  factory Holiday.fromMap(Map<String, Object?> map) => Holiday(
        id: map['id'] as int?,
        date: Dates.fromKey((map['date'] as int?) ?? 19700101),
        name: (map['name'] as String?) ?? 'Holiday',
      );
}
