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

      group(
        'Given: AUMID と DisplayName が登録済みで通知設定が disabledForApplication',
        () {
          final registry = FakeAumidRegistry({'com.kallr.app': 'Kallr'});
          const settings = FakeNotificationSettingSource(
            NotificationSetting.disabledForApplication,
          );

          group('When: evaluateAvailability を呼ぶ', () {
            test('[Normal] T-WDV-AVL-02: disabledForApplication では ok=false で理由に種別名を含める', () {
              final result = evaluateAvailability(
                'com.kallr.app',
                registry,
                settings,
              );

              expect(result.registered, isTrue);
              expect(result.displayNameSet, isTrue);
              expect(
                result.setting,
                NotificationSetting.disabledForApplication,
              );
              expect(result.ok, isFalse);
              expect(result.reason, contains('disabledForApplication'));
            });
          });
        },
      );

      group('Given: AUMID と DisplayName が登録済みで通知設定が disabledForUser', () {
        final registry = FakeAumidRegistry({'com.kallr.app': 'Kallr'});
        const settings = FakeNotificationSettingSource(
          NotificationSetting.disabledForUser,
        );

        group('When: evaluateAvailability を呼ぶ', () {
          test(
            '[Normal] T-WDV-AVL-03: disabledForUser では ok=false で理由に種別名を含める',
            () {
              final result = evaluateAvailability(
                'com.kallr.app',
                registry,
                settings,
              );

              expect(result.registered, isTrue);
              expect(result.displayNameSet, isTrue);
              expect(result.setting, NotificationSetting.disabledForUser);
              expect(result.ok, isFalse);
              expect(result.reason, contains('disabledForUser'));
            },
          );
        });
      });

      group('Given: AUMID と DisplayName が登録済みで通知設定が disabledByGroupPolicy', () {
        final registry = FakeAumidRegistry({'com.kallr.app': 'Kallr'});
        const settings = FakeNotificationSettingSource(
          NotificationSetting.disabledByGroupPolicy,
        );

        group('When: evaluateAvailability を呼ぶ', () {
          test('[Normal] T-WDV-AVL-04: disabledByGroupPolicy では ok=false で理由に種別名を含める', () {
            final result = evaluateAvailability(
              'com.kallr.app',
              registry,
              settings,
            );

            expect(result.registered, isTrue);
            expect(result.displayNameSet, isTrue);
            expect(result.setting, NotificationSetting.disabledByGroupPolicy);
            expect(result.ok, isFalse);
            expect(result.reason, contains('disabledByGroupPolicy'));
          });
        });
      });

      group('Given: AUMID と DisplayName が登録済みで通知設定が disabledByManifest', () {
        final registry = FakeAumidRegistry({'com.kallr.app': 'Kallr'});
        const settings = FakeNotificationSettingSource(
          NotificationSetting.disabledByManifest,
        );

        group('When: evaluateAvailability を呼ぶ', () {
          test(
            '[Normal] T-WDV-AVL-05: disabledByManifest では ok=false で理由に種別名を含める',
            () {
              final result = evaluateAvailability(
                'com.kallr.app',
                registry,
                settings,
              );

              expect(result.registered, isTrue);
              expect(result.displayNameSet, isTrue);
              expect(result.setting, NotificationSetting.disabledByManifest);
              expect(result.ok, isFalse);
              expect(result.reason, contains('disabledByManifest'));
            },
          );
        });
      });
    });
  });
}
