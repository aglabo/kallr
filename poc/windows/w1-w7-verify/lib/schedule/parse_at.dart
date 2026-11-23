// src: lib/schedule/parse_at.dart
// @(#) : parse the --at option string into an absolute time
//
// Copyright (c) 2026 atsushifx <http://github.com/atsushifx>
//
// Released under the MIT License.
// https://opensource.org/licenses/MIT

import '../errors.dart';

/// Returns the system UTC offset in effect at [utc].
Duration _systemOffsetAt(DateTime utc) => utc.toLocal().timeZoneOffset;

/// Matches a trailing `Z` or `+hh:mm` / `-hh:mm` offset.
final _explicitOffset = RegExp(r'(Z|[+-]\d{2}:?\d{2})$', caseSensitive: false);

/// Matches a date without a time part (`yyyy-mm-dd`).
final _dateOnly = RegExp(r'^\d{4}-\d{2}-\d{2}$');

/// Captures the year, month, day and optional hour, minute, second of a date-time string.
final _fields = RegExp(
  r'^(\d{4})-?(\d{2})-?(\d{2})(?:[T ](\d{2}):?(\d{2})(?::?(\d{2}))?)?',
);

/// Whether the numbers in [text] were rolled over when parsed into [wallClock].
///
/// `DateTime.parse` rolls out-of-range fields over (month 13 becomes January of the next year),
/// so the parsed fields are compared with the text to detect them.
/// A text without a recognisable date prefix is not judged here; `DateTime.parse` already decided it.
bool _isRolledOver(String text, DateTime wallClock) {
  final m = _fields.firstMatch(text);
  if (m == null) return false;
  final written = [for (var i = 1; i <= 6; i++) int.parse(m.group(i) ?? '0')];
  final parsed = [
    wallClock.year,
    wallClock.month,
    wallClock.day,
    wallClock.hour,
    wallClock.minute,
    wallClock.second,
  ];
  return written.indexed.any((f) => f.$2 != parsed[f.$1]);
}

/// Throws the error for a [text] that is not a date-time.
Never _cannotInterpret(String text) =>
    throw UsageException('cannot interpret --at value: "$text"');

/// Parses [text] into an absolute time (UTC).
///
/// A string with an explicit offset (`+09:00`, `Z`) is interpreted as that absolute instant.
/// A string without an offset is local time, resolved with [offsetAt],
/// which returns the UTC offset in effect at a given instant.
///
/// A local time that does not exist (skipped by a DST gap) throws [UsageException].
/// A local time that occurs twice (a DST overlap) resolves to the earlier instant.
/// A time in the past is not rejected.
DateTime parseAt(
  String text, {
  Duration Function(DateTime utc) offsetAt = _systemOffsetAt,
}) {
  final DateTime wallClock;
  try {
    if (_explicitOffset.hasMatch(text)) return DateTime.parse(text).toUtc();
    wallClock = DateTime.parse(
      '${_dateOnly.hasMatch(text) ? '${text}T00:00:00' : text}Z',
    );
  } on FormatException {
    _cannotInterpret(text);
  }
  if (_isRolledOver(text, wallClock)) _cannotInterpret(text);
  final instant = _resolveLocal(wallClock, offsetAt);
  if (instant == null) {
    throw UsageException('local time does not exist: $text');
  }
  return instant;
}

/// Resolves [wallClock] (the local time read as a UTC value) to an absolute instant.
///
/// The offsets in effect a day before and after are the candidates; a candidate is valid
/// when [offsetAt] returns the same offset at the instant it produces.
/// Returns the earliest valid instant, or `null` when the local time does not exist.
DateTime? _resolveLocal(
  DateTime wallClock,
  Duration Function(DateTime utc) offsetAt,
) {
  // Assumes at most one offset transition within a day of the local time,
  // so the offsets a day before and after cover every offset that can apply.
  const day = Duration(days: 1);
  final candidates = {
    offsetAt(wallClock.subtract(day)),
    offsetAt(wallClock.add(day)),
  };
  final instants = [
    for (final o in candidates)
      if (offsetAt(wallClock.subtract(o)) == o) wallClock.subtract(o),
  ]..sort();
  return instants.isEmpty ? null : instants.first;
}
