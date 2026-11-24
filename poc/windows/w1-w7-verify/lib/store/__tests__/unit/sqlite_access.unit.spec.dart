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
    });
  });
}
