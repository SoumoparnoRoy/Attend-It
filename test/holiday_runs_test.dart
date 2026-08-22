import 'package:flutter_test/flutter_test.dart';

import 'package:zeolite/data/models/holiday.dart';
import 'package:zeolite/domain/holiday_runs.dart';

int _nextId = 1;

Holiday _day(int day, String name, {int month = 10}) =>
    Holiday(id: _nextId++, date: DateTime(2026, month, day), name: name);

void main() {
  setUp(() => _nextId = 1);

  group('collapsing holidays into runs', () {
    test('an empty list has no runs', () {
      expect(buildHolidayRuns(<Holiday>[]), isEmpty);
    });

    test('consecutive days with the same name are one run', () {
      final List<HolidayRun> runs = buildHolidayRuns(<Holiday>[
        _day(20, 'Diwali'),
        _day(21, 'Diwali'),
        _day(22, 'Diwali'),
      ]);

      expect(runs, hasLength(1));
      expect(runs.single.length, 3);
      expect(runs.single.start, DateTime(2026, 10, 20));
      expect(runs.single.end, DateTime(2026, 10, 22));
      expect(runs.single.ids, <int>[1, 2, 3]);
    });

    test('a gap in the dates splits the run', () {
      final List<HolidayRun> runs = buildHolidayRuns(<Holiday>[
        _day(20, 'Diwali'),
        _day(21, 'Diwali'),
        _day(24, 'Diwali'),
      ]);

      expect(runs.map((HolidayRun r) => r.length), <int>[2, 1]);
    });

    test('adjacent days with different names stay separate', () {
      final List<HolidayRun> runs = buildHolidayRuns(<Holiday>[
        _day(20, 'Diwali'),
        _day(21, 'Founder\'s Day'),
      ]);

      expect(runs, hasLength(2));
      expect(runs.first.name, 'Diwali');
      expect(runs.last.name, 'Founder\'s Day');
    });

    test('runs are built in date order however the list arrives', () {
      final List<HolidayRun> runs = buildHolidayRuns(<Holiday>[
        _day(22, 'Diwali'),
        _day(20, 'Diwali'),
        _day(21, 'Diwali'),
      ]);

      expect(runs, hasLength(1));
      expect(runs.single.start, DateTime(2026, 10, 20));
    });

    test('a run spans the month boundary', () {
      final List<HolidayRun> runs = buildHolidayRuns(<Holiday>[
        _day(31, 'Break'),
        _day(1, 'Break', month: 11),
      ]);

      expect(runs, hasLength(1));
      expect(runs.single.length, 2);
    });

    test('every holiday survives the grouping', () {
      final List<Holiday> holidays = <Holiday>[
        _day(20, 'Diwali'),
        _day(21, 'Diwali'),
        _day(25, 'Strike'),
        _day(28, 'Exams'),
        _day(29, 'Exams'),
      ];

      final int grouped = buildHolidayRuns(holidays)
          .fold(0, (int sum, HolidayRun r) => sum + r.length);

      expect(grouped, holidays.length);
    });
  });

  group('how a run reads', () {
    test('a single day is not called a range', () {
      final HolidayRun run = buildHolidayRuns(<Holiday>[
        _day(20, 'Diwali'),
      ]).single;

      expect(run.isSingleDay, isTrue);
      expect(run.dateLabel, '20 Oct 2026');
      expect(run.lengthLabel, '1 day');
    });

    test('a range within one year says the year once', () {
      final HolidayRun run = buildHolidayRuns(<Holiday>[
        _day(20, 'Diwali'),
        _day(21, 'Diwali'),
      ]).single;

      expect(run.dateLabel, '20 Oct – 21 Oct 2026');
      expect(run.lengthLabel, '2 days');
    });

    test('a range crossing new year names both years', () {
      final List<Holiday> holidays = <Holiday>[
        Holiday(id: 1, date: DateTime(2026, 12, 31), name: 'Winter'),
        Holiday(id: 2, date: DateTime(2027, 1, 1), name: 'Winter'),
      ];

      expect(
        buildHolidayRuns(holidays).single.dateLabel,
        '31 Dec 2026 – 1 Jan 2027',
      );
    });
  });
}
