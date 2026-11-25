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
import '../fakes.dart';
import '../mock_notification_environment.dart';

// internal helpers

/// W5 record whose three fields are all clear and match the observed state.
const _matchingInput = W5Input(
  recordedAumid: 'com.kallr.app',
  recordedPermission: 'user',
  recordedInstallMethod: 'unpackaged',
);

/// Runs w5Check on [_matchingInput] with an environment where the AUMID is
/// registered and a probe observing `user`.
///
/// Returns the report of that run.
W5Report _checkMatching() => w5Check(
  _matchingInput,
  MockNotificationEnvironment.ok(),
  const FakePermissionProbe('user'),
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
            final report = _checkMatching();

            expect(_resultsOf(report, 'aumid').map((r) => r.status), [
              W5FieldStatus.match,
            ]);
          });

          test('[Normal] T-WDV-W5C-02: 実行権限欄は記録と観測が同じなら match とする', () {
            final report = _checkMatching();

            expect(_resultsOf(report, 'permission').map((r) => r.status), [
              W5FieldStatus.match,
            ]);
          });

          test('[Normal] T-WDV-W5C-03: インストール方式欄は notChecked で記録値を表示する', () {
            final report = _checkMatching();

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
              final report = _checkMatching();

              expect(report.exitCode, 0);
            },
          );

          test('[Normal] T-WDV-W5C-05: aumid、permission、install-method の 3 欄をこの順で返す', () {
            final report = _checkMatching();

            expect(report.fields.map((r) => r.field), [
              'aumid',
              'permission',
              'install-method',
            ]);
          });
        });
      });
    });
  });
}
