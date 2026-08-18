import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:zeolite/core/app_theme.dart';
import 'package:zeolite/core/date_utils.dart';
import 'package:zeolite/data/models/attendance_record.dart';
import 'package:zeolite/data/models/class_category.dart';
import 'package:zeolite/data/models/class_slot.dart';
import 'package:zeolite/data/models/extra_class.dart';
import 'package:zeolite/data/models/holiday.dart';
import 'package:zeolite/data/models/subject.dart';
import 'package:zeolite/data/settings/app_settings.dart';
import 'package:zeolite/features/timetable/week_grid_view.dart';
import 'package:zeolite/state/providers.dart';

class _StaticSettings extends SettingsController {
  _StaticSettings(this.settings);

  final AppSettings settings;

  @override
  Future<AppSettings> build() async => settings;
}

/// 9:00–17:00 on 50-minute blocks — nine blocks, so a Lab of two of them is
/// 1h 40m and lands on 9:00–10:40.
const AppSettings _settings = AppSettings(
  onboarded: true,
  defaultClassDurationMinutes: 50,
  dayStartMinutes: 9 * 60,
  dayEndMinutes: 17 * 60,
  blockMinutes: 50,
);

TimetableData _fixture({List<ClassSlot> slots = const <ClassSlot>[]}) =>
    TimetableData(
      categories: const <ClassCategory>[
        ClassCategory(id: 1, name: 'Lab', defaultDurationMinutes: 100),
      ],
      subjects: const <Subject>[
        Subject(
          id: 1,
          name: 'Physics',
          teacher: 'Dr Rao',
          categoryId: 1,
          colorValue: AppColors.defaultSubjectColor,
        ),
      ],
      slots: slots,
      extras: <ExtraClass>[],
      holidays: const <Holiday>[],
      records: <AttendanceRecord>[],
    );

Widget _app(TimetableData data, {AppSettings settings = _settings}) {
  return ProviderScope(
    overrides: [
      timetableProvider.overrideWith((Ref ref) async => data),
      settingsProvider.overrideWith(() => _StaticSettings(settings)),
    ],
    child: MaterialApp(
      theme: AppTheme.dark(),
      home: Scaffold(
        body: SingleChildScrollView(
          child: WeekGridView(weekStart: Dates.startOfWeek(Dates.today())),
        ),
      ),
    ),
  );
}

void main() {
  testWidgets('lays out one row per block', (WidgetTester tester) async {
    await tester.pumpWidget(_app(_fixture()));
    await tester.pumpAndSettle();

    expect(find.text('1'), findsOneWidget);
    expect(find.text('9'), findsOneWidget);
    // Nine blocks and no tenth.
    expect(find.text('10'), findsNothing);
    expect(find.text('9:00 am'), findsOneWidget);
    expect(find.text('3:40 pm'), findsOneWidget);
  });

  testWidgets('each empty cell opens its own block, not the last one',
      (WidgetTester tester) async {
    await tester.pumpWidget(_app(_fixture()));
    await tester.pumpAndSettle();

    // Regression: the cell callbacks used to close over the loop variable, so
    // every cell in the column reported the index the loop finished on.
    await tester.tap(find.byIcon(Icons.add_rounded).first);
    await tester.pumpAndSettle();

    expect(find.text('Monday · block 1'), findsOneWidget);
    expect(find.text('9:00 am – 9:50 am'), findsOneWidget);
  });

  testWidgets('a two-block class is twice the height of an empty cell',
      (WidgetTester tester) async {
    await tester.pumpWidget(
      _app(
        _fixture(
          slots: <ClassSlot>[
            ClassSlot(
              id: 1,
              subjectId: 1,
              weekday: DateTime.monday,
              startMinutes: 9 * 60,
              endMinutes: 9 * 60 + 100,
              room: 'PHY-LAB',
              startDate: Dates.addDays(Dates.today(), -30),
            ),
          ],
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Physics'), findsOneWidget);
    expect(find.text('PHY-LAB'), findsOneWidget);

    final double tall = tester.getSize(find.text('Physics').first).height;
    expect(tall, greaterThan(0));
    // Two blocks plus the gap between them.
    final Finder tile = find.ancestor(
      of: find.text('Physics'),
      matching: find.byType(Material),
    );
    expect(tester.getSize(tile.first).height, greaterThan(100));
  });

  testWidgets('a class off the block boundary shows its real time',
      (WidgetTester tester) async {
    await tester.pumpWidget(
      _app(
        _fixture(
          slots: <ClassSlot>[
            ClassSlot(
              id: 1,
              subjectId: 1,
              weekday: DateTime.monday,
              // 9:30 is inside block 1 but not on its edge.
              startMinutes: 9 * 60 + 30,
              endMinutes: 10 * 60 + 30,
              startDate: Dates.addDays(Dates.today(), -30),
            ),
          ],
        ),
      ),
    );
    await tester.pumpAndSettle();

    // Flagged rather than silently drawn as if it started at 9:00.
    expect(find.text('9:30 am'), findsOneWidget);
  });

  testWidgets('without a block length the grid explains itself instead',
      (WidgetTester tester) async {
    await tester.pumpWidget(
      _app(
        _fixture(),
        settings: const AppSettings(onboarded: true),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Divide your day up first'), findsOneWidget);
  });
}
