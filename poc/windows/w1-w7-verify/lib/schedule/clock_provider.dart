// src: lib/schedule/clock_provider.dart
// @(#) : ClockProvider interface
//
// Copyright (c) 2026 atsushifx <http://github.com/atsushifx>
//
// Released under the MIT License.
// https://opensource.org/licenses/MIT

/// Source of the current local time.
abstract interface class ClockProvider {
  /// Returns the current local time.
  DateTime now();
}
