// src: lib/environment/notification_environment.dart
// @(#) : NotificationEnvironment interface and Availability
//
// Copyright (c) 2026 atsushifx <http://github.com/atsushifx>
//
// Released under the MIT License.
// https://opensource.org/licenses/MIT

/// Result of checking whether toast notifications can be shown for an AUMID.
final class Availability {
  /// Creates a result from its field values.
  const Availability({
    required this.registered,
    required this.displayNameSet,
    required this.ok,
    this.reason,
  });

  /// Creates the result for an environment that can show notifications.
  const Availability.ok()
    : this(registered: true, displayNameSet: true, ok: true);

  /// Whether the AUMID is registered.
  final bool registered;

  /// Whether the registered DisplayName is set.
  final bool displayNameSet;

  /// Whether notifications can be shown.
  final bool ok;

  /// Why notifications cannot be shown; null when [ok].
  final String? reason;
}

/// Observes the notification environment of the OS.
abstract interface class NotificationEnvironment {
  /// Checks whether notifications can be shown for [aumid].
  Availability check(String aumid);
}
