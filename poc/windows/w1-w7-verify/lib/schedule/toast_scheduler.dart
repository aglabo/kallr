// src: lib/schedule/toast_scheduler.dart
// @(#) : ToastScheduler interface and ScheduledToast
//
// Copyright (c) 2026 atsushifx <http://github.com/atsushifx>
//
// Released under the MIT License.
// https://opensource.org/licenses/MIT

/// One scheduled toast held by the OS.
final class ScheduledToast {
  /// Creates a scheduled toast from its field values.
  const ScheduledToast({
    required this.tag,
    required this.group,
    required this.at,
  });

  /// Toast Tag.
  final String tag;

  /// Toast Group.
  final String group;

  /// Delivery time (absolute).
  final DateTime at;

  @override
  bool operator ==(Object other) =>
      other is ScheduledToast &&
      other.tag == tag &&
      other.group == group &&
      other.at == at;

  @override
  int get hashCode => Object.hash(tag, group, at);
}

/// Schedules toasts with the OS.
abstract interface class ToastScheduler {
  /// Schedules a toast; throws a `ScheduleException` when the OS rejects it.
  void add({
    required String tag,
    required String group,
    required DateTime at,
    required String title,
  });

  /// Removes the toast of ([tag], [group]); returns false when none exists (already fired).
  ///
  /// Throws a `ScheduleException` when the OS fails.
  bool remove(String tag, String group);

  /// Returns the scheduled toasts of [group].
  List<ScheduledToast> list(String group);
}
