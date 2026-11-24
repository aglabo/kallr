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

