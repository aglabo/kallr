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
import 'sqlite_access.dart';
import 'transaction.dart';

/// Key of the machine id row in `settings`.
const String _machineIdKey = 'machine_id';

/// Failure message prefixes shared by several methods.
const String _readFailure = 'Failed to read the mapping: ';
const String _replaceFailure = 'Failed to replace the mapping: ';

/// `notify_status` of a row: superseded, current or pending replacement.
///
/// Mirrors `CHECK (notify_status IN (0, 1, 2))` and the partial index
/// `IN (1, 2)` in schema.dart; keep them in sync.
enum _NotifyStatus {
  superseded(0),
  current(1),
  pending(2);

  const _NotifyStatus(this.value);

  /// The integer stored in the `notify_status` column.
  final int value;
}

/// SQL predicate selecting current rows ([_NotifyStatus.current] or
/// [_NotifyStatus.pending]), excluding superseded ones. Bind [_currentRowParams].
const String _currentRowPredicate = 'notify_status IN (?, ?)';

/// Values bound to the two `?` of [_currentRowPredicate].
final List<Object?> _currentRowParams = [
  _NotifyStatus.current.value,
  _NotifyStatus.pending.value,
];

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
  SqliteStore.fromDatabase(Database db) : _db = db, _access = SqliteAccess(db);

  /// Opens (creating if needed) the database at [path] and ensures the schema
  /// (see [openDatabase]).
  factory SqliteStore.open(String path) =>
      SqliteStore.fromDatabase(openDatabase(path));

  // Transitional: _db and _access wrap the same Database until _db is removed.
  final Database _db;
  final SqliteAccess _access;

  /// Value returned by [machineId] after its first successful call.
  String? _cachedMachineId;

  /// Closes the underlying database.
  void close() => _access.close();

  /// Returns the current record (`notify_status` 1 or 2) for ([batchId], [alarmId]),
  /// or null when none exists. A superseded row (0) is never returned.
  ///
  /// A [SqliteException] is thrown as a [StorageException].
  @override
  MappingRecord? get(String batchId, String alarmId) => _selectRecords(
    'WHERE batch_id = ? AND alarm_id = ? AND $_currentRowPredicate',
    [batchId, alarmId, ..._currentRowParams],
  ).firstOrNull;

  /// Returns every current record (`notify_status` 1 or 2).
  ///
  /// A [SqliteException] is thrown as a [StorageException].
  @override
  List<MappingRecord> all() =>
      _selectRecords('WHERE $_currentRowPredicate', _currentRowParams);

  /// Returns the Tag of every row, including superseded ones (`notify_status` 0),
  /// because the OS may still hold their notifications.
  ///
  /// A [SqliteException] is thrown as a [StorageException].
  @override
  Set<String> tags() {
    return _guard(
      _readFailure,
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
      _readFailure,
      () => _db
          .select(
            'SELECT batch_id, alarm_id, tag, at, title, registered_at '
            'FROM notifications $where',
            params,
          )
          .map(_toRecord)
          .toList(),
    );
  }

  /// Converts a row holding the columns `batch_id`, `alarm_id`, `tag`, `at`,
  /// `title` and `registered_at` of `notifications` into a [MappingRecord].
  static MappingRecord _toRecord(Row r) => MappingRecord(
    batchId: r['batch_id'] as String,
    alarmId: r['alarm_id'] as String,
    tag: r['tag'] as String,
    at: DateTime.parse(r['at'] as String),
    title: r['title'] as String,
    registeredAt: DateTime.parse(r['registered_at'] as String),
  );

  /// Returns the queued removals in queue order (`replacement_queue.id`).
  ///
  /// Each item holds the old row's Tag, the fixed [kGroup] and the new (pending)
  /// row as a [MappingRecord]. Queue rows without an old row are skipped.
  /// A [SqliteException] is thrown as a [StorageException].
  @override
  List<PendingRemoval> pendingRemovals() {
    return _guard(
      _readFailure,
      () => _db
          .select(
            'SELECT q.id AS queue_id, o.tag AS old_tag, o.group_name AS old_group, '
            'n.batch_id, n.alarm_id, n.tag, n.at, n.title, n.registered_at '
            'FROM replacement_queue q '
            'JOIN notifications n ON n.id = q.new_id '
            'JOIN notifications o ON o.id = q.old_id '
            'WHERE q.old_id IS NOT NULL ORDER BY q.id',
          )
          .map(
            (Row r) => PendingRemoval(
              queueId: r['queue_id'] as int,
              oldTag: r['old_tag'] as String,
              group: r['old_group'] as String,
              record: _toRecord(r),
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
    _guard('Failed to save the mapping: ', () {
      runInTransaction(_db, () {
        _db.execute(
          'UPDATE notifications SET tag = ?, at = ?, title = ?, registered_at = ? '
          'WHERE batch_id = ? AND alarm_id = ? AND $_currentRowPredicate',
          [
            record.tag,
            _atText(record),
            record.title,
            _registeredAtText(record),
            record.batchId,
            record.alarmId,
            ..._currentRowParams,
          ],
        );
        if (_db.updatedRows == 0) _insertRow(record, _NotifyStatus.current);
      });
    });
  }

  /// Replaces the current row of the key of [record] in one transaction and
  /// returns the id of the `replacement_queue` row it adds.
  ///
  /// When the current row is settled (`notify_status` 1), it becomes superseded (0)
  /// first, because the partial unique index `notifications_current` allows one
  /// current row per key. When it is pending (2, an unfinished earlier replacement),
  /// that replacement is cancelled: the pending row is deleted (its queue row goes
  /// with it by `ON DELETE CASCADE`) and the row it superseded stays superseded
  /// as the old row, so only the latest replacement remains queued.
  /// A new row is then inserted as pending (2), and (new id, old id) is queued.
  /// When there is no current row, a [StorageException] is thrown and nothing
  /// changes (the transaction rolls back). A [SqliteException] is thrown as a
  /// [StorageException].
  @override
  int replace(MappingRecord record) {
    return _guard(
      _replaceFailure,
      () => runInTransaction(_db, () {
        final int oldId = _takeOldRowId(record);
        _insertRow(record, _NotifyStatus.pending);
        _db.execute(
          'INSERT INTO replacement_queue (new_id, old_id) VALUES (?, ?)',
          [_db.lastInsertRowId, oldId],
        );
        return _db.lastInsertRowId;
      }),
    );
  }

  /// Completes the removal queued as [queueId] in one transaction: deletes the
  /// old row, so `ON DELETE SET NULL` clears `old_id` of the queue row (the queue
  /// row stays), and makes the new row current (`notify_status` 1).
  /// A [SqliteException] is thrown as a [StorageException].
  @override
  void completeRemoval(int queueId) {
    _guard(
      'Failed to complete the removal: ',
      () => runInTransaction(_db, () {
        _db.execute(
          'UPDATE notifications SET notify_status = ? '
          'WHERE id = (SELECT new_id FROM replacement_queue WHERE id = ?)',
          [_NotifyStatus.current.value, queueId],
        );
        _db.execute(
          'DELETE FROM notifications '
          'WHERE id = (SELECT old_id FROM replacement_queue WHERE id = ?)',
          [queueId],
        );
      }),
    );
  }

  /// Aborts the replacement queued as [queueId] in one transaction: deletes the
  /// new (pending) row, so `ON DELETE CASCADE` removes the queue row, and makes
  /// the old row current (`notify_status` 1) again. The new row goes first,
  /// because the partial unique index `notifications_current` allows one current
  /// or pending row per key. The old row id is read before that delete, as the
  /// cascade removes the queue row that holds it.
  ///
  /// Does nothing (no row changes, no exception) when [queueId] does not exist
  /// or its replacement is already completed (`old_id` is NULL, see
  /// [completeRemoval]): the new row is then the key's only current row. Only a
  /// pending new row (`notify_status` 2) is deleted.
  /// A [SqliteException] is thrown as a [StorageException].
  @override
  void abortReplacement(int queueId) {
    _guard(
      'Failed to abort the replacement: ',
      () => runInTransaction(_db, () {
        final int? oldId = _queuedOldId('id', queueId);
        if (oldId == null) return;
        _db.execute(
          'DELETE FROM notifications '
          'WHERE notify_status = ? '
          'AND id = (SELECT new_id FROM replacement_queue WHERE id = ?)',
          [_NotifyStatus.pending.value, queueId],
        );
        _db.execute('UPDATE notifications SET notify_status = ? WHERE id = ?', [
          _NotifyStatus.current.value,
          oldId,
        ]);
      }),
    );
  }

  /// Deletes, in one transaction, the `replacement_queue` rows whose `old_id` is
  /// NULL (the removal was finished by [completeRemoval]) and returns the number
  /// of deleted rows. Rows with an old row (unfinished replacements) are kept,
  /// as [pendingRemovals] and [abortReplacement] need them, and `notifications`
  /// is not touched. A [SqliteException] is thrown as a [StorageException].
  @override
  int purgeCompletedQueue() {
    return _guard(
      'Failed to purge the replacement queue: ',
      () => runInTransaction(_db, () {
        _db.execute('DELETE FROM replacement_queue WHERE old_id IS NULL');
        return _db.updatedRows;
      }),
    );
  }

  /// Returns `old_id` of the first `replacement_queue` row whose [column] equals
  /// [value], or null when there is no such row or its `old_id` is NULL.
  /// [column] is a fixed literal (`id` or `new_id`), never user input.
  int? _queuedOldId(String column, int value) => _db
      .select('SELECT old_id FROM replacement_queue WHERE $column = ?', [value])
      .map((Row r) => r['old_id'] as int?)
      .firstOrNull;

  /// Frees the current slot of the key of [record] for a new row and returns the
  /// id of the row to queue as the old one (see [replace]). Throws a
  /// [StorageException] when there is no current row. Must run inside a transaction.
  int _takeOldRowId(MappingRecord record) {
    final Row? current = _db.select(
      'SELECT id, notify_status FROM notifications '
      'WHERE batch_id = ? AND alarm_id = ? AND $_currentRowPredicate',
      [record.batchId, record.alarmId, ..._currentRowParams],
    ).firstOrNull;
    if (current == null) {
      throw StorageException(
        '${_replaceFailure}no current row for '
        '(${record.batchId}, ${record.alarmId})',
      );
    }
    final int currentId = current['id'] as int;
    return current['notify_status'] == _NotifyStatus.pending.value
        ? _cancelPending(currentId, record)
        : _supersede(currentId);
  }

  /// Settled branch of [_takeOldRowId]: marks the row [id] superseded and returns it.
  int _supersede(int id) {
    _db.execute('UPDATE notifications SET notify_status = ? WHERE id = ?', [
      _NotifyStatus.superseded.value,
      id,
    ]);
    return id;
  }

  /// Pending branch of [_takeOldRowId]: deletes the pending row [pendingId] and
  /// returns the old row it superseded. Throws a [StorageException] when the
  /// queue holds no old row for it.
  int _cancelPending(int pendingId, MappingRecord record) {
    final int? supersededId = _queuedOldId('new_id', pendingId);
    if (supersededId == null) {
      throw StorageException(
        '${_replaceFailure}pending row has no queued old row for '
        '(${record.batchId}, ${record.alarmId})',
      );
    }
    _db.execute('DELETE FROM notifications WHERE id = ?', [pendingId]);
    return supersededId;
  }

  /// Column text of `at`: saved as UTC.
  static String _atText(MappingRecord record) =>
      record.at.toUtc().toIso8601String();

  /// Column text of `registered_at`: saved as local time without an offset.
  static String _registeredAtText(MappingRecord record) =>
      record.registeredAt.toIso8601String();

  /// Inserts [record] as a new row with [notifyStatus]. Must run inside a transaction.
  void _insertRow(MappingRecord record, _NotifyStatus notifyStatus) {
    _db.execute(
      'INSERT INTO notifications '
      '(group_name, tag, batch_id, alarm_id, at, title, registered_at, notify_status) '
      'VALUES (?, ?, ?, ?, ?, ?, ?, ?)',
      [
        kGroup,
        record.tag,
        record.batchId,
        record.alarmId,
        _atText(record),
        record.title,
        _registeredAtText(record),
        notifyStatus.value,
      ],
    );
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
          [batchId, alarmId, ..._currentRowParams],
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
