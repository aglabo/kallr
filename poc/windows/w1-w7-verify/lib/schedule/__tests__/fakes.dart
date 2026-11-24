// src: lib/schedule/__tests__/fakes.dart
// @(#) : Fakes shared by SchedulingService tests
//
// Copyright (c) 2026 atsushifx <http://github.com/atsushifx>
//
// Released under the MIT License.
// https://opensource.org/licenses/MIT

import 'package:w1_w7_verify/environment/notification_environment.dart';
import 'package:w1_w7_verify/models.dart';
import 'package:w1_w7_verify/schedule/clock_provider.dart';
import 'package:w1_w7_verify/schedule/toast_scheduler.dart';
import 'package:w1_w7_verify/store/mapping_table.dart';
import 'package:w1_w7_verify/tag/providers.dart';

/// Ordered record of the calls made to the fakes that share it.
typedef CallLog = List<String>;

/// Fake environment that always reports an available environment and logs `env.check`.
class FakeEnvironment implements NotificationEnvironment {
  /// Creates the fake; [log] receives one entry per call.
  FakeEnvironment(this.log);

  /// Shared call log.
  final CallLog log;

  /// AUMIDs passed to [check], in call order.
  final List<String> checked = [];

  @override
  Availability check(String aumid) {
    checked.add(aumid);
    log.add('env.check');
    return const Availability.ok();
  }
}

/// In-memory [ToastScheduler] that logs calls.
class MockToastScheduler implements ToastScheduler {
  /// Creates an empty scheduler; [log] receives one entry per call.
  MockToastScheduler(this.log);

  /// Shared call log.
  final CallLog log;

  final List<ScheduledToast> _toasts = [];

  @override
  void add({
    required String tag,
    required String group,
    required DateTime at,
    required String title,
  }) {
    log.add('scheduler.add');
    _toasts.add(ScheduledToast(tag: tag, group: group, at: at));
  }

  @override
  List<ScheduledToast> list(String group) {
    log.add('scheduler.list');
    return _toasts.where((t) => t.group == group).toList();
  }
}

/// In-memory [MappingTable] that logs calls. Only the methods the add path needs are implemented.
class FakeMappingTable implements MappingTable {
  /// Creates an empty table; [log] receives one entry per call.
  FakeMappingTable(this.log);

  /// Shared call log.
  final CallLog log;

  final Map<(String, String), MappingRecord> _rows = {};

  @override
  MappingRecord? get(String batchId, String alarmId) {
    log.add('table.get');
    return _rows[(batchId, alarmId)];
  }

  @override
  void put(MappingRecord record) {
    log.add('table.put');
    _rows[(record.batchId, record.alarmId)] = record;
  }

  @override
  Set<String> tags() {
    log.add('table.tags');
    return _rows.values.map((r) => r.tag).toSet();
  }

  @override
  dynamic noSuchMethod(Invocation invocation) =>
      throw UnimplementedError('${invocation.memberName}');
}

/// Clock fixed at one time.
class FixedClock implements ClockProvider {
  /// Creates a clock that always returns [value].
  FixedClock(this._value);

  final DateTime _value;

  @override
  DateTime now() => _value;
}

/// Random source returning a fixed value.
class FixedRandom implements RandomSourceProvider {
  /// Creates a source that returns [value].
  FixedRandom(this.value);

  /// Returned value.
  final String value;

  @override
  String randomHex64() => value;
}

/// Machine id provider returning a fixed id.
class FixedMachineId implements MachineIdProvider {
  /// Creates a provider that returns [id].
  FixedMachineId(this.id);

  /// Returned id.
  final String id;

  @override
  String machineId() => id;
}
