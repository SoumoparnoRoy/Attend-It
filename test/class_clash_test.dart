import 'package:flutter_test/flutter_test.dart';

import 'package:attend_it/core/date_utils.dart';
import 'package:attend_it/data/models/class_slot.dart';
import 'package:attend_it/data/models/extra_class.dart';
import 'package:attend_it/domain/class_clash.dart';

/// A Monday inside the window every rule below covers.
final DateTime _monday = Dates.fromKey(20260817);
final DateTime _nextMonday = Dates.addDays(_monday, 7);
final DateTime _tuesday = Dates.addDays(_monday, 1);

ClassSlot _slot({
  int id = 1,
  int subjectId = 1,
  int weekday = DateTime.monday,
  int startMinutes = 9 * 60,
  DateTime? startDate,
  DateTime? endDate,
}) {
  return ClassSlot(
    id: id,
    subjectId: subjectId,
    weekday: weekday,
    startMinutes: startMinutes,
    endMinutes: startMinutes + 50,
    startDate: startDate ?? Dates.addDays(_monday, -70),
    endDate: endDate,
  );
}

ExtraClass _extra({
  int? id = 1,
  int subjectId = 1,
  DateTime? date,
  int startMinutes = 9 * 60,
}) {
  return ExtraClass(
    id: id,
    subjectId: subjectId,
    date: date ?? _monday,
    startMinutes: startMinutes,
    endMinutes: startMinutes + 50,
  );
}

void main() {
  group('a one-off class', () {
    test('collides with a weekly occurrence at the same minute', () {
      expect(
        ClassClash.forOneOff(
          slots: <ClassSlot>[_slot()],
          extras: <ExtraClass>[],
          proposed: _extra(id: null),
        ),
        isTrue,
      );
    });

    test('is fine on a day the rule does not cover', () {
      expect(
        ClassClash.forOneOff(
          slots: <ClassSlot>[_slot()],
          extras: <ExtraClass>[],
          proposed: _extra(id: null, date: _tuesday),
        ),
        isFalse,
      );
    });

    test('is fine once the rule has stopped repeating', () {
      expect(
        ClassClash.forOneOff(
          slots: <ClassSlot>[_slot(endDate: Dates.addDays(_monday, -1))],
          extras: <ExtraClass>[],
          proposed: _extra(id: null),
        ),
        isFalse,
      );
    });

    test('is fine before the rule starts', () {
      expect(
        ClassClash.forOneOff(
          slots: <ClassSlot>[_slot(startDate: _nextMonday)],
          extras: <ExtraClass>[],
          proposed: _extra(id: null),
        ),
        isFalse,
      );
    });

    test('is fine at a different start time', () {
      expect(
        ClassClash.forOneOff(
          slots: <ClassSlot>[_slot()],
          extras: <ExtraClass>[],
          proposed: _extra(id: null, startMinutes: 10 * 60),
        ),
        isFalse,
      );
    });

    test('is fine for a different subject', () {
      expect(
        ClassClash.forOneOff(
          slots: <ClassSlot>[_slot()],
          extras: <ExtraClass>[],
          proposed: _extra(id: null, subjectId: 2),
        ),
        isFalse,
      );
    });

    test('collides with another one-off on the same day and minute', () {
      expect(
        ClassClash.forOneOff(
          slots: <ClassSlot>[],
          extras: <ExtraClass>[_extra(id: 7)],
          proposed: _extra(id: null),
        ),
        isTrue,
      );
    });

    test('does not collide with itself when edited', () {
      // Reopening a one-off and saving it unchanged must not be rejected.
      expect(
        ClassClash.forOneOff(
          slots: <ClassSlot>[],
          extras: <ExtraClass>[_extra(id: 7)],
          proposed: _extra(id: 7),
        ),
        isFalse,
      );
    });
  });

  group('a weekly rule', () {
    test('names the date of the one-off it would land on', () {
      expect(
        ClassClash.forWeekly(
          extras: <ExtraClass>[_extra(date: _nextMonday)],
          proposed: _slot(),
        ),
        _nextMonday,
      );
    });

    test('reports the earliest collision when there are several', () {
      expect(
        ClassClash.forWeekly(
          extras: <ExtraClass>[
            _extra(id: 2, date: Dates.addDays(_monday, 14)),
            _extra(id: 1, date: _nextMonday),
          ],
          proposed: _slot(),
        ),
        _nextMonday,
      );
    });

    test('ignores a one-off outside the rule window', () {
      expect(
        ClassClash.forWeekly(
          extras: <ExtraClass>[_extra(date: _nextMonday)],
          proposed: _slot(endDate: _monday),
        ),
        isNull,
      );
    });

    test('ignores a one-off on another weekday', () {
      expect(
        ClassClash.forWeekly(
          extras: <ExtraClass>[_extra(date: _tuesday)],
          proposed: _slot(),
        ),
        isNull,
      );
    });

    test('ignores a one-off at another time or for another subject', () {
      expect(
        ClassClash.forWeekly(
          extras: <ExtraClass>[_extra(startMinutes: 11 * 60)],
          proposed: _slot(),
        ),
        isNull,
      );
      expect(
        ClassClash.forWeekly(
          extras: <ExtraClass>[_extra(subjectId: 2)],
          proposed: _slot(),
        ),
        isNull,
      );
    });
  });
}
