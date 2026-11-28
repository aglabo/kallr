// src: lib/environment/permission_probe.dart
// @(#) : PermissionProbe interface
//
// Copyright (c) 2026 atsushifx <http://github.com/atsushifx>
//
// Released under the MIT License.
// https://opensource.org/licenses/MIT

/// Observes the permission level the process runs with.
abstract interface class PermissionProbe {
  /// Current permission level: `user` or `administrator`.
  String current();
}
