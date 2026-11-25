// src: lib/environment/w5_check.dart
// @(#) : w5Check
//
// Copyright (c) 2026 atsushifx <http://github.com/atsushifx>
//
// Released under the MIT License.
// https://opensource.org/licenses/MIT

import 'notification_environment.dart';
import 'permission_probe.dart';

/// W5 fields as recorded by the verifier.
final class W5Input {
  /// Creates the record from its field values.
  const W5Input({
    this.recordedAumid,
    this.recordedPermission,
    this.recordedInstallMethod,
  });

  /// Recorded AUMID.
  final String? recordedAumid;

  /// Recorded permission level: `user` or `administrator`.
  final String? recordedPermission;

  /// Recorded install method.
  final String? recordedInstallMethod;
}

/// Verdict on one W5 field.
enum W5FieldStatus {
  /// The record matches the observed state.
  match,

  /// The record differs from the observed state.
  mismatch,

  /// The record is not clear enough to compare.
  unclear,

  /// The field is not compared.
  notChecked,
}

/// Result of one W5 field.
final class W5FieldResult {
  /// Creates a result from its field values.
  const W5FieldResult({
    required this.field,
    required this.status,
    this.recorded,
    this.observed,
  });

  /// Field name: `aumid`, `permission` or `install-method`.
  final String field;

  /// Verdict on the field.
  final W5FieldStatus status;

  /// Recorded value.
  final String? recorded;

  /// Observed value.
  final String? observed;
}

/// Result of a W5 check.
final class W5Report {
  /// Creates a report holding [fields].
  const W5Report({required this.fields});

  /// Results per field.
  final List<W5FieldResult> fields;

  /// Exit code of the check: 2 when any field is a `mismatch` or `unclear`,
  /// otherwise 0.
  int get exitCode =>
      fields.any(
        (result) =>
            result.status == W5FieldStatus.mismatch ||
            result.status == W5FieldStatus.unclear,
      )
      ? 2
      : 0;
}

/// Checks the W5 record [input] against [env] and [probe].
///
/// The install method is never compared: it is reported as `notChecked` with
/// the recorded value.
/// A recorded AUMID that is null, blank or `記載なし` is `unclear` and is not
/// looked up.
/// A clear AUMID that [env] does not know as registered is a `mismatch`,
/// observed as `登録なし`; otherwise the AUMID is reported as `match`.
/// A recorded permission that differs from the one [probe] observes is a
/// `mismatch` with both values; otherwise the permission is reported as
/// `match`.
W5Report w5Check(
  W5Input input,
  NotificationEnvironment env,
  PermissionProbe probe,
) => W5Report(
  fields: [
    _checkAumid(input.recordedAumid, env),
    _checkPermission(input.recordedPermission, probe),
    W5FieldResult(
      field: 'install-method',
      status: W5FieldStatus.notChecked,
      recorded: input.recordedInstallMethod,
    ),
  ],
);

/// Checks the [recorded] AUMID against the registrations of [env].
W5FieldResult _checkAumid(String? recorded, NotificationEnvironment env) {
  if (recorded == null || recorded.trim().isEmpty || recorded == '記載なし') {
    return const W5FieldResult(field: 'aumid', status: W5FieldStatus.unclear);
  }
  return !env.isRegistered(recorded)
      ? W5FieldResult(
          field: 'aumid',
          status: W5FieldStatus.mismatch,
          recorded: recorded,
          observed: '登録なし',
        )
      : const W5FieldResult(field: 'aumid', status: W5FieldStatus.match);
}

/// Checks the [recorded] permission against the one observed by [probe].
W5FieldResult _checkPermission(String? recorded, PermissionProbe probe) {
  final observed = probe.current();
  return recorded != null && recorded != observed
      ? W5FieldResult(
          field: 'permission',
          status: W5FieldStatus.mismatch,
          recorded: recorded,
          observed: observed,
        )
      : const W5FieldResult(field: 'permission', status: W5FieldStatus.match);
}
