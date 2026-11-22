---
title: "Implementation Specification: Windows Distribution Verify (Environment)"
based-on: specifications-environment.md v1.0.0
status: Draft
version: 1.0.1
created: "2026-11-22"
---

> implementation-index.md の分割ファイル。通知可否の確認、HKCU の登録と通知設定、W5 の整合チェック、これらの CLI を定める。

## 1. Overview

対応する仕様は specifications-environment.md (REQ-F-002, REQ-F-010, REQ-F-011, REQ-F-021)。
共通の前提、ファイル構成、型は implementation-index.md に従う。

---

## 2. Environment (`env/`)

対象: REQ-F-002, 010, 011, 021 / ENV-R-001〜019。

### 2.1 型とインターフェース

```dart
enum NotificationSetting {
  enabled, disabledForApplication, disabledForUser,
  disabledByGroupPolicy, disabledByManifest,
}

final class Availability {
  final bool registered;
  final bool displayNameSet;
  final NotificationSetting? setting;   // 確認を打ち切ったとき null (未評価)
  final bool ok;
  final String? reason;                 // ok が偽のとき
}

abstract interface class NotificationEnvironment {
  Availability check(String aumid);
  void register(String aumid, String displayName);
  void unregister(String aumid);
  bool isRegistered(String aumid);
}
```

OS に触れる観測を、さらに 3 つの IF に分ける。`evaluateAvailability` と `w5_check` はこれらだけを使う。

```dart
abstract interface class AumidRegistry {
  String? readDisplayName(String aumid);   // 登録が無ければ null。登録はあるが値が無ければ ''
  bool exists(String aumid);
  void write(String aumid, String displayName);
  bool delete(String aumid);               // 登録が無ければ false
}
abstract interface class NotificationSettingSource {
  /// 値が不明 (未知の数値) のときは RegistryException を投げる
  NotificationSetting read(String aumid);
}
abstract interface class PermissionProbe { String current(); }   // 'user' | 'administrator'
```

### 2.2 `evaluateAvailability` (`evaluate_availability.dart`)

```dart
Availability evaluateAvailability(
    String aumid, AumidRegistry registry, NotificationSettingSource settings);
```

ENV-R-001〜007 を次の順に実装する。

1. `aumid.trim().isEmpty` → `UsageException` (確認しない)。
2. `registry.exists(aumid)` が偽なら、`Availability` を返す。値は次のとおり。
   - `registered: false`
   - `displayNameSet: false`
   - `setting: null`
   - `ok: false`
   - `reason: '未登録'`
3. `registry.readDisplayName(aumid)` が null、空、空白だけなら、`Availability` を返す。値は次のとおり。
   - `registered: true`
   - `displayNameSet: false`
   - `setting: null`
   - `ok: false`
   - `reason: 'DisplayName が空'`
4. `settings.read(aumid)` を呼ぶ。
   - `enabled` 以外 → `ok: false`、`reason` に無効の種別名を含める。
   - `enabled` → `ok: true`。
5. `RegistryException` は握りつぶさず再スローする (ENV-R-007。「通知できない」に変換しない)。
   未知の値は `NotificationSettingSource` の実装が `RegistryException` を投げる (ENV-R-005)。

2〜3 で打ち切るとき、`settings.read` は呼ばない (ENV-DD-03)。`evaluateAvailability` は書き込みをしない (ENV-R-012)。

### 2.3 Windows 実装と Mock

- `WinNotificationEnvironment` (`windows/`) は `AumidRegistry` と `NotificationSettingSource` を受け取る。
  - `check`: `evaluateAvailability` に委譲する。
  - `register`: AUMID と DisplayName を検査し、空白だけなら `UsageException`。通れば `registry.write` を呼ぶ。
  - `unregister`: `registry.delete` が偽なら `NotFoundException`。
  - `isRegistered`: `registry.exists` を返す。
- `MockNotificationEnvironment` (`test/support/`) は、OS を呼ばない Mock とする。
  - `check`: 事前に与えられた `Availability` を返す。
  - `register` / `unregister`: 呼び出しを記録するだけで、レジストリと OS のどちらも呼ばない (ENV-R-013, AC-013)。
  - 7 つの状態を作る名前付きコンストラクタを持つ。状態は OK、未登録、DisplayName 空、無効 4 種。
- `kallr_verify` の本体 (`SchedulingService`、`run()`) は `NotificationEnvironment` だけを型として知る。
  `WinNotificationEnvironment` を直接 import しない (REQ-NF-001)。

### 2.4 W5 の完備判定と整合チェック (`w5_check.dart`)

```dart
final class W5Input {
  final String? recordedAumid;
  final String? recordedPermission;       // 'user' | 'administrator'
  final String? recordedInstallMethod;
}

enum W5FieldStatus { match, mismatch, unclear, notChecked }

final class W5FieldResult {
  final String field;                      // 'aumid' | 'permission' | 'install-method'
  final W5FieldStatus status;
  final String? recorded;
  final String? observed;
}

final class W5Report {
  final List<W5FieldResult> fields;
  int get exitCode => fields.every(
      (f) => f.status == W5FieldStatus.match || f.status == W5FieldStatus.notChecked) ? 0 : 2;
}

W5Report w5Check(W5Input input, NotificationEnvironment env, PermissionProbe probe);
```

手順 (ENV-R-014, 015, 016, 019):

1. 各欄が未明確か判定する。値が null、`trim()` で空、または `記載なし` なら `unclear`。この欄は照合しない。
2. aumid 欄が明確なら `env.isRegistered(recordedAumid)` が真で `match`、偽で `mismatch` (`observed` に「登録なし」)。
3. permission 欄が明確なら、`user` / `administrator` 以外の値は `UsageException`。照合は大文字小文字を区別する完全一致とし、`Administrator` は `UsageException` (ENV-DD-12)。それ以外は `probe.current()` と比べて `match` / `mismatch`。
4. install-method 欄が明確なら `status = notChecked` とし、記録した値を `recorded` に入れて「照合していない」と報告する (ENV-DD-04)。
5. `exitCode` は、`unclear` または `mismatch` が 1 つでもあれば 2、そうでなければ 0。W5 の合否は変えず、報告するだけ (ENV-DD-05)。

---

## 3. CLI (environment 系のコマンド)

共通の引数の解析と `run()` は implementation-index.md §4 に従う。ここでは、通知可否と HKCU 登録、W5 に関するコマンドの配線と出力書式を定める。

### 3.1 コマンドの配線

| コマンド       | 処理                                                               |
| -------------- | ------------------------------------------------------------------ |
| show           | 引数を検査 → `env.check` → 5 項目を出力 (対応表を開かない)         |
| register-reg   | 引数を検査 → `env.register` (事前確認しない)                       |
| unregister-reg | 引数を検査 → `env.unregister` (登録が無ければ `NotFoundException`) |
| w5-check       | 引数を検査 → `w5Check` → 3 欄の結果を出力 (対応表を開かない)       |

`show`、`register-reg`、`unregister-reg`、`w5-check` は対応表を使わないので、`openStore` を呼ばない (SQLite を作らない)。

### 3.2 出力書式 (`format.dart`)

- show: 次の 5 行を出す。`setting` が null のときは `(not evaluated)` を出す。作った値は出さない (ENV-DD-10)。
  - `registered: true|false`
  - `displayNameSet: true|false`
  - `setting: <name>|(not evaluated)`
  - `ok: true|false`
  - `reason: <text>`
- w5-check: 欄ごとに `field: status (recorded=..., observed=...)`。install-method は `not checked` と表示する。

---

## 4. Windows Implementation (`windows/`)

OS に触れる部分。自動テストの対象にせず、手動検証で確かめる (REQ-C-002)。各クラスは §2.1 の IF を実装するだけで、判断のロジックを持たない。

### 4.1 `win_registry.dart` (`AumidRegistry`)

advapi32 の関数を FFI で呼ぶ。外部コマンドには頼らない。使う関数は次のとおり。

- キーの開閉: `RegOpenKeyExW`、`RegCreateKeyExW`、`RegCloseKey`
- 値の読み書き: `RegQueryValueExW`、`RegSetValueExW`
- キーの削除: `RegDeleteKeyW`

- キー: `HKEY_CURRENT_USER` の `Software\Classes\AppUserModelId\<aumid>`、値名は `DisplayName` (`REG_SZ`)。
- `exists`: `RegOpenKeyExW` の結果で判定する。
  - `ERROR_SUCCESS`: true
  - `ERROR_FILE_NOT_FOUND` (2): false
  - それ以外: `RegistryException(code)`
- `readDisplayName`: キーが無ければ null。キーはあるが値が無い (`ERROR_FILE_NOT_FOUND`) なら `''`。値は UTF-16 で読む。それ以外のエラーは `RegistryException(code)`。
- `write`: `RegCreateKeyExW` → `RegSetValueExW` (既存なら値を置換)。失敗は `RegistryException(code)`。
- `delete`: `RegDeleteKeyW`。`ERROR_FILE_NOT_FOUND` なら false。他の AUMID のキーには触れない。
- 文字列は UTF-16 (`Utf16`) で渡す。非 ASCII 文字が登録の前後で変わらないこと (ENV-E-14) を手動検証で確認する。
- ハンドルは `try` / `finally` で必ず `RegCloseKey` する。

### 4.2 `win_notification_setting.dart` (`NotificationSettingSource`)

- `ToastNotificationManager` から、AUMID を指定して `ToastNotifier` を作る (`CreateToastNotifierWithId`)。
- `ToastNotifier.Setting` (`get_Setting`) の値を読む。w03.dart の vtable 呼び出しの方式に従う。
- 列挙値を `NotificationSetting` に対応させる。
  - 0: `enabled`
  - 1: `disabledForApplication`
  - 2: `disabledForUser`
  - 3: `disabledByGroupPolicy`
  - 4: `disabledByManifest`
  - これ以外の値は `RegistryException` (未知の値。ENV-R-005)。
- 登録済みの構成で `enabled` が返るかどうかは未確認。無効化した場合の値も未確認。手動検証で測定し、結果を記録する (specifications-environment.md §7 #1)。

### 4.3 `win_permission_probe.dart` (`PermissionProbe`)

- `OpenProcessToken` で自プロセスのトークンを開く。
- `GetTokenInformation(TokenElevation)` が昇格済みなら `administrator`、そうでなければ `user` を返す。
- 失敗は `RegistryException(code)`。

---

## 5. Tests

テスト ID の略語と採番は implementation-index.md §5 に従う。このファイルは、担当する対象の略語と、確認する値だけを示す。

| 略語  | 対象                           | 主な spec の規則               |
| ----- | ------------------------------ | ------------------------------ |
| `AVL` | `evaluateAvailability` と Mock | ENV-R-001〜007, ENV-R-012, 013 |
| `W5C` | `w5Check`                      | ENV-R-014〜016, ENV-R-019      |

| 対象 | 確認する値                                                                                                                                                    |
| ---- | ------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| AVL  | 未登録、DisplayName なし/空/空白、無効 4 種、有効、未知の値で `RegistryException`、打ち切り時に `settings.read` が呼ばれない、`setting == null`、書き込みなし |
| W5C  | 3 欄完備で一致、AUMID 不一致、権限不一致、install-method の `notChecked`、`記載なし`/空白/未指定で `unclear` と exitCode 2、権限の値が不正で `UsageException` |

---

## 6. Change History

<!-- SemVer: MAJOR = approach discarded, MINOR = decision criterion added,
     PATCH = clarification only. Keep frontmatter `version` equal to the newest row.
     `based-on` must cite a three-part version that exists in the specifications.
     See docs/.deckrd/rules/deckrd-rule-document-versioning.md -->

| Date       | Version | Description                                                    |
| ---------- | ------- | -------------------------------------------------------------- |
| 2026-11-22 | 1.0.0   | Split from implementation.md v1.0.0 (content moved, unchanged) |
| 2026-11-22 | 1.0.1   | State that the permission value match is case-sensitive (clarification) |
