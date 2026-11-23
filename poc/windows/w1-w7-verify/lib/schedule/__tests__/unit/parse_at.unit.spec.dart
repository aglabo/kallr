// src: lib/schedule/__tests__/unit/parse_at.unit.spec.dart
// @(#) : unit tests for parseAt
//
// Copyright (c) 2026 atsushifx <http://github.com/atsushifx>
//
// Released under the MIT License.
// https://opensource.org/licenses/MIT

// test framework
import 'package:test/test.dart';

// test target
import 'package:w1_w7_verify/errors.dart';
import 'package:w1_w7_verify/schedule/parse_at.dart';

// internal helpers

// functions

/// Builds a fixed UTC offset provider so the test does not depend on the machine's time zone.
///
/// - [offset]: the offset the provider returns (e.g. `Duration(hours: 9)` for +09:00).
///
/// Returns a provider that ignores its argument and always returns [offset].
Duration Function(DateTime) _fixedOffset(Duration offset) =>
    (_) => offset;

/// The instant US Eastern time switches to daylight time (2026-03-08 02:00 EST = 07:00Z).
final _nyDstStart = DateTime.utc(2026, 3, 8, 7);

/// The instant US Eastern time switches back to standard time (2026-11-01 02:00 EDT = 06:00Z).
final _nyDstEnd = DateTime.utc(2026, 11, 1, 6);

/// US Eastern UTC offset provider covering the 2026 transitions.
///
/// - [utc]: the instant to look up.
///
/// Returns -04:00 from [_nyDstStart] up to (not including) [_nyDstEnd], otherwise -05:00.
Duration _nyOffsetAt(DateTime utc) =>
    !utc.isBefore(_nyDstStart) && utc.isBefore(_nyDstEnd)
    ? const Duration(hours: -4)
    : const Duration(hours: -5);

/// Tests for parseAt.
void main() {
  group('parseAt', () {
    /// parseAt contract: a string with an explicit offset is interpreted as the same absolute instant.
    group('T-WDV-ATP: parseAt', () {
      group('When: 正常系', () {
        test('[Normal] T-WDV-ATP-01: +09:00 の文字列を同じ絶対時刻に解釈する', () {
          final at = parseAt('2026-11-22T09:30:00+09:00');
          expect(at.toUtc(), DateTime.utc(2026, 11, 22, 0, 30));
        });

        test('[Normal] T-WDV-ATP-02: オフセット付きの結果は UTC で保持する', () {
          final at = parseAt('2026-11-22T09:30:00+09:00');
          expect(at.isUtc, isTrue);
        });

        test('[Normal] T-WDV-ATP-03: Z の文字列を UTC の絶対時刻に解釈する', () {
          final at = parseAt('2026-11-22T00:30:00Z');
          expect(at, DateTime.utc(2026, 11, 22, 0, 30));
        });

        test('[Normal] T-WDV-ATP-04: -05:00 の文字列を同じ絶対時刻に解釈する', () {
          final at = parseAt('2026-11-22T09:30:00-05:00');
          expect(at, DateTime.utc(2026, 11, 22, 14, 30));
        });

        test('[Normal] T-WDV-ATP-05: オフセット無しの文字列をローカル時刻として解決する', () {
          final at = parseAt(
            '2026-11-22T09:30:00',
            offsetAt: _fixedOffset(const Duration(hours: 9)),
          );
          expect(at, DateTime.utc(2026, 11, 22, 0, 30));
        });

        test('[Normal] T-WDV-ATP-06: ローカルのオフセットに従い、JST を仮定しない', () {
          final at = parseAt(
            '2026-11-22T09:30:00',
            offsetAt: _fixedOffset(const Duration(hours: -5)),
          );
          expect(at, DateTime.utc(2026, 11, 22, 14, 30));
        });

        test(
          '[Normal] T-WDV-ATP-07: 日付のみは、ローカルの 00:00:00 として解決する (+09:00)',
          () {
            final at = parseAt(
              '2026-11-22',
              offsetAt: _fixedOffset(const Duration(hours: 9)),
            );
            expect(at, DateTime.utc(2026, 11, 21, 15));
          },
        );

        test('[Normal] T-WDV-ATP-08: 日付のみは、ローカルのオフセットに従う (-05:00)', () {
          final at = parseAt(
            '2026-11-22',
            offsetAt: _fixedOffset(const Duration(hours: -5)),
          );
          expect(at, DateTime.utc(2026, 11, 22, 5));
        });

        test('[Normal] T-WDV-ATP-24: 切り替えと無関係な夏の時刻は 1 つの瞬間に決まる (-04:00)', () {
          final at = parseAt('2026-07-01T12:00:00', offsetAt: _nyOffsetAt);
          expect(at, DateTime.utc(2026, 7, 1, 16));
        });

        test('[Normal] T-WDV-ATP-27: 進みの日の日付のみは、標準時の 00:00:00 になる', () {
          final at = parseAt('2026-03-08', offsetAt: _nyOffsetAt);
          expect(at, DateTime.utc(2026, 3, 8, 5));
        });

        test('[Normal] T-WDV-ATP-28: 戻りの日の日付のみは、夏時間の 00:00:00 になる', () {
          final at = parseAt('2026-11-01', offsetAt: _nyOffsetAt);
          expect(at, DateTime.utc(2026, 11, 1, 4));
        });
      });

      group('When: 異常系', () {
        test('[Error] T-WDV-ATP-09: 解釈できない文字列は UsageException を投げる', () {
          expect(() => parseAt('tomorrow'), throwsA(isA<UsageException>()));
        });

        test('[Error] T-WDV-ATP-10: 空文字は UsageException を投げる', () {
          expect(() => parseAt(''), throwsA(isA<UsageException>()));
        });

        test('[Error] T-WDV-ATP-11: 13 月 45 日は UsageException を投げる', () {
          expect(
            () => parseAt(
              '2026-13-45T09:30:00',
              offsetAt: _fixedOffset(const Duration(hours: 9)),
            ),
            throwsA(isA<UsageException>()),
          );
        });

        test(
          '[Error] T-WDV-ATP-12: 存在しない時刻 (夏時間の飛び越し) は UsageException を投げる',
          () {
            expect(
              () => parseAt('2026-03-08T02:30:00', offsetAt: _nyOffsetAt),
              throwsA(isA<UsageException>()),
            );
          },
        );

        test(
          '[Error] T-WDV-ATP-21: 存在しない時間帯の先頭 02:00:00 は UsageException を投げる',
          () {
            expect(
              () => parseAt('2026-03-08T02:00:00', offsetAt: _nyOffsetAt),
              throwsA(isA<UsageException>()),
            );
          },
        );

        test(
          '[Error] T-WDV-ATP-22: 存在しない時間帯の末尾 02:59:59 は UsageException を投げる',
          () {
            expect(
              () => parseAt('2026-03-08T02:59:59', offsetAt: _nyOffsetAt),
              throwsA(isA<UsageException>()),
            );
          },
        );

        test('[Error] T-WDV-ATP-25: 存在しない暦の日付のみは UsageException を投げる', () {
          expect(
            () => parseAt(
              '2026-02-30',
              offsetAt: _fixedOffset(const Duration(hours: 9)),
            ),
            throwsA(isA<UsageException>()),
          );
        });

        test(
          '[Error] T-WDV-ATP-26: 日付にオフセットだけを付けた文字列は UsageException を投げる',
          () {
            expect(
              () => parseAt('2026-11-22+09:00'),
              throwsA(isA<UsageException>()),
            );
          },
        );
      });

      group('When: エッジケース', () {
        test('[Edge] T-WDV-ATP-13: 夏時間の戻りで曖昧な時刻は早いほうの瞬間を使う', () {
          final at = parseAt('2026-11-01T01:30:00', offsetAt: _nyOffsetAt);
          expect(at, DateTime.utc(2026, 11, 1, 5, 30));
        });

        test('[Edge] T-WDV-ATP-14: 明示オフセットは夏時間の規則に左右されない', () {
          final at = parseAt(
            '2026-11-01T01:30:00-05:00',
            offsetAt: _nyOffsetAt,
          );
          expect(at, DateTime.utc(2026, 11, 1, 6, 30));
        });

        test('[Edge] T-WDV-ATP-15: 過去の時刻を検査せず同じ瞬間を返す', () {
          final at = parseAt('2000-01-01T00:00:00Z');
          expect(at, DateTime.utc(2000, 1, 1));
        });

        test('[Edge] T-WDV-ATP-16: 曖昧になる直前の 00:59:59 は曖昧でない', () {
          final at = parseAt('2026-11-01T00:59:59', offsetAt: _nyOffsetAt);
          expect(at, DateTime.utc(2026, 11, 1, 4, 59, 59));
        });

        test('[Edge] T-WDV-ATP-17: 曖昧な時間帯の先頭 01:00:00 は早いほうを使う', () {
          final at = parseAt('2026-11-01T01:00:00', offsetAt: _nyOffsetAt);
          expect(at, DateTime.utc(2026, 11, 1, 5));
        });

        test('[Edge] T-WDV-ATP-18: 曖昧な時間帯の末尾 01:59:59 は早いほうを使う', () {
          final at = parseAt('2026-11-01T01:59:59', offsetAt: _nyOffsetAt);
          expect(at, DateTime.utc(2026, 11, 1, 5, 59, 59));
        });

        test('[Edge] T-WDV-ATP-19: 曖昧でなくなる 02:00:00 は標準時の瞬間になる', () {
          final at = parseAt('2026-11-01T02:00:00', offsetAt: _nyOffsetAt);
          expect(at, DateTime.utc(2026, 11, 1, 7));
        });

        test('[Edge] T-WDV-ATP-20: 存在しなくなる直前の 01:59:59 は有効である', () {
          final at = parseAt('2026-03-08T01:59:59', offsetAt: _nyOffsetAt);
          expect(at, DateTime.utc(2026, 3, 8, 6, 59, 59));
        });

        test('[Edge] T-WDV-ATP-23: 存在し直す 03:00:00 は有効である', () {
          final at = parseAt('2026-03-08T03:00:00', offsetAt: _nyOffsetAt);
          expect(at, DateTime.utc(2026, 3, 8, 7));
        });
      });
    });
  });
}
