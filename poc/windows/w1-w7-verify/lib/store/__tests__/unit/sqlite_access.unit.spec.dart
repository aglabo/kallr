// src: lib/store/__tests__/unit/sqlite_access.unit.spec.dart
// @(#) : unit tests for SqliteAccess (SQL execution base layer)
//
// Copyright (c) 2026 atsushifx <http://github.com/atsushifx>
//
// Released under the MIT License.
// https://opensource.org/licenses/MIT

import 'dart:io';

// test framework
import 'package:sqlite3/sqlite3.dart';
import 'package:test/test.dart';

// test target
import 'package:w1_w7_verify/errors.dart';
import 'package:w1_w7_verify/store/sqlite_access.dart';

void main() {
  group('SqliteAccess', () {
    late SqliteAccess access;

    setUp(() => access = SqliteAccess(sqlite3.openInMemory()));
    tearDown(() => access.close());

    group('T-WDV-SQA: guard', () {
      group('Given: 成功する action (T-19-01)', () {
        group('When: 正常系 (guard(p: , action) を呼ぶ)', () {
          test('[Normal] T-WDV-SQA-01: action の戻り値をそのまま返す', () {
            expect(access.guard('p: ', () => 42), 42);
          });
        });
      });

      group('Given: 存在しないテーブルを SELECT する action (T-19)', () {
        group('When: 異常系 (guard(p: , action) を呼ぶ)', () {
          int failingAction() =>
              access.select('SELECT a FROM missing', const <Object?>[]).length;

          test('[Abnormal] T-WDV-SQA-07: StorageException を投げる', () {
            expect(
              () => access.guard('p: ', failingAction),
              throwsA(isA<StorageException>()),
            );
          });

          test(
            '[Abnormal] T-WDV-SQA-08: メッセージは prefix の後ろに SQLite のメッセージが続く',
            () {
              expect(
                () => access.guard('p: ', failingAction),
                throwsA(
                  isA<StorageException>().having(
                    (StorageException e) => e.message,
                    'message',
                    allOf(startsWith('p: '), contains('no such table')),
                  ),
                ),
              );
            },
          );
        });
      });
    });

    group('T-WDV-SQA: guard (passthrough)', () {
      group('Given: StateError を投げる action (T-19-07)', () {
        group('When: 異常系 (guard(p: , action) を呼ぶ)', () {
          test(
            '[Abnormal] T-WDV-SQA-09: StorageException に変換せず StateError のまま投げる',
            () {
              expect(
                () => access.guard<int>('p: ', () => throw StateError('boom')),
                throwsA(isA<StateError>()),
              );
            },
          );
        });
      });
    });

    group('T-WDV-SQA: transact', () {
      group('Given: 1 行を INSERT して 42 を返す body (T-19-02)', () {
        group('When: 正常系 (transact(p: , body) を呼ぶ)', () {
          test('[Normal] T-WDV-SQA-02: body の戻り値を返す', () {
            final Database db = sqlite3.openInMemory()
              ..execute('CREATE TABLE t (v INTEGER)');
            final SqliteAccess a = SqliteAccess(db);
            addTearDown(a.close);

            expect(
              a.transact('p: ', () {
                db.execute('INSERT INTO t (v) VALUES (1)');
                return 42;
              }),
              42,
            );
          });

          test('[Normal] T-WDV-SQA-03: 変更が確定し、別の接続から読める', () {
            final Directory dir = Directory.systemTemp.createTempSync('sqa_');
            addTearDown(() => dir.deleteSync(recursive: true));
            final String path = '${dir.path}/t.db';
            final Database db = sqlite3.open(path)
              ..execute('CREATE TABLE t (v INTEGER)');
            final SqliteAccess a = SqliteAccess(db);
            addTearDown(a.close);

            a.transact('p: ', () => db.execute('INSERT INTO t (v) VALUES (7)'));

            final Database other = sqlite3.open(path);
            addTearDown(other.close);
            expect(
              other.select('SELECT v FROM t').map((Row r) => r['v']),
              <Object?>[7],
            );
          });
        });
      });

      group('Given: 1 行を INSERT した後に存在しないテーブルを SELECT する body (T-19-08)', () {
        late Database db;
        late SqliteAccess a;

        int failingBody() {
          db.execute('INSERT INTO t (v) VALUES (1)');
          return db.select('SELECT a FROM missing').length;
        }

        setUp(() {
          final Directory dir = Directory.systemTemp.createTempSync('sqa_');
          addTearDown(() => dir.deleteSync(recursive: true));
          db = sqlite3.open('${dir.path}/t.db')
            ..execute('CREATE TABLE t (v INTEGER)');
          a = SqliteAccess(db);
          addTearDown(a.close);
        });

        group('When: 異常系 (transact(p: , body) を呼ぶ)', () {
          test('[Abnormal] T-WDV-SQA-10: StorageException を投げる', () {
            expect(
              () => a.transact('p: ', failingBody),
              throwsA(isA<StorageException>()),
            );
          });

          test('[State] T-WDV-SQA-11: INSERT した行は取り消され、トランザクションも閉じている', () {
            expect(
              () => a.transact('p: ', failingBody),
              throwsA(isA<StorageException>()),
            );

            expect(db.autocommit, isTrue);
            expect(db.select('SELECT v FROM t'), isEmpty);
          });
        });
      });
    });

    group('T-WDV-SQA: select', () {
      group('Given: a = 1 と a = 2 の 2 行があるテーブル (T-19-03)', () {
        group('When: 正常系 (select(sql, [2]) で値をバインドする)', () {
          test('[Normal] T-WDV-SQA-04: 条件に合う a = 2 の 1 行だけを返す', () {
            final Database db = sqlite3.openInMemory()
              ..execute('CREATE TABLE t (a INTEGER)')
              ..execute('INSERT INTO t (a) VALUES (1), (2)');
            final SqliteAccess a = SqliteAccess(db);
            addTearDown(a.close);

            final ResultSet rows = a.select('SELECT a FROM t WHERE a = ?', [2]);

            expect(rows.map((Row r) => r['a']), <Object?>[2]);
          });
        });
      });
    });

    group('T-WDV-SQA: execute', () {
      group('Given: 3 行のうち 2 行に当たる UPDATE を execute した直後 (T-19-04)', () {
        group('When: 正常系 (execute の後に updatedRows を読む)', () {
          test('[Normal] T-WDV-SQA-05: updatedRows が 2 である', () {
            final Database db = sqlite3.openInMemory()
              ..execute('CREATE TABLE t (a INTEGER)')
              ..execute('INSERT INTO t (a) VALUES (1), (2), (3)');
            final SqliteAccess a = SqliteAccess(db);
            addTearDown(a.close);

            a.execute('UPDATE t SET a = a + 10 WHERE a >= ?', [2]);

            expect(a.updatedRows, 2);
          });
        });
      });

      group('Given: AUTOINCREMENT のテーブルに 1 行を INSERT した直後 (T-19-05)', () {
        group('When: 正常系 (execute の後に lastInsertRowId を読む)', () {
          test('[Normal] T-WDV-SQA-06: lastInsertRowId が追加した行の id である', () {
            final Database db = sqlite3.openInMemory()
              ..execute(
                'CREATE TABLE t (id INTEGER PRIMARY KEY AUTOINCREMENT, v TEXT)',
              );
            final SqliteAccess a = SqliteAccess(db);
            addTearDown(a.close);

            a.execute("INSERT INTO t (v) VALUES ('x')");

            final Object? id = a
                .select('SELECT id FROM t', const <Object?>[])
                .single['id'];
            expect(a.lastInsertRowId, id);
          });
        });
      });
    });
  });
}
