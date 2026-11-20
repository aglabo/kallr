// src: lib/map_toast_key.dart
// @(#) : map an id to a toast Group/Tag key within a length limit
//
// Copyright (c) 2026 atsushifx <http://github.com/atsushifx>
//
// Released under the MIT License.
// https://opensource.org/licenses/MIT

/// Length of a shortened key: 16 lowercase hex digits (64 bits).
const int _hashLength = 16;

// FNV-1a 64-bit parameters. The offset basis exceeds the signed int range, so
// it is stored as its two's-complement value; this is valid on the Dart VM only.
const int _fnvOffsetBasis = 0xcbf29ce484222325;
const int _fnvPrime = 0x100000001b3;

/// Maps [id] to a key of at most [maxLength] UTF-16 code units.
///
/// An [id] that fits is returned unchanged. A longer one is replaced by its
/// FNV-1a 64-bit hash (16 lowercase hex digits), so the result is deterministic
/// and never splits a surrogate pair.
///
/// Throws [ArgumentError] when [maxLength] <= 0, [id] is empty, or shortening is
/// needed while [maxLength] is below the hash length.
String mapToastKey(String id, {required int maxLength}) {
  if (maxLength <= 0) {
    throw ArgumentError.value(maxLength, 'maxLength', 'must be positive');
  }
  if (id.isEmpty) {
    throw ArgumentError.value(id, 'id', 'must not be empty');
  }
  if (id.length <= maxLength) return id;
  if (maxLength < _hashLength) {
    throw ArgumentError.value(
      maxLength,
      'maxLength',
      'must be at least $_hashLength to shorten',
    );
  }
  return _fnv1a64Hex(id);
}

/// FNV-1a 64-bit over the UTF-16 code units, as unsigned lowercase hex.
/// Dart VM ints wrap at 64 bits, so the multiply wraps as FNV requires;
/// `toUnsigned(64)` keeps a set top bit from printing as a negative number.
String _fnv1a64Hex(String text) {
  final hash = text.codeUnits.fold<int>(
    _fnvOffsetBasis,
    (acc, unit) => (acc ^ unit) * _fnvPrime,
  );
  return BigInt.from(hash)
      .toUnsigned(64)
      .toRadixString(16)
      .padLeft(_hashLength, '0');
}
