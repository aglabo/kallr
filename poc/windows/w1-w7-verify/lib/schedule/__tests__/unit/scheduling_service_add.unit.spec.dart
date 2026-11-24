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
  /// [availability] is what `env.check` returns.
  _Fixture({
    bool withOld = false,
    bool fired = false,
    bool stoppedBeforeStage3 = false,
    bool withDuplicateTag = false,
    DateTime? oldAt,
    String oldTitle = 't0',
    Availability availability = const Availability.ok(),
  }) {
    env = FakeEnvironment(log, availability: availability);
    scheduler = MockToastScheduler(log);
    table = FakeMappingTable(log);
    service = SchedulingService(
      env: env,
      scheduler: scheduler,
      table: table,
      clock: FixedClock(_now),
      random: FixedRandom('0123456789abcdef'),
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
    });
  });
}
