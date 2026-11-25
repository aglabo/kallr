// src: lib/environment/notification_setting_value.dart
// @(#) : notificationSettingFromValue
//
// Copyright (c) 2026 atsushifx <http://github.com/atsushifx>
//
// Released under the MIT License.
// https://opensource.org/licenses/MIT

import '../errors.dart';
import 'notification_environment.dart';

/// Converts the OS notification setting [value] to a [NotificationSetting].
///
/// Throws [RegistryException] without a Win32 code when [value] is not one of
/// the values the OS defines (0 to 4).
NotificationSetting notificationSettingFromValue(int value) => switch (value) {
  0 => NotificationSetting.enabled,
  1 => NotificationSetting.disabledForApplication,
  2 => NotificationSetting.disabledForUser,
  3 => NotificationSetting.disabledByGroupPolicy,
  4 => NotificationSetting.disabledByManifest,
  _ => throw RegistryException('unknown notification setting: $value'),
};
