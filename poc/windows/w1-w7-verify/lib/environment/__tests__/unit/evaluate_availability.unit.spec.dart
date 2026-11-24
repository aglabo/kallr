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
import '../mock_notification_environment.dart';

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

      group(
        'Given: 状態「OK (通知できる)」の Mock で構築した MockNotificationEnvironment',
        () {
          const env = MockNotificationEnvironment.ok();

          group('When: check を呼ぶ', () {
            test('[Normal] T-WDV-AVL-06: ok=true の Availability を返す', () {
              final result = env.check('com.kallr.app');

              expect(result.registered, isTrue);
              expect(result.displayNameSet, isTrue);
              expect(result.setting, NotificationSetting.enabled);
              expect(result.ok, isTrue);
            });
          });
        },
      );

      group('Given: 状態「未登録」の Mock で構築した MockNotificationEnvironment', () {
        const env = MockNotificationEnvironment.unregistered();

        group('When: check を呼ぶ', () {
          test('[Normal] T-WDV-AVL-07: 未登録の Availability を返す', () {
            final result = env.check('com.kallr.app');

            expect(result.registered, isFalse);
            expect(result.ok, isFalse);
            expect(result.setting, isNull);
            expect(result.reason, '未登録');
          });
        });
      });

      group(
        'Given: 状態「DisplayName 空」の Mock で構築した MockNotificationEnvironment',
        () {
          const env = MockNotificationEnvironment.displayNameEmpty();

          group('When: check を呼ぶ', () {
            test('[Normal] T-WDV-AVL-08: DisplayName 空の Availability を返す', () {
              final result = env.check('com.kallr.app');

              expect(result.registered, isTrue);
              expect(result.displayNameSet, isFalse);
              expect(result.ok, isFalse);
              expect(result.setting, isNull);
              expect(result.reason, 'DisplayName が空');
            });
          });
        },
      );

      group('Given: 状態「無効 (disabledForApplication)」の Mock で構築した MockNotificationEnvironment', () {
        const env = MockNotificationEnvironment.disabledForApplication();

        group('When: check を呼ぶ', () {
          test('[Normal] T-WDV-AVL-09: disabledForApplication では setting と ok=false の Availability を返す', () {
            final result = env.check('com.kallr.app');

            expect(result.setting, NotificationSetting.disabledForApplication);
            expect(result.ok, isFalse);
          });
        });
      });

      group('Given: 状態「無効 (disabledForUser)」の Mock で構築した MockNotificationEnvironment', () {
        const env = MockNotificationEnvironment.disabledForUser();

        group('When: check を呼ぶ', () {
          test('[Normal] T-WDV-AVL-10: disabledForUser では setting と ok=false の Availability を返す', () {
            final result = env.check('com.kallr.app');

            expect(result.setting, NotificationSetting.disabledForUser);
            expect(result.ok, isFalse);
          });
        });
      });

      group('Given: 状態「無効 (disabledByGroupPolicy)」の Mock で構築した MockNotificationEnvironment', () {
        const env = MockNotificationEnvironment.disabledByGroupPolicy();

        group('When: check を呼ぶ', () {
          test('[Normal] T-WDV-AVL-11: disabledByGroupPolicy では setting と ok=false の Availability を返す', () {
            final result = env.check('com.kallr.app');

            expect(result.setting, NotificationSetting.disabledByGroupPolicy);
            expect(result.ok, isFalse);
          });
        });
      });

      group('Given: 状態「無効 (disabledByManifest)」の Mock で構築した MockNotificationEnvironment', () {
        const env = MockNotificationEnvironment.disabledByManifest();

        group('When: check を呼ぶ', () {
          test('[Normal] T-WDV-AVL-12: disabledByManifest では setting と ok=false の Availability を返す', () {
            final result = env.check('com.kallr.app');

            expect(result.setting, NotificationSetting.disabledByManifest);
            expect(result.ok, isFalse);
          });
        });
      });
    });
  });
}
