import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../core/app_theme.dart';
import '../domain/attendance_stats.dart';

/// The colour a subject's attendance is drawn in, shared by every screen that
/// shows a percentage so they never disagree.
/// The same colour softened for large filled areas such as the meter bar.
///
/// Text and icons keep the full-strength [healthColor] because they need the
/// contrast; a full-width slab of it reads as an alarm rather than as
/// information. Blending toward the track keeps the bar in the same family
/// instead of just making it translucent over whatever is behind it.
Color healthFill(AttendanceHealth health, AppPalette palette) {
  final Color base = healthColor(health, palette);
  return Color.alphaBlend(
    base.withValues(alpha: palette.isDark ? 0.78 : 0.62),
    palette.surfaceHigher,
  );
}

Color healthColor(AttendanceHealth health, AppPalette palette) {
  switch (health) {
    case AttendanceHealth.safe:
      return palette.present;
    case AttendanceHealth.tight:
      return palette.warning;
    case AttendanceHealth.atRisk:
    case AttendanceHealth.lost:
      return palette.absent;
    case AttendanceHealth.empty:
      return palette.textTertiary;
  }
}

/// A bordered, rounded panel — the base surface used across every screen.
class SurfaceCard extends StatelessWidget {
  const SurfaceCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(AppSpacing.lg),
    this.color,
    this.borderColor,
    this.radius = AppSpacing.radiusLg,
    this.onTap,
    this.onLongPress,
  });

  final Widget child;
  final EdgeInsetsGeometry padding;
  final Color? color;
  final Color? borderColor;
  final double radius;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;

  @override
  Widget build(BuildContext context) {
    final BorderRadius shape = BorderRadius.circular(radius);
    return Material(
      color: color ?? context.palette.surface,
      borderRadius: shape,
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        onLongPress: onLongPress,
        child: Container(
          decoration: BoxDecoration(
            borderRadius: shape,
            border: Border.all(color: borderColor ?? context.palette.outlineSoft),
          ),
          padding: padding,
          child: child,
        ),
      ),
    );
  }
}

/// Small uppercase heading used above list groups.
class SectionHeader extends StatelessWidget {
  const SectionHeader(this.title, {super.key, this.trailing});

  final String title;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(
        left: AppSpacing.xs,
        right: AppSpacing.xs,
        bottom: AppSpacing.md,
      ),
      child: Row(
        children: <Widget>[
          Expanded(
            child: Text(
              title.toUpperCase(),
              style: TextStyle(
                color: context.palette.textTertiary,
                fontSize: 11.5,
                fontWeight: FontWeight.w700,
                letterSpacing: 1.1,
              ),
            ),
          ),
          if (trailing != null) trailing!,
        ],
      ),
    );
  }
}

/// Friendly placeholder for screens with nothing to show yet.
class EmptyState extends StatelessWidget {
  const EmptyState({
    super.key,
    required this.icon,
    required this.title,
    required this.message,
    this.action,
  });

  final IconData icon;
  final String title;
  final String message;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Container(
              width: 76,
              height: 76,
              decoration: BoxDecoration(
                color: context.palette.surfaceHigh,
                borderRadius: BorderRadius.circular(AppSpacing.radiusLg),
                border: Border.all(color: context.palette.outlineSoft),
              ),
              child: Icon(icon, size: 32, color: context.palette.textTertiary),
            ),
            const SizedBox(height: AppSpacing.lg),
            Text(
              title,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.w700,
                color: context.palette.textPrimary,
              ),
            ),
            const SizedBox(height: AppSpacing.sm),
            Text(
              message,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 14,
                height: 1.4,
                color: context.palette.textSecondary,
              ),
            ),
            if (action != null) ...<Widget>[
              const SizedBox(height: AppSpacing.xl),
              action!,
            ],
          ],
        ),
      ),
    );
  }
}

/// Circular percentage indicator with the value in the middle.
class ProgressRing extends StatelessWidget {
  const ProgressRing({
    super.key,
    required this.value,
    required this.color,
    this.size = 92,
    this.strokeWidth = 9,
    this.targetValue,
    this.label,
    this.caption,
  });

  /// 0..1
  final double value;
  final Color color;
  final double size;
  final double strokeWidth;

  /// Draws a tick on the ring where the target sits.
  final double? targetValue;

  final String? label;
  final String? caption;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: CustomPaint(
        painter: _RingPainter(
          value: value.clamp(0.0, 1.0),
          color: color,
          strokeWidth: strokeWidth,
          targetValue: targetValue,
          // A painter has no BuildContext, so the palette is handed in and
          // compared in shouldRepaint to catch a theme change.
          palette: context.palette,
        ),
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              Text(
                label ?? '${(value * 100).round()}%',
                style: TextStyle(
                  fontSize: size * 0.25,
                  fontWeight: FontWeight.w700,
                  letterSpacing: -0.8,
                  color: context.palette.textPrimary,
                ),
              ),
              if (caption != null)
                Text(
                  caption!,
                  style: TextStyle(
                    fontSize: size * 0.115,
                    fontWeight: FontWeight.w500,
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

class _RingPainter extends CustomPainter {
  _RingPainter({
    required this.value,
    required this.color,
    required this.strokeWidth,
    required this.palette,
    this.targetValue,
  });

  final double value;
  final Color color;
  final double strokeWidth;
  final AppPalette palette;
  final double? targetValue;

  @override
  void paint(Canvas canvas, Size size) {
    final Offset center = Offset(size.width / 2, size.height / 2);
    final double radius = (math.min(size.width, size.height) - strokeWidth) / 2;
    final Rect rect = Rect.fromCircle(center: center, radius: radius);
    const double start = -math.pi / 2;

    final Paint track = Paint()
      ..color = palette.surfaceHigher
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round;
    canvas.drawCircle(center, radius, track);

    if (value > 0) {
      final Paint arc = Paint()
        ..color = color
        ..style = PaintingStyle.stroke
        ..strokeWidth = strokeWidth
        ..strokeCap = StrokeCap.round;
      canvas.drawArc(rect, start, 2 * math.pi * value, false, arc);
    }

    // A small notch marking where the required percentage sits.
    final double? target = targetValue;
    if (target != null && target > 0 && target < 1) {
      final double angle = start + 2 * math.pi * target;
      final Paint tick = Paint()
        ..color = palette.textPrimary
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2
        ..strokeCap = StrokeCap.round;
      final double inner = radius - strokeWidth / 2 - 1;
      final double outer = radius + strokeWidth / 2 + 1;
      canvas.drawLine(
        center + Offset(math.cos(angle) * inner, math.sin(angle) * inner),
        center + Offset(math.cos(angle) * outer, math.sin(angle) * outer),
        tick,
      );
    }
  }

  @override
  bool shouldRepaint(_RingPainter old) =>
      old.value != value ||
      old.color != color ||
      old.strokeWidth != strokeWidth ||
      old.targetValue != targetValue ||
      // Without this the ring keeps its old track colour when the theme is
      // switched, since nothing else about the painter changes.
      old.palette.surfaceHigher != palette.surfaceHigher ||
      old.palette.textPrimary != palette.textPrimary;
}

/// Thin horizontal meter with an optional target marker.
class TargetBar extends StatelessWidget {
  const TargetBar({
    super.key,
    required this.value,
    required this.color,
    this.target,
    this.height = 8,
  });

  final double value;
  final Color color;
  final double? target;
  final double height;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (BuildContext context, BoxConstraints constraints) {
        final double width = constraints.maxWidth;
        final double clamped = value.clamp(0.0, 1.0);
        return SizedBox(
          height: height + 6,
          child: Stack(
            alignment: Alignment.centerLeft,
            children: <Widget>[
              Container(
                height: height,
                decoration: BoxDecoration(
                  color: context.palette.surfaceHigher,
                  borderRadius: BorderRadius.circular(height),
                ),
              ),
              AnimatedContainer(
                duration: const Duration(milliseconds: 450),
                curve: Curves.easeOutCubic,
                height: height,
                width: width * clamped,
                decoration: BoxDecoration(
                  color: color,
                  borderRadius: BorderRadius.circular(height),
                ),
              ),
              if (target != null && target! > 0 && target! < 1)
                Positioned(
                  left: (width * target!).clamp(0.0, width - 2),
                  child: Container(
                    width: 2,
                    height: height + 6,
                    decoration: BoxDecoration(
                      color: context.palette.textSecondary,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
            ],
          ),
        );
      },
    );
  }
}

/// Coloured monogram avatar for a subject.
class SubjectAvatar extends StatelessWidget {
  const SubjectAvatar({
    super.key,
    required this.initials,
    required this.color,
    this.size = 44,
  });

  final String initials;
  final Color color;
  final double size;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.16),
        borderRadius: BorderRadius.circular(size * 0.32),
        border: Border.all(color: color.withValues(alpha: 0.35)),
      ),
      child: Text(
        initials,
        style: TextStyle(
          color: color,
          fontSize: size * 0.34,
          fontWeight: FontWeight.w700,
          letterSpacing: -0.3,
        ),
      ),
    );
  }
}

/// Compact pill used for statuses, rooms and counts.
class Pill extends StatelessWidget {
  const Pill({
    super.key,
    required this.label,
    this.icon,
    this.color,
    this.background,
  });

  final String label;
  final IconData? icon;
  final Color? color;
  final Color? background;

  @override
  Widget build(BuildContext context) {
    final Color fg = color ?? context.palette.textSecondary;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
      decoration: BoxDecoration(
        color: background ?? fg.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(AppSpacing.radiusSm),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          if (icon != null) ...<Widget>[
            Icon(icon, size: 12, color: fg),
            const SizedBox(width: 4),
          ],
          Text(
            label,
            style: TextStyle(
              color: fg,
              fontSize: 11.5,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

/// Sheet body for "type one thing and confirm": a text field and a submit button
/// that pops the sheet with what was typed.
///
/// It exists so the controller has an owner. Creating one at the call site and
/// disposing it after `showAppSheet` returns crashes the app: the route is popped
/// but its dismiss animation still has the field mounted, so the controller dies
/// while a live widget listens to it. A State disposes on unmount, which is after
/// the animation, so the ordering is right by construction rather than by every
/// call site remembering.
class SheetTextForm extends StatefulWidget {
  const SheetTextForm({
    super.key,
    required this.submitLabel,
    this.initial = '',
    this.header,
    this.labelText,
    this.hintText,
    this.maxLines = 1,
    this.textCapitalization = TextCapitalization.sentences,
    this.emptyFallback,
  });

  final String submitLabel;
  final String initial;

  /// Optional content above the field — a date, an explanation.
  final Widget? header;

  final String? labelText;
  final String? hintText;
  final int maxLines;
  final TextCapitalization textCapitalization;

  /// Popped when the field is left empty. Without one, submitting an empty
  /// field does nothing rather than saving a blank name.
  final String? emptyFallback;

  @override
  State<SheetTextForm> createState() => _SheetTextFormState();
}

class _SheetTextFormState extends State<SheetTextForm> {
  late final TextEditingController _input =
      TextEditingController(text: widget.initial);

  @override
  void dispose() {
    _input.dispose();
    super.dispose();
  }

  void _submit() {
    final String value = _input.text.trim();
    if (value.isEmpty) {
      if (widget.emptyFallback == null) return;
      Navigator.of(context).pop(widget.emptyFallback);
      return;
    }
    Navigator.of(context).pop(value);
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        if (widget.header != null) ...<Widget>[
          widget.header!,
          const SizedBox(height: AppSpacing.md),
        ],
        TextField(
          controller: _input,
          autofocus: true,
          maxLines: widget.maxLines,
          textCapitalization: widget.textCapitalization,
          decoration: InputDecoration(
            labelText: widget.labelText,
            hintText: widget.hintText,
          ),
          // Only a single-line field gets a usable submit action; a multi-line
          // one needs the return key for newlines.
          onSubmitted: widget.maxLines == 1 ? (_) => _submit() : null,
        ),
        const SizedBox(height: AppSpacing.xl),
        FilledButton(onPressed: _submit, child: Text(widget.submitLabel)),
      ],
    );
  }
}

/// Standard bottom-sheet wrapper: drag handle, title, scrollable body.
Future<T?> showAppSheet<T>({
  required BuildContext context,
  required String title,
  required Widget child,
}) {
  return showModalBottomSheet<T>(
    context: context,
    isScrollControlled: true,
    backgroundColor: context.palette.surface,
    builder: (BuildContext context) {
      return SafeArea(
        top: false,
        child: Padding(
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(context).viewInsets.bottom,
          ),
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.xl,
              AppSpacing.sm,
              AppSpacing.xl,
              AppSpacing.xl,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w700,
                    letterSpacing: -0.4,
                  ),
                ),
                const SizedBox(height: AppSpacing.xl),
                child,
              ],
            ),
          ),
        ),
      );
    },
  );
}
