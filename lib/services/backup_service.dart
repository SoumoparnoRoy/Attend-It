import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import '../core/date_utils.dart';
import '../data/db/zeolite_repository.dart';
import '../data/models/attendance_record.dart';
import '../data/models/class_category.dart';
import '../data/models/class_slot.dart';
import '../data/models/extra_class.dart';
import '../data/models/holiday.dart';
import '../data/models/room.dart';
import '../data/models/subject.dart';
import '../data/models/tag.dart';
import '../data/settings/app_settings.dart';

/// Result of an import attempt.
class ImportResult {
  const ImportResult({
    required this.success,
    required this.message,
    this.settings,
  });

  final bool success;
  final String message;
  final AppSettings? settings;
}

/// Exports and restores everything as a single JSON document.
///
/// Local-only storage is fast and private, but it means the phone is the only
/// copy — so a one-tap backup you can paste anywhere matters.
class BackupService {
  BackupService(this._repo, this._settingsService);

  final ZeoliteRepository _repo;
  final SettingsService _settingsService;

  /// v2 added class categories, v3 the saved room list and the day-grid
  /// settings, v4 attendance tags. Older backups still import: a missing key
  /// just means that feature was unused when the file was written, which is
  /// exactly what an empty list or a zero block length already mean.
  static const int formatVersion = 4;

  /// Written into every export so an import can tell our files from anything
  /// else pasted in.
  static const String appTag = 'Zeolite';

  /// The tag written before the app was renamed. Accepted on import and never
  /// on export, so a backup taken under the old name still restores — the file
  /// is the user's data, and a rebrand is no reason to reject it.
  static const String _legacyAppTag = 'Attend It!';

  /// Whether an export's `app` field is one we wrote.
  ///
  /// Separate from the import itself so the rename compatibility can be tested
  /// without a database behind it.
  static bool isRecognisedTag(Object? tag) =>
      tag == appTag || tag == _legacyAppTag;

  /// Builds the full backup document.
  Future<Map<String, Object?>> buildBackup() async {
    final List<ClassCategory> categories = await _repo.getCategories();
    final List<Room> rooms = await _repo.getRooms();
    final List<Tag> tags = await _repo.getTags();
    final List<Subject> subjects = await _repo.getSubjects();
    final List<ClassSlot> slots = await _repo.getSlots();
    final List<ExtraClass> extras = await _repo.getExtraClasses();
    final List<AttendanceRecord> records = await _repo.getAttendance();
    final List<Holiday> holidays = await _repo.getHolidays();
    final AppSettings settings = await _settingsService.load();

    return <String, Object?>{
      'app': appTag,
      'formatVersion': formatVersion,
      'exportedAt': DateTime.now().toIso8601String(),
      'settings': settings.toJson(),
      'categories':
          categories.map((ClassCategory c) => c.toMap()).toList(),
      'rooms': rooms.map((Room r) => r.toMap()).toList(),
      'tags': tags.map((Tag t) => t.toMap()).toList(),
      'subjects': subjects.map((Subject s) => s.toMap()).toList(),
      'slots': slots.map((ClassSlot s) => s.toMap()).toList(),
      'extraClasses': extras.map((ExtraClass e) => e.toMap()).toList(),
      'attendance': records.map((AttendanceRecord r) => r.toMap()).toList(),
      'holidays': holidays.map((Holiday h) => h.toMap()).toList(),
    };
  }

  Future<String> exportToJsonString() async {
    const JsonEncoder encoder = JsonEncoder.withIndent('  ');
    return encoder.convert(await buildBackup());
  }

  /// Writes the backup to the app's documents directory and returns the file.
  ///
  /// This location needs no storage permission on modern Android and is
  /// reachable from a file manager under `Android/data/<package>/files`.
  Future<File> exportToFile() async {
    final String json = await exportToJsonString();
    final Directory dir = await getApplicationDocumentsDirectory();
    final File file = File(p.join(dir.path, fileNameFor(DateTime.now())));
    return file.writeAsString(json);
  }

  /// `zeolite_backup_20260819_1310.json` — sorts chronologically as plain text,
  /// which is what lets the prune below pick the oldest without parsing dates
  /// or trusting filesystem timestamps.
  static String fileNameFor(DateTime now) {
    final String stamp = '${Dates.keyOf(now)}_'
        '${now.hour.toString().padLeft(2, '0')}'
        '${now.minute.toString().padLeft(2, '0')}';
    return '$_filePrefix$stamp.json';
  }

  static const String _filePrefix = 'zeolite_backup_';

  /// Five daily files is a working week of history for a few hundred KB, and
  /// old ones are deleted rather than left to grow for the life of the install.
  static const int keepAutoBackups = 5;

  // ------------------------------------------------------------ auto backup

  /// Whether an automatic backup is due. Separate from the writing so it can be
  /// tested without a filesystem, and so the caller skips the export entirely —
  /// serialising the database to find out nothing changed defeats the point.
  static bool isAutoBackupDue({
    required bool enabled,
    required DateTime? lastAt,
    required DateTime now,
  }) {
    if (!enabled) return false;
    if (lastAt == null) return true;
    return Dates.keyOf(now) != Dates.keyOf(lastAt);
  }

  /// Writes one automatic backup and prunes the oldest beyond
  /// [keepAutoBackups]. Returns the file, or null when nothing was due.
  ///
  /// Goes to the app's own documents directory, not anywhere the user picked:
  /// a save-dialog location is granted for that dialog only, so writing there
  /// unattended would need a persisted URI permission the app never asks for.
  Future<File?> runAutoBackup({
    required bool enabled,
    required DateTime? lastAt,
    DateTime? nowOverride,
  }) async {
    final DateTime now = nowOverride ?? DateTime.now();
    if (!isAutoBackupDue(enabled: enabled, lastAt: lastAt, now: now)) {
      return null;
    }
    final File file = await exportToFile();
    await pruneAutoBackups();
    return file;
  }

  /// Deletes the oldest exports beyond [keepAutoBackups].
  ///
  /// Exports written into this folder before the file dialog existed are pruned
  /// too — the folder goes when the app does, so nothing here is the durable
  /// copy. A manual export lands wherever the user chose and is never touched.
  Future<void> pruneAutoBackups() async {
    final Directory dir = await getApplicationDocumentsDirectory();
    final List<File> backups = <File>[
      for (final FileSystemEntity e in dir.listSync())
        if (e is File && p.basename(e.path).startsWith(_filePrefix)) e,
    ]..sort((File a, File b) => p.basename(a.path).compareTo(p.basename(b.path)));

    for (int i = 0; i < backups.length - keepAutoBackups; i++) {
      try {
        backups[i].deleteSync();
      } catch (_) {
        // A file the OS has locked or the user deleted underneath us is not
        // worth failing a backup over; the next run tries again.
      }
    }
  }

  /// Replaces all current data with the contents of [jsonString].
  ///
  /// Ids are remapped rather than trusted, so a backup can be restored onto a
  /// database that already has rows without primary-key collisions.
  Future<ImportResult> importFromJsonString(String jsonString) async {
    late final Map<String, Object?> data;
    try {
      final Object? decoded = jsonDecode(jsonString);
      if (decoded is! Map<String, Object?>) {
        return const ImportResult(
          success: false,
          message: 'That does not look like a Zeolite backup.',
        );
      }
      data = decoded;
    } catch (_) {
      return const ImportResult(
        success: false,
        message: 'Could not read that as JSON.',
      );
    }

    if (!isRecognisedTag(data['app'])) {
      return const ImportResult(
        success: false,
        message: 'This file was not created by Zeolite.',
      );
    }

    final int version = (data['formatVersion'] as num?)?.toInt() ?? 0;
    if (version > formatVersion) {
      return const ImportResult(
        success: false,
        message: 'This backup came from a newer version of Zeolite.',
      );
    }

    try {
      await _repo.clearAll();

      // Old id -> newly assigned id, for categories, subjects and tags.
      final Map<int, int> categoryIdMap = <int, int>{};
      final Map<int, int> subjectIdMap = <int, int>{};
      final Map<int, int> tagIdMap = <int, int>{};

      for (final Object? raw in (data['categories'] as List<Object?>?) ??
          const <Object?>[]) {
        if (raw is! Map) continue;
        final Map<String, Object?> map = Map<String, Object?>.from(raw);
        final int? oldId = (map['id'] as num?)?.toInt();
        final ClassCategory category = ClassCategory.fromMap(map);
        final int newId = await _repo.insertCategory(
          ClassCategory(
            name: category.name,
            defaultDurationMinutes: category.defaultDurationMinutes,
            createdAt: category.createdAt,
          ),
        );
        if (oldId != null) categoryIdMap[oldId] = newId;
      }

      // Nothing references a room by id, so these need no id remapping.
      for (final Object? raw in (data['rooms'] as List<Object?>?) ??
          const <Object?>[]) {
        if (raw is! Map) continue;
        final Room room = Room.fromMap(Map<String, Object?>.from(raw));
        await _repo.insertRoom(Room(name: room.name));
      }

      // Tags do need remapping — `attendance.tag_id` points at one. Restored
      // before the marks that reference them, so the ids exist by then.
      for (final Object? raw in (data['tags'] as List<Object?>?) ??
          const <Object?>[]) {
        if (raw is! Map) continue;
        final Map<String, Object?> map = Map<String, Object?>.from(raw);
        final int? oldId = (map['id'] as num?)?.toInt();
        final Tag tag = Tag.fromMap(map);
        final int newId = await _repo.insertTag(Tag(name: tag.name));
        if (oldId != null) tagIdMap[oldId] = newId;
      }

      for (final Object? raw in (data['subjects'] as List<Object?>?) ??
          const <Object?>[]) {
        if (raw is! Map) continue;
        final Map<String, Object?> map = Map<String, Object?>.from(raw);
        final int? oldId = (map['id'] as num?)?.toInt();
        final Subject subject = Subject.fromMap(map);
        final int newId = await _repo.insertSubject(
          Subject(
            name: subject.name,
            code: subject.code,
            teacher: subject.teacher,
            colorValue: subject.colorValue,
            targetPercent: subject.targetPercent,
            categoryId: subject.categoryId == null
                ? null
                : categoryIdMap[subject.categoryId],
            createdAt: subject.createdAt,
          ),
        );
        if (oldId != null) subjectIdMap[oldId] = newId;
      }

      for (final Object? raw in (data['slots'] as List<Object?>?) ??
          const <Object?>[]) {
        if (raw is! Map) continue;
        final Map<String, Object?> map = Map<String, Object?>.from(raw);
        final ClassSlot slot = ClassSlot.fromMap(map);
        final int? subjectId = subjectIdMap[slot.subjectId];
        if (subjectId == null) continue;
        // Rebuilt without an id so SQLite assigns a fresh primary key.
        await _repo.insertSlot(
          ClassSlot(
            subjectId: subjectId,
            weekday: slot.weekday,
            startMinutes: slot.startMinutes,
            endMinutes: slot.endMinutes,
            room: slot.room,
            startDate: slot.startDate,
            endDate: slot.endDate,
          ),
        );
      }

      for (final Object? raw in (data['extraClasses'] as List<Object?>?) ??
          const <Object?>[]) {
        if (raw is! Map) continue;
        final Map<String, Object?> map = Map<String, Object?>.from(raw);
        final ExtraClass extra = ExtraClass.fromMap(map);
        final int? subjectId = subjectIdMap[extra.subjectId];
        if (subjectId == null) continue;
        await _repo.insertExtraClass(
          ExtraClass(
            subjectId: subjectId,
            date: extra.date,
            startMinutes: extra.startMinutes,
            endMinutes: extra.endMinutes,
            room: extra.room,
            note: extra.note,
          ),
        );
      }

      final List<AttendanceRecord> records = <AttendanceRecord>[];
      for (final Object? raw in (data['attendance'] as List<Object?>?) ??
          const <Object?>[]) {
        if (raw is! Map) continue;
        final Map<String, Object?> map = Map<String, Object?>.from(raw);
        final AttendanceRecord record = AttendanceRecord.fromMap(map);
        final int? subjectId = subjectIdMap[record.subjectId];
        if (subjectId == null) continue;
        records.add(
          AttendanceRecord(
            subjectId: subjectId,
            date: record.date,
            startMinutes: record.startMinutes,
            status: record.status,
            // An unknown tag id drops to null rather than failing the import.
            // The mark is the data worth keeping; the label is not worth
            // rejecting a whole backup over.
            tagId: record.tagId == null ? null : tagIdMap[record.tagId],
            note: record.note,
            markedAt: record.markedAt,
          ),
        );
      }
      await _repo.setManyAttendance(records);

      for (final Object? raw in (data['holidays'] as List<Object?>?) ??
          const <Object?>[]) {
        if (raw is! Map) continue;
        final Map<String, Object?> map = Map<String, Object?>.from(raw);
        final Holiday holiday = Holiday.fromMap(map);
        await _repo.insertHoliday(
          Holiday(date: holiday.date, name: holiday.name),
        );
      }

      AppSettings? settings;
      final Object? rawSettings = data['settings'];
      if (rawSettings is Map) {
        settings = AppSettings.fromJson(Map<String, Object?>.from(rawSettings));
        await _settingsService.save(settings);
      }

      return ImportResult(
        success: true,
        message: 'Backup restored.',
        settings: settings,
      );
    } catch (error) {
      return ImportResult(
        success: false,
        message: 'Import failed: $error',
      );
    }
  }
}
