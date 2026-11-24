// src: lib/schedule/__tests__/unit/scheduling_service_list.unit.spec.dart
// @(#) : unit tests for SchedulingService.list (merged view of table and scheduler)
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

/// Tag of the record `OK` that has a toast in the scheduler.
const String _ok = '20261122090000-a1b2c3d4-0123456789abcdef';

/// Tag of the record `STL` whose toast is gone from the scheduler.
const String _stl = '20261122091000-a1b2c3d4-0123456789abcdef';

/// Tag of a toast that the table does not know at all (`ORP`).
const String _orp = '20261122092000-a1b2c3d4-0123456789abcdef';

/// Tag of the pending row `PND` of a stopped replacement.
const String _pnd = '20261122093000-a1b2c3d4-0123456789abcdef';

/// Notification time shared by every record and toast.
final DateTime _at = DateTime.parse('2026-11-22T12:00:00+09:00');

/// Registration time shared by every record.
final DateTime _registeredAt = DateTime(2026, 11, 22, 9);

/// Builds the record for [alarmId] under batch b1 with [tag].
MappingRecord _record(String alarmId, String tag) => MappingRecord(
  batchId: 'b1',
  alarmId: alarmId,
  tag: tag,
  at: _at.toUtc(),
  title: 't-$alarmId',
  registeredAt: _registeredAt,
);

/// Builds the scheduled toast for [tag] in the kallr group.
ScheduledToast _toast(String tag) =>
    ScheduledToast(tag: tag, group: 'kallr', at: _at);

/// Reduces [entries] to (state, record, toast) tuples, since ScheduleEntry has no value equality.
List<(EntryState, MappingRecord?, ScheduledToast?)> _summary(
  List<ScheduleEntry> entries,
) => [for (final e in entries) (e.state, e.record, e.toast)];

/// Service under test with its fakes; the table and the scheduler start empty.
class _Fixture {
  /// Creates the fixture with an empty table and an empty scheduler.
  _Fixture() {
    scheduler = MockToastScheduler(log);
    table = FakeMappingTable(log);
    service = SchedulingService(
      env: FakeEnvironment(log),
      scheduler: scheduler,
      table: table,
      clock: FixedClock(_registeredAt),
      random: FixedRandom('0123456789abcdef'),
      machineId: FixedMachineId('a1b2c3d4'),
    );
  }

  final CallLog log = [];
  late final MockToastScheduler scheduler;
  late final FakeMappingTable table;
  late final SchedulingService service;

  /// Puts the record for [alarmId] with [tag] into the table.
  void putRecord(String alarmId, String tag) =>
      table.put(_record(alarmId, tag));

  /// Puts the toast with [tag] into the scheduler.
  void seedToast(String tag) => scheduler.seed(_toast(tag));
}

/// Tests for SchedulingService.list.
void main() {
  group('SchedulingService.list', () {
    /// Merges the table records and the scheduler toasts into ok / stale / orphan entries.
    group('T-WDV-SVL: list', () {
      group('When: 正常系', () {
        test('[Normal] T-WDV-SVL-01: 同じ Tag の予約がある record は ok で record と toast を持つ', () {
          final f = _Fixture()
            ..putRecord('a1', _ok)
            ..seedToast(_ok);
          expect(_summary(f.service.list()), [
            (EntryState.ok, _record('a1', _ok), _toast(_ok)),
          ]);
        });

        test('[Normal] T-WDV-SVL-02: 予約が無い record は stale で toast を持たない', () {
          final f = _Fixture()..putRecord('a1', _stl);
          expect(_summary(f.service.list()), [
            (EntryState.stale, _record('a1', _stl), null),
          ]);
        });

        /// list の orphan 判定の規則そのもの。add 失敗後のシナリオは T-WDV-SVA-27。
        test('[Normal] T-WDV-SVL-03: 対応表に無い予約は orphan で record を持たない', () {
          final f = _Fixture()..seedToast(_orp);
          expect(_summary(f.service.list()), [
            (EntryState.orphan, null, _toast(_orp)),
          ]);
        });
      });

      /// A replacement stopped before stage 3 leaves the superseded toast awaiting removal.
      group('When: エッジケース', () {
        test(
          '[Edge] T-WDV-SVL-04: 置換途中の旧予約は一覧に出ず、新 (pending) record 側だけが出る',
          () {
            final f = _Fixture()
              ..putRecord('a1', _ok)
              ..seedToast(_ok);
            f.table.replace(_record('a1', _pnd));
            f.seedToast(_pnd);
            expect(_summary(f.service.list()), [
              (EntryState.ok, _record('a1', _pnd), _toast(_pnd)),
            ]);
          },
        );

        test('[Edge] T-WDV-SVL-05: 対応表も予約も空なら空リストを返す', () {
          expect(_Fixture().service.list(), isEmpty);
        });

        test('[Edge] T-WDV-SVL-06: ok / stale / orphan が混在すると record 順の後に orphan が続く', () {
          final f = _Fixture()
            ..seedToast(_orp)
            ..putRecord('a1', _ok)
            ..putRecord('a2', _stl)
            ..seedToast(_ok);
          expect(
            f.service.list().map(
              (e) => (e.state, e.record?.tag ?? e.toast!.tag),
            ),
            [
              (EntryState.ok, _ok),
              (EntryState.stale, _stl),
              (EntryState.orphan, _orp),
            ],
          );
        });
      });
    });
  });
}
