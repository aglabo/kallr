// src: lib/environment/__tests__/unit/evaluate_availability.unit.spec.dart
// @(#) : unit tests for evaluateAvailability
//
// Copyright (c) 2026 atsushifx <http://github.com/atsushifx>
//
// Released under the MIT License.
// https://opensource.org/licenses/MIT

// test framework
import 'package:test/test.dart';

// test target
import 'package:w1_w7_verify/environment/evaluate_availability.dart';
import 'package:w1_w7_verify/environment/notification_environment.dart';

// internal helpers
import '../fakes.dart';

void main() {
  group('evaluateAvailability', () {
    group('T-WDV-AVL: evaluateAvailability', () {
      group('Given: AUMID と DisplayName が登録済みで通知設定が enabled', () {
        final registry = FakeAumidRegistry({'com.kallr.app': 'Kallr'});
        const settings = FakeNotificationSettingSource(
          NotificationSetting.enabled,
        );

        group('When: evaluateAvailability を呼ぶ', () {
          test('[Normal] T-WDV-AVL-01: 通知できる状態では ok=true の結果を返す', () {
            final result = evaluateAvailability(
              'com.kallr.app',
              registry,
              settings,
            );

            expect(result.registered, isTrue);
            expect(result.displayNameSet, isTrue);
            expect(result.setting, NotificationSetting.enabled);
            expect(result.ok, isTrue);
            expect(result.reason, isNull);
          });
        });
      });
    });
  });
}
