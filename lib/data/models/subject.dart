import 'package:flutter/material.dart';

import '../../core/app_theme.dart';

/// A course you are enrolled in. Classes hang off a subject, and attendance is
/// aggregated per subject.
@immutable
class Subject {
  const Subject({
    this.id,
    required this.name,
    this.code,
    this.teacher,
    required this.colorValue,
    this.targetPercent,
    this.categoryId,
    this.createdAt,
  });

  final int? id;
  final String name;
  final String? code;
  final String? teacher;
  final int colorValue;

  /// Per-subject attendance requirement. When null the global target applies.
  final double? targetPercent;

  /// The [ClassCategory] this subject belongs to, which supplies the default
  /// class length. Null means the global default applies.
  final int? categoryId;

  final DateTime? createdAt;

  Color get color => Color(colorValue);

  /// Two-letter monogram used on avatars, e.g. "Data Structures" -> "DS".
  String get initials {
    final List<String> words = name
        .trim()
        .split(RegExp(r'\s+'))
        .where((String w) => w.isNotEmpty)
        .toList();
    if (words.isEmpty) return '?';
    if (words.length == 1) {
      return words.first.substring(0, words.first.length >= 2 ? 2 : 1).toUpperCase();
    }
    return (words[0][0] + words[1][0]).toUpperCase();
  }

  Subject copyWith({
    int? id,
    String? name,
    String? code,
    String? teacher,
    int? colorValue,
    double? targetPercent,
    bool clearTargetPercent = false,
    int? categoryId,
    bool clearCategory = false,
    DateTime? createdAt,
  }) {
    return Subject(
      id: id ?? this.id,
      name: name ?? this.name,
      code: code ?? this.code,
      teacher: teacher ?? this.teacher,
      colorValue: colorValue ?? this.colorValue,
      targetPercent:
          clearTargetPercent ? null : (targetPercent ?? this.targetPercent),
      categoryId: clearCategory ? null : (categoryId ?? this.categoryId),
      createdAt: createdAt ?? this.createdAt,
    );
  }

  Map<String, Object?> toMap() => <String, Object?>{
        if (id != null) 'id': id,
        'name': name,
        'code': code,
        'teacher': teacher,
        'color': colorValue,
        'target_percent': targetPercent,
        'category_id': categoryId,
        'created_at':
            (createdAt ?? DateTime.now()).millisecondsSinceEpoch,
      };

  factory Subject.fromMap(Map<String, Object?> map) {
    return Subject(
      id: map['id'] as int?,
      name: (map['name'] as String?) ?? '',
      code: map['code'] as String?,
      teacher: map['teacher'] as String?,
      colorValue: (map['color'] as int?) ?? AppColors.defaultSubjectColor,
      targetPercent: (map['target_percent'] as num?)?.toDouble(),
      categoryId: map['category_id'] as int?,
      createdAt: map['created_at'] == null
          ? null
          : DateTime.fromMillisecondsSinceEpoch(map['created_at']! as int),
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) || (other is Subject && other.id == id);

  @override
  int get hashCode => id.hashCode;
}
