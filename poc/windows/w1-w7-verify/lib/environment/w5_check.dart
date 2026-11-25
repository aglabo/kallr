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

  /// Exit code of the check; currently always 0.
  int get exitCode => 0;
}

/// Checks the W5 record [input] against [env] and [probe].
///
/// The install method is never compared: it is reported as `notChecked` with
/// the recorded value.
/// The AUMID and permission statuses are currently fixed to `match`; [env] and
/// [probe] are not consulted.
W5Report w5Check(
  W5Input input,
  NotificationEnvironment env,
  PermissionProbe probe,
) => W5Report(
  fields: [
    const W5FieldResult(field: 'aumid', status: W5FieldStatus.match),
    const W5FieldResult(field: 'permission', status: W5FieldStatus.match),
    W5FieldResult(
      field: 'install-method',
      status: W5FieldStatus.notChecked,
      recorded: input.recordedInstallMethod,
    ),
  ],
);
