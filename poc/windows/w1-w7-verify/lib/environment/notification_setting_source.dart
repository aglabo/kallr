// src: lib/environment/notification_setting_source.dart
// @(#) : NotificationSettingSource interface
//
// Copyright (c) 2026 atsushifx <http://github.com/atsushifx>
//
// Released under the MIT License.
// https://opensource.org/licenses/MIT

import 'notification_environment.dart';

/// Reads the OS notification setting of an AUMID. Receives normalized AUMIDs only.
abstract interface class NotificationSettingSource {
  /// Returns the current setting of [aumid].
  NotificationSetting read(String aumid);
}
