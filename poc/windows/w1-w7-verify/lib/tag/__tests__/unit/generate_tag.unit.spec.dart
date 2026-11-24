// src: lib/tag/__tests__/unit/generate_tag.unit.spec.dart
// @(#) : unit tests for generateTag
//
// Copyright (c) 2026 atsushifx <http://github.com/atsushifx>
//
// Released under the MIT License.
// https://opensource.org/licenses/MIT

// test framework
import 'package:test/test.dart';

// test target
import 'package:w1_w7_verify/tag/generate_tag.dart';

// internal helpers

/// Valid machine id (8 lowercase hex digits) shared by all cases.
const String _machineId = 'a1b2c3d4';

/// Valid random part (16 lowercase hex digits) shared by all cases.
const String _random = '0123456789abcdef';

/// Default registration time (local) used when a case does not care about it.
final DateTime _registeredAt = DateTime(2026, 11, 22, 9, 5, 3);

/// Shows [value] with its line breaks as `\n` / `\r` so it fits on one line of a test name.
///
/// Precondition: none; any string is accepted.
/// - [value]: the text to show.
///
/// Returns [value] with each `\n` and `\r` replaced by its two-character escape.
String _escaped(String value) =>
    value.replaceAll('\r', r'\r').replaceAll('\n', r'\n');

/// Calls generateTag; every argument defaults to the shared valid value.
///
/// Precondition: none; the defaults are valid, so a case overrides only what it checks.
/// - [registeredAt]: registration time; defaults to [_registeredAt].
/// - [machineId]: machine id; defaults to [_machineId].
/// - [random]: random part; defaults to [_random].
///
/// Returns the generated Tag. Invalid overrides throw ArgumentError from generateTag.
String _gen({
  DateTime? registeredAt,
  String machineId = _machineId,
  String random = _random,
}) => generateTag(
  registeredAt: registeredAt ?? _registeredAt,
  machineId: machineId,
  random: random,
);

/// Datetime-part cases: (title, local input, expected 14-digit part).
final List<(String, DateTime, String)> _datetimePartCases = [
  ('月日時分秒が 1 桁でもゼロ埋めの 2 桁にする', DateTime(2026, 1, 2, 3, 4, 5), '20260102030405'),
  // The date tests (the datetime part and the boundary dates) detect a toUtc() regression only
  // when the runner's time zone is not UTC.
  (
    'ローカル日時を UTC へ変換せず、そのまま使う',
    DateTime(2026, 12, 31, 23, 59, 59),
    '20261231235959',
  ),
];

/// Valid boundary-input cases:
/// (title, registeredAt, machineId, random, expected whole Tag).
///
/// Year 0 is accepted and padded to `0000` (Dart's DateTime allows it and the
/// 4-digit year field is zero-padded); year 9999 is the upper bound.
final List<(String, DateTime, String, String, String)> _validTagCases = [
  (
    '999 ミリ秒は切り上げずに切り捨てる',
    DateTime(2026, 11, 22, 9, 5, 3, 999),
    _machineId,
    _random,
    '20261122090503-a1b2c3d4-0123456789abcdef',
  ),
  (
    '年 0 は 0000 として受け入れる (0000-01-01 00:00:00)',
    DateTime(0, 1, 1),
    _machineId,
    _random,
    '00000101000000-a1b2c3d4-0123456789abcdef',
  ),
  (
    '年 9999 は 9999 として受け入れる (9999-12-31 23:59:59)',
    DateTime(9999, 12, 31, 23, 59, 59),
    _machineId,
    _random,
    '99991231235959-a1b2c3d4-0123456789abcdef',
  ),
  (
    'マシン ID 00000000 は有効な値として受け入れる',
    DateTime(2026, 11, 22, 9, 5, 3),
    '00000000',
    _random,
    '20261122090503-00000000-0123456789abcdef',
  ),
  (
    '乱数 ffffffffffffffff は有効な値として受け入れる',
    DateTime(2026, 11, 22, 9, 5, 3),
    _machineId,
    'ffffffffffffffff',
    '20261122090503-a1b2c3d4-ffffffffffffffff',
  ),
  (
    'マシン ID ffffffff は有効な値として受け入れる',
    DateTime(2026, 11, 22, 9, 5, 3),
    'ffffffff',
    _random,
    '20261122090503-ffffffff-0123456789abcdef',
  ),
];

/// Out-of-range year cases: (title, input whose year is outside 0..9999).
final List<(String, DateTime)> _outOfRangeYearCases = [
  ('年が -1 なら ArgumentError を投げる', DateTime(-1, 11, 22, 9, 5, 3)),
  ('年が 10000 なら ArgumentError を投げる', DateTime(10000, 11, 22, 9, 5, 3)),
];

/// Invalid machine id cases: (title, machineId not matching 8 lowercase hex digits).
final List<(String, String)> _invalidMachineIdCases = [
  ('マシン ID が 7 桁なら ArgumentError を投げる', 'a1b2c3d'),
  ('マシン ID が 9 桁なら ArgumentError を投げる', 'a1b2c3d4e'),
  ('マシン ID が大文字なら ArgumentError を投げる', 'A1B2C3D4'),
  ('マシン ID に 16 進以外の文字があれば ArgumentError を投げる', 'g1b2c3d4'),
  ('マシン ID が空文字なら ArgumentError を投げる', ''),
];

/// Invalid random cases: (title, random not matching 16 lowercase hex digits).
final List<(String, String)> _invalidRandomCases = [
  ('乱数が 15 桁なら ArgumentError を投げる', '0123456789abcde'),
  ('乱数が 17 桁なら ArgumentError を投げる', '0123456789abcdef0'),
  ('乱数が大文字なら ArgumentError を投げる', '0123456789ABCDEF'),
  ('乱数に 16 進以外の文字があれば ArgumentError を投げる', '0123456789abcdeg'),
  ('乱数の末尾に改行があれば ArgumentError を投げる', '0123456789abcdef\n'),
  ('乱数に `/` (`0` の直前の文字) があれば ArgumentError を投げる', '0123456789abcde/'),
  ('乱数に `:` (`9` の直後の文字) があれば ArgumentError を投げる', '0123456789abcde:'),
  ('乱数にバッククォート (`a` の直前の文字) があれば ArgumentError を投げる', '0123456789abcde`'),
];

/// Tests for generateTag: format, length, zero padding and local-time use.
void main() {
  group('generateTag', () {
    /// generateTag builds a 40-character Tag from valid input (normal and
    /// boundary-value edge cases) and rejects malformed input with ArgumentError.
    group('T-WDV-TAG: generateTag', () {
      group('When: 正常系', () {
        test('[Normal] T-WDV-TAG-01: 有効な 3 入力から決められた書式の Tag を返す', () {
          expect(_gen(), '20261122090503-a1b2c3d4-0123456789abcdef');
        });

        test('[Normal] T-WDV-TAG-02: 返した Tag は 40 文字で、上限 64 文字以下である', () {
          final tag = _gen();
          expect(tag.length, 40);
          expect(tag.length, lessThanOrEqualTo(64));
        });

        for (final (title, input, expected) in _datetimePartCases) {
          test('[Normal] T-WDV-TAG-03: $title ($expected)', () {
            expect(_gen(registeredAt: input).substring(0, 14), expected);
          });
        }

        test('[Normal] T-WDV-TAG-05: 同じ入力で 2 回呼ぶと同じ Tag を返す', () {
          final registeredAt = DateTime(2026, 11, 22, 9, 5, 3);
          expect(
            _gen(registeredAt: registeredAt),
            _gen(registeredAt: registeredAt),
          );
        });
      });

      group('When: エッジケース (有効な境界値)', () {
        for (final (title, registeredAt, machineId, random, expected)
            in _validTagCases) {
          test('[Edge] T-WDV-TAG-17: $title ($expected)', () {
            expect(
              _gen(
                registeredAt: registeredAt,
                machineId: machineId,
                random: random,
              ),
              expected,
            );
          });
        }
      });

      // Nothing here depends on the time zone or DST: the same local time twice
      // (as at a DST fall-back) only needs the random part to tell the Tags apart.
      group('When: エッジケース (同じ登録時刻が重なる)', () {
        test('[Edge] T-WDV-TAG-22: 同じ登録時刻でも乱数が違えば日時部分は等しく Tag は異なる', () {
          final registeredAt = DateTime(2026, 11, 1, 1, 30, 0);
          final tag1 = _gen(
            registeredAt: registeredAt,
            random: '0000000000000001',
          );
          final tag2 = _gen(
            registeredAt: registeredAt,
            random: '0000000000000002',
          );
          expect(tag1.substring(0, 14), tag2.substring(0, 14));
          expect(tag1, isNot(tag2));
        });
      });

      group('When: 異常系 (年が範囲外)', () {
        for (final (title, input) in _outOfRangeYearCases) {
          test('[Error] T-WDV-TAG-06: $title', () {
            expect(() => _gen(registeredAt: input), throwsArgumentError);
          });
        }
      });

      group('When: 異常系 (マシン ID の書式が不正)', () {
        for (final (title, machineId) in _invalidMachineIdCases) {
          test('[Error] T-WDV-TAG-08: $title ("$machineId")', () {
            expect(() => _gen(machineId: machineId), throwsArgumentError);
          });
        }
      });

      group('When: 異常系 (乱数の書式が不正)', () {
        for (final (title, random) in _invalidRandomCases) {
          // Escape the value so a control character (the trailing-newline case) cannot split the test name.
          test('[Error] T-WDV-TAG-13: $title ("${_escaped(random)}")', () {
            expect(() => _gen(random: random), throwsArgumentError);
          });
        }
      });
    });
  });
}
