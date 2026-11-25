// src: lib/environment/__tests__/fakes.dart
// @(#) : Fakes shared by the evaluateAvailability and MockNotificationEnvironment tests
//
// Copyright (c) 2026 atsushifx <http://github.com/atsushifx>
//
// Released under the MIT License.
// https://opensource.org/licenses/MIT

import 'package:w1_w7_verify/environment/aumid_registry.dart';
import 'package:w1_w7_verify/environment/notification_environment.dart';
import 'package:w1_w7_verify/environment/notification_setting_source.dart';

/// In-memory [AumidRegistry] holding AUMID -> DisplayName.
class FakeAumidRegistry implements AumidRegistry {
  /// Creates a registry holding [entries] (AUMID -> DisplayName).
  ///
  /// A null DisplayName is a registered AUMID for which [readDisplayName]
  /// returns null.
  FakeAumidRegistry([Map<String, String?> entries = const {}])
    : _entries = {...entries};

  final Map<String, String?> _entries;

  /// Failure thrown by [exists]; null to answer from the entries.
  Exception? existsError;

  /// Failure thrown by [readDisplayName]; null to answer from the entries.
  Exception? readDisplayNameError;

  /// AUMIDs passed to [exists], in call order.
  final List<String> existsArgs = [];

  /// AUMIDs passed to [readDisplayName], in call order.
  final List<String> readDisplayNameArgs = [];

  @override
  String? readDisplayName(String aumid) {
    readDisplayNameArgs.add(aumid);
    if (readDisplayNameError case final error?) throw error;
    return _entries[aumid];
  }

  @override
  bool exists(String aumid) {
    existsArgs.add(aumid);
    if (existsError case final error?) throw error;
    return _entries.containsKey(aumid);
  }

  @override
  void write(String aumid, String displayName) => _entries[aumid] = displayName;

  @override
  bool delete(String aumid) {
    final existed = _entries.containsKey(aumid);
    _entries.remove(aumid);
    return existed;
  }
}

/// [NotificationSettingSource] that always returns [setting].
class FakeNotificationSettingSource implements NotificationSettingSource {
  /// Creates the fake returning [setting].
  const FakeNotificationSettingSource(this.setting);

  /// Value returned by [read].
  final NotificationSetting setting;

  @override
  NotificationSetting read(String aumid) => setting;
}

/// [NotificationSettingSource] that records the arguments of [read] and always
/// returns [setting].
class RecordingNotificationSettingSource implements NotificationSettingSource {
  /// Creates the fake returning [setting].
  RecordingNotificationSettingSource(this.setting);

  /// Value returned by [read].
  final NotificationSetting setting;

  /// AUMIDs passed to [read], in call order.
  final List<String> readArgs = [];

  @override
  NotificationSetting read(String aumid) {
    readArgs.add(aumid);
    return setting;
  }
}

/// [NotificationSettingSource] whose [read] always throws [error].
class ThrowingNotificationSettingSource implements NotificationSettingSource {
  /// Creates the fake throwing [error].
  const ThrowingNotificationSettingSource(this.error);

  /// Failure thrown by [read].
  final Exception error;

  @override
  NotificationSetting read(String aumid) => throw error;
}

/// [AumidRegistry] that fails on any call and counts the attempts in [calls].
class FailingAumidRegistry implements AumidRegistry {
  /// Number of calls received; must stay 0 for code that never touches it.
  int calls = 0;

  Never _fail() {
    calls++;
    throw StateError('AumidRegistry must not be called');
  }

  @override
  String? readDisplayName(String aumid) => _fail();

  @override
  bool exists(String aumid) => _fail();

  @override
  void write(String aumid, String displayName) => _fail();

  @override
  bool delete(String aumid) => _fail();
}

/// [NotificationSettingSource] that fails on any call and counts the attempts in [calls].
class FailingNotificationSettingSource implements NotificationSettingSource {
  /// Number of calls received; must stay 0 for code that never touches it.
  int calls = 0;

  @override
  NotificationSetting read(String aumid) {
    calls++;
    throw StateError('NotificationSettingSource must not be called');
  }
}
