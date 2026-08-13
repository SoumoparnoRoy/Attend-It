import 'package:flutter_test/flutter_test.dart';

import 'package:attend_it/core/app_theme.dart';
import 'package:attend_it/core/date_utils.dart';
import 'package:attend_it/data/models/attendance_record.dart';
import 'package:attend_it/data/models/attendance_status.dart';
import 'package:attend_it/data/models/class_session.dart';
import 'package:attend_it/data/models/subject.dart';
import 'package:attend_it/domain/attendance_log.dart';

const Subject _physics = Subject(
  id: 1,
  name: 'Physics',
  colorValue: AppColors.defaultSubjectColor,
);

const Subject _maths = Subject(
  id: 2,
  name: 'Mathematics',
  colorValue: AppColors.defaultSubjectColor,
);

ClassSession _session(
  DateTime date,
  int startMinutes, {
  Subject subject = _physics,
  int? endMinutes,
  String? room,
}) {
  return ClassSession(
    subject: subject,
    date: date,
    startMinutes: startMinutes,
    endMinutes: endMinutes ?? startMinutes + 60,
    room: room,
  );
}

AttendanceRecord _record(
  DateTime date,
  int startMinutes, {
  int subjectId = 1,
  AttendanceStatus status = AttendanceStatus.present,
}) {
  return AttendanceRecord(
    subjectId: subjectId,
    date: date,
    startMinutes: startMinutes,
    status: status,
  );
}

void main() {
  final DateTime day1 = DateTime(2026, 3, 2);
  final DateTime day2 = DateTime(2026, 3, 4);
  final DateTime day3 = DateTime(2026, 3, 6);

  group('merging occurrences and records', () {
    test('nothing in, nothing out', () {
      expect(
        buildAttendanceLog(
          subjectId: 1,
          pastSessions: const <ClassSession>[],
          records: const <AttendanceRecord>[],
        ),
        isEmpty,
      );
    });

    test('an occurrence with a mark carries that mark', () {
      final List<AttendanceLogEntry> log = buildAttendanceLog(
        subjectId: 1,
        pastSessions: <ClassSession>[_session(day1, 540)],
        records: <AttendanceRecord>[
          _record(day1, 540, status: AttendanceStatus.absent),
        ],
      );

      expect(log, hasLength(1));
      expect(log.single.status, AttendanceStatus.absent);
      expect(log.single.isOrphaned, isFalse);
      expect(log.single.needsMarking, isFalse);
      expect(log.single.endMinutes, 600);
    });

    test('an occurrence with no mark is reported as needing one', () {
      final List<AttendanceLogEntry> log = buildAttendanceLog(
        subjectId: 1,
        pastSessions: <ClassSession>[_session(day1, 540, room: 'LH-3')],
        records: const <AttendanceRecord>[],
      );

      expect(log.single.status, isNull);
      expect(log.single.needsMarking, isTrue);
      expect(log.single.isMarked, isFalse);
      expect(log.single.room, 'LH-3');
    });

    test('a mark with no occurrence survives as an orphan', () {
      // This is what deleting a weekly class leaves behind: the rule is gone
      // but the mark is still in the database and still counts.
      final List<AttendanceLogEntry> log = buildAttendanceLog(
        subjectId: 1,
        pastSessions: const <ClassSession>[],
        records: <AttendanceRecord>[_record(day1, 540)],
      );

      expect(log, hasLength(1));
      expect(log.single.isOrphaned, isTrue);
      expect(log.single.status, AttendanceStatus.present);
      // The rule that defined the length is gone, so there is no end time.
      expect(log.single.endMinutes, isNull);
    });

    test('an occurrence and an orphan can coexist on the same day', () {
      final List<AttendanceLogEntry> log = buildAttendanceLog(
        subjectId: 1,
        pastSessions: <ClassSession>[_session(day1, 540)],
        records: <AttendanceRecord>[
          _record(day1, 540),
          _record(day1, 840, status: AttendanceStatus.cancelled),
        ],
      );

      expect(log, hasLength(2));
      // Later start time sorts first within a day.
      expect(log.first.startMinutes, 840);
      expect(log.first.isOrphaned, isTrue);
      expect(log.last.isOrphaned, isFalse);
    });

    test('the same occurrence is never listed twice', () {
      final List<AttendanceLogEntry> log = buildAttendanceLog(
        subjectId: 1,
        pastSessions: <ClassSession>[
          _session(day1, 540),
          _session(day1, 540),
        ],
        records: const <AttendanceRecord>[],
      );

      expect(log, hasLength(1));
    });
  });

  group('scoping to one subject', () {
    test('other subjects\' occurrences are excluded', () {
      final List<AttendanceLogEntry> log = buildAttendanceLog(
        subjectId: 1,
        pastSessions: <ClassSession>[
          _session(day1, 540),
          _session(day1, 600, subject: _maths),
        ],
        records: const <AttendanceRecord>[],
      );

      expect(log, hasLength(1));
      expect(log.single.startMinutes, 540);
    });

    test('other subjects\' marks never appear as orphans', () {
      final List<AttendanceLogEntry> log = buildAttendanceLog(
        subjectId: 1,
        pastSessions: const <ClassSession>[],
        records: <AttendanceRecord>[_record(day1, 540, subjectId: 2)],
      );

      expect(log, isEmpty);
    });
  });

  group('ordering', () {
    test('newest first, because recent mistakes are the ones being fixed', () {
      final List<AttendanceLogEntry> log = buildAttendanceLog(
        subjectId: 1,
        pastSessions: <ClassSession>[
          _session(day1, 540),
          _session(day3, 540),
          _session(day2, 540),
        ],
        records: const <AttendanceRecord>[],
      );

      expect(
        log.map((AttendanceLogEntry e) => Dates.keyOf(e.date)).toList(),
        <int>[
          Dates.keyOf(day3),
          Dates.keyOf(day2),
          Dates.keyOf(day1),
        ],
      );
    });

    test('within a day, the later class comes first', () {
      final List<AttendanceLogEntry> log = buildAttendanceLog(
        subjectId: 1,
        pastSessions: <ClassSession>[
          _session(day1, 540),
          _session(day1, 900),
          _session(day1, 720),
        ],
        records: const <AttendanceRecord>[],
      );

      expect(
        log.map((AttendanceLogEntry e) => e.startMinutes).toList(),
        <int>[900, 720, 540],
      );
    });
  });
}
