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
/// [Availability] given at construction; [register] / [unregister] only record
/// their calls.
class MockNotificationEnvironment implements NotificationEnvironment {
  /// Creates a mock whose [check] returns [_availability].
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
    : this(
        const Availability(
          registered: true,
          displayNameSet: true,
          setting: NotificationSetting.disabledForApplication,
          ok: false,
          reason: 'disabledForApplication',
        ),
      );

  /// State: the OS setting is disabledForUser.
  MockNotificationEnvironment.disabledForUser()
    : this(
        const Availability(
          registered: true,
          displayNameSet: true,
          setting: NotificationSetting.disabledForUser,
          ok: false,
          reason: 'disabledForUser',
        ),
      );

  /// State: the OS setting is disabledByGroupPolicy.
  MockNotificationEnvironment.disabledByGroupPolicy()
    : this(
        const Availability(
          registered: true,
          displayNameSet: true,
          setting: NotificationSetting.disabledByGroupPolicy,
          ok: false,
          reason: 'disabledByGroupPolicy',
        ),
      );

  /// State: the OS setting is disabledByManifest.
  MockNotificationEnvironment.disabledByManifest()
    : this(
        const Availability(
          registered: true,
          displayNameSet: true,
          setting: NotificationSetting.disabledByManifest,
          ok: false,
          reason: 'disabledByManifest',
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

  /// Records the call only; never touches the registry or the OS.
  void register(String aumid, String displayName) =>
      registerCalls.add((aumid: aumid, displayName: displayName));

  /// Records the call only; never touches the registry or the OS.
  void unregister(String aumid) => unregisterCalls.add(aumid);

  @override
  Availability check(String aumid) => _availability;
}
