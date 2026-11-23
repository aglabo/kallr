// src: lib/store/transaction.dart
// @(#) : shared BEGIN ... COMMIT helper
//
// Copyright (c) 2026 atsushifx <http://github.com/atsushifx>
//
// Released under the MIT License.
// https://opensource.org/licenses/MIT

import 'package:sqlite3/sqlite3.dart';

/// Runs [body] between `BEGIN` and `COMMIT` on [db] and returns its result.
///
/// A [SqliteException] from `BEGIN` is thrown without a ROLLBACK: no
/// transaction was started, and a ROLLBACK could undo one that is already
/// open. Any exception from [body] or `COMMIT` rolls back and is rethrown
/// unchanged; a failing ROLLBACK is ignored so it cannot mask the original
/// error. Mapping to a [StorageException] is left to the caller.
T runInTransaction<T>(Database db, T Function() body) {
  db.execute('BEGIN');
  try {
    final T result = body();
    db.execute('COMMIT');
    return result;
  } catch (_) {
    _rollbackQuietly(db);
    rethrow;
  }
}

void _rollbackQuietly(Database db) {
  try {
    db.execute('ROLLBACK');
  } on SqliteException {
    // The original error is rethrown by the caller.
  }
}
