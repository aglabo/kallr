// src: lib/schedule/__tests__/fakes.dart
// @(#) : Fakes shared by SchedulingService tests
//
// Copyright (c) 2026 atsushifx <http://github.com/atsushifx>
//
// Released under the MIT License.
// https://opensource.org/licenses/MIT

import 'package:w1_w7_verify/environment/notification_environment.dart';
import 'package:w1_w7_verify/errors.dart';
import 'package:w1_w7_verify/models.dart';
import 'package:w1_w7_verify/schedule/clock_provider.dart';
import 'package:w1_w7_verify/schedule/toast_scheduler.dart';
import 'package:w1_w7_verify/store/mapping_table.dart';
import 'package:w1_w7_verify/tag/providers.dart';

/// Ordered record of the calls made to the fakes that share it.
typedef CallLog = List<String>;

/// Fake environment that reports a fixed [Availability] and logs `env.check`.
/// Only `check`, the method the add path needs, is implemented.
class FakeEnvironment implements NotificationEnvironment {
  /// Creates the fake; [log] receives one entry per call.
  ///
  /// [availability] is what [check] returns (default: an available environment).
  FakeEnvironment(this.log, {this.availability = const Availability.ok()});

  /// Result returned by [check].
  final Availability availability;

  /// Shared call log.
  final CallLog log;

  /// AUMIDs passed to [check], in call order.
  final List<String> checked = [];

  @override
  Availability check(String aumid) {
    checked.add(aumid);
    log.add('env.check');
    return availability;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) =>
      throw UnimplementedError('${invocation.memberName}');
}

/// Operation of [ToastScheduler] that [MockToastScheduler.failNext] can make fail.
enum ToastOp { add, remove, list }

/// In-memory [ToastScheduler] that logs calls.
class MockToastScheduler implements ToastScheduler {
  /// Creates an empty scheduler; [log] receives one entry per call.
  MockToastScheduler(this.log);

  /// Shared call log.
  final CallLog log;

  /// Titles passed to [add], in call order (recorded even when the call then fails).
  final List<String> addedTitles = [];

  final List<ScheduledToast> _toasts = [];
  final Map<ToastOp, int> _failures = {};
  final Map<ToastOp, Object> _errors = {};
  final Set<String> _firedBeforeRemove = {};

  /// Makes the next [remove] of [tag] behave as if its toast fired just before the call
  /// (once; the toast leaves the list if present, [remove] returns false, the call is still logged).
  void fireBeforeRemove(String tag) => _firedBeforeRemove.add(tag);

  /// Makes the next [op] throw `ScheduleException(hresult)` (once; the call is still logged).
  void failNext(ToastOp op, int hresult) => _failures[op] = hresult;

  /// Makes the next [op] throw [error] as is (once; the call is still logged).
  void failNextWith(ToastOp op, Object error) => _errors[op] = error;

  void _throwIfFailing(ToastOp op) {
    final error = _errors.remove(op);
    if (error != null) throw error;
    final hresult = _failures.remove(op);
    if (hresult != null) throw ScheduleException(hresult);
  }

  @override
  void add({
    required String tag,
    required String group,
    required DateTime at,
    required String title,
  }) {
    log.add('scheduler.add');
    addedTitles.add(title);
    _throwIfFailing(ToastOp.add);
    _toasts.add(ScheduledToast(tag: tag, group: group, at: at));
  }

  @override
  bool remove(String tag, String group) {
    log.add('scheduler.remove');
    _throwIfFailing(ToastOp.remove);
    if (_firedBeforeRemove.remove(tag)) {
      _toasts.removeWhere((t) => t.tag == tag && t.group == group);
      return false;
    }
    final before = _toasts.length;
    _toasts.removeWhere((t) => t.tag == tag && t.group == group);
    return _toasts.length < before;
  }

  /// Puts [toast] into the scheduled list without logging (test setup).
  void seed(ScheduledToast toast) => _toasts.add(toast);

  @override
  List<ScheduledToast> list(String group) {
    log.add('scheduler.list');
    _throwIfFailing(ToastOp.list);
    return _toasts.where((t) => t.group == group).toList();
  }
}

/// In-memory [MappingTable] that logs calls. Only the methods the add path needs are implemented.
///
/// Superseded rows stay in [tags] until the removal completes, like the real table.
class FakeMappingTable implements MappingTable {
  /// Creates an empty table; [log] receives one entry per call.
  ///
  /// [firstQueueId] is the id the first [replace] returns (default 1).
  FakeMappingTable(this.log, {int firstQueueId = 1})
    : _lastQueueId = firstQueueId - 1;

  /// Shared call log.
  final CallLog log;

  final Map<(String, String), MappingRecord> _rows = {};
  final Map<int, MappingRecord> _superseded = {};
  final Map<int, MappingRecord> _queue = {};
  int _lastQueueId;

  @override
  MappingRecord? get(String batchId, String alarmId) {
    log.add('table.get');
    return _rows[(batchId, alarmId)];
  }

  StorageException? _putFailure;

  /// Makes the next [put] throw [error] (once; the call is still logged).
  void failNextPut(StorageException error) => _putFailure = error;

  @override
  void put(MappingRecord record) {
    log.add('table.put');
    final failure = _putFailure;
    if (failure != null) {
      _putFailure = null;
      throw failure;
    }
    _rows[(record.batchId, record.alarmId)] = record;
  }

  StorageException? _replaceFailure;

  /// Makes the next [replace] throw [error] (once; the call is still logged, rows and queue stay unchanged).
  void failNextReplace(StorageException error) => _replaceFailure = error;

  @override
  int replace(MappingRecord record) {
    log.add('table.replace');
    final failure = _replaceFailure;
    if (failure != null) {
      _replaceFailure = null;
      throw failure;
    }
    final old = _rows[(record.batchId, record.alarmId)];
    if (old == null) throw const StorageException('no current record');
    final queueId = ++_lastQueueId;
    _superseded[queueId] = old;
    _rows[(record.batchId, record.alarmId)] = record;
    _queue[queueId] = record;
    return queueId;
  }

  @override
  List<PendingRemoval> pendingRemovals() {
    log.add('table.pendingRemovals');
    return [
      for (final MapEntry(:key, :value) in _queue.entries)
        PendingRemoval(
          queueId: key,
          oldTag: _superseded[key]!.tag,
          group: kGroup,
          record: value,
        ),
    ];
  }

  StorageException? _completeRemovalFailure;

  /// Makes the next [completeRemoval] throw [error] (once; the call is still logged, rows and queue stay unchanged).
  void failNextCompleteRemoval(StorageException error) =>
      _completeRemovalFailure = error;

  @override
  void completeRemoval(int queueId) {
    log.add('table.completeRemoval');
    final failure = _completeRemovalFailure;
    if (failure != null) {
      _completeRemovalFailure = null;
      throw failure;
    }
    _queue.remove(queueId);
    _superseded.remove(queueId);
  }

  /// Queue ids passed to [abortReplacement], in call order.
  final List<int> aborted = [];

  @override
  void abortReplacement(int queueId) {
    log.add('table.abortReplacement');
    aborted.add(queueId);
    final pending = _queue.remove(queueId);
    final old = _superseded.remove(queueId);
    if (pending == null || old == null) return;
    _rows[(old.batchId, old.alarmId)] = old;
  }

  @override
  List<MappingRecord> all() {
    log.add('table.all');
    return _rows.values.toList();
  }

  @override
  Set<String> tags() {
    log.add('table.tags');
    return [..._rows.values, ..._superseded.values].map((r) => r.tag).toSet();
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

/// Random source returning [values] in order, then repeating the last one.
class SequenceRandom implements RandomSourceProvider {
  /// Creates a source that returns [values] in order; [values] must not be empty.
  SequenceRandom(List<String> values)
    : assert(values.isNotEmpty, 'values must not be empty'),
      _values = List.unmodifiable(values);

  final List<String> _values;
  int _next = 0;

  @override
  String randomHex64() {
    final value = _values[_next < _values.length ? _next : _values.length - 1];
    _next++;
    return value;
  }
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
