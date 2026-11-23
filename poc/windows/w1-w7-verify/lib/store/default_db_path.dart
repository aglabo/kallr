// src: lib/store/default_db_path.dart
// @(#) : resolve the default storage path of the mapping table
//
// Copyright (c) 2026 atsushifx <http://github.com/atsushifx>
//
// Released under the MIT License.
// https://opensource.org/licenses/MIT

import '../errors.dart';

/// Path separator between LOCALAPPDATA and the relative path.
const String _separator = '/';

/// Path segments below LOCALAPPDATA (SCH-DD-12), joined with `/`.
const String _relativeDbPath = 'kallr/w1-w7-verify/mappings.sqlite3';

/// Returns the default DB path `<LOCALAPPDATA>/kallr/w1-w7-verify/mappings.sqlite3`.
///
/// [environment] is normally `Platform.environment`; it is passed in so the
/// caller (and the tests) decide where `LOCALAPPDATA` comes from.
///
/// Throws [StorageException] when `LOCALAPPDATA` is absent: no fallback path
/// is invented (fail first).
String defaultDbPath(Map<String, String> environment) {
  final String? localAppData = environment['LOCALAPPDATA'];
  if (localAppData == null) {
    throw const StorageException(
      'LOCALAPPDATA is not set; cannot resolve the default DB path',
    );
  }
  return '$localAppData$_separator$_relativeDbPath';
}
