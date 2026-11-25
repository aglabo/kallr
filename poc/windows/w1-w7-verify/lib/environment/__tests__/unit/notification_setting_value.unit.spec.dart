// src: lib/environment/__tests__/unit/notification_setting_value.unit.spec.dart
// @(#) : unit tests for notificationSettingFromValue
//
// Copyright (c) 2026 atsushifx <http://github.com/atsushifx>
//
// Released under the MIT License.
// https://opensource.org/licenses/MIT

// test framework
import 'package:test/test.dart';

// test target
import 'package:w1_w7_verify/environment/notification_environment.dart';
import 'package:w1_w7_verify/environment/notification_setting_value.dart';
import 'package:w1_w7_verify/errors.dart';

// internal helpers

/// Matches a thrown [RegistryException] for the unknown setting [value]: no
/// Win32 code, and a message that contains the value.
///
/// Returns the matcher for a closure that converts [value].
Matcher _throwsUnknownSetting(int value) => throwsA(
  isA<RegistryException>()
      .having((e) => e.win32Code, 'win32Code', isNull)
      .having((e) => e.message, 'message', contains('$value')),
);

void main() {
  // OS の通知設定の数値を NotificationSetting に変換する関数。
  group('notificationSettingFromValue', () {
    // 定義済みの値 (0〜4) の変換と、それ以外の値の拒否を検証する。
    group('T-WDV-NSV: notificationSettingFromValue', () {
      group('Given: OS が定める数値', () {
        group('When: notificationSettingFromValue を呼ぶ', () {
          test('[Normal] T-WDV-NSV-01: 値 0 は enabled になる', () {
            expect(
              notificationSettingFromValue(0),
              NotificationSetting.enabled,
            );
          });

          test('[Normal] T-WDV-NSV-02: 値 1 は disabledForApplication になる', () {
            expect(
              notificationSettingFromValue(1),
              NotificationSetting.disabledForApplication,
            );
          });

          test('[Normal] T-WDV-NSV-03: 値 2 は disabledForUser になる', () {
            expect(
              notificationSettingFromValue(2),
              NotificationSetting.disabledForUser,
            );
          });

          test('[Normal] T-WDV-NSV-04: 値 3 は disabledByGroupPolicy になる', () {
            expect(
              notificationSettingFromValue(3),
              NotificationSetting.disabledByGroupPolicy,
            );
          });

          test('[Normal] T-WDV-NSV-05: 値 4 は disabledByManifest になる', () {
            expect(
              notificationSettingFromValue(4),
              NotificationSetting.disabledByManifest,
            );
          });
        });
      });

      group('Given: 未知の数値', () {
        group('When: notificationSettingFromValue を呼ぶ', () {
          test('[Error] T-WDV-NSV-06: 値 99 は win32Code が null の RegistryException とする', () {
            expect(
              () => notificationSettingFromValue(99),
              _throwsUnknownSetting(99),
            );
          });
        });
      });

      group('Given: 定義の範囲のすぐ外の数値', () {
        group('When: notificationSettingFromValue を呼ぶ', () {
          test('[Edge] T-WDV-NSV-07: 値 5 は win32Code が null の RegistryException とする', () {
            expect(
              () => notificationSettingFromValue(5),
              _throwsUnknownSetting(5),
            );
          });

          test('[Edge] T-WDV-NSV-08: 値 -1 は win32Code が null の RegistryException とする', () {
            expect(
              () => notificationSettingFromValue(-1),
              _throwsUnknownSetting(-1),
            );
          });
        });
      });
    });
  });
}
