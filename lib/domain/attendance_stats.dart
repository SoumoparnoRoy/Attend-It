import 'dart:math' as math;

import '../data/models/attendance_status.dart';
import '../data/models/class_session.dart';
import '../data/models/subject.dart';

/// How a subject is doing against its attendance requirement.
enum AttendanceHealth {
  /// Comfortably above target with room to spare.
  safe,

  /// At or just above target — one miss could break it.
  tight,

  /// Below target but still recoverable before the semester ends.
  atRisk,

  /// Below target and mathematically impossible to recover.
  lost,

  /// Nothing marked yet.
  empty,
}

/// Attendance maths for a single subject.
///
/// The interesting part is not the percentage — it is the two forward-looking
/// answers: how many classes you can still afford to miss, and how many you
/// must attend in a row to climb back.
class SubjectStats {
  const SubjectStats({
    required this.subject,
    required this.present,
    required this.absent,
    required this.cancelled,
    required this.target,
    required this.remainingPlanned,
  });

  final Subject subject;
  final int present;
  final int absent;
  final int cancelled;

  /// Required attendance as a fraction, e.g. 0.75.
  final double target;

  /// Classes still scheduled before the semester ends.
  final int remainingPlanned;

  /// Classes that count towards the percentage. Cancelled ones don't.
  int get held => present + absent;

  bool get hasData => held > 0;

  /// Current attendance as a fraction of held classes.
  double get ratio => held == 0 ? 0 : present / held;

  double get percent => ratio * 100;

  bool get meetsTarget => held == 0 || ratio >= target - 1e-9;

  /// How many more classes you can miss and still hold the target.
  ///
  /// Solve `present / (held + x) >= target` for the largest whole `x`:
  ///   `x = floor(present / target) - held`
  int get canSkip {
    if (target <= 0) return 999;
    if (present == 0) return 0;
    final int maxTotal = (present / target).floor();
    return math.max(0, maxTotal - held);
  }

  /// How many classes you must attend, back to back, to reach the target.
  ///
  /// Solve `(present + y) / (held + y) >= target` for the smallest whole `y`:
  ///   `y = ceil((target * held - present) / (1 - target))`
  int get needToAttend {
    if (meetsTarget) return 0;
    if (target >= 1) return remainingPlanned;
    final double numerator = target * held - present;
    if (numerator <= 0) return 0;
    return math.max(0, (numerator / (1 - target)).ceil());
  }

  /// The best percentage still achievable if you attend everything left.
  double get maxAchievableRatio {
    final int total = held + remainingPlanned;
    if (total == 0) return 1;
    return (present + remainingPlanned) / total;
  }

  /// True when even a perfect run from here cannot reach the target.
  bool get isUnrecoverable =>
      !meetsTarget && remainingPlanned > 0 && maxAchievableRatio < target - 1e-9;

  AttendanceHealth get health {
    if (!hasData) return AttendanceHealth.empty;
    if (meetsTarget) {
      return canSkip >= 2 ? AttendanceHealth.safe : AttendanceHealth.tight;
    }
    if (remainingPlanned > 0 && maxAchievableRatio < target - 1e-9) {
      return AttendanceHealth.lost;
    }
    return AttendanceHealth.atRisk;
  }

  /// The one-line verdict shown under each subject.
  String get headline {
    switch (health) {
      case AttendanceHealth.empty:
        return 'No classes marked yet';
      case AttendanceHealth.safe:
        return canSkip == 1
            ? 'You can skip 1 more class'
            : 'You can skip $canSkip more classes';
      case AttendanceHealth.tight:
        return canSkip == 0
            ? 'Right on target — attending the next one keeps you here'
            : 'You can skip 1 more class';
      case AttendanceHealth.atRisk:
        return needToAttend == 1
            ? 'One more class brings you back to target'
            : 'Attending the next $needToAttend brings you back to target';
      case AttendanceHealth.lost:
        return 'Target is out of reach this semester';
    }
  }

  static SubjectStats fromSessions({
    required Subject subject,
    required Iterable<ClassSession> sessions,
    required double target,
    int remainingPlanned = 0,
  }) {
    int present = 0;
    int absent = 0;
    int cancelled = 0;
    for (final ClassSession session in sessions) {
      final AttendanceStatus? status = session.status;
      if (status == AttendanceStatus.present) {
        present++;
      } else if (status == AttendanceStatus.absent) {
        absent++;
      } else if (status == AttendanceStatus.cancelled) {
        cancelled++;
      }
    }
    return SubjectStats(
      subject: subject,
      present: present,
      absent: absent,
      cancelled: cancelled,
      target: target,
      remainingPlanned: remainingPlanned,
    );
  }
}

/// Aggregate view across every subject.
class OverallStats {
  const OverallStats({required this.subjects, required this.target});

  final List<SubjectStats> subjects;
  final double target;

  int get present =>
      subjects.fold<int>(0, (int sum, SubjectStats s) => sum + s.present);

  int get absent =>
      subjects.fold<int>(0, (int sum, SubjectStats s) => sum + s.absent);

  int get cancelled =>
      subjects.fold<int>(0, (int sum, SubjectStats s) => sum + s.cancelled);

  int get held => present + absent;

  bool get hasData => held > 0;

  double get ratio => held == 0 ? 0 : present / held;

  double get percent => ratio * 100;

  bool get meetsTarget => held == 0 || ratio >= target - 1e-9;

  /// Subjects that have fallen below their own target.
  List<SubjectStats> get atRisk => subjects
      .where((SubjectStats s) => s.hasData && !s.meetsTarget)
      .toList();

  /// Subjects sitting on the edge — one absence away from dropping below.
  List<SubjectStats> get tight => subjects
      .where((SubjectStats s) =>
          s.hasData && s.meetsTarget && s.canSkip == 0)
      .toList();

  SubjectStats? get weakest {
    final List<SubjectStats> withData =
        subjects.where((SubjectStats s) => s.hasData).toList();
    if (withData.isEmpty) return null;
    withData.sort((SubjectStats a, SubjectStats b) =>
        a.ratio.compareTo(b.ratio));
    return withData.first;
  }
}
