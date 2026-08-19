import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/app_theme.dart';
import '../../core/date_utils.dart';
import '../../data/models/attendance_status.dart';
import '../../data/models/class_session.dart';
import '../../data/models/holiday.dart';
import '../../data/models/tag.dart';
import '../../data/settings/app_settings.dart';
import '../../domain/attendance_stats.dart';
import '../../domain/schedule_engine.dart';
import '../../services/notification_service.dart';
import '../../state/providers.dart';
import '../../widgets/common.dart';
import '../../widgets/tag_picker.dart';
import '../subjects/class_editor_sheets.dart';
import '../timetable/week_grid_view.dart';
import 'session_card.dart';
import 'week_strip.dart';

/// Per-day dots for the date strip: how many classes, and whether any of them
/// are still waiting to be marked.
///
/// Computed once per data change rather than on every scroll frame.
final dayMarkersProvider = Provider<Map<int, DayMarker>>((ref) {
  final ScheduleEngine? engine = ref.watch(scheduleEngineProvider);
  if (engine == null) return const <int, DayMarker>{};

  final DateTime from = Dates.addDays(Dates.today(), -60);
  final DateTime to = Dates.addDays(Dates.today(), 120);
  final Map<int, List<ClassSession>> byDay =
      engine.sessionsByDayBetween(from, to);

  return <int, DayMarker>{
    for (final MapEntry<int, List<ClassSession>> entry in byDay.entries)
      entry.key: DayMarker(
        count: entry.value.length,
        hasUnmarked:
            entry.value.any((ClassSession s) => s.needsMarking),
        color: entry.value.first.subject.color,
      ),
  };
});

/// The home screen: what is on today, and one tap to mark each class.
class TodayScreen extends ConsumerWidget {
  const TodayScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final DateTime selected = ref.watch(selectedDateProvider);
    final List<ClassSession> sessions =
        ref.watch(selectedDaySessionsProvider);
    final AppSettings settings =
        ref.watch(settingsProvider).value ?? const AppSettings();
    final OverallStats stats = ref.watch(statsProvider);
    final ScheduleEngine? engine = ref.watch(scheduleEngineProvider);
    final Map<int, DayMarker> markers = ref.watch(dayMarkersProvider);
    final List<ClassSession> unmarked = ref.watch(unmarkedSessionsProvider);
    final TimetableData? data = ref.watch(timetableProvider).value;
    final HomeView view = ref.watch(homeViewProvider);
    final bool isToday = Dates.isSameDay(selected, Dates.today());
    // The grid follows whichever day you were looking at, so switching views
    // does not lose your place and needs no state of its own.
    final DateTime gridWeek = Dates.startOfWeek(selected);

    final Holiday? holiday = engine?.holidayOn(selected);
    final bool outsideSemester = engine?.isOutsideSemester(selected) ?? false;
    final int unmarkedToday =
        sessions.where((ClassSession s) => s.needsMarking).length;

    // Warnings the notification tray is no longer carrying have to surface
    // somewhere, so raise them here once the frame is on screen. Showing it
    // post-frame keeps the dialog out of the build phase, and the announced
    // set makes a rebuild a no-op rather than a second popup.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (context.mounted) _showPendingAlerts(context, ref);
      // Due at most once a day, and a no-op the rest of the time — the check is
      // a date comparison, not an export.
      ref.read(actionsProvider).maybeRunAutoBackup();
    });

    return Scaffold(
      body: SafeArea(
        bottom: false,
        child: RefreshIndicator(
          color: context.palette.accent,
          backgroundColor: context.palette.surfaceHigh,
          onRefresh: () async => ref.invalidate(timetableProvider),
          child: CustomScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            slivers: <Widget>[
              SliverToBoxAdapter(
                child: _Header(
                  selected: selected,
                  isToday: isToday,
                  view: view,
                  onJumpToToday: () =>
                      ref.read(selectedDateProvider.notifier).goToToday(),
                  onToggleView: () =>
                      ref.read(homeViewProvider.notifier).toggle(),
                ),
              ),
              if (view == HomeView.day)
                SliverToBoxAdapter(
                  child: WeekStrip(
                    selected: selected,
                    markers: markers,
                    onSelected: (DateTime date) =>
                        ref.read(selectedDateProvider.notifier).select(date),
                  ),
                ),
              const SliverToBoxAdapter(child: SizedBox(height: AppSpacing.lg)),

              if (view == HomeView.grid) ...<Widget>[
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(
                    AppSpacing.lg,
                    0,
                    AppSpacing.lg,
                    AppSpacing.md,
                  ),
                  sliver: SliverToBoxAdapter(
                    child: _GridWeekNav(
                      weekStart: gridWeek,
                      onShift: (int weeks) => ref
                          .read(selectedDateProvider.notifier)
                          .shiftDays(weeks * 7),
                    ),
                  ),
                ),
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(
                    AppSpacing.lg,
                    0,
                    AppSpacing.lg,
                    120,
                  ),
                  sliver: SliverToBoxAdapter(
                    child: WeekGridView(weekStart: gridWeek),
                  ),
                ),
              ] else ...<Widget>[
              if (stats.hasData)
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(
                    AppSpacing.lg,
                    0,
                    AppSpacing.lg,
                    AppSpacing.lg,
                  ),
                  sliver: SliverToBoxAdapter(
                    child: _OverallCard(stats: stats, settings: settings),
                  ),
                ),

              if (unmarked.isNotEmpty)
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(
                    AppSpacing.lg,
                    0,
                    AppSpacing.lg,
                    AppSpacing.lg,
                  ),
                  sliver: SliverToBoxAdapter(
                    child: _UnmarkedBanner(
                      count: unmarked.length,
                      onJump: () => ref
                          .read(selectedDateProvider.notifier)
                          .select(unmarked.first.date),
                    ),
                  ),
                ),

              SliverPadding(
                padding: const EdgeInsets.fromLTRB(
                  AppSpacing.lg,
                  0,
                  AppSpacing.lg,
                  AppSpacing.sm,
                ),
                sliver: SliverToBoxAdapter(
                  child: SectionHeader(
                    isToday ? 'Today' : Dates.formatDayMonth(selected),
                    trailing: unmarkedToday > 1
                        ? TextButton.icon(
                            onPressed: () => _markAllPresent(
                              context,
                              ref,
                              sessions,
                            ),
                            icon: const Icon(Icons.done_all_rounded, size: 18),
                            label: const Text('All present'),
                          )
                        : null,
                  ),
                ),
              ),

              if (holiday != null)
                SliverToBoxAdapter(
                  child: _NoticeCard(
                    icon: Icons.celebration_rounded,
                    title: holiday.name,
                    message: 'Marked as a holiday — no recurring classes today.',
                    color: context.palette.cyan,
                  ),
                )
              else if (outsideSemester)
                SliverToBoxAdapter(
                  child: _NoticeCard(
                    icon: Icons.event_busy_rounded,
                    title: 'Outside the semester',
                    message: settings.hasSemester
                        ? 'Your semester runs '
                            '${Dates.formatFull(settings.semesterStart!)} – '
                            '${Dates.formatFull(settings.semesterEnd!)}.'
                        : 'Set your semester dates in Settings.',
                    color: context.palette.textTertiary,
                  ),
                ),

              if (sessions.isEmpty && holiday == null && !outsideSemester)
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      vertical: AppSpacing.xxl,
                    ),
                    child: EmptyState(
                      icon: Icons.free_breakfast_outlined,
                      title: isToday ? 'Nothing on today' : 'No classes',
                      message: isToday
                          ? 'Enjoy the free day. Add classes from the Timetable tab.'
                          : 'There are no classes scheduled for this day.',
                    ),
                  ),
                ),

              SliverPadding(
                padding: const EdgeInsets.fromLTRB(
                  AppSpacing.lg,
                  0,
                  AppSpacing.lg,
                  120,
                ),
                sliver: SliverList.separated(
                  itemCount: sessions.length,
                  separatorBuilder: (_, __) =>
                      const SizedBox(height: AppSpacing.md),
                  itemBuilder: (BuildContext context, int index) {
                    final ClassSession session = sessions[index];
                    final List<Tag> tags = data?.tags ?? const <Tag>[];
                    return SessionCard(
                      session: session,
                      use24Hour: settings.use24HourTime,
                      categoryName: data?.categoryFor(session.subject)?.name,
                      tagName: data?.tagById(session.record?.tagId)?.name,
                      onMark: (AttendanceStatus status) => ref
                          .read(actionsProvider)
                          .mark(session, status),
                      onTag: tags.isEmpty
                          ? null
                          : () => _pickTag(context, ref, session, tags),
                      onLongPress: () =>
                          showSessionOptions(context, ref, session),
                    );
                  },
                ),
              ),
              ],
            ],
          ),
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => showAddClassSheet(context, ref, initialDate: selected),
        icon: const Icon(Icons.add_rounded),
        label: const Text('Add class'),
      ),
    );
  }

  /// Opens the tag picker for one marked class and writes the result.
  ///
  /// The toggle lives in `setTagAt`, so tapping the tag a class already has
  /// clears it here without this screen knowing the rule.
  Future<void> _pickTag(
    BuildContext context,
    WidgetRef ref,
    ClassSession session,
    List<Tag> tags,
  ) async {
    final int? subjectId = session.subject.id;
    if (subjectId == null) return;
    final int? chosen = await showTagPicker(
      context,
      tags: tags,
      selected: session.record?.tagId,
    );
    if (chosen == null) return;
    await ref.read(actionsProvider).setTagAt(
          subjectId: subjectId,
          date: session.date,
          startMinutes: session.startMinutes,
          tagId: chosen,
        );
  }

  Future<void> _markAllPresent(
    BuildContext context,
    WidgetRef ref,
    List<ClassSession> sessions,
  ) async {
    final int count =
        await ref.read(actionsProvider).markAll(sessions, AttendanceStatus.present);
    if (!context.mounted || count == 0) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Marked $count ${count == 1 ? 'class' : 'classes'} present'),
      ),
    );
  }

  /// Shows one popup for subjects that have newly fallen into danger while
  /// their system notification is switched off. Subjects that recover are
  /// forgotten, so a later slip warns again.
  void _showPendingAlerts(BuildContext context, WidgetRef ref) {
    final List<SubjectStats> alerts = ref.read(inAppAlertsProvider);
    final AnnouncedAlertsController announced =
        ref.read(announcedAlertsProvider.notifier);
    announced.retainOnly(alerts);

    final List<SubjectStats> pending = announced.pending(alerts);
    if (pending.isEmpty) return;

    // Recorded before awaiting the dialog so a rebuild mid-flight cannot open
    // a second copy of it.
    announced.markAnnounced(pending);
    showDialog<void>(
      context: context,
      builder: (BuildContext context) => _InAppAlertDialog(alerts: pending),
    );
  }
}

/// The in-app stand-in for an attendance notification. Deliberately reuses
/// [NotificationService.dangerMessage] so the wording matches the tray exactly.
class _InAppAlertDialog extends StatelessWidget {
  const _InAppAlertDialog({required this.alerts});

  final List<SubjectStats> alerts;

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: context.palette.surfaceHigh,
      icon: Icon(
        // An alarm triangle overstates it — this is a heads-up about a
        // percentage, not an emergency.
        Icons.info_outline_rounded,
        color: context.palette.warning,
        size: 28,
      ),
      title: Text(
        alerts.length == 1
            ? 'Worth a look'
            : '${alerts.length} subjects worth a look',
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          for (final SubjectStats s in alerts)
            Padding(
              padding: const EdgeInsets.only(bottom: AppSpacing.md),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(
                    s.subject.name,
                    style: const TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 14.5,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    NotificationService.dangerMessage(s),
                    style: TextStyle(
                      color: context.palette.textSecondary,
                      fontSize: 13,
                      height: 1.35,
                    ),
                  ),
                ],
              ),
            ),
          Text(
            'Notifications for these are off, so Zeolite is telling you '
            'here instead. Change this in Settings → Notifications.',
            style: TextStyle(
              color: context.palette.textTertiary,
              fontSize: 12,
              height: 1.35,
            ),
          ),
        ],
      ),
      actions: <Widget>[
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Got it'),
        ),
      ],
    );
  }
}

class _Header extends ConsumerWidget {
  const _Header({
    required this.selected,
    required this.isToday,
    required this.view,
    required this.onJumpToToday,
    required this.onToggleView,
  });

  final DateTime selected;
  final bool isToday;
  final HomeView view;
  final VoidCallback onJumpToToday;
  final VoidCallback onToggleView;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ClassSession? next = ref.watch(nextSessionProvider);
    final AppSettings settings =
        ref.watch(settingsProvider).value ?? const AppSettings();
    final bool isGrid = view == HomeView.grid;

    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.lg,
        AppSpacing.lg,
        AppSpacing.lg,
        AppSpacing.lg,
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  isGrid ? 'Week' : Dates.relativeLabel(selected),
                  style: const TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.w800,
                    letterSpacing: -1,
                    height: 1.1,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  next == null
                      ? Dates.formatFull(selected)
                      : 'Next: ${next.subject.name} · '
                          '${Dates.relativeLabel(next.date)} '
                          '${Clock.format(next.startMinutes, use24Hour: settings.use24HourTime)}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 13.5,
                    fontWeight: FontWeight.w500,
                    color: context.palette.textSecondary,
                  ),
                ),
              ],
            ),
          ),
          if (!isToday)
            IconButton(
              onPressed: onJumpToToday,
              tooltip: 'Jump to today',
              icon: const Icon(Icons.today_rounded),
              style: IconButton.styleFrom(
                backgroundColor: context.palette.surfaceHigh,
                foregroundColor: context.palette.accent,
              ),
            ),
          const SizedBox(width: AppSpacing.sm),
          IconButton(
            onPressed: onToggleView,
            tooltip: isGrid ? 'Show the day' : 'Show the week grid',
            icon: Icon(
              isGrid ? Icons.view_agenda_outlined : Icons.grid_view_rounded,
            ),
            style: IconButton.styleFrom(
              backgroundColor: isGrid
                  ? context.palette.accent.withValues(alpha: 0.16)
                  : context.palette.surfaceHigh,
              foregroundColor: context.palette.accent,
            ),
          ),
        ],
      ),
    );
  }
}

/// Week stepper for the grid. The day list has the date strip for this, but the
/// grid shows a whole week at a time so it needs its own.
class _GridWeekNav extends StatelessWidget {
  const _GridWeekNav({required this.weekStart, required this.onShift});

  final DateTime weekStart;
  final ValueChanged<int> onShift;

  @override
  Widget build(BuildContext context) {
    final DateTime weekEnd = Dates.addDays(weekStart, 6);
    final bool isCurrent =
        Dates.isSameDay(weekStart, Dates.startOfWeek(Dates.today()));

    return SurfaceCard(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.sm,
        vertical: AppSpacing.xs,
      ),
      child: Row(
        children: <Widget>[
          IconButton(
            onPressed: () => onShift(-1),
            icon: const Icon(Icons.chevron_left_rounded),
            color: context.palette.textSecondary,
          ),
          Expanded(
            child: Column(
              children: <Widget>[
                Text(
                  isCurrent ? 'This week' : 'Week of',
                  style: TextStyle(
                    fontSize: 10.5,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.8,
                    color: context.palette.textTertiary,
                  ),
                ),
                Text(
                  '${weekStart.day} ${kMonthNamesShort[weekStart.month - 1]} – '
                  '${weekEnd.day} ${kMonthNamesShort[weekEnd.month - 1]}',
                  style: const TextStyle(
                    fontSize: 13.5,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            onPressed: () => onShift(1),
            icon: const Icon(Icons.chevron_right_rounded),
            color: context.palette.textSecondary,
          ),
        ],
      ),
    );
  }
}

class _OverallCard extends StatelessWidget {
  const _OverallCard({required this.stats, required this.settings});

  final OverallStats stats;
  final AppSettings settings;

  @override
  Widget build(BuildContext context) {
    final Color color = stats.meetsTarget ? context.palette.present : context.palette.absent;
    final SubjectStats? weakest = stats.weakest;

    return SurfaceCard(
      child: Row(
        children: <Widget>[
          ProgressRing(
            value: stats.ratio,
            color: color,
            targetValue: stats.target,
            size: 84,
            caption: 'overall',
          ),
          const SizedBox(width: AppSpacing.lg),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  stats.meetsTarget ? 'On track' : 'Below target',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    letterSpacing: -0.3,
                    color: color,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '${stats.present} attended of ${stats.held} held · '
                  'target ${settings.targetPercent.toStringAsFixed(0)}%',
                  style: TextStyle(
                    fontSize: 13,
                    height: 1.35,
                    color: context.palette.textSecondary,
                  ),
                ),
                if (weakest != null && !weakest.meetsTarget) ...<Widget>[
                  const SizedBox(height: AppSpacing.sm),
                  Row(
                    children: <Widget>[
                      Container(
                        width: 8,
                        height: 8,
                        decoration: BoxDecoration(
                          color: weakest.subject.color,
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          '${weakest.subject.name}: ${weakest.headline.toLowerCase()}',
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 12.5,
                            color: context.palette.textTertiary,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _UnmarkedBanner extends StatelessWidget {
  const _UnmarkedBanner({required this.count, required this.onJump});

  final int count;
  final VoidCallback onJump;

  @override
  Widget build(BuildContext context) {
    return SurfaceCard(
      color: context.palette.warning.withValues(alpha: 0.10),
      borderColor: context.palette.warning.withValues(alpha: 0.35),
      onTap: onJump,
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.lg,
        vertical: AppSpacing.md,
      ),
      child: Row(
        children: <Widget>[
          Icon(
            Icons.error_outline_rounded,
            size: 20,
            color: context.palette.warning,
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Text(
              '$count past ${count == 1 ? 'class needs' : 'classes need'} marking',
              style: TextStyle(
                fontSize: 13.5,
                fontWeight: FontWeight.w600,
                color: context.palette.textPrimary,
              ),
            ),
          ),
          Icon(
            Icons.chevron_right_rounded,
            size: 20,
            color: context.palette.warning,
          ),
        ],
      ),
    );
  }
}

class _NoticeCard extends StatelessWidget {
  const _NoticeCard({
    required this.icon,
    required this.title,
    required this.message,
    required this.color,
  });

  final IconData icon;
  final String title;
  final String message;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.lg,
        0,
        AppSpacing.lg,
        AppSpacing.md,
      ),
      child: SurfaceCard(
        color: color.withValues(alpha: 0.08),
        borderColor: color.withValues(alpha: 0.3),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Icon(icon, size: 20, color: color),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(
                    title,
                    style: const TextStyle(
                      fontSize: 14.5,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    message,
                    style: TextStyle(
                      fontSize: 13,
                      height: 1.35,
                      color: context.palette.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
