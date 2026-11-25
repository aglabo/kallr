// src: lib/environment/__tests__/unit/availability.unit.spec.dart
// @(#) : unit tests for Availability in notification_environment.dart
//
// Copyright (c) 2026 atsushifx <http://github.com/atsushifx>
//
// Released under the MIT License.
// https://opensource.org/licenses/MIT

// test framework
import 'package:test/test.dart';

// test target
import 'package:w1_w7_verify/environment/notification_environment.dart';

/// Reason passed to the general constructor.
const String _reason = 'not registered';

/// Availability built with every field given (general constructor cases).
const Availability _custom = Availability(
  registered: true,
  displayNameSet: false,
  setting: NotificationSetting.disabledForUser,
  ok: false,
  reason: _reason,
);

/// Tests for Availability: the ok() constructor and the retained values of
/// the general constructor.
void main() {
  group('T-WDV-AVO: Availability', () {
    /// Availability.ok(): the result for an environment that can notify.
    group('Availability.ok', () {
      test('[Normal] T-WDV-AVO-01: registered は true である', () {
        expect(const Availability.ok().registered, isTrue);
      });

      test('[Normal] T-WDV-AVO-02: displayNameSet は true である', () {
        expect(const Availability.ok().displayNameSet, isTrue);
      });

      test('[Normal] T-WDV-AVO-03: setting は enabled である', () {
        expect(const Availability.ok().setting, NotificationSetting.enabled);
      });

      test('[Normal] T-WDV-AVO-04: ok は true である', () {
        expect(const Availability.ok().ok, isTrue);
      });

      test('[Normal] T-WDV-AVO-05: reason は null である', () {
        expect(const Availability.ok().reason, isNull);
      });
    });

    /// General constructor: each given value is retained.
    group('Availability', () {
      test('[Normal] T-WDV-AVO-06: registered を保持する', () {
        expect(_custom.registered, isTrue);
      });

      test('[Normal] T-WDV-AVO-07: displayNameSet を保持する', () {
        expect(_custom.displayNameSet, isFalse);
      });

      test('[Normal] T-WDV-AVO-08: setting を保持する', () {
        expect(_custom.setting, NotificationSetting.disabledForUser);
      });

      test('[Normal] T-WDV-AVO-09: ok を保持する', () {
        expect(_custom.ok, isFalse);
      });

      test('[Normal] T-WDV-AVO-10: reason を保持する', () {
        expect(_custom.reason, _reason);
      });
    });
  });
}
