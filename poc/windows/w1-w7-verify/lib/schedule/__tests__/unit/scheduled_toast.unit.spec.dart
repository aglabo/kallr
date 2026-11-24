// src: lib/schedule/__tests__/unit/scheduled_toast.unit.spec.dart
// @(#) : unit tests for ScheduledToast equality in toast_scheduler.dart
//
// Copyright (c) 2026 atsushifx <http://github.com/atsushifx>
//
// Released under the MIT License.
// https://opensource.org/licenses/MIT

// test framework
import 'package:test/test.dart';

// test target
import 'package:w1_w7_verify/schedule/toast_scheduler.dart';

/// Base toast; every case compares against it.
final ScheduledToast _base = ScheduledToast(
  tag: 'tag-a',
  group: 'group-a',
  at: DateTime.utc(2026, 1, 1, 9),
);

/// Toast with the same values as [_base], built separately.
final ScheduledToast _same = ScheduledToast(
  tag: 'tag-a',
  group: 'group-a',
  at: DateTime.utc(2026, 1, 1, 9),
);

/// Toasts that differ from [_base] in exactly one field, by title.
final List<({String title, ScheduledToast other})> _differing = [
  (
    title: 'tag',
    other: ScheduledToast(
      tag: 'tag-b',
      group: 'group-a',
      at: DateTime.utc(2026, 1, 1, 9),
    ),
  ),
  (
    title: 'group',
    other: ScheduledToast(
      tag: 'tag-a',
      group: 'group-b',
      at: DateTime.utc(2026, 1, 1, 9),
    ),
  ),
  (
    title: 'at',
    other: ScheduledToast(
      tag: 'tag-a',
      group: 'group-a',
      at: DateTime.utc(2026, 1, 1, 10),
    ),
  ),
];

/// Tests for ScheduledToast: value equality and hashCode.
void main() {
  group('T-WDV-STO: ScheduledToast', () {
    /// Equality: decided by tag, group and at.
    group('==', () {
      test('[Normal] T-WDV-STO-01: 同一値なら等しい', () {
        expect(_base, _same);
      });

      for (final (:title, :other) in _differing) {
        test('[Normal] T-WDV-STO-02: $title だけが違うと等しくない', () {
          expect(_base == other, isFalse);
        });
      }
    });

    /// hashCode: equal values give equal hash codes.
    group('hashCode', () {
      test('[Normal] T-WDV-STO-03: 同一値なら hashCode が一致する', () {
        expect(_base.hashCode, _same.hashCode);
      });
    });
  });
}
