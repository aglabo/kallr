// src: lib/ids.dart
// @(#) : identifier normalization
//
// Copyright (c) 2026 atsushifx <http://github.com/atsushifx>
//
// Released under the MIT License.
// https://opensource.org/licenses/MIT

/// Normalizes an identifier by trimming surrounding whitespace.
///
/// Inner whitespace is kept; an empty result is returned as is (no exception).
String normalizeId(String raw) => raw.trim();
