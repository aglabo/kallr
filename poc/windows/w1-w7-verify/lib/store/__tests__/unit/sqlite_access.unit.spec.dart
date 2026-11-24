// src: lib/store/__tests__/unit/sqlite_access.unit.spec.dart
// @(#) : unit tests for SqliteAccess (SQL execution base layer)
//
// Copyright (c) 2026 atsushifx <http://github.com/atsushifx>
//
// Released under the MIT License.
// https://opensource.org/licenses/MIT

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
  });
}
