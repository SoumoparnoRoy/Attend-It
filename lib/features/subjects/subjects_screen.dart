import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/app_theme.dart';
import '../../data/models/attendance_record.dart';
import '../../data/models/class_category.dart';
import '../../data/models/class_slot.dart';
import '../../data/models/extra_class.dart';
import '../../data/models/subject.dart';
import '../../domain/attendance_stats.dart';
import '../../state/providers.dart';
import '../../widgets/common.dart';
import 'class_editor_sheets.dart';

/// Every subject in one place: add, edit, recolour and delete.
///
/// Pushed from Settings. The rest of the app edits subjects incidentally — from
/// a class editor or a stats card — so this is the one screen that treats them
/// as the list they are.
class SubjectsScreen extends ConsumerWidget {
  const SubjectsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final TimetableData? data = ref.watch(timetableProvider).value;
    // Already ordered by name from the repository.
    final List<Subject> subjects = data?.subjects ?? <Subject>[];

    return Scaffold(
      appBar: AppBar(title: const Text('Subjects')),
      body: subjects.isEmpty
          ? Padding(
              padding: const EdgeInsets.only(bottom: 60),
              child: EmptyState(
                icon: Icons.school_outlined,
                title: 'No subjects yet',
                message:
                    'Add the courses you are taking. Classes hang off a subject, '
                    'and your attendance is tracked per subject.',
                action: FilledButton.icon(
                  onPressed: () => showSubjectEditor(context, ref),
                  icon: const Icon(Icons.add_rounded),
                  label: const Text('Add your first subject'),
                ),
              ),
            )
          : ListView.separated(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.lg,
                AppSpacing.lg,
                AppSpacing.lg,
                100,
              ),
              itemCount: subjects.length,
              separatorBuilder: (_, __) => const SizedBox(height: AppSpacing.md),
              itemBuilder: (BuildContext context, int index) =>
                  _SubjectRow(subject: subjects[index]),
            ),
      floatingActionButton: subjects.isEmpty
          ? null
          : FloatingActionButton.extended(
              onPressed: () => showSubjectEditor(context, ref),
              icon: const Icon(Icons.add_rounded),
              label: const Text('Add subject'),
            ),
    );
  }
}

enum _SubjectAction { edit, colour, delete }

/// One entry in the overflow menu. A plain row rather than a [ListTile], which
/// wants more height than a [PopupMenuItem] gives it.
class _MenuRow extends StatelessWidget {
  const _MenuRow({required this.icon, required this.label, this.color});

  final IconData icon;
  final String label;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final Color tint = color ?? context.palette.textPrimary;
    return Row(
      children: <Widget>[
        Icon(icon, size: 19, color: tint),
        const SizedBox(width: AppSpacing.md),
        Text(
          label,
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w500,
            color: tint,
          ),
        ),
      ],
    );
  }
}

class _SubjectRow extends ConsumerWidget {
  const _SubjectRow({required this.subject});

  final Subject subject;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final TimetableData? data = ref.watch(timetableProvider).value;
    final int? id = subject.id;
    final SubjectStats? stats =
        id == null ? null : ref.watch(subjectStatsProvider(id));

    final ClassCategory? category = data?.categoryFor(subject);
    final int classCount = _classCount(data, id);

    final String detail = <String>[
      if (subject.code != null && subject.code!.isNotEmpty) subject.code!,
      if (subject.teacher != null && subject.teacher!.isNotEmpty)
        subject.teacher!,
      if (category != null) category.name,
      classCount == 1 ? '1 class' : '$classCount classes',
    ].join(' · ');

    final Color percentColor =
        healthColor(stats?.health ?? AttendanceHealth.empty, context.palette);

    return SurfaceCard(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.lg,
        AppSpacing.md,
        AppSpacing.sm,
        AppSpacing.md,
      ),
      onTap: () => showSubjectEditor(context, ref, subject: subject),
      onLongPress: () => showSubjectColorPicker(context, ref, subject),
      child: Row(
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
                  detail,
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
          const SizedBox(width: AppSpacing.sm),
          Text(
            stats != null && stats.hasData
                ? '${stats.percent.toStringAsFixed(0)}%'
                : '—',
            style: TextStyle(
              fontSize: 17,
              fontWeight: FontWeight.w800,
              letterSpacing: -0.5,
              color: percentColor,
            ),
          ),
          PopupMenuButton<_SubjectAction>(
            icon: Icon(
              Icons.more_vert_rounded,
              size: 20,
              color: context.palette.textTertiary,
            ),
            color: context.palette.surfaceHigh,
            onSelected: (_SubjectAction action) async {
              switch (action) {
                case _SubjectAction.edit:
                  await showSubjectEditor(context, ref, subject: subject);
                case _SubjectAction.colour:
                  await showSubjectColorPicker(context, ref, subject);
                case _SubjectAction.delete:
                  await _confirmDelete(context, ref, data);
              }
            },
            itemBuilder: (BuildContext context) =>
                <PopupMenuEntry<_SubjectAction>>[
              const PopupMenuItem<_SubjectAction>(
                value: _SubjectAction.edit,
                child: _MenuRow(icon: Icons.edit_outlined, label: 'Edit'),
              ),
              const PopupMenuItem<_SubjectAction>(
                value: _SubjectAction.colour,
                child: _MenuRow(
                  icon: Icons.palette_outlined,
                  label: 'Change colour',
                ),
              ),
              PopupMenuItem<_SubjectAction>(
                value: _SubjectAction.delete,
                child: _MenuRow(
                  icon: Icons.delete_outline_rounded,
                  label: 'Delete',
                  color: context.palette.absent,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  /// Weekly rules plus one-off classes booked against this subject.
  int _classCount(TimetableData? data, int? id) {
    if (data == null || id == null) return 0;
    int count = 0;
    for (final ClassSlot slot in data.slots) {
      if (slot.subjectId == id) count++;
    }
    for (final ExtraClass extra in data.extras) {
      if (extra.subjectId == id) count++;
    }
    return count;
  }

  /// Deleting cascades to classes and history, so the dialog says exactly what
  /// is about to go rather than a vague warning.
  Future<void> _confirmDelete(
    BuildContext context,
    WidgetRef ref,
    TimetableData? data,
  ) async {
    final int? id = subject.id;
    if (id == null) return;

    // Grabbed up front: deleting unmounts this row, so looking the messenger up
    // afterwards would find nothing and the confirmation would never show.
    final ScaffoldMessengerState messenger = ScaffoldMessenger.of(context);

    int slots = 0;
    int extras = 0;
    int marks = 0;
    if (data != null) {
      for (final ClassSlot slot in data.slots) {
        if (slot.subjectId == id) slots++;
      }
      for (final ExtraClass extra in data.extras) {
        if (extra.subjectId == id) extras++;
      }
      for (final AttendanceRecord record in data.records) {
        if (record.subjectId == id) marks++;
      }
    }

    final List<String> losses = <String>[
      if (slots > 0) slots == 1 ? '1 weekly class' : '$slots weekly classes',
      if (extras > 0)
        extras == 1 ? '1 one-off class' : '$extras one-off classes',
      if (marks > 0) marks == 1 ? '1 attendance mark' : '$marks attendance marks',
    ];

    final String message = losses.isEmpty
        ? 'Nothing is recorded against it yet, so nothing else is lost.'
        : '${subject.name} has ${_joinNaturally(losses)}. Deleting the subject '
            'removes all of it. This cannot be undone.';

    final bool? confirmed = await showDialog<bool>(
      context: context,
      builder: (BuildContext context) => AlertDialog(
        backgroundColor: context.palette.surfaceHigh,
        title: Text('Delete ${subject.name}?'),
        content: Text(message, style: const TextStyle(height: 1.4)),
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
    await ref.read(actionsProvider).deleteSubject(id);
    messenger.showSnackBar(
      SnackBar(content: Text('Deleted ${subject.name}')),
    );
  }

  /// "a, b and c" — reads like a sentence rather than a list of counts.
  String _joinNaturally(List<String> parts) {
    if (parts.length == 1) return parts.first;
    return '${parts.sublist(0, parts.length - 1).join(', ')} and ${parts.last}';
  }
}
