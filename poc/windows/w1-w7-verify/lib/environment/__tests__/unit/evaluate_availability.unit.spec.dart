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

/// AUMID `com.kallr.app` with surrounding spaces, for the normalization cases.
const _paddedAumid = ' com.kallr.app ';

/// AUMID made of non-ASCII characters only (apart from the dot).
const _nonAsciiAumid = 'かるる.通知';

/// DisplayName made of non-ASCII characters only, which must not count as empty.
const _nonAsciiDisplayName = 'かるる通知';

/// Registry read failure with Win32 code 5 (access denied), thrown by the fakes.
const _accessDenied = RegistryException('access denied', win32Code: 5);

/// Failure a setting source raises for the unknown setting value 99.
const _unknownSetting = RegistryException('unknown notification setting: 99');

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
        late FakeAumidRegistry registry;
        const settings = FakeNotificationSettingSource(
          NotificationSetting.enabled,
        );

        setUp(() {
          registry = FakeAumidRegistry({'com.kallr.app': 'Kallr'});
        });

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

          test('[Edge] T-WDV-AVL-22: 通知できる状態の確認ではレジストリへの書き込みも削除もしない', () {
            evaluateAvailability('com.kallr.app', registry, settings);

            expect(registry.writeArgs, isEmpty);
            expect(registry.deleteArgs, isEmpty);
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

          test('[Edge] T-WDV-AVL-23: 未登録の確認では登録を作らず削除もしない', () {
            final registry = FakeAumidRegistry();

            evaluateAvailability(
              'com.kallr.app',
              registry,
              const FakeNotificationSettingSource(NotificationSetting.enabled),
            );

            expect(registry.writeArgs, isEmpty);
            expect(registry.deleteArgs, isEmpty);
          });

          test('[Edge] T-WDV-AVL-26: 未登録の AUMID では DisplayName を一度も読まない', () {
            final registry = FakeAumidRegistry();

            evaluateAvailability(
              'com.kallr.app',
              registry,
              const FakeNotificationSettingSource(NotificationSetting.enabled),
            );

            expect(registry.readDisplayNameArgs, isEmpty);
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

          test('[Edge] T-WDV-AVL-27: DisplayName が空で通知設定が disabledForUser でも理由は DisplayName が空にする', () {
            final result = evaluateAvailability(
              'com.kallr.app',
              FakeAumidRegistry({'com.kallr.app': ''}),
              const FakeNotificationSettingSource(
                NotificationSetting.disabledForUser,
              ),
            );

            expect(result.reason, 'DisplayName が空');
            expect(result.setting, isNull);
          });

          test(
            '[Edge] T-WDV-AVL-28: DisplayName が空の確認では DisplayName を書き直さず削除もしない',
            () {
              final registry = FakeAumidRegistry({'com.kallr.app': ''});

              evaluateAvailability(
                'com.kallr.app',
                registry,
                const FakeNotificationSettingSource(
                  NotificationSetting.enabled,
                ),
              );

              expect(registry.writeArgs, isEmpty);
              expect(registry.deleteArgs, isEmpty);
            },
          );
        });
      });

      group('Given: com.kallr.app が登録済みで渡す AUMID の前後に空白がある', () {
        late FakeAumidRegistry registry;
        const settings = FakeNotificationSettingSource(
          NotificationSetting.enabled,
        );

        setUp(() {
          registry = FakeAumidRegistry({'com.kallr.app': 'Kallr'});
        });

        group('When: evaluateAvailability を呼ぶ', () {
          test('[Normal] T-WDV-AVL-13: 前後の空白を削除した AUMID で登録を調べ registered=true を返す', () {
            final result = evaluateAvailability(
              _paddedAumid,
              registry,
              settings,
            );

            expect(registry.existsArgs, ['com.kallr.app']);
            expect(result.registered, isTrue);
          });

          test('[Normal] T-WDV-AVL-14: 前後の空白を削除した AUMID で DisplayName を読む', () {
            evaluateAvailability(_paddedAumid, registry, settings);

            expect(registry.readDisplayNameArgs, ['com.kallr.app']);
          });

          test('[Normal] T-WDV-AVL-15: 前後の空白を削除した AUMID で通知設定を読む', () {
            final recordingSettings = RecordingNotificationSettingSource(
              NotificationSetting.enabled,
            );

            evaluateAvailability(_paddedAumid, registry, recordingSettings);

            expect(recordingSettings.readArgs, ['com.kallr.app']);
          });
        });
      });

      group('Given: レジストリまたは OS の読み取りが失敗する', () {
        group('When: evaluateAvailability を呼ぶ', () {
          test('[Error] T-WDV-AVL-16: exists の失敗は Win32 コードを保って再スローする', () {
            expect(
              () => evaluateAvailability(
                'com.kallr.app',
                FakeAumidRegistry()..existsError = _accessDenied,
                const FakeNotificationSettingSource(
                  NotificationSetting.enabled,
                ),
              ),
              throwsA(same(_accessDenied)),
            );
          });

          test('[Error] T-WDV-AVL-17: DisplayName の読み取り失敗は再スローする', () {
            expect(
              () => evaluateAvailability(
                'com.kallr.app',
                FakeAumidRegistry({'com.kallr.app': 'Kallr'})
                  ..readDisplayNameError = _accessDenied,
                const FakeNotificationSettingSource(
                  NotificationSetting.enabled,
                ),
              ),
              throwsA(same(_accessDenied)),
            );
          });

          test('[Error] T-WDV-AVL-18: 通知設定の読み取り失敗は再スローする', () {
            expect(
              () => evaluateAvailability(
                'com.kallr.app',
                FakeAumidRegistry({'com.kallr.app': 'Kallr'}),
                const ThrowingNotificationSettingSource(_accessDenied),
              ),
              throwsA(same(_accessDenied)),
            );
          });

          test('[Error] T-WDV-AVL-19: 通知設定が未知の値 99 の失敗は可否の結果にせず送出する', () {
            expect(
              () => evaluateAvailability(
                'com.kallr.app',
                FakeAumidRegistry({'com.kallr.app': 'Kallr'}),
                const ThrowingNotificationSettingSource(_unknownSetting),
              ),
              throwsA(same(_unknownSetting)),
            );
          });
        });
      });

      group('Given: 登録を削除した後も通知設定は enabled のまま', () {
        late FakeAumidRegistry registry;
        const settings = FakeNotificationSettingSource(
          NotificationSetting.enabled,
        );

        setUp(() {
          registry = FakeAumidRegistry({'com.kallr.app': 'Kallr'})
            ..delete('com.kallr.app');
        });

        group('When: evaluateAvailability を呼ぶ', () {
          test(
            '[Edge] T-WDV-AVL-20: 通知設定が enabled でも削除済みの AUMID は未登録の結果で返す',
            () {
              final result = evaluateAvailability(
                'com.kallr.app',
                registry,
                settings,
              );

              expect(result.ok, isFalse);
              expect(result.reason, '未登録');
              expect(result.setting, isNull);
            },
          );
        });
      });

      group('Given: 登録の直後で通知設定が enabled', () {
        late FakeAumidRegistry registry;
        late RecordingNotificationSettingSource settings;

        setUp(() {
          registry = FakeAumidRegistry({'com.kallr.app': 'Kallr'});
          settings = RecordingNotificationSettingSource(
            NotificationSetting.enabled,
          );
        });

        group('When: evaluateAvailability を 1 回呼ぶ', () {
          test(
            '[Edge] T-WDV-AVL-21: 表示の遅延は観測せず、通知設定を 1 回だけ読んで ok=true を返す',
            () {
              final result = evaluateAvailability(
                'com.kallr.app',
                registry,
                settings,
              );

              expect(result.ok, isTrue);
              expect(settings.readArgs, ['com.kallr.app']);
            },
          );
        });
      });

      group('Given: 非 ASCII の AUMID が登録済みで通知設定が enabled', () {
        late FakeAumidRegistry registry;
        late RecordingNotificationSettingSource settings;

        setUp(() {
          registry = FakeAumidRegistry({_nonAsciiAumid: 'Kallr'});
          settings = RecordingNotificationSettingSource(
            NotificationSetting.enabled,
          );
        });

        group('When: evaluateAvailability を呼ぶ', () {
          test('[Edge] T-WDV-AVL-24: 非 ASCII の AUMID を変えずに registry と設定へ渡し ok=true を返す', () {
            final result = evaluateAvailability(
              _nonAsciiAumid,
              registry,
              settings,
            );

            expect(registry.existsArgs, [_nonAsciiAumid]);
            expect(registry.readDisplayNameArgs, [_nonAsciiAumid]);
            expect(settings.readArgs, [_nonAsciiAumid]);
            expect(result.ok, isTrue);
          });
        });
      });

      group('Given: DisplayName が非 ASCII の登録があり通知設定が enabled', () {
        late FakeAumidRegistry registry;
        const settings = FakeNotificationSettingSource(
          NotificationSetting.enabled,
        );

        setUp(() {
          registry = FakeAumidRegistry({'com.kallr.app': _nonAsciiDisplayName});
        });

        group('When: evaluateAvailability を呼ぶ', () {
          test(
            '[Edge] T-WDV-AVL-25: 非 ASCII の DisplayName を空とみなさず ok=true を返す',
            () {
              final result = evaluateAvailability(
                'com.kallr.app',
                registry,
                settings,
              );

              expect(result.displayNameSet, isTrue);
              expect(result.ok, isTrue);
            },
          );
        });
      });
    });
  });
}
