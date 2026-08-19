import 'package:flutter/material.dart';

import '../../core/app_theme.dart';
import '../../core/date_utils.dart';
import '../../data/models/attendance_status.dart';
import '../../data/models/class_session.dart';
import '../../widgets/common.dart';

/// One class on the Today screen, with the three one-tap attendance actions.
///
/// Tapping the status a class already has clears it, so a mis-tap is undone
/// with the same button rather than a menu.
class SessionCard extends StatelessWidget {
  const SessionCard({
    super.key,
    required this.session,
    required this.onMark,
    required this.use24Hour,
    this.onLongPress,
    this.showDate = false,
    this.categoryName,
    this.tagName,
    this.onTag,
  });

  final ClassSession session;
  final void Function(AttendanceStatus status) onMark;
  final bool use24Hour;
  final VoidCallback? onLongPress;
  final bool showDate;

  /// Category label (Lab, Theory, ...) shown as a pill, when the subject has one.
  final String? categoryName;

  /// The mark's tag, already resolved to a name. Passed in rather than looked
  /// up here for the same reason as [categoryName] — the card stays a plain
  /// widget with no data layer behind it.
  final String? tagName;

  /// Opens the tag picker. Null when there are no tags to choose from, which
  /// is how the control stays invisible until Settings has one.
  final VoidCallback? onTag;

  @override
  Widget build(BuildContext context) {
    final Color subjectColor = session.subject.color;
    final String? teacher = session.subject.teacher;
    final AttendanceStatus? status = session.status;
    final bool isCancelled = status == AttendanceStatus.cancelled;
    final bool dimmed = isCancelled;

    return SurfaceCard(
      padding: EdgeInsets.zero,
      borderColor: session.isOngoing
          ? subjectColor.withValues(alpha: 0.55)
          : (status != null
              ? status.colorIn(context.palette).withValues(alpha: 0.25)
              : context.palette.outlineSoft),
      onLongPress: onLongPress,
      child: Opacity(
        opacity: dimmed ? 0.55 : 1,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            IntrinsicHeight(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: <Widget>[
                  // Subject colour spine.
                  Container(width: 4, color: subjectColor),
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(
                        AppSpacing.lg,
                        AppSpacing.lg,
                        AppSpacing.lg,
                        AppSpacing.md,
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: <Widget>[
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: <Widget>[
                              Expanded(
                                child: Text(
                                  session.subject.name,
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    fontSize: 16.5,
                                    fontWeight: FontWeight.w700,
                                    letterSpacing: -0.3,
                                    color: context.palette.textPrimary,
                                    decoration: isCancelled
                                        ? TextDecoration.lineThrough
                                        : null,
                                    decorationColor: context.palette.textTertiary,
                                  ),
                                ),
                              ),
                              if (session.isOngoing)
                                Pill(
                                  label: 'Now',
                                  icon: Icons.play_arrow_rounded,
                                  color: subjectColor,
                                )
                              else if (status != null)
                                Pill(
                                  label: status.label,
                                  icon: status.icon,
                                  color: status.colorIn(context.palette),
                                ),
                            ],
                          ),
                          const SizedBox(height: AppSpacing.sm),
                          Wrap(
                            spacing: AppSpacing.md,
                            runSpacing: AppSpacing.xs,
                            crossAxisAlignment: WrapCrossAlignment.center,
                            children: <Widget>[
                              _MetaItem(
                                icon: Icons.schedule_rounded,
                                text: Clock.formatRange(
                                  session.startMinutes,
                                  session.endMinutes,
                                  use24Hour: use24Hour,
                                ),
                              ),
                              if (session.room != null &&
                                  session.room!.isNotEmpty)
                                _MetaItem(
                                  icon: Icons.place_outlined,
                                  text: session.room!,
                                ),
                              if (teacher != null && teacher.isNotEmpty)
                                _MetaItem(
                                  icon: Icons.person_outline_rounded,
                                  text: teacher,
                                ),
                              if (showDate)
                                _MetaItem(
                                  icon: Icons.event_outlined,
                                  text: Dates.relativeLabel(session.date),
                                ),
                              if (categoryName != null &&
                                  categoryName!.isNotEmpty)
                                Pill(
                                  label: categoryName!,
                                  icon: Icons.category_outlined,
                                  color: subjectColor,
                                ),
                              if (session.isExtra)
                                Pill(
                                  label: 'One-off',
                                  icon: Icons.looks_one_outlined,
                                  color: context.palette.cyan,
                                ),
                              if (tagName != null && tagName!.isNotEmpty)
                                Pill(
                                  label: '+$tagName',
                                  color: context.palette.cyan,
                                ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.md,
                0,
                AppSpacing.md,
                AppSpacing.md,
              ),
              child: Row(
                children: <Widget>[
                  for (final AttendanceStatus option
                      in AttendanceStatus.values) ...<Widget>[
                    Expanded(
                      child: _StatusButton(
                        status: option,
                        selected: status == option,
                        onTap: () => onMark(option),
                      ),
                    ),
                    if (option != AttendanceStatus.values.last)
                      const SizedBox(width: AppSpacing.sm),
                  ],
                  // Only once the class is marked: a tag labels a mark, so
                  // offering one on an unmarked class would have nothing to
                  // attach to. Marking itself stays a single tap.
                  if (onTag != null && session.isMarked) ...<Widget>[
                    const SizedBox(width: AppSpacing.sm),
                    _TagButton(active: tagName != null, onTap: onTag!),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _StatusButton extends StatelessWidget {
  const _StatusButton({
    required this.status,
    required this.selected,
    required this.onTap,
  });

  final AttendanceStatus status;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final Color color = status.colorIn(context.palette);
    return Material(
      color: selected ? color.withValues(alpha: 0.18) : context.palette.surfaceHigh,
      borderRadius: BorderRadius.circular(AppSpacing.radiusSm),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppSpacing.radiusSm),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 160),
          padding: const EdgeInsets.symmetric(vertical: 10),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(AppSpacing.radiusSm),
            border: Border.all(
              color: selected
                  ? color.withValues(alpha: 0.6)
                  : context.palette.outlineSoft,
            ),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: <Widget>[
              Icon(
                status.icon,
                size: 16,
                color: selected ? color : context.palette.textTertiary,
              ),
              const SizedBox(width: 6),
              Flexible(
                child: Text(
                  status.label,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                    color: selected ? color : context.palette.textSecondary,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _TagButton extends StatelessWidget {
  const _TagButton({required this.active, required this.onTap});

  /// Whether a tag is already set. Kept to an icon either way: the tag's name
  /// is already on the line above, and repeating it here would push the three
  /// status buttons into ellipsis on a narrow phone.
  final bool active;

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final Color accent = context.palette.cyan;
    return Material(
      color: active
          ? accent.withValues(alpha: 0.18)
          : context.palette.surfaceHigh,
      borderRadius: BorderRadius.circular(AppSpacing.radiusSm),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppSpacing.radiusSm),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 10),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(AppSpacing.radiusSm),
            border: Border.all(
              color: active
                  ? accent.withValues(alpha: 0.6)
                  : context.palette.outlineSoft,
            ),
          ),
          child: Icon(
            Icons.sell_outlined,
            size: 16,
            color: active ? accent : context.palette.textTertiary,
          ),
        ),
      ),
    );
  }
}

class _MetaItem extends StatelessWidget {
  const _MetaItem({required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        Icon(icon, size: 14, color: context.palette.textTertiary),
        const SizedBox(width: 5),
        Text(
          text,
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w500,
            color: context.palette.textSecondary,
          ),
        ),
      ],
    );
  }
}
