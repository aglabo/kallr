// src: lib/environment/notification_environment.dart
// @(#) : NotificationEnvironment interface and Availability
//
// Copyright (c) 2026 atsushifx <http://github.com/atsushifx>
//
// Released under the MIT License.
// https://opensource.org/licenses/MIT

/// OS notification setting of an AUMID.
enum NotificationSetting {
  /// Notifications are enabled.
  enabled,

  /// Disabled for the application.
  disabledForApplication,

  /// Disabled by the user.
  disabledForUser,

  /// Disabled by group policy.
  disabledByGroupPolicy,

  /// Disabled by the manifest.
  disabledByManifest,
}

/// Result of checking whether toast notifications can be shown for an AUMID.
final class Availability {
  /// Creates a result from its field values.
  const Availability({
    required this.registered,
    required this.displayNameSet,
    required this.ok,
    this.setting,
    this.reason,
  });

  /// Creates the result for an environment that can show notifications.
  const Availability.ok()
    : this(
        registered: true,
        displayNameSet: true,
        setting: NotificationSetting.enabled,
        ok: true,
      );

  /// Whether the AUMID is registered.
  final bool registered;

  /// Whether the registered DisplayName is set.
  final bool displayNameSet;

  /// OS notification setting; null when the check stopped before reading it.
  final NotificationSetting? setting;

  /// Whether notifications can be shown.
  final bool ok;

  /// Why notifications cannot be shown; null when [ok].
  final String? reason;
}

/// Checks, creates and deletes the notification registration of the OS.
abstract interface class NotificationEnvironment {
  /// Checks whether notifications can be shown for [aumid].
  Availability check(String aumid);

  /// Registers [aumid] with [displayName], overwriting the DisplayName of an
  /// existing registration.
  void register(String aumid, String displayName);

  /// Deletes the registration of [aumid].
  void unregister(String aumid);

  /// Whether [aumid] is registered, with or without a DisplayName.
  bool isRegistered(String aumid);
}
