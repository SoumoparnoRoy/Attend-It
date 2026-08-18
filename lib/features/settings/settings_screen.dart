import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/app_theme.dart';
import '../../core/date_utils.dart';
import '../../data/models/class_category.dart';
import '../../data/models/holiday.dart';
import '../../data/models/subject.dart';
import '../../data/settings/app_settings.dart';
import '../../services/backup_service.dart';
import '../../services/notification_service.dart';
import '../../state/providers.dart';
import '../../widgets/common.dart';
import '../subjects/class_editor_sheets.dart';
import '../subjects/subjects_screen.dart';
import 'timetable_layout_section.dart';

/// Semester setup, attendance target, notifications, holidays and backup.
class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AppSettings settings =
        ref.watch(settingsProvider).value ?? const AppSettings();
    final TimetableData? timetable = ref.watch(timetableProvider).value;
    final List<Holiday> holidays = timetable?.holidays ?? <Holiday>[];
    final List<ClassCategory> categories =
        timetable?.categories ?? <ClassCategory>[];
    final List<Subject> subjects = timetable?.subjects ?? <Subject>[];
    final int classCount =
        (timetable?.slots.length ?? 0) + (timetable?.extras.length ?? 0);
    final SettingsController controller =
        ref.read(settingsProvider.notifier);

    return Scaffold(
      body: SafeArea(
        bottom: false,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.lg,
            AppSpacing.lg,
            AppSpacing.lg,
            100,
          ),
          children: <Widget>[
            const Text(
              'Settings',
              style: TextStyle(
                fontSize: 28,
                fontWeight: FontWeight.w800,
                letterSpacing: -1,
              ),
            ),
            const SizedBox(height: AppSpacing.xl),

            // ------------------------------------------------------ semester
            const SectionHeader('Semester'),
            SurfaceCard(
              padding: EdgeInsets.zero,
              child: Column(
                children: <Widget>[
                  _Row(
                    icon: Icons.play_circle_outline_rounded,
                    title: 'Starts',
                    value: settings.semesterStart == null
                        ? 'Not set'
                        : Dates.formatFull(settings.semesterStart!),
                    onTap: () => _pickSemesterDate(
                      context,
                      controller,
                      settings,
                      isStart: true,
                    ),
                  ),
                  const Divider(indent: AppSpacing.lg),
                  _Row(
                    icon: Icons.stop_circle_outlined,
                    title: 'Ends',
                    value: settings.semesterEnd == null
                        ? 'Not set'
                        : Dates.formatFull(settings.semesterEnd!),
                    onTap: () => _pickSemesterDate(
                      context,
                      controller,
                      settings,
                      isStart: false,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: AppSpacing.sm),
            const _Hint(
              'Recurring classes only appear between these dates, and the '
              '"classes left" figures are counted up to the end date.',
            ),
            const SizedBox(height: AppSpacing.xl),

            // -------------------------------------------------------- target
            const SectionHeader('Attendance target'),
            SurfaceCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: <Widget>[
                  Row(
                    children: <Widget>[
                      const Expanded(
                        child: Text(
                          'Minimum required',
                          style: TextStyle(
                            fontSize: 14.5,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                      Text(
                        '${settings.targetPercent.round()}%',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.w800,
                          color: context.palette.accent,
                          letterSpacing: -0.5,
                        ),
                      ),
                    ],
                  ),
                  Slider(
                    value: settings.targetPercent.clamp(40, 100),
                    min: 40,
                    max: 100,
                    divisions: 60,
                    label: '${settings.targetPercent.round()}%',
                    onChanged: (double value) => controller.setTarget(value),
                  ),
                  const _Hint(
                    'Individual subjects can override this — open Subjects '
                    'below and edit one.',
                  ),
                ],
              ),
            ),
            const SizedBox(height: AppSpacing.xl),

            // ------------------------------------------------------ subjects
            const SectionHeader('Subjects'),
            SurfaceCard(
              padding: EdgeInsets.zero,
              child: _Row(
                icon: Icons.menu_book_outlined,
                title: 'Manage subjects',
                value: subjects.isEmpty
                    ? 'None yet — add your first'
                    : '${subjects.length} '
                        '${subjects.length == 1 ? 'subject' : 'subjects'} · '
                        '$classCount ${classCount == 1 ? 'class' : 'classes'}',
                onTap: () => Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (BuildContext context) => const SubjectsScreen(),
                  ),
                ),
              ),
            ),
            const SizedBox(height: AppSpacing.sm),
            const _Hint(
              'Add courses, change their colour or attendance target, and '
              'delete ones you have dropped.',
            ),
            const SizedBox(height: AppSpacing.xl),

            // ------------------------------------------- timetable layout
            const DayGridSection(),
            const SizedBox(height: AppSpacing.xl),
            const RoomsSection(),
            const SizedBox(height: AppSpacing.xl),

            // ------------------------------------------------ class lengths
            SectionHeader(
              'Class categories',
              trailing: TextButton.icon(
                onPressed: () => showCategoryEditor(context, ref),
                icon: const Icon(Icons.add_rounded, size: 18),
                label: const Text('Add'),
              ),
            ),
            if (categories.isEmpty)
              const SurfaceCard(
                child: _Hint(
                  'No categories yet. Create one — Lab, Theory, Tutorial — and '
                  'give it a default length, then put your subjects in it.',
                ),
              )
            else
              SurfaceCard(
                padding: EdgeInsets.zero,
                child: Column(
                  children: <Widget>[
                    for (int i = 0; i < categories.length; i++) ...<Widget>[
                      if (i > 0) const Divider(indent: AppSpacing.lg),
                      _Row(
                        icon: Icons.category_outlined,
                        title: categories[i].name,
                        value: 'Classes default to '
                            '${categories[i].durationLabel}',
                        onTap: () => showCategoryEditor(
                          context,
                          ref,
                          category: categories[i],
                        ),
                        trailing: IconButton(
                          onPressed: () =>
                              _deleteCategory(context, ref, categories[i]),
                          icon: const Icon(Icons.close_rounded, size: 18),
                          color: context.palette.textTertiary,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            const SizedBox(height: AppSpacing.md),
            SurfaceCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: <Widget>[
                  Row(
                    children: <Widget>[
                      const Expanded(
                        child: Text(
                          'Default class length',
                          style: TextStyle(
                            fontSize: 14.5,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                      Text(
                        Clock.formatDuration(
                          settings.defaultClassDurationMinutes,
                        ),
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w800,
                          color: context.palette.accent,
                          letterSpacing: -0.4,
                        ),
                      ),
                    ],
                  ),
                  Slider(
                    value: settings.defaultClassDurationMinutes
                        .toDouble()
                        .clamp(15, 300),
                    min: 15,
                    max: 300,
                    divisions: 57,
                    label: Clock.formatDuration(
                      settings.defaultClassDurationMinutes,
                    ),
                    onChanged: (double value) => controller.save(
                      settings.copyWith(
                        defaultClassDurationMinutes: (value / 5).round() * 5,
                      ),
                    ),
                  ),
                  const _Hint(
                    'Used for subjects that are not in a category. Setting a '
                    'class start time fills the end time in from this.',
                  ),
                ],
              ),
            ),
            const SizedBox(height: AppSpacing.xl),

            // ------------------------------------------------- notifications
            // --------------------------------------------------- appearance
            const SectionHeader('Appearance'),
            SurfaceCard(
              child: Row(
                children: <Widget>[
                  for (final AppThemeMode mode in AppThemeMode.values)
                    Expanded(
                      child: Padding(
                        padding: EdgeInsets.only(
                          right: mode == AppThemeMode.dark ? 0 : AppSpacing.sm,
                        ),
                        child: _ThemeOption(
                          mode: mode,
                          selected: settings.themeMode == mode,
                          onTap: () => controller
                              .save(settings.copyWith(themeMode: mode)),
                        ),
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(height: AppSpacing.sm),
            _Hint(
              settings.themeMode == AppThemeMode.system
                  ? 'Follows your device setting, switching automatically when '
                      'it does.'
                  : 'Always ${settings.themeMode.label.toLowerCase()}, whatever '
                      'your device is set to.',
            ),
            const SizedBox(height: AppSpacing.xl),

            const SectionHeader('Notifications'),
            SurfaceCard(
              padding: EdgeInsets.zero,
              child: Column(
                children: <Widget>[
                  _SwitchRow(
                    icon: settings.notificationsEnabled
                        ? Icons.notifications_outlined
                        : Icons.notifications_off_outlined,
                    title: 'All notifications',
                    subtitle: settings.notificationsEnabled
                        ? 'Individual types can be turned off below'
                        : 'Nothing is sent to your notification tray',
                    value: settings.notificationsEnabled,
                    onChanged: (bool v) async {
                      if (v) await NotificationService.instance.requestPermissions();
                      await controller
                          .save(settings.copyWith(notificationsEnabled: v));
                      await ref.read(actionsProvider).reloadAfterImport();
                    },
                  ),
                  const Divider(indent: AppSpacing.lg),
                  _SwitchRow(
                    icon: Icons.chat_bubble_outline,
                    title: 'Show alerts in the app',
                    subtitle: settings.showDangerInApp
                        ? 'Attendance warnings appear here instead'
                        : 'Used when attendance alerts are switched off',
                    value: settings.inAppAlerts,
                    onChanged: (bool v) async {
                      await controller.save(settings.copyWith(inAppAlerts: v));
                    },
                  ),
                ],
              ),
            ),
            const SizedBox(height: AppSpacing.md),
            Opacity(
              // The per-type rows stay readable but inert while the master
              // switch is off, so it is obvious why they do nothing.
              opacity: settings.notificationsEnabled ? 1 : 0.4,
              child: IgnorePointer(
                ignoring: !settings.notificationsEnabled,
                child: SurfaceCard(
              padding: EdgeInsets.zero,
              child: Column(
                children: <Widget>[
                  _SwitchRow(
                    icon: Icons.notifications_active_outlined,
                    title: 'Before each class',
                    subtitle:
                        '${settings.notifyLeadMinutes} minutes before it starts',
                    value: settings.notifyBeforeClass,
                    onChanged: (bool v) async {
                      if (v) await NotificationService.instance.requestPermissions();
                      await controller
                          .save(settings.copyWith(notifyBeforeClass: v));
                      await ref.read(actionsProvider).reloadAfterImport();
                    },
                    onTapSubtitle: settings.notifyBeforeClass
                        ? () => _pickLeadTime(context, controller, settings, ref)
                        : null,
                  ),
                  const Divider(indent: AppSpacing.lg),
                  _SwitchRow(
                    icon: Icons.edit_calendar_outlined,
                    title: 'Evening reminder',
                    subtitle:
                        'Mark unmarked classes at ${Clock.format(settings.eveningReminderMinutes, use24Hour: settings.use24HourTime)}',
                    value: settings.notifyEveningReminder,
                    onChanged: (bool v) async {
                      if (v) await NotificationService.instance.requestPermissions();
                      await controller
                          .save(settings.copyWith(notifyEveningReminder: v));
                      await ref.read(actionsProvider).reloadAfterImport();
                    },
                    onTapSubtitle: settings.notifyEveningReminder
                        ? () =>
                            _pickEveningTime(context, controller, settings, ref)
                        : null,
                  ),
                  const Divider(indent: AppSpacing.lg),
                  _SwitchRow(
                    icon: Icons.warning_amber_rounded,
                    title: 'Attendance alerts',
                    subtitle: settings.showDangerInApp
                        ? 'Off — shown in the app instead'
                        : 'Warn me when a subject nears the limit',
                    value: settings.notifyAttendanceDanger,
                    onChanged: (bool v) async {
                      if (v) await NotificationService.instance.requestPermissions();
                      await controller
                          .save(settings.copyWith(notifyAttendanceDanger: v));
                      await ref.read(actionsProvider).reloadAfterImport();
                    },
                  ),
                ],
              ),
                ),
              ),
            ),
            const SizedBox(height: AppSpacing.xl),

            // ------------------------------------------------------ holidays
            SectionHeader(
              'Holidays',
              trailing: TextButton.icon(
                onPressed: () => _addHoliday(context, ref),
                icon: const Icon(Icons.add_rounded, size: 18),
                label: const Text('Add'),
              ),
            ),
            if (holidays.isEmpty)
              const SurfaceCard(
                child: _Hint(
                  'No holidays yet. Add days when classes do not run — they '
                  'are skipped everywhere and never count against you.',
                ),
              )
            else
              SurfaceCard(
                padding: EdgeInsets.zero,
                child: Column(
                  children: <Widget>[
                    for (int i = 0; i < holidays.length; i++) ...<Widget>[
                      if (i > 0) const Divider(indent: AppSpacing.lg),
                      _Row(
                        icon: Icons.celebration_outlined,
                        title: holidays[i].name,
                        value: Dates.formatFull(holidays[i].date),
                        trailing: IconButton(
                          onPressed: () async {
                            final int? id = holidays[i].id;
                            if (id != null) {
                              await ref.read(actionsProvider).deleteHoliday(id);
                            }
                          },
                          icon: const Icon(Icons.close_rounded, size: 18),
                          color: context.palette.textTertiary,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            const SizedBox(height: AppSpacing.xl),

            // ---------------------------------------------------- appearance
            const SectionHeader('Display'),
            SurfaceCard(
              padding: EdgeInsets.zero,
              child: _SwitchRow(
                icon: Icons.schedule_rounded,
                title: '24-hour time',
                subtitle: settings.use24HourTime ? '14:30' : '2:30 pm',
                value: settings.use24HourTime,
                onChanged: (bool v) =>
                    controller.save(settings.copyWith(use24HourTime: v)),
              ),
            ),
            const SizedBox(height: AppSpacing.xl),

            // ---------------------------------------------------------- data
            const SectionHeader('Your data'),
            SurfaceCard(
              padding: EdgeInsets.zero,
              child: Column(
                children: <Widget>[
                  _Row(
                    icon: Icons.ios_share_rounded,
                    title: 'Export backup',
                    value: 'Save a JSON copy',
                    onTap: () => _export(context, ref),
                  ),
                  const Divider(indent: AppSpacing.lg),
                  _Row(
                    icon: Icons.download_rounded,
                    title: 'Import backup',
                    value: 'Paste a previous export',
                    onTap: () => _import(context, ref),
                  ),
                  const Divider(indent: AppSpacing.lg),
                  _Row(
                    icon: Icons.delete_forever_outlined,
                    title: 'Reset everything',
                    value: 'Delete all subjects and history',
                    danger: true,
                    onTap: () => _reset(context, ref),
                  ),
                ],
              ),
            ),
            const SizedBox(height: AppSpacing.xl),

            Center(
              child: Text(
                'Zeolite · 1.0.0\nAll your data stays on this device.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 12,
                  height: 1.5,
                  color: context.palette.textTertiary,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ------------------------------------------------------------- semester

  Future<void> _pickSemesterDate(
    BuildContext context,
    SettingsController controller,
    AppSettings settings, {
    required bool isStart,
  }) async {
    final DateTime initial = isStart
        ? (settings.semesterStart ?? Dates.today())
        : (settings.semesterEnd ?? Dates.addDays(Dates.today(), 120));
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: DateTime(DateTime.now().year - 2),
      lastDate: DateTime(DateTime.now().year + 4),
    );
    if (picked == null) return;

    final DateTime day = Dates.dayOf(picked);
    if (isStart) {
      final DateTime end = settings.semesterEnd ?? Dates.addDays(day, 120);
      await controller.setSemester(
        day,
        Dates.keyOf(end) < Dates.keyOf(day) ? Dates.addDays(day, 120) : end,
      );
    } else {
      final DateTime start = settings.semesterStart ?? Dates.today();
      await controller.setSemester(
        Dates.keyOf(start) > Dates.keyOf(day) ? Dates.addDays(day, -120) : start,
        day,
      );
    }
  }

  // -------------------------------------------------------- notifications

  Future<void> _pickLeadTime(
    BuildContext context,
    SettingsController controller,
    AppSettings settings,
    WidgetRef ref,
  ) async {
    const List<int> options = <int>[5, 10, 15, 20, 30, 45, 60];
    final int? picked = await showAppSheet<int>(
      context: context,
      title: 'Remind me before class',
      child: Column(
        children: <Widget>[
          for (final int minutes in options)
            ListTile(
              contentPadding: EdgeInsets.zero,
              title: Text('$minutes minutes before'),
              trailing: settings.notifyLeadMinutes == minutes
                  ? Icon(Icons.check_rounded, color: context.palette.accent)
                  : null,
              onTap: () => Navigator.of(context).pop(minutes),
            ),
        ],
      ),
    );
    if (picked == null) return;
    await controller.save(settings.copyWith(notifyLeadMinutes: picked));
    await ref.read(actionsProvider).reloadAfterImport();
  }

  Future<void> _pickEveningTime(
    BuildContext context,
    SettingsController controller,
    AppSettings settings,
    WidgetRef ref,
  ) async {
    final TimeOfDay? picked = await showTimePicker(
      context: context,
      initialTime: TimeOfDay(
        hour: Clock.hourOf(settings.eveningReminderMinutes),
        minute: Clock.minuteOf(settings.eveningReminderMinutes),
      ),
    );
    if (picked == null) return;
    await controller.save(
      settings.copyWith(
        eveningReminderMinutes: Clock.toMinutes(picked.hour, picked.minute),
      ),
    );
    await ref.read(actionsProvider).reloadAfterImport();
  }

  // ----------------------------------------------------------- categories

  Future<void> _deleteCategory(
    BuildContext context,
    WidgetRef ref,
    ClassCategory category,
  ) async {
    final int? id = category.id;
    if (id == null) return;

    final int inUse =
        await ref.read(actionsProvider).countSubjectsInCategory(id);
    if (!context.mounted) return;

    final bool? confirmed = await showDialog<bool>(
      context: context,
      builder: (BuildContext context) => AlertDialog(
        backgroundColor: context.palette.surfaceHigh,
        title: Text('Delete ${category.name}?'),
        content: Text(
          inUse == 0
              ? 'No subjects use this category.'
              : '$inUse ${inUse == 1 ? 'subject uses' : 'subjects use'} this '
                  'category. They keep all their classes and attendance — they '
                  'just fall back to the default class length.',
          style: const TextStyle(height: 1.4),
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
    await ref.read(actionsProvider).deleteCategory(id);
  }

  // ------------------------------------------------------------- holidays

  Future<void> _addHoliday(BuildContext context, WidgetRef ref) async {
    final DateTime? date = await showDatePicker(
      context: context,
      initialDate: Dates.today(),
      firstDate: DateTime(DateTime.now().year - 1),
      lastDate: DateTime(DateTime.now().year + 3),
      helpText: 'Pick the holiday date',
    );
    if (date == null || !context.mounted) return;

    final String? label = await showAppSheet<String>(
      context: context,
      title: 'Name this holiday',
      child: SheetTextForm(
        submitLabel: 'Add holiday',
        hintText: 'e.g. Diwali, Founder\'s Day',
        textCapitalization: TextCapitalization.words,
        emptyFallback: 'Holiday',
        header: Text(
          Dates.formatFull(date),
          style: TextStyle(
            fontSize: 13,
            color: context.palette.textSecondary,
          ),
        ),
      ),
    );
    if (label == null) return;

    await ref
        .read(actionsProvider)
        .addHoliday(Holiday(date: date, name: label));
  }

  // ----------------------------------------------------------------- data

  Future<void> _export(BuildContext context, WidgetRef ref) async {
    final BackupService backup = ref.read(backupServiceProvider);
    try {
      final String json = await backup.exportToJsonString();
      final File file = await backup.exportToFile();
      await Clipboard.setData(ClipboardData(text: json));
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Copied to clipboard and saved as ${file.path.split('/').last}',
          ),
          duration: const Duration(seconds: 5),
        ),
      );
    } catch (error) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('Export failed: $error')));
    }
  }

  Future<void> _import(BuildContext context, WidgetRef ref) async {
    final String? json = await showAppSheet<String>(
      context: context,
      title: 'Import backup',
      child: const SheetTextForm(
        submitLabel: 'Restore',
        hintText: '{ "app": "Zeolite", …',
        maxLines: 6,
        textCapitalization: TextCapitalization.none,
        header: _Hint(
          'Paste the contents of a Zeolite export. This replaces everything '
          'currently in the app.',
        ),
      ),
    );
    if (json == null || json.trim().isEmpty) return;

    final ImportResult result =
        await ref.read(backupServiceProvider).importFromJsonString(json);
    if (result.success) {
      await ref.read(actionsProvider).reloadAfterImport();
    }
    if (!context.mounted) return;
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(result.message)));
  }

  Future<void> _reset(BuildContext context, WidgetRef ref) async {
    final bool? confirmed = await showDialog<bool>(
      context: context,
      builder: (BuildContext context) => AlertDialog(
        backgroundColor: context.palette.surfaceHigh,
        title: const Text('Delete everything?'),
        content: const Text(
          'Every subject, class and attendance mark will be removed. '
          'Export a backup first if you might want this data back.',
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
            child: const Text('Delete all'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    await ref.read(actionsProvider).resetEverything();
    if (!context.mounted) return;
    ScaffoldMessenger.of(context)
        .showSnackBar(const SnackBar(content: Text('All data deleted')));
  }
}

// ------------------------------------------------------------ small pieces

class _Row extends StatelessWidget {
  const _Row({
    required this.icon,
    required this.title,
    required this.value,
    this.onTap,
    this.trailing,
    this.danger = false,
  });

  final IconData icon;
  final String title;
  final String value;
  final VoidCallback? onTap;
  final Widget? trailing;
  final bool danger;

  @override
  Widget build(BuildContext context) {
    final Color color = danger ? context.palette.absent : context.palette.textPrimary;
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.lg,
          vertical: AppSpacing.md,
        ),
        child: Row(
          children: <Widget>[
            Icon(icon, size: 20, color: danger ? color : context.palette.textSecondary),
            const SizedBox(width: AppSpacing.lg),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(
                    title,
                    style: TextStyle(
                      fontSize: 14.5,
                      fontWeight: FontWeight.w600,
                      color: color,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    value,
                    style: TextStyle(
                      fontSize: 12.5,
                      color: context.palette.textTertiary,
                    ),
                  ),
                ],
              ),
            ),
            if (trailing != null)
              trailing!
            else if (onTap != null)
              Icon(
                Icons.chevron_right_rounded,
                size: 20,
                color: context.palette.textTertiary,
              ),
          ],
        ),
      ),
    );
  }
}

/// One of the three theme choices, shown as a tappable tile.
class _ThemeOption extends StatelessWidget {
  const _ThemeOption({
    required this.mode,
    required this.selected,
    required this.onTap,
  });

  final AppThemeMode mode;
  final bool selected;
  final VoidCallback onTap;

  IconData get _icon => switch (mode) {
        AppThemeMode.system => Icons.brightness_auto_rounded,
        AppThemeMode.light => Icons.light_mode_rounded,
        AppThemeMode.dark => Icons.dark_mode_rounded,
      };

  @override
  Widget build(BuildContext context) {
    final AppPalette p = context.palette;
    return Material(
      color: selected ? p.accentSoft : p.surfaceHigh,
      borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: AppSpacing.lg),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
            border: Border.all(
              color: selected ? p.accent : p.outline,
              width: selected ? 1.6 : 1,
            ),
          ),
          child: Column(
            children: <Widget>[
              Icon(
                _icon,
                size: 22,
                color: selected ? p.accent : p.textSecondary,
              ),
              const SizedBox(height: AppSpacing.sm),
              Text(
                // "Match system" is too wide for a third of the row.
                mode == AppThemeMode.system ? 'System' : mode.label,
                style: TextStyle(
                  fontSize: 12.5,
                  fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                  color: selected ? p.accent : p.textSecondary,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SwitchRow extends StatelessWidget {
  const _SwitchRow({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.value,
    required this.onChanged,
    this.onTapSubtitle,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final bool value;
  final ValueChanged<bool> onChanged;
  final VoidCallback? onTapSubtitle;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.lg,
        vertical: AppSpacing.sm,
      ),
      child: Row(
        children: <Widget>[
          Icon(icon, size: 20, color: context.palette.textSecondary),
          const SizedBox(width: AppSpacing.lg),
          Expanded(
            child: InkWell(
              onTap: onTapSubtitle,
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      title,
                      style: const TextStyle(
                        fontSize: 14.5,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Row(
                      children: <Widget>[
                        Flexible(
                          child: Text(
                            subtitle,
                            maxLines: 2,
                            style: TextStyle(
                              fontSize: 12.5,
                              color: onTapSubtitle != null
                                  ? context.palette.accent
                                  : context.palette.textTertiary,
                            ),
                          ),
                        ),
                        if (onTapSubtitle != null)
                          Icon(
                            Icons.edit_rounded,
                            size: 12,
                            color: context.palette.accent,
                          ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
          Switch.adaptive(value: value, onChanged: onChanged),
        ],
      ),
    );
  }
}

class _Hint extends StatelessWidget {
  const _Hint(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: TextStyle(
        fontSize: 12.5,
        height: 1.45,
        color: context.palette.textTertiary,
      ),
    );
  }
}
