import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/app_theme.dart';
import '../../core/date_utils.dart';
import '../../data/models/attendance_status.dart';
import '../../data/models/class_session.dart';
import '../../domain/day_grid.dart';
import '../../domain/schedule_engine.dart';
import '../../state/providers.dart';
import '../../widgets/common.dart';
import '../subjects/class_editor_sheets.dart';

/// The week as a grid: uniform lecture blocks down the side, weekdays across.
///
/// Laid out as a row of per-day columns rather than a column of rows, because a
/// class spanning several blocks is then simply a taller tile in one column.
/// Every column sums to the same height, so the blocks stay aligned across days
/// without any of the arithmetic a row-spanning table would need.
class WeekGridView extends ConsumerWidget {
  const WeekGridView({super.key, required this.weekStart});

  final DateTime weekStart;

  static const double _blockHeight = 58;
  static const double _gap = AppSpacing.xs;
  static const double _gutterWidth = 58;
  static const double _minColumnWidth = 92;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final DayGrid grid = ref.watch(dayGridProvider);
    final ScheduleEngine? engine = ref.watch(scheduleEngineProvider);
    final bool use24Hour =
        ref.watch(settingsProvider).value?.use24HourTime ?? false;

    if (!grid.isConfigured) return const _NotConfigured();

    final Map<int, List<ClassSession>> byDay =
        engine?.sessionsForWeekOf(weekStart) ?? <int, List<ClassSession>>{};

    return LayoutBuilder(
      builder: (BuildContext context, BoxConstraints constraints) {
        final double natural =
            (constraints.maxWidth - _gutterWidth) / 7 - _gap;
        final double columnWidth =
            natural < _minColumnWidth ? _minColumnWidth : natural;

        return SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              _HeaderRow(
                weekStart: weekStart,
                columnWidth: columnWidth,
                gutterWidth: _gutterWidth,
                gap: _gap,
              ),
              const SizedBox(height: _gap),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  _TimeGutter(
                    grid: grid,
                    use24Hour: use24Hour,
                    blockHeight: _blockHeight,
                    gap: _gap,
                    width: _gutterWidth,
                  ),
                  for (int i = 0; i < 7; i++) ...<Widget>[
                    const SizedBox(width: _gap),
                    SizedBox(
                      width: columnWidth,
                      child: _DayColumn(
                        date: Dates.addDays(weekStart, i),
                        sessions: byDay[Dates.keyOf(Dates.addDays(weekStart, i))] ??
                            const <ClassSession>[],
                        grid: grid,
                        use24Hour: use24Hour,
                        blockHeight: _blockHeight,
                        gap: _gap,
                      ),
                    ),
                  ],
                ],
              ),
            ],
          ),
        );
      },
    );
  }
}

/// Shown until the day has been divided into blocks, since without a block
/// length there is no grid to draw.
class _NotConfigured extends StatelessWidget {
  const _NotConfigured();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.xxl),
      child: EmptyState(
        icon: Icons.grid_view_rounded,
        title: 'Divide your day up first',
        message: 'The grid needs to know when your day starts and ends and how '
            'long one lecture runs. Set that in Settings → The teaching day, '
            'then fill the grid in by tapping the empty blocks.',
      ),
    );
  }
}

class _HeaderRow extends StatelessWidget {
  const _HeaderRow({
    required this.weekStart,
    required this.columnWidth,
    required this.gutterWidth,
    required this.gap,
  });

  final DateTime weekStart;
  final double columnWidth;
  final double gutterWidth;
  final double gap;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: <Widget>[
        SizedBox(width: gutterWidth),
        for (int i = 0; i < 7; i++) ...<Widget>[
          SizedBox(width: gap),
          SizedBox(
            width: columnWidth,
            child: _DayHeader(date: Dates.addDays(weekStart, i)),
          ),
        ],
      ],
    );
  }
}

class _DayHeader extends StatelessWidget {
  const _DayHeader({required this.date});

  final DateTime date;

  @override
  Widget build(BuildContext context) {
    final bool isToday = Dates.isSameDay(date, Dates.today());
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 6),
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: isToday
            ? context.palette.accent.withValues(alpha: 0.14)
            : Colors.transparent,
        borderRadius: BorderRadius.circular(AppSpacing.radiusSm),
      ),
      child: Column(
        children: <Widget>[
          Text(
            kWeekdayNamesShort[date.weekday - 1].toUpperCase(),
            style: TextStyle(
              fontSize: 10.5,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.8,
              color: isToday
                  ? context.palette.accent
                  : context.palette.textTertiary,
            ),
          ),
          Text(
            '${date.day}',
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w700,
              color: isToday
                  ? context.palette.accent
                  : context.palette.textSecondary,
            ),
          ),
        ],
      ),
    );
  }
}

class _TimeGutter extends StatelessWidget {
  const _TimeGutter({
    required this.grid,
    required this.use24Hour,
    required this.blockHeight,
    required this.gap,
    required this.width,
  });

  final DayGrid grid;
  final bool use24Hour;
  final double blockHeight;
  final double gap;
  final double width;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: width,
      child: Column(
        children: <Widget>[
          for (int i = 0; i < grid.blockCount; i++) ...<Widget>[
            if (i > 0) SizedBox(height: gap),
            SizedBox(
              height: blockHeight,
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: <Widget>[
                  Text(
                    '${i + 1}',
                    style: TextStyle(
                      fontSize: 12.5,
                      fontWeight: FontWeight.w800,
                      color: context.palette.textSecondary,
                    ),
                  ),
                  Text(
                    Clock.format(grid.startOf(i), use24Hour: use24Hour),
                    style: TextStyle(
                      fontSize: 9.5,
                      fontWeight: FontWeight.w600,
                      color: context.palette.textTertiary,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}

/// One weekday: a tile per class, an empty cell per free block.
class _DayColumn extends ConsumerWidget {
  const _DayColumn({
    required this.date,
    required this.sessions,
    required this.grid,
    required this.use24Hour,
    required this.blockHeight,
    required this.gap,
  });

  final DateTime date;
  final List<ClassSession> sessions;
  final DayGrid grid;
  final bool use24Hour;
  final double blockHeight;
  final double gap;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Group by the block each class starts in. Two classes in one block do
    // happen — a clash, or a subject entered twice — so a cell holds a list
    // rather than a single session.
    final Map<int, List<ClassSession>> byBlock = <int, List<ClassSession>>{};
    for (final ClassSession session in sessions) {
      final int? index = grid.indexOf(session.startMinutes);
      if (index == null) continue; // Outside the configured day.
      byBlock.putIfAbsent(index, () => <ClassSession>[]).add(session);
    }

    final List<Widget> cells = <Widget>[];
    int block = 0;
    while (block < grid.blockCount) {
      // Copied out of the loop variable before any closure captures it — a
      // callback that closed over `block` itself would read whatever the loop
      // had advanced to by the time it ran, which is one past the last block.
      final int index = block;
      final List<ClassSession>? here = byBlock[index];
      if (cells.isNotEmpty) cells.add(SizedBox(height: gap));

      if (here == null) {
        cells.add(
          SizedBox(
            height: blockHeight,
            child: _EmptyCell(
              onTap: () => showBlockClassEditor(
                context,
                ref,
                date: date,
                blockIndex: index,
              ),
            ),
          ),
        );
        block += 1;
        continue;
      }

      // A cell is as tall as its longest class, clamped to the end of the day
      // so the column cannot outgrow its neighbours.
      int span = 1;
      for (final ClassSession session in here) {
        final int blocks = grid.blocksFor(session.durationMinutes);
        if (blocks > span) span = blocks;
      }
      final int remaining = grid.blockCount - index;
      if (span > remaining) span = remaining;

      cells.add(
        SizedBox(
          height: blockHeight * span + gap * (span - 1),
          child: Column(
            children: <Widget>[
              for (final ClassSession session in here)
                Expanded(
                  child: Padding(
                    padding: EdgeInsets.only(
                      bottom: session == here.last ? 0 : 2,
                    ),
                    child: _ClassCell(
                      session: session,
                      offGrid: !grid.isAligned(session.startMinutes),
                      use24Hour: use24Hour,
                      onTap: () => showSessionEditor(context, ref, session),
                      onLongPress: () =>
                          showSessionOptions(context, ref, session),
                    ),
                  ),
                ),
            ],
          ),
        ),
      );
      block += span;
    }

    return Column(children: cells);
  }
}

class _EmptyCell extends StatelessWidget {
  const _EmptyCell({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(AppSpacing.radiusSm),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppSpacing.radiusSm),
        child: DecoratedBox(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(AppSpacing.radiusSm),
            border: Border.all(color: context.palette.outlineSoft),
          ),
          child: Center(
            child: Icon(
              Icons.add_rounded,
              size: 15,
              color: context.palette.textTertiary.withValues(alpha: 0.5),
            ),
          ),
        ),
      ),
    );
  }
}

class _ClassCell extends StatelessWidget {
  const _ClassCell({
    required this.session,
    required this.offGrid,
    required this.use24Hour,
    required this.onTap,
    required this.onLongPress,
  });

  final ClassSession session;

  /// The class does not start on a block boundary — usually because it was
  /// created before the grid existed. Flagged rather than silently moved.
  final bool offGrid;

  final bool use24Hour;
  final VoidCallback onTap;
  final VoidCallback onLongPress;

  @override
  Widget build(BuildContext context) {
    final Color color = session.subject.color;
    final AttendanceStatus? status = session.status;
    final bool cancelled = status == AttendanceStatus.cancelled;

    return Material(
      color: color.withValues(alpha: cancelled ? 0.08 : 0.18),
      borderRadius: BorderRadius.circular(AppSpacing.radiusSm),
      child: InkWell(
        onTap: onTap,
        onLongPress: onLongPress,
        borderRadius: BorderRadius.circular(AppSpacing.radiusSm),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 5),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(AppSpacing.radiusSm),
            border: Border.all(color: color.withValues(alpha: 0.5)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Row(
                children: <Widget>[
                  Expanded(
                    child: Text(
                      session.subject.name,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 11.5,
                        fontWeight: FontWeight.w700,
                        height: 1.15,
                        color: context.palette.textPrimary,
                        decoration:
                            cancelled ? TextDecoration.lineThrough : null,
                        decorationColor: context.palette.textTertiary,
                      ),
                    ),
                  ),
                  if (status != null)
                    Icon(
                      status.icon,
                      size: 12,
                      color: status.colorIn(context.palette),
                    ),
                ],
              ),
              const Spacer(),
              Text(
                <String>[
                  if (offGrid)
                    Clock.format(session.startMinutes, use24Hour: use24Hour),
                  if (session.room != null && session.room!.isNotEmpty)
                    session.room!,
                ].join(' · '),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w600,
                  color: offGrid
                      ? context.palette.warning
                      : context.palette.textTertiary,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
