// src: lib/environment/evaluate_availability.dart
// @(#) : evaluateAvailability
//
// Copyright (c) 2026 atsushifx <http://github.com/atsushifx>
//
// Released under the MIT License.
// https://opensource.org/licenses/MIT

import '../ids.dart';
import 'aumid_registry.dart';
import 'notification_environment.dart';
import 'notification_setting_source.dart';

/// Evaluates whether toast notifications can be shown for [aumid].
///
/// [aumid] is normalized first. Reads only; never writes to [registry].
Availability evaluateAvailability(
  String aumid,
  AumidRegistry registry,
  NotificationSettingSource settings,
) {
  final id = normalizeId(aumid);
  final setting = settings.read(id);
  final ok = setting == NotificationSetting.enabled;
  return Availability(
    registered: registry.exists(id),
    displayNameSet: (registry.readDisplayName(id) ?? '').trim().isNotEmpty,
    setting: setting,
    ok: ok,
    reason: ok ? null : setting.name,
  );
}
