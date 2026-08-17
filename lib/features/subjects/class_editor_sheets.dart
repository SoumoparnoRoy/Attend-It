import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/app_theme.dart';
import '../../core/date_utils.dart';
import '../../data/models/attendance_status.dart';
import '../../data/models/class_category.dart';
import '../../data/models/class_session.dart';
import '../../data/models/class_slot.dart';
import '../../data/models/extra_class.dart';
import '../../data/models/subject.dart';
import '../../state/providers.dart';
import '../../widgets/common.dart';

// ---------------------------------------------------------------- entry point

/// Asks whether the new class repeats weekly or happens once, then opens the
/// matching editor.
Future<void> showAddClassSheet(
  BuildContext context,
  WidgetRef ref, {
  DateTime? initialDate,
}) async {
  final _AddKind? kind = await showAppSheet<_AddKind>(
    context: context,
    title: 'Add a class',
    child: Column(
      children: <Widget>[
        _ChoiceTile(
          icon: Icons.repeat_rounded,
          title: 'Repeats every week',
          subtitle:
              'Pick the days and time. It appears every week from the start date onwards.',
          onTap: () => Navigator.of(context).pop(_AddKind.recurring),
        ),
        const SizedBox(height: AppSpacing.md),
        _ChoiceTile(
          icon: Icons.event_rounded,
          title: 'One-off class',
          subtitle: 'A single make-up lecture, extra lab or rescheduled slot.',
          onTap: () => Navigator.of(context).pop(_AddKind.oneOff),
        ),
      ],
    ),
  );

  if (kind == null || !context.mounted) return;
  if (kind == _AddKind.recurring) {
    await showSlotEditor(context, ref, initialDate: initialDate);
  } else {
    await showExtraClassEditor(context, ref, initialDate: initialDate);
  }
}

enum _AddKind { recurring, oneOff }

class _ChoiceTile extends StatelessWidget {
  const _ChoiceTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return SurfaceCard(
      color: context.palette.surfaceHigh,
      onTap: onTap,
      child: Row(
        children: <Widget>[
          Container(
            width: 44,
            height: 44,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: context.palette.accent.withValues(alpha: 0.14),
              borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
            ),
            child: Icon(icon, color: context.palette.accent, size: 22),
          ),
          const SizedBox(width: AppSpacing.lg),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 15.5,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  subtitle,
                  style: TextStyle(
                    fontSize: 12.5,
                    height: 1.35,
                    color: context.palette.textSecondary,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ------------------------------------------------------------ subject editor

/// Create or edit a subject. Returns the subject id on save.
Future<int?> showSubjectEditor(
  BuildContext context,
  WidgetRef ref, {
  Subject? subject,
}) {
  return showAppSheet<int>(
    context: context,
    title: subject == null ? 'New subject' : 'Edit subject',
    child: _SubjectForm(subject: subject),
  );
}

class _SubjectForm extends ConsumerStatefulWidget {
  const _SubjectForm({this.subject});

  final Subject? subject;

  @override
  ConsumerState<_SubjectForm> createState() => _SubjectFormState();
}

class _SubjectFormState extends ConsumerState<_SubjectForm> {
  late final TextEditingController _name;
  late final TextEditingController _code;
  late final TextEditingController _teacher;
  late int _color;
  int? _categoryId;
  late bool _overrideTarget;
  late double _target;
  String? _error;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    final Subject? s = widget.subject;
    _name = TextEditingController(text: s?.name ?? '');
    _code = TextEditingController(text: s?.code ?? '');
    _teacher = TextEditingController(text: s?.teacher ?? '');
    _color = s?.colorValue ?? AppColors.subjectPalette.first;
    _categoryId = s?.categoryId;
    _overrideTarget = s?.targetPercent != null;
    _target = s?.targetPercent ?? 75;
  }

  @override
  void dispose() {
    _name.dispose();
    _code.dispose();
    _teacher.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final String name = _name.text.trim();
    if (name.isEmpty) {
      setState(() => _error = 'Give the subject a name.');
      return;
    }
    setState(() {
      _saving = true;
      _error = null;
    });

    final Subject value = Subject(
      id: widget.subject?.id,
      name: name,
      code: _code.text.trim().isEmpty ? null : _code.text.trim(),
      teacher: _teacher.text.trim().isEmpty ? null : _teacher.text.trim(),
      colorValue: _color,
      targetPercent: _overrideTarget ? _target : null,
      categoryId: _categoryId,
      createdAt: widget.subject?.createdAt,
    );

    final TimetableActions actions = ref.read(actionsProvider);
    int? id = widget.subject?.id;
    if (id == null) {
      id = await actions.addSubject(value);
    } else {
      await actions.updateSubject(value);
    }

    if (!mounted) return;
    Navigator.of(context).pop(id);
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        TextField(
          controller: _name,
          autofocus: widget.subject == null,
          textCapitalization: TextCapitalization.words,
          decoration: const InputDecoration(
            labelText: 'Subject name',
            hintText: 'e.g. Data Structures',
          ),
        ),
        const SizedBox(height: AppSpacing.md),
        Row(
          children: <Widget>[
            Expanded(
              child: TextField(
                controller: _code,
                textCapitalization: TextCapitalization.characters,
                decoration: const InputDecoration(
                  labelText: 'Code',
                  hintText: 'CS201',
                ),
              ),
            ),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: TextField(
                controller: _teacher,
                textCapitalization: TextCapitalization.words,
                decoration: const InputDecoration(
                  labelText: 'Teacher',
                  hintText: 'Optional',
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.xl),
        _CategoryPicker(
          value: _categoryId,
          onChanged: (int? id) => setState(() => _categoryId = id),
        ),
        const SizedBox(height: AppSpacing.xl),
        const SectionHeader('Colour'),
        Wrap(
          spacing: AppSpacing.md,
          runSpacing: AppSpacing.md,
          children: <Widget>[
            for (final int value in AppColors.subjectPalette)
              _ColorDot(
                value: value,
                selected: value == _color,
                onTap: () => setState(() => _color = value),
              ),
          ],
        ),
        const SizedBox(height: AppSpacing.xl),
        SwitchListTile.adaptive(
          value: _overrideTarget,
          onChanged: (bool v) => setState(() => _overrideTarget = v),
          contentPadding: EdgeInsets.zero,
          title: const Text('Custom attendance target'),
          subtitle: Text(
            _overrideTarget
                ? 'This subject needs ${_target.round()}%'
                : 'Uses your global target',
            style: const TextStyle(fontSize: 12.5),
          ),
        ),
        if (_overrideTarget)
          Slider(
            value: _target,
            min: 40,
            max: 100,
            divisions: 60,
            label: '${_target.round()}%',
            onChanged: (double v) => setState(() => _target = v),
          ),
        if (_error != null) ...<Widget>[
          const SizedBox(height: AppSpacing.md),
          Text(
            _error!,
            style: TextStyle(color: context.palette.absent, fontSize: 13),
          ),
        ],
        const SizedBox(height: AppSpacing.xl),
        FilledButton(
          onPressed: _saving ? null : _save,
          child: Text(widget.subject == null ? 'Create subject' : 'Save'),
        ),
      ],
    );
  }
}

/// Recolour a subject without opening the whole form — one tap, saved straight
/// away. Used by the long-press and the overflow menu on the Subjects screen.
Future<void> showSubjectColorPicker(
  BuildContext context,
  WidgetRef ref,
  Subject subject,
) {
  return showAppSheet<void>(
    context: context,
    title: subject.name,
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        const SectionHeader('Colour'),
        Wrap(
          spacing: AppSpacing.md,
          runSpacing: AppSpacing.md,
          children: <Widget>[
            for (final int value in AppColors.subjectPalette)
              _ColorDot(
                value: value,
                selected: value == subject.colorValue,
                onTap: () async {
                  Navigator.of(context).pop();
                  if (value == subject.colorValue) return;
                  await ref
                      .read(actionsProvider)
                      .updateSubject(subject.copyWith(colorValue: value));
                },
              ),
          ],
        ),
      ],
    ),
  );
}

class _ColorDot extends StatelessWidget {
  const _ColorDot({
    required this.value,
    required this.selected,
    required this.onTap,
  });

  final int value;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final Color color = Color(value);
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          color: color.withValues(alpha: selected ? 1 : 0.35),
          shape: BoxShape.circle,
          border: Border.all(
            color: selected ? Colors.white : Colors.transparent,
            width: 2,
          ),
        ),
        child: selected
            ? const Icon(Icons.check_rounded, size: 20, color: Colors.white)
            : null,
      ),
    );
  }
}


/// Chooses which category a subject belongs to, with an inline "new category"
/// escape hatch so the flow is never blocked by missing setup.
class _CategoryPicker extends ConsumerWidget {
  const _CategoryPicker({required this.value, required this.onChanged});

  final int? value;
  final ValueChanged<int?> onChanged;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final List<ClassCategory> categories =
        ref.watch(timetableProvider).value?.categories ?? <ClassCategory>[];
    final int fallback =
        ref.watch(settingsProvider).value?.defaultClassDurationMinutes ?? 60;

    ClassCategory? selected;
    for (final ClassCategory category in categories) {
      if (category.id == value) selected = category;
    }
    final String selectedLabel = selected == null
        ? 'Without a category, new classes default to '
            '${Clock.formatDuration(fallback)}.'
        : '${selected.name} classes default to ${selected.durationLabel}.';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        const SectionHeader('Category'),
        Wrap(
          spacing: AppSpacing.sm,
          runSpacing: AppSpacing.sm,
          children: <Widget>[
            _CategoryChip(
              label: 'None',
              detail: Clock.formatDuration(fallback),
              selected: value == null,
              onTap: () => onChanged(null),
            ),
            for (final ClassCategory category in categories)
              _CategoryChip(
                label: category.name,
                detail: category.durationLabel,
                selected: category.id == value,
                onTap: () => onChanged(category.id),
              ),
            _NewSubjectChip(
              onTap: () async {
                final int? id = await showCategoryEditor(context, ref);
                if (id != null) onChanged(id);
              },
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.sm),
        Text(
          selectedLabel,
          style: TextStyle(
            fontSize: 12,
            height: 1.4,
            color: context.palette.textTertiary,
          ),
        ),
      ],
    );
  }
}

class _CategoryChip extends StatelessWidget {
  const _CategoryChip({
    required this.label,
    required this.detail,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final String detail;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: selected
          ? context.palette.accent.withValues(alpha: 0.18)
          : context.palette.surfaceHigh,
      borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
            border: Border.all(
              color: selected
                  ? context.palette.accent.withValues(alpha: 0.7)
                  : context.palette.outlineSoft,
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              Text(
                label,
                style: TextStyle(
                  fontSize: 13.5,
                  fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                  color: selected
                      ? context.palette.textPrimary
                      : context.palette.textSecondary,
                ),
              ),
              const SizedBox(width: 6),
              Text(
                detail,
                style: TextStyle(
                  fontSize: 11.5,
                  fontWeight: FontWeight.w600,
                  color: context.palette.textTertiary,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ----------------------------------------------------------- category editor

/// Create or edit a class category. Returns its id on save.
Future<int?> showCategoryEditor(
  BuildContext context,
  WidgetRef ref, {
  ClassCategory? category,
}) {
  return showAppSheet<int>(
    context: context,
    title: category == null ? 'New category' : 'Edit category',
    child: _CategoryForm(category: category),
  );
}

class _CategoryForm extends ConsumerStatefulWidget {
  const _CategoryForm({this.category});

  final ClassCategory? category;

  @override
  ConsumerState<_CategoryForm> createState() => _CategoryFormState();
}

class _CategoryFormState extends ConsumerState<_CategoryForm> {
  late final TextEditingController _name;
  late int _minutes;
  String? _error;
  bool _saving = false;

  /// Lengths a timetable actually uses, so the common case is one tap.
  static const List<int> _presets = <int>[30, 45, 50, 60, 90, 120, 180];

  @override
  void initState() {
    super.initState();
    _name = TextEditingController(text: widget.category?.name ?? '');
    _minutes = widget.category?.defaultDurationMinutes ?? 60;
  }

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final String name = _name.text.trim();
    if (name.isEmpty) {
      setState(() => _error = 'Give the category a name.');
      return;
    }

    final List<ClassCategory> existing =
        ref.read(timetableProvider).value?.categories ?? <ClassCategory>[];
    for (final ClassCategory other in existing) {
      if (other.id == widget.category?.id) continue;
      if (other.name.toLowerCase() == name.toLowerCase()) {
        setState(() => _error = 'You already have a category called "$name".');
        return;
      }
    }

    setState(() {
      _saving = true;
      _error = null;
    });

    final TimetableActions actions = ref.read(actionsProvider);
    int? id = widget.category?.id;
    if (id == null) {
      id = await actions.addCategory(
        ClassCategory(name: name, defaultDurationMinutes: _minutes),
      );
    } else {
      await actions.updateCategory(
        ClassCategory(
          id: id,
          name: name,
          defaultDurationMinutes: _minutes,
          createdAt: widget.category?.createdAt,
        ),
      );
    }

    if (!mounted) return;
    Navigator.of(context).pop(id);
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        TextField(
          controller: _name,
          autofocus: widget.category == null,
          textCapitalization: TextCapitalization.words,
          decoration: const InputDecoration(
            labelText: 'Category name',
            hintText: 'e.g. Lab, Theory, Tutorial',
          ),
        ),
        const SizedBox(height: AppSpacing.xl),
        const SectionHeader('Default class length'),
        Wrap(
          spacing: AppSpacing.sm,
          runSpacing: AppSpacing.sm,
          children: <Widget>[
            for (final int preset in _presets)
              _DurationChip(
                minutes: preset,
                selected: preset == _minutes,
                onTap: () => setState(() => _minutes = preset),
              ),
          ],
        ),
        const SizedBox(height: AppSpacing.md),
        Row(
          children: <Widget>[
            Expanded(
              child: Slider(
                value: _minutes.toDouble().clamp(15, 300),
                min: 15,
                max: 300,
                divisions: 57,
                label: Clock.formatDuration(_minutes),
                onChanged: (double v) =>
                    setState(() => _minutes = (v / 5).round() * 5),
              ),
            ),
            SizedBox(
              width: 62,
              child: Text(
                Clock.formatDuration(_minutes),
                textAlign: TextAlign.end,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: context.palette.accent,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.sm),
        Text(
          'Picking a start time for a class in this category fills the end '
          'time in automatically.',
          style: TextStyle(
            fontSize: 12,
            height: 1.4,
            color: context.palette.textTertiary,
          ),
        ),
        if (_error != null) ...<Widget>[
          const SizedBox(height: AppSpacing.md),
          Text(
            _error!,
            style: TextStyle(color: context.palette.absent, fontSize: 13),
          ),
        ],
        const SizedBox(height: AppSpacing.xl),
        FilledButton(
          onPressed: _saving ? null : _save,
          child: Text(
            widget.category == null ? 'Create category' : 'Save changes',
          ),
        ),
      ],
    );
  }
}

class _DurationChip extends StatelessWidget {
  const _DurationChip({
    required this.minutes,
    required this.selected,
    required this.onTap,
  });

  final int minutes;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: selected
          ? context.palette.accent.withValues(alpha: 0.18)
          : context.palette.surfaceHigh,
      borderRadius: BorderRadius.circular(AppSpacing.radiusSm),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppSpacing.radiusSm),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(AppSpacing.radiusSm),
            border: Border.all(
              color: selected
                  ? context.palette.accent.withValues(alpha: 0.7)
                  : context.palette.outlineSoft,
            ),
          ),
          child: Text(
            Clock.formatDuration(minutes),
            style: TextStyle(
              fontSize: 13,
              fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
              color:
                  selected ? context.palette.textPrimary : context.palette.textSecondary,
            ),
          ),
        ),
      ),
    );
  }
}

// --------------------------------------------------------- recurring editor

/// Create or edit a weekly recurring class.
Future<void> showSlotEditor(
  BuildContext context,
  WidgetRef ref, {
  ClassSlot? slot,
  DateTime? initialDate,
}) {
  return showAppSheet<void>(
    context: context,
    title: slot == null ? 'Weekly class' : 'Edit weekly class',
    child: _SlotForm(slot: slot, initialDate: initialDate),
  );
}

class _SlotForm extends ConsumerStatefulWidget {
  const _SlotForm({this.slot, this.initialDate});

  final ClassSlot? slot;
  final DateTime? initialDate;

  @override
  ConsumerState<_SlotForm> createState() => _SlotFormState();
}

/// One meeting of a recurring class: a weekday, its times and its room.
///
/// A subject can meet more than once on the same day — a morning lecture and
/// an afternoon lab — and the room often differs per meeting, so every entry
/// is fully independent rather than sharing a time or a room.
class _ClassTime {
  _ClassTime({
    required this.weekday,
    required this.startMinutes,
    required this.endMinutes,
    String room = '',
  }) : roomController = TextEditingController(text: room);

  int weekday;
  int startMinutes;
  int endMinutes;
  final TextEditingController roomController;

  int get durationMinutes => endMinutes - startMinutes;

  String? get room {
    final String value = roomController.text.trim();
    return value.isEmpty ? null : value;
  }

  void dispose() => roomController.dispose();
}

class _SlotFormState extends ConsumerState<_SlotForm> {
  int? _subjectId;

  /// Every meeting this form will create. Order is irrelevant — the list is
  /// grouped by weekday for display and sorted on save.
  final List<_ClassTime> _times = <_ClassTime>[];

  /// The last times the user chose. A newly ticked day inherits them, so when
  /// the schedule *is* uniform it stays a couple of taps.
  int _lastStart = 9 * 60;
  int _lastEnd = 10 * 60;

  late DateTime _startDate;
  DateTime? _endDate;
  String? _error;
  bool _saving = false;

  /// Set once an *end* time has been chosen by hand, after which changing the
  /// subject no longer re-lengths the rows. Picking a start time deliberately
  /// does not count: that chooses when the class sits, not how long it runs,
  /// so the category default should still apply to it.
  bool _durationTouched = false;

  bool get _isEditing => widget.slot != null;

  /// The class length implied by the chosen subject's category, falling back
  /// to the global setting.
  int get _defaultDuration => ref.read(defaultDurationProvider(_subjectId));

  /// Re-lengths every row from the current default. Call inside setState.
  void _applyDefaultDurationToAll() {
    final int duration = _defaultDuration;
    for (final _ClassTime time in _times) {
      time.endMinutes = Clock.endFromStart(time.startMinutes, duration);
    }
    if (_times.isNotEmpty) _lastEnd = _times.first.endMinutes;
  }

  /// Selected weekdays, Monday first.
  List<int> get _days {
    final Set<int> unique = <int>{
      for (final _ClassTime time in _times) time.weekday,
    };
    return unique.toList()..sort();
  }

  List<_ClassTime> _timesOn(int weekday) {
    final List<_ClassTime> rows = _times
        .where((_ClassTime time) => time.weekday == weekday)
        .toList();
    rows.sort((_ClassTime a, _ClassTime b) =>
        a.startMinutes.compareTo(b.startMinutes));
    return rows;
  }

  @override
  void initState() {
    super.initState();
    final ClassSlot? slot = widget.slot;
    final DateTime seed = widget.initialDate ?? Dates.today();
    _subjectId = slot?.subjectId;

    if (slot != null) {
      _lastStart = slot.startMinutes;
      _lastEnd = slot.endMinutes;
      _times.add(
        _ClassTime(
          weekday: slot.weekday,
          startMinutes: slot.startMinutes,
          endMinutes: slot.endMinutes,
          room: slot.room ?? '',
        ),
      );
    } else {
      _times.add(
        _ClassTime(
          weekday: seed.weekday,
          startMinutes: _lastStart,
          endMinutes: _lastEnd,
        ),
      );
    }

    _startDate = slot?.startDate ?? seed;
    _endDate = slot?.endDate;
  }

  @override
  void dispose() {
    for (final _ClassTime time in _times) {
      time.dispose();
    }
    super.dispose();
  }

  void _toggleWeekday(int weekday) {
    setState(() {
      _error = null;

      if (_isEditing) {
        // Editing a single rule: picking a day moves it, it does not add one.
        _times.first.weekday = weekday;
        return;
      }

      final List<_ClassTime> existing = _timesOn(weekday);
      if (existing.isNotEmpty) {
        // Always leave at least one day selected.
        if (_days.length == 1) return;
        for (final _ClassTime time in existing) {
          _times.remove(time);
          time.dispose();
        }
        return;
      }

      _times.add(
        _ClassTime(
          weekday: weekday,
          startMinutes: _lastStart,
          endMinutes: _lastEnd,
        ),
      );
    });
  }

  /// Adds another meeting on [weekday], starting when the previous one ends —
  /// which is usually what a second class that day looks like.
  void _addTimeOn(int weekday) {
    setState(() {
      _error = null;
      final List<_ClassTime> rows = _timesOn(weekday);
      final int duration = _defaultDuration;
      int start = rows.isEmpty ? _lastStart : rows.last.endMinutes;
      if (start > Clock.minutesPerDay - duration - 5) {
        start = Clock.minutesPerDay - duration - 5;
      }
      if (start < 0) start = 0;
      _times.add(
        _ClassTime(
          weekday: weekday,
          startMinutes: start,
          endMinutes: Clock.endFromStart(start, duration),
        ),
      );
    });
  }

  void _removeTime(_ClassTime time) {
    setState(() {
      if (_times.length == 1) return;
      _times.remove(time);
      time.dispose();
      _error = null;
    });
  }

  Future<void> _pickTime(_ClassTime time, {required bool isStart}) async {
    final int current = isStart ? time.startMinutes : time.endMinutes;
    final TimeOfDay? picked = await showTimePicker(
      context: context,
      initialTime: TimeOfDay(
        hour: Clock.hourOf(current),
        minute: Clock.minuteOf(current),
      ),
      helpText: '${kWeekdayNamesLong[time.weekday - 1]} · '
          '${isStart ? 'start time' : 'end time'}',
    );
    if (picked == null || !mounted) return;

    setState(() {
      _error = null;
      final int value = Clock.toMinutes(picked.hour, picked.minute);
      if (isStart) {
        // Setting a start fills the end in from the category's default length,
        // which is the whole point of categories. An end the user already set
        // by hand is kept, and only shifted to preserve its length.
        final int duration =
            _durationTouched ? time.durationMinutes : _defaultDuration;
        time.startMinutes = value;
        time.endMinutes = Clock.endFromStart(value, duration);
      } else {
        _durationTouched = true;
        time.endMinutes = value;
      }
      _lastStart = time.startMinutes;
      _lastEnd = time.endMinutes;
    });
  }

  Future<void> _pickDate({required bool isStart}) async {
    final DateTime initial =
        isStart ? _startDate : (_endDate ?? Dates.addDays(_startDate, 120));
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: DateTime(DateTime.now().year - 2),
      lastDate: DateTime(DateTime.now().year + 3),
    );
    if (picked == null || !mounted) return;
    setState(() {
      if (isStart) {
        _startDate = Dates.dayOf(picked);
      } else {
        _endDate = Dates.dayOf(picked);
      }
    });
  }

  /// Two meetings of the same subject that start at the same minute on the
  /// same weekday would share one attendance key, so marking one would mark
  /// the other. They are rejected rather than silently merged.
  String? _validateClashes() {
    for (int i = 0; i < _times.length; i++) {
      for (int j = i + 1; j < _times.length; j++) {
        if (_times[i].weekday == _times[j].weekday &&
            _times[i].startMinutes == _times[j].startMinutes) {
          return 'Two classes on '
              '${kWeekdayNamesLong[_times[i].weekday - 1]} start at '
              '${Clock.format(_times[i].startMinutes)}. Give them different '
              'start times.';
        }
      }
    }

    final List<ClassSlot> existing =
        ref.read(timetableProvider).value?.slots ?? <ClassSlot>[];
    for (final _ClassTime time in _times) {
      for (final ClassSlot slot in existing) {
        if (slot.subjectId != _subjectId) continue;
        if (slot.id == widget.slot?.id) continue;
        if (slot.weekday == time.weekday &&
            slot.startMinutes == time.startMinutes) {
          return 'This subject already has a class on '
              '${kWeekdayNamesLong[time.weekday - 1]} at '
              '${Clock.format(time.startMinutes)}.';
        }
      }
    }
    return null;
  }

  Future<void> _save() async {
    if (_subjectId == null) {
      setState(() => _error = 'Choose a subject.');
      return;
    }
    if (_times.isEmpty) {
      setState(() => _error = 'Add at least one class time.');
      return;
    }
    for (final _ClassTime time in _times) {
      if (time.endMinutes <= time.startMinutes) {
        setState(() {
          _error = '${kWeekdayNamesLong[time.weekday - 1]}: the end time must '
              'be after the start time.';
        });
        return;
      }
    }
    final String? clash = _validateClashes();
    if (clash != null) {
      setState(() => _error = clash);
      return;
    }
    if (_endDate != null && Dates.keyOf(_endDate!) < Dates.keyOf(_startDate)) {
      setState(() => _error = 'The end date is before the start date.');
      return;
    }

    setState(() {
      _saving = true;
      _error = null;
    });

    final TimetableActions actions = ref.read(actionsProvider);

    if (_isEditing) {
      final _ClassTime time = _times.first;
      // Rebuilt rather than copyWith so clearing the room actually clears it.
      await actions.updateSlot(
        ClassSlot(
          id: widget.slot!.id,
          subjectId: _subjectId!,
          weekday: time.weekday,
          startMinutes: time.startMinutes,
          endMinutes: time.endMinutes,
          room: time.room,
          startDate: _startDate,
          endDate: _endDate,
        ),
      );
    } else {
      final List<_ClassTime> ordered = <_ClassTime>[..._times]..sort(
          (_ClassTime a, _ClassTime b) {
            final int byDay = a.weekday.compareTo(b.weekday);
            return byDay != 0
                ? byDay
                : a.startMinutes.compareTo(b.startMinutes);
          },
        );
      for (final _ClassTime time in ordered) {
        await actions.addSlot(
          ClassSlot(
            subjectId: _subjectId!,
            weekday: time.weekday,
            startMinutes: time.startMinutes,
            endMinutes: time.endMinutes,
            room: time.room,
            startDate: _startDate,
            endDate: _endDate,
          ),
        );
      }
    }

    if (!mounted) return;
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final bool use24Hour =
        ref.watch(settingsProvider).value?.use24HourTime ?? false;
    final int defaultDuration =
        ref.watch(defaultDurationProvider(_subjectId));
    final List<int> days = _days;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        _SubjectPicker(
          value: _subjectId,
          onChanged: (int? id) => setState(() {
            _subjectId = id;
            // Adopt the new category's length, unless the user set an end
            // time by hand.
            if (!_durationTouched) _applyDefaultDurationToAll();
          }),
        ),
        const SizedBox(height: AppSpacing.xl),

        SectionHeader(_isEditing ? 'Day' : 'Repeats on'),
        _WeekdaySelector(
          selected: days.toSet(),
          onToggle: _toggleWeekday,
        ),
        const SizedBox(height: AppSpacing.xl),

        SectionHeader(
          _isEditing ? 'Time and room' : 'Class times',
          trailing: Text(
            'defaults to ${Clock.formatDuration(defaultDuration)}',
            style: TextStyle(
              fontSize: 11.5,
              fontWeight: FontWeight.w600,
              color: context.palette.textTertiary,
            ),
          ),
        ),
        for (final int weekday in days)
          _DayGroup(
            weekday: weekday,
            times: _timesOn(weekday),
            use24Hour: use24Hour,
            showHeader: !_isEditing,
            canRemove: _times.length > 1,
            onAddTime: _isEditing ? null : () => _addTimeOn(weekday),
            onPickStart: (_ClassTime t) => _pickTime(t, isStart: true),
            onPickEnd: (_ClassTime t) => _pickTime(t, isStart: false),
            onRemove: _removeTime,
          ),

        if (!_isEditing) ...<Widget>[
          const SizedBox(height: AppSpacing.xs),
          Text(
            'Each entry keeps its own time and room. Setting a start time '
            'fills the end in from the subject\'s category, and "Add another '
            'time" covers a subject that meets twice in one day.',
            style: TextStyle(
              fontSize: 12,
              height: 1.4,
              color: context.palette.textTertiary,
            ),
          ),
        ],
        const SizedBox(height: AppSpacing.xl),

        const SectionHeader('Runs from'),
        Row(
          children: <Widget>[
            Expanded(
              child: _FieldButton(
                label: 'First class',
                value: Dates.formatFull(_startDate),
                icon: Icons.play_arrow_rounded,
                onTap: () => _pickDate(isStart: true),
              ),
            ),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: _FieldButton(
                label: 'Until',
                value: _endDate == null
                    ? 'Semester end'
                    : Dates.formatFull(_endDate!),
                icon: Icons.stop_rounded,
                onTap: () => _pickDate(isStart: false),
                onClear: _endDate == null
                    ? null
                    : () => setState(() => _endDate = null),
              ),
            ),
          ],
        ),

        if (_error != null) ...<Widget>[
          const SizedBox(height: AppSpacing.md),
          Text(
            _error!,
            style: TextStyle(color: context.palette.absent, fontSize: 13),
          ),
        ],
        const SizedBox(height: AppSpacing.xl),
        FilledButton(
          onPressed: _saving ? null : _save,
          child: Text(
            _isEditing
                ? 'Save changes'
                : (_times.length > 1
                    ? 'Add ${_times.length} weekly classes'
                    : 'Add to timetable'),
          ),
        ),
      ],
    );
  }
}

/// All the meetings on one weekday, with a control to add another.
class _DayGroup extends StatelessWidget {
  const _DayGroup({
    required this.weekday,
    required this.times,
    required this.use24Hour,
    required this.showHeader,
    required this.canRemove,
    required this.onPickStart,
    required this.onPickEnd,
    required this.onRemove,
    this.onAddTime,
  });

  final int weekday;
  final List<_ClassTime> times;
  final bool use24Hour;
  final bool showHeader;
  final bool canRemove;
  final VoidCallback? onAddTime;
  final ValueChanged<_ClassTime> onPickStart;
  final ValueChanged<_ClassTime> onPickEnd;
  final ValueChanged<_ClassTime> onRemove;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          if (showHeader)
            Padding(
              padding: const EdgeInsets.only(
                left: AppSpacing.xs,
                bottom: AppSpacing.sm,
              ),
              child: Row(
                children: <Widget>[
                  Expanded(
                    child: Text(
                      kWeekdayNamesLong[weekday - 1].toUpperCase(),
                      style: TextStyle(
                        fontSize: 11.5,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 1.1,
                        color: context.palette.textSecondary,
                      ),
                    ),
                  ),
                  if (times.length > 1)
                    Text(
                      '${times.length} classes',
                      style: TextStyle(
                        fontSize: 11.5,
                        fontWeight: FontWeight.w600,
                        color: context.palette.textTertiary,
                      ),
                    ),
                ],
              ),
            ),
          for (final _ClassTime time in times)
            Padding(
              padding: const EdgeInsets.only(bottom: AppSpacing.sm),
              child: _ClassTimeCard(
                time: time,
                use24Hour: use24Hour,
                canRemove: canRemove,
                onPickStart: () => onPickStart(time),
                onPickEnd: () => onPickEnd(time),
                onRemove: () => onRemove(time),
              ),
            ),
          if (onAddTime != null)
            Align(
              alignment: Alignment.centerLeft,
              child: TextButton.icon(
                onPressed: onAddTime,
                icon: const Icon(Icons.add_rounded, size: 17),
                label: Text(
                  'Add another time on ${kWeekdayNamesLong[weekday - 1]}',
                ),
                style: TextButton.styleFrom(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.sm,
                  ),
                  textStyle: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

/// A single meeting: its start and end times plus its own room.
class _ClassTimeCard extends StatelessWidget {
  const _ClassTimeCard({
    required this.time,
    required this.use24Hour,
    required this.canRemove,
    required this.onPickStart,
    required this.onPickEnd,
    required this.onRemove,
  });

  final _ClassTime time;
  final bool use24Hour;
  final bool canRemove;
  final VoidCallback onPickStart;
  final VoidCallback onPickEnd;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.md,
        AppSpacing.md,
        AppSpacing.sm,
        AppSpacing.md,
      ),
      decoration: BoxDecoration(
        color: context.palette.surfaceHigh,
        borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
        border: Border.all(color: context.palette.outline),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Row(
            children: <Widget>[
              _TimeChip(
                label: Clock.format(time.startMinutes, use24Hour: use24Hour),
                onTap: onPickStart,
              ),
              Padding(
                padding: EdgeInsets.symmetric(horizontal: AppSpacing.sm),
                child: Text(
                  '–',
                  style: TextStyle(color: context.palette.textTertiary, fontSize: 13),
                ),
              ),
              _TimeChip(
                label: Clock.format(time.endMinutes, use24Hour: use24Hour),
                onTap: onPickEnd,
              ),
              const Spacer(),
              Text(
                Clock.formatDuration(time.endMinutes - time.startMinutes),
                style: TextStyle(
                  fontSize: 11.5,
                  fontWeight: FontWeight.w600,
                  color: context.palette.textTertiary,
                ),
              ),
              IconButton(
                onPressed: canRemove ? onRemove : null,
                icon: const Icon(Icons.close_rounded, size: 17),
                visualDensity: VisualDensity.compact,
                color: context.palette.textTertiary,
                tooltip: 'Remove this class time',
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          TextField(
            controller: time.roomController,
            textCapitalization: TextCapitalization.characters,
            style: const TextStyle(fontSize: 14),
            decoration: InputDecoration(
              isDense: true,
              prefixIcon: Icon(Icons.place_outlined, size: 17),
              prefixIconConstraints: BoxConstraints(
                minWidth: 34,
                minHeight: 34,
              ),
              hintText: 'Room (optional)',
              filled: true,
              fillColor: context.palette.surfaceHigher,
              contentPadding: EdgeInsets.symmetric(
                horizontal: AppSpacing.sm,
                vertical: AppSpacing.md,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _TimeChip extends StatelessWidget {
  const _TimeChip({required this.label, required this.onTap});

  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: context.palette.surfaceHigher,
      borderRadius: BorderRadius.circular(AppSpacing.radiusSm),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppSpacing.radiusSm),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(AppSpacing.radiusSm),
            border: Border.all(color: context.palette.outline),
          ),
          child: Text(
            label,
            style: const TextStyle(
              fontSize: 13.5,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ),
    );
  }
}

// -------------------------------------------------------- one-off class form

Future<void> showExtraClassEditor(
  BuildContext context,
  WidgetRef ref, {
  DateTime? initialDate,
}) {
  return showAppSheet<void>(
    context: context,
    title: 'One-off class',
    child: _ExtraClassForm(initialDate: initialDate),
  );
}

class _ExtraClassForm extends ConsumerStatefulWidget {
  const _ExtraClassForm({this.initialDate});

  final DateTime? initialDate;

  @override
  ConsumerState<_ExtraClassForm> createState() => _ExtraClassFormState();
}

class _ExtraClassFormState extends ConsumerState<_ExtraClassForm> {
  int? _subjectId;
  late DateTime _date;
  int _start = 9 * 60;
  int _end = 10 * 60;
  final TextEditingController _room = TextEditingController();
  String? _error;
  bool _saving = false;

  /// See the weekly form: only a hand-set end time pins the length.
  bool _durationTouched = false;

  int get _defaultDuration => ref.read(defaultDurationProvider(_subjectId));

  @override
  void initState() {
    super.initState();
    _date = widget.initialDate ?? Dates.today();
  }

  @override
  void dispose() {
    _room.dispose();
    super.dispose();
  }

  Future<void> _pickTime({required bool isStart}) async {
    final int current = isStart ? _start : _end;
    final TimeOfDay? picked = await showTimePicker(
      context: context,
      initialTime: TimeOfDay(
        hour: Clock.hourOf(current),
        minute: Clock.minuteOf(current),
      ),
    );
    if (picked == null || !mounted) return;
    setState(() {
      final int value = Clock.toMinutes(picked.hour, picked.minute);
      if (isStart) {
        final int duration =
            _durationTouched ? _end - _start : _defaultDuration;
        _start = value;
        _end = Clock.endFromStart(value, duration);
      } else {
        _durationTouched = true;
        _end = value;
      }
    });
  }

  Future<void> _pickDate() async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _date,
      firstDate: DateTime(DateTime.now().year - 2),
      lastDate: DateTime(DateTime.now().year + 3),
    );
    if (picked == null || !mounted) return;
    setState(() => _date = Dates.dayOf(picked));
  }

  Future<void> _save() async {
    if (_subjectId == null) {
      setState(() => _error = 'Choose a subject.');
      return;
    }
    if (_end <= _start) {
      setState(() => _error = 'The end time must be after the start time.');
      return;
    }
    setState(() {
      _saving = true;
      _error = null;
    });

    await ref.read(actionsProvider).addExtraClass(
          ExtraClass(
            subjectId: _subjectId!,
            date: _date,
            startMinutes: _start,
            endMinutes: _end,
            room: _room.text.trim().isEmpty ? null : _room.text.trim(),
          ),
        );

    if (!mounted) return;
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        _SubjectPicker(
          value: _subjectId,
          onChanged: (int? id) => setState(() {
            _subjectId = id;
            if (!_durationTouched) {
              _end = Clock.endFromStart(_start, _defaultDuration);
            }
          }),
        ),
        const SizedBox(height: AppSpacing.xl),
        const SectionHeader('When'),
        _FieldButton(
          label: 'Date',
          value: '${Dates.weekdayLong(_date)}, ${Dates.formatFull(_date)}',
          icon: Icons.event_rounded,
          onTap: _pickDate,
        ),
        const SizedBox(height: AppSpacing.md),
        Row(
          children: <Widget>[
            Expanded(
              child: _FieldButton(
                label: 'Starts',
                value: Clock.format(_start),
                icon: Icons.schedule_rounded,
                onTap: () => _pickTime(isStart: true),
              ),
            ),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: _FieldButton(
                label: 'Ends',
                value: Clock.format(_end),
                icon: Icons.schedule_rounded,
                onTap: () => _pickTime(isStart: false),
              ),
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.md),
        TextField(
          controller: _room,
          textCapitalization: TextCapitalization.characters,
          decoration: const InputDecoration(
            labelText: 'Room',
            hintText: 'Optional',
          ),
        ),
        if (_error != null) ...<Widget>[
          const SizedBox(height: AppSpacing.md),
          Text(
            _error!,
            style: TextStyle(color: context.palette.absent, fontSize: 13),
          ),
        ],
        const SizedBox(height: AppSpacing.xl),
        FilledButton(
          onPressed: _saving ? null : _save,
          child: const Text('Add class'),
        ),
      ],
    );
  }
}

// ------------------------------------------------------------ shared pieces

/// Dropdown of existing subjects with an inline "create new" option.
class _SubjectPicker extends ConsumerWidget {
  const _SubjectPicker({required this.value, required this.onChanged});

  final int? value;
  final ValueChanged<int?> onChanged;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final List<Subject> subjects =
        ref.watch(timetableProvider).value?.subjects ?? <Subject>[];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        const SectionHeader('Subject'),
        if (subjects.isEmpty)
          SurfaceCard(
            color: context.palette.surfaceHigh,
            onTap: () async {
              final int? id = await showSubjectEditor(context, ref);
              if (id != null) onChanged(id);
            },
            child: Row(
              children: <Widget>[
                Icon(Icons.add_rounded, color: context.palette.accent),
                SizedBox(width: AppSpacing.md),
                Expanded(
                  child: Text(
                    'Create your first subject',
                    style: TextStyle(fontWeight: FontWeight.w600),
                  ),
                ),
              ],
            ),
          )
        else
          Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              Wrap(
                spacing: AppSpacing.sm,
                runSpacing: AppSpacing.sm,
                children: <Widget>[
                  for (final Subject subject in subjects)
                    _SubjectChip(
                      subject: subject,
                      selected: subject.id == value,
                      onTap: () => onChanged(subject.id),
                    ),
                  _NewSubjectChip(
                    onTap: () async {
                      final int? id = await showSubjectEditor(context, ref);
                      if (id != null) onChanged(id);
                    },
                  ),
                ],
              ),
            ],
          ),
      ],
    );
  }
}

class _SubjectChip extends StatelessWidget {
  const _SubjectChip({
    required this.subject,
    required this.selected,
    required this.onTap,
  });

  final Subject subject;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final Color color = subject.color;
    return Material(
      color: selected ? color.withValues(alpha: 0.18) : context.palette.surfaceHigh,
      borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
            border: Border.all(
              color: selected
                  ? color.withValues(alpha: 0.7)
                  : context.palette.outlineSoft,
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              Container(
                width: 10,
                height: 10,
                decoration: BoxDecoration(color: color, shape: BoxShape.circle),
              ),
              const SizedBox(width: 8),
              Text(
                subject.name,
                style: TextStyle(
                  fontSize: 13.5,
                  fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                  color: selected ? context.palette.textPrimary : context.palette.textSecondary,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _NewSubjectChip extends StatelessWidget {
  const _NewSubjectChip({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
            border: Border.all(color: context.palette.accent.withValues(alpha: 0.5)),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              Icon(Icons.add_rounded, size: 16, color: context.palette.accent),
              SizedBox(width: 6),
              Text(
                'New',
                style: TextStyle(
                  fontSize: 13.5,
                  fontWeight: FontWeight.w600,
                  color: context.palette.accent,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _WeekdaySelector extends StatelessWidget {
  const _WeekdaySelector({required this.selected, required this.onToggle});

  final Set<int> selected;
  final ValueChanged<int> onToggle;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: <Widget>[
        for (int weekday = 1; weekday <= 7; weekday++) ...<Widget>[
          Expanded(
            child: _WeekdayCell(
              weekday: weekday,
              selected: selected.contains(weekday),
              onTap: () => onToggle(weekday),
            ),
          ),
          if (weekday != 7) const SizedBox(width: 6),
        ],
      ],
    );
  }
}

class _WeekdayCell extends StatelessWidget {
  const _WeekdayCell({
    required this.weekday,
    required this.selected,
    required this.onTap,
  });

  final int weekday;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: selected ? context.palette.accent : context.palette.surfaceHigh,
      borderRadius: BorderRadius.circular(AppSpacing.radiusSm),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppSpacing.radiusSm),
        child: Container(
          alignment: Alignment.center,
          padding: const EdgeInsets.symmetric(vertical: 12),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(AppSpacing.radiusSm),
            border: Border.all(
              color: selected ? context.palette.accent : context.palette.outlineSoft,
            ),
          ),
          child: Text(
            kWeekdayNamesShort[weekday - 1].substring(0, 1),
            style: TextStyle(
              fontSize: 13.5,
              fontWeight: FontWeight.w700,
              color: selected ? Colors.white : context.palette.textSecondary,
            ),
          ),
        ),
      ),
    );
  }
}

/// Tappable pseudo-field used for time and date pickers.
class _FieldButton extends StatelessWidget {
  const _FieldButton({
    required this.label,
    required this.value,
    required this.icon,
    required this.onTap,
    this.onClear,
  });

  final String label;
  final String value;
  final IconData icon;
  final VoidCallback onTap;
  final VoidCallback? onClear;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: context.palette.surfaceHigh,
      borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
        child: Container(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.lg,
            vertical: AppSpacing.md,
          ),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
            border: Border.all(color: context.palette.outline),
          ),
          child: Row(
            children: <Widget>[
              Icon(icon, size: 16, color: context.palette.textTertiary),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      label,
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: context.palette.textTertiary,
                      ),
                    ),
                    const SizedBox(height: 1),
                    Text(
                      value,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
              if (onClear != null)
                GestureDetector(
                  onTap: onClear,
                  child: Icon(
                    Icons.close_rounded,
                    size: 16,
                    color: context.palette.textTertiary,
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

// ----------------------------------------------------------- session options

/// Long-press menu on a class: cancel just this one, stop it repeating, or
/// remove it entirely.
Future<void> showSessionOptions(
  BuildContext context,
  WidgetRef ref,
  ClassSession session,
) async {
  await showAppSheet<void>(
    context: context,
    title: session.subject.name,
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        _OptionTile(
          icon: Icons.block_rounded,
          title: 'Cancel just this class',
          subtitle:
              'Marks ${Dates.formatDayMonth(session.date)} as cancelled. It stops counting towards your percentage.',
          onTap: () async {
            Navigator.of(context).pop();
            await ref
                .read(actionsProvider)
                .mark(session, AttendanceStatus.cancelled);
          },
        ),
        if (session.slotId != null) ...<Widget>[
          const SizedBox(height: AppSpacing.md),
          _OptionTile(
            icon: Icons.event_busy_rounded,
            title: 'Stop repeating from this date',
            subtitle:
                'Keeps everything already recorded, but the class no longer appears from ${Dates.formatDayMonth(session.date)} onwards.',
            onTap: () async {
              Navigator.of(context).pop();
              await ref
                  .read(actionsProvider)
                  .endSlotFrom(session.slotId!, session.date);
            },
          ),
          const SizedBox(height: AppSpacing.md),
          _OptionTile(
            icon: Icons.delete_outline_rounded,
            title: 'Delete this weekly class',
            // Marks are keyed by (subject, date, start time), not by slot id,
            // so deleting the rule does not delete them. Saying otherwise here
            // would be a lie told at the moment of a destructive action.
            subtitle: 'Removes the rule and its future weeks. Attendance you '
                'already marked is kept and still counts.',
            danger: true,
            onTap: () async {
              Navigator.of(context).pop();
              await ref.read(actionsProvider).deleteSlot(session.slotId!);
            },
          ),
        ],
        if (session.extraClassId != null) ...<Widget>[
          const SizedBox(height: AppSpacing.md),
          _OptionTile(
            icon: Icons.delete_outline_rounded,
            title: 'Delete this one-off class',
            subtitle: 'Removes it from your timetable.',
            danger: true,
            onTap: () async {
              Navigator.of(context).pop();
              await ref
                  .read(actionsProvider)
                  .deleteExtraClass(session.extraClassId!);
            },
          ),
        ],
        if (session.isMarked) ...<Widget>[
          const SizedBox(height: AppSpacing.md),
          _OptionTile(
            icon: Icons.undo_rounded,
            title: 'Clear the mark',
            subtitle: 'Sets this class back to unmarked.',
            onTap: () async {
              Navigator.of(context).pop();
              await ref.read(actionsProvider).clearMark(session);
            },
          ),
        ],
      ],
    ),
  );
}

class _OptionTile extends StatelessWidget {
  const _OptionTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
    this.danger = false,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;
  final bool danger;

  @override
  Widget build(BuildContext context) {
    final Color color = danger ? context.palette.absent : context.palette.textPrimary;
    return SurfaceCard(
      color: context.palette.surfaceHigh,
      onTap: onTap,
      padding: const EdgeInsets.all(AppSpacing.lg),
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
                  style: TextStyle(
                    fontSize: 14.5,
                    fontWeight: FontWeight.w700,
                    color: color,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  subtitle,
                  style: TextStyle(
                    fontSize: 12.5,
                    height: 1.35,
                    color: context.palette.textSecondary,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
