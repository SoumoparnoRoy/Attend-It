import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/app_theme.dart';
import '../../core/date_utils.dart';
import '../../data/models/attendance_status.dart';
import '../../data/models/class_session.dart';
import '../../data/models/class_slot.dart';
import '../../data/settings/app_settings.dart';
import '../../domain/schedule_engine.dart';
import '../../state/providers.dart';
import '../../widgets/common.dart';
import '../subjects/class_editor_sheets.dart';

/// The weekly view: every class, day by day, with the tools to add, edit and
/// remove them.
class TimetableScreen extends ConsumerWidget {
  const TimetableScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final DateTime weekStart = ref.watch(visibleWeekProvider);
    final ScheduleEngine? engine = ref.watch(scheduleEngineProvider);
    final AppSettings settings =
        ref.watch(settingsProvider).value ?? const AppSettings();
    final List<ClassSlot> slots =
        ref.watch(timetableProvider).value?.slots ?? <ClassSlot>[];

    final Map<int, List<ClassSession>> byDay =
        engine?.sessionsForWeekOf(weekStart) ?? <int, List<ClassSession>>{};
    final DateTime thisWeek = Dates.startOfWeek(Dates.today());
    final bool isCurrentWeek = Dates.isSameDay(weekStart, thisWeek);
    final int weekTotal =
        byDay.values.fold<int>(0, (int sum, List<ClassSession> v) => sum + v.length);

    return Scaffold(
      body: SafeArea(
        bottom: false,
        child: CustomScrollView(
          slivers: <Widget>[
            SliverToBoxAdapter(
              child: _WeekHeader(
                weekStart: weekStart,
                isCurrentWeek: isCurrentWeek,
                classCount: weekTotal,
                onPrevious: () =>
                    ref.read(visibleWeekProvider.notifier).shiftWeeks(-1),
                onNext: () =>
                    ref.read(visibleWeekProvider.notifier).shiftWeeks(1),
                onThisWeek: () =>
                    ref.read(visibleWeekProvider.notifier).goToThisWeek(),
              ),
            ),

            if (slots.isEmpty && weekTotal == 0)
              SliverFillRemaining(
                hasScrollBody: false,
                child: Padding(
                  padding: const EdgeInsets.only(bottom: 80),
                  child: EmptyState(
                    icon: Icons.calendar_month_outlined,
                    title: 'Your timetable is empty',
                    message:
                        'Add your weekly classes once and Attend It! will lay out every week for you.',
                    action: FilledButton.icon(
                      onPressed: () => showAddClassSheet(context, ref),
                      icon: const Icon(Icons.add_rounded),
                      label: const Text('Add your first class'),
                    ),
                  ),
                ),
              )
            else
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(
                  AppSpacing.lg,
                  0,
                  AppSpacing.lg,
                  120,
                ),
                sliver: SliverList.builder(
                  itemCount: 7,
                  itemBuilder: (BuildContext context, int index) {
                    final DateTime day = Dates.addDays(weekStart, index);
                    final List<ClassSession> sessions =
                        byDay[Dates.keyOf(day)] ?? const <ClassSession>[];
                    return _DaySection(
                      day: day,
                      sessions: sessions,
                      settings: settings,
                      holidayName: engine?.holidayOn(day)?.name,
                      onAdd: () => showAddClassSheet(
                        context,
                        ref,
                        initialDate: day,
                      ),
                      onTapSession: (ClassSession session) =>
                          _editSession(context, ref, session, slots),
                      onLongPressSession: (ClassSession session) =>
                          showSessionOptions(context, ref, session),
                    );
                  },
                ),
              ),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => showAddClassSheet(context, ref),
        icon: const Icon(Icons.add_rounded),
        label: const Text('Add class'),
      ),
    );
  }

  Future<void> _editSession(
    BuildContext context,
    WidgetRef ref,
    ClassSession session,
    List<ClassSlot> slots,
  ) async {
    if (session.slotId == null) {
      // One-off classes have no rule to edit, so offer the options menu.
      await showSessionOptions(context, ref, session);
      return;
    }
    ClassSlot? slot;
    for (final ClassSlot candidate in slots) {
      if (candidate.id == session.slotId) {
        slot = candidate;
        break;
      }
    }
    if (slot == null || !context.mounted) return;
    await showSlotEditor(context, ref, slot: slot);
  }
}

class _WeekHeader extends StatelessWidget {
  const _WeekHeader({
    required this.weekStart,
    required this.isCurrentWeek,
    required this.classCount,
    required this.onPrevious,
    required this.onNext,
    required this.onThisWeek,
  });

  final DateTime weekStart;
  final bool isCurrentWeek;
  final int classCount;
  final VoidCallback onPrevious;
  final VoidCallback onNext;
  final VoidCallback onThisWeek;

  @override
  Widget build(BuildContext context) {
    final DateTime weekEnd = Dates.addDays(weekStart, 6);
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.lg,
        AppSpacing.lg,
        AppSpacing.lg,
        AppSpacing.lg,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              const Expanded(
                child: Text(
                  'Timetable',
                  style: TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.w800,
                    letterSpacing: -1,
                  ),
                ),
              ),
              if (!isCurrentWeek)
                TextButton(
                  onPressed: onThisWeek,
                  child: const Text('This week'),
                ),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          SurfaceCard(
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.sm,
              vertical: AppSpacing.sm,
            ),
            child: Row(
              children: <Widget>[
                IconButton(
                  onPressed: onPrevious,
                  icon: const Icon(Icons.chevron_left_rounded),
                  color: context.palette.textSecondary,
                ),
                Expanded(
                  child: Column(
                    children: <Widget>[
                      Text(
                        isCurrentWeek ? 'This week' : 'Week of',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 0.8,
                          color: context.palette.textTertiary,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        '${weekStart.day} ${kMonthNamesShort[weekStart.month - 1]} – '
                        '${weekEnd.day} ${kMonthNamesShort[weekEnd.month - 1]}',
                        style: const TextStyle(
                          fontSize: 14.5,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  onPressed: onNext,
                  icon: const Icon(Icons.chevron_right_rounded),
                  color: context.palette.textSecondary,
                ),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(
            classCount == 0
                ? 'No classes this week'
                : '$classCount ${classCount == 1 ? 'class' : 'classes'} this week',
            style: TextStyle(
              fontSize: 12.5,
              color: context.palette.textTertiary,
            ),
          ),
        ],
      ),
    );
  }
}

class _DaySection extends StatelessWidget {
  const _DaySection({
    required this.day,
    required this.sessions,
    required this.settings,
    required this.onAdd,
    required this.onTapSession,
    required this.onLongPressSession,
    this.holidayName,
  });

  final DateTime day;
  final List<ClassSession> sessions;
  final AppSettings settings;
  final VoidCallback onAdd;
  final ValueChanged<ClassSession> onTapSession;
  final ValueChanged<ClassSession> onLongPressSession;
  final String? holidayName;

  @override
  Widget build(BuildContext context) {
    final bool isToday = Dates.isSameDay(day, Dates.today());

    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.xl),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Row(
            children: <Widget>[
              Container(
                width: 6,
                height: 6,
                margin: const EdgeInsets.only(right: AppSpacing.sm),
                decoration: BoxDecoration(
                  color: isToday ? context.palette.accent : Colors.transparent,
                  shape: BoxShape.circle,
                ),
              ),
              Text(
                Dates.weekdayLong(day).toUpperCase(),
                style: TextStyle(
                  fontSize: 11.5,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 1.1,
                  color: isToday ? context.palette.accent : context.palette.textTertiary,
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              Text(
                '${day.day} ${kMonthNamesShort[day.month - 1]}',
                style: TextStyle(
                  fontSize: 11.5,
                  fontWeight: FontWeight.w600,
                  color: context.palette.textTertiary,
                ),
              ),
              const Spacer(),
              IconButton(
                onPressed: onAdd,
                visualDensity: VisualDensity.compact,
                iconSize: 18,
                color: context.palette.textTertiary,
                icon: const Icon(Icons.add_rounded),
                tooltip: 'Add a class on this day',
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          if (holidayName != null)
            _EmptyDayRow(label: holidayName!, icon: Icons.celebration_rounded)
          else if (sessions.isEmpty)
            const _EmptyDayRow(label: 'Free', icon: Icons.remove_rounded)
          else
            for (final ClassSession session in sessions)
              Padding(
                padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                child: _CompactSessionRow(
                  session: session,
                  use24Hour: settings.use24HourTime,
                  onTap: () => onTapSession(session),
                  onLongPress: () => onLongPressSession(session),
                ),
              ),
        ],
      ),
    );
  }
}

class _EmptyDayRow extends StatelessWidget {
  const _EmptyDayRow({required this.label, required this.icon});

  final String label;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.lg,
        vertical: AppSpacing.md,
      ),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
        border: Border.all(color: context.palette.outlineSoft),
      ),
      child: Row(
        children: <Widget>[
          Icon(icon, size: 15, color: context.palette.textTertiary),
          const SizedBox(width: AppSpacing.sm),
          Text(
            label,
            style: TextStyle(
              fontSize: 13,
              color: context.palette.textTertiary,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}

class _CompactSessionRow extends StatelessWidget {
  const _CompactSessionRow({
    required this.session,
    required this.use24Hour,
    required this.onTap,
    required this.onLongPress,
  });

  final ClassSession session;
  final bool use24Hour;
  final VoidCallback onTap;
  final VoidCallback onLongPress;

  @override
  Widget build(BuildContext context) {
    final Color color = session.subject.color;
    final AttendanceStatus? status = session.status;

    return SurfaceCard(
      onTap: onTap,
      onLongPress: onLongPress,
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.md,
        vertical: AppSpacing.md,
      ),
      child: Row(
        children: <Widget>[
          Container(
            width: 3,
            height: 34,
            decoration: BoxDecoration(
              color: color,
              borderRadius: BorderRadius.circular(3),
            ),
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  session.subject.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 14.5,
                    fontWeight: FontWeight.w600,
                    decoration: status == AttendanceStatus.cancelled
                        ? TextDecoration.lineThrough
                        : null,
                    decorationColor: context.palette.textTertiary,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  <String>[
                    Clock.formatRange(
                      session.startMinutes,
                      session.endMinutes,
                      use24Hour: use24Hour,
                    ),
                    if (session.room != null && session.room!.isNotEmpty)
                      session.room!,
                  ].join(' · '),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 12.5,
                    color: context.palette.textTertiary,
                  ),
                ),
              ],
            ),
          ),
          if (session.isExtra)
            Padding(
              padding: EdgeInsets.only(left: AppSpacing.sm),
              child: Pill(label: 'Extra', color: context.palette.cyan),
            ),
          if (status != null)
            Padding(
              padding: const EdgeInsets.only(left: AppSpacing.sm),
              child: Icon(status.icon, size: 17, color: status.colorIn(context.palette)),
            ),
        ],
      ),
    );
  }
}
