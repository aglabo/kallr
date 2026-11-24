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
import 'package:w1_w7_verify/models.dart';
import 'package:w1_w7_verify/schedule/scheduling_service.dart';
import 'package:w1_w7_verify/schedule/toast_scheduler.dart';

// internal helpers
import '../fakes.dart';

/// AUMID used by every case.
const String _aumid = 'Kallr.Test';

/// Notification time `A1` (2026-11-22T12:00:00+09:00).
final DateTime _a1 = DateTime.parse('2026-11-22T12:00:00+09:00');

/// Tag allocated for the first registration (`ADD1`).
const String _add1 = '20261122100000-a1b2c3d4-0123456789abcdef';

/// Fixed registration time of the clock.
final DateTime _now = DateTime(2026, 11, 22, 10);

/// Service under test with its fakes.
class _Fixture {
  _Fixture() {
    env = FakeEnvironment(log);
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
  }

  final CallLog log = [];
  late final FakeEnvironment env;
  late final MockToastScheduler scheduler;
  late final FakeMappingTable table;
  late final SchedulingService service;

  /// Runs `add('b1', 'a1', A1, 't1', 'Kallr.Test')`.
  MappingRecord add() => service.add(
    batchId: 'b1',
    alarmId: 'a1',
    at: _a1,
    title: 't1',
    aumid: _aumid,
  );
}

/// Tests for SchedulingService.add.
void main() {
  group('SchedulingService.add', () {
    /// Registration of a key that is not in the mapping table.
    group('T-WDV-SVA: add (new)', () {
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
      });
    });
  });
}
