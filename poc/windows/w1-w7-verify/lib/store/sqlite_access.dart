// src: lib/store/sqlite_access.dart
// @(#) : SQL execution base layer: SqliteException conversion and transactions
//
// Copyright (c) 2026 atsushifx <http://github.com/atsushifx>
//
// Released under the MIT License.
// https://opensource.org/licenses/MIT

/// cspell:words rethrowing

import 'package:sqlite3/sqlite3.dart';

import '../errors.dart';

/// Base layer over a [Database]: runs SQL and converts [SqliteException].
///
/// It knows no table, column or value type. It takes ownership of the
/// database ([close] closes it).
final class SqliteAccess {
  SqliteAccess(this._db);

  final Database _db;

  /// Runs [action], rethrowing a [SqliteException] as a [StorageException]
  /// whose message is [failurePrefix] followed by the SQLite message.
  /// Other exceptions pass through unchanged.
  T guard<T>(String failurePrefix, T Function() action) {
    try {
      return action();
    } on SqliteException catch (e) {
      throw StorageException('$failurePrefix${e.message}');
    }
  }

  /// Closes the underlying database.
  void close() => _db.close();
}
