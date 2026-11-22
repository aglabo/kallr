---
title: "Implementation Tasks: environment"
module: kallr/windows-dist-verify
status: Active
created: "2026-11-22 00:00:00"
source: specifications-environment.md
version: 1.0.0
---

<!-- textlint-disable ja-technical-writing/sentence-length -->
<!-- textlint-disable ja-technical-writing/max-comma -->
<!-- markdownlint-disable no-duplicate-heading line-length -->

> このドキュメントは specifications-environment.md から導いた実装タスクを含む。
> 各タスクは 1 つの単体テストケース (`it()` ブロック) に対応する。

---

## Task Summary

| Test Target                                | Scenarios | Cases | Status  |
| ------------------------------------------ | --------- | ----- | ------- |
| T-08: evaluateAvailability (AVL)           | 14        | 36    | pending |
| T-09: w5Check (W5C)                        | 14        | 40    | pending |
| T-13: DefaultNotificationEnvironment (NEV) | 10        | 13    | pending |

---

## T-08: evaluateAvailability (AVL)

### [正常] Normal Cases

#### T-08-01: Given 登録あり・DisplayName あり・通知設定が enabled, When evaluateAvailability を呼ぶ

- [ ] **T-08-01-01**: 通知できる状態では ok=true の結果を返す (ENV-R-006)
  - Target: `evaluateAvailability`
  - Scenario: Given Fake AumidRegistry に AUMID `com.kallr.app` の登録があり DisplayName が `Kallr` である、Fake NotificationSettingSource が `enabled` を返す, When `evaluateAvailability('com.kallr.app', registry, settings)` を呼ぶ
  - Expected: Then `registered=true`、`displayNameSet=true`、`setting=enabled`、`ok=true`、`reason=null` の Availability を返す

#### T-08-02: Given 登録あり・DisplayName あり・通知設定が enabled 以外の既知の値, When evaluateAvailability を呼ぶ

- [ ] **T-08-02-01**: 通知設定が `disabledForApplication` のとき ok=false で理由に種別名を含める (ENV-R-004, ENV-E-04)
  - Target: `evaluateAvailability`
  - Scenario: Given Fake AumidRegistry に AUMID `com.kallr.app` の登録があり DisplayName が `Kallr` である、Fake NotificationSettingSource が `disabledForApplication` を返す, When `evaluateAvailability('com.kallr.app', registry, settings)` を呼ぶ
  - Expected: Then 例外を投げず、`registered=true`、`displayNameSet=true`、`setting=disabledForApplication`、`ok=false` を返し、`reason` に `disabledForApplication` を含める

- [ ] **T-08-02-02**: 通知設定が `disabledForUser` のとき ok=false で理由に種別名を含める (ENV-R-004, ENV-E-04)
  - Target: `evaluateAvailability`
  - Scenario: Given Fake AumidRegistry に AUMID `com.kallr.app` の登録があり DisplayName が `Kallr` である、Fake NotificationSettingSource が `disabledForUser` を返す, When `evaluateAvailability('com.kallr.app', registry, settings)` を呼ぶ
  - Expected: Then 例外を投げず、`registered=true`、`displayNameSet=true`、`setting=disabledForUser`、`ok=false` を返し、`reason` に `disabledForUser` を含める

- [ ] **T-08-02-03**: 通知設定が `disabledByGroupPolicy` のとき ok=false で理由に種別名を含める (ENV-R-004, ENV-E-04)
  - Target: `evaluateAvailability`
  - Scenario: Given Fake AumidRegistry に AUMID `com.kallr.app` の登録があり DisplayName が `Kallr` である、Fake NotificationSettingSource が `disabledByGroupPolicy` を返す, When `evaluateAvailability('com.kallr.app', registry, settings)` を呼ぶ
  - Expected: Then 例外を投げず、`registered=true`、`displayNameSet=true`、`setting=disabledByGroupPolicy`、`ok=false` を返し、`reason` に `disabledByGroupPolicy` を含める

- [ ] **T-08-02-04**: 通知設定が `disabledByManifest` のとき ok=false で理由に種別名を含める (ENV-R-004, ENV-E-04, ENV-E-05)
  - Target: `evaluateAvailability`
  - Scenario: Given Fake AumidRegistry に AUMID `com.kallr.app` の登録があり DisplayName が `Kallr` である、Fake NotificationSettingSource が `disabledByManifest` を返す, When `evaluateAvailability('com.kallr.app', registry, settings)` を呼ぶ
  - Expected: Then 例外を投げず、`registered=true`、`displayNameSet=true`、`setting=disabledByManifest`、`ok=false` を返し、`reason` に `disabledByManifest` を含める

#### T-08-03: Given Mock が 7 つの状態の 1 つで構築されている, When check を呼ぶ

- [ ] **T-08-03-01**: Mock の状態「OK (通知できる)」では、与えられた Availability をそのまま返す (ENV-R-013, ENV-E-15)
  - Target: `MockNotificationEnvironment.check`
  - Scenario: Given 状態「OK (通知できる)」の名前付きコンストラクタで構築した `MockNotificationEnvironment`, When `check('com.kallr.app')` を呼ぶ
  - Expected: Then ok=true の Availability (`registered=true`、`displayNameSet=true`、`setting=enabled`) を返す

- [ ] **T-08-03-02**: Mock の状態「未登録」では、与えられた Availability をそのまま返す (ENV-R-013, ENV-E-15)
  - Target: `MockNotificationEnvironment.check`
  - Scenario: Given 状態「未登録」の名前付きコンストラクタで構築した `MockNotificationEnvironment`, When `check('com.kallr.app')` を呼ぶ
  - Expected: Then `registered=false`、`ok=false`、`setting=null`、`reason=未登録` の Availability を返す

- [ ] **T-08-03-03**: Mock の状態「DisplayName 空」では、与えられた Availability をそのまま返す (ENV-R-013, ENV-E-15)
  - Target: `MockNotificationEnvironment.check`
  - Scenario: Given 状態「DisplayName 空」の名前付きコンストラクタで構築した `MockNotificationEnvironment`, When `check('com.kallr.app')` を呼ぶ
  - Expected: Then `registered=true`、`displayNameSet=false`、`ok=false`、`setting=null`、`reason=DisplayName が空` の Availability を返す

- [ ] **T-08-03-04**: Mock の状態「無効 (disabledForApplication)」では、与えられた Availability をそのまま返す (ENV-R-013, ENV-E-15)
  - Target: `MockNotificationEnvironment.check`
  - Scenario: Given 状態「無効 (disabledForApplication)」の名前付きコンストラクタで構築した `MockNotificationEnvironment`, When `check('com.kallr.app')` を呼ぶ
  - Expected: Then `setting=disabledForApplication`、`ok=false` の Availability を返す

- [ ] **T-08-03-05**: Mock の状態「無効 (disabledForUser)」では、与えられた Availability をそのまま返す (ENV-R-013, ENV-E-15)
  - Target: `MockNotificationEnvironment.check`
  - Scenario: Given 状態「無効 (disabledForUser)」の名前付きコンストラクタで構築した `MockNotificationEnvironment`, When `check('com.kallr.app')` を呼ぶ
  - Expected: Then `setting=disabledForUser`、`ok=false` の Availability を返す

- [ ] **T-08-03-06**: Mock の状態「無効 (disabledByGroupPolicy)」では、与えられた Availability をそのまま返す (ENV-R-013, ENV-E-15)
  - Target: `MockNotificationEnvironment.check`
  - Scenario: Given 状態「無効 (disabledByGroupPolicy)」の名前付きコンストラクタで構築した `MockNotificationEnvironment`, When `check('com.kallr.app')` を呼ぶ
  - Expected: Then `setting=disabledByGroupPolicy`、`ok=false` の Availability を返す

- [ ] **T-08-03-07**: Mock の状態「無効 (disabledByManifest)」では、与えられた Availability をそのまま返す (ENV-R-013, ENV-E-15)
  - Target: `MockNotificationEnvironment.check`
  - Scenario: Given 状態「無効 (disabledByManifest)」の名前付きコンストラクタで構築した `MockNotificationEnvironment`, When `check('com.kallr.app')` を呼ぶ
  - Expected: Then `setting=disabledByManifest`、`ok=false` の Availability を返す

#### T-08-04: Given Mock, When register / unregister を呼ぶ

- [ ] **T-08-04-01**: register は呼び出しを記録するだけで、レジストリと OS を呼ばない (ENV-R-013, AC-013)
  - Target: `MockNotificationEnvironment.register`
  - Scenario: Given `MockNotificationEnvironment` と、呼ばれると失敗する Fake AumidRegistry / NotificationSettingSource, When `register('com.kallr.app', 'Kallr')` を呼ぶ
  - Expected: Then 記録に (`com.kallr.app`, `Kallr`) が 1 件残り、Fake の AumidRegistry と NotificationSettingSource は 1 度も呼ばれず、例外を投げない

- [ ] **T-08-04-02**: unregister は呼び出しを記録するだけで、レジストリと OS を呼ばない (ENV-R-013, AC-013)
  - Target: `MockNotificationEnvironment.unregister`
  - Scenario: Given `MockNotificationEnvironment` と、呼ばれると失敗する Fake AumidRegistry / NotificationSettingSource, When `unregister('com.kallr.app')` を呼ぶ
  - Expected: Then 記録に `com.kallr.app` の削除が 1 件残り、Fake の AumidRegistry と NotificationSettingSource は 1 度も呼ばれず、例外を投げない

#### T-08-14: Given: aumid の前後に空白がある (契約。specifications-index 3.1)

- [ ] **T-08-14-01**: 前後の空白を削除した aumid で登録を調べる
  - Target: `evaluateAvailability`
  - Scenario: Given Fake AumidRegistry は `com.kallr.app` を登録済みとして持つ, When `evaluateAvailability(' com.kallr.app ', registry, settings)` を呼ぶ
  - Expected: Then `registry.exists` が `com.kallr.app` で呼ばれ、`registered=true` を返す

### [異常] Error Cases

#### T-08-05: Given AUMID が空, When evaluateAvailability を呼ぶ

- [ ] **T-08-05-01**: 空文字の AUMID は UsageException で拒否する (ENV-R-001, ENV-E-08)
  - Target: `evaluateAvailability`
  - Scenario: Given AUMID が空文字 `''`, When `evaluateAvailability('', registry, settings)` を呼ぶ
  - Expected: Then `UsageException` を投げ、Availability を返さない

- [ ] **T-08-05-02**: 空文字の AUMID では確認を始めない (ENV-R-001)
  - Target: `evaluateAvailability`
  - Scenario: Given AUMID が空文字 `''`、呼び出しを記録する Fake AumidRegistry と NotificationSettingSource, When `evaluateAvailability('', registry, settings)` を呼ぶ
  - Expected: Then `exists`、`readDisplayName`、`read` は 1 度も呼ばれない

- [ ] **T-08-05-03**: 空白だけの AUMID は UsageException で拒否する (ENV-R-001, ENV-E-08)
  - Target: `evaluateAvailability`
  - Scenario: Given AUMID が空白だけの `'   '`, When `evaluateAvailability('   ', registry, settings)` を呼ぶ
  - Expected: Then `UsageException` を投げ、Availability を返さない

#### T-08-06: Given AUMID の登録が無い, When evaluateAvailability を呼ぶ

- [ ] **T-08-06-01**: 未登録は例外ではなく値で返し、通知設定は未評価とする (ENV-R-002, ENV-DD-01, ENV-DD-10, ENV-E-01, ENV-E-25)
  - Target: `evaluateAvailability`
  - Scenario: Given Fake AumidRegistry が `com.kallr.app` を登録なしとして返す (`exists` が false), When `evaluateAvailability('com.kallr.app', registry, settings)` を呼ぶ
  - Expected: Then 例外を投げず、`registered=false`、`displayNameSet=false`、`setting=null`、`ok=false`、`reason=未登録` を返す

- [ ] **T-08-06-02**: 未登録のときは通知設定を読まずに打ち切る (ENV-DD-03)
  - Target: `evaluateAvailability`
  - Scenario: Given Fake AumidRegistry が `com.kallr.app` を登録なしとして返す (`exists` が false)、呼び出しを記録する Fake NotificationSettingSource, When `evaluateAvailability('com.kallr.app', registry, settings)` を呼ぶ
  - Expected: Then `settings.read` は 1 度も呼ばれない

#### T-08-07: Given 登録はあるが DisplayName が空, When evaluateAvailability を呼ぶ

- [ ] **T-08-07-01**: DisplayName の値が無い (null) とき、DisplayName が空として返す (ENV-R-003, ENV-E-02)
  - Target: `evaluateAvailability`
  - Scenario: Given 登録があり、Fake AumidRegistry の `readDisplayName` が `null` を返す, When `evaluateAvailability('com.kallr.app', registry, settings)` を呼ぶ
  - Expected: Then 例外を投げず、`registered=true`、`displayNameSet=false`、`setting=null`、`ok=false`、`reason=DisplayName が空` を返す

- [ ] **T-08-07-02**: DisplayName が空文字のとき、DisplayName が空として返す (ENV-R-003, ENV-E-03, ENV-E-25, ENV-DD-10)
  - Target: `evaluateAvailability`
  - Scenario: Given 登録があり、Fake AumidRegistry の `readDisplayName` が空文字 `''` を返す, When `evaluateAvailability('com.kallr.app', registry, settings)` を呼ぶ
  - Expected: Then 例外を投げず、`registered=true`、`displayNameSet=false`、`setting=null`、`ok=false`、`reason=DisplayName が空` を返す

- [ ] **T-08-07-03**: DisplayName が空白だけのとき、DisplayName が空として返す (ENV-R-003, ENV-E-03)
  - Target: `evaluateAvailability`
  - Scenario: Given 登録があり、Fake AumidRegistry の `readDisplayName` が空白だけの `'   '` を返す, When `evaluateAvailability('com.kallr.app', registry, settings)` を呼ぶ
  - Expected: Then 例外を投げず、`registered=true`、`displayNameSet=false`、`setting=null`、`ok=false`、`reason=DisplayName が空` を返す

- [ ] **T-08-07-04**: DisplayName が空のときは通知設定を読まずに打ち切る (ENV-DD-03)
  - Target: `evaluateAvailability`
  - Scenario: Given 登録があり `readDisplayName` が空文字 `''` を返す、呼び出しを記録する Fake NotificationSettingSource, When `evaluateAvailability('com.kallr.app', registry, settings)` を呼ぶ
  - Expected: Then `settings.read` は 1 度も呼ばれない

#### T-08-08: Given レジストリまたは OS の読み取りが失敗する, When evaluateAvailability を呼ぶ

- [ ] **T-08-08-01**: `exists` が失敗したとき、RegistryException を再スローし Win32 コードを保つ (ENV-R-007, ENV-E-07)
  - Target: `evaluateAvailability`
  - Scenario: Given Fake AumidRegistry の `exists` が `RegistryException(win32Code: 5)` (アクセス拒否) を投げる, When `evaluateAvailability('com.kallr.app', registry, settings)` を呼ぶ
  - Expected: Then `win32Code=5` の `RegistryException` が投げられ、「通知できない」の Availability に変換されない

- [ ] **T-08-08-02**: `readDisplayName` が失敗したとき、RegistryException を再スローする (ENV-R-007, ENV-E-07)
  - Target: `evaluateAvailability`
  - Scenario: Given 登録があり、Fake AumidRegistry の `readDisplayName` が `RegistryException(win32Code: 5)` を投げる, When `evaluateAvailability('com.kallr.app', registry, settings)` を呼ぶ
  - Expected: Then `win32Code=5` の `RegistryException` が投げられ、Availability を返さない

- [ ] **T-08-08-03**: `settings.read` が失敗したとき、RegistryException を再スローする (ENV-R-007, ENV-E-07)
  - Target: `evaluateAvailability`
  - Scenario: Given 登録あり・DisplayName ありで、Fake NotificationSettingSource の `read` が `RegistryException(win32Code: 5)` を投げる, When `evaluateAvailability('com.kallr.app', registry, settings)` を呼ぶ
  - Expected: Then `win32Code=5` の `RegistryException` が投げられ、`ok=false` の Availability に変換されない

- [ ] **T-08-08-04**: 通知設定が未知の値のとき、可否のどちらにも倒さず失敗とする (ENV-R-005, ENV-DD-06, ENV-E-06)
  - Target: `evaluateAvailability`
  - Scenario: Given 登録あり・DisplayName ありで、Fake NotificationSettingSource の `read` が未知の数値 `99` に対して `RegistryException` を投げる, When `evaluateAvailability('com.kallr.app', registry, settings)` を呼ぶ
  - Expected: Then `RegistryException` が投げられ、`ok=true` も `ok=false` の Availability も返らない

### [エッジケース] Edge Cases

#### T-08-09: Given 登録を削除した後も通知設定は enabled のまま, When evaluateAvailability を呼ぶ

- [ ] **T-08-09-01**: 設定が enabled でも、登録が無ければ「通知できない (未登録)」とする (ENV-E-11, ENV-R-002, ENV-DD-03)
  - Target: `evaluateAvailability`
  - Scenario: Given Fake AumidRegistry が `com.kallr.app` を登録なしとして返す (`exists` が false)、Fake NotificationSettingSource が `enabled` を返す設定になっている, When `evaluateAvailability('com.kallr.app', registry, settings)` を呼ぶ
  - Expected: Then `ok=false`、`reason=未登録`、`setting=null` を返し、`ok=true` にならない

#### T-08-10: Given 登録の直後に確認を実行する, When evaluateAvailability を呼ぶ

- [ ] **T-08-10-01**: 登録と設定が観測できれば ok=true とし、表示の遅延を観測しない (ENV-E-12)
  - Target: `evaluateAvailability`
  - Scenario: Given Fake AumidRegistry に AUMID `com.kallr.app` の登録があり DisplayName が `Kallr` である (登録の直後を模す)、呼び出しを記録し `enabled` を返す Fake NotificationSettingSource, When `evaluateAvailability('com.kallr.app', registry, settings)` を 1 回呼ぶ
  - Expected: Then `ok=true` を返し、`settings.read` の呼び出しは 1 回で、再試行や待機をしない

#### T-08-11: Given 確認が読み取り専用でなければならない, When evaluateAvailability を呼ぶ

- [ ] **T-08-11-01**: 通知できる状態の確認で、レジストリに書き込まない (ENV-R-012, ENV-DD-02)
  - Target: `evaluateAvailability`
  - Scenario: Given Fake AumidRegistry に AUMID `com.kallr.app` の登録があり DisplayName が `Kallr` である、`enabled` を返す Fake NotificationSettingSource、`write` と `delete` の呼び出しを記録する Fake AumidRegistry, When `evaluateAvailability('com.kallr.app', registry, settings)` を呼ぶ
  - Expected: Then `write` と `delete` は 1 度も呼ばれない

- [ ] **T-08-11-02**: 未登録の確認で、登録を作らず書き込まない (ENV-R-012, ENV-DD-02)
  - Target: `evaluateAvailability`
  - Scenario: Given Fake AumidRegistry が `com.kallr.app` を登録なしとして返す (`exists` が false)、`write` と `delete` の呼び出しを記録する Fake AumidRegistry, When `evaluateAvailability('com.kallr.app', registry, settings)` を呼ぶ
  - Expected: Then `write` と `delete` は 1 度も呼ばれない

#### T-08-12: Given AUMID または DisplayName に非 ASCII 文字を含む, When evaluateAvailability を呼ぶ

- [ ] **T-08-12-01**: 非 ASCII の AUMID を変えずに registry と settings へ渡す (ENV-E-14)
  - Target: `evaluateAvailability`
  - Scenario: Given AUMID が `かるる.通知`、その AUMID の登録と DisplayName `Kallr` を持つ Fake AumidRegistry、`enabled` を返す Fake NotificationSettingSource, When `evaluateAvailability('かるる.通知', registry, settings)` を呼ぶ
  - Expected: Then `exists`、`readDisplayName`、`read` が `かるる.通知` を変更なしで受け取り、`ok=true` を返す

- [ ] **T-08-12-02**: 非 ASCII の DisplayName を空と誤判定しない (ENV-E-14)
  - Target: `evaluateAvailability`
  - Scenario: Given 登録があり、Fake AumidRegistry の `readDisplayName` が `かるる通知` を返し、`enabled` を返す Fake NotificationSettingSource, When `evaluateAvailability('com.kallr.app', registry, settings)` を呼ぶ
  - Expected: Then `displayNameSet=true`、`ok=true` を返す

#### T-08-13: Given 評価順の境界, When evaluateAvailability を呼ぶ

- [ ] **T-08-13-01**: 登録が無いとき、DisplayName を読まずに打ち切る (ENV-R-002, ENV-DD-03)
  - Target: `evaluateAvailability`
  - Scenario: Given Fake AumidRegistry が `com.kallr.app` を登録なしとして返す (`exists` が false)、`readDisplayName` の呼び出しを記録する Fake AumidRegistry, When `evaluateAvailability('com.kallr.app', registry, settings)` を呼ぶ
  - Expected: Then `readDisplayName` は 1 度も呼ばれない

- [ ] **T-08-13-02**: DisplayName が空で設定も無効のとき、理由は DisplayName が空を優先する (ENV-R-003 が ENV-R-004 より先。ENV-DD-10)
  - Target: `evaluateAvailability`
  - Scenario: Given 登録があり `readDisplayName` が空文字 `''`、Fake NotificationSettingSource が `disabledForUser` を返す, When `evaluateAvailability('com.kallr.app', registry, settings)` を呼ぶ
  - Expected: Then `reason=DisplayName が空`、`setting=null` を返し、無効の種別を理由に含めない

---

## T-09: w5Check (W5C)

### [正常] Normal Cases

#### T-09-01: Given 3 欄が明確で記録が実態と一致 (user), When w5Check を呼ぶ

- [ ] **T-09-01-01**: AUMID 欄は登録があれば match とする (ENV-R-015, ENV-R-011)
  - Target: `w5Check`
  - Scenario: Given W5Input(recordedAumid=`'com.kallr.app'`, recordedPermission=`'user'`, recordedInstallMethod=`'unpackaged'`)、`MockNotificationEnvironment` (`isRegistered('com.kallr.app')` が true)、Fake PermissionProbe の `current()` が `user` を返す, When `w5Check(input, env, probe)` を呼ぶ
  - Expected: Then `field=aumid` の結果が `status=match`

- [ ] **T-09-01-02**: 実行権限欄は記録と観測が同じなら match とする (ENV-R-015)
  - Target: `w5Check`
  - Scenario: Given W5Input(recordedAumid=`'com.kallr.app'`, recordedPermission=`'user'`, recordedInstallMethod=`'unpackaged'`)、`MockNotificationEnvironment` (`isRegistered('com.kallr.app')` が true)、Fake PermissionProbe の `current()` が `user` を返す, When `w5Check(input, env, probe)` を呼ぶ
  - Expected: Then `field=permission` の結果が `status=match`

- [ ] **T-09-01-03**: インストール方式欄は照合せず notChecked とし、記録した値を表示する (ENV-DD-04, ENV-R-015, ENV-E-19)
  - Target: `w5Check`
  - Scenario: Given W5Input(recordedAumid=`'com.kallr.app'`, recordedPermission=`'user'`, recordedInstallMethod=`'unpackaged'`)、`MockNotificationEnvironment` (`isRegistered('com.kallr.app')` が true)、Fake PermissionProbe の `current()` が `user` を返す, When `w5Check(input, env, probe)` を呼ぶ
  - Expected: Then `field=install-method` の結果が `status=notChecked`、`recorded=unpackaged`、`observed=null`

- [ ] **T-09-01-04**: 全欄が match / notChecked のとき exitCode は 0 (ENV-R-019)
  - Target: `w5Check`
  - Scenario: Given W5Input(recordedAumid=`'com.kallr.app'`, recordedPermission=`'user'`, recordedInstallMethod=`'unpackaged'`)、`MockNotificationEnvironment` (`isRegistered('com.kallr.app')` が true)、Fake PermissionProbe の `current()` が `user` を返す, When `w5Check(input, env, probe)` を呼ぶ
  - Expected: Then `exitCode` が 0

- [ ] **T-09-01-05**: 結果は aumid、permission、install-method の 3 欄を、この順で返す (ENV-R-019)
  - Target: `w5Check`
  - Scenario: Given W5Input(recordedAumid=`'com.kallr.app'`, recordedPermission=`'user'`, recordedInstallMethod=`'unpackaged'`)、`MockNotificationEnvironment` (`isRegistered('com.kallr.app')` が true)、Fake PermissionProbe の `current()` が `user` を返す, When `w5Check(input, env, probe)` を呼ぶ
  - Expected: Then `fields` が 3 件で、`field` が順に `aumid`、`permission`、`install-method`

#### T-09-02: Given 実行権限が administrator で記録と一致, When w5Check を呼ぶ

- [ ] **T-09-02-01**: administrator の記録と観測が同じなら permission は match とする (ENV-DD-12)
  - Target: `w5Check`
  - Scenario: Given W5Input(recordedAumid=`'com.kallr.app'`, recordedPermission=`'administrator'`, recordedInstallMethod=`'unpackaged'`)、`MockNotificationEnvironment` (`isRegistered('com.kallr.app')` が true)、Fake PermissionProbe の `current()` が `administrator` を返す, When `w5Check(input, env, probe)` を呼ぶ
  - Expected: Then `field=permission` の結果が `status=match`

- [ ] **T-09-02-02**: administrator で全欄が一致するとき exitCode は 0 (ENV-R-019)
  - Target: `w5Check`
  - Scenario: Given W5Input(recordedAumid=`'com.kallr.app'`, recordedPermission=`'administrator'`, recordedInstallMethod=`'unpackaged'`)、`MockNotificationEnvironment` (`isRegistered('com.kallr.app')` が true)、Fake PermissionProbe の `current()` が `administrator` を返す, When `w5Check(input, env, probe)` を呼ぶ
  - Expected: Then `exitCode` が 0

#### T-09-14: Given: 記録した aumid の前後に空白がある (契約。specifications-index 3.1)

- [ ] **T-09-14-01**: 前後の空白を削除した記録の aumid で登録を照合する
  - Target: `w5Check`
  - Scenario: Given `recordedAumid` が `" com.kallr.app "`、`env.isRegistered('com.kallr.app')` は真, When `w5Check` を呼ぶ
  - Expected: Then `env.isRegistered` が `com.kallr.app` で呼ばれ、aumid 欄が `match` である

### [異常] Error Cases

#### T-09-03: Given 記録した AUMID が HKCU に登録されていない, When w5Check を呼ぶ

- [ ] **T-09-03-01**: AUMID が未登録なら mismatch とし、記録した値と観測した値を報告する (ENV-R-015, ENV-R-016, ENV-E-17)
  - Target: `w5Check`
  - Scenario: Given W5Input(recordedAumid=`'com.kallr.app'`, recordedPermission=`'user'`, recordedInstallMethod=`'unpackaged'`)、`isRegistered('com.kallr.app')` が false を返す Mock、`current()` が `user` を返す Fake PermissionProbe, When `w5Check(input, env, probe)` を呼ぶ
  - Expected: Then `field=aumid` が `status=mismatch`、`recorded=com.kallr.app`、`observed=登録なし`

- [ ] **T-09-03-02**: AUMID の不一致があれば exitCode は 2 (ENV-R-019, ENV-DD-05, ENV-E-17)
  - Target: `w5Check`
  - Scenario: Given W5Input(recordedAumid=`'com.kallr.app'`, recordedPermission=`'user'`, recordedInstallMethod=`'unpackaged'`)、`isRegistered('com.kallr.app')` が false を返す Mock、`current()` が `user` を返す Fake PermissionProbe, When `w5Check(input, env, probe)` を呼ぶ
  - Expected: Then `exitCode` が 2

- [ ] **T-09-03-03**: AUMID の不一致があっても記録の完備は変わらず、unclear の欄が 0 件 (ENV-E-28, ENV-DD-04)
  - Target: `w5Check`
  - Scenario: Given W5Input(recordedAumid=`'com.kallr.app'`, recordedPermission=`'user'`, recordedInstallMethod=`'unpackaged'`)、`isRegistered('com.kallr.app')` が false を返す Mock、`current()` が `user` を返す Fake PermissionProbe, When `w5Check(input, env, probe)` を呼ぶ
  - Expected: Then どの欄も `status=unclear` でなく、`permission` は `match`、`install-method` は `notChecked` のまま

#### T-09-04: Given 記録した実行権限が観測した権限と異なる, When w5Check を呼ぶ

- [ ] **T-09-04-01**: 記録 administrator・観測 user のとき mismatch とし、両方の値を報告する (ENV-R-015, ENV-R-016, ENV-E-18)
  - Target: `w5Check`
  - Scenario: Given W5Input(recordedAumid=`'com.kallr.app'`, recordedPermission=`'administrator'`, recordedInstallMethod=`'unpackaged'`)、`MockNotificationEnvironment` (`isRegistered('com.kallr.app')` が true)、Fake PermissionProbe の `current()` が `user` を返す, When `w5Check(input, env, probe)` を呼ぶ
  - Expected: Then `field=permission` が `status=mismatch`、`recorded=administrator`、`observed=user`

- [ ] **T-09-04-02**: 実行権限の不一致があれば exitCode は 2 (ENV-R-019, ENV-E-18)
  - Target: `w5Check`
  - Scenario: Given W5Input(recordedAumid=`'com.kallr.app'`, recordedPermission=`'administrator'`, recordedInstallMethod=`'unpackaged'`)、`MockNotificationEnvironment` (`isRegistered('com.kallr.app')` が true)、Fake PermissionProbe の `current()` が `user` を返す, When `w5Check(input, env, probe)` を呼ぶ
  - Expected: Then `exitCode` が 2

- [ ] **T-09-04-03**: 記録 user・観測 administrator のとき mismatch とし、両方の値を報告する (ENV-R-015, ENV-R-016, ENV-E-18)
  - Target: `w5Check`
  - Scenario: Given W5Input(recordedAumid=`'com.kallr.app'`, recordedPermission=`'user'`, recordedInstallMethod=`'unpackaged'`)、`MockNotificationEnvironment` (`isRegistered('com.kallr.app')` が true)、Fake PermissionProbe の `current()` が `administrator` を返す, When `w5Check(input, env, probe)` を呼ぶ
  - Expected: Then `field=permission` が `status=mismatch`、`recorded=user`、`observed=administrator`

#### T-09-05: Given AUMID 欄が未明確, When w5Check を呼ぶ

- [ ] **T-09-05-01**: AUMID 欄が指定なし (null) のとき unclear とする (ENV-R-019, ENV-DD-13, ENV-E-27)
  - Target: `w5Check`
  - Scenario: Given W5Input(recordedAumid=`null` (指定なし), recordedPermission=`'user'`, recordedInstallMethod=`'unpackaged'`)、`MockNotificationEnvironment` (`isRegistered('com.kallr.app')` が true)、Fake PermissionProbe の `current()` が `user` を返す, When `w5Check(input, env, probe)` を呼ぶ
  - Expected: Then `field=aumid` が `status=unclear`

- [ ] **T-09-05-02**: AUMID 欄が空文字のとき unclear とする (ENV-R-019, ENV-DD-13, ENV-E-16)
  - Target: `w5Check`
  - Scenario: Given W5Input(recordedAumid=`''`, recordedPermission=`'user'`, recordedInstallMethod=`'unpackaged'`)、`MockNotificationEnvironment` (`isRegistered('com.kallr.app')` が true)、Fake PermissionProbe の `current()` が `user` を返す, When `w5Check(input, env, probe)` を呼ぶ
  - Expected: Then `field=aumid` が `status=unclear`

- [ ] **T-09-05-03**: AUMID 欄が空白だけのとき unclear とする (ENV-R-019, ENV-DD-13, ENV-E-16)
  - Target: `w5Check`
  - Scenario: Given W5Input(recordedAumid=`'   '`, recordedPermission=`'user'`, recordedInstallMethod=`'unpackaged'`)、`MockNotificationEnvironment` (`isRegistered('com.kallr.app')` が true)、Fake PermissionProbe の `current()` が `user` を返す, When `w5Check(input, env, probe)` を呼ぶ
  - Expected: Then `field=aumid` が `status=unclear`

- [ ] **T-09-05-04**: AUMID 欄の値が `記載なし` のとき unclear とする (ENV-R-019, ENV-DD-13, ENV-E-16, ENV-E-29)
  - Target: `w5Check`
  - Scenario: Given W5Input(recordedAumid=`'記載なし'`, recordedPermission=`'user'`, recordedInstallMethod=`'unpackaged'`)、`MockNotificationEnvironment` (`isRegistered('com.kallr.app')` が true)、Fake PermissionProbe の `current()` が `user` を返す, When `w5Check(input, env, probe)` を呼ぶ
  - Expected: Then `field=aumid` が `status=unclear`

- [ ] **T-09-05-05**: AUMID 欄が未明確のとき、登録の照合をしない (ENV-R-015)
  - Target: `w5Check`
  - Scenario: Given W5Input(recordedAumid=`null` (指定なし), recordedPermission=`'user'`, recordedInstallMethod=`'unpackaged'`)、`isRegistered` の呼び出しを記録する Mock、`current()` が `user` を返す Fake PermissionProbe, When `w5Check(input, env, probe)` を呼ぶ
  - Expected: Then `env.isRegistered` は 1 度も呼ばれない

- [ ] **T-09-05-06**: AUMID 欄が `記載なし` のとき exitCode は 2 (ENV-R-019, ENV-E-29)
  - Target: `w5Check`
  - Scenario: Given W5Input(recordedAumid=`'記載なし'`, recordedPermission=`'user'`, recordedInstallMethod=`'unpackaged'`)、`MockNotificationEnvironment` (`isRegistered('com.kallr.app')` が true)、Fake PermissionProbe の `current()` が `user` を返す, When `w5Check(input, env, probe)` を呼ぶ
  - Expected: Then `exitCode` が 2

#### T-09-06: Given 実行権限欄が未明確, When w5Check を呼ぶ

- [ ] **T-09-06-01**: 実行権限欄が指定なし (null) のとき unclear とする (ENV-R-019, ENV-DD-13, ENV-E-27)
  - Target: `w5Check`
  - Scenario: Given W5Input(recordedAumid=`'com.kallr.app'`, recordedPermission=`null` (指定なし), recordedInstallMethod=`'unpackaged'`)、`MockNotificationEnvironment` (`isRegistered('com.kallr.app')` が true)、Fake PermissionProbe の `current()` が `user` を返す, When `w5Check(input, env, probe)` を呼ぶ
  - Expected: Then `field=permission` が `status=unclear`

- [ ] **T-09-06-02**: 実行権限欄が空文字のとき unclear とする (ENV-R-019, ENV-DD-13, ENV-E-16)
  - Target: `w5Check`
  - Scenario: Given W5Input(recordedAumid=`'com.kallr.app'`, recordedPermission=`''`, recordedInstallMethod=`'unpackaged'`)、`MockNotificationEnvironment` (`isRegistered('com.kallr.app')` が true)、Fake PermissionProbe の `current()` が `user` を返す, When `w5Check(input, env, probe)` を呼ぶ
  - Expected: Then `field=permission` が `status=unclear`

- [ ] **T-09-06-03**: 実行権限欄が空白だけのとき unclear とする (ENV-R-019, ENV-DD-13, ENV-E-16)
  - Target: `w5Check`
  - Scenario: Given W5Input(recordedAumid=`'com.kallr.app'`, recordedPermission=`'   '`, recordedInstallMethod=`'unpackaged'`)、`MockNotificationEnvironment` (`isRegistered('com.kallr.app')` が true)、Fake PermissionProbe の `current()` が `user` を返す, When `w5Check(input, env, probe)` を呼ぶ
  - Expected: Then `field=permission` が `status=unclear`

- [ ] **T-09-06-04**: 実行権限欄の値が `記載なし` のとき unclear とする (ENV-R-019, ENV-DD-13, ENV-E-16, ENV-E-29)
  - Target: `w5Check`
  - Scenario: Given W5Input(recordedAumid=`'com.kallr.app'`, recordedPermission=`'記載なし'`, recordedInstallMethod=`'unpackaged'`)、`MockNotificationEnvironment` (`isRegistered('com.kallr.app')` が true)、Fake PermissionProbe の `current()` が `user` を返す, When `w5Check(input, env, probe)` を呼ぶ
  - Expected: Then `field=permission` が `status=unclear`

- [ ] **T-09-06-05**: 実行権限欄が未明確のとき、観測した権限と比べない (ENV-R-015)
  - Target: `w5Check`
  - Scenario: Given W5Input(recordedAumid=`'com.kallr.app'`, recordedPermission=`null` (指定なし), recordedInstallMethod=`'unpackaged'`)、`MockNotificationEnvironment` (`isRegistered('com.kallr.app')` が true)、`current()` の呼び出しを記録する Fake PermissionProbe, When `w5Check(input, env, probe)` を呼ぶ
  - Expected: Then `probe.current` は 1 度も呼ばれず、`field=permission` の `observed` は `null`

- [ ] **T-09-06-06**: 実行権限欄が指定なしのとき exitCode は 2 (ENV-R-019, ENV-E-27)
  - Target: `w5Check`
  - Scenario: Given W5Input(recordedAumid=`'com.kallr.app'`, recordedPermission=`null` (指定なし), recordedInstallMethod=`'unpackaged'`)、`MockNotificationEnvironment` (`isRegistered('com.kallr.app')` が true)、Fake PermissionProbe の `current()` が `user` を返す, When `w5Check(input, env, probe)` を呼ぶ
  - Expected: Then `exitCode` が 2

#### T-09-07: Given インストール方式欄が未明確, When w5Check を呼ぶ

- [ ] **T-09-07-01**: インストール方式欄が指定なし (null) のとき unclear とする (ENV-R-019, ENV-DD-13, ENV-E-27)
  - Target: `w5Check`
  - Scenario: Given W5Input(recordedAumid=`'com.kallr.app'`, recordedPermission=`'user'`, recordedInstallMethod=`null` (指定なし))、`MockNotificationEnvironment` (`isRegistered('com.kallr.app')` が true)、Fake PermissionProbe の `current()` が `user` を返す, When `w5Check(input, env, probe)` を呼ぶ
  - Expected: Then `field=install-method` が `status=unclear`

- [ ] **T-09-07-02**: インストール方式欄が空文字のとき unclear とする (ENV-R-019, ENV-DD-13, ENV-E-16)
  - Target: `w5Check`
  - Scenario: Given W5Input(recordedAumid=`'com.kallr.app'`, recordedPermission=`'user'`, recordedInstallMethod=`''`)、`MockNotificationEnvironment` (`isRegistered('com.kallr.app')` が true)、Fake PermissionProbe の `current()` が `user` を返す, When `w5Check(input, env, probe)` を呼ぶ
  - Expected: Then `field=install-method` が `status=unclear`

- [ ] **T-09-07-03**: インストール方式欄が空白だけのとき unclear とする (ENV-R-019, ENV-DD-13, ENV-E-16)
  - Target: `w5Check`
  - Scenario: Given W5Input(recordedAumid=`'com.kallr.app'`, recordedPermission=`'user'`, recordedInstallMethod=`'   '`)、`MockNotificationEnvironment` (`isRegistered('com.kallr.app')` が true)、Fake PermissionProbe の `current()` が `user` を返す, When `w5Check(input, env, probe)` を呼ぶ
  - Expected: Then `field=install-method` が `status=unclear`

- [ ] **T-09-07-04**: インストール方式欄の値が `記載なし` のとき unclear とする (ENV-R-019, ENV-DD-13, ENV-E-16, ENV-E-29)
  - Target: `w5Check`
  - Scenario: Given W5Input(recordedAumid=`'com.kallr.app'`, recordedPermission=`'user'`, recordedInstallMethod=`'記載なし'`)、`MockNotificationEnvironment` (`isRegistered('com.kallr.app')` が true)、Fake PermissionProbe の `current()` が `user` を返す, When `w5Check(input, env, probe)` を呼ぶ
  - Expected: Then `field=install-method` が `status=unclear`

- [ ] **T-09-07-05**: インストール方式欄が指定なしのとき exitCode は 2 (ENV-R-019, ENV-E-27)
  - Target: `w5Check`
  - Scenario: Given W5Input(recordedAumid=`'com.kallr.app'`, recordedPermission=`'user'`, recordedInstallMethod=`null` (指定なし))、`MockNotificationEnvironment` (`isRegistered('com.kallr.app')` が true)、Fake PermissionProbe の `current()` が `user` を返す, When `w5Check(input, env, probe)` を呼ぶ
  - Expected: Then `exitCode` が 2

#### T-09-08: Given 実行権限の値が `user` / `administrator` 以外, When w5Check を呼ぶ

- [ ] **T-09-08-01**: 権限の値が `root` のとき UsageException で拒否する (ENV-DD-12)
  - Target: `w5Check`
  - Scenario: Given W5Input(recordedAumid=`'com.kallr.app'`, recordedPermission=`'root'`, recordedInstallMethod=`'unpackaged'`)、`MockNotificationEnvironment` (`isRegistered('com.kallr.app')` が true)、`current()` が `user` を返す Fake PermissionProbe, When `w5Check(input, env, probe)` を呼ぶ
  - Expected: Then `UsageException` を投げ、W5Report を返さない

### [エッジケース] Edge Cases

#### T-09-09: Given インストール方式欄に任意の値を記録した, When w5Check を呼ぶ

- [ ] **T-09-09-01**: インストール方式の値の良し悪しは問わず、mismatch にしない (ENV-R-014, ENV-E-19)
  - Target: `w5Check`
  - Scenario: Given W5Input(recordedAumid=`'com.kallr.app'`, recordedPermission=`'user'`, recordedInstallMethod=`'msix'`)、AUMID と権限が一致する Mock と Fake PermissionProbe, When `w5Check(input, env, probe)` を呼ぶ
  - Expected: Then `field=install-method` が `status=notChecked`、`recorded=msix`、`mismatch` でなく、`exitCode` が 0

#### T-09-10: Given 不一致と未明確が別の欄に同時にある, When w5Check を呼ぶ

- [ ] **T-09-10-01**: AUMID の mismatch が、他の欄の判定に影響されない (ENV-R-015)
  - Target: `w5Check`
  - Scenario: Given W5Input(recordedAumid=`'com.kallr.app'`, recordedPermission=`null` (指定なし), recordedInstallMethod=`'unpackaged'`)、`isRegistered` が false の Mock, When `w5Check(input, env, probe)` を呼ぶ
  - Expected: Then `field=aumid` が `status=mismatch`

- [ ] **T-09-10-02**: 実行権限の unclear が、他の欄の不一致で上書きされず exitCode は 2 (ENV-R-019)
  - Target: `w5Check`
  - Scenario: Given W5Input(recordedAumid=`'com.kallr.app'`, recordedPermission=`null` (指定なし), recordedInstallMethod=`'unpackaged'`)、`isRegistered` が false の Mock, When `w5Check(input, env, probe)` を呼ぶ
  - Expected: Then `field=permission` が `status=unclear`、`exitCode` が 2

#### T-09-11: Given 3 欄すべてが指定なし, When w5Check を呼ぶ

- [ ] **T-09-11-01**: 3 欄すべてが unclear で exitCode は 2 (ENV-R-019, ENV-E-27)
  - Target: `w5Check`
  - Scenario: Given W5Input(recordedAumid=`null` (指定なし), recordedPermission=`null` (指定なし), recordedInstallMethod=`null` (指定なし)), When `w5Check(input, env, probe)` を呼ぶ
  - Expected: Then 3 欄すべてが `status=unclear` で、`exitCode` が 2

- [ ] **T-09-11-02**: 3 欄すべてが未明確のとき、登録と権限を照合しない (ENV-R-015)
  - Target: `w5Check`
  - Scenario: Given W5Input(recordedAumid=`null` (指定なし), recordedPermission=`null` (指定なし), recordedInstallMethod=`null` (指定なし))、呼び出しを記録する Mock と Fake PermissionProbe, When `w5Check(input, env, probe)` を呼ぶ
  - Expected: Then `env.isRegistered` と `probe.current` は 1 度も呼ばれない

#### T-09-12: Given 整合チェックが読み取り専用でなければならない, When w5Check を呼ぶ

- [ ] **T-09-12-01**: 記録した AUMID で isRegistered を 1 回だけ呼ぶ (ENV-R-011, ENV-R-015)
  - Target: `w5Check`
  - Scenario: Given W5Input(recordedAumid=`'com.kallr.app'`, recordedPermission=`'user'`, recordedInstallMethod=`'unpackaged'`)、呼び出しを記録する Mock (`isRegistered` が true)、`user` を返す Fake PermissionProbe, When `w5Check(input, env, probe)` を呼ぶ
  - Expected: Then `env.isRegistered` が `com.kallr.app` で 1 回だけ呼ばれる

- [ ] **T-09-12-02**: register と unregister を呼ばず、書き込まない (ENV-R-012, ENV-DD-02)
  - Target: `w5Check`
  - Scenario: Given W5Input(recordedAumid=`'com.kallr.app'`, recordedPermission=`'user'`, recordedInstallMethod=`'unpackaged'`)、呼び出しを記録する Mock、`user` を返す Fake PermissionProbe, When `w5Check(input, env, probe)` を呼ぶ
  - Expected: Then `env.register` と `env.unregister` は 1 度も呼ばれない

#### T-09-13: Given 実行権限の値が大文字を含む, When w5Check を呼ぶ

- [ ] **T-09-13-01**: 権限の値 `Administrator` (大文字始まり) は UsageException で拒否する (ENV-DD-12。値は小文字の `user` / `administrator` のみ)
  - Target: `w5Check`
  - Scenario: Given W5Input(recordedAumid=`'com.kallr.app'`, recordedPermission=`'Administrator'`, recordedInstallMethod=`'unpackaged'`)、`MockNotificationEnvironment` (`isRegistered('com.kallr.app')` が true)、`current()` が `administrator` を返す Fake PermissionProbe, When `w5Check(input, env, probe)` を呼ぶ
  - Expected: Then `UsageException` を投げ、W5Report を返さない

## T-13: DefaultNotificationEnvironment (NEV)

> 共通の前提: `DefaultNotificationEnvironment` に、呼び出しを記録する Fake `AumidRegistry` と Fake `NotificationSettingSource` を渡す。
> Fake の `AumidRegistry` は `app.x` を登録済みとして持つ。Fake は渡された aumid をそのまま記録する。

### [正常] Normal Cases

#### T-13-01: register の aumid の前後に空白がある

- [ ] **T-13-01-01**: 前後の空白を削除した aumid で書き込む
  - Target: `DefaultNotificationEnvironment.register`
  - Scenario: Given aumid が `" app.x "`、表示名が `名前`, When `register` を呼ぶ
  - Expected: Then `registry.write` が aumid `app.x` で呼ばれる

#### T-13-02: unregister の aumid の前後に空白がある

- [ ] **T-13-02-01**: 前後の空白を削除した aumid で削除する
  - Target: `DefaultNotificationEnvironment.unregister`
  - Scenario: Given aumid が `" app.x "`, When `unregister` を呼ぶ
  - Expected: Then `registry.delete` が aumid `app.x` で呼ばれる

#### T-13-03: isRegistered の aumid の前後に空白がある

- [ ] **T-13-03-01**: 前後の空白を削除した aumid で調べて真を返す
  - Target: `DefaultNotificationEnvironment.isRegistered`
  - Scenario: Given aumid が `" app.x "`, When `isRegistered` を呼ぶ
  - Expected: Then `registry.exists` が aumid `app.x` で呼ばれ、`true` を返す

#### T-13-04: check の aumid の前後に空白がある

- [ ] **T-13-04-01**: 前後の空白を削除した aumid で確認する
  - Target: `DefaultNotificationEnvironment.check`
  - Scenario: Given aumid が `" app.x "`, When `check` を呼ぶ
  - Expected: Then `registry.exists` が aumid `app.x` で呼ばれる

### [異常] Error Cases

#### T-13-05: register の aumid が空白だけ

- [ ] **T-13-05-01**: `UsageException` を投げる
  - Target: `DefaultNotificationEnvironment.register`
  - Scenario: Given aumid が `"   "`、表示名が `名前`, When `register` を呼ぶ
  - Expected: Then `UsageException` を投げる

- [ ] **T-13-05-02**: 下層を呼ばない
  - Target: `DefaultNotificationEnvironment.register`
  - Scenario: Given aumid が `"   "`、表示名が `名前`, When `register` を呼ぶ
  - Expected: Then `registry.write` が 1 度も呼ばれない

#### T-13-06: register の aumid が空文字

- [ ] **T-13-06-01**: `UsageException` を投げる
  - Target: `DefaultNotificationEnvironment.register`
  - Scenario: Given aumid が `""`、表示名が `名前`, When `register` を呼ぶ
  - Expected: Then `UsageException` を投げる

#### T-13-07: unregister の aumid が空白だけ

- [ ] **T-13-07-01**: `UsageException` を投げる
  - Target: `DefaultNotificationEnvironment.unregister`
  - Scenario: Given aumid が `"   "`, When `unregister` を呼ぶ
  - Expected: Then `UsageException` を投げる

- [ ] **T-13-07-02**: 下層を呼ばない
  - Target: `DefaultNotificationEnvironment.unregister`
  - Scenario: Given aumid が `"   "`, When `unregister` を呼ぶ
  - Expected: Then `registry.delete` が 1 度も呼ばれない

#### T-13-08: isRegistered の aumid が空白だけ

- [ ] **T-13-08-01**: `UsageException` を投げる
  - Target: `DefaultNotificationEnvironment.isRegistered`
  - Scenario: Given aumid が `"   "`, When `isRegistered` を呼ぶ
  - Expected: Then `UsageException` を投げ、`registry.exists` が 1 度も呼ばれない

#### T-13-09: check の aumid が空白だけ

- [ ] **T-13-09-01**: `UsageException` を投げる
  - Target: `DefaultNotificationEnvironment.check`
  - Scenario: Given aumid が `"   "`, When `check` を呼ぶ
  - Expected: Then `UsageException` を投げる

- [ ] **T-13-09-02**: 下層を呼ばない
  - Target: `DefaultNotificationEnvironment.check`
  - Scenario: Given aumid が `"   "`, When `check` を呼ぶ
  - Expected: Then `registry` と `settings` は、どちらも呼ばれない

### [エッジケース] Edge Cases

#### T-13-10: aumid の内側に空白がある

- [ ] **T-13-10-01**: 内側の空白は変えずに書き込む
  - Target: `DefaultNotificationEnvironment.register`
  - Scenario: Given aumid が `" app x "`、表示名が `名前`, When `register` を呼ぶ
  - Expected: Then `registry.write` が aumid `app x` で呼ばれる

---

## Coverage Check

| Source item                                                          | Task ID(s)                                                                                                                         |
| -------------------------------------------------------------------- | ---------------------------------------------------------------------------------------------------------------------------------- |
| ENV-R-001 (AUMID 空 → UsageException)                                | T-08-05-01, T-08-05-02, T-08-05-03                                                                                                 |
| ENV-R-002 (未登録)                                                   | T-08-06-01, T-08-06-02, T-08-09-01, T-08-13-01                                                                                     |
| ENV-R-003 (DisplayName 空)                                           | T-08-07-01, T-08-07-02, T-08-07-03, T-08-07-04, T-08-13-02                                                                         |
| ENV-R-004 (無効 4 種)                                                | T-08-02-01 〜 T-08-02-04                                                                                                           |
| ENV-R-005 (未知の値 → 失敗)                                          | T-08-08-04                                                                                                                         |
| ENV-R-006 (ok=true)                                                  | T-08-01-01, T-08-10-01                                                                                                             |
| ENV-R-007 (読み取り失敗 → 再スロー)                                  | T-08-08-01, T-08-08-02, T-08-08-03                                                                                                 |
| ENV-R-011 (登録の確認。w5Check からの利用)                           | T-09-01-01, T-09-12-01                                                                                                             |
| ENV-R-012 (読み取り専用)                                             | T-08-11-01, T-08-11-02, T-09-12-02                                                                                                 |
| ENV-R-013 (Mock は OS を呼ばない)                                    | T-08-03-01 〜 T-08-03-07, T-08-04-01, T-08-04-02                                                                                   |
| ENV-R-014 (3 欄の完備判定)                                           | T-09-05-01 〜 T-09-07-05, T-09-09-01                                                                                               |
| ENV-R-015 (欄ごとの整合チェック)                                     | T-09-01-01, T-09-01-02, T-09-01-03, T-09-02-01, T-09-03-01, T-09-04-01, T-09-05-05, T-09-06-05, T-09-10-01, T-09-11-02, T-09-12-01 |
| ENV-R-016 (不一致の報告)                                             | T-09-03-01, T-09-04-01, T-09-04-03                                                                                                 |
| ENV-R-019 (w5Check の判定。exitCode と 3 欄の結果)                   | T-09-01-04, T-09-01-05, T-09-02-02, T-09-03-02, T-09-05-01〜06, T-09-06-01〜06, T-09-07-01〜05, T-09-10-02, T-09-11-01             |
| 識別子の正規化 (specifications-index 3.1。implementation-index §3.3) | T-13-01-01〜T-13-10-01                                                                                                             |
| ENV-E-01 (未登録で add) の確認部分                                   | T-08-06-01 (add の終了コード 3 は対象外。下表)                                                                                     |
| ENV-E-02 (DisplayName の値なし)                                      | T-08-07-01                                                                                                                         |
| ENV-E-03 (DisplayName 空文字・空白)                                  | T-08-07-02, T-08-07-03                                                                                                             |
| ENV-E-04 (無効 4 種)                                                 | T-08-02-01 〜 T-08-02-04                                                                                                           |
| ENV-E-05 (マニフェスト無効)                                          | T-08-02-04                                                                                                                         |
| ENV-E-06 (未知の値)                                                  | T-08-08-04                                                                                                                         |
| ENV-E-07 (読み取り失敗)                                              | T-08-08-01, T-08-08-02, T-08-08-03                                                                                                 |
| ENV-E-08 (AUMID 空)                                                  | T-08-05-01, T-08-05-03                                                                                                             |
| ENV-E-11 (削除後も設定が有効)                                        | T-08-09-01                                                                                                                         |
| ENV-E-12 (登録の直後)                                                | T-08-10-01                                                                                                                         |
| ENV-E-14 (非 ASCII) の判定ロジック部分                               | T-08-12-01, T-08-12-02                                                                                                             |
| ENV-E-15 (Mock の戻り値に従う) の Mock 部分                          | T-08-03-01 〜 T-08-03-07                                                                                                           |
| ENV-E-16 (W5 の記録が空・記載なし)                                   | T-09-05-02, T-09-05-03, T-09-05-04, T-09-06-02, T-09-06-03, T-09-06-04, T-09-07-02, T-09-07-03, T-09-07-04                         |
| ENV-E-17 (AUMID 欄が未登録)                                          | T-09-03-01, T-09-03-02                                                                                                             |
| ENV-E-18 (権限の不一致)                                              | T-09-04-01, T-09-04-02, T-09-04-03                                                                                                 |
| ENV-E-19 (インストール方式は対象外)                                  | T-09-01-03, T-09-09-01                                                                                                             |
| ENV-E-25 (未評価の通知設定)                                          | T-08-06-01, T-08-07-02                                                                                                             |
| ENV-E-27 (指定の無い `--recorded-*`)                                 | T-09-05-01, T-09-06-01, T-09-06-06, T-09-07-01, T-09-07-05, T-09-11-01                                                             |
| ENV-E-28 (完備だが不一致)                                            | T-09-03-03                                                                                                                         |
| ENV-E-29 (`記載なし`)                                                | T-09-05-04, T-09-05-06, T-09-06-04, T-09-07-04                                                                                     |
| ENV-DD-01 (不可は値、失敗は例外)                                     | T-08-06-01, T-08-07-01, T-08-08-01                                                                                                 |
| ENV-DD-02 (読み取り専用)                                             | T-08-11-01, T-08-11-02, T-09-12-02                                                                                                 |
| ENV-DD-03 (登録なし・DisplayName 空で打ち切り)                       | T-08-06-02, T-08-07-04, T-08-09-01, T-08-13-01                                                                                     |
| ENV-DD-04 (インストール方式は照合しない)                             | T-09-01-03, T-09-03-03, T-09-09-01                                                                                                 |
| ENV-DD-05 (不一致は exitCode 2、W5 の合否は変えない)                 | T-09-03-02, T-09-03-03, T-09-04-02                                                                                                 |
| ENV-DD-06 (未知の値は失敗)                                           | T-08-08-04                                                                                                                         |
| ENV-DD-10 (未評価は null)                                            | T-08-06-01, T-08-07-02, T-08-13-02                                                                                                 |
| ENV-DD-12 (権限の値は user / administrator)                          | T-09-02-01, T-09-08-01, T-09-13-01                                                                                                 |
| ENV-DD-13 (`記載なし` の機械検査)                                    | T-09-05-01 〜 T-09-07-04                                                                                                           |
| IDX-DD-04 (終了コード 0 / 2。w5Check の exitCode)                    | T-09-01-04, T-09-03-02                                                                                                             |
| IDX-DD-05 (例外と値の使い分け)                                       | T-08-06-01, T-08-08-01, T-08-08-03                                                                                                 |
| IDX-DD-10 (空の AUMID は使い方の誤り)                                | T-08-05-01, T-08-05-03                                                                                                             |
| IDX-DD-12 (w5-check の exitCode 2。W5 の合否は変えない)              | T-09-03-02, T-09-03-03, T-09-05-06                                                                                                 |
| DR-06 (本体はインターフェースだけを使う / Mock 差し替え)             | T-08-03-01 〜 T-08-04-02, T-09-12-01, T-09-12-02                                                                                   |
| DR-03 (W5 の合否は記録の完備だけ)                                    | T-09-03-03, T-09-05-01 〜 T-09-07-05                                                                                               |
| DR-01 (HKCU 登録・管理者権限不要)                                    | 該当なし (観測できる振る舞いは `windows/` の FFI 実装にあり、手動検証で確かめる)                                                   |

### 対象外 (この文書では扱わない)

| Source item                                                                                            | 扱う場所                                                                          |
| ------------------------------------------------------------------------------------------------------ | --------------------------------------------------------------------------------- |
| ENV-R-008 と ENV-E-01 の add の終了コード 3、ENV-E-15 の add の成否                                    | SchedulingService.add のタスク (tasks-service.md の T-07)。終了コード変換は tasks-cli.md |
| ENV-R-009, ENV-R-010, ENV-E-09, ENV-E-10, ENV-E-20, ENV-E-21, ENV-E-26 (register-reg / unregister-reg) | tasks-cli.md (T-10 / T-11)。`windows/` の登録・削除は手動検証                     |
| ENV-R-011 の Windows 実装 (レジストリでの存在確認)、ENV-E-14 の登録の前後で文字が変わらないこと        | 手動検証 (`windows/win_registry.dart`)                                            |
| ENV-R-017, ENV-R-018, ENV-E-22, ENV-E-23, ENV-E-24 (引数検査と show の終了コード)                      | tasks-cli.md (T-10 / T-11)                                                        |
| ENV-R-019 の `--recorded-*` の引数解析、ENV-DD-07, ENV-DD-08, ENV-DD-09, ENV-DD-11                     | tasks-cli.md (T-10 / T-11)                                                        |
| ENV-E-13 (集中モード・ロック状態)                                                                      | 確認の対象外。観測する入力が無く自動テストの対象外。手動検証で限界を記録する      |

## Category Balance

| Test Target                                | Normal / Error / Edge              | Result |
| ------------------------------------------ | ---------------------------------- | ------ |
| T-08: evaluateAvailability (AVL)           | Normal: 15 \| Error: 13 \| Edge: 8 | [OK]   |
| T-09: w5Check (W5C)                        | Normal: 8 \| Error: 24 \| Edge: 8  | [OK]   |
| T-13: DefaultNotificationEnvironment (NEV) | Normal: 4 \| Error: 8 \| Edge: 1   | [OK]   |
