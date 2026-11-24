// src: lib/schedule/scheduling_service.dart
// @(#) : SchedulingService: registers toast notifications and keeps the mapping table in step
//
// Copyright (c) 2026 atsushifx <http://github.com/atsushifx>
//
// Released under the MIT License.
// https://opensource.org/licenses/MIT

import '../environment/notification_environment.dart';
import '../errors.dart';
import '../models.dart';
import '../store/mapping_table.dart';
import '../tag/providers.dart';
import '../tag/tag_allocator.dart';
import 'clock_provider.dart';
import 'toast_scheduler.dart';

/// Registers toast notifications with the OS and records them in the mapping table.
final class SchedulingService {
  /// Creates the service from its collaborators.
  SchedulingService({
    required NotificationEnvironment env,
    required ToastScheduler scheduler,
    required MappingTable table,
    required ClockProvider clock,
    required RandomSourceProvider random,
    required MachineIdProvider machineId,
  }) : _env = env,
       _scheduler = scheduler,
       _table = table,
       _clock = clock,
       _random = random,
       _machineId = machineId;

  final NotificationEnvironment _env;
  final ToastScheduler _scheduler;
  final MappingTable _table;
  final ClockProvider _clock;
  final RandomSourceProvider _random;
  final MachineIdProvider _machineId;

  /// Registers a notification for ([batchId], [alarmId]) at [at] and returns its record.
  ///
  /// Throws [UnavailableException] before any side effect when notifications cannot be shown.
  ///
  /// When the key already has a toast in the scheduler, the toast is replaced in four stages
  /// (table.replace, scheduler.add, scheduler.remove, table.completeRemoval).
  MappingRecord add({
    required String batchId,
    required String alarmId,
    required DateTime at,
    required String title,
    required String aumid,
  }) {
    final availability = _env.check(aumid);
    if (!availability.ok) throw UnavailableException(availability);
    final current = _table.get(batchId, alarmId);
    final toasts = _scheduler.list(kGroup);
    final registeredAt = _clock.now();
    final tag = allocateTag(
      random: _random,
      machineId: _machineId,
      existingTags: {...toasts.map((t) => t.tag), ..._table.tags()},
      registeredAt: registeredAt,
    );
    final record = MappingRecord(
      batchId: batchId,
      alarmId: alarmId,
      tag: tag,
      at: at.toUtc(),
      title: title,
      registeredAt: registeredAt,
    );
    final replaced = current != null && toasts.any((t) => t.tag == current.tag);
    if (replaced) {
      final queueId = _table.replace(record);
      _scheduler.add(tag: tag, group: kGroup, at: at, title: title);
      _scheduler.remove(current.tag, kGroup);
      _table.completeRemoval(queueId);
    } else {
      _scheduler.add(tag: tag, group: kGroup, at: at, title: title);
      _table.put(record);
    }
    return record;
  }

  /// Returns the merged view of the mapping table and the OS schedule.
  ///
  /// A toast the table does not know at all is an orphan (an earlier add stopped after the
  /// OS registration). A table record without a toast is stale. Superseded toasts that
  /// still await removal are not listed.
  List<ScheduleEntry> list() {
    final toasts = _scheduler.list(kGroup);
    final records = _table.all();
    final toastByTag = {for (final t in toasts) t.tag: t};
    final knownTags = _table.tags();
    final recordTags = {for (final r in records) r.tag};
    return [
      for (final r in records)
        ScheduleEntry(
          state: toastByTag.containsKey(r.tag)
              ? EntryState.ok
              : EntryState.stale,
          record: r,
          toast: toastByTag[r.tag],
        ),
      for (final t in toasts)
        if (!recordTags.contains(t.tag) && !knownTags.contains(t.tag))
          ScheduleEntry(state: EntryState.orphan, toast: t),
    ];
  }
}
