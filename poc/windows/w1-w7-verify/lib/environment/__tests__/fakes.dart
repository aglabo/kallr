// src: lib/environment/__tests__/fakes.dart
// @(#) : Fakes shared by evaluateAvailability tests
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
  FakeAumidRegistry([Map<String, String> entries = const {}])
    : _entries = {...entries};

  final Map<String, String> _entries;

  @override
  String? readDisplayName(String aumid) => _entries[aumid];

  @override
  bool exists(String aumid) => _entries.containsKey(aumid);

  @override
  void write(String aumid, String displayName) => _entries[aumid] = displayName;

  @override
  bool delete(String aumid) => _entries.remove(aumid) != null;
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
