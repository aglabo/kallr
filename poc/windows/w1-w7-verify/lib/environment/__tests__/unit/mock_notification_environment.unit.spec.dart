// src: lib/environment/__tests__/unit/mock_notification_environment.unit.spec.dart
// @(#) : unit tests for MockNotificationEnvironment
//
// Copyright (c) 2026 atsushifx <http://github.com/atsushifx>
//
// Released under the MIT License.
// https://opensource.org/licenses/MIT

// test framework
import 'package:test/test.dart';

// test target
import 'package:w1_w7_verify/environment/notification_environment.dart';

// internal helpers
import '../fakes.dart';
import '../mock_notification_environment.dart';

void main() {
  group('MockNotificationEnvironment', () {
    group('T-WDV-MNE: MockNotificationEnvironment', () {
      group(
        'Given: 状態「OK (通知できる)」の Mock で構築した MockNotificationEnvironment',
        () {
          final env = MockNotificationEnvironment.ok();

          group('When: check を呼ぶ', () {
            test('[Normal] T-WDV-MNE-01: ok=true の Availability を返す', () {
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
        final env = MockNotificationEnvironment.unregistered();

        group('When: check を呼ぶ', () {
          test('[Normal] T-WDV-MNE-02: 未登録の Availability を返す', () {
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
          final env = MockNotificationEnvironment.displayNameEmpty();

          group('When: check を呼ぶ', () {
            test('[Normal] T-WDV-MNE-03: DisplayName 空の Availability を返す', () {
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
        final env = MockNotificationEnvironment.disabledForApplication();

        group('When: check を呼ぶ', () {
          test('[Normal] T-WDV-MNE-04: disabledForApplication では setting と ok=false の Availability を返す', () {
            final result = env.check('com.kallr.app');

            expect(result.setting, NotificationSetting.disabledForApplication);
            expect(result.ok, isFalse);
          });
        });
      });

      group('Given: 状態「無効 (disabledForUser)」の Mock で構築した MockNotificationEnvironment', () {
        final env = MockNotificationEnvironment.disabledForUser();

        group('When: check を呼ぶ', () {
          test('[Normal] T-WDV-MNE-05: disabledForUser では setting と ok=false の Availability を返す', () {
            final result = env.check('com.kallr.app');

            expect(result.setting, NotificationSetting.disabledForUser);
            expect(result.ok, isFalse);
          });
        });
      });

      group('Given: 状態「無効 (disabledByGroupPolicy)」の Mock で構築した MockNotificationEnvironment', () {
        final env = MockNotificationEnvironment.disabledByGroupPolicy();

        group('When: check を呼ぶ', () {
          test('[Normal] T-WDV-MNE-06: disabledByGroupPolicy では setting と ok=false の Availability を返す', () {
            final result = env.check('com.kallr.app');

            expect(result.setting, NotificationSetting.disabledByGroupPolicy);
            expect(result.ok, isFalse);
          });
        });
      });

      group('Given: 状態「無効 (disabledByManifest)」の Mock で構築した MockNotificationEnvironment', () {
        final env = MockNotificationEnvironment.disabledByManifest();

        group('When: check を呼ぶ', () {
          test('[Normal] T-WDV-MNE-07: disabledByManifest では setting と ok=false の Availability を返す', () {
            final result = env.check('com.kallr.app');

            expect(result.setting, NotificationSetting.disabledByManifest);
            expect(result.ok, isFalse);
          });
        });
      });

      group('Given: Mock と、呼ばれると失敗する Fake AumidRegistry / NotificationSettingSource', () {
        late FailingAumidRegistry registry;
        late FailingNotificationSettingSource settings;
        late MockNotificationEnvironment env;

        setUp(() {
          registry = FailingAumidRegistry();
          settings = FailingNotificationSettingSource();
          env = MockNotificationEnvironment(
            const Availability.ok(),
            registry: registry,
            settings: settings,
          );
        });

        group('When: register を呼ぶ', () {
          test('[Normal] T-WDV-MNE-08: 呼び出しを記録するだけで、レジストリと OS を呼ばない', () {
            env.register('com.kallr.app', 'Kallr');

            expect(env.registerCalls, [
              (aumid: 'com.kallr.app', displayName: 'Kallr'),
            ]);
            expect(registry.calls, 0);
            expect(settings.calls, 0);
          });
        });

        group('When: unregister を呼ぶ', () {
          test('[Normal] T-WDV-MNE-09: 呼び出しを記録するだけで、レジストリと OS を呼ばない', () {
            env.unregister('com.kallr.app');

            expect(env.unregisterCalls, ['com.kallr.app']);
            expect(registry.calls, 0);
            expect(settings.calls, 0);
          });
        });
      });
    });
  });
}
