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
import 'package:w1_w7_verify/environment/permission_probe.dart';
import 'package:w1_w7_verify/errors.dart';

import '../fakes.dart';
import '../mock_notification_environment.dart';

// internal helpers

/// `記載なし` with surrounding whitespace, recorded in each field in turn.
const _paddedUnclear = ' 記載なし ';

/// Runs w5Check on a W5 record with the AUMID [aumid], the permission
/// [recorded] and the install method [installMethod], by default a clear one,
/// against [env] and [probe].
///
/// Returns the report of that run.
W5Report _checkRecord({
  required String? recorded,
  required PermissionProbe probe,
  required NotificationEnvironment env,
  String? aumid = 'com.kallr.app',
  String? installMethod = 'unpackaged',
}) => w5Check(
  W5Input(
    recordedAumid: aumid,
    recordedPermission: recorded,
    recordedInstallMethod: installMethod,
  ),
  env,
  probe,
);

/// Runs [_checkRecord] against [env] with [permission] both recorded and
/// observed.
///
/// Returns the report of that run.
W5Report _checkClearRecord(String permission, NotificationEnvironment env) =>
    _checkRecord(
      recorded: permission,
      probe: FakePermissionProbe(permission),
      env: env,
    );

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

/// Runs [_checkRecord] with no permission recorded, in an environment where the
/// AUMID is not registered, so a mismatch and an unclear field occur together.
///
/// Returns the report of that run.
W5Report _checkUnregisteredWithoutPermission() => _checkRecord(
  recorded: null,
  probe: const FakePermissionProbe('user'),
  env: MockNotificationEnvironment.unregistered(),
);

/// Runs [_checkRecordedPermission] with differing permissions [recorded] and
/// [observed].
///
/// Returns the report of that run.
W5Report _checkPermissionMismatch({
  required String recorded,
  required String observed,
}) => _checkRecordedPermission(recorded, probe: FakePermissionProbe(observed));

/// Runs [_checkRecord] with the AUMID [aumid] and `user` both recorded and
/// observed, against [env], by default one where `com.kallr.app` is
/// registered.
///
/// Returns the report of that run.
W5Report _checkAumidRecord(String? aumid, {NotificationEnvironment? env}) =>
    _checkRecord(
      recorded: 'user',
      probe: const FakePermissionProbe('user'),
      env: env ?? MockNotificationEnvironment.ok(),
      aumid: aumid,
    );

/// Runs [_checkRecord] with the permission [recorded] against [probe], by default
/// one observing `user`, in an environment where the AUMID is registered.
///
/// Returns the report of that run.
W5Report _checkRecordedPermission(
  String? recorded, {
  PermissionProbe probe = const FakePermissionProbe('user'),
}) => _checkRecord(
  recorded: recorded,
  probe: probe,
  env: MockNotificationEnvironment.ok(),
);

/// Runs [_checkRecord] with the install method [installMethod] and `user` both
/// recorded and observed, in an environment where the AUMID is registered.
///
/// Returns the report of that run.
W5Report _checkInstallMethodRecord(String? installMethod) => _checkRecord(
  recorded: 'user',
  probe: const FakePermissionProbe('user'),
  env: MockNotificationEnvironment.ok(),
  installMethod: installMethod,
);

/// Runs [_checkRecord] with none of the three fields recorded, against [env] and
/// [probe], by default ones where `com.kallr.app` is registered and `user` is
/// observed.
///
/// Returns the report of that run.
W5Report _checkAllUnspecified({
  NotificationEnvironment? env,
  PermissionProbe probe = const FakePermissionProbe('user'),
}) => _checkRecord(
  recorded: null,
  probe: probe,
  env: env ?? MockNotificationEnvironment.ok(),
  aumid: null,
  installMethod: null,
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

      group('Given: 実行権限欄が未明確', () {
        group('When: w5Check を呼ぶ', () {
          test('[Error] T-WDV-W5C-20: 実行権限欄が指定なし (null) なら unclear とする', () {
            final report = _checkRecordedPermission(null);

            expect(_resultsOf(report, 'permission').map((r) => r.status), [
              W5FieldStatus.unclear,
            ]);
          });

          test('[Error] T-WDV-W5C-21: 実行権限欄が空文字なら unclear とする', () {
            final report = _checkRecordedPermission('');

            expect(_resultsOf(report, 'permission').map((r) => r.status), [
              W5FieldStatus.unclear,
            ]);
          });

          test('[Error] T-WDV-W5C-22: 実行権限欄が空白だけなら unclear とする', () {
            final report = _checkRecordedPermission('   ');

            expect(_resultsOf(report, 'permission').map((r) => r.status), [
              W5FieldStatus.unclear,
            ]);
          });

          test('[Error] T-WDV-W5C-23: 実行権限欄の値が「記載なし」なら unclear とする', () {
            final report = _checkRecordedPermission('記載なし');

            expect(_resultsOf(report, 'permission').map((r) => r.status), [
              W5FieldStatus.unclear,
            ]);
          });

          test(
            '[Error] T-WDV-W5C-24: 実行権限欄が未明確なら権限を観測せず、observed は null とする',
            () {
              final probe = RecordingPermissionProbe('user');

              final report = _checkRecordedPermission(null, probe: probe);

              expect(probe.calls, 0);
              expect(_resultsOf(report, 'permission').map((r) => r.observed), [
                null,
              ]);
            },
          );

          test(
            '[Error] T-WDV-W5C-25: 実行権限欄が指定なし (null) なら exitCode は 2 とする',
            () {
              final report = _checkRecordedPermission(null);

              expect(report.exitCode, 2);
            },
          );
        });
      });

      group('Given: インストール方式欄が未明確', () {
        group('When: w5Check を呼ぶ', () {
          test(
            '[Error] T-WDV-W5C-26: インストール方式欄が指定なし (null) なら unclear とする',
            () {
              final report = _checkInstallMethodRecord(null);

              expect(
                _resultsOf(report, 'install-method').map((r) => r.status),
                [W5FieldStatus.unclear],
              );
            },
          );

          test('[Error] T-WDV-W5C-27: インストール方式欄が空文字なら unclear とする', () {
            final report = _checkInstallMethodRecord('');

            expect(_resultsOf(report, 'install-method').map((r) => r.status), [
              W5FieldStatus.unclear,
            ]);
          });

          test('[Error] T-WDV-W5C-28: インストール方式欄が空白だけなら unclear とする', () {
            final report = _checkInstallMethodRecord('   ');

            expect(_resultsOf(report, 'install-method').map((r) => r.status), [
              W5FieldStatus.unclear,
            ]);
          });

          test('[Error] T-WDV-W5C-29: インストール方式欄の値が「記載なし」なら unclear とする', () {
            final report = _checkInstallMethodRecord('記載なし');

            expect(_resultsOf(report, 'install-method').map((r) => r.status), [
              W5FieldStatus.unclear,
            ]);
          });

          test(
            '[Error] T-WDV-W5C-30: インストール方式欄が指定なし (null) なら exitCode は 2 とする',
            () {
              final report = _checkInstallMethodRecord(null);

              expect(report.exitCode, 2);
            },
          );
        });
      });

      group('Given: 実行権限の値が user / administrator 以外', () {
        group('When: w5Check を呼ぶ', () {
          test(
            '[Error] T-WDV-W5C-31: 実行権限欄の値が root なら UsageException を送出する',
            () {
              expect(
                () => _checkRecordedPermission('root'),
                throwsA(isA<UsageException>()),
              );
            },
          );
        });
      });

      group('Given: インストール方式欄に任意の値を記録した', () {
        group('When: w5Check を呼ぶ', () {
          test('[Edge] T-WDV-W5C-32: インストール方式欄の値が msix でも notChecked で記録値を表示し、exitCode は 0 とする', () {
            final report = _checkInstallMethodRecord('msix');

            expect(
              _resultsOf(
                report,
                'install-method',
              ).map((r) => (r.status, r.recorded)),
              [(W5FieldStatus.notChecked, 'msix')],
            );
            expect(report.exitCode, 0);
          });
        });
      });

      group('Given: 不一致と未明確が別の欄に同時にある', () {
        group('When: w5Check を呼ぶ', () {
          test('[Edge] T-WDV-W5C-33: 実行権限欄が未明確でも AUMID 欄は mismatch とする', () {
            final report = _checkUnregisteredWithoutPermission();

            expect(_resultsOf(report, 'aumid').map((r) => r.status), [
              W5FieldStatus.mismatch,
            ]);
          });

          test('[Edge] T-WDV-W5C-34: AUMID の不一致があっても実行権限欄は unclear とし、exitCode は 2 とする', () {
            final report = _checkUnregisteredWithoutPermission();

            expect(_resultsOf(report, 'permission').map((r) => r.status), [
              W5FieldStatus.unclear,
            ]);
            expect(report.exitCode, 2);
          });
        });
      });

      group('Given: 記録の欄が前後に空白のある 記載なし', () {
        group('When: w5Check を呼ぶ', () {
          test('[Edge] T-WDV-W5C-35: AUMID 欄は unclear とし、登録を照合しない', () {
            final env = MockNotificationEnvironment.ok();

            final report = _checkAumidRecord(_paddedUnclear, env: env);

            expect(_resultsOf(report, 'aumid').map((r) => r.status), [
              W5FieldStatus.unclear,
            ]);
            expect(env.isRegisteredCalls, isEmpty);
          });

          test(
            '[Edge] T-WDV-W5C-36: 実行権限欄は unclear とし、UsageException を送出しない',
            () {
              late final W5Report report;

              expect(
                () => report = _checkRecordedPermission(_paddedUnclear),
                returnsNormally,
              );
              expect(_resultsOf(report, 'permission').map((r) => r.status), [
                W5FieldStatus.unclear,
              ]);
            },
          );

          test('[Edge] T-WDV-W5C-37: インストール方式欄は unclear とする', () {
            final report = _checkInstallMethodRecord(_paddedUnclear);

            expect(_resultsOf(report, 'install-method').map((r) => r.status), [
              W5FieldStatus.unclear,
            ]);
          });
        });
      });

      group('Given: 3 欄すべてが指定なし', () {
        group('When: w5Check を呼ぶ', () {
          test('[Edge] T-WDV-W5C-38: 3 欄すべてを unclear とし、exitCode は 2 とする', () {
            final report = _checkAllUnspecified();

            expect(report.fields.map((r) => (r.field, r.status)), [
              ('aumid', W5FieldStatus.unclear),
              ('permission', W5FieldStatus.unclear),
              ('install-method', W5FieldStatus.unclear),
            ]);
            expect(report.exitCode, 2);
          });

          test('[Edge] T-WDV-W5C-39: 登録も権限も照合しない', () {
            final env = MockNotificationEnvironment.ok();
            final probe = RecordingPermissionProbe('user');

            _checkAllUnspecified(env: env, probe: probe);

            expect(env.isRegisteredCalls, isEmpty);
            expect(probe.calls, 0);
          });
        });
      });

      group('Given: 整合チェックは読み取り専用', () {
        group('When: w5Check を呼ぶ', () {
          test('[Edge] T-WDV-W5C-40: 記録した AUMID で登録を 1 回だけ照合する', () {
            final env = MockNotificationEnvironment.ok();

            _checkAumidRecord('com.kallr.app', env: env);

            expect(env.isRegisteredCalls, ['com.kallr.app']);
          });

          test('[Edge] T-WDV-W5C-41: register も unregister も呼ばない', () {
            final env = MockNotificationEnvironment.ok();

            _checkAumidRecord('com.kallr.app', env: env);

            expect(env.registerCalls, isEmpty);
            expect(env.unregisterCalls, isEmpty);
          });
        });
      });

      group('Given: 実行権限の値が大文字を含む', () {
        group('When: w5Check を呼ぶ', () {
          test('[Edge] T-WDV-W5C-42: 実行権限欄の値が Administrator なら観測が administrator でも UsageException を送出する', () {
            expect(
              () => _checkRecordedPermission(
                'Administrator',
                probe: const FakePermissionProbe('administrator'),
              ),
              throwsA(isA<UsageException>()),
            );
          });
        });
      });

      group('Given: 記録した aumid の前後に空白がある', () {
        group('When: w5Check を呼ぶ', () {
          test(
            '[Edge] T-WDV-W5C-43: 前後の空白を削除した aumid で登録を照合し、AUMID 欄は match とする',
            () {
              final env = MockNotificationEnvironment.ok();

              final report = _checkAumidRecord(' com.kallr.app ', env: env);

              expect(env.isRegisteredCalls, ['com.kallr.app']);
              expect(_resultsOf(report, 'aumid').map((r) => r.status), [
                W5FieldStatus.match,
              ]);
            },
          );
        });
      });
    });
  });
}
