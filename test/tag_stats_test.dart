import 'package:flutter_test/flutter_test.dart';

import 'package:zeolite/core/app_theme.dart';
import 'package:zeolite/data/models/attendance_record.dart';
import 'package:zeolite/data/models/attendance_status.dart';
import 'package:zeolite/data/models/subject.dart';
import 'package:zeolite/data/models/tag.dart';
import 'package:zeolite/domain/tag_stats.dart';

const List<Subject> _subjects = <Subject>[
  Subject(id: 1, name: 'Physics', colorValue: AppColors.defaultSubjectColor),
  Subject(id: 2, name: 'Maths', colorValue: AppColors.defaultSubjectColor),
];

const List<Tag> _tags = <Tag>[
  Tag(id: 1, name: 'Proxy'),
  Tag(id: 2, name: 'Online'),
];

AttendanceRecord _mark({
  int subjectId = 1,
  int day = 1,
  int startMinutes = 540,
  AttendanceStatus status = AttendanceStatus.present,
  int? tagId,
}) {
  return AttendanceRecord(
    subjectId: subjectId,
    date: DateTime(2026, 8, day),
    startMinutes: startMinutes,
    status: status,
    tagId: tagId,
  );
}

TagBreakdown _named(List<TagBreakdown> all, String name) =>
    all.firstWhere((TagBreakdown b) => b.tag.name == name);

void main() {
  group('grouping marks by tag', () {
    test('untagged marks are left out entirely', () {
      final List<TagBreakdown> result = buildTagBreakdowns(
        tags: _tags,
        subjects: _subjects,
        records: <AttendanceRecord>[
          _mark(day: 1, tagId: 1),
          _mark(day: 2),
          _mark(day: 3),
        ],
      );

      expect(_named(result, 'Proxy').total, 1);
      expect(
        result.fold<int>(0, (int sum, TagBreakdown b) => sum + b.total),
        1,
      );
    });

    test('a tag with no marks is kept, so a new tag still appears', () {
      final List<TagBreakdown> result = buildTagBreakdowns(
        tags: _tags,
        subjects: _subjects,
        records: <AttendanceRecord>[_mark(tagId: 1)],
      );

      expect(result.length, 2);
      expect(_named(result, 'Online').isEmpty, isTrue);
      expect(_named(result, 'Online').summary, 'Not used yet');
    });

    test('with no tags configured there is nothing to group', () {
      expect(
        buildTagBreakdowns(
          tags: const <Tag>[],
          subjects: _subjects,
          records: <AttendanceRecord>[_mark(tagId: 1)],
        ),
        isEmpty,
      );
    });

    test('a mark pointing at a tag that no longer exists is skipped', () {
      // The foreign key covers the in-app path; a hand-edited import is what
      // this guards. Counting it would put a row under no visible tag.
      final List<TagBreakdown> result = buildTagBreakdowns(
        tags: _tags,
        subjects: _subjects,
        records: <AttendanceRecord>[_mark(tagId: 99)],
      );

      expect(
        result.every((TagBreakdown b) => b.isEmpty),
        isTrue,
      );
    });

    test('the status split is counted per tag, not per subject', () {
      final List<TagBreakdown> result = buildTagBreakdowns(
        tags: _tags,
        subjects: _subjects,
        records: <AttendanceRecord>[
          _mark(day: 1, tagId: 1),
          _mark(day: 2, tagId: 1, status: AttendanceStatus.absent),
          _mark(day: 3, tagId: 1, status: AttendanceStatus.cancelled),
          _mark(day: 4, tagId: 2),
        ],
      );

      final TagBreakdown proxy = _named(result, 'Proxy');
      expect(proxy.total, 3);
      expect(proxy.present, 1);
      expect(proxy.absent, 1);
      expect(proxy.cancelled, 1);
      expect(proxy.summary, '1 present · 1 absent · 1 cancelled');
      expect(_named(result, 'Online').total, 1);
    });

    test('the count label agrees with its noun', () {
      // Caught on the tablet reading "1 classes in one subject".
      final List<TagBreakdown> result = buildTagBreakdowns(
        tags: _tags,
        subjects: _subjects,
        records: <AttendanceRecord>[
          _mark(day: 1, tagId: 1),
          _mark(day: 2, tagId: 2),
          _mark(day: 3, tagId: 2),
        ],
      );

      expect(_named(result, 'Proxy').countLabel, '1 class');
      expect(_named(result, 'Online').countLabel, '2 classes');
    });

    test('the summary names only the statuses that occurred', () {
      final List<TagBreakdown> result = buildTagBreakdowns(
        tags: _tags,
        subjects: _subjects,
        records: <AttendanceRecord>[
          _mark(day: 1, tagId: 1),
          _mark(day: 2, tagId: 1),
        ],
      );

      expect(_named(result, 'Proxy').summary, '2 present');
    });

    test('subject reach counts distinct subjects', () {
      final List<TagBreakdown> result = buildTagBreakdowns(
        tags: _tags,
        subjects: _subjects,
        records: <AttendanceRecord>[
          _mark(day: 1, tagId: 1),
          _mark(day: 2, tagId: 1),
          _mark(day: 3, subjectId: 2, tagId: 1),
        ],
      );

      expect(_named(result, 'Proxy').subjectCount, 2);
    });

    test('marks are newest first, and same-day ones by latest start', () {
      final List<TagBreakdown> result = buildTagBreakdowns(
        tags: _tags,
        subjects: _subjects,
        records: <AttendanceRecord>[
          _mark(day: 1, tagId: 1),
          _mark(day: 5, startMinutes: 540, tagId: 1),
          _mark(day: 5, startMinutes: 660, tagId: 1),
        ],
      );

      final List<TaggedMark> marks = _named(result, 'Proxy').marks;
      expect(marks[0].record.date.day, 5);
      expect(marks[0].record.startMinutes, 660);
      expect(marks[1].record.startMinutes, 540);
      expect(marks[2].record.date.day, 1);
    });

    test('a mark whose subject is gone still counts, with no subject', () {
      // Dropping it would make the tag's total disagree with its own list.
      final List<TagBreakdown> result = buildTagBreakdowns(
        tags: _tags,
        subjects: _subjects,
        records: <AttendanceRecord>[_mark(subjectId: 77, tagId: 1)],
      );

      final TagBreakdown proxy = _named(result, 'Proxy');
      expect(proxy.total, 1);
      expect(proxy.marks.single.subject, isNull);
    });
  });
}
