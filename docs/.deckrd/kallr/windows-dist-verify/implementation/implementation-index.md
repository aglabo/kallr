---
title: "Implementation Specification: Windows Distribution Verify (Index)"
based-on: specifications-index.md v1.3.0
status: Draft
version: 1.2.0
created: "2026-11-22"
---

> 分割した実装仕様の索引。共通の前提、ファイル構成、共通の型、CLI の共通部、テストの方針、REQ との対応をまとめ、機能ごとの詳細は 4 つの分割ファイルに置く。

## 1. Overview

### 1.1 Purpose

`specifications-*.md` が定めた振る舞いを、Dart のコードとして実現するための具体的な実装仕様を定めます。
定めるのは、ファイル構成、型とシグネチャ、保存形式 (SQLite のスキーマ)、アルゴリズム、OS 依存部の境界、テスト対象と手動検証の切り分けです。
作業の順序、フェーズ、commit の分割は本書の対象外とし、`tasks` が定めます。

### 1.2 Reference

- Specifications:
  - specifications-index.md (v1.1.5)
  - specifications-tag.md (v1.0.0)
  - specifications-schedule.md (v1.5.0)
  - specifications-environment.md (v1.0.0)
  - specifications-verification.md (v1.0.3)
- Prior Art: `poc/windows/w0-3-dartffi/src/w03.dart` (WinRT の FFI)
  - 参照する関数: `check`、`hstr`、`callPtr`
  - 参照する関数: `getInt64`、`toWinRtTicks`、`run`
- DB 設計: db-migration.md (v1.1.0。テーブル、列、関連、版、移行の規則)
- 追記先の文書: `docs/.deckrd/keneek-core/api-contract/workspaces/redesign/poc-results-windows.md`

### 1.3 実装の前提

- 実装場所は `poc/windows/w1-w7-verify/` に限る (REQ-C-001, REQ-F-018, VER-R-010)。
- 言語は Dart (SDK ^3.14.0)。FFI を使う Windows 実装以外は、OS に依存しない純粋な Dart で書く。
- 新しい依存は `sqlite3` (SQLite の束縛、同期 API) と `ffi` の 2 つ。どちらも `poc/` の `pubspec.yaml` にだけ追加する。
- 既存の `lib/map_toast_key.dart` と `test/map_toast_key.unit.spec.dart` (T-WDV-MTK-*) は削除する。
  `module.md` の略語表の `MTK` 行も同時に削除する (IDX-DD-09)。
- 例外から終了コードへの変換は `run()` の 1 か所だけで行う (IDX-DD-05)。それ以外の層は終了コードを知らない。
- プロセスは一度に 1 つだけ動く前提とする。ロックや排他制御は実装しない (SCH-E-24)。

### 1.4 分割ファイル

| ファイル                                                           | 対応する REQ                                                     | 概要                                                                   |
| ------------------------------------------------------------------ | ---------------------------------------------------------------- | ---------------------------------------------------------------------- |
| [implementation-tag.md](./implementation-tag.md)                   | REQ-F-007, REQ-F-016, REQ-F-017, REQ-F-019                       | `tag/` の生成と重複回避、`MachineIdProvider` の実装                    |
| [implementation-schedule.md](./implementation-schedule.md)         | REQ-F-001, REQ-F-004, REQ-F-005, REQ-F-006, REQ-F-020            | `store/`、`schedule/`、予約系の CLI、`WinToastScheduler`               |
| [implementation-environment.md](./implementation-environment.md)   | REQ-F-002, REQ-F-010, REQ-F-011, REQ-F-021                       | `env/`、通知可否と W5 の CLI、HKCU 登録・通知設定・権限の Windows 実装 |
| [implementation-verification.md](./implementation-verification.md) | REQ-F-003, REQ-F-008, REQ-F-009, REQ-F-012〜REQ-F-015, REQ-F-018 | `winrt.dart`、エントリポイント、手動検証、実機で測定する事項           |
| [db-migration.md](./db-migration.md)                               | REQ-F-020                                                        | 対応表 (SQLite) のテーブル、版、移行の規則                             |

---

## 2. Module Layout

```text
poc/windows/w1-w7-verify/
  pubspec.yaml                    sqlite3, ffi を追加
  bin/
    kallr_verify.dart             main: exit(await run(args)) だけ
  lib/
    errors.dart                   例外型
    ids.dart                      識別子の正規化 (normalizeId)
    models.dart                   値型
    tag/
      providers.dart              ClockProvider, RandomSourceProvider, MachineIdProvider (IF)
      generate_tag.dart           generateTag (純粋)
      tag_allocator.dart          allocateTag (重複回避)
    store/
      mapping_table.dart          MappingTable (IF)
      sqlite_store.dart           SQLite の接続、スキーマ、MappingTable と MachineIdProvider の実装
      default_db_path.dart        既定の保存先
    env/
      notification_environment.dart  NotificationEnvironment (IF)、Availability、NotificationSetting
      evaluate_availability.dart  ENV-R-001〜007 の評価 (純粋)
      probes.dart                 AumidRegistry (IF)、NotificationSettingSource (IF)、PermissionProbe (IF)
      w5_check.dart               W5 の完備判定と整合チェック (純粋)
      default_notification_environment.dart  NotificationEnvironment の実装 (AumidRegistry と NotificationSettingSource を束ねる。純粋)
    schedule/
      toast_scheduler.dart        ToastScheduler (IF)
      parse_at.dart               --at の解釈と夏時間の解決 (純粋)
      scheduling_service.dart     SchedulingService
    cli/
      args.dart                   引数の解析
      run.dart                    run(): コマンドの振り分けと終了コードへの変換
      format.dart                 list / show / re-register-all / w5-check の出力書式
    windows/
      winrt.dart                  w03.dart から抜き出した WinRT 呼び出しの共通部
      win_registry.dart           AumidRegistry の実装 (advapi32)
      win_notification_setting.dart  NotificationSettingSource の実装 (ToastNotifier.Setting)
      win_toast_scheduler.dart    ToastScheduler の実装
      win_permission_probe.dart   PermissionProbe の実装 (トークンの昇格)
  test/
    *.unit.spec.dart              OS に触れないテスト。Mock と一時ディレクトリの SQLite を使う
    support/                      Mock 群 (FakeClock など)
```

依存の向きは `cli → schedule/env/store/tag → models/errors` の一方向とする。
`windows/` は `env/` と `schedule/` の IF を実装するだけで、他の層から import されない。
`bin/kallr_verify.dart` だけが `windows/` を組み立てて `run()` に渡す。

公開範囲は、上層と下層で分ける。

- 上層 (公開する): `SchedulingService`、`NotificationEnvironment`、`DefaultNotificationEnvironment`、`Availability`、
  `run()`、`normalizeId`、`models.dart` と `errors.dart` の型。
  `lib/kallr_verify.dart` が export する。
- 下層 (公開しない): `ToastScheduler`、`MappingTable`、`AumidRegistry`、`NotificationSettingSource`、`PermissionProbe`、
  `SqliteStore`、`windows/` の実装。export しない。テストだけが直接 import する。
- 識別子の正規化は上層で行う。下層は正規化済みの値を受け取るだけで、正規化と検査はしない (§3.3)。

---

## 3. Types

### 3.1 例外 (`errors.dart`)

| 型                      | 持つ値                      | 投げる箇所                                     | 終了コード |
| ----------------------- | --------------------------- | ---------------------------------------------- | ---------: |
| `UsageException`        | `message`                   | 引数の検査、`--at` の解釈、AUMID が空          |          1 |
| `UnavailableException`  | `Availability availability` | add / re-register-all の事前確認 (ok が偽)     |          3 |
| `NotFoundException`     | `message`                   | cancel / unregister-reg で対象が無い           |          2 |
| `DuplicateTagException` | `attempts`                  | Tag の再生成が上限を超えた                     |          2 |
| `ScheduleException`     | `message`, `int? hresult`   | OS の予約の追加・削除・一覧の失敗              |          2 |
| `RegistryException`     | `message`, `int win32Code`  | レジストリの読み書きの失敗、通知設定が未知の値 |          2 |
| `StorageException`      | `message`                   | SQLite を開けない、壊れている、書き込みの失敗  |          2 |

- `ArgumentError` (Dart 標準) も `run()` は使い方の誤り (1) として扱う (schedule の impl-note に従う)。`generateTag` の不正入力はこれで投げる。
- すべての例外は `Exception` を実装し、`toString()` で理由を返す。`run()` は理由を標準エラーへ出す。

### 3.2 値型 (`models.dart`)

```dart
final class MappingRecord {
  final String batchId;
  final String alarmId;
  final String tag;               // 40 文字
  final DateTime at;              // 絶対時刻。UTC で保持
  final String title;
  final DateTime registeredAt;    // ローカル日時 (isUtc == false)
}

final class ScheduledToast {      // OS の予約一覧の 1 要素
  final String tag;
  final String group;
  final DateTime at;
}

enum EntryState { ok, orphan, stale }

final class ScheduleEntry {
  final MappingRecord? record;    // orphan のとき null
  final ScheduledToast? toast;    // stale のとき null
  final EntryState state;
}

final class ReRegisterReport {
  final List<MappingRecord> registered;
  final List<({MappingRecord record, String reason})> failed;
  final List<MappingRecord> skippedPast;
  final List<MappingRecord> alreadyPresent;
  int get exitCode => failed.isEmpty ? 0 : 2;
}
```

- `MappingRecord`、`ScheduledToast` は `==` と `hashCode` を、フィールドの値に基づいて定義する (テストの比較に使うため)。

### 3.3 識別子の正規化 (`ids.dart`)

```dart
String normalizeId(String raw);   // raw.trim()
```

- `normalizeId` は前後の空白を削除する。内側の空白は変えない。空文字は空文字のまま返す (例外にしない)。
- 検査は、正規化した上層の各メソッドが、それぞれ行う。
  メソッドは最初に `normalizeId` を呼び、結果が空なら `UsageException` を投げる。
  以降は正規化後の値だけを使い、呼び出し側の値を直接使わない。
- 対象の上層のメソッドは、`SchedulingService` の `add`、`cancel`、`reRegisterAll`、`NotificationEnvironment` の 4 メソッドである。
  `evaluateAvailability` は、`NotificationEnvironment.check` の実体であり、同じ手順で正規化と検査をする。
- CLI の `parseArgs` も同じ関数を使う。二重に正規化しても結果は変わらない。
- `w5Check` の記録の aumid は、空を「未明確」として扱うため、`normalizeId` だけを呼ぶ (例外にしない)。
- 下層 (`ToastScheduler`、`MappingTable`、`AumidRegistry` など) は正規化済みの値を受け取る。
  対応表の DB の `CHECK` は、最後の防御として残す (SCH-R-025、db-migration.md §2.2)。

---

## 4. CLI 共通 (`cli/`)

対象: IDX-DD-04〜05, 10〜13 / SCH-R-001, 012, 028 / ENV-R-017〜019。

### 4.1 コマンドとオプション

| コマンド        | 必須                                   | 任意                                                               |
| --------------- | -------------------------------------- | ------------------------------------------------------------------ |
| add             | `--batch --alarm --at --title --aumid` | `--db`                                                             |
| cancel          | `--batch --alarm --aumid`              | `--db`                                                             |
| list            | `--aumid`                              | `--db`                                                             |
| re-register-all | `--aumid`                              | `--db`                                                             |
| show            | `--aumid`                              | -                                                                  |
| register-reg    | `--aumid --display-name`               | -                                                                  |
| unregister-reg  | `--aumid`                              | -                                                                  |
| w5-check        | `--aumid`                              | `--recorded-aumid --recorded-permission --recorded-install-method` |

### 4.2 引数の解析 (`args.dart`)

```dart
final class ParsedArgs {
  final String command;
  final Map<String, String> options;   // '--' を除いたキー
}
ParsedArgs parseArgs(List<String> args);
```

- 先頭の引数がコマンド名。無い、または未知なら `UsageException`。
- 以降は `--name value` の組だけを受け付ける。`--name=value` も同じに扱う。未知のオプション、値の欠落、同じオプションの重複は `UsageException`。
  未知かどうかは、上の表のコマンドごとの必須と任意で決める。他のコマンド用のオプション (`show --db x` など) も未知とする。
  `--name` の直後の 1 語は、`--` で始まっていても常に値とする。値の欠落は、直後の語が無いときだけである。
  `--name=value` は最初の `=` だけで分割し、残りを値とする (`--title=a=b` の値は `a=b`)。
  値として取った後に `--` で始まらない語が残れば、余分な引数として `UsageException` とする (`--title --at 2026-..` は、`--at` が値になり、`2026-..` が余分な引数になる)。
- 必須オプションの検査はコマンドごとに行う。欠落は `UsageException` (既定値で補わない)。`--batch`、`--alarm`、`--aumid` は `trim()` して空なら欠落と同じ扱い。
  `--batch`、`--alarm`、`--aumid` は、`trim()` した値を `options` に入れる。`run()` は、その値を `env` と `schedulerFor` に渡す。
  `--display-name` も同様に空白だけは欠落と同じ。
- 文字列は `String` のまま扱い、エンコーディングを変換しない (UTF-8 のまま保存する。REQ-NF-004)。コンソールの出力側のコードページは、手動検証で確認する
  (implementation-verification.md §4)。

### 4.3 `run` (`run.dart`)

```dart
Future<int> run(
  List<String> args, {
  required NotificationEnvironment env,
  required ToastScheduler Function(String aumid) schedulerFor,
  required PermissionProbe permissionProbe,
  required ClockProvider clock,
  required RandomSourceProvider random,
  required SqliteStoreFactory openStore,       // path -> (MappingTable, MachineIdProvider)
  StringSink? out,
  StringSink? err,
});
```

- すべての依存は引数で受け取る。これにより Mock だけでコマンドの全体を自動テストできる。
- 本体は 1 つの `try` で `_dispatch(...)` を呼び、例外を終了コードに変える。変換の表は次のとおり (唯一の変換点。IDX-DD-05)。

| 例外 / 結果                              | 終了コード | 標準エラーへ出す内容               |
| ---------------------------------------- | ---------: | ---------------------------------- |
| 正常終了                                 |          0 | -                                  |
| `UsageException`, `ArgumentError`        |          1 | `message`                          |
| `UnavailableException`                   |          3 | `availability.reason`              |
| `NotFoundException`, `ScheduleException` |          2 | `message` (HRESULT を含める)       |
| `DuplicateTagException`                  |          2 | `toString()` (`attempts` を含める) |
| `RegistryException`, `StorageException`  |          2 | `message` (Win32 コードを含める)   |
| 上記以外の例外                           |          2 | `toString()`                       |

- `show` は `Availability` を表示した後、`ok` が偽なら 3 を返す。これは例外ではなく値による分岐で、`UnavailableException` は使わない (ENV-R-018)。
- `re-register-all` と `w5-check` は報告を表示した後、`report.exitCode` を返す。
- `add` と `re-register-all` だけが `UnavailableException` (3) を起こす。`cancel` と `list` は `env.check` を呼ばない。

### 4.4 コマンドの配線と出力書式

コマンドごとの配線と出力書式は、担当する分割ファイルに置く。

- 予約系 (add / cancel / list / re-register-all): implementation-schedule.md §4
- 環境系 (show / register-reg / unregister-reg / w5-check): implementation-environment.md §3

---

## 5. Tests (共通)

### 5.1 方針

- OS に触れない部分 (各機能ファイルの実装) は、Mock と一時ディレクトリの SQLite で自動テストする (REQ-C-002)。
  1 つのテストは 1 つの観測できる値 (戻り値、例外、終了コード、DB の内容) だけを確認する (REQ-NF-002)。
- テストファイルは `test/<対象>.unit.spec.dart`。テスト ID は `T-WDV-<略語>-NN`。略語は PoC のラベル (W1 など) と別物とする (REQ-C-003)。
- `windows/` は自動テストの対象外。手動検証 (implementation-verification.md §4) で確かめる。
- テスト ID の採番と機械検査は `deckrd-rule-testing-guidelines.md` に従う。ID の採番は `tasks` で行う。

### 5.2 テスト対象の略語 (module.md の略語表を、`MTK` の行を削除して、次に置き換える)

| 略語  | 対象                                                                                | 主な spec の規則                                |
| ----- | ----------------------------------------------------------------------------------- | ----------------------------------------------- |
| `TAG` | `generateTag`                                                                       | TAG-R-001〜004                                  |
| `TAL` | `allocateTag` (重複回避)                                                            | TAG-R-005〜007, SCH-E-32                        |
| `MAP` | `MappingTable` (通知の行) と `SqliteStore`                                          | SCH-R-025〜027, SCH-R-029, SCH-E-20, 26         |
| `RPQ` | 置換キュー (`replace` / `pendingRemovals` / `completeRemoval` / `abortReplacement`) | SCH-R-009, SCH-R-010, SCH-R-030, SCH-R-036, 3.5 |
| `MID` | `MachineIdProvider` の実装 (`settings`)                                             | TAG-R-008〜010                                  |
| `AVL` | `evaluateAvailability` と Mock                                                      | ENV-R-001〜007, ENV-R-012, 013                  |
| `W5C` | `w5Check`                                                                           | ENV-R-014〜016, ENV-R-019                       |
| `NEV` | `DefaultNotificationEnvironment` (4 メソッドの正規化と検査)                         | specifications-index 3.1                        |
| `ATP` | `parseAt`                                                                           | SCH-R-002, SCH-R-031                            |
| `SVC` | `SchedulingService`                                                                 | SCH-R-003〜024, 030, 033〜035, 3.5              |
| `ARG` | `parseArgs`                                                                         | SCH-R-001, 012, 028, ENV-R-017                  |
| `CLI` | `run()` (終了コードの変換と出力書式)                                                | IDX-DD-04, 05, 12, 13, ENV-R-018                |
| `NID` | `normalizeId`                                                                       | specifications-index 3.1                        |

機能別の担当は次のとおり。

- TAG / TAL / MID: implementation-tag.md
- MAP / RPQ / ATP / SVC: implementation-schedule.md
- AVL / W5C / NEV: implementation-environment.md
- ARG / CLI: 本書 §4
- NID: 本書 §3.3

### 5.3 自動テストの主な観点 (横断)

機能別の観点は各分割ファイルの Tests に置く。ここには、複数の機能にまたがる CLI の観点だけを置く。

| 対象 | 確認する値                                                                                                           |
| ---- | -------------------------------------------------------------------------------------------------------------------- |
| ARG  | 各コマンドの必須オプションの欠落、空/空白だけの識別子、未知のオプション、`--name=value` 形式                         |
| CLI  | 例外型ごとの終了コード (0/1/2/3)、show の ok 偽で 3、w5-check の 0/2、`openStore` を呼ばないコマンド、標準出力の書式 |

---

## 6. Traceability

| REQ       | 実装の場所                                                   | テスト/検証       | 担当ファイル                |
| --------- | ------------------------------------------------------------ | ----------------- | --------------------------- |
| REQ-F-001 | `SchedulingService.add`、`parseAt`、CLI add                  | SVC, ATP, CLI, W1 | implementation-schedule     |
| REQ-F-002 | `evaluateAvailability`、`SchedulingService.add` の最初の段階 | AVL, SVC, 手動    | implementation-environment  |
| REQ-F-003 | (手動)                                                       | W2                | implementation-verification |
| REQ-F-004 | `SchedulingService.cancel`                                   | SVC, W3           | implementation-schedule     |
| REQ-F-005 | `SchedulingService.add` の置換                               | SVC, RPQ, W4 (a)  | implementation-schedule     |
| REQ-F-006 | `SchedulingService.add` の発火後の分類                       | SVC, W4 (b)       | implementation-schedule     |
| REQ-F-007 | `generateTag`、`kGroup`                                      | TAG, W4 (c)       | implementation-tag          |
| REQ-F-008 | (手動)                                                       | W4 (d)            | implementation-verification |
| REQ-F-009 | `SchedulingService.add` の失敗状態 (3.5)                     | SVC, W4 (e)       | implementation-verification |
| REQ-F-010 | `w5Check`                                                    | W5C, W5           | implementation-environment  |
| REQ-F-011 | `w5Check`                                                    | W5C, W5           | implementation-environment  |
| REQ-F-012 | `SchedulingService.reRegisterAll`                            | SVC, W7           | implementation-verification |
| REQ-F-013 | (手動)                                                       | 任意の測定        | implementation-verification |
| REQ-F-014 | (手動)                                                       | 結果の追記        | implementation-verification |
| REQ-F-015 | (手動)                                                       | 全体の合否        | implementation-verification |
| REQ-F-016 | `generateTag`                                                | TAG               | implementation-tag          |
| REQ-F-017 | `allocateTag`                                                | TAL               | implementation-tag          |
| REQ-F-018 | §2 の配置、`module.md` の owns                               | レビュー          | implementation-verification |
| REQ-F-019 | `SqliteStore` の `MachineIdProvider`                         | MID               | implementation-tag          |
| REQ-F-020 | `SqliteStore` の `MappingTable`                              | MAP, RPQ          | implementation-schedule     |
| REQ-F-021 | `NotificationEnvironment`、Mock、`windows/`                  | AVL, CLI, 手動    | implementation-environment  |

---

## 7. Open Points

仕様が実装での選択に委ねた事項の決定と、実機でしか決まらない事項を分ける。

決定した事項:

- 対応表の既定の保存先: `%LOCALAPPDATA%\kallr\w1-w7-verify\mappings.sqlite3` (implementation-schedule.md §2.1)
- list の出力の書式: タブ区切り (implementation-schedule.md §4.2)
- `at` の保存形式: UTC の ISO 8601 (implementation-schedule.md §2.2)

実機で測定する事項は implementation-verification.md §5 に置く。

---

## 8. Change History

<!-- SemVer: MAJOR = approach discarded, MINOR = decision criterion added,
     PATCH = clarification only. Keep frontmatter `version` equal to the newest row.
     `based-on` must cite a three-part version that exists in the specifications.
     See docs/.deckrd/rules/deckrd-rule-document-versioning.md -->

| Date       | Version | Description                                                                                                                                             |
| ---------- | ------- | ------------------------------------------------------------------------------------------------------------------------------------------------------- |
| 2026-11-22 | 1.0.0   | Split from implementation.md v1.0.0 (content moved, unchanged)                                                                                          |
| 2026-11-22 | 1.0.1   | Follow specifications v1.1.1 / v1.3.1 / v1.0.3 (DR-08 citations)                                                                                        |
| 2026-11-22 | 1.0.2   | stderr of DuplicateTagException is its `toString()` with `attempts`; fix the register of 1.1 (clarification)                                            |
| 2026-11-22 | 1.0.3   | Follow specifications-schedule v1.4.0                                                                                                                   |
| 2026-11-22 | 1.0.4   | Follow specifications-schedule v1.5.0; parseArgs stores the trimmed `--batch` and `--alarm`                                                             |
| 2026-11-22 | 1.0.5   | Follow specifications-index v1.1.2; parseArgs stores the trimmed `--aumid`                                                                              |
| 2026-11-22 | 1.0.6   | Follow specifications-index v1.1.3                                                                                                                      |
| 2026-11-22 | 1.0.7   | Add `ids.dart` (normalizeId, requireId) and the target NID; follow specifications-index v1.1.4                                                          |
| 2026-11-22 | 1.0.8   | Only `normalizeId`; each upper method checks; the lower layer is not public; follow specifications-index v1.1.5                                         |
| 2026-11-22 | 1.0.9   | Move the NotificationEnvironment implementation to env/ (DefaultNotificationEnvironment) and add the target NEV                                         |
| 2026-11-22 | 1.1.0   | parseArgs takes the word after `--name` as the value even if it starts with `--`; `=` splits at the first one (4.2); follow specifications-index v1.2.0 |
| 2026-11-22 | 1.2.0   | Options not listed for the command (including those of other commands) are unknown (4.2); follow specifications-index v1.3.0                            |
