// src: lib/tag/providers.dart
// @(#) : provider interfaces injected into allocateTag
//
// Copyright (c) 2026 atsushifx <http://github.com/atsushifx>
//
// Released under the MIT License.
// https://opensource.org/licenses/MIT

/// Source of the 64-bit random part of a Tag.
abstract interface class RandomSourceProvider {
  /// Returns 16 lowercase hex digits (64 bits of randomness).
  String randomHex64();
}

/// Source of the machine id part of a Tag.
abstract interface class MachineIdProvider {
  /// Returns 8 lowercase hex digits identifying this machine.
  String machineId();
}
