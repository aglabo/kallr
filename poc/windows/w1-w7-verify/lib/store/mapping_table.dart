// src: lib/store/mapping_table.dart
// @(#) : MappingTable interface
//
// Copyright (c) 2026 atsushifx <http://github.com/atsushifx>
//
// Released under the MIT License.
// https://opensource.org/licenses/MIT

import '../models.dart';

/// Table of scheduled notifications, keyed by (batchId, alarmId).
abstract interface class MappingTable {
  /// Returns the record for ([batchId], [alarmId]), or null when none exists.
  MappingRecord? get(String batchId, String alarmId);

  /// Stores [record], overwriting the record of the same (batchId, alarmId).
  void put(MappingRecord record);

  /// Replaces the current record of the same (batchId, alarmId) with [record] and returns the id of the queued removal.
  ///
  /// When the current record is itself an unfinished replacement, that replacement is cancelled and only the latest one stays queued.
  /// Throws a [StorageException] and changes nothing when there is no current record to replace.
  int replace(MappingRecord record);

  /// Returns the queued removals of superseded notifications, oldest queue row first.
  ///
  /// Each item carries the old Tag and Group to remove from the OS, and the record that replaced it.
  List<PendingRemoval> pendingRemovals();

  /// Completes the removal queued as [queueId]: deletes the old record and makes the new (pending) record current.
  ///
  /// The queue row stays, with its old record cleared. Throws a [StorageException] when the change fails.
  void completeRemoval(int queueId);

  /// Aborts the replacement queued as [queueId]: deletes the new (pending) record and its queue row, and makes the old record current again.
  ///
  /// Does nothing (no row changes, no exception) when [queueId] does not exist or
  /// its replacement is already completed (see [completeRemoval]).
  ///
  /// Throws a [StorageException] when the change fails.
  void abortReplacement(int queueId);

  /// Deletes the queue rows whose removal is already completed (see [completeRemoval]) and returns how many were deleted.
  ///
  /// Queue rows of unfinished replacements are kept, because [pendingRemovals] and [abortReplacement] need them. The records are not touched.
  /// Throws a [StorageException] when the change fails.
  int purgeCompletedQueue();

  /// Removes the record for ([batchId], [alarmId]); does nothing when none exists.
  void remove(String batchId, String alarmId);

  /// Returns every current record.
  List<MappingRecord> all();

  /// Returns the Tag of every row, including superseded ones that the OS may still hold.
  Set<String> tags();
}
