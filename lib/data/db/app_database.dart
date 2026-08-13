import 'package:path/path.dart' as p;
import 'package:sqflite/sqflite.dart';

/// Owns the SQLite connection and the schema.
///
/// Everything is local to the device: no accounts, no network, works on a train
/// with no signal.
class AppDatabase {
  AppDatabase._();

  static final AppDatabase instance = AppDatabase._();

  static const String fileName = 'attend_it.db';
  static const int schemaVersion = 2;

  Database? _db;

  Future<Database> get database async {
    return _db ??= await _open();
  }

  Future<Database> _open() async {
    final String dir = await getDatabasesPath();
    final String path = p.join(dir, fileName);
    return openDatabase(
      path,
      version: schemaVersion,
      onConfigure: (Database db) async {
        await db.execute('PRAGMA foreign_keys = ON');
      },
      onCreate: (Database db, int version) async {
        await _createSchema(db);
      },
      onUpgrade: (Database db, int oldVersion, int newVersion) async {
        // Migrations run in order so an old install can climb to current
        // without losing anything already recorded.
        if (oldVersion < 2) {
          // v2 introduced class categories (Theory, Lab, ...) which carry a
          // default class length, and linked subjects to them.
          await db.execute(_categoriesTable);
          await db.execute(
            'ALTER TABLE subjects ADD COLUMN category_id INTEGER',
          );
          await _seedCategories(db);
        }
      },
    );
  }

  /// Kept as a constant so the create path and the v2 migration cannot drift.
  static const String _categoriesTable = '''
      CREATE TABLE categories (
        id              INTEGER PRIMARY KEY AUTOINCREMENT,
        name            TEXT    NOT NULL,
        default_minutes INTEGER NOT NULL,
        created_at      INTEGER NOT NULL
      )
    ''';

  /// Two categories most timetables need on day one. They are ordinary rows —
  /// the user can rename, retime or delete them like any other.
  static Future<void> _seedCategories(Database db) async {
    final int now = DateTime.now().millisecondsSinceEpoch;
    final Batch batch = db.batch();
    batch.insert('categories', <String, Object?>{
      'name': 'Theory',
      'default_minutes': 60,
      'created_at': now,
    });
    batch.insert('categories', <String, Object?>{
      'name': 'Lab',
      'default_minutes': 120,
      'created_at': now,
    });
    await batch.commit(noResult: true);
  }

  Future<void> _createSchema(Database db) async {
    final Batch batch = db.batch();

    batch.execute(_categoriesTable);

    batch.execute('''
      CREATE TABLE subjects (
        id             INTEGER PRIMARY KEY AUTOINCREMENT,
        name           TEXT    NOT NULL,
        code           TEXT,
        teacher        TEXT,
        color          INTEGER NOT NULL,
        target_percent REAL,
        category_id    INTEGER,
        created_at     INTEGER NOT NULL,
        FOREIGN KEY (category_id) REFERENCES categories (id) ON DELETE SET NULL
      )
    ''');

    // A recurring weekly rule. Dates are stored as yyyymmdd integers.
    batch.execute('''
      CREATE TABLE class_slots (
        id            INTEGER PRIMARY KEY AUTOINCREMENT,
        subject_id    INTEGER NOT NULL,
        weekday       INTEGER NOT NULL,
        start_minutes INTEGER NOT NULL,
        end_minutes   INTEGER NOT NULL,
        room          TEXT,
        start_date    INTEGER NOT NULL,
        end_date      INTEGER,
        FOREIGN KEY (subject_id) REFERENCES subjects (id) ON DELETE CASCADE
      )
    ''');

    // One-off classes outside the weekly pattern.
    batch.execute('''
      CREATE TABLE extra_classes (
        id            INTEGER PRIMARY KEY AUTOINCREMENT,
        subject_id    INTEGER NOT NULL,
        date          INTEGER NOT NULL,
        start_minutes INTEGER NOT NULL,
        end_minutes   INTEGER NOT NULL,
        room          TEXT,
        note          TEXT,
        FOREIGN KEY (subject_id) REFERENCES subjects (id) ON DELETE CASCADE
      )
    ''');

    // One row per marked occurrence, keyed by subject + day + start time.
    batch.execute('''
      CREATE TABLE attendance (
        id            INTEGER PRIMARY KEY AUTOINCREMENT,
        subject_id    INTEGER NOT NULL,
        date          INTEGER NOT NULL,
        start_minutes INTEGER NOT NULL,
        status        TEXT    NOT NULL,
        note          TEXT,
        marked_at     INTEGER NOT NULL,
        UNIQUE (subject_id, date, start_minutes) ON CONFLICT REPLACE,
        FOREIGN KEY (subject_id) REFERENCES subjects (id) ON DELETE CASCADE
      )
    ''');

    batch.execute('''
      CREATE TABLE holidays (
        id   INTEGER PRIMARY KEY AUTOINCREMENT,
        date INTEGER NOT NULL UNIQUE,
        name TEXT    NOT NULL
      )
    ''');

    batch.execute(
      'CREATE INDEX idx_slots_subject ON class_slots (subject_id)',
    );
    batch.execute('CREATE INDEX idx_slots_weekday ON class_slots (weekday)');
    batch.execute('CREATE INDEX idx_extra_date ON extra_classes (date)');
    batch.execute('CREATE INDEX idx_attendance_date ON attendance (date)');
    batch.execute(
      'CREATE INDEX idx_attendance_subject ON attendance (subject_id)',
    );

    await batch.commit(noResult: true);
    await _seedCategories(db);
  }

  Future<void> close() async {
    await _db?.close();
    _db = null;
  }

  /// Wipes every table. Used by "reset all data" and by import.
  Future<void> clearAll() async {
    final Database db = await database;
    final Batch batch = db.batch();
    batch.delete('attendance');
    batch.delete('extra_classes');
    batch.delete('class_slots');
    batch.delete('holidays');
    batch.delete('subjects');
    batch.delete('categories');
    await batch.commit(noResult: true);
  }
}
