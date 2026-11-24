// Copyright (c) 2026 Furukawa Atsushi <atsushifx@gmail.com>
//
// This software is released under the MIT License.
// https://opensource.org/licenses/MIT
// src: lib/errors.dart
// @(#) : exception types shared across the verification tool
//
// Copyright (c) 2026 atsushifx <http://github.com/atsushifx>
//
// Released under the MIT License.
// https://opensource.org/licenses/MIT

import 'environment/notification_environment.dart';

/// Thrown when a unique Tag could not be allocated within the retry limit.
class DuplicateTagException implements Exception {
  /// Creates the exception for [attempts] duplicate Tags in a row.
  const DuplicateTagException({required this.attempts});

  /// Number of generation attempts that all produced a duplicate Tag.
  final int attempts;

  @override
  String toString() =>
      'DuplicateTagException: Tag was duplicated in all $attempts attempts';
}

/// Thrown when an argument is invalid: a bad argument, an uninterpretable
/// `--at` string, or an empty AUMID.
class UsageException implements Exception {
  /// Creates the exception with the usage error [message].
  const UsageException(this.message);

  /// Reason the usage is invalid.
  final String message;

  @override
  String toString() => 'UsageException: $message';
}

/// Thrown when the database cannot be opened or initialized, a read fails,
/// the stored value is invalid, or a write fails.
class StorageException implements Exception {
  /// Creates the exception with the failure [message].
  const StorageException(this.message);

  /// Reason of the storage failure.
  final String message;

  @override
  String toString() => 'StorageException: $message';
}

/// HRESULT codes the OS returns for toast scheduling failures.
abstract final class Hresult {
  /// E_INVALIDARG: the OS rejects a past `at`.
  static const int invalidArgument = 0x80070057;

  /// The OS rejects a new registration over its toast limit.
  static const int tooManyToasts = 0x80070718;
}

/// Thrown when the OS rejects a toast operation; carries the OS error code.
class ScheduleException implements Exception {
  /// Creates the exception for the OS error [hresult].
  const ScheduleException(this.hresult);

  /// HRESULT returned by the OS.
  final int hresult;

  @override
  String toString() => 'ScheduleException: 0x${hresult.toRadixString(16)}';
}

/// Thrown when toast notifications cannot be shown (the availability check is not ok).
class UnavailableException implements Exception {
  /// Creates the exception for the failed [availability] check.
  const UnavailableException(this.availability);

  /// Result of the failed check.
  final Availability availability;

  @override
  String toString() => 'UnavailableException: ${availability.reason}';
}
