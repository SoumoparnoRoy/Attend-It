import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/app_theme.dart';
import '../../data/models/subject.dart';
import '../../data/settings/app_settings.dart';
import '../../domain/attendance_stats.dart';
import '../../state/providers.dart';
import '../../widgets/common.dart';
import '../subjects/attendance_log_screen.dart';
import '../subjects/class_editor_sheets.dart';

/// Attendance overview: where you stand, and how much room you have left.
class StatsScreen extends ConsumerWidget {
  const StatsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final OverallStats stats = ref.watch(statsProvider);
    final AppSettings settings =
        ref.watch(settingsProvider).value ?? const AppSettings();

    return Scaffold(
      body: SafeArea(
        bottom: false,
        child: CustomScrollView(
          slivers: <Widget>[
            const SliverToBoxAdapter(
              child: Padding(
                padding: EdgeInsets.fromLTRB(
                  AppSpacing.lg,
                  AppSpacing.lg,
                  AppSpacing.lg,
                  AppSpacing.lg,
                ),
                child: Text(
                  'Attendance',
                  style: TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.w800,
                    letterSpacing: -1,
                  ),
                ),
              ),
            ),

            if (stats.subjects.isEmpty)
              const SliverFillRemaining(
                hasScrollBody: false,
                child: Padding(
                  padding: EdgeInsets.only(bottom: 80),
                  child: EmptyState(
                    icon: Icons.insights_outlined,
                    title: 'No data yet',
                    message:
                        'Add subjects and mark a few classes — your percentages and skip allowance appear here.',
                  ),
                ),
              )
            else ...<Widget>[
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(
                  AppSpacing.lg,
                  0,
                  AppSpacing.lg,
                  AppSpacing.xl,
                ),
                sliver: SliverToBoxAdapter(
                  child: _OverallPanel(stats: stats, settings: settings),
                ),
              ),
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(
                  AppSpacing.lg,
                  0,
                  AppSpacing.lg,
                  0,
                ),
                sliver: const SliverToBoxAdapter(
                  child: SectionHeader('By subject'),
                ),
              ),
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(
                  AppSpacing.lg,
                  0,
                  AppSpacing.lg,
                  100,
                ),
                sliver: SliverList.separated(
                  itemCount: stats.subjects.length,
                  separatorBuilder: (_, __) =>
                      const SizedBox(height: AppSpacing.md),
                  itemBuilder: (BuildContext context, int index) {
                    final SubjectStats subjectStats = stats.subjects[index];
                    return _SubjectStatsCard(
                      stats: subjectStats,
                      onTap: () =>
                          _showSubjectDetail(context, ref, subjectStats),
                    );
                  },
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Future<void> _showSubjectDetail(
    BuildContext context,
    WidgetRef ref,
    SubjectStats stats,
  ) async {
    await showAppSheet<void>(
      context: context,
      title: stats.subject.name,
      child: _SubjectDetail(stats: stats),
    );
  }
}

class _OverallPanel extends StatelessWidget {
  const _OverallPanel({required this.stats, required this.settings});

  final OverallStats stats;
  final AppSettings settings;

  @override
  Widget build(BuildContext context) {
    final Color color = stats.meetsTarget ? context.palette.present : context.palette.absent;

    return SurfaceCard(
      padding: const EdgeInsets.all(AppSpacing.xl),
      child: Column(
        children: <Widget>[
          Row(
            children: <Widget>[
              ProgressRing(
                value: stats.ratio,
                color: color,
                targetValue: stats.target,
                size: 104,
                strokeWidth: 10,
                caption: 'attended',
              ),
              const SizedBox(width: AppSpacing.xl),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    _StatLine(
                      label: 'Attended',
                      value: '${stats.present}',
                      color: context.palette.present,
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    _StatLine(
                      label: 'Missed',
                      value: '${stats.absent}',
                      color: context.palette.absent,
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    _StatLine(
                      label: 'Cancelled',
                      value: '${stats.cancelled}',
                      color: context.palette.cancelled,
                    ),
                  ],
                ),
              ),
            ],
          ),
          if (settings.hasSemester) ...<Widget>[
            const SizedBox(height: AppSpacing.xl),
            const Divider(),
            const SizedBox(height: AppSpacing.lg),
            Row(
              children: <Widget>[
                Icon(
                  Icons.timelapse_rounded,
                  size: 16,
                  color: context.palette.textTertiary,
                ),
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: Text(
                    'Semester ${(settings.semesterProgress * 100).round()}% done · '
                    '${settings.daysLeftInSemester} days left',
                    style: TextStyle(
                      fontSize: 12.5,
                      fontWeight: FontWeight.w500,
                      color: context.palette.textSecondary,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.sm),
            TargetBar(
              value: settings.semesterProgress,
              color: context.palette.accent,
              height: 6,
            ),
          ],
        ],
      ),
    );
  }
}

class _StatLine extends StatelessWidget {
  const _StatLine({
    required this.label,
    required this.value,
    required this.color,
  });

  final String label;
  final String value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: <Widget>[
        Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: AppSpacing.sm),
        Expanded(
          child: Text(
            label,
            style: TextStyle(
              fontSize: 13,
              color: context.palette.textSecondary,
            ),
          ),
        ),
        Text(
          value,
          style: const TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w700,
          ),
        ),
      ],
    );
  }
}

class _SubjectStatsCard extends StatelessWidget {
  const _SubjectStatsCard({required this.stats, required this.onTap});

  final SubjectStats stats;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final Subject subject = stats.subject;
    final Color healthTint = healthColor(stats.health, context.palette);

    return SurfaceCard(
      onTap: onTap,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              SubjectAvatar(
                initials: subject.initials,
                color: subject.color,
                size: 40,
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      subject.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 15.5,
                        fontWeight: FontWeight.w700,
                        letterSpacing: -0.2,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      stats.hasData
                          ? '${stats.present} of ${stats.held} attended'
                          : 'Nothing marked yet',
                      style: TextStyle(
                        fontSize: 12.5,
                        color: context.palette.textTertiary,
                      ),
                    ),
                  ],
                ),
              ),
              Text(
                stats.hasData ? '${stats.percent.toStringAsFixed(0)}%' : '—',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w800,
                  letterSpacing: -0.6,
                  color: healthTint,
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          TargetBar(
            value: stats.ratio,
            color: healthFill(stats.health, context.palette),
            target: stats.target,
          ),
          const SizedBox(height: AppSpacing.sm),
          Row(
            children: <Widget>[
              Icon(
                stats.meetsTarget
                    ? Icons.check_circle_outline_rounded
                    : Icons.error_outline_rounded,
                size: 14,
                color: healthTint,
              ),
              const SizedBox(width: 5),
              Expanded(
                child: Text(
                  stats.headline,
                  maxLines: 2,
                  style: TextStyle(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w600,
                    color: healthTint,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _SubjectDetail extends ConsumerWidget {
  const _SubjectDetail({required this.stats});

  final SubjectStats stats;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final Subject subject = stats.subject;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        Row(
          children: <Widget>[
            SubjectAvatar(
              initials: subject.initials,
              color: subject.color,
              size: 52,
            ),
            const SizedBox(width: AppSpacing.lg),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(
                    <String>[
                      if (subject.code != null && subject.code!.isNotEmpty)
                        subject.code!,
                      if (subject.teacher != null &&
                          subject.teacher!.isNotEmpty)
                        subject.teacher!,
                    ].join(' · '),
                    style: TextStyle(
                      fontSize: 13,
                      color: context.palette.textSecondary,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    'Target ${(stats.target * 100).round()}%',
                    style: TextStyle(
                      fontSize: 12.5,
                      color: context.palette.textTertiary,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.xl),
        Row(
          children: <Widget>[
            Expanded(
              child: _MetricTile(
                label: 'Attended',
                value: '${stats.present}',
                color: context.palette.present,
              ),
            ),
            const SizedBox(width: AppSpacing.sm),
            Expanded(
              child: _MetricTile(
                label: 'Missed',
                value: '${stats.absent}',
                color: context.palette.absent,
              ),
            ),
            const SizedBox(width: AppSpacing.sm),
            Expanded(
              child: _MetricTile(
                label: 'Cancelled',
                value: '${stats.cancelled}',
                color: context.palette.cancelled,
              ),
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.md),
        Row(
          children: <Widget>[
            Expanded(
              child: _MetricTile(
                label: 'Can skip',
                value: stats.meetsTarget ? '${stats.canSkip}' : '0',
                color: context.palette.accent,
              ),
            ),
            const SizedBox(width: AppSpacing.sm),
            Expanded(
              child: _MetricTile(
                label: 'Must attend',
                value: '${stats.needToAttend}',
                color: context.palette.warning,
              ),
            ),
            const SizedBox(width: AppSpacing.sm),
            Expanded(
              child: _MetricTile(
                label: 'Left in term',
                value: '${stats.remainingPlanned}',
                color: context.palette.cyan,
              ),
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.xl),
        SurfaceCard(
          color: context.palette.surfaceHigh,
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Icon(
                stats.meetsTarget
                    ? Icons.check_circle_outline_rounded
                    : Icons.error_outline_rounded,
                size: 18,
                color:
                    stats.meetsTarget ? context.palette.present : context.palette.absent,
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Text(
                  stats.headline,
                  style: const TextStyle(
                    fontSize: 13.5,
                    height: 1.35,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
        ),
        if (stats.remainingPlanned > 0) ...<Widget>[
          const SizedBox(height: AppSpacing.md),
          Text(
            'Attending every remaining class would put you at '
            '${(stats.maxAchievableRatio * 100).toStringAsFixed(0)}%.',
            style: TextStyle(
              fontSize: 12.5,
              height: 1.4,
              color: context.palette.textTertiary,
            ),
          ),
        ],
        const SizedBox(height: AppSpacing.xl),
        OutlinedButton.icon(
          onPressed: () async {
            // Same ordering as Edit below: push on top first, because popping
            // this sheet would unmount the context being navigated from.
            await Navigator.of(context).push(
              MaterialPageRoute<void>(
                builder: (BuildContext context) =>
                    AttendanceLogScreen(subject: subject),
              ),
            );
            if (context.mounted) Navigator.of(context).pop();
          },
          icon: const Icon(Icons.history_rounded, size: 18),
          label: const Text('Attendance log'),
        ),
        const SizedBox(height: AppSpacing.md),
        Row(
          children: <Widget>[
            Expanded(
              child: OutlinedButton.icon(
                onPressed: () async {
                  // Open the editor on top first — popping this sheet before
                  // awaiting would unmount the context we need.
                  await showSubjectEditor(context, ref, subject: subject);
                  if (context.mounted) Navigator.of(context).pop();
                },
                icon: const Icon(Icons.edit_outlined, size: 18),
                label: const Text('Edit'),
              ),
            ),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: OutlinedButton.icon(
                onPressed: () => _confirmDelete(context, ref, subject),
                style: OutlinedButton.styleFrom(
                  foregroundColor: context.palette.absent,
                  side: BorderSide(
                    color: context.palette.absent.withValues(alpha: 0.4),
                  ),
                ),
                icon: const Icon(Icons.delete_outline_rounded, size: 18),
                label: const Text('Delete'),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Future<void> _confirmDelete(
    BuildContext context,
    WidgetRef ref,
    Subject subject,
  ) async {
    final bool? confirmed = await showDialog<bool>(
      context: context,
      builder: (BuildContext context) => AlertDialog(
        backgroundColor: context.palette.surfaceHigh,
        title: Text('Delete ${subject.name}?'),
        content: const Text(
          'This also removes its classes and all attendance history. '
          'This cannot be undone.',
          style: TextStyle(height: 1.4),
        ),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: TextButton.styleFrom(foregroundColor: context.palette.absent),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;
    final int? id = subject.id;
    if (id != null) {
      await ref.read(actionsProvider).deleteSubject(id);
    }
    if (context.mounted) Navigator.of(context).pop();
  }
}

class _MetricTile extends StatelessWidget {
  const _MetricTile({
    required this.label,
    required this.value,
    required this.color,
  });

  final String label;
  final String value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        vertical: AppSpacing.md,
        horizontal: AppSpacing.sm,
      ),
      decoration: BoxDecoration(
        color: context.palette.surfaceHigh,
        borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
        border: Border.all(color: context.palette.outlineSoft),
      ),
      child: Column(
        children: <Widget>[
          Text(
            value,
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w800,
              letterSpacing: -0.6,
              color: color,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: context.palette.textTertiary,
            ),
          ),
        ],
      ),
    );
  }
}
