// src: lib/environment/__tests__/mock_notification_environment.dart
// @(#) : Mock NotificationEnvironment returning a given Availability
//
// Copyright (c) 2026 atsushifx <http://github.com/atsushifx>
//
// Released under the MIT License.
// https://opensource.org/licenses/MIT

import 'package:w1_w7_verify/environment/notification_environment.dart';

/// [NotificationEnvironment] that never touches the OS: [check] returns the
/// [Availability] given at construction.
class MockNotificationEnvironment implements NotificationEnvironment {
  /// Creates a mock whose [check] returns [_availability].
  const MockNotificationEnvironment(this._availability);

  /// State: notifications can be shown.
  const MockNotificationEnvironment.ok() : this(const Availability.ok());

  /// State: the AUMID is not registered.
  const MockNotificationEnvironment.unregistered()
    : this(
        const Availability(
          registered: false,
          displayNameSet: false,
          ok: false,
          reason: '未登録',
        ),
      );

  /// State: registered, but the DisplayName is empty.
  const MockNotificationEnvironment.displayNameEmpty()
    : this(
        const Availability(
          registered: true,
          displayNameSet: false,
          ok: false,
          reason: 'DisplayName が空',
        ),
      );

  /// State: the OS setting is disabledForApplication.
  const MockNotificationEnvironment.disabledForApplication()
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
  const MockNotificationEnvironment.disabledForUser()
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
  const MockNotificationEnvironment.disabledByGroupPolicy()
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
  const MockNotificationEnvironment.disabledByManifest()
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

  @override
  Availability check(String aumid) => _availability;
}
