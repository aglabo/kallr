// src: lib/store/__tests__/unit/default_db_path.unit.spec.dart
// @(#) : unit tests for defaultDbPath
//
// Copyright (c) 2026 atsushifx <http://github.com/atsushifx>
//
// Released under the MIT License.
// https://opensource.org/licenses/MIT

// test framework
import 'package:test/test.dart';

// test target
import 'package:w1_w7_verify/store/default_db_path.dart';

// helpers
import 'package:w1_w7_verify/errors.dart';

// internal helpers

/// LOCALAPPDATA value used as the sample input of the normal case.
const String _localAppData = r'C:\Users\tester\AppData\Local';

// test body

/// defaultDbPath
///
/// Resolves the default storage path of the mapping table from the given
/// environment, so the tests never read the real environment.
void main() {
  group('defaultDbPath', () {
    /// defaultDbPath: when `--db` is absent, the path is under LOCALAPPDATA.
    group('T-WDV-DDP: defaultDbPath', () {
      /// When: 正常系 -- LOCALAPPDATA is present.
      group('When: 正常系', () {
        test('[Normal] T-WDV-DDP-01: LOCALAPPDATA 配下の既定の DB パスを返す', () {
          expect(
            defaultDbPath({'LOCALAPPDATA': _localAppData}),
            r'C:\Users\tester\AppData\Local/kallr/w1-w7-verify/mappings.sqlite3',
          );
        });
      });

      /// When: 異常系 -- LOCALAPPDATA is absent; fail first, no fallback path.
      group('When: 異常系', () {
        test(
          '[Error] T-WDV-DDP-02: LOCALAPPDATA が無い -> StorageException を投げる',
          () {
            expect(
              () => defaultDbPath(<String, String>{}),
              throwsA(
                isA<StorageException>().having(
                  (e) => e.message,
                  'message',
                  contains('LOCALAPPDATA'),
                ),
              ),
            );
          },
        );
      });
    });
  });
}
