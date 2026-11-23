// src: lib/store/sqlite_store.dart
// @(#) : SQLite-backed MappingTable and MachineIdProvider implementation
//
// Copyright (c) 2026 atsushifx <http://github.com/atsushifx>
//
// Released under the MIT License.
// https://opensource.org/licenses/MIT

import 'dart:math';

import 'package:sqlite3/sqlite3.dart';

import '../errors.dart';
import '../models.dart';
import '../tag/providers.dart';
import 'mapping_table.dart';
import 'schema.dart';
import 'transaction.dart';

/// Key of the machine id row in `settings`.
const String _machineIdKey = 'machine_id';

/// SQL predicate selecting current rows (`notify_status` 1 or 2), excluding superseded ones (0).
const String _currentRowPredicate = 'notify_status IN (1, 2)';

/// Store backed by one SQLite [Database].
///
/// Implements [MappingTable] (`notifications` table) and [MachineIdProvider]
/// (`settings` table). [SqliteStore.open] rejects a corrupt file through
/// [openDatabase]; the store does not check `user_version`. A [SqliteException] while reading or writing is thrown as a
/// [StorageException].
class SqliteStore implements MappingTable, MachineIdProvider {
  /// Wraps an already opened [db] without creating the schema.
  ///
  /// The caller must have created the schema (as [SqliteStore.open] does), and the store takes ownership
  /// of [db] ([close] closes it). Mainly a seam for injecting a test double.
  SqliteStore.fromDatabase(this._db);

  /// Opens (creating if needed) the database at [path] and ensures the schema
  /// (see [openDatabase]).
  factory SqliteStore.open(String path) =>
      SqliteStore.fromDatabase(openDatabase(path));

  final Database _db;

  /// Value returned by [machineId] after its first successful call.
  String? _cachedMachineId;

  /// Closes the underlying database.
  void close() => _db.close();

  /// Returns the record for ([batchId], [alarmId]), or null when none exists.
  ///
  /// A [SqliteException] is thrown as a [StorageException].
  @override
  MappingRecord? get(String batchId, String alarmId) => _selectRecords(
    'WHERE batch_id = ? AND alarm_id = ?',
    [batchId, alarmId],
  ).firstOrNull;

  /// Returns every current record (`notify_status` 1 or 2).
  ///
  /// A [SqliteException] is thrown as a [StorageException].
  @override
  List<MappingRecord> all() => _selectRecords('WHERE $_currentRowPredicate');

  /// Returns the Tag of every row, including superseded ones (`notify_status` 0),
  /// because the OS may still hold their notifications.
  ///
  /// A [SqliteException] is thrown as a [StorageException].
  @override
  Set<String> tags() {
    return _guard(
      'Failed to read the mapping: ',
      () => _db
          .select('SELECT tag FROM notifications')
          .map((Row r) => r['tag'] as String)
          .toSet(),
    );
  }

  /// Runs [action], rethrowing a [SqliteException] as a [StorageException]
  /// whose message is [failurePrefix] followed by the SQLite message.
  static T _guard<T>(String failurePrefix, T Function() action) {
    try {
      return action();
    } on SqliteException catch (e) {
      throw StorageException('$failurePrefix${e.message}');
    }
  }

  /// Selects records matching [where] (an SQL `WHERE` clause with [params]).
  List<MappingRecord> _selectRecords(
    String where, [
    List<Object?> params = const [],
  ]) {
    return _guard(
      'Failed to read the mapping: ',
      () => _db
          .select(
            'SELECT batch_id, alarm_id, tag, at, title, registered_at '
            'FROM notifications $where',
            params,
          )
          .map(
            (Row r) => MappingRecord(
              batchId: r['batch_id'] as String,
              alarmId: r['alarm_id'] as String,
              tag: r['tag'] as String,
              at: DateTime.parse(r['at'] as String),
              title: r['title'] as String,
              registeredAt: DateTime.parse(r['registered_at'] as String),
            ),
          )
          .toList(),
    );
  }

  /// Stores [record] in one transaction: updates the current row (`notify_status`
  /// 1 or 2) of its key in place, keeping its physical id, or inserts a new row
  /// when there is none. `at` is saved as UTC and `registeredAt` as local time
  /// without an offset. A [SqliteException] is thrown as a [StorageException].
  @override
  void put(MappingRecord record) {
    final String at = record.at.toUtc().toIso8601String();
    final String registeredAt = record.registeredAt.toIso8601String();
    _guard('Failed to save the mapping: ', () {
      runInTransaction(_db, () {
        _db.execute(
          'UPDATE notifications SET tag = ?, at = ?, title = ?, registered_at = ? '
          'WHERE batch_id = ? AND alarm_id = ? AND $_currentRowPredicate',
          [
            record.tag,
            at,
            record.title,
            registeredAt,
            record.batchId,
            record.alarmId,
          ],
        );
        if (_db.updatedRows > 0) return;
        _db.execute(
          'INSERT INTO notifications '
          '(group_name, tag, batch_id, alarm_id, at, title, registered_at) '
          'VALUES (?, ?, ?, ?, ?, ?, ?)',
          [
            kGroup,
            record.tag,
            record.batchId,
            record.alarmId,
            at,
            record.title,
            registeredAt,
          ],
        );
      });
    });
  }

  /// Deletes the current row (`notify_status` 1 or 2) of ([batchId], [alarmId]) in
  /// one transaction; does nothing when there is none. A [SqliteException] is
  /// thrown as a [StorageException].
  @override
  void remove(String batchId, String alarmId) {
    _guard(
      'Failed to remove the mapping: ',
      () => runInTransaction(
        _db,
        () => _db.execute(
          'DELETE FROM notifications '
          'WHERE batch_id = ? AND alarm_id = ? AND $_currentRowPredicate',
          [batchId, alarmId],
        ),
      ),
    );
  }

  /// Returns the stored `machine_id`, or generates and stores a new one.
  ///
  /// The value is cached per instance after the first call. A stored value
  /// that is not text of 8 lowercase hex digits throws a [StorageException]; it is
  /// neither repaired, replaced nor cached. A [SqliteException] while reading
  /// or saving is thrown as a [StorageException]; a failed save caches nothing,
  /// so a later call retries. A failed `BEGIN` is thrown without a rollback:
  /// no transaction was started, and a ROLLBACK could undo one that is already
  /// open.
  @override
  String machineId() {
    final String? cached = _cachedMachineId;
    if (cached != null) return cached;

    final String value = _readStoredMachineId() ?? _saveNewMachineId();
    return _cachedMachineId = value;
  }

  /// Reads and validates the stored `machine_id`; returns null when no row
  /// exists. Throws a [StorageException] when the SELECT fails or the value is
  /// not text of 8 lowercase hex digits (this includes TEXT that is not valid
  /// UTF-8, which the sqlite3 package rejects with a [FormatException] while
  /// decoding the row). Caches nothing.
  String? _readStoredMachineId() {
    final Object? value;
    try {
      final ResultSet rows = _db.select(
        'SELECT value FROM settings WHERE key = ?',
        [_machineIdKey],
      );
      if (rows.isEmpty) return null;
      value = rows.first['value'];
    } on SqliteException catch (e) {
      throw StorageException('Failed to read machine_id: ${e.message}');
    } on FormatException {
      // The sqlite3 package decodes TEXT cells as strict UTF-8 inside select.
      throw StorageException(
        'Stored machine_id is invalid: not valid UTF-8 text (expected 8 lowercase hex digits)',
      );
    }
    if (value is! String) {
      throw StorageException(
        'Stored machine_id is invalid: expected text but found ${value.runtimeType} (expected 8 lowercase hex digits)',
      );
    }
    if (!kMachineIdPattern.hasMatch(value)) {
      throw StorageException(
        'Stored machine_id is invalid: "$value" (expected 8 lowercase hex digits)',
      );
    }
    return value;
  }

  /// Generates a new `machine_id` and INSERTs it in one transaction; a
  /// [SqliteException] from `BEGIN`, the INSERT or COMMIT is thrown as a
  /// [StorageException] (see [runInTransaction] for the ROLLBACK rules).
  /// Caches nothing.
  String _saveNewMachineId() {
    final String value = _generateMachineId();
    _guard(
      'Failed to save machine_id: ',
      () => runInTransaction(
        _db,
        () => _db.execute('INSERT INTO settings (key, value) VALUES (?, ?)', [
          _machineIdKey,
          value,
        ]),
      ),
    );
    return value;
  }

  /// Builds 8 lowercase hex digits from 4 secure random bytes.
  static String _generateMachineId() {
    final Random random = Random.secure();
    return List.generate(
      4,
      (_) => random.nextInt(256).toRadixString(16).padLeft(2, '0'),
    ).join();
  }
}
