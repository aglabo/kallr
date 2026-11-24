// src: lib/store/__tests__/unit/sqlite_store.unit.spec.dart
// @(#) : unit tests for SqliteStore (MachineIdProvider)
//
// Copyright (c) 2026 atsushifx <http://github.com/atsushifx>
//
// Released under the MIT License.
// https://opensource.org/licenses/MIT

// test framework
import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:sqlite3/sqlite3.dart';
import 'package:test/fake.dart';
import 'package:test/test.dart';

// test target
import 'package:w1_w7_verify/errors.dart';
import 'package:w1_w7_verify/models.dart';
import 'package:w1_w7_verify/store/schema.dart';
import 'package:w1_w7_verify/store/sqlite_store.dart';

// internal helpers

/// Extended result code of a UNIQUE constraint violation (SQLITE_CONSTRAINT_UNIQUE).
const int _sqliteConstraintUnique = 2067;

/// Pattern of a machine id: 8 lowercase hex digits.
final RegExp _machineIdPattern = RegExp(r'^[0-9a-f]{8}$');

/// Invalid stored machine_id cases: (case id, title, stored value not matching 8 lowercase hex digits).
final List<(String, String, String)> _invalidStoredValueCases = [
  ('T-WDV-MID-09', '16 進以外の文字なら StorageException を投げる', 'zzzzzzzz'),
  ('T-WDV-MID-10', '7 桁なら StorageException を投げる', 'a1b2c3d'),
  ('T-WDV-MID-11', '大文字なら StorageException を投げる', 'A1B2C3D4'),
  ('T-WDV-MID-12', '9 桁なら StorageException を投げる', 'a1b2c3d4e'),
  ('T-WDV-MID-13', '空文字なら StorageException を投げる', ''),
  (
    'T-WDV-MID-26',
    '`/` を含む値 (`0` の直前の文字) なら StorageException を投げる',
    '0123456/',
  ),
  (
    'T-WDV-MID-27',
    '`:` を含む値 (`9` の直後の文字) なら StorageException を投げる',
    '0123456:',
  ),
  (
    'T-WDV-MID-28',
    'バッククォートを含む値 (`a` の直前の文字) なら StorageException を投げる',
    '0123456`',
  ),
  (
    'T-WDV-MID-29',
    '`g` を含む値 (`f` の直後の文字) なら StorageException を投げる',
    '0123456g',
  ),
  ('T-WDV-MID-44', '末尾に改行がある値なら StorageException を投げる', 'a1b2c3d4\n'),
];

/// Boundary stored machine_id cases that are valid: (case id, title, stored value).
final List<(String, String, String)> _boundaryStoredValueCases = [
  ('T-WDV-MID-23', '全ゼロ `00000000` は有効な値として返す', '00000000'),
  ('T-WDV-MID-24', '最大値 `ffffffff` は有効な値として返す', 'ffffffff'),
  ('T-WDV-MID-25', 'digit/letter seam `89abcdef` は有効な値として返す', '89abcdef'),
];

/// Save-failure cases (fake Database): (case id, title, SQL prefix -> failure
/// thrown, expected write path after the first call, matcher of the thrown error).
final List<(String, String, Map<String, Object>, List<String>, Matcher)>
_saveFailureCases = [
  (
    'T-WDV-MID-33',
    'INSERT throws StateError: rolls back and rethrows it unchanged, returns no value and caches nothing (TAG-R-009, IDX-DD-01)',
    {'INSERT': StateError('insert bug')},
    ['BEGIN', 'INSERT', 'ROLLBACK'],
    isA<StateError>().having(
      (StateError e) => e.message,
      'message',
      'insert bug',
    ),
  ),
  (
    'T-WDV-MID-34',
    'INSERT throws SqliteException while ROLLBACK also fails: throws the INSERT failure as StorageException, not the ROLLBACK failure, returns no value and caches nothing (TAG-R-009, IDX-DD-01)',
    {
      'INSERT': _blocked('insert blocked'),
      'ROLLBACK': _blocked('rollback blocked'),
    },
    ['BEGIN', 'INSERT', 'ROLLBACK'],
    isA<StorageException>().having(
      (StorageException e) => e.message,
      'message',
      allOf(
        contains('insert blocked'),
        contains('save machine_id'),
        isNot(contains('rollback blocked')),
      ),
    ),
  ),
  (
    'T-WDV-MID-35',
    'BEGIN throws SqliteException: throws StorageException without INSERT, ROLLBACK or COMMIT, returns no value and caches nothing (TAG-R-009, IDX-DD-01)',
    {'BEGIN': _blocked('begin blocked')},
    // The transaction never started: nothing to roll back, since a ROLLBACK
    // could undo another transaction that is already open.
    ['BEGIN'],
    isA<StorageException>().having(
      (StorageException e) => e.message,
      'message',
      allOf(contains('save machine_id'), contains('begin blocked')),
    ),
  ),
  (
    'T-WDV-MID-36',
    'INSERT throws StateError while ROLLBACK also fails: rethrows the StateError unchanged, not the ROLLBACK failure, returns no value and caches nothing (TAG-R-009, IDX-DD-01)',
    {
      'INSERT': StateError('insert bug'),
      'ROLLBACK': _blocked('rollback blocked'),
    },
    ['BEGIN', 'INSERT', 'ROLLBACK'],
    isA<StateError>().having(
      (StateError e) => e.message,
      'message',
      'insert bug',
    ),
  ),
  (
    'T-WDV-MID-37',
    'COMMIT throws SqliteException: rolls back and throws StorageException with the SQLite message, returns no value and caches nothing (TAG-R-009, IDX-DD-01)',
    {'COMMIT': _blocked('commit blocked')},
    ['BEGIN', 'INSERT', 'COMMIT', 'ROLLBACK'],
    isA<StorageException>().having(
      (StorageException e) => e.message,
      'message',
      allOf(contains('save machine_id'), contains('commit blocked')),
    ),
  ),
  (
    'T-WDV-MID-38',
    'COMMIT throws StateError: rolls back and rethrows it unchanged, returns no value and caches nothing (TAG-R-009, IDX-DD-01)',
    {'COMMIT': StateError('commit bug')},
    ['BEGIN', 'INSERT', 'COMMIT', 'ROLLBACK'],
    isA<StateError>().having(
      (StateError e) => e.message,
      'message',
      'commit bug',
    ),
  ),
];

/// Sample [MappingRecord] shared by the MappingTable cases (tasks-schedule.md T-05).
MappingRecord _sampleRecord({
  String batchId = 'b1',
  String alarmId = 'a1',
  String tag = '20261122090000-a1b2c3d4-0123456789abcdef',
  String at = '2026-11-22T12:00:00+09:00',
  String title = 't1',
}) => MappingRecord(
  batchId: batchId,
  alarmId: alarmId,
  tag: tag,
  at: DateTime.parse(at),
  title: title,
  registeredAt: DateTime.parse('2026-11-22T09:00:00'),
);

/// Second record for the same key (b1, a1) as [_sampleRecord]: other tag, at and title.
MappingRecord _overwritingRecord() => _sampleRecord(
  tag: '20261122090000-a1b2c3d4-fedcba9876543210',
  at: '2026-11-23T08:30:00+09:00',
  title: 't2',
);

/// Record for the key (b1, a2): a different alarm of the same batch as [_sampleRecord].
MappingRecord _otherKeyRecord() => _sampleRecord(
  alarmId: 'a2',
  tag: '20261122090000-a1b2c3d4-aaaaaaaaaaaaaaaa',
  at: '2026-11-24T10:00:00+09:00',
  title: 't3',
);

/// Record for the key (b2, a2) that reuses the Tag of [_sampleRecord] (UNIQUE (group_name, tag) violation).
MappingRecord _duplicateTagRecord() =>
    _sampleRecord(batchId: 'b2', alarmId: 'a2', title: 't4');

/// Record whose batchId is the empty string (rejected by `CHECK (batch_id <> '')`).
MappingRecord _emptyBatchIdRecord() => _sampleRecord(batchId: '');

/// Record whose alarmId is the empty string (rejected by `CHECK (alarm_id <> '')`).
MappingRecord _emptyAlarmIdRecord() => _sampleRecord(alarmId: '');

/// Record whose Tag is 39 ASCII characters (rejected by `CHECK (length(tag) = 40)`).
MappingRecord _shortTagRecord() => _sampleRecord(tag: 'a' * 39);

/// Record whose Tag is 41 ASCII characters (rejected by `CHECK (length(tag) = 40)`).
MappingRecord _longTagRecord() => _sampleRecord(tag: 'a' * 41);

/// Size in bytes of one page of a DB created by SQLite with the default settings.
const int _sqlitePageSize = 4096;

/// Corrupt existing file forms: (open-fails case id, file-kept case id, title, writes the corrupt file to the given path).
///
/// - 01: 100 bytes of text that is not an SQLite file (the header check fails at the first query).
/// - 02: a real DB with a valid header whose pages after the first are overwritten,
///   so only `PRAGMA quick_check` finds it (implementation-schedule.md 2.3).
final List<(String, String, String, void Function(String path))>
_corruptFileCases = [
  (
    'T-WDV-MAP-29-01',
    'T-WDV-MAP-30-01',
    '100 バイトの SQLite でない文字列のファイル',
    (String path) => File(path).writeAsBytesSync(
      List<int>.generate(
        100,
        (int i) => 'not an sqlite db. '.codeUnitAt(i % 18),
      ),
    ),
  ),
  (
    'T-WDV-MAP-29-02',
    'T-WDV-MAP-30-02',
    '先頭ヘッダーが正しく、2 ページ目以降を 0xFF で上書きしたファイル (quick_check でだけ見つかる)',
    (String path) {
      _openWithStoredRow(path, 1, 'a1b2c3d4').close();
      final Uint8List bytes = File(path).readAsBytesSync();
      expect(bytes.length, greaterThan(_sqlitePageSize));
      File(
        path,
      ).writeAsBytesSync(bytes..fillRange(_sqlitePageSize, bytes.length, 0xff));
    },
  ),
];

/// Lists the sorted names of the entries in the directory of [path] (detects `-journal` / `-wal` / `-shm` leftovers).
List<String> _siblingNames(String path) =>
    (Directory(File(path).parent.path)
        .listSync()
        .map(
          (FileSystemEntity e) =>
              e.uri.pathSegments.where((String s) => s.isNotEmpty).last,
        )
        .toList()
      ..sort());

/// Creates a valid SQLite file at [path] with one table and one row, then sets `PRAGMA user_version`.
///
/// Precondition: [path] does not exist yet. The connection is closed before returning.
/// - [path]: the DB file path.
/// - [version]: the value stored in `user_version`.
/// - [table]: the name of the only table (default `legacy`).
void _createForeignVersionDb(
  String path,
  int version, {
  String table = 'legacy',
}) {
  final Database db = sqlite3.open(path);
  try {
    db.execute('CREATE TABLE $table (id INTEGER PRIMARY KEY, note TEXT)');
    db.execute("INSERT INTO $table (note) VALUES ('keep me')");
    db.execute('PRAGMA user_version = $version');
  } finally {
    db.close();
  }
}

/// Matcher for the [StorageException] thrown by a failed `put` (its message names the save).
final Matcher _throwsSaveFailure = throwsA(
  isA<StorageException>().having(
    (StorageException e) => e.message,
    'message',
    contains('Failed to save the mapping'),
  ),
);

/// Creates a fresh temp directory, runs [body] with a DB path in it, then deletes it.
Future<void> _withDbPath(Future<void> Function(String path) body) async {
  final Directory dir = Directory.systemTemp.createTempSync('kallr_mid_');
  try {
    await body('${dir.path}${Platform.pathSeparator}mappings.sqlite3');
  } finally {
    dir.deleteSync(recursive: true);
  }
}

/// Opens a store on [path], runs [body] with it, and always closes the store.
///
/// Precondition: [path] is a DB file path that no raw connection holds locked.
/// The store is closed in a `finally`, so it is closed even when [body] throws
/// (on Windows an open store keeps the file locked and blocks deleting the
/// temp dir). Read the table back with a raw connection AFTER this returns.
///
/// [path] is the DB file path.
/// [body] receives the opened store; it may be sync or async.
/// [open] opens the store (default [SqliteStore.open]); pass
/// `(p) => _openWithStoredRow(p, id, value)` to start from a stored row.
/// Returns the value [body] returned.
Future<T> _withStore<T>(
  String path,
  FutureOr<T> Function(SqliteStore store) body, {
  SqliteStore Function(String path)? open,
}) async {
  final SqliteStore store = (open ?? SqliteStore.open)(path);
  try {
    return await body(store);
  } finally {
    store.close();
  }
}

/// Creates the schema, inserts a `machine_id` row with [rowId] directly, and
/// returns the opened store. Every intermediate Database is closed.
SqliteStore _openWithStoredRow(String path, int rowId, String value) {
  SqliteStore.open(path).close();
  final Database db = sqlite3.open(path);
  try {
    db.execute(
      "INSERT INTO settings (id, key, value) VALUES (?, 'machine_id', ?)",
      [rowId, value],
    );
  } finally {
    db.close();
  }
  return SqliteStore.open(path);
}

/// Runs one SQL statement on [path] through a raw connection, then closes it.
///
/// Precondition: [path] holds an SQLite file, and no [SqliteStore] write is in
/// progress on it. Used to prepare or change stored rows behind the store's back.
/// - [path]: the DB file path.
/// - [sql]: one statement, with no parameters.
///
/// Returns when the statement has run and the connection is closed. A failing
/// statement throws [SqliteException] (the connection is still closed).
void _rawExecute(String path, String sql) {
  final Database db = sqlite3.open(path);
  try {
    db.execute(sql);
  } finally {
    db.close();
  }
}

/// Shows [value] with its line breaks as `\n` / `\r` so it fits on one line of a test name.
///
/// Precondition: none; any string is accepted.
/// - [value]: the text to show.
///
/// Returns [value] with each `\n` and `\r` replaced by its two-character escape.
String _escaped(String value) =>
    value.replaceAll('\r', r'\r').replaceAll('\n', r'\n');

/// Reads all `settings` rows as (id, key, value) triples.
List<List<Object?>> _readSettings(String path) {
  final Database db = sqlite3.open(path);
  try {
    return db
        .select('SELECT id, key, value FROM settings ORDER BY id')
        .map((Row r) => <Object?>[r['id'], r['key'], r['value']])
        .toList();
  } finally {
    db.close();
  }
}

/// Reads `PRAGMA user_version` of [path] through a raw connection.
///
/// Precondition: [path] holds an SQLite file, and no store on it is open.
int _readUserVersion(String path) {
  final Database db = sqlite3.open(path);
  try {
    return db.select('PRAGMA user_version').single['user_version'] as int;
  } finally {
    db.close();
  }
}

/// Reads the sorted names of the tables in [path] through a raw connection.
///
/// Precondition: [path] holds an SQLite file, and no store on it is open.
/// Internal tables (`sqlite_sequence` etc.) are excluded.
List<String> _readTableNames(String path) {
  final Database db = sqlite3.open(path);
  try {
    return db
        .select(
          "SELECT name FROM sqlite_master WHERE type = 'table' "
          "AND name NOT LIKE 'sqlite_%' ORDER BY name",
        )
        .map((Row r) => r['name'] as String)
        .toList();
  } finally {
    db.close();
  }
}

/// Reads [column] of the only `notifications` row.
///
/// Precondition: [path] holds a DB with exactly one `notifications` row, and no
/// store on it is open. [column] is a trusted column name of the test.
Object? _readNotificationColumn(String path, String column) {
  final Database db = sqlite3.open(path);
  try {
    return db.select('SELECT $column FROM notifications').single[column];
  } finally {
    db.close();
  }
}

/// Reads every `notifications` row as (batch_id, alarm_id, tag, at, title,
/// registered_at) tuples, ordered by id, through a raw connection.
///
/// Precondition: [path] holds a DB with the schema; the store on it holds no open
/// transaction (a read is blocked only by an uncommitted write).
List<(String, String, String, String, String, String)> _readNotificationRows(
  String path,
) {
  final Database db = sqlite3.open(path, mode: OpenMode.readOnly);
  try {
    return db
        .select(
          'SELECT batch_id, alarm_id, tag, at, title, registered_at '
          'FROM notifications ORDER BY id',
        )
        .map(
          (Row r) => (
            r['batch_id'] as String,
            r['alarm_id'] as String,
            r['tag'] as String,
            r['at'] as String,
            r['title'] as String,
            r['registered_at'] as String,
          ),
        )
        .toList();
  } finally {
    db.close();
  }
}

/// Asserts that a stored non-text `machine_id` value is rejected and kept.
///
/// Precondition: [path] holds a DB whose `settings` has exactly one
/// `machine_id` row with a non-text value, and no store on it is open.
/// Opens the store, expects `machineId()` to throw a [StorageException] twice
/// (nothing cached) whose message names the text expectation and the runtime
/// type, closes the store, then reads the row back with a raw connection.
///
/// [path] is the DB file path.
/// [expectedType] is the SQLite `typeof(value)` of the stored row.
/// [expectedTypeInMessage] is the Dart runtime type the message must name.
/// [expectedHex] is the `hex(value)` the row must still hold (checked if given).
/// Returns when every assertion has passed.
Future<void> _expectInvalidNonTextValue(
  String path, {
  required String expectedType,
  required String expectedTypeInMessage,
  String? expectedHex,
}) async {
  await _withStore(path, (SqliteStore store) {
    expect(
      () => store.machineId(),
      throwsA(
        isA<StorageException>().having(
          (StorageException e) => e.message,
          'message',
          allOf(
            contains('Stored machine_id is invalid'),
            contains('expected text but found $expectedTypeInMessage'),
          ),
        ),
      ),
    );
    expect(() => store.machineId(), throwsA(isA<StorageException>()));
  });

  final Database check = sqlite3.open(path);
  try {
    final ResultSet rows = check.select(
      "SELECT typeof(value) AS t, hex(value) AS h FROM settings WHERE key = 'machine_id'",
    );
    expect(rows.length, 1);
    expect(rows.single['t'], expectedType);
    if (expectedHex != null) {
      expect(rows.single['h'], expectedHex);
    }
    expect(check.select('SELECT id FROM settings').length, 1);
  } finally {
    check.close();
  }
}

/// Extracts the write path from the SQL recorded by a [_FakeDatabase].
///
/// Precondition: [_FakeDatabase.executedSql] holds the SQL strings in call
/// order. Statements before the first `BEGIN` are dropped and every
/// `INSERT ...` statement is collapsed to `INSERT`.
///
/// [fake] is the fake Database whose recorded SQL is inspected.
/// Returns the normalized statements from `BEGIN` onward.
List<String> _writePath(_FakeDatabase fake) => fake.executedSql
    .skipWhile((String s) => s != 'BEGIN')
    .map((String s) => s.startsWith('INSERT') ? 'INSERT' : s)
    .toList();

/// Builds the [SqliteException] a [_FakeDatabase] failure throws.
///
/// Precondition: none.
/// - [message]: the exception message the code under test copies into its [StorageException].
///
/// Returns an [SqliteException] with a generic error code (1).
SqliteException _blocked(String message) =>
    SqliteException(extendedResultCode: 1, message: message);

/// Builds a [_FakeDatabase.failOn] function from a map of SQL prefix to the
/// object to throw.
///
/// The first entry whose key is a prefix of the SQL decides; no match means
/// the statement succeeds.
///
/// [bySql] maps an SQL prefix (`SELECT`, `BEGIN`, `INSERT`, `ROLLBACK`, ...)
/// to the failure thrown for it.
/// Returns the function to pass as `failOn`.
Object? Function(String) _failOn(Map<String, Object> bySql) =>
    (String sql) => bySql.entries
        .where((MapEntry<String, Object> e) => sql.startsWith(e.key))
        .map((MapEntry<String, Object> e) => e.value)
        .firstOrNull;

/// Hand-written fake [Database]: only [execute] and [select] are implemented
/// (any other call fails via [Fake]). Records every SQL string in
/// [executedSql].
///
/// [failOn] is called with every SQL string after it is recorded; a non-null
/// result is thrown, null means the statement succeeds. Without [failOn]
/// everything succeeds and [select] returns no `machine_id` row.
class _FakeDatabase extends Fake implements Database {
  _FakeDatabase({this.failOn});

  /// Decides per SQL string whether to throw (see the class doc).
  final Object? Function(String sql)? failOn;

  /// Every SQL string passed to [execute] or [select], in call order.
  final List<String> executedSql = [];

  @override
  void execute(String sql, [List<Object?> parameters = const []]) {
    executedSql.add(sql);
    final Object? failure = failOn?.call(sql);
    if (failure != null) {
      throw failure;
    }
  }

  @override
  ResultSet select(String sql, [List<Object?> parameters = const []]) {
    executedSql.add(sql);
    final Object? failure = failOn?.call(sql);
    if (failure != null) {
      throw failure;
    }
    return ResultSet(['value'], [null], []);
  }
}

void main() {
  // SqliteStore as MappingTable: stores notifications and reads them back.
  group('T-WDV-MAP: MappingTable', () {
    group('Given: 空の対応表に put した後 (SCH-R-025)', () {
      group('When: 正常系 (get(b1, a1) を呼ぶ)', () {
        test('[Normal] T-WDV-MAP-01: put した項目を同じ値のまま返す (SCH-R-025)', () async {
          await _withDbPath((String path) async {
            final MappingRecord? found = await _withStore(path, (
              SqliteStore store,
            ) {
              store.put(_sampleRecord());
              return store.get('b1', 'a1');
            });

            expect(found, _sampleRecord());
          });
        });
      });
    });

    group('Given: title が 会議の開始 の項目 (SCH-E-23)', () {
      group('When: 正常系 (put して get(b1, a1) を呼ぶ)', () {
        test(
          '[Normal] T-WDV-MAP-06: UTF-8 の title をそのまま返す (SCH-E-23)',
          () async {
            await _withDbPath((String path) async {
              final MappingRecord? found = await _withStore(path, (
                SqliteStore store,
              ) {
                store.put(_sampleRecord(title: '会議の開始'));
                return store.get('b1', 'a1');
              });

              expect(found!.title, '会議の開始');
            });
          },
        );
      });
    });

    group('Given: 新規の項目 (SCH-DD-02)', () {
      group('When: 正常系 (put する)', () {
        test('[Normal] T-WDV-MAP-05: notifications.group_name に kallr を入れる (SCH-DD-02)', () async {
          await _withDbPath((String path) async {
            await _withStore(
              path,
              (SqliteStore store) => store.put(_sampleRecord()),
            );

            expect(_readNotificationColumn(path, 'group_name'), 'kallr');
          });
        });
      });
    });

    group(
      'Given: registeredAt が 2026-11-22T09:00:00 (ローカル) の項目 (SCH-DD-04)',
      () {
        group('When: 正常系 (put して get(b1, a1) を呼ぶ)', () {
          test('[Normal] T-WDV-MAP-04: registered_at をオフセット無しのローカル日時で保存し、ローカルのまま返す (SCH-DD-04)', () async {
            await _withDbPath((String path) async {
              final MappingRecord? found = await _withStore(path, (
                SqliteStore store,
              ) {
                store.put(_sampleRecord());
                return store.get('b1', 'a1');
              });

              expect(
                _readNotificationColumn(path, 'registered_at'),
                '2026-11-22T09:00:00.000',
              );
              expect(found!.registeredAt.isUtc, isFalse);
            });
          });
        });
      },
    );

    group('Given: at が 2026-11-22T12:00:00+09:00 の項目を put した (SCH-DD-02)', () {
      group('When: 正常系 (get(b1, a1) を呼ぶ)', () {
        test('[Normal] T-WDV-MAP-03: 返した at は 2026-11-22T03:00:00Z と同じ瞬間になる (SCH-DD-02)', () async {
          await _withDbPath((String path) async {
            final MappingRecord? found = await _withStore(path, (
              SqliteStore store,
            ) {
              store.put(_sampleRecord());
              return store.get('b1', 'a1');
            });

            expect(
              found!.at.isAtSameMomentAs(DateTime.utc(2026, 11, 22, 3)),
              isTrue,
            );
          });
        });
      });
    });

    group('Given: at が 2026-11-22T12:00:00+09:00 の項目 (SCH-DD-02)', () {
      group('When: 正常系 (put する)', () {
        test('[Normal] T-WDV-MAP-02: notifications.at を UTC の ISO 8601 で保存する (SCH-DD-02)', () async {
          await _withDbPath((String path) async {
            await _withStore(
              path,
              (SqliteStore store) => store.put(_sampleRecord()),
            );

            expect(
              _readNotificationColumn(path, 'at'),
              '2026-11-22T03:00:00.000Z',
            );
          });
        });
      });
    });

    group(
      'Given: b1 / a1 を put 済みで、同じキーに別の tag・at・title で put する (SCH-R-025)',
      () {
        group('When: 正常系 (get(b1, a1) を呼ぶ)', () {
          test('[Normal] T-WDV-MAP-07: 2 回目の値で上書きされる (SCH-R-025)', () async {
            await _withDbPath((String path) async {
              final MappingRecord? found = await _withStore(path, (
                SqliteStore store,
              ) {
                store.put(_sampleRecord());
                store.put(_overwritingRecord());
                return store.get('b1', 'a1');
              });

              expect(found, _overwritingRecord());
            });
          });
        });
      },
    );

    group('Given: b1 / a1 を put 済みで notifications.id を控えた (SCH-R-025)', () {
      group('When: 正常系 (同じキーに別の tag で put する)', () {
        test(
          '[Normal] T-WDV-MAP-08: 上書きでも notifications.id は変わらない (SCH-R-025)',
          () async {
            await _withDbPath((String path) async {
              await _withStore(path, (SqliteStore store) {
                store.put(_sampleRecord());
              });
              final Object? idBefore = _readNotificationColumn(path, 'id');

              await _withStore(
                path,
                (SqliteStore store) => store.put(_overwritingRecord()),
              );

              expect(_readNotificationColumn(path, 'id'), idBefore);
            });
          },
        );
      });
    });

    group('Given: 同じキー b1 / a1 に 2 回 put した (SCH-R-025)', () {
      group('When: 正常系 (all() を呼ぶ)', () {
        test('[Normal] T-WDV-MAP-09: 有効な項目は 1 つだけである (SCH-R-025)', () async {
          await _withDbPath((String path) async {
            final List<MappingRecord> records = await _withStore(path, (
              SqliteStore store,
            ) {
              store.put(_sampleRecord());
              store.put(_overwritingRecord());
              return store.all();
            });

            expect(records, hasLength(1));
          });
        });
      });
    });

    group('Given: b1 / a1 を put 済み', () {
      group('When: 正常系 (remove(b1, a1) を呼ぶ)', () {
        test('[Normal] T-WDV-MAP-10: remove した項目は get で引けない', () async {
          await _withDbPath((String path) async {
            final MappingRecord? found = await _withStore(path, (
              SqliteStore store,
            ) {
              store.put(_sampleRecord());
              store.remove('b1', 'a1');
              return store.get('b1', 'a1');
            });

            expect(found, isNull);
          });
        });

        test('[Normal] T-WDV-MAP-11: remove した項目は all に含まれない', () async {
          await _withDbPath((String path) async {
            final List<MappingRecord> records = await _withStore(path, (
              SqliteStore store,
            ) {
              store.put(_sampleRecord());
              store.remove('b1', 'a1');
              return store.all();
            });

            expect(records, isEmpty);
          });
        });
      });
    });

    group('Given: 異なるキー b1 / a1 と b1 / a2 を put 済み', () {
      group('When: 正常系 (all() を呼ぶ)', () {
        test('[Normal] T-WDV-MAP-12: 2 件の MappingRecord を返す', () async {
          await _withDbPath((String path) async {
            final List<MappingRecord> records = await _withStore(path, (
              SqliteStore store,
            ) {
              store.put(_sampleRecord());
              store.put(_otherKeyRecord());
              return store.all();
            });

            expect(
              records,
              unorderedEquals([_sampleRecord(), _otherKeyRecord()]),
            );
          });
        });
      });

      group('When: 正常系 (tags() を呼ぶ)', () {
        test('[Normal] T-WDV-MAP-13: 2 件の Tag を含む Set を返す', () async {
          await _withDbPath((String path) async {
            final Set<String> tags = await _withStore(path, (
              SqliteStore store,
            ) {
              store.put(_sampleRecord());
              store.put(_otherKeyRecord());
              return store.tags();
            });

            expect(tags, {_sampleRecord().tag, _otherKeyRecord().tag});
          });
        });
      });
    });

    group('Given: 存在しないパスの new.sqlite3 (SCH-R-027, 初回の利用)', () {
      group('When: 正常系 (SqliteStore.open する)', () {
        test('[Normal] T-WDV-MAP-14: そのパスにファイルが作られる (SCH-R-027)', () async {
          await _withDbPath((String path) async {
            expect(File(path).existsSync(), isFalse);

            await _withStore(path, (SqliteStore store) {});

            expect(File(path).existsSync(), isTrue);
          });
        });

        test(
          '[Normal] T-WDV-MAP-15: PRAGMA user_version が 1 になる (SCH-R-027)',
          () async {
            await _withDbPath((String path) async {
              expect(File(path).existsSync(), isFalse);

              await _withStore(path, (SqliteStore store) {});

              expect(_readUserVersion(path), 1);
            });
          },
        );

        test('[Normal] T-WDV-MAP-16: notifications / replacement_queue / settings の 3 テーブルだけが作られる (SCH-R-027)', () async {
          await _withDbPath((String path) async {
            expect(File(path).existsSync(), isFalse);

            await _withStore(path, (SqliteStore store) {});

            expect(_readTableNames(path), [
              'notifications',
              'replacement_queue',
              'settings',
            ]);
          });
        });

        test(
          '[Normal] T-WDV-MAP-17: 空の対応表として始まり all() は空のリストを返す (SCH-R-027)',
          () async {
            await _withDbPath((String path) async {
              expect(File(path).existsSync(), isFalse);

              final List<MappingRecord> records = await _withStore(
                path,
                (SqliteStore store) => store.all(),
              );

              expect(records, isEmpty);
            });
          },
        );
      });
    });

    group('Given: b1 / a1 を put して閉じた正常な既存ファイル (SCH-R-027)', () {
      group('When: 正常系 (同じパスを SqliteStore.open して get(b1, a1) を呼ぶ)', () {
        test('[Normal] T-WDV-MAP-18: put した項目と等しい MappingRecord を返し、user_version は 1 のままになる (SCH-R-027)', () async {
          await _withDbPath((String path) async {
            await _withStore(
              path,
              (SqliteStore store) => store.put(_sampleRecord()),
            );
            // The first store is closed by _withStore: the file exists on disk.
            expect(File(path).existsSync(), isTrue);

            final MappingRecord? found = await _withStore(
              path,
              (SqliteStore store) => store.get('b1', 'a1'),
            );

            expect(found, _sampleRecord());
            expect(_readUserVersion(path), 1);
          });
        });
      });
    });

    group('Given: 開いた接続 (SCH-R-027, 接続ごとの設定)', () {
      group('When: 正常系 (PRAGMA foreign_keys を読む)', () {
        // SqliteStore.open returns openDatabase's connection unchanged and keeps it
        // private; PRAGMA foreign_keys is per connection, so it is read from the
        // connection openDatabase returns, not from a second connection.
        test('[Normal] T-WDV-MAP-19: 値が 1 (ON) である (SCH-R-027)', () async {
          await _withDbPath((String path) async {
            final Database db = openDatabase(path);
            try {
              expect(
                db.select('PRAGMA foreign_keys').single['foreign_keys'],
                1,
              );
            } finally {
              db.close();
            }
          });
        });
      });
    });

    group('Given: --db 相当の指定パス <tmp>/custom/x.sqlite3 (親ディレクトリあり) (SCH-R-029, SCH-E-26, SCH-DD-12)', () {
      group('When: 正常系 (SqliteStore.open して b1 / a1 を put する)', () {
        test('[Normal] T-WDV-MAP-20: 指定したパスのファイルに項目が保存され、他の DB ファイルは作られない (SCH-R-029, SCH-E-26, SCH-DD-12)', () async {
          final Directory tmp = Directory.systemTemp.createTempSync(
            'kallr_db_',
          );
          try {
            final Directory custom = Directory(
              '${tmp.path}${Platform.pathSeparator}custom',
            )..createSync();
            final String path =
                '${custom.path}${Platform.pathSeparator}x.sqlite3';

            await _withStore(
              path,
              (SqliteStore store) => store.put(_sampleRecord()),
            );

            // A raw connection (not the store) sees the row in the file at [path].
            final Database raw = sqlite3.open(path, mode: OpenMode.readOnly);
            try {
              expect(
                raw
                    .select('SELECT batch_id, alarm_id FROM notifications')
                    .map((Row r) => (r['batch_id'], r['alarm_id']))
                    .toList(),
                [('b1', 'a1')],
              );
            } finally {
              raw.close();
            }
            // The whole temp tree holds only the specified file.
            expect(
              tmp
                  .listSync(recursive: true)
                  .whereType<File>()
                  .map((File f) => f.path)
                  .toList(),
              [path],
            );
          } finally {
            tmp.deleteSync(recursive: true);
          }
        });
      });
    });

    group(
      'Given: 親ディレクトリ a/b/c が存在しないパス <tmp>/a/b/c/x.sqlite3 (SCH-R-029)',
      () {
        group('When: 正常系 (SqliteStore.open する)', () {
          test(
            '[Normal] T-WDV-MAP-39: 例外を投げず、親ディレクトリと DB ファイルが作られる (SCH-R-029)',
            () async {
              final Directory tmp = Directory.systemTemp.createTempSync(
                'kallr_db_',
              );
              try {
                final String sep = Platform.pathSeparator;
                final Directory parent = Directory(
                  '${tmp.path}${sep}a${sep}b${sep}c',
                );
                final String path = '${parent.path}${sep}x.sqlite3';
                expect(parent.existsSync(), isFalse);

                await _withStore(path, (SqliteStore store) {});

                expect(parent.existsSync(), isTrue);
                expect(File(path).existsSync(), isTrue);
              } finally {
                tmp.deleteSync(recursive: true);
              }
            },
          );
        });
      },
    );

    group(
      'Given: DB パスに 0 バイトの既存ファイルがある (db-migration.md 3.1: empty -> initial)',
      () {
        group('When: 正常系 (SqliteStore.open する)', () {
          test('[Normal] T-WDV-MAP-41: 例外を投げず、PRAGMA user_version が 1 になる (SCH-R-027)', () async {
            await _withDbPath((String path) async {
              File(path).writeAsBytesSync(<int>[]);
              expect(File(path).lengthSync(), 0);

              await _withStore(path, (SqliteStore store) {});

              expect(_readUserVersion(path), 1);
            });
          });

          test('[Normal] T-WDV-MAP-42: notifications / replacement_queue / settings の 3 テーブルが作られる (SCH-R-027)', () async {
            await _withDbPath((String path) async {
              File(path).writeAsBytesSync(<int>[]);
              expect(File(path).lengthSync(), 0);

              await _withStore(path, (SqliteStore store) {});

              expect(_readTableNames(path), [
                'notifications',
                'replacement_queue',
                'settings',
              ]);
            });
          });
        });
      },
    );

    group('Given: b1 / a1 が Tag T1 を持つ状態 (SCH-R-025, SCH-R-026)', () {
      group('When: 異常系 (b2 / a2 を同じ Tag T1 で put する)', () {
        test(
          '[Error] T-WDV-MAP-21: StorageException を投げる (SCH-R-025, SCH-R-026)',
          () async {
            await _withDbPath((String path) async {
              await _withStore(path, (SqliteStore store) {
                store.put(_sampleRecord());

                expect(
                  () => store.put(_duplicateTagRecord()),
                  throwsA(isA<StorageException>()),
                );
              });
            });
          },
        );
      });

      group('When: 異常系 (b2 / a2 を同じ Tag T1 で put して失敗した後)', () {
        test('[Error] T-WDV-MAP-22: b1 / a1 の行は全項目そのままで b2 / a2 の行は作られず、続けて有効な put ができる (SCH-R-026)', () async {
          await _withDbPath((String path) async {
            await _withStore(path, (SqliteStore store) {
              store.put(_sampleRecord());
              final rowsBefore = _readNotificationRows(path);

              expect(
                () => store.put(_duplicateTagRecord()),
                throwsA(isA<StorageException>()),
              );

              expect(store.get('b1', 'a1'), _sampleRecord());
              expect(store.get('b2', 'a2'), isNull);
              expect(store.all(), [_sampleRecord()]);
              expect(_readNotificationRows(path), rowsBefore);
              expect(rowsBefore.length, 1);

              // The failed put left no open transaction: a valid put succeeds.
              final MappingRecord valid = _sampleRecord(
                batchId: 'b2',
                alarmId: 'a2',
                tag: '20261122090000-a1b2c3d4-bbbbbbbbbbbbbbbb',
              );
              store.put(valid);
              expect(store.all(), unorderedEquals([_sampleRecord(), valid]));
            });
          });
        });
      });
    });

    group('Given: batchId が空文字の項目 (仕様 3.3 の制約)', () {
      group('When: 異常系 (put する)', () {
        test(
          '[Error] T-WDV-MAP-23: StorageException を投げる (SCH-R-026)',
          () async {
            await _withDbPath((String path) async {
              await _withStore(path, (SqliteStore store) {
                expect(
                  () => store.put(_emptyBatchIdRecord()),
                  _throwsSaveFailure,
                );
              });
            });
          },
        );
      });

      group('When: 異常系 (put して失敗した後)', () {
        test(
          '[Error] T-WDV-MAP-24: all() が空で、notifications に行は作られない (SCH-R-026)',
          () async {
            await _withDbPath((String path) async {
              await _withStore(path, (SqliteStore store) {
                expect(
                  () => store.put(_emptyBatchIdRecord()),
                  _throwsSaveFailure,
                );

                expect(store.all(), isEmpty);
              });
              expect(_readNotificationRows(path), isEmpty);
            });
          },
        );
      });
    });

    group('Given: alarmId が空文字の項目 (仕様 3.3 の制約)', () {
      group('When: 異常系 (put する)', () {
        test(
          '[Error] T-WDV-MAP-25: StorageException を投げる (SCH-R-026)',
          () async {
            await _withDbPath((String path) async {
              await _withStore(path, (SqliteStore store) {
                expect(
                  () => store.put(_emptyAlarmIdRecord()),
                  _throwsSaveFailure,
                );
              });
            });
          },
        );
      });

      group('When: 異常系 (put して失敗した後)', () {
        test(
          '[Error] T-WDV-MAP-26: all() が空で、notifications に行は作られない (SCH-R-026)',
          () async {
            await _withDbPath((String path) async {
              await _withStore(path, (SqliteStore store) {
                expect(
                  () => store.put(_emptyAlarmIdRecord()),
                  _throwsSaveFailure,
                );

                expect(store.all(), isEmpty);
              });
              expect(_readNotificationRows(path), isEmpty);
            });
          },
        );
      });
    });

    group('Given: Tag が 39 文字の項目 (db-migration.md 2.2 の CHECK)', () {
      group('When: 異常系 (put する)', () {
        test(
          '[Error] T-WDV-MAP-27: StorageException を投げる (SCH-R-026)',
          () async {
            await _withDbPath((String path) async {
              await _withStore(path, (SqliteStore store) {
                expect(() => store.put(_shortTagRecord()), _throwsSaveFailure);
              });
            });
          },
        );
      });
    });

    group('Given: Tag が 41 文字の項目 (db-migration.md 2.2 の CHECK)', () {
      group('When: 異常系 (put する)', () {
        test(
          '[Error] T-WDV-MAP-28: StorageException を投げる (SCH-R-026)',
          () async {
            await _withDbPath((String path) async {
              await _withStore(path, (SqliteStore store) {
                expect(() => store.put(_longTagRecord()), _throwsSaveFailure);
              });
            });
          },
        );
      });
    });

    group('Given: 壊れた既存ファイル (SCH-R-027, SCH-E-20)', () {
      group('When: 異常系 (open する)', () {
        for (final (
              String throwsId,
              String keptId,
              String title,
              void Function(String) prepare,
            )
            in _corruptFileCases) {
          test(
            '[Error] $throwsId: $title は StorageException を投げる (SCH-R-027, SCH-E-20)',
            () async {
              await _withDbPath((String path) async {
                prepare(path);
                expect(
                  () => SqliteStore.open(path),
                  throwsA(isA<StorageException>()),
                );
              });
            },
          );

          test(
            '[Error] $keptId: $title は open が失敗しても作り直さず、バイト列・長さが同じで -journal / -wal / -shm も残らない (SCH-R-027, SCH-E-20)',
            () async {
              await _withDbPath((String path) async {
                prepare(path);
                final Uint8List before = File(path).readAsBytesSync();

                expect(
                  () => SqliteStore.open(path),
                  throwsA(isA<StorageException>()),
                );

                expect(File(path).existsSync(), isTrue);
                expect(File(path).readAsBytesSync(), before);
                expect(_siblingNames(path), ['mappings.sqlite3']);
              });
            },
          );
        }
      });
    });

    group('Given: user_version が 2 (未定義の版) の正常な既存ファイル (db-migration.md 3.1)', () {
      group('When: 異常系 (open する)', () {
        test(
          '[Error] T-WDV-MAP-31-01: 版とパスを示す StorageException を投げる (SCH-R-027)',
          () async {
            await _withDbPath((String path) async {
              _createForeignVersionDb(path, 2);

              expect(
                () => SqliteStore.open(path),
                throwsA(
                  isA<StorageException>().having(
                    (StorageException e) => e.message,
                    'message',
                    allOf(contains('2'), contains(path)),
                  ),
                ),
              );
            });
          },
        );

        test('[Error] T-WDV-MAP-32-01: open が失敗してもバイト列・テーブル・版が同じで -journal / -wal / -shm も残らない (SCH-R-027)', () async {
          await _withDbPath((String path) async {
            _createForeignVersionDb(path, 2);
            final Uint8List before = File(path).readAsBytesSync();

            expect(
              () => SqliteStore.open(path),
              throwsA(isA<StorageException>()),
            );

            expect(File(path).readAsBytesSync(), before);
            expect(_readTableNames(path), ['legacy']);
            expect(_readUserVersion(path), 2);
            expect(_siblingNames(path), ['mappings.sqlite3']);
          });
        });
      });
    });

    group('Given: user_version が 0 で別のテーブル other がある既存ファイル (別のアプリの DB, db-migration.md 3.1)', () {
      group('When: 異常系 (open する)', () {
        test('[Error] T-WDV-MAP-33-01: テーブルがあるのに版が未設定なので、パスを示す StorageException を投げる (SCH-R-027)', () async {
          await _withDbPath((String path) async {
            _createForeignVersionDb(path, 0, table: 'other');

            expect(
              () => SqliteStore.open(path),
              throwsA(
                isA<StorageException>().having(
                  (StorageException e) => e.message,
                  'message',
                  contains(path),
                ),
              ),
            );
          });
        });

        test('[Error] T-WDV-MAP-34-01: open が失敗してもバイト列・テーブル・版が同じで -journal / -wal / -shm も残らない (SCH-R-027)', () async {
          await _withDbPath((String path) async {
            _createForeignVersionDb(path, 0, table: 'other');
            final Uint8List before = File(path).readAsBytesSync();

            expect(
              () => SqliteStore.open(path),
              throwsA(isA<StorageException>()),
            );

            expect(File(path).readAsBytesSync(), before);
            expect(_readTableNames(path), ['other']);
            expect(_readUserVersion(path), 0);
            expect(_siblingNames(path), ['mappings.sqlite3']);
          });
        });
      });
    });

    group('Given: b1 / a1 だけ put 済み (存在しないキーの remove)', () {
      group('When: エッジケース (remove(b9, a9) を呼ぶ)', () {
        test('[Edge] T-WDV-MAP-35-01: 例外を投げず正常に戻る', () async {
          await _withDbPath((String path) async {
            await _withStore(path, (SqliteStore store) {
              store.put(_sampleRecord());
              expect(store.get('b1', 'a1'), _sampleRecord());

              expect(() => store.remove('b9', 'a9'), returnsNormally);
            });
          });
        });

        test('[Edge] T-WDV-MAP-36-01: b1 / a1 は get・all・notifications の行とも全項目そのままで、batchId だけ・alarmId だけが一致するキーの remove でも変わらない', () async {
          await _withDbPath((String path) async {
            late final List<(String, String, String, String, String, String)>
            rowsBefore;
            await _withStore(path, (SqliteStore store) {
              store.put(_sampleRecord());
              rowsBefore = _readNotificationRows(path);

              // b9/a9: neither field matches; b1/a9: only batchId; b9/a1: only alarmId.
              store.remove('b9', 'a9');
              store.remove('b1', 'a9');
              store.remove('b9', 'a1');

              expect(store.get('b1', 'a1'), _sampleRecord());
              expect(store.all(), [_sampleRecord()]);
            });

            expect(rowsBefore, hasLength(1));
            expect(_readNotificationRows(path), rowsBefore);
          });
        });
      });
    });

    group(
      'Given: b1 / a1 が Tag T1 で put 済み (同じキー・同じ Tag で title だけ変えて put)',
      () {
        group('When: エッジケース (同じ Tag のまま title を t2 にして put する)', () {
          test('[Edge] T-WDV-MAP-40-01: 自分自身の Tag との重複は UNIQUE 違反にならず、get の title が t2 になる', () async {
            await _withDbPath((String path) async {
              await _withStore(path, (SqliteStore store) {
                store.put(_sampleRecord());

                expect(
                  () => store.put(_sampleRecord(title: 't2')),
                  returnsNormally,
                );
                expect(store.get('b1', 'a1'), _sampleRecord(title: 't2'));
              });
            });
          });
        });
      },
    );

    group('Given: 何も put していない対応表', () {
      group('When: エッジケース (all() を呼ぶ)', () {
        test('[Edge] T-WDV-MAP-37-01: 空のリストを返す', () async {
          await _withDbPath((String path) async {
            await _withStore(path, (SqliteStore store) {
              expect(store.all(), equals(<MappingRecord>[]));
            });
          });
        });
      });

      group('When: エッジケース (tags() を呼ぶ)', () {
        test('[Edge] T-WDV-MAP-38-01: 空の Set を返す', () async {
          await _withDbPath((String path) async {
            await _withStore(path, (SqliteStore store) {
              expect(store.tags(), equals(<String>{}));
            });
          });
        });
      });
    });
  });

  // SqliteStore.machineId: generates, saves, reads back and caches the machine
  // id in the settings table, and reports read/save failures as StorageException.
  group('T-WDV-MID: machineId', () {
    group('Given: new DB whose settings has no machine_id row', () {
      group('When: 正常系 (machineId is called for the first time)', () {
        test('[Normal] T-WDV-MID-01: returns 8 lowercase hex digits and saves it (TAG-R-009)', () async {
          await _withDbPath((String path) async {
            final String id = await _withStore(
              path,
              (SqliteStore store) => store.machineId(),
            );

            expect(id, matches(_machineIdPattern));
            expect(_readSettings(path), [
              [1, 'machine_id', id],
            ]);
          });
        });

        test('[Normal] T-WDV-MID-02: stores the value as exactly one machine_id row (TAG-R-009, TAG-DD-03, IDX-DD-01)', () async {
          await _withDbPath((String path) async {
            final String id = await _withStore(
              path,
              (SqliteStore store) => store.machineId(),
            );

            final Database db = sqlite3.open(path);
            try {
              final ResultSet rows = db.select(
                "SELECT value FROM settings WHERE key = 'machine_id'",
              );
              expect(rows.map((Row r) => r['value']).toList(), [id]);
            } finally {
              db.close();
            }
          });
        });

        test('[Normal] T-WDV-MID-42: every one of 256 generated ids is 8 lowercase hex digits and they are not all the same (TAG-R-009)', () {
          final List<String> ids = List<String>.generate(256, (_) {
            final SqliteStore store = SqliteStore.open(':memory:');
            try {
              return store.machineId();
            } finally {
              store.close();
            }
          });

          expect(ids, hasLength(256));
          expect(ids, everyElement(matches(_machineIdPattern)));
          expect(ids.toSet().length, greaterThan(1));
        });
      });
    });

    group('Given: DB whose settings already has a machine_id row', () {
      group('When: 正常系 (machineId is called)', () {
        test('[Normal] T-WDV-MID-03: returns the stored value and creates no new value (TAG-R-008)', () async {
          await _withDbPath((String path) async {
            final String id = await _withStore(
              path,
              (SqliteStore store) => store.machineId(),
              open: (String p) => _openWithStoredRow(p, 1, 'a1b2c3d4'),
            );

            expect(id, 'a1b2c3d4');
            expect(_readSettings(path), [
              [1, 'machine_id', 'a1b2c3d4'],
            ]);
          });
        });

        test('[Normal] T-WDV-MID-04: reads the value by key when the row id is not 1', () async {
          await _withDbPath((String path) async {
            final String id = await _withStore(
              path,
              (SqliteStore store) => store.machineId(),
              open: (String p) => _openWithStoredRow(p, 42, 'a1b2c3d4'),
            );

            expect(id, 'a1b2c3d4');
          });
        });
      });
    });

    group('Given: DB whose settings holds a boundary machine_id value', () {
      group('When: 正常系 (machineId is called)', () {
        for (final (caseId, title, stored) in _boundaryStoredValueCases) {
          test(
            '[Normal] $caseId: $title ("${_escaped(stored)}", TAG-R-010)',
            () async {
              await _withDbPath((String path) async {
                final String id = await _withStore(
                  path,
                  (SqliteStore store) => store.machineId(),
                  open: (String p) => _openWithStoredRow(p, 1, stored),
                );

                expect(id, stored);
              });
            },
          );
        }
      });
    });

    group('Given: temp-file DB whose machineId was obtained and the store was closed', () {
      group('When: 正常系 (the DB is reopened at the same path and machineId is called)', () {
        test('[Normal] T-WDV-MID-06: returns the same value as the first call and keeps a single row (TAG-R-008, AC-011)', () async {
          await _withDbPath((String path) async {
            final String v1 = await _withStore(
              path,
              (SqliteStore store) => store.machineId(),
            );
            final String v2 = await _withStore(
              path,
              (SqliteStore store) => store.machineId(),
            );

            expect(v1, matches(_machineIdPattern));
            expect(v2, v1);
            // Both stores are closed: still exactly one row, same value.
            expect(_readSettings(path), [
              [1, 'machine_id', v1],
            ]);
          });
        });
      });
    });

    group('Given: new temp-file DB and one SqliteStore instance', () {
      group('When: 正常系 (machineId is called twice on the same instance)', () {
        test(
          '[Normal] T-WDV-MID-07: returns equal values (impl §3 step 4)',
          () async {
            await _withDbPath((String path) async {
              final (String v1, String v2) = await _withStore(
                path,
                (SqliteStore store) => (store.machineId(), store.machineId()),
              );

              expect(v1, matches(_machineIdPattern));
              expect(v2, v1);
            });
          },
        );

        test('[Normal] T-WDV-MID-08: serves the second call from the instance cache even if the stored row changes (impl §3 step 4)', () async {
          await _withDbPath((String path) async {
            await _withStore(path, (SqliteStore store) {
              final String v1 = store.machineId();

              _rawExecute(
                path,
                "UPDATE settings SET value = 'ffffffff' WHERE key = 'machine_id'",
              );

              expect(_readSettings(path).single[2], 'ffffffff');
              expect(store.machineId(), v1);
            });
          });
        });

        test('[Normal] T-WDV-MID-43: serves the second call from the instance cache after reading a stored value (impl §3 step 4)', () async {
          await _withDbPath((String path) async {
            await _withStore(path, (SqliteStore store) {
              expect(store.machineId(), 'a1b2c3d4');

              _rawExecute(
                path,
                "UPDATE settings SET value = 'ffffffff' WHERE key = 'machine_id'",
              );

              expect(_readSettings(path).single[2], 'ffffffff');
              expect(store.machineId(), 'a1b2c3d4');
            }, open: (String p) => _openWithStoredRow(p, 1, 'a1b2c3d4'));
          });
        });
      });
    });

    group('Given: a fresh DB whose machine id was already generated', () {
      group('When: 正常系 (machineId is called once more)', () {
        test('[Normal] T-WDV-MID-30: the settings table still holds exactly one machine_id row (TAG-R-008)', () async {
          await _withDbPath((String path) async {
            final (String v1, String v2) = await _withStore(
              path,
              (SqliteStore store) => (store.machineId(), store.machineId()),
            );

            expect(v1, matches(_machineIdPattern));
            expect(v2, v1);
            expect(_readSettings(path), [
              [1, 'machine_id', v1],
            ]);
          });
        });
      });
    });

    group('Given: DB whose settings holds an invalid machine_id value', () {
      group('When: 異常系 (machineId is called)', () {
        for (final (id, title, stored) in _invalidStoredValueCases) {
          test(
            '[Error] $id: $title ("${_escaped(stored)}", TAG-R-010)',
            () async {
              await _withDbPath((String path) async {
                await _withStore(path, (SqliteStore store) {
                  expect(
                    () => store.machineId(),
                    throwsA(isA<StorageException>()),
                  );
                }, open: (String p) => _openWithStoredRow(p, 1, stored));
              });
            },
          );
        }
      });
    });

    group('Given: DB whose settings holds machine_id "zzzzzzzz" and machineId() threw StorageException', () {
      group('When: 異常系 (the state after the failed call is inspected)', () {
        test('[Error] T-WDV-MID-14: leaves the existing row unchanged and adds no row (TAG-R-010, TAG-DD-04)', () async {
          await _withDbPath((String path) async {
            await _withStore(path, (SqliteStore store) {
              expect(() => store.machineId(), throwsA(isA<StorageException>()));
            }, open: (String p) => _openWithStoredRow(p, 1, 'zzzzzzzz'));

            expect(_readSettings(path), [
              [1, 'machine_id', 'zzzzzzzz'],
            ]);
          });
        });

        test('[Error] T-WDV-MID-15: does not cache the invalid value, so a repaired row is read on the next call (TAG-R-010)', () async {
          await _withDbPath((String path) async {
            await _withStore(path, (SqliteStore store) {
              expect(() => store.machineId(), throwsA(isA<StorageException>()));

              _rawExecute(
                path,
                "UPDATE settings SET value = 'a1b2c3d4' WHERE key = 'machine_id'",
              );

              expect(store.machineId(), 'a1b2c3d4');
            }, open: (String p) => _openWithStoredRow(p, 1, 'zzzzzzzz'));
          });
        });
      });
    });

    group('Given: DB whose settings holds machine_id as a BLOB (hex 6131623263336434)', () {
      group('When: 異常系 (machineId is called)', () {
        test('[Error] T-WDV-MID-39: throws StorageException, keeps the BLOB row and caches nothing (TAG-R-010, TAG-DD-04)', () async {
          await _withDbPath((String path) async {
            SqliteStore.open(path).close();
            _rawExecute(
              path,
              "INSERT INTO settings (key, value) VALUES ('machine_id', x'6131623263336434')",
            );

            await _expectInvalidNonTextValue(
              path,
              expectedType: 'blob',
              expectedTypeInMessage: 'Uint8List',
              expectedHex: '6131623263336434',
            );
          });
        });
      });
    });

    group('Given: existing nullable settings table whose machine_id value is NULL', () {
      group('When: 異常系 (machineId is called)', () {
        test('[Error] T-WDV-MID-40: throws StorageException, keeps the NULL row and caches nothing (TAG-R-010, TAG-DD-04)', () async {
          await _withDbPath((String path) async {
            // The table exists before open, so CREATE TABLE IF NOT EXISTS keeps
            // this nullable `value` column. user_version 1 marks it as this
            // code's own database (version 0 with tables is rejected).
            _rawExecute(path, 'PRAGMA user_version = 1');
            _rawExecute(
              path,
              'CREATE TABLE settings (id INTEGER PRIMARY KEY AUTOINCREMENT, key TEXT NOT NULL, value TEXT)',
            );
            _rawExecute(
              path,
              'CREATE UNIQUE INDEX settings_key ON settings(key)',
            );
            _rawExecute(
              path,
              "INSERT INTO settings (key, value) VALUES ('machine_id', NULL)",
            );

            await _expectInvalidNonTextValue(
              path,
              expectedType: 'null',
              expectedTypeInMessage: 'Null',
            );
          });
        });
      });
    });

    group("Given: DB whose settings holds machine_id as TEXT that is not valid UTF-8 (CAST(x'ff' AS TEXT))", () {
      group('When: 異常系 (machineId is called)', () {
        test('[Error] T-WDV-MID-41: throws StorageException, keeps the row and caches nothing (TAG-R-010, TAG-DD-04)', () async {
          await _withDbPath((String path) async {
            SqliteStore.open(path).close();
            _rawExecute(
              path,
              "INSERT INTO settings (key, value) VALUES ('machine_id', CAST(x'ff' AS TEXT))",
            );

            await _withStore(path, (SqliteStore store) {
              expect(
                () => store.machineId(),
                throwsA(
                  isA<StorageException>().having(
                    (StorageException e) => e.message,
                    'message',
                    allOf(
                      contains('Stored machine_id is invalid'),
                      contains('not valid UTF-8'),
                    ),
                  ),
                ),
              );
              expect(() => store.machineId(), throwsA(isA<StorageException>()));
            });

            // Read back without decoding the text: selecting `value` itself
            // would throw a FormatException.
            final Database check = sqlite3.open(path);
            try {
              final ResultSet row = check.select(
                "SELECT typeof(value) AS t, hex(value) AS h FROM settings WHERE key = 'machine_id'",
              );
              expect(row, hasLength(1));
              expect(row.first['t'], 'text');
              expect(row.first['h'], 'FF');
              expect(
                check.select('SELECT count(*) AS n FROM settings').first['n'],
                1,
              );
            } finally {
              check.close();
            }
          });
        });
      });
    });

    group('Given: settings has no machine_id row and the INSERT fails (fake Database)', () {
      group('When: 異常系 (machineId is called)', () {
        test('[Error] T-WDV-MID-17: throws StorageException, returns no value and caches nothing (TAG-R-009)', () {
          final _FakeDatabase fake = _FakeDatabase(
            failOn: _failOn({'INSERT': _blocked('insert blocked')}),
          );
          final SqliteStore store = SqliteStore.fromDatabase(fake);

          expect(() => store.machineId(), throwsA(isA<StorageException>()));

          // Nothing was cached: the second call looks up and inserts again.
          fake.executedSql.clear();
          expect(() => store.machineId(), throwsA(isA<StorageException>()));
          expect(fake.executedSql.first, contains('SELECT'));
          expect(
            fake.executedSql.any((String s) => s.startsWith('INSERT')),
            isTrue,
          );
        });

        // Fake Database: this checks the transaction handling (ROLLBACK issued,
        // COMMIT never issued), not the contents of the real table.
        test('[Error] T-WDV-MID-18: rolls back and never commits after the failed INSERT (transaction handling, IDX-DD-01)', () {
          final _FakeDatabase fake = _FakeDatabase(
            failOn: _failOn({'INSERT': _blocked('insert blocked')}),
          );
          final SqliteStore store = SqliteStore.fromDatabase(fake);

          expect(() => store.machineId(), throwsA(isA<StorageException>()));

          expect(_writePath(fake), ['BEGIN', 'INSERT', 'ROLLBACK']);
        });
      });
    });

    group('Given: settings has no machine_id row and a write step fails (fake Database)', () {
      group('When: 異常系 (machineId is called)', () {
        for (final (id, title, fails, path, thrown) in _saveFailureCases) {
          test('[Error] $id: $title', () {
            final _FakeDatabase fake = _FakeDatabase(failOn: _failOn(fails));
            final SqliteStore store = SqliteStore.fromDatabase(fake);

            expect(() => store.machineId(), throwsA(thrown));

            expect(_writePath(fake), path);

            // Nothing was cached: the second call begins a new transaction.
            expect(() => store.machineId(), throwsA(thrown));
            expect(
              fake.executedSql.where((String s) => s == 'BEGIN'),
              hasLength(2),
            );
          });
        }
      });
    });

    group('Given: the machine_id SELECT fails (fake Database)', () {
      group('When: 異常系 (machineId is called)', () {
        test('[Error] T-WDV-MID-31: throws StorageException with the SQLite message, saves nothing and caches nothing (TAG-R-010, TAG-DD-04)', () {
          final _FakeDatabase fake = _FakeDatabase(
            failOn: _failOn({'SELECT': _blocked('read blocked')}),
          );
          final SqliteStore store = SqliteStore.fromDatabase(fake);

          expect(
            () => store.machineId(),
            throwsA(
              isA<StorageException>().having(
                (StorageException e) => e.message,
                'message',
                allOf(contains('read machine_id'), contains('read blocked')),
              ),
            ),
          );
          expect(
            fake.executedSql.any(
              (String s) => s == 'BEGIN' || s.startsWith('INSERT'),
            ),
            isFalse,
          );

          // The failure is not cached: the second call reads again and fails.
          fake.executedSql.clear();
          expect(() => store.machineId(), throwsA(isA<StorageException>()));
          expect(fake.executedSql, hasLength(1));
        });
      });
    });

    group('Given: DB file whose settings table has no key column', () {
      group('When: 異常系 (SqliteStore.open fails while creating the schema)', () {
        test('[Error] T-WDV-MID-05: open throws StorageException and releases the file handle', () async {
          await _withDbPath((String path) async {
            // user_version 1: reach the DDL (version 0 with tables is rejected earlier).
            _rawExecute(path, 'PRAGMA user_version = 1');
            _rawExecute(path, 'CREATE TABLE settings (x TEXT)');

            expect(
              () => SqliteStore.open(path),
              throwsA(isA<StorageException>()),
            );

            // A leaked handle keeps the file locked on Windows. This assertion
            // can only fail on Windows (POSIX allows deleting open files).
            expect(() => File(path).deleteSync(), returnsNormally);
          });
        });
      });
    });

    group('Given: file whose bytes are not an SQLite database', () {
      group('When: 異常系 (SqliteStore.open on the corrupt file)', () {
        test('[Error] T-WDV-MID-16: open throws StorageException and leaves the file untouched', () async {
          await _withDbPath((String path) async {
            final List<int> corrupt = List.filled(200, 0x41);
            File(path).writeAsBytesSync(corrupt);

            expect(
              () => SqliteStore.open(path),
              throwsA(isA<StorageException>()),
            );

            expect(File(path).readAsBytesSync(), corrupt);
            // A leaked handle keeps the file locked on Windows. This assertion
            // can only fail on Windows (POSIX allows deleting open files).
            expect(() => File(path).deleteSync(), returnsNormally);
          });
        });
      });
    });

    group('Given: settings already has a machine_id row', () {
      group(
        'When: 異常系 (a second row with the same key machine_id is INSERTed)',
        () {
          test('[Error] T-WDV-MID-19: the INSERT is rejected by the unique constraint on settings.key and one row remains', () async {
            await _withDbPath((String path) async {
              SqliteStore.open(path).close();
              final Database db = sqlite3.open(path);
              try {
                db.execute(
                  "INSERT INTO settings (key, value) VALUES ('machine_id', 'a1b2c3d4')",
                );

                expect(
                  () => db.execute(
                    "INSERT INTO settings (key, value) VALUES ('machine_id', 'b2c3d4e5')",
                  ),
                  throwsA(
                    isA<SqliteException>().having(
                      (SqliteException e) => e.extendedResultCode,
                      'extendedResultCode',
                      _sqliteConstraintUnique,
                    ),
                  ),
                );
              } finally {
                db.close();
              }

              final List<List<Object?>> rows = _readSettings(path);
              expect(rows, hasLength(1));
              expect(rows.single[1], 'machine_id');
              expect(rows.single[2], 'a1b2c3d4');
            });
          });
        },
      );
    });

    group('Given: settings holds only other settings (no machine_id row)', () {
      /// Creates the schema, inserts the `other` row, calls [SqliteStore.machineId]
      /// on a reopened store and returns the id and the table read back.
      Future<(String, List<List<Object?>>)> generateAndRead(String path) async {
        SqliteStore.open(path).close();
        final Database db = sqlite3.open(path);
        try {
          db.execute("INSERT INTO settings (key, value) VALUES ('other', 'x')");
        } finally {
          db.close();
        }

        final String id = await _withStore(
          path,
          (SqliteStore store) => store.machineId(),
        );
        return (id, _readSettings(path));
      }

      group('When: 正常系 (machineId is called)', () {
        test('[Normal] T-WDV-MID-20: a new machine id is generated and saved as a machine_id row', () async {
          await _withDbPath((String path) async {
            final (String id, List<List<Object?>> rows) = await generateAndRead(
              path,
            );

            expect(id, matches(_machineIdPattern));
            expect(rows, hasLength(2));
            expect(
              rows.map((List<Object?> r) => r[1]),
              containsAll(['other', 'machine_id']),
            );
            expect(
              rows.singleWhere((List<Object?> r) => r[1] == 'machine_id')[2],
              id,
            );
          });
        });

        test(
          '[Normal] T-WDV-MID-21: the other row is left unchanged',
          () async {
            await _withDbPath((String path) async {
              final (_, List<List<Object?>> rows) = await generateAndRead(path);

              final List<Object?> other = rows.singleWhere(
                (List<Object?> r) => r[1] == 'other',
              );
              expect(other, [1, 'other', 'x']);
            });
          },
        );
      });
    });

    group('Given: the database file was deleted after the first machineId()', () {
      group(
        'When: 正常系 (SqliteStore.open at the same path and machineId is called)',
        () {
          test('[Normal] T-WDV-MID-22: a new machine id is generated and saved (TAG-DD-04)', () async {
            await _withDbPath((String path) async {
              await _withStore(path, (SqliteStore store) => store.machineId());

              for (final String suffix in ['', '-journal', '-wal', '-shm']) {
                final File file = File('$path$suffix');
                if (file.existsSync()) {
                  file.deleteSync();
                }
              }

              final String v2 = await _withStore(
                path,
                (SqliteStore store) => store.machineId(),
              );

              expect(v2, matches(_machineIdPattern));
              expect(_readSettings(path), [
                [1, 'machine_id', v2],
              ]);
            });
          });
        },
      );
    });

    group('Given: a store wrapping an open in-memory Database', () {
      group('When: 正常系 (close is called once)', () {
        test('[Normal] T-WDV-MID-45: the underlying Database is closed and can no longer be used', () {
          final Database db = sqlite3.openInMemory();
          final SqliteStore store = SqliteStore.fromDatabase(db);

          store.close();

          expect(() => db.select('SELECT 1'), throwsStateError);
        });
      });
    });
  });
}
