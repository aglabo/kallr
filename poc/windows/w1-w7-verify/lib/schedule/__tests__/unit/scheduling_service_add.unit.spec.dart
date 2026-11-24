// src: lib/schedule/__tests__/unit/scheduling_service_add.unit.spec.dart
// @(#) : unit tests for SchedulingService.add (new registration)
//
// Copyright (c) 2026 atsushifx <http://github.com/atsushifx>
//
// Released under the MIT License.
// https://opensource.org/licenses/MIT

// test framework
import 'package:test/test.dart';

// test target
import 'package:w1_w7_verify/environment/notification_environment.dart';
import 'package:w1_w7_verify/errors.dart';
import 'package:w1_w7_verify/models.dart';
import 'package:w1_w7_verify/schedule/scheduling_service.dart';
import 'package:w1_w7_verify/schedule/toast_scheduler.dart';
import 'package:w1_w7_verify/tag/providers.dart';
import 'package:w1_w7_verify/tag/tag_allocator.dart';

// internal helpers
import '../fakes.dart';

/// AUMID used by every case.
const String _aumid = 'Kallr.Test';

/// Notification time `A1` (2026-11-22T12:00:00+09:00).
final DateTime _a1 = DateTime.parse('2026-11-22T12:00:00+09:00');

/// Tag allocated for the first registration (`ADD1`).
const String _add1 = '20261122100000-a1b2c3d4-0123456789abcdef';

/// Tag currently registered for b1/a1 before a replacement (`OLD`).
const String _old = '20261122090000-a1b2c3d4-0123456789abcdef';

/// Registration time of `OLD`.
final DateTime _oldRegisteredAt = DateTime(2026, 11, 22, 9);

/// Notification time of `OLD` (2026-11-22T11:00:00+09:00).
final DateTime _oldAt = DateTime.parse('2026-11-22T11:00:00+09:00');

/// Tag allocated when the first random value collides (`ADD2`).
const String _add2 = '20261122100000-a1b2c3d4-fedcba9876543210';

/// Tag of the pending row `PND` of a stopped replacement.
const String _pnd = '20261122093000-a1b2c3d4-0123456789abcdef';

/// Notification time of `PND` (2026-11-22T13:00:00+09:00).
final DateTime _pndAt = DateTime.parse('2026-11-22T13:00:00+09:00');

/// Result of a check that finds the AUMID unregistered.
const Availability _unregistered = Availability(
  registered: false,
  displayNameSet: false,
  ok: false,
  reason: 'AUMID が未登録',
);

/// Title mixing CJK, a space, a non-BMP emoji (surrogate pair) and accented Latin (SVA-57, SVA-58).
const String _mixedTitle = '会議 🔔 Ünï';

/// Fixed registration time of the clock.
final DateTime _now = DateTime(2026, 11, 22, 10);

/// Service under test with its fakes.
class _Fixture {
  /// Creates the fixture; [withOld] registers `OLD` for b1/a1 in the table and the scheduler.
  ///
  /// [oldAt] and [oldTitle] set the content of `OLD` (default: a different at and title).
  /// With [fired], `OLD` is only in the table: its toast already fired and left the scheduler.
  /// With [stoppedBeforeStage3] (P3), the replacement of `OLD` by `PND` stopped before stage 3:
  /// the table holds `OLD` superseded and `PND` pending, and the scheduler holds both.
  /// With [withDuplicateTag], the table already holds `ADD1` under b9/a9, so every
  /// Tag the fixed random source allocates for b1/a1 is a duplicate (table only).
  /// [firstQueueId] is the queue id the table assigns to the first replacement.
  /// [random] replaces the fixed random source (default: always `0123456789abcdef`).
  /// [availability] is what `env.check` returns.
  _Fixture({
    bool withOld = false,
    bool fired = false,
    bool stoppedBeforeStage3 = false,
    bool withDuplicateTag = false,
    int firstQueueId = 1,
    DateTime? oldAt,
    String oldTitle = 't0',
    RandomSourceProvider? random,
    Availability availability = const Availability.ok(),
  }) {
    env = FakeEnvironment(log, availability: availability);
    scheduler = MockToastScheduler(log);
    table = FakeMappingTable(log, firstQueueId: firstQueueId);
    service = SchedulingService(
      env: env,
      scheduler: scheduler,
      table: table,
      clock: FixedClock(_now),
      random: random ?? FixedRandom('0123456789abcdef'),
      machineId: FixedMachineId('a1b2c3d4'),
    );
    if (withDuplicateTag) {
      table.put(
        MappingRecord(
          batchId: 'b9',
          alarmId: 'a9',
          tag: _add1,
          at: _a1.toUtc(),
          title: 't9',
          registeredAt: _now,
        ),
      );
      log.clear();
    }
    final registeredOldAt = oldAt ?? _oldAt;
    if (withOld || stoppedBeforeStage3) {
      table.put(
        MappingRecord(
          batchId: 'b1',
          alarmId: 'a1',
          tag: _old,
          at: registeredOldAt.toUtc(),
          title: oldTitle,
          registeredAt: _oldRegisteredAt,
        ),
      );
      if (!fired) {
        scheduler.seed(
          ScheduledToast(tag: _old, group: 'kallr', at: registeredOldAt),
        );
      }
      if (stoppedBeforeStage3) {
        table.replace(
          MappingRecord(
            batchId: 'b1',
            alarmId: 'a1',
            tag: _pnd,
            at: _pndAt.toUtc(),
            title: '再開後',
            registeredAt: DateTime(2026, 11, 22, 9, 30),
          ),
        );
        scheduler.seed(ScheduledToast(tag: _pnd, group: 'kallr', at: _pndAt));
      }
      log.clear();
    }
  }

  final CallLog log = [];
  late final FakeEnvironment env;
  late final MockToastScheduler scheduler;
  late final FakeMappingTable table;
  late final SchedulingService service;

  /// Runs `add('b1', 'a1', A1, title, 'Kallr.Test')`.
  MappingRecord add({String title = 't1'}) => service.add(
    batchId: 'b1',
    alarmId: 'a1',
    at: _a1,
    title: title,
    aumid: _aumid,
  );
}

/// Tests for SchedulingService.add.
void main() {
  group('SchedulingService.add', () {
    /// Registration of a new key, and replacement of a key whose Tag is in the scheduler.
    group('T-WDV-SVA: add (new / replace)', () {
      group('When: 正常系', () {
        test('[Normal] T-WDV-SVA-01: 新しい MappingRecord を返す', () {
          final record = _Fixture().add();
          expect(
            record,
            MappingRecord(
              batchId: 'b1',
              alarmId: 'a1',
              tag: _add1,
              at: _a1.toUtc(),
              title: 't1',
              registeredAt: _now,
            ),
          );
        });

        test('[Normal] T-WDV-SVA-02: 予約一覧に新しい Tag の予約がちょうど 1 件できる', () {
          final f = _Fixture()..add();
          expect(f.scheduler.list('kallr'), [
            ScheduledToast(tag: _add1, group: 'kallr', at: _a1),
          ]);
        });

        test('[Normal] T-WDV-SVA-03: 対応表に add の返り値と同じ内容が記録される', () {
          final f = _Fixture();
          final record = f.add();
          expect(f.table.get('b1', 'a1'), record);
        });

        test('[Normal] T-WDV-SVA-04: 予約の追加は対応表の更新より先に行う', () {
          final f = _Fixture()..add();
          expect(f.log.where({'scheduler.add', 'table.put'}.contains), [
            'scheduler.add',
            'table.put',
          ]);
        });

        test('[Normal] T-WDV-SVA-05: 通知可否の確認に aumid を渡し、1 回だけ呼ぶ', () {
          final f = _Fixture()..add();
          expect(f.env.checked, [_aumid]);
        });

        test(
          '[Normal] T-WDV-SVA-06: 置換は OLD ではなく新しい Tag の MappingRecord を返す',
          () {
            final record = _Fixture(withOld: true).add(title: 't2');
            expect(
              record,
              MappingRecord(
                batchId: 'b1',
                alarmId: 'a1',
                tag: _add1,
                at: _a1.toUtc(),
                title: 't2',
                registeredAt: _now,
              ),
            );
          },
        );

        test('[Normal] T-WDV-SVA-07: 置換後の予約一覧に OLD が無く、新しい Tag の 1 件だけになる', () {
          final f = _Fixture(withOld: true)..add(title: 't2');
          expect(f.scheduler.list('kallr'), [
            ScheduledToast(tag: _add1, group: 'kallr', at: _a1),
          ]);
        });

        test('[Normal] T-WDV-SVA-08: 対応表は置換後の内容を current として持つ', () {
          final f = _Fixture(withOld: true);
          final record = f.add(title: 't2');
          expect(f.table.get('b1', 'a1'), record);
        });

        test('[Normal] T-WDV-SVA-09: 置換の完了後に保留が残らない', () {
          final f = _Fixture(withOld: true)..add(title: 't2');
          expect(f.table.pendingRemovals(), isEmpty);
        });

        test('[Normal] T-WDV-SVA-10: 置換は table.replace → scheduler.add → scheduler.remove → table.completeRemoval の順に呼ぶ', () {
          final f = _Fixture(withOld: true)..add(title: 't2');
          const stages = {
            'table.replace',
            'scheduler.add',
            'scheduler.remove',
            'table.completeRemoval',
          };
          expect(f.log.where(stages.contains), [
            'table.replace',
            'scheduler.add',
            'scheduler.remove',
            'table.completeRemoval',
          ]);
        });
      });

      /// A re-add with the same at and title is still a replace (SCH-E-09).
      group('When: エッジケース', () {
        test('[Edge] T-WDV-SVA-11: 同じ at と title の再 add でも新しい Tag を返す', () {
          final record = _Fixture(
            withOld: true,
            oldAt: _a1,
            oldTitle: 't1',
          ).add();
          expect(record.tag, _add1);
        });

        test(
          '[Edge] T-WDV-SVA-12: 同じ at と title の再 add 後、予約一覧は新しい Tag の 1 件だけになる',
          () {
            final f = _Fixture(withOld: true, oldAt: _a1, oldTitle: 't1')
              ..add();
            expect(f.scheduler.list('kallr'), [
              ScheduledToast(tag: _add1, group: 'kallr', at: _a1),
            ]);
          },
        );
      });

      /// The generated Tag collides only with a Tag in the scheduler list; add draws again (SCH-R-007, D8: scheduler list and table).
      group('When: 生成した Tag が予約一覧にだけある Tag と重複する', () {
        _Fixture schedulerOnlyDuplicate() {
          final f = _Fixture(
            random: SequenceRandom(['0123456789abcdef', 'fedcba9876543210']),
          );
          f.scheduler.seed(ScheduledToast(tag: _add1, group: 'kallr', at: _a1));
          return f;
        }

        test('[Edge] T-WDV-SVA-49: 乱数を再生成した Tag (ADD2) を使う', () {
          final f = schedulerOnlyDuplicate();
          final record = f.add();
          expect(record.tag, _add2);
          expect(f.scheduler.list('kallr').map((t) => t.tag), [_add1, _add2]);
        });
      });

      /// The generated Tag collides only with a Tag in the mapping table (its toast already fired); add draws again (SCH-E-32, D8).
      group('When: 生成した Tag が対応表にだけある Tag と重複する', () {
        test('[Edge] T-WDV-SVA-52: 乱数を再生成した Tag (ADD2) を使い、対応表に保存する', () {
          final f = _Fixture(
            withDuplicateTag: true,
            random: SequenceRandom(['0123456789abcdef', 'fedcba9876543210']),
          );
          final record = f.add();
          expect(record.tag, _add2);
          expect(f.table.get('b1', 'a1'), record);
          expect(f.scheduler.list('kallr').map((t) => t.tag), [_add2]);
        });
      });

      /// A mapping row whose toast is gone from the scheduler already fired: add registers it as new (SCH-E-08).
      group('When: 発火済み', () {
        test('[Normal] T-WDV-SVA-13: 発火済みの項目は新しい Tag の MappingRecord を返す', () {
          final record = _Fixture(withOld: true, fired: true).add();
          expect(record.tag, _add1);
        });

        test('[Normal] T-WDV-SVA-14: 発火済みの項目は新しい内容で上書きされる', () {
          final f = _Fixture(withOld: true, fired: true)..add(title: 't2');
          expect(
            f.table.get('b1', 'a1'),
            MappingRecord(
              batchId: 'b1',
              alarmId: 'a1',
              tag: _add1,
              at: _a1.toUtc(),
              title: 't2',
              registeredAt: _now,
            ),
          );
        });

        test('[Normal] T-WDV-SVA-15: 発火済みの項目は置換の手順を行わない', () {
          final f = _Fixture(withOld: true, fired: true)..add();
          expect(
            f.log.where({'table.replace', 'scheduler.remove'}.contains),
            isEmpty,
          );
        });

        test(
          '[Normal] T-WDV-SVA-16: 発火済みの項目の add 後、予約一覧は新しい Tag の 1 件だけになる',
          () {
            final f = _Fixture(withOld: true, fired: true)..add();
            expect(f.scheduler.list('kallr'), [
              ScheduledToast(tag: _add1, group: 'kallr', at: _a1),
            ]);
          },
        );
      });

      /// A failed availability check stops add before any side effect (SCH-R-003, SCH-E-06, IDX-R-001).
      group('When: 通知できない', () {
        test(
          '[Error] T-WDV-SVA-17: 通知可否の確認の結果を持つ UnavailableException を投げる',
          () {
            final f = _Fixture(availability: _unregistered);
            expect(
              f.add,
              throwsA(
                isA<UnavailableException>().having(
                  (e) => e.availability,
                  'availability',
                  same(_unregistered),
                ),
              ),
            );
          },
        );

        test('[Error] T-WDV-SVA-18: OS の予約を一切呼ばない', () {
          final f = _Fixture(availability: _unregistered);
          expect(f.add, throwsA(isA<UnavailableException>()));
          expect(f.log.where((c) => c.startsWith('scheduler.')), isEmpty);
        });

        test('[Error] T-WDV-SVA-19: 対応表を一切呼ばない', () {
          final f = _Fixture(availability: _unregistered);
          expect(f.add, throwsA(isA<UnavailableException>()));
          expect(f.log.where((c) => c.startsWith('table.')), isEmpty);
        });

        test('[Error] T-WDV-SVA-20: 保留の再開もしない (P3 のまま残る)', () {
          final f = _Fixture(
            stoppedBeforeStage3: true,
            availability: _unregistered,
          );
          expect(f.add, throwsA(isA<UnavailableException>()));
          expect(f.table.pendingRemovals(), hasLength(1));
          expect(f.scheduler.list('kallr').map((t) => t.tag), [_old, _pnd]);
        });
      });

      /// The OS rejects a past `at`; add propagates the error and leaves the table alone (SCH-E-04, SCH-DD-05).
      group('When: OS が過去の at を拒否する', () {
        test(
          '[Error] T-WDV-SVA-21: hresult 0x80070057 の ScheduleException を投げる',
          () {
            final f = _Fixture()
              ..scheduler.failNext(ToastOp.add, Hresult.invalidArgument);
            expect(
              f.add,
              throwsA(
                isA<ScheduleException>().having(
                  (e) => e.hresult,
                  'hresult',
                  Hresult.invalidArgument,
                ),
              ),
            );
          },
        );

        test('[Error] T-WDV-SVA-22: 対応表を変えない', () {
          final f = _Fixture()
            ..scheduler.failNext(ToastOp.add, Hresult.invalidArgument);
          expect(f.add, throwsA(isA<ScheduleException>()));
          expect(f.table.get('b1', 'a1'), isNull);
          expect(f.log, isNot(contains('table.put')));
        });
      });

      /// The OS rejects a new registration over its toast limit; add propagates the error (SCH-E-16).
      group('When: OS が予約件数の上限超過を拒否する', () {
        test(
          '[Error] T-WDV-SVA-23: hresult 0x80070718 の ScheduleException を投げる',
          () {
            final f = _Fixture()
              ..scheduler.failNext(ToastOp.add, Hresult.tooManyToasts);
            expect(
              f.add,
              throwsA(
                isA<ScheduleException>().having(
                  (e) => e.hresult,
                  'hresult',
                  Hresult.tooManyToasts,
                ),
              ),
            );
          },
        );
      });

      /// The table write fails after the OS registration; add propagates the error and keeps the toast (SCH-E-14, SCH-R-010).
      group('When: 新規の予約の後に対応表の書き込みが失敗する', () {
        _Fixture failingPut() =>
            _Fixture()..table.failNextPut(const StorageException('disk full'));

        test('[Error] T-WDV-SVA-24: StorageException をそのまま投げる', () {
          expect(failingPut().add, throwsA(isA<StorageException>()));
        });

        test('[Error] T-WDV-SVA-25: 追加した予約は巻き戻さず残る', () {
          final f = failingPut();
          expect(f.add, throwsA(isA<StorageException>()));
          expect(f.scheduler.list('kallr').map((t) => t.tag), [_add1]);
          expect(f.log, isNot(contains('scheduler.remove')));
        });

        test('[Error] T-WDV-SVA-26: 対応表には項目が無い', () {
          final f = failingPut();
          expect(f.add, throwsA(isA<StorageException>()));
          expect(f.table.get('b1', 'a1'), isNull);
        });

        /// orphan 判定そのものは T-WDV-SVL-03 が検証する。ここは add 失敗後のシナリオを確かめる。
        test('[Error] T-WDV-SVA-27: 続く list は残った予約を orphan として検出する', () {
          final f = failingPut();
          expect(f.add, throwsA(isA<StorageException>()));
          final entries = f.service.list();
          expect(entries.map((e) => (e.toast?.tag, e.state)), [
            (_add1, EntryState.orphan),
          ]);
        });
      });

      /// Every allocated Tag is already in the table; add gives up after the retry limit (SCH-R-007, SCH-E-15).
      group('When: Tag の重複が上限の後も続く', () {
        test('[Error] T-WDV-SVA-28: DuplicateTagException を投げる', () {
          final f = _Fixture(withDuplicateTag: true);
          expect(
            f.add,
            throwsA(
              isA<DuplicateTagException>().having(
                (e) => e.attempts,
                'attempts',
                kMaxTagAttempts,
              ),
            ),
          );
        });

        test('[Error] T-WDV-SVA-29: OS の予約を作らない', () {
          final f = _Fixture(withDuplicateTag: true);
          expect(f.add, throwsA(isA<DuplicateTagException>()));
          expect(f.log, isNot(contains('scheduler.add')));
          expect(f.scheduler.list('kallr'), isEmpty);
        });

        test('[Error] T-WDV-SVA-30: 対応表を書き換えない', () {
          final f = _Fixture(withDuplicateTag: true);
          expect(f.add, throwsA(isA<DuplicateTagException>()));
          expect(f.log.where({'table.put', 'table.replace'}.contains), isEmpty);
          expect(f.table.get('b1', 'a1'), isNull);
        });
      });

      /// Stage 1 of a replacement (table.replace) fails; add propagates the error before touching the OS schedule (SCH-E-11, SCH-DD-01).
      group('When: 置換の段階 1 (DB への記録) が失敗する', () {
        _Fixture failingReplace() =>
            _Fixture(withOld: true)
              ..table.failNextReplace(const StorageException('disk full'));

        test('[Error] T-WDV-SVA-31: StorageException をそのまま投げる', () {
          expect(
            failingReplace().add,
            throwsA(
              isA<StorageException>().having(
                (e) => e.message,
                'message',
                'disk full',
              ),
            ),
          );
        });

        test('[Error] T-WDV-SVA-32: OS の予約を追加も削除もしない', () {
          final f = failingReplace();
          expect(f.add, throwsA(isA<StorageException>()));
          expect(
            f.log.where({'scheduler.add', 'scheduler.remove'}.contains),
            isEmpty,
          );
        });

        test('[Error] T-WDV-SVA-33: 予約一覧には OLD の 1 件だけが残る', () {
          final f = failingReplace();
          expect(f.add, throwsA(isA<StorageException>()));
          expect(f.scheduler.list('kallr').map((t) => t.tag), [_old]);
        });

        test('[Error] T-WDV-SVA-34: 対応表は OLD の行を current のまま持つ', () {
          final f = failingReplace();
          expect(f.add, throwsA(isA<StorageException>()));
          expect(f.table.pendingRemovals(), isEmpty);
          expect(f.table.get('b1', 'a1')?.tag, _old);
        });
      });

      /// Stage 2 of a replacement (scheduler.add) is rejected by the OS; add aborts stage 1 and propagates the error (SCH-E-10, SCH-R-010).
      group('When: 置換の段階 2 (OS の追加) を OS が拒否する', () {
        _Fixture rejectingAdd({int firstQueueId = 1}) =>
            _Fixture(withOld: true, firstQueueId: firstQueueId)
              ..scheduler.failNext(ToastOp.add, Hresult.invalidArgument);

        test('[Error] T-WDV-SVA-35: ScheduleException をそのまま投げる', () {
          expect(
            rejectingAdd().add,
            throwsA(
              isA<ScheduleException>().having(
                (e) => e.hresult,
                'hresult',
                Hresult.invalidArgument,
              ),
            ),
          );
        });

        test('[Error] T-WDV-SVA-36: replace の queueId で abortReplacement を 1 回だけ呼ぶ', () {
          final f = rejectingAdd(firstQueueId: 7);
          expect(f.add, throwsA(isA<ScheduleException>()));
          expect(f.table.aborted, [7]);
          expect(
            f.log.where((c) => c == 'table.abortReplacement'),
            hasLength(1),
          );
        });

        test('[Error] T-WDV-SVA-37: 対応表は OLD の行を current に戻す', () {
          final f = rejectingAdd();
          expect(f.add, throwsA(isA<ScheduleException>()));
          expect(f.table.get('b1', 'a1')?.tag, _old);
        });

        test('[Error] T-WDV-SVA-38: 保留が残らない', () {
          final f = rejectingAdd();
          expect(f.add, throwsA(isA<ScheduleException>()));
          expect(f.table.pendingRemovals(), isEmpty);
        });

        test('[Error] T-WDV-SVA-39: 予約一覧には OLD の 1 件だけが残る', () {
          final f = rejectingAdd();
          expect(f.add, throwsA(isA<ScheduleException>()));
          expect(f.scheduler.list('kallr').map((t) => t.tag), [_old]);
        });

        test('[Error] T-WDV-SVA-40: OLD の予約を削除しない', () {
          final f = rejectingAdd();
          expect(f.add, throwsA(isA<ScheduleException>()));
          expect(f.log, isNot(contains('scheduler.remove')));
        });

        test('[Error] T-WDV-SVA-51: ScheduleException 以外の例外は巻き戻さずそのまま投げる', () {
          final f = _Fixture(withOld: true)
            ..scheduler.failNextWith(ToastOp.add, StateError('bug'));
          expect(f.add, throwsA(isA<StateError>()));
          expect(f.table.aborted, isEmpty);
          expect(f.log, isNot(contains('table.abortReplacement')));
          expect(f.table.pendingRemovals(), hasLength(1));
        });
      });

      /// Stage 3 of a replacement (scheduler.remove) fails; add propagates the error and keeps the pending row, with no rollback (SCH-E-12, SCH-DD-01).
      group('When: 置換の段階 3 (置換前の予約の削除) が失敗する', () {
        _Fixture failingRemove() =>
            _Fixture(withOld: true)
              ..scheduler.failNext(ToastOp.remove, Hresult.invalidArgument);

        test('[Error] T-WDV-SVA-41: ScheduleException をそのまま投げる', () {
          expect(
            failingRemove().add,
            throwsA(
              isA<ScheduleException>().having(
                (e) => e.hresult,
                'hresult',
                Hresult.invalidArgument,
              ),
            ),
          );
        });

        test('[Error] T-WDV-SVA-42: 予約一覧には OLD と新しい Tag の 2 件が残る', () {
          final f = failingRemove();
          expect(f.add, throwsA(isA<ScheduleException>()));
          expect(f.scheduler.list('kallr').map((t) => t.tag), [_old, _add1]);
        });

        test('[Error] T-WDV-SVA-43: 保留が置換キューに 1 件残る', () {
          final f = failingRemove();
          expect(f.add, throwsA(isA<ScheduleException>()));
          expect(f.table.pendingRemovals(), hasLength(1));
        });

        test('[Error] T-WDV-SVA-44: 段階 4 (completeRemoval) に進まない', () {
          final f = failingRemove();
          expect(f.add, throwsA(isA<ScheduleException>()));
          expect(f.log, isNot(contains('table.completeRemoval')));
        });

        test('[Error] T-WDV-SVA-45: 段階 1 を巻き戻さない (abortReplacement を呼ばない)', () {
          final f = failingRemove();
          expect(f.add, throwsA(isA<ScheduleException>()));
          expect(f.table.aborted, isEmpty);
          expect(f.log, isNot(contains('table.abortReplacement')));
        });
      });

      /// Stage 4 of a replacement (table.completeRemoval) fails; add propagates the error and keeps the pending row, with no rollback (SCH-E-12, SCH-DD-01).
      group('When: 置換の段階 4 (DB の完了) が失敗する', () {
        _Fixture failingComplete() => _Fixture(withOld: true)
          ..table.failNextCompleteRemoval(const StorageException('disk full'));

        test('[Error] T-WDV-SVA-46: StorageException をそのまま投げる', () {
          expect(
            failingComplete().add,
            throwsA(
              isA<StorageException>().having(
                (e) => e.message,
                'message',
                'disk full',
              ),
            ),
          );
        });

        test('[Error] T-WDV-SVA-47: 予約一覧には ADD1 の 1 件だけが残る', () {
          final f = failingComplete();
          expect(f.add, throwsA(isA<StorageException>()));
          expect(f.scheduler.list('kallr').map((t) => t.tag), [_add1]);
        });

        test('[Error] T-WDV-SVA-48: 保留が置換キューに 1 件残る', () {
          final f = failingComplete();
          expect(f.add, throwsA(isA<StorageException>()));
          expect(f.table.pendingRemovals(), hasLength(1));
        });

        test('[Error] T-WDV-SVA-50: 段階 1 を巻き戻さない (abortReplacement を呼ばない)', () {
          final f = failingComplete();
          expect(f.add, throwsA(isA<StorageException>()));
          expect(f.table.aborted, isEmpty);
          expect(f.log, isNot(contains('table.abortReplacement')));
        });
      });

      /// A UTF-8 (non-ASCII) title is passed to the OS and returned unchanged (SCH-E-23, REQ-NF-004).
      group('When: UTF-8 の title を渡す', () {
        const title = '会議の開始';

        test('[Normal] T-WDV-SVA-53: OS の追加に title をそのまま渡す', () {
          final f = _Fixture()..add(title: title);
          expect(f.scheduler.addedTitles, [title]);
        });

        test('[Normal] T-WDV-SVA-54: 返り値の title も同じである', () {
          final record = _Fixture().add(title: title);
          expect(record.title, title);
        });

        test(
          '[Normal] T-WDV-SVA-54-01: 保存された MappingRecord の title も同じである',
          () {
            final f = _Fixture()..add(title: title);
            expect(f.table.get('b1', 'a1')?.title, title);
          },
        );

        test('[Normal] T-WDV-SVA-55: 置換でも OS の追加に title をそのまま渡す', () {
          final f = _Fixture(withOld: true)..add(title: title);
          expect(f.scheduler.addedTitles, [title]);
        });

        test('[Normal] T-WDV-SVA-56: 置換の返り値の title も同じである', () {
          final record = _Fixture(withOld: true).add(title: title);
          expect(record.title, title);
        });

        test(
          '[Edge] T-WDV-SVA-57: 絵文字 (サロゲートペア) を含む title を OS の追加にそのまま渡す',
          () {
            final f = _Fixture()..add(title: _mixedTitle);
            expect(f.scheduler.addedTitles, [_mixedTitle]);
          },
        );

        test('[Edge] T-WDV-SVA-58: 絵文字を含む title の返り値も同じである', () {
          final record = _Fixture().add(title: _mixedTitle);
          expect(record.title, _mixedTitle);
        });
      });

      /// OLD fires between the list read and stage 3, so scheduler.remove returns false; add treats it as success (SCH-E-13, SCH-R-030, SCH-DD-13).
      group('When: 置換の途中で置換前の予約が発火済みになる', () {
        _Fixture firedDuringReplace() =>
            _Fixture(withOld: true)..scheduler.fireBeforeRemove(_old);

        test(
          '[Normal] T-WDV-SVA-59: 例外を投げず新しい Tag (ADD1) の MappingRecord を返す',
          () {
            final record = firedDuringReplace().add();
            expect(record.tag, _add1);
          },
        );

        test('[Normal] T-WDV-SVA-60: 段階 4 (completeRemoval) まで完了し、保留が残らない', () {
          final f = firedDuringReplace()..add();
          expect(f.log, contains('table.completeRemoval'));
          expect(f.table.pendingRemovals(), isEmpty);
        });

        test('[Normal] T-WDV-SVA-61: 予約一覧には ADD1 の 1 件だけが残る', () {
          final f = firedDuringReplace()..add();
          expect(f.scheduler.list('kallr').map((t) => t.tag), [_add1]);
        });

        test('[Normal] T-WDV-SVA-62: 置換前の予約の削除を OS に 1 回だけ依頼する', () {
          final f = firedDuringReplace()..add();
          expect(f.log.where((c) => c == 'scheduler.remove'), hasLength(1));
        });
      });
    });
  });
}
