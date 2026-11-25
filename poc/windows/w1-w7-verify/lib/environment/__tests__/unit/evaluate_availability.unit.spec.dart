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
import 'package:w1_w7_verify/errors.dart';

// helpers
import '../fakes.dart';

// internal helpers

/// Registered DisplayName values that count as empty (ID branch, label, value).
const _emptyDisplayNames = <(String, String, String?)>[
  ('01', 'null', null),
  ('02', '空文字', ''),
  ('03', '空白だけ', '   '),
];

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

      group('Given: AUMID が空文字', () {
        group('When: evaluateAvailability を呼ぶ', () {
          test('[Error] T-WDV-AVL-06: 空文字の AUMID は UsageException で拒否する', () {
            expect(
              () => evaluateAvailability(
                '',
                FakeAumidRegistry(),
                const FakeNotificationSettingSource(
                  NotificationSetting.enabled,
                ),
              ),
              throwsA(isA<UsageException>()),
            );
          });

          test('[Error] T-WDV-AVL-07: 空文字の AUMID では registry と設定を一度も読まない', () {
            final registry = FailingAumidRegistry();
            final settings = FailingNotificationSettingSource();

            expect(
              () => evaluateAvailability('', registry, settings),
              throwsA(isA<UsageException>()),
            );
            expect(registry.calls, 0);
            expect(settings.calls, 0);
          });
        });
      });

      group('Given: AUMID が空白だけ', () {
        group('When: evaluateAvailability を呼ぶ', () {
          test('[Error] T-WDV-AVL-08: 空白だけの AUMID は UsageException で拒否する', () {
            expect(
              () => evaluateAvailability(
                '   ',
                FakeAumidRegistry(),
                const FakeNotificationSettingSource(
                  NotificationSetting.enabled,
                ),
              ),
              throwsA(isA<UsageException>()),
            );
          });
        });
      });

      group('Given: AUMID の登録が無い', () {
        group('When: evaluateAvailability を呼ぶ', () {
          test('[Error] T-WDV-AVL-09: 未登録は例外ではなく通知設定が未評価の結果で返す', () {
            final result = evaluateAvailability(
              'com.kallr.app',
              FakeAumidRegistry(),
              const FakeNotificationSettingSource(NotificationSetting.enabled),
            );

            expect(result.registered, isFalse);
            expect(result.displayNameSet, isFalse);
            expect(result.setting, isNull);
            expect(result.ok, isFalse);
            expect(result.reason, '未登録');
          });

          test('[Error] T-WDV-AVL-10: 未登録の AUMID では通知設定を一度も読まない', () {
            final settings = FailingNotificationSettingSource();

            evaluateAvailability(
              'com.kallr.app',
              FakeAumidRegistry(),
              settings,
            );

            expect(settings.calls, 0);
          });
        });
      });

      group('Given: AUMID の登録はあるが DisplayName が空', () {
        group('When: evaluateAvailability を呼ぶ', () {
          for (final (branch, label, displayName) in _emptyDisplayNames) {
            test('[Error] T-WDV-AVL-11-$branch: DisplayName が $label なら'
                '例外ではなく通知設定が未評価の結果で返す', () {
              final result = evaluateAvailability(
                'com.kallr.app',
                FakeAumidRegistry({'com.kallr.app': displayName}),
                const FakeNotificationSettingSource(
                  NotificationSetting.enabled,
                ),
              );

              expect(result.registered, isTrue);
              expect(result.displayNameSet, isFalse);
              expect(result.setting, isNull);
              expect(result.ok, isFalse);
              expect(result.reason, 'DisplayName が空');
            });
          }

          test(
            '[Error] T-WDV-AVL-12: DisplayName が空の AUMID では通知設定を一度も読まない',
            () {
              final settings = FailingNotificationSettingSource();

              evaluateAvailability(
                'com.kallr.app',
                FakeAumidRegistry({'com.kallr.app': ''}),
                settings,
              );

              expect(settings.calls, 0);
            },
          );
        });
      });

      group('Given: com.kallr.app が登録済みで渡す AUMID の前後に空白がある', () {
        group('When: evaluateAvailability を呼ぶ', () {
          test('[Normal] T-WDV-AVL-13: 前後の空白を削除した AUMID で登録を調べ registered=true を返す', () {
            final registry = FakeAumidRegistry({'com.kallr.app': 'Kallr'});

            final result = evaluateAvailability(
              ' com.kallr.app ',
              registry,
              const FakeNotificationSettingSource(NotificationSetting.enabled),
            );

            expect(registry.existsArgs, ['com.kallr.app']);
            expect(result.registered, isTrue);
          });
        });
      });
    });
  });
}
