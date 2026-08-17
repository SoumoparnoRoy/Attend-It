import 'package:flutter/foundation.dart';

/// The day divided into uniform blocks of one lecture each.
///
/// Three numbers rather than a table of named periods, because a period-based
/// timetable has no arbitrary segments: every class is a whole number of blocks,
/// a double lab is two of them, and a free period is a block with nothing in it.
/// The shape of the day follows from where it starts, where it ends and how long
/// one block runs.
///
/// Classes still store real start and end minutes, so the schedule engine, the
/// stats and old backups are untouched. This is a lens, not a second source of
/// truth.
@immutable
class DayGrid {
  const DayGrid({
    required this.dayStartMinutes,
    required this.dayEndMinutes,
    required this.blockMinutes,
  });

  /// The day has not been divided up, which is where every install starts.
  static const DayGrid none = DayGrid(
    dayStartMinutes: 0,
    dayEndMinutes: 0,
    blockMinutes: 0,
  );

  final int dayStartMinutes;
  final int dayEndMinutes;
  final int blockMinutes;

  int get blockCount {
    if (blockMinutes <= 0) return 0;
    final int span = dayEndMinutes - dayStartMinutes;
    if (span <= 0) return 0;
    return span ~/ blockMinutes;
  }

  bool get isConfigured => blockCount > 0;

  /// Minutes at the end of the day too short to hold another block. Surfaced in
  /// Settings rather than silently swallowed, because a 9:00–17:00 day on
  /// 50-minute blocks losing its last 40 minutes should be the user's choice.
  int get leftoverMinutes {
    if (!isConfigured) return 0;
    return (dayEndMinutes - dayStartMinutes) % blockMinutes;
  }

  int startOf(int index) => dayStartMinutes + index * blockMinutes;

  int endOf(int index) => startOf(index) + blockMinutes;

  /// Rounds to the nearest block, so a 95-minute length typed by hand still
  /// reads as the two blocks it meant. Never less than one — a class always
  /// occupies the block it starts in.
  int blocksFor(int durationMinutes) {
    if (!isConfigured) return 1;
    final int blocks = (durationMinutes / blockMinutes).round();
    return blocks < 1 ? 1 : blocks;
  }

  int snapDuration(int durationMinutes) =>
      isConfigured ? blocksFor(durationMinutes) * blockMinutes : durationMinutes;

  /// Lets the UI say "2 blocks" only when that is exactly true, rather than
  /// rounding on the user's behalf.
  bool isWholeBlocks(int durationMinutes) =>
      isConfigured &&
      durationMinutes > 0 &&
      durationMinutes % blockMinutes == 0;

  /// The block containing [startMinutes], or null outside the day.
  ///
  /// Floors rather than requiring a boundary: classes created before the grid
  /// existed need not sit on one, and showing them where they really are beats
  /// moving anyone's data to tidy the picture.
  int? indexOf(int startMinutes) {
    if (!isConfigured) return null;
    if (startMinutes < dayStartMinutes) return null;
    final int index = (startMinutes - dayStartMinutes) ~/ blockMinutes;
    return index >= blockCount ? null : index;
  }

  bool isAligned(int startMinutes) =>
      isConfigured &&
      startMinutes >= dayStartMinutes &&
      (startMinutes - dayStartMinutes) % blockMinutes == 0;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is DayGrid &&
          other.dayStartMinutes == dayStartMinutes &&
          other.dayEndMinutes == dayEndMinutes &&
          other.blockMinutes == blockMinutes);

  @override
  int get hashCode =>
      Object.hash(dayStartMinutes, dayEndMinutes, blockMinutes);
}
