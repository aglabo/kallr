// src: lib/environment/__tests__/mock_notification_environment.dart
// @(#) : Mock NotificationEnvironment returning a given Availability
//
// Copyright (c) 2026 atsushifx <http://github.com/atsushifx>
//
// Released under the MIT License.
// https://opensource.org/licenses/MIT

import 'package:w1_w7_verify/environment/aumid_registry.dart';
import 'package:w1_w7_verify/environment/notification_environment.dart';
import 'package:w1_w7_verify/environment/notification_setting_source.dart';

/// [NotificationEnvironment] that never touches the OS: [check] returns the
/// [Availability] given at construction; [isRegistered] returns its
/// [Availability.registered] and records the call; [register] / [unregister]
/// only record their calls.
class MockNotificationEnvironment implements NotificationEnvironment {
  /// Creates a mock answering [check] and [isRegistered] from [_availability].
  ///
  /// [registry] and [settings] are held only so tests can inject fakes and
  /// verify they are never called; this mock never calls them.
  MockNotificationEnvironment(
    this._availability, {
    this.registry,
    this.settings,
  });

  /// State: notifications can be shown.
  MockNotificationEnvironment.ok() : this(const Availability.ok());

  /// State: the AUMID is not registered.
  MockNotificationEnvironment.unregistered()
    : this(
        const Availability(
          registered: false,
          displayNameSet: false,
          ok: false,
          reason: '未登録',
        ),
      );

  /// State: registered, but the DisplayName is empty.
  MockNotificationEnvironment.displayNameEmpty()
    : this(
        const Availability(
          registered: true,
          displayNameSet: false,
          ok: false,
          reason: 'DisplayName が空',
        ),
      );

  /// State: the OS setting is disabledForApplication.
  MockNotificationEnvironment.disabledForApplication()
    : this._disabled(NotificationSetting.disabledForApplication);

  /// State: the OS setting is disabledForUser.
  MockNotificationEnvironment.disabledForUser()
    : this._disabled(NotificationSetting.disabledForUser);

  /// State: the OS setting is disabledByGroupPolicy.
  MockNotificationEnvironment.disabledByGroupPolicy()
    : this._disabled(NotificationSetting.disabledByGroupPolicy);

  /// State: the OS setting is disabledByManifest.
  MockNotificationEnvironment.disabledByManifest()
    : this._disabled(NotificationSetting.disabledByManifest);

  /// Registered with a DisplayName, disabled by [setting].
  MockNotificationEnvironment._disabled(NotificationSetting setting)
    : this(
        Availability(
          registered: true,
          displayNameSet: true,
          setting: setting,
          ok: false,
          reason: setting.name,
        ),
      );

  final Availability _availability;

  /// Injected registry; never called by this mock.
  final AumidRegistry? registry;

  /// Injected setting source; never called by this mock.
  final NotificationSettingSource? settings;

  /// Arguments of every [register] call, in call order.
  final List<({String aumid, String displayName})> registerCalls = [];

  /// AUMID of every [unregister] call, in call order.
  final List<String> unregisterCalls = [];

  /// AUMID of every [isRegistered] call, in call order.
  final List<String> isRegisteredCalls = [];

  /// Records the call only; never touches the registry or the OS.
  @override
  void register(String aumid, String displayName) =>
      registerCalls.add((aumid: aumid, displayName: displayName));

  /// Records the call only; never touches the registry or the OS.
  @override
  void unregister(String aumid) => unregisterCalls.add(aumid);

  @override
  Availability check(String aumid) => _availability;

  @override
  bool isRegistered(String aumid) {
    isRegisteredCalls.add(aumid);
    return _availability.registered;
  }
}
