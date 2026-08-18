import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/app_theme.dart';
import '../../core/date_utils.dart';
import '../../data/settings/app_settings.dart';
import '../../services/notification_service.dart';
import '../../state/providers.dart';
import '../../widgets/common.dart';

/// First-run setup: semester dates and the attendance requirement.
///
/// Kept to a single screen deliberately — the app is useful the moment these
/// two things are known, and everything else can be changed later in Settings.
class OnboardingScreen extends ConsumerStatefulWidget {
  const OnboardingScreen({super.key});

  @override
  ConsumerState<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends ConsumerState<OnboardingScreen> {
  late DateTime _start;
  late DateTime _end;
  double _target = 75;
  bool _notifications = true;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    final DateTime today = Dates.today();
    _start = today;
    // A typical term is about four months.
    _end = Dates.addDays(today, 120);
  }

  Future<void> _pick({required bool isStart}) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: isStart ? _start : _end,
      firstDate: DateTime(DateTime.now().year - 1),
      lastDate: DateTime(DateTime.now().year + 4),
    );
    if (picked == null || !mounted) return;
    setState(() {
      if (isStart) {
        _start = Dates.dayOf(picked);
        if (Dates.keyOf(_end) <= Dates.keyOf(_start)) {
          _end = Dates.addDays(_start, 120);
        }
      } else {
        _end = Dates.dayOf(picked);
        if (Dates.keyOf(_end) <= Dates.keyOf(_start)) {
          _start = Dates.addDays(_end, -120);
        }
      }
    });
  }

  Future<void> _finish() async {
    setState(() => _saving = true);

    if (_notifications) {
      await NotificationService.instance.requestPermissions();
    }

    await ref.read(settingsProvider.notifier).save(
          AppSettings(
            semesterStart: _start,
            semesterEnd: _end,
            targetPercent: _target,
            notifyBeforeClass: _notifications,
            notifyEveningReminder: _notifications,
            notifyAttendanceDanger: _notifications,
            onboarded: true,
          ),
        );
  }

  @override
  Widget build(BuildContext context) {
    final int weeks = (Dates.daysBetween(_start, _end) / 7).round();

    return Scaffold(
      body: SafeArea(
        child: Column(
          children: <Widget>[
            Expanded(
              child: ListView(
                padding: const EdgeInsets.all(AppSpacing.xl),
                children: <Widget>[
                  const SizedBox(height: AppSpacing.xl),
                  Container(
                    width: 64,
                    height: 64,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: context.palette.accent.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(AppSpacing.radiusLg),
                      border: Border.all(
                        color: context.palette.accent.withValues(alpha: 0.4),
                      ),
                    ),
                    child: Icon(
                      Icons.school_rounded,
                      color: context.palette.accent,
                      size: 30,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.xl),
                  const Text(
                    'Zeolite',
                    style: TextStyle(
                      fontSize: 34,
                      fontWeight: FontWeight.w800,
                      letterSpacing: -1.4,
                      height: 1.1,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  Text(
                    'Your timetable and attendance, in one place. '
                    'Two quick answers and you are set up.',
                    style: TextStyle(
                      fontSize: 15,
                      height: 1.45,
                      color: context.palette.textSecondary,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.xxl),

                  const SectionHeader('When is your semester?'),
                  SurfaceCard(
                    child: Column(
                      children: <Widget>[
                        _DateRow(
                          label: 'Starts',
                          value: Dates.formatFull(_start),
                          onTap: () => _pick(isStart: true),
                        ),
                        const SizedBox(height: AppSpacing.md),
                        const Divider(),
                        const SizedBox(height: AppSpacing.md),
                        _DateRow(
                          label: 'Ends',
                          value: Dates.formatFull(_end),
                          onTap: () => _pick(isStart: false),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  Text(
                    'About $weeks weeks. You can change this any time.',
                    style: TextStyle(
                      fontSize: 12.5,
                      color: context.palette.textTertiary,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.xxl),

                  const SectionHeader('Attendance you need'),
                  SurfaceCard(
                    child: Column(
                      children: <Widget>[
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          crossAxisAlignment: CrossAxisAlignment.baseline,
                          textBaseline: TextBaseline.alphabetic,
                          children: <Widget>[
                            Text(
                              '${_target.round()}',
                              style: TextStyle(
                                fontSize: 46,
                                fontWeight: FontWeight.w800,
                                letterSpacing: -2,
                                color: context.palette.accent,
                              ),
                            ),
                            Text(
                              '%',
                              style: TextStyle(
                                fontSize: 22,
                                fontWeight: FontWeight.w700,
                                color: context.palette.accent,
                              ),
                            ),
                          ],
                        ),
                        Slider(
                          value: _target,
                          min: 40,
                          max: 100,
                          divisions: 60,
                          label: '${_target.round()}%',
                          onChanged: (double v) => setState(() => _target = v),
                        ),
                        Text(
                          'Most universities require 75%.',
                          style: TextStyle(
                            fontSize: 12.5,
                            color: context.palette.textTertiary,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: AppSpacing.xl),

                  SurfaceCard(
                    child: Row(
                      children: <Widget>[
                        Icon(
                          Icons.notifications_active_outlined,
                          size: 20,
                          color: context.palette.textSecondary,
                        ),
                        const SizedBox(width: AppSpacing.md),
                        const Expanded(
                          child: Text(
                            'Remind me about classes and unmarked attendance',
                            style: TextStyle(
                              fontSize: 13.5,
                              height: 1.35,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                        Switch.adaptive(
                          value: _notifications,
                          onChanged: (bool v) =>
                              setState(() => _notifications = v),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.xl,
                AppSpacing.sm,
                AppSpacing.xl,
                AppSpacing.xl,
              ),
              child: FilledButton(
                onPressed: _saving ? null : _finish,
                child: _saving
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : const Text('Start tracking'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _DateRow extends StatelessWidget {
  const _DateRow({
    required this.label,
    required this.value,
    required this.onTap,
  });

  final String label;
  final String value;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Row(
        children: <Widget>[
          Text(
            label,
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: context.palette.textSecondary,
            ),
          ),
          const Spacer(),
          Text(
            value,
            style: const TextStyle(fontSize: 14.5, fontWeight: FontWeight.w700),
          ),
          const SizedBox(width: AppSpacing.sm),
          Icon(
            Icons.edit_calendar_outlined,
            size: 16,
            color: context.palette.accent,
          ),
        ],
      ),
    );
  }
}
