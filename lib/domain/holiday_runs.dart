import '../core/date_utils.dart';
import '../data/models/holiday.dart';

/// A stretch of consecutive holidays sharing a name — a Diwali break, a week
/// of exams — as it is listed and deleted.
///
/// A run is not stored. Every holiday is still one row per date, which is what
/// keeps the schedule engine a map lookup and lets a single day be removed out
/// of the middle of a break. This is the display side of that.
class HolidayRun {
  const HolidayRun({required this.name, required this.days});

  final String name;

  /// Ascending, always at least one, and consecutive by construction.
  final List<Holiday> days;

  DateTime get start => days.first.date;

  DateTime get end => days.last.date;

  int get length => days.length;

  bool get isSingleDay => length == 1;

  List<int> get ids => <int>[
        for (final Holiday day in days)
          if (day.id != null) day.id!,
      ];

  /// "11 Aug 2026", or "20 Oct – 29 Oct 2026" with the year said once.
  String get dateLabel {
    if (isSingleDay) return Dates.formatFull(start);
    final String from = start.year == end.year
        ? '${start.day} ${kMonthNamesShort[start.month - 1]}'
        : Dates.formatFull(start);
    return '$from – ${Dates.formatFull(end)}';
  }

  String get lengthLabel => isSingleDay ? '1 day' : '$length days';
}

/// Collapses the holiday list into runs for display.
///
/// Two days join a run when they are named the same and sit one day apart, so
/// a break entered as a range reads as one line while two unrelated holidays
/// that happen to be adjacent stay separate.
List<HolidayRun> buildHolidayRuns(List<Holiday> holidays) {
  if (holidays.isEmpty) return const <HolidayRun>[];

  final List<Holiday> sorted = <Holiday>[...holidays]
    ..sort((Holiday a, Holiday b) => Dates.keyOf(a.date) - Dates.keyOf(b.date));

  final List<HolidayRun> runs = <HolidayRun>[];
  List<Holiday> current = <Holiday>[sorted.first];

  for (final Holiday holiday in sorted.skip(1)) {
    final Holiday previous = current.last;
    final bool continues = holiday.name == previous.name &&
        Dates.daysBetween(previous.date, holiday.date) == 1;
    if (continues) {
      current.add(holiday);
      continue;
    }
    runs.add(HolidayRun(name: previous.name, days: current));
    current = <Holiday>[holiday];
  }
  runs.add(HolidayRun(name: current.last.name, days: current));

  return runs;
}
