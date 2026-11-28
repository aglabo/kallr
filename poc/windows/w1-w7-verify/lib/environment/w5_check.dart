// src: lib/environment/w5_check.dart
// @(#) : w5Check
//
// Copyright (c) 2026 atsushifx <http://github.com/atsushifx>
//
// Released under the MIT License.
// https://opensource.org/licenses/MIT

import '../errors.dart';
import '../ids.dart';
import 'notification_environment.dart';
import 'permission_probe.dart';

/// Permission levels a W5 record may state.
const _permissionLevels = {'user', 'administrator'};

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

  /// Recorded value: set for a `mismatch` and a `notChecked` field.
  final String? recorded;

  /// Observed value: set for a `mismatch` field only.
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
/// A recorded AUMID, permission or install method that is null, blank or
/// `記載なし` (ignoring surrounding whitespace) is `unclear` and is not
/// compared: the AUMID is not looked up and [probe] is not asked.
/// A clear install method is never compared: it is reported as `notChecked`
/// with the recorded value.
/// A clear AUMID is looked up with the value normalized by [normalizeId]. One
/// that [env] does not know as registered is a `mismatch` with that normalized
/// value as the recorded value, observed as `登録なし`; otherwise the AUMID is
/// reported as `match`.
/// A clear permission other than exactly `user` or `administrator`
/// (case-sensitive) throws a [UsageException], so no report is returned.
/// An allowed permission that differs from the one [probe] observes is a
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
    _checkInstallMethod(input.recordedInstallMethod),
  ],
);

/// Returns [recorded] when it is clear enough to compare, or null when it is
/// unclear: null, blank, or `記載なし` with or without surrounding whitespace.
String? _clearValue(String? recorded) => switch (recorded?.trim()) {
  null || '' || '記載なし' => null,
  _ => recorded,
};

/// Judges the [recorded] value of the field [field].
///
/// Returns an `unclear` result when [_clearValue] rejects [recorded], without
/// calling [judge]; otherwise returns what [judge] makes of the clear value.
W5FieldResult _checkField(
  String field,
  String? recorded,
  W5FieldResult Function(String value) judge,
) {
  final value = _clearValue(recorded);
  return value == null
      ? W5FieldResult(field: field, status: W5FieldStatus.unclear)
      : judge(value);
}

/// Reports the comparison of the field [field]: a `match` without values when
/// [matches] is true, otherwise a `mismatch` with [recorded] and [observed].
W5FieldResult _compared(
  String field, {
  required bool matches,
  required String recorded,
  required String observed,
}) => matches
    ? W5FieldResult(field: field, status: W5FieldStatus.match)
    : W5FieldResult(
        field: field,
        status: W5FieldStatus.mismatch,
        recorded: recorded,
        observed: observed,
      );

/// Checks the [recorded] AUMID against the registrations of [env].
W5FieldResult _checkAumid(String? recorded, NotificationEnvironment env) =>
    _checkField('aumid', recorded, (value) {
      final aumid = normalizeId(value);
      return _compared(
        'aumid',
        matches: env.isRegistered(aumid),
        recorded: aumid,
        observed: '登録なし',
      );
    });

/// Checks the [recorded] permission against the one observed by [probe].
///
/// Throws a [UsageException] for a clear value outside [_permissionLevels],
/// without asking [probe].
W5FieldResult _checkPermission(String? recorded, PermissionProbe probe) =>
    _checkField('permission', recorded, (value) {
      if (!_permissionLevels.contains(value)) {
        throw UsageException(
          'permission must be "user" or "administrator": "$value"',
        );
      }
      final observed = probe.current();
      return _compared(
        'permission',
        matches: value == observed,
        recorded: value,
        observed: observed,
      );
    });

/// Reports the [recorded] install method without comparing it.
W5FieldResult _checkInstallMethod(String? recorded) => _checkField(
  'install-method',
  recorded,
  (value) => W5FieldResult(
    field: 'install-method',
    status: W5FieldStatus.notChecked,
    recorded: value,
  ),
);
