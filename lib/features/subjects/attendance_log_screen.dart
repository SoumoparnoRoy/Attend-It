import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/app_theme.dart';
import '../../core/date_utils.dart';
import '../../data/models/attendance_status.dart';
import '../../data/models/subject.dart';
import '../../data/settings/app_settings.dart';
import '../../domain/attendance_log.dart';
import '../../state/providers.dart';
import '../../widgets/common.dart';

/// Every past class for one subject, with its mark, correctable in place.
///
/// Exists because the Today screen only reaches one day at a time: fixing a
/// mistake from three weeks ago meant walking back through it day by day.
class AttendanceLogScreen extends ConsumerWidget {
  const AttendanceLogScreen({super.key, required this.subject});

  final Subject subject;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final int? subjectId = subject.id;
    if (subjectId == null) {
      // Defensive: a subject always has an id once persisted, but the model
      // allows null before insertion and a blank screen would be worse.
      return Scaffold(
        appBar: AppBar(title: Text(subject.name)),
        body: const _LogEmpty(
          message: 'This subject has not been saved yet.',
        ),
      );
    }

    final List<AttendanceLogEntry> entries =
        ref.watch(attendanceLogProvider(subjectId));
    final AppSettings settings =
        ref.watch(settingsProvider).value ?? const AppSettings();

    final int marked =
        entries.where((AttendanceLogEntry e) => e.isMarked).length;

    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Text(subject.name, overflow: TextOverflow.ellipsis),
            if (entries.isNotEmpty)
              Text(
                '$marked of ${entries.length} marked',
                style: TextStyle(
                  fontSize: 12.5,
                  fontWeight: FontWeight.w500,
                  color: context.palette.textSecondary,
                ),
              ),
          ],
        ),
      ),
      body: SafeArea(
        top: false,
        child: entries.isEmpty
            ? const _LogEmpty(
                message:
                    'Once this subject has had a class, every one of them '
                    'shows up here to mark or correct.',
              )
            : _LogList(
                subjectId: subjectId,
                entries: entries,
                use24Hour: settings.use24HourTime,
              ),
      ),
    );
  }
}

class _LogEmpty extends StatelessWidget {
  const _LogEmpty({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return EmptyState(
      icon: Icons.history_rounded,
      title: 'Nothing to show yet',
      message: message,
    );
  }
}

/// A month heading or a single class, flattened so one [ListView.builder] can
/// lazily render a whole term without building rows it never shows.
@immutable
class _Row {
  const _Row.header(this.header) : entry = null;
  const _Row.entry(this.entry) : header = null;

  final String? header;
  final AttendanceLogEntry? entry;

  bool get isHeader => header != null;
}

class _LogList extends ConsumerWidget {
  const _LogList({
    required this.subjectId,
    required this.entries,
    required this.use24Hour,
  });

  final int subjectId;
  final List<AttendanceLogEntry> entries;
  final bool use24Hour;

  List<_Row> _flatten() {
    final List<_Row> rows = <_Row>[];
    String? currentMonth;
    for (final AttendanceLogEntry entry in entries) {
      final String month = Dates.formatMonthYear(entry.date);
      if (month != currentMonth) {
        currentMonth = month;
        rows.add(_Row.header(month));
      }
      rows.add(_Row.entry(entry));
    }
    return rows;
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final List<_Row> rows = _flatten();

    return Center(
      // Keeps line length readable on tablets and foldables rather than
      // stretching a date and three buttons across the whole width.
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 640),
        child: ListView.builder(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.lg,
            AppSpacing.sm,
            AppSpacing.lg,
            AppSpacing.xxl,
          ),
          itemCount: rows.length,
          itemBuilder: (BuildContext context, int index) {
            final _Row row = rows[index];
            if (row.isHeader) {
              return Padding(
                padding: const EdgeInsets.only(
                  top: AppSpacing.lg,
                  bottom: AppSpacing.sm,
                ),
                child: SectionHeader(row.header!),
              );
            }
            return _LogTile(
              subjectId: subjectId,
              entry: row.entry!,
              use24Hour: use24Hour,
            );
          },
        ),
      ),
    );
  }
}

class _LogTile extends ConsumerWidget {
  const _LogTile({
    required this.subjectId,
    required this.entry,
    required this.use24Hour,
  });

  final int subjectId;
  final AttendanceLogEntry entry;
  final bool use24Hour;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AppPalette p = context.palette;

    final String time = entry.endMinutes == null
        ? Clock.format(entry.startMinutes, use24Hour: use24Hour)
        : Clock.formatRange(
            entry.startMinutes,
            entry.endMinutes!,
            use24Hour: use24Hour,
          );

    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.sm),
      child: SurfaceCard(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.lg,
          vertical: AppSpacing.md,
        ),
        // Unmarked rows are the ones worth chasing, so they carry a hint of the
        // warning colour instead of sitting silently in the list.
        borderColor: entry.needsMarking
            ? p.warning.withValues(alpha: 0.35)
            : null,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Row(
              children: <Widget>[
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Text(
                        Dates.formatFull(entry.date),
                        style: const TextStyle(
                          fontSize: 14.5,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        <String>[
                          Dates.weekdayLong(entry.date),
                          time,
                          if (entry.room != null && entry.room!.isNotEmpty)
                            entry.room!,
                        ].join(' · '),
                        style: TextStyle(
                          fontSize: 12.5,
                          color: p.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
                for (final AttendanceStatus status in AttendanceStatus.values)
                  Padding(
                    padding: const EdgeInsets.only(left: AppSpacing.sm),
                    child: _StatusToggle(
                      status: status,
                      selected: entry.status == status,
                      onTap: () => ref.read(actionsProvider).setStatusAt(
                            subjectId: subjectId,
                            date: entry.date,
                            startMinutes: entry.startMinutes,
                            current: entry.status,
                            status: status,
                          ),
                    ),
                  ),
              ],
            ),
            if (entry.isOrphaned) ...<Widget>[
              const SizedBox(height: AppSpacing.sm),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Icon(
                    Icons.link_off_rounded,
                    size: 14,
                    color: p.textTertiary,
                  ),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      'The weekly class this was recorded against has been '
                      'deleted. It still counts towards your percentage.',
                      style: TextStyle(fontSize: 11.5, color: p.textTertiary),
                    ),
                  ),
                ],
              ),
              Align(
                alignment: Alignment.centerLeft,
                child: TextButton.icon(
                  onPressed: () => _confirmRemove(context, ref),
                  icon: const Icon(Icons.delete_outline_rounded, size: 16),
                  label: const Text('Remove this mark'),
                  style: TextButton.styleFrom(
                    foregroundColor: p.absent,
                    padding: const EdgeInsets.symmetric(
                      horizontal: AppSpacing.sm,
                    ),
                    textStyle: const TextStyle(
                      fontSize: 12.5,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// Confirms before discarding a stray mark.
///
/// There is no undo anywhere in the app, and this row is the only place the
/// mark is visible at all, so removing it silently would destroy the one thing
/// that explains a percentage the user cannot otherwise account for.
extension on _LogTile {
  Future<void> _confirmRemove(BuildContext context, WidgetRef ref) async {
    final bool confirmed = await showDialog<bool>(
          context: context,
          builder: (BuildContext context) => AlertDialog(
            backgroundColor: context.palette.surfaceHigh,
            title: const Text('Remove this mark?'),
            content: Text(
              'The ${entry.status?.label.toLowerCase() ?? 'recorded'} mark for '
              '${Dates.formatFull(entry.date)} will be deleted and will stop '
              'counting towards your percentage. This cannot be undone.',
              style: const TextStyle(fontSize: 13.5, height: 1.4),
            ),
            actions: <Widget>[
              TextButton(
                onPressed: () => Navigator.of(context).pop(false),
                child: const Text('Keep it'),
              ),
              TextButton(
                onPressed: () => Navigator.of(context).pop(true),
                style: TextButton.styleFrom(
                  foregroundColor: context.palette.absent,
                ),
                child: const Text('Remove'),
              ),
            ],
          ),
        ) ??
        false;

    if (!confirmed) return;
    await ref.read(actionsProvider).clearStatusAt(
          subjectId: subjectId,
          date: entry.date,
          startMinutes: entry.startMinutes,
        );
  }
}

/// Compact icon-only toggle. A term's worth of rows cannot afford the
/// full-width labelled buttons the Today screen uses, so the label moves into
/// the semantics and tooltip rather than disappearing.
class _StatusToggle extends StatelessWidget {
  const _StatusToggle({
    required this.status,
    required this.selected,
    required this.onTap,
  });

  final AttendanceStatus status;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final AppPalette p = context.palette;
    final Color color = status.colorIn(p);

    return Tooltip(
      message: selected ? 'Clear ${status.label}' : status.label,
      child: Semantics(
        button: true,
        selected: selected,
        label: status.label,
        child: Material(
          color: selected ? color.withValues(alpha: 0.18) : p.surfaceHigh,
          borderRadius: BorderRadius.circular(AppSpacing.radiusSm),
          child: InkWell(
            onTap: onTap,
            borderRadius: BorderRadius.circular(AppSpacing.radiusSm),
            child: Container(
              // 44px keeps the target at the accessible minimum even though the
              // icon inside is small.
              width: 44,
              height: 44,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(AppSpacing.radiusSm),
                border: Border.all(
                  color: selected
                      ? color.withValues(alpha: 0.6)
                      : p.outlineSoft,
                  width: selected ? 1.6 : 1,
                ),
              ),
              child: Icon(
                status.icon,
                size: 18,
                color: selected ? color : p.textTertiary,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
