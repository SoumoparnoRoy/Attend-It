import '../core/date_utils.dart';
import '../data/models/class_slot.dart';
import '../data/models/extra_class.dart';

/// Whether a proposed class would land on an attendance key another class of the
/// same subject already owns.
///
/// A mark is keyed by `(subjectId, dateKey, startMinutes)` so it survives editing
/// the rule that produced it. The cost is that two classes of one subject
/// starting at the same minute on the same day are indistinguishable to
/// attendance — marking one marks the other, and the second never appears in the
/// log — so they are rejected at entry instead.
class ClassClash {
  const ClassClash._();

  /// [proposed] keeps its own id so that editing a one-off does not clash with
  /// itself.
  static bool forOneOff({
    required List<ClassSlot> slots,
    required List<ExtraClass> extras,
    required ExtraClass proposed,
  }) {
    final int dateKey = Dates.keyOf(proposed.date);

    for (final ExtraClass other in extras) {
      if (other.id == proposed.id) continue;
      if (other.subjectId != proposed.subjectId) continue;
      if (other.startMinutes != proposed.startMinutes) continue;
      if (Dates.keyOf(other.date) == dateKey) return true;
    }

    for (final ClassSlot slot in slots) {
      if (slot.subjectId != proposed.subjectId) continue;
      if (slot.startMinutes != proposed.startMinutes) continue;
      if (slot.appliesOn(proposed.date)) return true;
    }

    return false;
  }

  /// The earliest date on which [proposed] would collide with a one-off class,
  /// or null. A rule spans months, so naming the day is what makes the message
  /// actionable.
  ///
  /// Rule against rule is not checked here — two rules clash on weekday and
  /// start time regardless of date, which the weekly form checks directly.
  static DateTime? forWeekly({
    required List<ExtraClass> extras,
    required ClassSlot proposed,
  }) {
    DateTime? earliest;
    for (final ExtraClass extra in extras) {
      if (extra.subjectId != proposed.subjectId) continue;
      if (extra.startMinutes != proposed.startMinutes) continue;
      // appliesOn carries the weekday and the start/end bounds, so the
      // recurrence window keeps one implementation.
      if (!proposed.appliesOn(extra.date)) continue;
      if (earliest == null || Dates.keyOf(extra.date) < Dates.keyOf(earliest)) {
        earliest = extra.date;
      }
    }
    return earliest;
  }
}
