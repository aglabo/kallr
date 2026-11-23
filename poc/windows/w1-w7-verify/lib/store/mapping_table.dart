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

  /// Removes the record for ([batchId], [alarmId]); does nothing when none exists.
  void remove(String batchId, String alarmId);

  /// Returns every current record.
  List<MappingRecord> all();

  /// Returns the Tag of every row, including superseded ones that the OS may still hold.
  Set<String> tags();
}
