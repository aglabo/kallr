// src: test/map_toast_key.unit.spec.dart
// @(#) : unit tests for mapToastKey
//
// Copyright (c) 2026 atsushifx <http://github.com/atsushifx>
//
// Released under the MIT License.
// https://opensource.org/licenses/MIT

// test framework
import 'package:test/test.dart';

// test target
import 'package:w1_w7_verify/map_toast_key.dart';

// internal helpers

/// Returns [count] long ids that differ only in their leading part.
List<String> _distinctLongIds(int count) =>
    List.generate(count, (i) => 'batch-$i-' + 'x' * 100);

/// Ids for the hash format cases. Includes ids whose hash has the top bit set,
/// which would print as a negative number if the unsigned conversion were missing.
final List<String> _hashSampleIds = [
  'a' * 17,
  'batch-001-' + 'x' * 40,
  'foobar-foobar-foobar',
  '😀' * 20,
  for (var i = 0; i < 6; i++) 'sample-$i-' + 'y' * 20,
];

/// Independent FNV-1a 64-bit (BigInt arithmetic, explicit 64-bit mask) as unsigned lowercase hex.
String _referenceFnv1a64Hex(String text) {
  final mask = (BigInt.one << 64) - BigInt.one;
  final prime = BigInt.parse('100000001b3', radix: 16);
  final hash = text.codeUnits.fold<BigInt>(
    BigInt.parse('cbf29ce484222325', radix: 16),
    (acc, unit) => ((acc ^ BigInt.from(unit)) * prime) & mask,
  );
  return hash.toRadixString(16).padLeft(16, '0');
}

/// One mapToastKey call and its test identity (case id and name).
typedef _Case = ({String caseId, String name, String id, int maxLength});

/// Invalid arguments that must raise ArgumentError (no fallback value).
const List<_Case> _invalidArgumentCases = [
  (
    caseId: 'T-WDV-MTK-05',
    name: 'maxLength が 0',
    id: 'batch-001',
    maxLength: 0,
  ),
  (
    caseId: 'T-WDV-MTK-06',
    name: 'maxLength が負数',
    id: 'batch-001',
    maxLength: -1,
  ),
  (caseId: 'T-WDV-MTK-07', name: '空文字の ID', id: '', maxLength: 64),
  (
    caseId: 'T-WDV-MTK-08',
    name: '短縮が必要で maxLength が 16 未満',
    id: 'aaaaaaaaaaaaaaaaaaaa',
    maxLength: 15,
  ),
];

/// Ids that fit in maxLength and must come back unchanged (boundary cases).
final List<_Case> _unchangedCases = [
  (
    caseId: 'T-WDV-MTK-09',
    name: '長さが maxLength ちょうどなら無変更',
    id: 'a' * 64,
    maxLength: 64,
  ),
  (
    caseId: 'T-WDV-MTK-12',
    name: '極小の maxLength でも ID が収まれば無変更',
    id: 'a',
    maxLength: 1,
  ),
];

/// True when [text] contains a UTF-16 surrogate that is not part of a valid pair.
bool _hasLoneSurrogate(String text) => RegExp(
  r'[\uD800-\uDBFF](?![\uDC00-\uDFFF])|(?<![\uD800-\uDBFF])[\uDC00-\uDFFF]',
).hasMatch(text);

void main() {
  group('mapToastKey', () {
    group('T-WDV-MTK: mapToastKey', () {
      group('When: 正常系', () {
        test('[Normal] T-WDV-MTK-01: 上限以内の ID は無変更で返す', () {
          expect(mapToastKey('batch-001', maxLength: 64), 'batch-001');
        });

        test('[Normal] T-WDV-MTK-02: 上限を大きく超える ID は上限以内に短縮される', () {
          final id = 'a' * 200;
          final result = mapToastKey(id, maxLength: 64);
          expect(result.length, lessThanOrEqualTo(64));
          expect(result, isNot(id));
        });

        test('[Normal] T-WDV-MTK-03: 同じ入力は同じ結果を返す', () {
          final id = 'a' * 100;
          expect(
            mapToastKey(id, maxLength: 32),
            mapToastKey(id, maxLength: 32),
          );
        });

        test('[Normal] T-WDV-MTK-04: 先頭が異なる 1000 個の長い ID の結果は衝突しない', () {
          final results = _distinctLongIds(1000)
              .map((id) => mapToastKey(id, maxLength: 32));
          expect(results.toSet().length, 1000);
        });

        test('[Normal] T-WDV-MTK-14: 末尾だけが異なる 2 つの長い ID は異なる結果になる', () {
          final a = mapToastKey('p' * 100 + 'A', maxLength: 32);
          final b = mapToastKey('p' * 100 + 'B', maxLength: 32);
          expect(a, isNot(b));
        });

        for (final (index, id) in _hashSampleIds.indexed) {
          final caseId =
              'T-WDV-MTK-15-${(index + 1).toString().padLeft(2, '0')}';
          test(
            '[Normal] $caseId: 短縮結果は FNV-1a 64bit の 16 桁小文字 16 進 (${id.length} units)',
            () {
              expect(mapToastKey(id, maxLength: 16), _referenceFnv1a64Hex(id));
            },
          );
        }
      });

      group('When: 異常系', () {
        for (final c in _invalidArgumentCases) {
          test('[Error] ${c.caseId}: ${c.name} -> ArgumentError', () {
            expect(
              () => mapToastKey(c.id, maxLength: c.maxLength),
              throwsArgumentError,
            );
          });
        }
      });

      group('When: エッジケース', () {
        for (final c in _unchangedCases) {
          test('[Edge] ${c.caseId}: ${c.name}', () {
            expect(mapToastKey(c.id, maxLength: c.maxLength), c.id);
          });
        }

        test('[Edge] T-WDV-MTK-10: 長さが maxLength + 1 なら短縮される', () {
          final id = 'a' * 65;
          final result = mapToastKey(id, maxLength: 64);
          expect(result.length, lessThanOrEqualTo(64));
          expect(result, isNot(id));
        });

        test('[Edge] T-WDV-MTK-11: maxLength がハッシュ長ちょうどなら長さ 16 に短縮される', () {
          expect(mapToastKey('a' * 17, maxLength: 16).length, 16);
        });

        test('[Edge] T-WDV-MTK-13: サロゲートペアを含む ID は孤立サロゲートを作らず上限以内に収まる', () {
          final result = mapToastKey('😀' * 20, maxLength: 32);
          expect(result.length, lessThanOrEqualTo(32));
          expect(_hasLoneSurrogate(result), isFalse);
        });
      });
    });
  });
}
