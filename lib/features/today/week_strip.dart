import 'package:flutter/material.dart';

import '../../core/app_theme.dart';
import '../../core/date_utils.dart';

/// Horizontally scrollable strip of days used to move around the calendar.
///
/// It renders a wide window either side of today and auto-scrolls the selected
/// day into view, so jumping weeks is a flick rather than a date picker.
class WeekStrip extends StatefulWidget {
  const WeekStrip({
    super.key,
    required this.selected,
    required this.onSelected,
    this.markers = const <int, DayMarker>{},
    this.pastDays = 60,
    this.futureDays = 120,
  });

  final DateTime selected;
  final ValueChanged<DateTime> onSelected;

  /// Per-day dot summary, keyed by [Dates.keyOf].
  final Map<int, DayMarker> markers;

  final int pastDays;
  final int futureDays;

  @override
  State<WeekStrip> createState() => _WeekStripState();
}

/// What to draw under a day: how many classes and whether any are unmarked.
class DayMarker {
  const DayMarker({
    required this.count,
    this.hasUnmarked = false,
    this.color,
  });

  final int count;
  final bool hasUnmarked;
  final Color? color;
}

class _WeekStripState extends State<WeekStrip> {
  static const double _itemWidth = 56;
  static const double _itemSpacing = AppSpacing.sm;

  late final ScrollController _controller;
  late final DateTime _first;

  @override
  void initState() {
    super.initState();
    _first = Dates.addDays(Dates.today(), -widget.pastDays);
    _controller = ScrollController(
      initialScrollOffset: _offsetFor(widget.selected),
    );
  }

  @override
  void didUpdateWidget(covariant WeekStrip oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!Dates.isSameDay(oldWidget.selected, widget.selected)) {
      _scrollTo(widget.selected);
    }
  }

  double _offsetFor(DateTime date) {
    final int index = Dates.daysBetween(_first, date);
    final double raw = index * (_itemWidth + _itemSpacing);
    // Nudge the selection towards the middle rather than the left edge.
    return (raw - 2 * (_itemWidth + _itemSpacing)).clamp(0.0, double.infinity);
  }

  void _scrollTo(DateTime date) {
    if (!_controller.hasClients) return;
    final double target = _offsetFor(date).clamp(
      0.0,
      _controller.position.maxScrollExtent,
    );
    _controller.animateTo(
      target,
      duration: const Duration(milliseconds: 320),
      curve: Curves.easeOutCubic,
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final int total = widget.pastDays + widget.futureDays + 1;
    final DateTime today = Dates.today();

    return SizedBox(
      height: 78,
      child: ListView.separated(
        controller: _controller,
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
        itemCount: total,
        separatorBuilder: (_, __) => const SizedBox(width: _itemSpacing),
        itemBuilder: (BuildContext context, int index) {
          final DateTime date = Dates.addDays(_first, index);
          final bool isSelected = Dates.isSameDay(date, widget.selected);
          final bool isToday = Dates.isSameDay(date, today);
          final DayMarker? marker = widget.markers[Dates.keyOf(date)];
          return _DayCell(
            date: date,
            selected: isSelected,
            isToday: isToday,
            marker: marker,
            width: _itemWidth,
            onTap: () => widget.onSelected(date),
          );
        },
      ),
    );
  }
}

class _DayCell extends StatelessWidget {
  const _DayCell({
    required this.date,
    required this.selected,
    required this.isToday,
    required this.width,
    required this.onTap,
    this.marker,
  });

  final DateTime date;
  final bool selected;
  final bool isToday;
  final double width;
  final VoidCallback onTap;
  final DayMarker? marker;

  @override
  Widget build(BuildContext context) {
    final Color background =
        selected ? context.palette.accent : context.palette.surface;
    final Color primaryText =
        selected ? Colors.white : context.palette.textPrimary;
    final Color secondaryText = selected
        ? Colors.white.withValues(alpha: 0.8)
        : context.palette.textTertiary;

    return SizedBox(
      width: width,
      child: Material(
        color: background,
        borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
          child: Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
              border: Border.all(
                color: selected
                    ? context.palette.accent
                    : (isToday ? context.palette.accent : context.palette.outlineSoft),
                width: isToday && !selected ? 1.4 : 1,
              ),
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: <Widget>[
                Text(
                  Dates.weekdayShort(date).toUpperCase(),
                  style: TextStyle(
                    fontSize: 10.5,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.6,
                    color: secondaryText,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  '${date.day}',
                  style: TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w700,
                    letterSpacing: -0.4,
                    color: primaryText,
                  ),
                ),
                const SizedBox(height: 5),
                _Dots(marker: marker, selected: selected),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _Dots extends StatelessWidget {
  const _Dots({required this.selected, this.marker});

  final DayMarker? marker;
  final bool selected;

  @override
  Widget build(BuildContext context) {
    final DayMarker? m = marker;
    if (m == null || m.count == 0) {
      return const SizedBox(height: 5);
    }
    final Color color = selected
        ? Colors.white
        : (m.hasUnmarked ? context.palette.warning : (m.color ?? context.palette.accent));
    final int dots = m.count > 3 ? 3 : m.count;
    return SizedBox(
      height: 5,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: <Widget>[
          for (int i = 0; i < dots; i++)
            Container(
              width: 4,
              height: 4,
              margin: const EdgeInsets.symmetric(horizontal: 1.2),
              decoration: BoxDecoration(
                color: color,
                shape: BoxShape.circle,
              ),
            ),
        ],
      ),
    );
  }
}
