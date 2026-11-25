// src: lib/environment/__tests__/unit/w5_check.unit.spec.dart
// @(#) : unit tests for w5Check
//
// Copyright (c) 2026 atsushifx <http://github.com/atsushifx>
//
// Released under the MIT License.
// https://opensource.org/licenses/MIT

// test framework
import 'package:test/test.dart';

// test target
import 'package:w1_w7_verify/environment/w5_check.dart';

// helpers
import 'package:w1_w7_verify/environment/notification_environment.dart';

import '../fakes.dart';
import '../mock_notification_environment.dart';

// internal helpers

/// Runs w5Check on a W5 record with the AUMID [aumid], the permission
/// [recorded] and a clear install method, against [env] and a probe observing
/// [observed].
///
/// Returns the report of that run.
W5Report _checkRecord({
  required String recorded,
  required String observed,
  required NotificationEnvironment env,
  String? aumid = 'com.kallr.app',
}) => w5Check(
  W5Input(
    recordedAumid: aumid,
    recordedPermission: recorded,
    recordedInstallMethod: 'unpackaged',
  ),
  env,
  FakePermissionProbe(observed),
);

/// Runs [_checkRecord] against [env] with [permission] both recorded and
/// observed.
///
/// Returns the report of that run.
W5Report _checkClearRecord(String permission, NotificationEnvironment env) =>
    _checkRecord(recorded: permission, observed: permission, env: env);

/// Runs [_checkClearRecord] for [permission] in an environment where the AUMID
/// is registered.
///
/// Returns the report of that run.
W5Report _checkMatching(String permission) =>
    _checkClearRecord(permission, MockNotificationEnvironment.ok());

/// Runs [_checkClearRecord] for `user` in an environment where the AUMID is not
/// registered.
///
/// Returns the report of that run.
W5Report _checkUnregistered() =>
    _checkClearRecord('user', MockNotificationEnvironment.unregistered());

/// Runs [_checkRecord] with differing permissions [recorded] and [observed] in
/// an environment where the AUMID is registered.
///
/// Returns the report of that run.
W5Report _checkPermissionMismatch({
  required String recorded,
  required String observed,
}) => _checkRecord(
  recorded: recorded,
  observed: observed,
  env: MockNotificationEnvironment.ok(),
);

/// Runs [_checkRecord] with the AUMID [aumid] and `user` both recorded and
/// observed, against [env], by default one where `com.kallr.app` is
/// registered.
///
/// Returns the report of that run.
W5Report _checkAumidRecord(String? aumid, {NotificationEnvironment? env}) =>
    _checkRecord(
      recorded: 'user',
      observed: 'user',
      env: env ?? MockNotificationEnvironment.ok(),
      aumid: aumid,
    );

/// Selects the results of [report] whose field name is [field].
///
/// Returns every match, so a missing field shows up as an empty list.
Iterable<W5FieldResult> _resultsOf(W5Report report, String field) =>
    report.fields.where((result) => result.field == field);

void main() {
  /// w5Check compares the recorded W5 fields with the observed state.
  group('w5Check', () {
    /// Reports one result per W5 field and the exit code of the whole check.
    group('T-WDV-W5C: w5Check', () {
      group('Given: 3 欄が明確で記録が実態と一致 (user)', () {
        group('When: w5Check を呼ぶ', () {
          test('[Normal] T-WDV-W5C-01: AUMID 欄は登録があれば match とする', () {
            final report = _checkMatching('user');

            expect(_resultsOf(report, 'aumid').map((r) => r.status), [
              W5FieldStatus.match,
            ]);
          });

          test('[Normal] T-WDV-W5C-02: 実行権限欄は記録と観測が同じなら match とする', () {
            final report = _checkMatching('user');

            expect(_resultsOf(report, 'permission').map((r) => r.status), [
              W5FieldStatus.match,
            ]);
          });

          test('[Normal] T-WDV-W5C-03: インストール方式欄は notChecked で記録値を表示する', () {
            final report = _checkMatching('user');

            expect(
              _resultsOf(
                report,
                'install-method',
              ).map((r) => (r.status, r.recorded, r.observed)),
              [(W5FieldStatus.notChecked, 'unpackaged', null)],
            );
          });

          test(
            '[Normal] T-WDV-W5C-04: 全欄が match / notChecked なら exitCode は 0 とする',
            () {
              final report = _checkMatching('user');

              expect(report.exitCode, 0);
            },
          );

          test('[Normal] T-WDV-W5C-05: aumid、permission、install-method の 3 欄をこの順で返す', () {
            final report = _checkMatching('user');

            expect(report.fields.map((r) => r.field), [
              'aumid',
              'permission',
              'install-method',
            ]);
          });
        });
      });

      group('Given: 実行権限が administrator で記録と一致', () {
        group('When: w5Check を呼ぶ', () {
          test(
            '[Normal] T-WDV-W5C-06: 実行権限欄は administrator の記録と観測が同じなら match とする',
            () {
              final report = _checkMatching('administrator');

              expect(_resultsOf(report, 'permission').map((r) => r.status), [
                W5FieldStatus.match,
              ]);
            },
          );

          test(
            '[Normal] T-WDV-W5C-07: administrator で全欄が一致するなら exitCode は 0 とする',
            () {
              final report = _checkMatching('administrator');

              expect(report.exitCode, 0);
            },
          );
        });
      });

      group('Given: 記録した AUMID が HKCU に登録されていない', () {
        group('When: w5Check を呼ぶ', () {
          test(
            '[Error] T-WDV-W5C-08: AUMID 欄は mismatch とし、記録値と観測値「登録なし」を報告する',
            () {
              final report = _checkUnregistered();

              expect(
                _resultsOf(
                  report,
                  'aumid',
                ).map((r) => (r.status, r.recorded, r.observed)),
                [(W5FieldStatus.mismatch, 'com.kallr.app', '登録なし')],
              );
            },
          );

          test('[Error] T-WDV-W5C-09: AUMID の不一致があれば exitCode は 2 とする', () {
            final report = _checkUnregistered();

            expect(report.exitCode, 2);
          });

          test('[Error] T-WDV-W5C-10: unclear の欄は無く、実行権限欄は match、インストール方式欄は notChecked のままとする', () {
            final report = _checkUnregistered();

            expect(
              report.fields.where((r) => r.status == W5FieldStatus.unclear),
              isEmpty,
            );
            expect(
              [
                ..._resultsOf(report, 'permission'),
                ..._resultsOf(report, 'install-method'),
              ].map((r) => r.status),
              [W5FieldStatus.match, W5FieldStatus.notChecked],
            );
          });
        });
      });

      group('Given: 記録した実行権限が観測した権限と異なる', () {
        group('When: w5Check を呼ぶ', () {
          test('[Error] T-WDV-W5C-11: 実行権限欄は記録 administrator・観測 user なら mismatch とし、両方の値を報告する', () {
            final report = _checkPermissionMismatch(
              recorded: 'administrator',
              observed: 'user',
            );

            expect(
              _resultsOf(
                report,
                'permission',
              ).map((r) => (r.status, r.recorded, r.observed)),
              [(W5FieldStatus.mismatch, 'administrator', 'user')],
            );
          });

          test('[Error] T-WDV-W5C-12: 実行権限の不一致があれば exitCode は 2 とする', () {
            final report = _checkPermissionMismatch(
              recorded: 'administrator',
              observed: 'user',
            );

            expect(report.exitCode, 2);
          });

          test('[Error] T-WDV-W5C-13: 実行権限欄は記録 user・観測 administrator なら mismatch とし、両方の値を報告する', () {
            final report = _checkPermissionMismatch(
              recorded: 'user',
              observed: 'administrator',
            );

            expect(
              _resultsOf(
                report,
                'permission',
              ).map((r) => (r.status, r.recorded, r.observed)),
              [(W5FieldStatus.mismatch, 'user', 'administrator')],
            );
          });
        });
      });

      group('Given: AUMID 欄が未明確', () {
        group('When: w5Check を呼ぶ', () {
          test('[Error] T-WDV-W5C-14: AUMID 欄が指定なし (null) なら unclear とする', () {
            final report = _checkAumidRecord(null);

            expect(_resultsOf(report, 'aumid').map((r) => r.status), [
              W5FieldStatus.unclear,
            ]);
          });

          test('[Error] T-WDV-W5C-15: AUMID 欄が空文字なら unclear とする', () {
            final report = _checkAumidRecord('');

            expect(_resultsOf(report, 'aumid').map((r) => r.status), [
              W5FieldStatus.unclear,
            ]);
          });

          test('[Error] T-WDV-W5C-16: AUMID 欄が空白だけなら unclear とする', () {
            final report = _checkAumidRecord('   ');

            expect(_resultsOf(report, 'aumid').map((r) => r.status), [
              W5FieldStatus.unclear,
            ]);
          });

          test('[Error] T-WDV-W5C-17: AUMID 欄の値が「記載なし」なら unclear とする', () {
            final report = _checkAumidRecord('記載なし');

            expect(_resultsOf(report, 'aumid').map((r) => r.status), [
              W5FieldStatus.unclear,
            ]);
          });

          test('[Error] T-WDV-W5C-18: AUMID 欄が未明確なら登録の照合をしない', () {
            final env = MockNotificationEnvironment.ok();

            _checkAumidRecord(null, env: env);

            expect(env.isRegisteredCalls, isEmpty);
          });

          test('[Error] T-WDV-W5C-19: AUMID 欄が「記載なし」なら exitCode は 2 とする', () {
            final report = _checkAumidRecord('記載なし');

            expect(report.exitCode, 2);
          });
        });
      });
    });
  });
}
