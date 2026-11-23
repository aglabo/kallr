// src: lib/store/schema.dart
// @(#) : SQLite schema (DDL) and database opening
//
// Copyright (c) 2026 atsushifx <http://github.com/atsushifx>
//
// Released under the MIT License.
// https://opensource.org/licenses/MIT

import 'dart:io';

import 'package:sqlite3/sqlite3.dart';

import '../errors.dart';
import 'transaction.dart';

/// Schema version written to `PRAGMA user_version` when a database is created.
const int _schemaVersion = 1;

/// Reads the stored schema version.
const String _userVersionSql = 'PRAGMA user_version';

/// Finds any schema object, internal `sqlite_*` ones included; no row means
/// the database file is empty (brand new, or a 0-byte file).
const String _anyObjectSql = 'SELECT 1 FROM sqlite_master LIMIT 1';

/// Integrity check that only reads; a healthy database yields one row `ok`.
const String _quickCheckSql = 'PRAGMA quick_check';

/// DDL of the tables and indexes the store needs (db-migration.md §2.2).
const String _schemaDdl = '''
  CREATE TABLE IF NOT EXISTS notifications (
    id            INTEGER PRIMARY KEY AUTOINCREMENT,
    group_name    TEXT NOT NULL CHECK (length(group_name) BETWEEN 1 AND 64),
    tag           TEXT NOT NULL CHECK (length(tag) = 40),
    batch_id      TEXT NOT NULL CHECK (batch_id <> ''),
    alarm_id      TEXT NOT NULL CHECK (alarm_id <> ''),
    at            TEXT NOT NULL,
    title         TEXT NOT NULL,
    registered_at TEXT NOT NULL,
    notify_status INTEGER NOT NULL DEFAULT 1 CHECK (notify_status IN (0, 1, 2)),
    UNIQUE (group_name, tag)
  );
  CREATE UNIQUE INDEX IF NOT EXISTS notifications_current
    ON notifications (batch_id, alarm_id) WHERE notify_status IN (1, 2);
  CREATE TABLE IF NOT EXISTS replacement_queue (
    id     INTEGER PRIMARY KEY AUTOINCREMENT,
    new_id INTEGER NOT NULL REFERENCES notifications(id) ON DELETE CASCADE,
    old_id INTEGER REFERENCES notifications(id) ON DELETE SET NULL
  );
  CREATE INDEX IF NOT EXISTS replacement_queue_pending
    ON replacement_queue (id) WHERE old_id IS NOT NULL;
  CREATE TABLE IF NOT EXISTS settings (
    id    INTEGER PRIMARY KEY AUTOINCREMENT,
    key   TEXT NOT NULL CHECK (key <> ''),
    value TEXT NOT NULL
  );
  CREATE UNIQUE INDEX IF NOT EXISTS settings_key ON settings (key);
''';

/// Opens (creating if needed) the database at [path] and ensures the schema.
///
/// Missing parent directories of [path] are created first (SCH-R-029).
///
/// Before any write, `PRAGMA quick_check` and the version gate
/// ([_requireKnownVersion]) run, so a corrupt file, a file with an undefined
/// `user_version`, and another application's database (tables but version 0)
/// are never modified or recreated (SCH-R-027). A [SqliteException] while opening or
/// initializing (e.g. the file is not an SQLite database) and a failed check
/// close the [Database] and are thrown as a [StorageException]; any other
/// exception also closes it and is rethrown unchanged.
Database openDatabase(String path) {
  Database? db;
  try {
    File(path).parent.createSync(recursive: true);
    final Database opened = sqlite3.open(path);
    db = opened;
    // Per connection, and a no-op inside a transaction: set it before any DDL.
    opened.execute('PRAGMA foreign_keys = ON');
    _requireIntact(opened, path);
    // No object in sqlite_master: brand new, or a 0-byte file (see _anyObjectSql).
    final bool isEmpty = opened.select(_anyObjectSql).isEmpty;
    _requireKnownVersion(opened, path, isEmpty: isEmpty);
    runInTransaction(opened, () {
      opened.execute(_schemaDdl);
      if (isEmpty) opened.execute('PRAGMA user_version = $_schemaVersion');
    });
    return opened;
  } on SqliteException catch (e) {
    db?.close();
    throw StorageException(
      'Failed to open or initialize the database at "$path": ${e.message}',
    );
  } catch (_) {
    db?.close();
    rethrow;
  }
}

/// Version gate (db-migration.md 3.1): throws a [StorageException] unless the
/// `user_version` of [db] is one this code defines.
///
/// Reads only, so a file with an undefined version is never written. Defined:
/// 0 (`empty`: no object in `sqlite_master` at all) and 1 (`initial`); anything
/// else is reserved and is not read until it is defined. Version 0 with any
/// object is another application's database and is rejected too.
/// - [isEmpty]: whether `sqlite_master` of [db] holds no object.
void _requireKnownVersion(Database db, String path, {required bool isEmpty}) {
  final int version = db.select(_userVersionSql).single.values.first as int;
  if (version == _schemaVersion || (version == 0 && isEmpty)) return;
  throw StorageException(
    version == 0
        ? 'The database at "$path" has tables but no known schema version '
              '(user_version 0); it is not created by this code.'
        : 'The database at "$path" has undefined schema version $version '
              '(this code defines versions 0 and $_schemaVersion).',
  );
}

/// Throws a [StorageException] unless `PRAGMA quick_check` on [db] reports only `ok`.
void _requireIntact(Database db, String path) {
  final List<Object?> results = db
      .select(_quickCheckSql)
      .map((Row r) => r.values.first)
      .toList();
  if (results.length == 1 && results.single == 'ok') return;
  throw StorageException(
    'The database at "$path" is corrupt: ${results.join('; ')}',
  );
}
