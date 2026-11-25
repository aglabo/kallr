// src: lib/environment/evaluate_availability.dart
// @(#) : evaluateAvailability
//
// Copyright (c) 2026 atsushifx <http://github.com/atsushifx>
//
// Released under the MIT License.
// https://opensource.org/licenses/MIT

import '../errors.dart';
import '../ids.dart';
import 'aumid_registry.dart';
import 'notification_environment.dart';
import 'notification_setting_source.dart';

/// Evaluates whether toast notifications can be shown for [aumid].
///
/// [aumid] is normalized first. Reads only; never writes to [registry].
/// An unregistered AUMID, or a missing or blank DisplayName, is reported as a
/// result, without reading [settings].
/// Throws [UsageException] when the normalized AUMID is empty, before any
/// read of [registry] or [settings].
/// A read failure of [registry] or [settings] propagates unchanged; it is never
/// turned into an unavailable result.
Availability evaluateAvailability(
  String aumid,
  AumidRegistry registry,
  NotificationSettingSource settings,
) {
  final id = normalizeId(aumid);
  if (id.isEmpty) {
    throw const UsageException('AUMID must not be empty');
  }
  if (!registry.exists(id)) {
    return const Availability(
      registered: false,
      displayNameSet: false,
      ok: false,
      reason: '未登録',
    );
  }
  if ((registry.readDisplayName(id) ?? '').trim().isEmpty) {
    return const Availability(
      registered: true,
      displayNameSet: false,
      ok: false,
      reason: 'DisplayName が空',
    );
  }
  return _availabilityOfSetting(settings.read(id));
}

/// Result for a registered AUMID with a DisplayName, judged by [setting].
Availability _availabilityOfSetting(NotificationSetting setting) =>
    setting == NotificationSetting.enabled
    ? const Availability.ok()
    : Availability(
        registered: true,
        displayNameSet: true,
        setting: setting,
        ok: false,
        reason: setting.name,
      );
