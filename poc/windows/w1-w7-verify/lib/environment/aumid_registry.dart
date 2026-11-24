// src: lib/environment/aumid_registry.dart
// @(#) : AumidRegistry interface
//
// Copyright (c) 2026 atsushifx <http://github.com/atsushifx>
//
// Released under the MIT License.
// https://opensource.org/licenses/MIT

/// Reads and writes AUMID registrations. Receives normalized AUMIDs only.
abstract interface class AumidRegistry {
  /// Returns the DisplayName; null when unregistered, '' when registered without a value.
  String? readDisplayName(String aumid);

  /// Whether [aumid] is registered.
  bool exists(String aumid);

  /// Registers [aumid] with [displayName].
  void write(String aumid, String displayName);

  /// Deletes the registration; false when there was none.
  bool delete(String aumid);
}
