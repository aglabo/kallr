// src: lib/store/__tests__/unit/schema.unit.spec.dart
// @(#) : unit tests for openDatabase (schema creation and database opening)
//
// Copyright (c) 2026 atsushifx <http://github.com/atsushifx>
//
// Released under the MIT License.
// https://opensource.org/licenses/MIT

// test framework
import 'dart:io';
import 'dart:typed_data';

import 'package:sqlite3/sqlite3.dart';
import 'package:test/test.dart';

// test target
import 'package:w1_w7_verify/errors.dart';
import 'package:w1_w7_verify/store/schema.dart';

// internal helpers

/// Size in bytes of one page of a DB created by SQLite with the default settings.
const int _sqlitePageSize = 4096;

/// Corrupt existing file forms: (title, writes the corrupt file to the given path).
///
/// - 01: 100 bytes of text that is not an SQLite file (the header check fails at the first query).
/// - 02: a real DB with a valid header whose pages after the first are overwritten,
///   so only `PRAGMA quick_check` finds it (implementation-schedule.md 2.3).
final List<(String, void Function(String path))> _corruptFileCases = [
  (
    '100 バイトの SQLite でない文字列のファイル',
    (String path) => File(path).writeAsBytesSync(
      List<int>.generate(
        100,
        (int i) => 'not an sqlite db. '.codeUnitAt(i % 18),
      ),
    ),
  ),
  (
    '先頭ヘッダーが正しく、2 ページ目以降を 0xFF で上書きしたファイル (quick_check でだけ見つかる)',
    (String path) {
      openDatabase(path).close();
      _rawExecute(
        path,
        "INSERT INTO settings (id, key, value) VALUES (1, 'machine_id', 'a1b2c3d4')",
      );
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

/// Creates a fresh temp directory, runs [body] with a DB path in it, then deletes it.
Future<void> _withDbPath(Future<void> Function(String path) body) async {
  final Directory dir = Directory.systemTemp.createTempSync('kallr_sch_');
  try {
    await body('${dir.path}${Platform.pathSeparator}mappings.sqlite3');
  } finally {
    dir.deleteSync(recursive: true);
  }
}

/// Runs one SQL statement on [path] through a raw connection, then closes it.
///
/// Precondition: [path] holds an SQLite file, and no connection holds a write on it.
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

/// Reads `PRAGMA user_version` of [path] through a raw connection.
///
/// Precondition: [path] holds an SQLite file, and no connection from [openDatabase] on it is open.
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
/// Precondition: [path] holds an SQLite file, and no connection from [openDatabase] on it is open.
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

void main() {
  // openDatabase: opens (creating if needed) the DB file and ensures the schema.
  group('T-WDV-SCH: openDatabase', () {
    group('Given: 存在しないパスの new.sqlite3 (SCH-R-027, 初回の利用)', () {
      group('When: 正常系 (openDatabase する)', () {
        test('[Normal] T-WDV-SCH-01: そのパスにファイルが作られる (SCH-R-027)', () async {
          await _withDbPath((String path) async {
            expect(File(path).existsSync(), isFalse);

            openDatabase(path).close();

            expect(File(path).existsSync(), isTrue);
          });
        });

        test(
          '[Normal] T-WDV-SCH-02: PRAGMA user_version が 1 になる (SCH-R-027)',
          () async {
            await _withDbPath((String path) async {
              expect(File(path).existsSync(), isFalse);

              openDatabase(path).close();

              expect(_readUserVersion(path), 1);
            });
          },
        );

        test('[Normal] T-WDV-SCH-03: notifications / replacement_queue / settings の 3 テーブルだけが作られる (SCH-R-027)', () async {
          await _withDbPath((String path) async {
            expect(File(path).existsSync(), isFalse);

            openDatabase(path).close();

            expect(_readTableNames(path), [
              'notifications',
              'replacement_queue',
              'settings',
            ]);
          });
        });
      });
    });

    group('Given: 開いた接続 (SCH-R-027, 接続ごとの設定)', () {
      group('When: 正常系 (PRAGMA foreign_keys を読む)', () {
        // PRAGMA foreign_keys is per connection, so it is read from the
        // connection openDatabase returns, not from a second connection.
        test('[Normal] T-WDV-SCH-06: 値が 1 (ON) である (SCH-R-027)', () async {
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

    group(
      'Given: 親ディレクトリ a/b/c が存在しないパス <tmp>/a/b/c/x.sqlite3 (SCH-R-029)',
      () {
        group('When: 正常系 (openDatabase する)', () {
          test(
            '[Normal] T-WDV-SCH-07: 例外を投げず、親ディレクトリと DB ファイルが作られる (SCH-R-029)',
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

                openDatabase(path).close();

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
        group('When: 正常系 (openDatabase する)', () {
          test('[Normal] T-WDV-SCH-04: 例外を投げず、PRAGMA user_version が 1 になる (SCH-R-027)', () async {
            await _withDbPath((String path) async {
              File(path).writeAsBytesSync(<int>[]);
              expect(File(path).lengthSync(), 0);

              openDatabase(path).close();

              expect(_readUserVersion(path), 1);
            });
          });

          test('[Normal] T-WDV-SCH-05: notifications / replacement_queue / settings の 3 テーブルが作られる (SCH-R-027)', () async {
            await _withDbPath((String path) async {
              File(path).writeAsBytesSync(<int>[]);
              expect(File(path).lengthSync(), 0);

              openDatabase(path).close();

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

    group('Given: 壊れた既存ファイル (SCH-R-027, SCH-E-20)', () {
      group('When: 異常系 (openDatabase する)', () {
        for (final (String title, void Function(String) prepare)
            in _corruptFileCases) {
          test(
            '[Error] T-WDV-SCH-08: $title は StorageException を投げる (SCH-R-027, SCH-E-20)',
            () async {
              await _withDbPath((String path) async {
                prepare(path);
                expect(
                  () => openDatabase(path),
                  throwsA(isA<StorageException>()),
                );
              });
            },
          );

          test(
            '[Error] T-WDV-SCH-09: $title は openDatabase が失敗しても作り直さず、バイト列・長さが同じで -journal / -wal / -shm も残らない (SCH-R-027, SCH-E-20)',
            () async {
              await _withDbPath((String path) async {
                prepare(path);
                final Uint8List before = File(path).readAsBytesSync();

                expect(
                  () => openDatabase(path),
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

    group(
      'Given: user_version が 2 (未定義の版) の正常な既存ファイル (db-migration.md 3.1)',
      () {
        group('When: 異常系 (openDatabase する)', () {
          test(
            '[Error] T-WDV-SCH-10: 版とパスを示す StorageException を投げる (SCH-R-027)',
            () async {
              await _withDbPath((String path) async {
                _createForeignVersionDb(path, 2);

                expect(
                  () => openDatabase(path),
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

          test('[Error] T-WDV-SCH-11: openDatabase が失敗してもバイト列・テーブル・版が同じで -journal / -wal / -shm も残らない (SCH-R-027)', () async {
            await _withDbPath((String path) async {
              _createForeignVersionDb(path, 2);
              final Uint8List before = File(path).readAsBytesSync();

              expect(
                () => openDatabase(path),
                throwsA(isA<StorageException>()),
              );

              expect(File(path).readAsBytesSync(), before);
              expect(_readTableNames(path), ['legacy']);
              expect(_readUserVersion(path), 2);
              expect(_siblingNames(path), ['mappings.sqlite3']);
            });
          });
        });
      },
    );

    group('Given: user_version が 0 で別のテーブル other がある既存ファイル (別のアプリの DB, db-migration.md 3.1)', () {
      group('When: 異常系 (openDatabase する)', () {
        test('[Error] T-WDV-SCH-12: テーブルがあるのに版が未設定なので、パスを示す StorageException を投げる (SCH-R-027)', () async {
          await _withDbPath((String path) async {
            _createForeignVersionDb(path, 0, table: 'other');

            expect(
              () => openDatabase(path),
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

        test('[Error] T-WDV-SCH-13: openDatabase が失敗してもバイト列・テーブル・版が同じで -journal / -wal / -shm も残らない (SCH-R-027)', () async {
          await _withDbPath((String path) async {
            _createForeignVersionDb(path, 0, table: 'other');
            final Uint8List before = File(path).readAsBytesSync();

            expect(() => openDatabase(path), throwsA(isA<StorageException>()));

            expect(File(path).readAsBytesSync(), before);
            expect(_readTableNames(path), ['other']);
            expect(_readUserVersion(path), 0);
            expect(_siblingNames(path), ['mappings.sqlite3']);
          });
        });
      });
    });

    group('Given: DB file whose settings table has no key column', () {
      group('When: 異常系 (openDatabase fails while creating the schema)', () {
        test('[Error] T-WDV-SCH-14: openDatabase throws StorageException and releases the file handle', () async {
          await _withDbPath((String path) async {
            // user_version 1: reach the DDL (version 0 with tables is rejected earlier).
            _rawExecute(path, 'PRAGMA user_version = 1');
            _rawExecute(path, 'CREATE TABLE settings (x TEXT)');

            expect(() => openDatabase(path), throwsA(isA<StorageException>()));

            // A leaked handle keeps the file locked on Windows. This assertion
            // can only fail on Windows (POSIX allows deleting open files).
            expect(() => File(path).deleteSync(), returnsNormally);
          });
        });
      });
    });

    group('Given: file whose bytes are not an SQLite database', () {
      group('When: 異常系 (openDatabase on the corrupt file)', () {
        test('[Error] T-WDV-SCH-15: openDatabase throws StorageException and leaves the file untouched', () async {
          await _withDbPath((String path) async {
            final List<int> corrupt = List.filled(200, 0x41);
            File(path).writeAsBytesSync(corrupt);

            expect(() => openDatabase(path), throwsA(isA<StorageException>()));

            expect(File(path).readAsBytesSync(), corrupt);
            // A leaked handle keeps the file locked on Windows. This assertion
            // can only fail on Windows (POSIX allows deleting open files).
            expect(() => File(path).deleteSync(), returnsNormally);
          });
        });
      });
    });
  });
}
