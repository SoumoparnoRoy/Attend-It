import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import '../core/date_utils.dart';
import '../data/db/attend_it_repository.dart';
import '../data/models/attendance_record.dart';
import '../data/models/class_category.dart';
import '../data/models/class_slot.dart';
import '../data/models/extra_class.dart';
import '../data/models/holiday.dart';
import '../data/models/subject.dart';
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

  final AttendItRepository _repo;
  final SettingsService _settingsService;

  /// v2 added class categories. Older backups still import — a missing
  /// `categories` key simply means every subject falls back to the global
  /// default class length.
  static const int formatVersion = 2;

  /// Written into every export so an import can tell our files from anything
  /// else pasted in.
  static const String appTag = 'Attend It!';

  /// Builds the full backup document.
  Future<Map<String, Object?>> buildBackup() async {
    final List<ClassCategory> categories = await _repo.getCategories();
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
    final DateTime now = DateTime.now();
    final String stamp = '${Dates.keyOf(now)}_'
        '${now.hour.toString().padLeft(2, '0')}'
        '${now.minute.toString().padLeft(2, '0')}';
    final File file = File(p.join(dir.path, 'attend_it_backup_$stamp.json'));
    return file.writeAsString(json);
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
          message: 'That does not look like an Attend It! backup.',
        );
      }
      data = decoded;
    } catch (_) {
      return const ImportResult(
        success: false,
        message: 'Could not read that as JSON.',
      );
    }

    if (data['app'] != appTag) {
      return const ImportResult(
        success: false,
        message: 'This file was not created by Attend It!.',
      );
    }

    final int version = (data['formatVersion'] as num?)?.toInt() ?? 0;
    if (version > formatVersion) {
      return const ImportResult(
        success: false,
        message: 'This backup came from a newer version of Attend It!.',
      );
    }

    try {
      await _repo.clearAll();

      // Old id -> newly assigned id, for both categories and subjects.
      final Map<int, int> categoryIdMap = <int, int>{};
      final Map<int, int> subjectIdMap = <int, int>{};

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
