// src: lib/tag/__tests__/unit/tag_allocator.unit.spec.dart
// @(#) : unit tests for allocateTag
//
// Copyright (c) 2026 atsushifx <http://github.com/atsushifx>
//
// Released under the MIT License.
// https://opensource.org/licenses/MIT

// test framework
import 'package:test/test.dart';

// test target
import 'package:w1_w7_verify/errors.dart';
import 'package:w1_w7_verify/tag/providers.dart';
import 'package:w1_w7_verify/tag/tag_allocator.dart';

// internal helpers

/// Valid machine id (8 lowercase hex digits) returned by [_FakeMachineId].
const String _machineId = 'a1b2c3d4';

/// First random part (16 lowercase hex digits) used by the normal cases.
const String _firstRandom = '0123456789abcdef';

/// Second random part, queued so an extra call would not fail by exhaustion.
const String _secondRandom = 'fedcba9876543210';

/// Registration time shared by all cases.
final DateTime _registeredAt = DateTime(2026, 11, 22, 9, 5, 3);

/// The four random parts that are all already taken in the retry-limit cases.
const List<String> _dupRandoms = [
  '0000000000000001',
  '0000000000000002',
  '0000000000000003',
  '0000000000000004',
];

/// Builds a fixture Tag for [random] (registered at [_registeredAt] on [_machineId]).
///
/// Use only for fixtures; expected values stay literal so the format is not reused.
String _tagFor(String random) => '20261122090503-$_machineId-$random';

/// Fake random source that returns queued values in order and counts calls.
class _FakeRandomSource implements RandomSourceProvider {
  /// Creates a source that returns [_values] one by one.
  _FakeRandomSource(Iterable<String> values) : _values = List.of(values);

  final List<String> _values;

  /// Number of times [randomHex64] has been called.
  int callCount = 0;

  /// Returns the next queued value and counts the call.
  @override
  String randomHex64() {
    if (callCount >= _values.length) {
      throw StateError('random queue exhausted after $callCount calls');
    }
    return _values[callCount++];
  }
}

/// Fake machine id provider that always returns a fixed id ([_machineId] by default).
class _FakeMachineId implements MachineIdProvider {
  /// Creates a provider returning [id].
  _FakeMachineId([this.id = _machineId]);

  /// The id returned by [machineId].
  final String id;

  /// Number of times [machineId] has been called.
  int callCount = 0;

  /// Returns the fixed machine id and counts the call.
  @override
  String machineId() {
    callCount++;
    return id;
  }
}

/// Fake machine id provider whose [machineId] always fails with [StorageException].
class _FailingMachineId implements MachineIdProvider {
  @override
  String machineId() => throw const StorageException('cannot open SQLite');
}

/// Calls allocateTag with the defaults shared by most cases.
///
/// Precondition: none; [existingTags] is read-only for allocateTag, so the const default is safe
/// (cases that mutate or inspect the set pass their own mutable set).
/// - [random]: random source (required).
/// - [machineId]: machine id provider; defaults to a fresh [_FakeMachineId].
/// - [existingTags]: Tags already registered; defaults to empty.
/// - [registeredAt]: registration time; defaults to [_registeredAt].
///
/// Returns the allocated Tag. Cases that count machineId calls, use failing providers, or
/// assert on the call itself (throwsA closures) call allocateTag directly.
String _allocate({
  required RandomSourceProvider random,
  MachineIdProvider? machineId,
  Set<String> existingTags = const {},
  DateTime? registeredAt,
}) => allocateTag(
  random: random,
  machineId: machineId ?? _FakeMachineId(),
  existingTags: existingTags,
  registeredAt: registeredAt ?? _registeredAt,
);

/// Tests for allocateTag.
void main() {
  group('allocateTag', () {
    /// allocateTag contract: the first Tag is adopted when it is free, only the random part
    /// is regenerated on a duplicate, retries are bounded (DuplicateTagException at the limit),
    /// ArgumentError / StorageException from the providers propagate, and existingTags is untouched.
    group('T-WDV-TAL: allocateTag', () {
      group('When: 正常系', () {
        test('[Normal] T-WDV-TAL-01: existingTags が空なら 1 回目の乱数の Tag を返す', () {
          final tag = _allocate(random: _FakeRandomSource([_firstRandom]));
          expect(tag, '20261122090503-a1b2c3d4-0123456789abcdef');
        });

        test('[Normal] T-WDV-TAL-02: 重複がなければ randomHex64 を 1 回だけ呼ぶ', () {
          final random = _FakeRandomSource([_firstRandom, _secondRandom]);
          _allocate(random: random);
          expect(random.callCount, 1);
        });
      });

      /// Duplicate cases: only the random part is regenerated.
      group('When: 1 回目の Tag が重複', () {
        final firstTag = _tagFor(_firstRandom);

        test('[Normal] T-WDV-TAL-03: 1 回目の Tag が existingTags にあれば 2 回目の乱数の Tag を返す', () {
          final tag = _allocate(
            random: _FakeRandomSource([_firstRandom, _secondRandom]),
            existingTags: {firstTag},
          );
          expect(tag, '20261122090503-a1b2c3d4-$_secondRandom');
        });

        test('[Normal] T-WDV-TAL-04: 再生成しても machineId() を呼ぶのは 1 回だけである', () {
          final machineId = _FakeMachineId();
          allocateTag(
            random: _FakeRandomSource([_firstRandom, _secondRandom]),
            machineId: machineId,
            existingTags: {firstTag},
            registeredAt: _registeredAt,
          );
          expect(machineId.callCount, 1);
        });
      });

      /// Side-effect cases: existingTags is read-only for allocateTag.
      group('When: existingTags を変更しない', () {
        test('[Normal] T-WDV-TAL-05: 呼び出し後も existingTags の内容が変わらない', () {
          final existing = _tagFor(_secondRandom);
          final existingTags = <String>{existing};
          final tag = _allocate(
            random: _FakeRandomSource([_firstRandom]),
            existingTags: existingTags,
          );
          expect(existingTags, {existing});
          expect(existingTags.contains(tag), isFalse);
        });
      });

      /// Error cases: retry limit (every attempt a duplicate) and invalid or failing providers.
      group('When: 異常系', () {
        final existingTags = {for (final r in _dupRandoms) _tagFor(r)};

        test('[Error] T-WDV-TAL-06: 4 回とも重複したら DuplicateTagException を attempts: 4 で投げる', () {
          expect(
            () => allocateTag(
              random: _FakeRandomSource(_dupRandoms),
              machineId: _FakeMachineId(),
              existingTags: existingTags,
              registeredAt: _registeredAt,
            ),
            throwsA(
              isA<DuplicateTagException>().having(
                (e) => e.attempts,
                'attempts',
                4,
              ),
            ),
          );
        });

        test('[Error] T-WDV-TAL-07: 上限に達したら 5 回目の乱数を取得しない', () {
          final random = _FakeRandomSource([
            ..._dupRandoms,
            '0000000000000005',
            '0000000000000006',
          ]);
          expect(
            () => allocateTag(
              random: random,
              machineId: _FakeMachineId(),
              existingTags: existingTags,
              registeredAt: _registeredAt,
            ),
            throwsA(isA<DuplicateTagException>()),
          );
          expect(random.callCount, 4);
        });

        test('[Error] T-WDV-TAL-08: 乱数が不正なら ArgumentError を投げ、再生成せず randomHex64 を 1 回だけ呼ぶ', () {
          final random = _FakeRandomSource(['xyz', _secondRandom]);
          expect(
            () => allocateTag(
              random: random,
              machineId: _FakeMachineId(),
              existingTags: <String>{},
              registeredAt: _registeredAt,
            ),
            throwsArgumentError,
          );
          expect(random.callCount, 1);
        });

        test('[Error] T-WDV-TAL-09: machineId() が StorageException を投げたらそのまま伝え、乱数を取得しない', () {
          final random = _FakeRandomSource([_firstRandom]);
          expect(
            () => allocateTag(
              random: random,
              machineId: _FailingMachineId(),
              existingTags: <String>{},
              registeredAt: _registeredAt,
            ),
            throwsA(isA<StorageException>()),
          );
          expect(random.callCount, 0);
        });

        test('[Error] T-WDV-TAL-10: machineId() が ZZZZZZZZ を返したら補正せず ArgumentError を投げる', () {
          expect(
            () => allocateTag(
              random: _FakeRandomSource([_firstRandom]),
              machineId: _FakeMachineId('ZZZZZZZZ'),
              existingTags: <String>{},
              registeredAt: _registeredAt,
            ),
            throwsArgumentError,
          );
        });
      });

      /// Boundary cases: success on the last allowed attempt (the 4th).
      group('When: エッジケース (3 回重複して 4 回目で成功)', () {
        final randoms = [..._dupRandoms, '0000000000000005'];
        final existingTags = {for (final r in randoms.take(3)) _tagFor(r)};

        test('[Edge] T-WDV-TAL-11: 最初の 3 回が重複し 4 回目で空きなら 4 回目の Tag を返す', () {
          final tag = _allocate(
            random: _FakeRandomSource(randoms),
            existingTags: existingTags,
          );
          expect(tag, '20261122090503-a1b2c3d4-0000000000000004');
        });

        test(
          '[Edge] T-WDV-TAL-12: 3 回目の再生成で成功したときの randomHex64 の呼び出しは 4 回である',
          () {
            final random = _FakeRandomSource(randoms);
            _allocate(random: random, existingTags: existingTags);
            expect(random.callCount, 4);
          },
        );
      });

      /// Edge case: a Tag differing only in the random part is not a duplicate.
      group('When: エッジケース (乱数だけ違う既存の Tag)', () {
        test('[Edge] T-WDV-TAL-13: 乱数だけ違う既存の Tag があっても 1 回目の Tag を採用し randomHex64 は 1 回だけ呼ぶ', () {
          final random = _FakeRandomSource([_firstRandom, _secondRandom]);
          final tag = _allocate(
            random: random,
            existingTags: {_tagFor(_secondRandom)},
          );
          expect(tag, '20261122090503-a1b2c3d4-$_firstRandom');
          expect(random.callCount, 1);
        });
      });

      /// Edge case: allocateTag does not limit the size of existingTags.
      group('When: エッジケース (上限相当の件数)', () {
        test(
          '[Edge] T-WDV-TAL-14: existingTags が 4096 件でも重複しなければ 1 回目の Tag を返す',
          () {
            final existingTags = <String>{
              for (var i = 0; i < 4096; i++)
                _tagFor(i.toRadixString(16).padLeft(16, '0')),
            };
            final random = _FakeRandomSource([_firstRandom]);

            final tag = _allocate(random: random, existingTags: existingTags);

            expect(tag, '20261122090503-a1b2c3d4-$_firstRandom');
            expect(random.callCount, 1);
          },
        );
      });

      /// Edge case: replacing goes through the same steps as adding.
      group('When: エッジケース (置換でも追加と同じ手順)', () {
        test('[Edge] T-WDV-TAL-15: 同じ登録時刻で 2 回目に呼び、1 回目の Tag が existingTags にあれば別の Tag を返す', () {
          final existingTags = <String>{};
          final tag1 = _allocate(
            random: _FakeRandomSource([_firstRandom]),
            existingTags: existingTags,
          );
          existingTags.add(tag1);

          final random = _FakeRandomSource([_firstRandom, _secondRandom]);
          final tag2 = _allocate(random: random, existingTags: existingTags);

          expect(tag2, isNot(tag1));
          expect(tag2, '20261122090503-a1b2c3d4-$_secondRandom');
          expect(random.callCount, 2);
        });
      });

      /// Edge case: a Tag sharing only the random part is not a duplicate (TAG-R-006).
      group('When: エッジケース (乱数だけ同じ既存の Tag)', () {
        test('[Edge] T-WDV-TAL-16: 乱数が同じでも日時とマシン ID が違う既存の Tag だけなら 1 回目の Tag を返し randomHex64 は 1 回だけ呼ぶ', () {
          final random = _FakeRandomSource([_firstRandom, _secondRandom]);
          final tag = _allocate(
            random: random,
            existingTags: {'20260101000000-ffffffff-$_firstRandom'},
          );
          expect(tag, '20261122090503-a1b2c3d4-$_firstRandom');
          expect(random.callCount, 1);
        });
      });

      /// Edge cases: a Tag differing from the first one in only one part is not a duplicate
      /// (TAG-R-006). Kills comparisons that leave out the registration time or the machine id.
      group('When: エッジケース (日時またはマシン ID の片方だけ違う既存の Tag)', () {
        test('[Edge] T-WDV-TAL-17: 乱数とマシン ID が同じで日時だけ違う既存の Tag だけなら 1 回目の Tag を返し randomHex64 は 1 回だけ呼ぶ', () {
          final random = _FakeRandomSource([_firstRandom, _secondRandom]);
          final tag = _allocate(
            random: random,
            existingTags: {'20260101000000-$_machineId-$_firstRandom'},
          );
          expect(tag, '20261122090503-a1b2c3d4-$_firstRandom');
          expect(random.callCount, 1);
        });

        test('[Edge] T-WDV-TAL-18: 乱数と日時が同じでマシン ID だけ違う既存の Tag だけなら 1 回目の Tag を返し randomHex64 は 1 回だけ呼ぶ', () {
          final random = _FakeRandomSource([_firstRandom, _secondRandom]);
          final tag = _allocate(
            random: random,
            existingTags: {'20261122090503-ffffffff-$_firstRandom'},
          );
          expect(tag, '20261122090503-a1b2c3d4-$_firstRandom');
          expect(random.callCount, 1);
        });
      });
    });
  });
}
