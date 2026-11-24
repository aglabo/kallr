// Copyright (c) 2026 Furukawa Atsushi <atsushifx@gmail.com>
//
// This software is released under the MIT License.
// https://opensource.org/licenses/MIT
// src: lib/models.dart
// @(#) : shared constants and models
//
// Copyright (c) 2026 atsushifx <http://github.com/atsushifx>
//
// Released under the MIT License.
// https://opensource.org/licenses/MIT

import 'schedule/toast_scheduler.dart' show ScheduledToast;

/// Fixed toast Group name (TAG-R-004). Must be 64 characters or fewer.
const String kGroup = 'kallr';

/// Machine id format: exactly 8 lowercase hex digits.
final RegExp kMachineIdPattern = RegExp(r'^[0-9a-f]{8}$');

/// One notification row of the mapping table (db-migration.md §2.5).
///
/// Equality is by field values. [at] is held as an absolute time (UTC);
/// [registeredAt] is a local date-time (`isUtc == false`).
final class MappingRecord {
  /// Creates a record from its field values.
  const MappingRecord({
    required this.batchId,
    required this.alarmId,
    required this.tag,
    required this.at,
    required this.title,
    required this.registeredAt,
  });

  /// Caller-supplied batch identifier.
  final String batchId;

  /// Caller-supplied alarm identifier.
  final String alarmId;

  /// 40-character Tag.
  final String tag;

  /// Notification time (absolute, UTC).
  final DateTime at;

  /// Notification title.
  final String title;

  /// Registration time (local).
  final DateTime registeredAt;

  @override
  bool operator ==(Object other) =>
      other is MappingRecord &&
      other.batchId == batchId &&
      other.alarmId == alarmId &&
      other.tag == tag &&
      other.at == at &&
      other.title == title &&
      other.registeredAt == registeredAt;

  @override
  int get hashCode =>
      Object.hash(batchId, alarmId, tag, at, title, registeredAt);
}

/// One queued removal of a superseded notification (`replacement_queue` row).
///
/// Equality is by field values.
final class PendingRemoval {
  /// Creates a pending removal from its field values.
  const PendingRemoval({
    required this.queueId,
    required this.oldTag,
    required this.group,
    required this.record,
  });

  /// Id of the `replacement_queue` row.
  final int queueId;

  /// Tag of the superseded (old) notification to remove from the OS.
  final String oldTag;

  /// Toast Group of the old notification.
  final String group;

  /// The record that replaced the old one (the pending row).
  final MappingRecord record;

  @override
  bool operator ==(Object other) =>
      other is PendingRemoval &&
      other.queueId == queueId &&
      other.oldTag == oldTag &&
      other.group == group &&
      other.record == record;

  @override
  int get hashCode => Object.hash(queueId, oldTag, group, record);
}

/// How an entry of the OS schedule and the mapping table relate.
enum EntryState {
  /// Present in both the table and the scheduler.
  ok,

  /// Present in the scheduler only.
  orphan,

  /// Present in the table only.
  stale,
}

/// One row of the merged view of the mapping table and the OS schedule.
final class ScheduleEntry {
  /// Creates an entry; [record] is null for an orphan, [toast] is null for a stale one.
  const ScheduleEntry({required this.state, this.record, this.toast});

  /// Table record, or null when the table has none.
  final MappingRecord? record;

  /// Scheduled toast, or null when the scheduler has none.
  final ScheduledToast? toast;

  /// Relation between [record] and [toast].
  final EntryState state;
}
