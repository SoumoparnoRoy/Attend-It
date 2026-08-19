import '../data/models/attendance_record.dart';
import '../data/models/attendance_status.dart';
import '../data/models/subject.dart';
import '../data/models/tag.dart';

/// One marked class carrying a tag, resolved enough to list on screen.
///
/// The subject is looked up here rather than on the widget so the stats screen
/// never has to search the subject list per row.
class TaggedMark {
  const TaggedMark({
    required this.record,
    required this.subject,
  });

  final AttendanceRecord record;

  /// Null when the mark outlived its subject. Cannot happen through the app —
  /// `attendance` cascades on subject delete — but a hand-edited import could
  /// carry one, and dropping the row silently would make the counts lie.
  final Subject? subject;

  AttendanceStatus get status => record.status;
}

/// Every mark carrying one tag, and the split that makes the group readable.
///
/// Deliberately not a percentage. A tag is not a target you are measured
/// against, and showing "Proxy: 62%" would invite reading it as one.
class TagBreakdown {
  const TagBreakdown({required this.tag, required this.marks});

  final Tag tag;

  /// Newest first — a tag is usually consulted for what happened recently.
  final List<TaggedMark> marks;

  int get total => marks.length;

  bool get isEmpty => marks.isEmpty;

  int countOf(AttendanceStatus status) =>
      marks.where((TaggedMark m) => m.status == status).length;

  int get present => countOf(AttendanceStatus.present);

  int get absent => countOf(AttendanceStatus.absent);

  int get cancelled => countOf(AttendanceStatus.cancelled);

  /// How many distinct subjects this tag appears across, which is the one
  /// number that says whether a tag is a per-subject habit or a general one.
  int get subjectCount =>
      marks.map((TaggedMark m) => m.record.subjectId).toSet().length;

  /// "1 class" / "4 classes" — the count with its noun agreeing.
  String get countLabel => total == 1 ? '1 class' : '$total classes';

  /// The line under the tag name. Reads as a plain description of the marks
  /// rather than a verdict, since a tag carries no target.
  String get summary {
    if (isEmpty) return 'Not used yet';
    final List<String> parts = <String>[
      if (present > 0) '$present present',
      if (absent > 0) '$absent absent',
      if (cancelled > 0) '$cancelled cancelled',
    ];
    return parts.join(' · ');
  }
}

/// Groups attendance marks by the tag they carry.
///
/// Untagged marks are simply absent from the result — "no tag" is the default
/// and not a group anyone wants to page through. Tags with no marks are kept,
/// so a tag you just created still shows up instead of looking like it failed
/// to save.
List<TagBreakdown> buildTagBreakdowns({
  required List<Tag> tags,
  required List<AttendanceRecord> records,
  required List<Subject> subjects,
}) {
  if (tags.isEmpty) return const <TagBreakdown>[];

  final Map<int, Subject> subjectsById = <int, Subject>{
    for (final Subject subject in subjects)
      if (subject.id != null) subject.id!: subject,
  };

  final Map<int, List<TaggedMark>> byTag = <int, List<TaggedMark>>{
    for (final Tag tag in tags)
      if (tag.id != null) tag.id!: <TaggedMark>[],
  };

  for (final AttendanceRecord record in records) {
    final int? tagId = record.tagId;
    if (tagId == null) continue;
    // A mark can point at a tag that no longer exists if a database was edited
    // outside the app; the FK handles the in-app path. Skipping keeps the
    // group list and the tag list in step.
    final List<TaggedMark>? bucket = byTag[tagId];
    if (bucket == null) continue;
    bucket.add(
      TaggedMark(record: record, subject: subjectsById[record.subjectId]),
    );
  }

  for (final List<TaggedMark> marks in byTag.values) {
    marks.sort((TaggedMark a, TaggedMark b) {
      final int byDate = b.record.date.compareTo(a.record.date);
      if (byDate != 0) return byDate;
      return b.record.startMinutes.compareTo(a.record.startMinutes);
    });
  }

  return <TagBreakdown>[
    for (final Tag tag in tags)
      if (tag.id != null)
        TagBreakdown(tag: tag, marks: byTag[tag.id!] ?? const <TaggedMark>[]),
  ];
}
