// src: lib/tag/generate_tag.dart
// @(#) : build a 40-character toast Tag from time, machine id and random part
//
// Copyright (c) 2026 atsushifx <http://github.com/atsushifx>
//
// Released under the MIT License.
// https://opensource.org/licenses/MIT

import '../models.dart';

/// Random part format: exactly 16 lowercase hex digits (no trailing newline).
final RegExp _randomPattern = RegExp(r'^[0-9a-f]{16}$');

/// Zero-pads [value] to [width] digits.
String _pad(int value, int width) => value.toString().padLeft(width, '0');

/// Zero-pads [value] to two digits.
String _pad2(int value) => _pad(value, 2);

/// Builds a Tag `<yyyyMMddHHmmss>-<machineId>-<random>` from [registeredAt].
///
/// [registeredAt] is used as local time as-is (no UTC conversion).
///
/// Throws [ArgumentError] when the year of [registeredAt] is outside 0..9999,
/// when [machineId] is not exactly 8 lowercase hex digits,
/// or when [random] is not exactly 16 lowercase hex digits.
String generateTag({
  required DateTime registeredAt,
  required String machineId,
  required String random,
}) {
  if (registeredAt.year < 0 || registeredAt.year > 9999) {
    throw ArgumentError.value(
      registeredAt.year,
      'registeredAt',
      'year must be in 0..9999',
    );
  }
  if (!kMachineIdPattern.hasMatch(machineId)) {
    throw ArgumentError.value(
      machineId,
      'machineId',
      'must be 8 lowercase hex digits',
    );
  }
  if (!_randomPattern.hasMatch(random)) {
    throw ArgumentError.value(
      random,
      'random',
      'must be 16 lowercase hex digits',
    );
  }
  final datetime =
      '${_pad(registeredAt.year, 4)}'
      '${_pad2(registeredAt.month)}${_pad2(registeredAt.day)}'
      '${_pad2(registeredAt.hour)}${_pad2(registeredAt.minute)}'
      '${_pad2(registeredAt.second)}';
  return '$datetime-$machineId-$random';
}
