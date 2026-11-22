---
title: "Implementation Tasks: schedule"
module: kallr/windows-dist-verify
status: Active
created: "2026-11-22 00:00:00"
source: specifications-schedule.md
version: 1.0.0
---

<!-- textlint-disable ja-technical-writing/sentence-length -->
<!-- textlint-disable ja-technical-writing/max-comma -->
<!-- markdownlint-disable no-duplicate-heading line-length -->

> This document contains implementation tasks derived from specifications-schedule.md.
> Each task corresponds to a single unit test case (`it()` block).
> 対象は T-04 (ATP)、T-05 (MAP)、T-06 (RPQ)、T-07 (SVC)。Tag の生成 (T-01〜T-03)、CLI (T-10, T-11)、AVL / W5C は別ファイルが扱う。

---

## Task Summary

| Test Target                            | Scenarios | Cases | Status      |
| -------------------------------------- | --------- | ----- | ----------- |
| T-04: parseAt (ATP)                    | 15        | 22    | in progress |
| T-05: MappingTable / SqliteStore (MAP) | 21        | 39    | pending     |
| T-06: 置換キュー (RPQ)                 | 12        | 28    | pending     |
| T-07: SchedulingService (SVC)          | 56        | 142   | pending     |

<!-- Status may be: pending | in progress | done -->

---

## T-04: parseAt (ATP)

> `offsetAt` は次の 2 種類を使う。
>
> - 固定: 常に指定のオフセットを返す (例: 固定 +09:00)。
> - NY 規則: 米国東部の夏時間。`2026-03-08T07:00:00Z` 以降は -04:00、`2026-11-01T06:00:00Z` 以降は -05:00 (それ以前は直前の値)。

### [正常] Normal Cases

#### T-04-01: Given: オフセット +09:00 付きの文字列

- [ ] **T-04-01-01**: +09:00 の文字列を同じ絶対時刻に解釈する
  - Target: `parseAt`
  - Scenario: Given `"2026-11-22T09:30:00+09:00"`, When `parseAt` を呼ぶ
  - Expected: Then `2026-11-22T00:30:00Z` と同じ瞬間を返す

- [ ] **T-04-01-02**: オフセット付きの結果は UTC で保持する
  - Target: `parseAt`
  - Scenario: Given `"2026-11-22T09:30:00+09:00"`, When `parseAt` を呼ぶ
  - Expected: Then 返した `DateTime` の `isUtc` が true である

#### T-04-02: Given: `Z` 付きの文字列

- [ ] **T-04-02-01**: `Z` の文字列を UTC の絶対時刻に解釈する
  - Target: `parseAt`
  - Scenario: Given `"2026-11-22T00:30:00Z"`, When `parseAt` を呼ぶ
  - Expected: Then `2026-11-22T00:30:00Z` と同じ瞬間を返す

#### T-04-03: Given: 負のオフセット -05:00 付きの文字列

- [ ] **T-04-03-01**: -05:00 の文字列を同じ絶対時刻に解釈する
  - Target: `parseAt`
  - Scenario: Given `"2026-11-22T09:30:00-05:00"`, When `parseAt` を呼ぶ
  - Expected: Then `2026-11-22T14:30:00Z` と同じ瞬間を返す

#### T-04-04: Given: オフセット無しの文字列と、固定 +09:00 の `offsetAt` (SCH-R-002, SCH-DD-04)

- [ ] **T-04-04-01**: オフセット無しの文字列をローカル時刻として解決する
  - Target: `parseAt`
  - Scenario: Given `"2026-11-22T09:30:00"` と固定 +09:00 の `offsetAt`, When `parseAt` を呼ぶ
  - Expected: Then `2026-11-22T00:30:00Z` と同じ瞬間を返す

#### T-04-05: Given: オフセット無しの文字列と、固定 -05:00 の `offsetAt` (JST 前提でないこと。SCH-E-03)

- [ ] **T-04-05-01**: ローカルのオフセットに従い、JST を仮定しない
  - Target: `parseAt`
  - Scenario: Given `"2026-11-22T09:30:00"` と固定 -05:00 の `offsetAt`, When `parseAt` を呼ぶ
  - Expected: Then `2026-11-22T14:30:00Z` と同じ瞬間を返す

### [異常] Error Cases

#### T-04-06: Given: 日時として解釈できない文字列 (SCH-R-001 (c))

- [ ] **T-04-06-01**: 解釈できない文字列は使い方の誤りになる
  - Target: `parseAt`
  - Scenario: Given `"tomorrow"`, When `parseAt` を呼ぶ
  - Expected: Then `UsageException` を投げる

#### T-04-07: Given: 空文字

- [ ] **T-04-07-01**: 空文字は使い方の誤りになる
  - Target: `parseAt`
  - Scenario: Given `""`, When `parseAt` を呼ぶ
  - Expected: Then `UsageException` を投げる

#### T-04-08: Given: 存在しない暦の日付

- [ ] **T-04-08-01**: 13 月 45 日は使い方の誤りになる
  - Target: `parseAt`
  - Scenario: Given `"2026-13-45T09:30:00"`, When `parseAt` を呼ぶ
  - Expected: Then `UsageException` を投げる

#### T-04-09: Given: 夏時間の進みで存在しないローカル時刻 (SCH-R-031, SCH-E-05, SCH-DD-14)

- [ ] **T-04-09-01**: 存在しない時刻は使い方の誤りになる
  - Target: `parseAt`
  - Scenario: Given `"2026-03-08T02:30:00"` と NY 規則の `offsetAt`, When `parseAt` を呼ぶ
  - Expected: Then `UsageException` を投げる

### [エッジケース] Edge Cases

#### T-04-10: Given: 夏時間の戻りで曖昧なローカル時刻 (SCH-R-031, SCH-E-05)

- [ ] **T-04-10-01**: 曖昧な時刻は早いほうの瞬間を使う
  - Target: `parseAt`
  - Scenario: Given `"2026-11-01T01:30:00"` と NY 規則の `offsetAt`, When `parseAt` を呼ぶ
  - Expected: Then 早いほうの `2026-11-01T05:30:00Z` と同じ瞬間を返す (遅いほうの `06:30:00Z` ではない)

#### T-04-11: Given: 曖昧な時間帯の明示オフセット付き文字列 (contrast)

- [ ] **T-04-11-01**: 明示オフセットは夏時間の規則に左右されない
  - Target: `parseAt`
  - Scenario: Given `"2026-11-01T01:30:00-05:00"` と NY 規則の `offsetAt`, When `parseAt` を呼ぶ
  - Expected: Then `2026-11-01T06:30:00Z` と同じ瞬間を返す (早いほうに寄せない)

#### T-04-12: Given: 過去の時刻 (SCH-DD-05)

- [ ] **T-04-12-01**: 過去の時刻を検査しない
  - Target: `parseAt`
  - Scenario: Given `"2000-01-01T00:00:00Z"`, When `parseAt` を呼ぶ
  - Expected: Then 例外を投げず、`2000-01-01T00:00:00Z` と同じ瞬間を返す

#### T-04-13: Given: 曖昧な時間帯の境界 (NY 規則)

- [ ] **T-04-13-01**: 曖昧になる直前の 00:59:59 は曖昧でない
  - Target: `parseAt`
  - Scenario: Given `"2026-11-01T00:59:59"` と NY 規則の `offsetAt`, When `parseAt` を呼ぶ
  - Expected: Then `2026-11-01T04:59:59Z` と同じ瞬間を返す

- [ ] **T-04-13-02**: 曖昧な時間帯の先頭 01:00:00 は早いほうを使う
  - Target: `parseAt`
  - Scenario: Given `"2026-11-01T01:00:00"` と NY 規則の `offsetAt`, When `parseAt` を呼ぶ
  - Expected: Then `2026-11-01T05:00:00Z` と同じ瞬間を返す

- [ ] **T-04-13-03**: 曖昧な時間帯の末尾 01:59:59 は早いほうを使う
  - Target: `parseAt`
  - Scenario: Given `"2026-11-01T01:59:59"` と NY 規則の `offsetAt`, When `parseAt` を呼ぶ
  - Expected: Then `2026-11-01T05:59:59Z` と同じ瞬間を返す

- [ ] **T-04-13-04**: 曖昧でなくなる 02:00:00 は標準時の瞬間になる
  - Target: `parseAt`
  - Scenario: Given `"2026-11-01T02:00:00"` と NY 規則の `offsetAt`, When `parseAt` を呼ぶ
  - Expected: Then `2026-11-01T07:00:00Z` と同じ瞬間を返す

#### T-04-14: Given: 存在しない時間帯の境界 (NY 規則)

- [ ] **T-04-14-01**: 存在しなくなる直前の 01:59:59 は有効である
  - Target: `parseAt`
  - Scenario: Given `"2026-03-08T01:59:59"` と NY 規則の `offsetAt`, When `parseAt` を呼ぶ
  - Expected: Then `2026-03-08T06:59:59Z` と同じ瞬間を返す

- [ ] **T-04-14-02**: 存在しない時間帯の先頭 02:00:00 は使い方の誤りになる
  - Target: `parseAt`
  - Scenario: Given `"2026-03-08T02:00:00"` と NY 規則の `offsetAt`, When `parseAt` を呼ぶ
  - Expected: Then `UsageException` を投げる

- [ ] **T-04-14-03**: 存在しない時間帯の末尾 02:59:59 は使い方の誤りになる
  - Target: `parseAt`
  - Scenario: Given `"2026-03-08T02:59:59"` と NY 規則の `offsetAt`, When `parseAt` を呼ぶ
  - Expected: Then `UsageException` を投げる

- [ ] **T-04-14-04**: 存在し直す 03:00:00 は有効である
  - Target: `parseAt`
  - Scenario: Given `"2026-03-08T03:00:00"` と NY 規則の `offsetAt`, When `parseAt` を呼ぶ
  - Expected: Then `2026-03-08T07:00:00Z` と同じ瞬間を返す

#### T-04-15: Given: 夏時間の規則がある地域の、切り替えと無関係な時刻

- [ ] **T-04-15-01**: 切り替えと無関係な夏の時刻は 1 つの瞬間に決まる
  - Target: `parseAt`
  - Scenario: Given `"2026-07-01T12:00:00"` と NY 規則の `offsetAt`, When `parseAt` を呼ぶ
  - Expected: Then `2026-07-01T16:00:00Z` と同じ瞬間を返す

---

## T-05: MappingTable / SqliteStore (MAP)

> 共通の前提: 一時ディレクトリの SQLite を使う。`MappingRecord` の例は (batchId `b1`, alarmId `a1`, tag `20261122090000-a1b2c3d4-0123456789abcdef`, at `2026-11-22T12:00:00+09:00`, title `t1`, registeredAt `2026-11-22T09:00:00` (ローカル))。
> DB の内容は、テストが SQLite を直接読んで確認する。

### [正常] Normal Cases

#### T-05-01: Given: 空の対応表に put した後 (SCH-R-025)

- [ ] **T-05-01-01**: put した項目を get で同じ値のまま引ける
  - Target: `MappingTable.get`
  - Scenario: Given 空の対応表に `b1` / `a1` の項目を `put` した, When `get('b1','a1')` を呼ぶ
  - Expected: Then 全フィールドが等しい `MappingRecord` を返す

#### T-05-02: Given: 保存形式 (db-migration.md §2.2)

- [ ] **T-05-02-01**: `at` は UTC の ISO 8601 で保存する
  - Target: `MappingTable.put`
  - Scenario: Given `at` が `2026-11-22T12:00:00+09:00` の項目, When `put` する
  - Expected: Then `notifications.at` の値が `2026-11-22T03:00:00.000Z` である

- [ ] **T-05-02-02**: 読み戻した `at` は同じ絶対時刻になる
  - Target: `MappingTable.get`
  - Scenario: Given `at` が `2026-11-22T12:00:00+09:00` の項目を `put` した, When `get` する
  - Expected: Then 返した `at` が `2026-11-22T03:00:00Z` と同じ瞬間である

- [ ] **T-05-02-03**: `registeredAt` はオフセット無しのローカル日時で保存し、ローカルのまま読み戻す
  - Target: `MappingTable.put`
  - Scenario: Given `registeredAt` が `2026-11-22T09:00:00` (ローカル) の項目, When `put` して `get` する
  - Expected: Then `notifications.registered_at` が `2026-11-22T09:00:00.000` で、返した `registeredAt` の `isUtc` が false である

- [ ] **T-05-02-04**: `group_name` に `kallr` を入れる
  - Target: `MappingTable.put`
  - Scenario: Given 新規の項目, When `put` する
  - Expected: Then `notifications.group_name` が `kallr` である

- [ ] **T-05-02-05**: title の UTF-8 文字をそのまま保存する (SCH-E-23)
  - Target: `MappingTable.put`
  - Scenario: Given title が `会議の開始` の項目, When `put` して `get` する
  - Expected: Then 返した title が `会議の開始` と等しい

#### T-05-03: Given: 同じ (batchId, alarmId) に 2 回 put する (SCH-R-025)

- [ ] **T-05-03-01**: 2 回目の値で上書きされる
  - Target: `MappingTable.put`
  - Scenario: Given `b1` / `a1` に tag `...-0123456789abcdef` を `put` 済み, When 同じキーに別の tag と at と title で `put` する
  - Expected: Then `get('b1','a1')` が 2 回目の値を返す

- [ ] **T-05-03-02**: 上書きでも物理 ID は変わらない
  - Target: `MappingTable.put`
  - Scenario: Given `b1` / `a1` を `put` 済みで `notifications.id` を控えた, When 同じキーに別の tag で `put` する
  - Expected: Then `notifications.id` が控えた値のままである

- [ ] **T-05-03-03**: 有効な項目は 1 つだけである
  - Target: `MappingTable.all`
  - Scenario: Given 同じキーに 2 回 `put` した, When `all()` を呼ぶ
  - Expected: Then 要素数が 1 である

#### T-05-04: Given: 項目を remove した後

- [ ] **T-05-04-01**: remove した項目は get で引けない
  - Target: `MappingTable.remove`
  - Scenario: Given `b1` / `a1` を `put` 済み, When `remove('b1','a1')` を呼ぶ
  - Expected: Then `get('b1','a1')` が null を返す

- [ ] **T-05-04-02**: remove した項目は all に含まれない
  - Target: `MappingTable.remove`
  - Scenario: Given `b1` / `a1` を `put` 済み, When `remove('b1','a1')` を呼ぶ
  - Expected: Then `all()` が空である

#### T-05-05: Given: 異なるキーを 2 件 put した後

- [ ] **T-05-05-01**: all は 2 件を返す
  - Target: `MappingTable.all`
  - Scenario: Given `b1`/`a1` と `b1`/`a2` を `put` 済み, When `all()` を呼ぶ
  - Expected: Then 2 件の `MappingRecord` を返す

- [ ] **T-05-05-02**: tags は 2 件の Tag を返す
  - Target: `MappingTable.tags`
  - Scenario: Given `b1`/`a1` と `b1`/`a2` を `put` 済み, When `tags()` を呼ぶ
  - Expected: Then 2 件の Tag を含む `Set` を返す

#### T-05-06: Given: 存在しないパスに SqliteStore を開く (SCH-R-027, 初回の利用)

- [ ] **T-05-06-01**: ファイルが作られる
  - Target: `SqliteStore.open`
  - Scenario: Given 存在しない `new.sqlite3` のパス, When `open` する
  - Expected: Then そのパスにファイルが作られる

- [ ] **T-05-06-02**: `user_version` が 1 になる
  - Target: `SqliteStore.open`
  - Scenario: Given 存在しない `new.sqlite3` のパス, When `open` する
  - Expected: Then `PRAGMA user_version` が 1 である

- [ ] **T-05-06-03**: 3 つのテーブルが作られる
  - Target: `SqliteStore.open`
  - Scenario: Given 存在しない `new.sqlite3` のパス, When `open` する
  - Expected: Then `notifications`、`replacement_queue`、`settings` の 3 テーブルが存在する

- [ ] **T-05-06-04**: 空の対応表として始まる
  - Target: `SqliteStore.open`
  - Scenario: Given 存在しない `new.sqlite3` のパス, When `open` して `all()` を呼ぶ
  - Expected: Then 空のリストを返す

#### T-05-07: Given: 正常な既存ファイルを開き直す

- [ ] **T-05-07-01**: 保存済みの項目を読める
  - Target: `SqliteStore.open`
  - Scenario: Given `b1`/`a1` を `put` して閉じた正常なファイル, When 同じパスを `open` して `get('b1','a1')` を呼ぶ
  - Expected: Then `put` した値と等しい `MappingRecord` を返す

#### T-05-08: Given: 接続の設定

- [ ] **T-05-08-01**: 外部キー制約が有効である
  - Target: `SqliteStore.open`
  - Scenario: Given 開いた接続, When `PRAGMA foreign_keys` を読む
  - Expected: Then 値が 1 (ON) である

#### T-05-09: Given: `--db` で指定した保存先 (SCH-R-029, SCH-E-26, SCH-DD-12)

- [ ] **T-05-09-01**: 指定したパスのファイルを使う
  - Target: `SqliteStore.open`
  - Scenario: Given `--db` 相当のパス `<tmp>/custom/x.sqlite3` (親ディレクトリあり), When `open` して `put` する
  - Expected: Then そのパスのファイルに項目が保存されている

#### T-05-10: Given: `--db` が無いときの既定の保存先 (SCH-R-029, SCH-DD-12)

- [ ] **T-05-10-01**: LOCALAPPDATA 配下の既定のパスを返す
  - Target: `default_db_path.dart` の既定の保存先の解決
  - Scenario: Given 環境変数 `LOCALAPPDATA` が `C:\Users\tester\AppData\Local`, When 既定の保存先を求める
  - Expected: Then `C:\Users\tester\AppData\Local\kallr\w1-w7-verify\mappings.sqlite3` を返す

### [異常] Error Cases

#### T-05-11: Given: 別のキーが持つ Tag と同じ Tag の項目を put する (SCH-R-025, SCH-R-026)

- [ ] **T-05-11-01**: UNIQUE 違反は StorageException になる
  - Target: `MappingTable.put`
  - Scenario: Given `b1`/`a1` が tag `T1` を持つ, When `b2`/`a2` に同じ tag `T1` で `put` する
  - Expected: Then `StorageException` を投げる

- [ ] **T-05-11-02**: 失敗した put は何も変えない
  - Target: `MappingTable.put`
  - Scenario: Given `b1`/`a1` が tag `T1` を持つ, When `b2`/`a2` に同じ tag `T1` で `put` して失敗した
  - Expected: Then `all()` が失敗前と同じ 1 件のままである

#### T-05-12: Given: batchId が空文字の項目 (3.3 の制約)

- [ ] **T-05-12-01**: 空の batchId は StorageException になる
  - Target: `MappingTable.put`
  - Scenario: Given batchId が `""` の項目, When `put` する
  - Expected: Then `StorageException` を投げる

- [ ] **T-05-12-02**: 空の batchId の項目は保存されない
  - Target: `MappingTable.put`
  - Scenario: Given batchId が `""` の項目, When `put` して失敗した
  - Expected: Then `all()` が空である

#### T-05-13: Given: Tag の長さが 40 でない項目 (db-migration.md §2.2 の CHECK)

- [ ] **T-05-13-01**: 39 文字の Tag は StorageException になる
  - Target: `MappingTable.put`
  - Scenario: Given tag が 39 文字の項目, When `put` する
  - Expected: Then `StorageException` を投げる

- [ ] **T-05-13-02**: 41 文字の Tag は StorageException になる
  - Target: `MappingTable.put`
  - Scenario: Given tag が 41 文字の項目, When `put` する
  - Expected: Then `StorageException` を投げる

#### T-05-14: Given: 壊れたファイル (SCH-R-027, SCH-E-20)

- [ ] **T-05-14-01**: 壊れたファイルは StorageException になる
  - Target: `SqliteStore.open`
  - Scenario: Given 100 バイトの SQLite でない文字列を書いた既存ファイル, When `open` する
  - Expected: Then `StorageException` を投げる

- [ ] **T-05-14-02**: 壊れたファイルは作り直さない
  - Target: `SqliteStore.open`
  - Scenario: Given 100 バイトの SQLite でない文字列を書いた既存ファイル, When `open` して失敗した
  - Expected: Then ファイルのバイト列が `open` の前と同じである

#### T-05-15: Given: `user_version` が 2 の既存ファイル (db-migration.md §3.1)

- [ ] **T-05-15-01**: 未定義の版は StorageException になる
  - Target: `SqliteStore.open`
  - Scenario: Given `PRAGMA user_version = 2` の正常な SQLite ファイル, When `open` する
  - Expected: Then `StorageException` を投げる

- [ ] **T-05-15-02**: 未定義の版のファイルは変更しない
  - Target: `SqliteStore.open`
  - Scenario: Given `PRAGMA user_version = 2` の正常な SQLite ファイル, When `open` して失敗した
  - Expected: Then ファイルのバイト列が `open` の前と同じである

#### T-05-16: Given: `user_version` が 0 の既存ファイル (テーブルが無い 0 バイトのファイル)

- [ ] **T-05-16-01**: 版が 1 以外の既存ファイルは StorageException になる
  - Target: `SqliteStore.open`
  - Scenario: Given 0 バイトの既存ファイル, When `open` する
  - Expected: Then `StorageException` を投げる

#### T-05-17: Given: 環境変数 LOCALAPPDATA が無い

- [ ] **T-05-17-01**: 既定の保存先を決められず StorageException になる
  - Target: `default_db_path.dart` の既定の保存先の解決
  - Scenario: Given 環境変数 `LOCALAPPDATA` が未設定, When 既定の保存先を求める
  - Expected: Then `StorageException` を投げる

### [エッジケース] Edge Cases

#### T-05-18: Given: 存在しないキーの remove

- [ ] **T-05-18-01**: 存在しないキーの remove は例外を投げない
  - Target: `MappingTable.remove`
  - Scenario: Given `b1`/`a1` だけが `put` 済み, When `remove('b9','a9')` を呼ぶ
  - Expected: Then 例外を投げない

- [ ] **T-05-18-02**: 存在しないキーの remove は他の項目を変えない
  - Target: `MappingTable.remove`
  - Scenario: Given `b1`/`a1` だけが `put` 済み, When `remove('b9','a9')` を呼ぶ
  - Expected: Then `get('b1','a1')` が元の値を返す

#### T-05-19: Given: 空の対応表

- [ ] **T-05-19-01**: 空の対応表の all は空のリストを返す
  - Target: `MappingTable.all`
  - Scenario: Given 何も `put` していない対応表, When `all()` を呼ぶ
  - Expected: Then 空のリストを返す

- [ ] **T-05-19-02**: 空の対応表の tags は空の集合を返す
  - Target: `MappingTable.tags`
  - Scenario: Given 何も `put` していない対応表, When `tags()` を呼ぶ
  - Expected: Then 空の `Set` を返す

#### T-05-20: Given: 親ディレクトリが無い保存先 (db-migration.md / impl §2.1)

- [ ] **T-05-20-01**: 親ディレクトリを作って開く
  - Target: `SqliteStore.open`
  - Scenario: Given 存在しない `<tmp>/a/b/c` を親に持つ `x.sqlite3` のパス, When `open` する
  - Expected: Then 親ディレクトリが作られ、例外を投げずにファイルが作られる

#### T-05-21: Given: 同じキー・同じ Tag で title だけ変えて put する

- [ ] **T-05-21-01**: 自分自身の Tag との重複は UNIQUE 違反にならない
  - Target: `MappingTable.put`
  - Scenario: Given `b1`/`a1` が tag `T1` で `put` 済み, When 同じキーを同じ tag `T1` で title だけ `t2` にして `put` する
  - Expected: Then 例外を投げず、`get('b1','a1')` の title が `t2` である

---

## T-06: 置換キュー (RPQ)

> 共通の前提: 旧行は (`b1`,`a1`, tag `OLD`=`20261122090000-a1b2c3d4-0123456789abcdef`, at `2026-11-22T12:00:00+09:00`, title `旧`) で current。
> 置換後の `MappingRecord` は (`b1`,`a1`, tag `PND`=`20261122093000-a1b2c3d4-0123456789abcdef`, at `2026-11-22T13:00:00+09:00`, title `新`)。
> `notify_status` は 1 = current、2 = pending、0 = superseded。DB の内容は SQLite を直接読んで確認する。

### [正常] Normal Cases

#### T-06-01: Given: 旧行が current の状態で replace した直後 (SCH-R-009 段階 1, SCH-DD-01)

- [ ] **T-06-01-01**: 置換後の行が pending で追加される
  - Target: `MappingTable.replace`
  - Scenario: Given 旧行が current, When 置換後の `MappingRecord` で `replace` する
  - Expected: Then tag `PND` の行が `notify_status = 2` で存在する

- [ ] **T-06-01-02**: 旧行が superseded になる
  - Target: `MappingTable.replace`
  - Scenario: Given 旧行が current, When 置換後の `MappingRecord` で `replace` する
  - Expected: Then tag `OLD` の行が `notify_status = 0` である

- [ ] **T-06-01-03**: キューに (新行の id, 旧行の id) が入る
  - Target: `MappingTable.replace`
  - Scenario: Given 旧行が current, When 置換後の `MappingRecord` で `replace` する
  - Expected: Then `replacement_queue` に `new_id` が新行の id、`old_id` が旧行の id の行がちょうど 1 件ある

- [ ] **T-06-01-04**: 戻り値はキューの行の id である
  - Target: `MappingTable.replace`
  - Scenario: Given 旧行が current, When 置換後の `MappingRecord` で `replace` する
  - Expected: Then 戻り値が `replacement_queue.id` と等しい

#### T-06-02: Given: replace 直後の参照 (impl §2.4)

- [ ] **T-06-02-01**: get は置換後の行を返す
  - Target: `MappingTable.get`
  - Scenario: Given `replace` した直後, When `get('b1','a1')` を呼ぶ
  - Expected: Then tag `PND` の `MappingRecord` を返す

- [ ] **T-06-02-02**: all は旧行を含まず pending の行を含む
  - Target: `MappingTable.all`
  - Scenario: Given `replace` した直後, When `all()` を呼ぶ
  - Expected: Then tag `PND` の 1 件だけを返す

- [ ] **T-06-02-03**: tags は旧行の Tag を含む
  - Target: `MappingTable.tags`
  - Scenario: Given `replace` した直後, When `tags()` を呼ぶ
  - Expected: Then `OLD` と `PND` の両方を含む

#### T-06-03: Given: 保留が 1 件ある

- [ ] **T-06-03-01**: pendingRemovals は旧行の Tag・Group・置換後の値を返す
  - Target: `MappingTable.pendingRemovals`
  - Scenario: Given `replace` した直後, When `pendingRemovals()` を呼ぶ
  - Expected: Then 1 件で、`queueId` が `replace` の戻り値、`oldTag` が `OLD`、`group` が `kallr`、置換後の `MappingRecord` が tag `PND` の値である

#### T-06-04: Given: 保留が 2 件ある

- [ ] **T-06-04-01**: pendingRemovals は queueId の昇順で返す
  - Target: `MappingTable.pendingRemovals`
  - Scenario: Given `b1`/`a1` を先に、`b2`/`a2` を後に `replace` した, When `pendingRemovals()` を呼ぶ
  - Expected: Then `b1`/`a1` の保留、`b2`/`a2` の保留の順で 2 件を返す

#### T-06-05: Given: 保留を completeRemoval した後 (SCH-R-009 段階 4)

- [ ] **T-06-05-01**: 旧行が削除される
  - Target: `MappingTable.completeRemoval`
  - Scenario: Given `replace` 済みで `queueId` を得た, When `completeRemoval(queueId)` を呼ぶ
  - Expected: Then tag `OLD` の行が `notifications` に存在しない

- [ ] **T-06-05-02**: 新行が current になる
  - Target: `MappingTable.completeRemoval`
  - Scenario: Given `replace` 済みで `queueId` を得た, When `completeRemoval(queueId)` を呼ぶ
  - Expected: Then tag `PND` の行が `notify_status = 1` である

- [ ] **T-06-05-03**: キューの行は残り `old_id` が NULL になる
  - Target: `MappingTable.completeRemoval`
  - Scenario: Given `replace` 済みで `queueId` を得た, When `completeRemoval(queueId)` を呼ぶ
  - Expected: Then `replacement_queue` の該当行が残り、`old_id` が NULL である

- [ ] **T-06-05-04**: 完了済みの行は pendingRemovals に出ない
  - Target: `MappingTable.pendingRemovals`
  - Scenario: Given `completeRemoval` 済み, When `pendingRemovals()` を呼ぶ
  - Expected: Then 空のリストを返す

- [ ] **T-06-05-05**: tags から旧行の Tag が消える
  - Target: `MappingTable.tags`
  - Scenario: Given `completeRemoval` 済み, When `tags()` を呼ぶ
  - Expected: Then `PND` を含み、`OLD` を含まない

#### T-06-06: Given: 保留を abortReplacement した後 (SCH-R-010)

- [ ] **T-06-06-01**: 新行が削除される
  - Target: `MappingTable.abortReplacement`
  - Scenario: Given `replace` 済みで `queueId` を得た, When `abortReplacement(queueId)` を呼ぶ
  - Expected: Then tag `PND` の行が `notifications` に存在しない

- [ ] **T-06-06-02**: キューの行も削除される
  - Target: `MappingTable.abortReplacement`
  - Scenario: Given `replace` 済みで `queueId` を得た, When `abortReplacement(queueId)` を呼ぶ
  - Expected: Then `replacement_queue` に該当行が存在しない (`ON DELETE CASCADE`)

- [ ] **T-06-06-03**: 旧行が current に戻る
  - Target: `MappingTable.abortReplacement`
  - Scenario: Given `replace` 済みで `queueId` を得た, When `abortReplacement(queueId)` を呼ぶ
  - Expected: Then tag `OLD` の行が `notify_status = 1` である

- [ ] **T-06-06-04**: get は旧行の値を返す
  - Target: `MappingTable.get`
  - Scenario: Given `abortReplacement` 済み, When `get('b1','a1')` を呼ぶ
  - Expected: Then tag `OLD` の `MappingRecord` を返す

- [ ] **T-06-06-05**: 取り消した保留は pendingRemovals に出ない
  - Target: `MappingTable.pendingRemovals`
  - Scenario: Given `abortReplacement` 済み, When `pendingRemovals()` を呼ぶ
  - Expected: Then 空のリストを返す

### [異常] Error Cases

#### T-06-07: Given: 置換後の Tag が別のキーの Tag と衝突する replace (SCH-R-026, SCH-E-11)

- [ ] **T-06-07-01**: StorageException になる
  - Target: `MappingTable.replace`
  - Scenario: Given `b9`/`a9` が tag `PND` を持つ, When `b1`/`a1` を tag `PND` で `replace` する
  - Expected: Then `StorageException` を投げる

- [ ] **T-06-07-02**: 旧行は current のまま変わらない
  - Target: `MappingTable.replace`
  - Scenario: Given `b9`/`a9` が tag `PND` を持つ, When `b1`/`a1` を tag `PND` で `replace` して失敗した
  - Expected: Then tag `OLD` の行が `notify_status = 1` である

- [ ] **T-06-07-03**: 新行とキューの行は作られない
  - Target: `MappingTable.replace`
  - Scenario: Given `b9`/`a9` が tag `PND` を持つ, When `b1`/`a1` を tag `PND` で `replace` して失敗した
  - Expected: Then `replacement_queue` が 0 件で、`notifications` に pending の行が無い

#### T-06-08: Given: 置換後の Tag が旧行の Tag と同じ replace

- [ ] **T-06-08-01**: StorageException になる
  - Target: `MappingTable.replace`
  - Scenario: Given 旧行の tag が `OLD`, When `b1`/`a1` を tag `OLD` で `replace` する
  - Expected: Then `StorageException` を投げる

- [ ] **T-06-08-02**: 旧行は current のまま変わらない
  - Target: `MappingTable.replace`
  - Scenario: Given 旧行の tag が `OLD`, When `b1`/`a1` を tag `OLD` で `replace` して失敗した
  - Expected: Then tag `OLD` の行が `notify_status = 1` である

### [エッジケース] Edge Cases

#### T-06-09: Given: 2 件の保留のうち 1 件を complete する

- [ ] **T-06-09-01**: もう 1 件は保留のまま残る
  - Target: `MappingTable.completeRemoval`
  - Scenario: Given `b1`/`a1` と `b2`/`a2` を `replace` 済み, When `b1`/`a1` の `completeRemoval` を呼ぶ
  - Expected: Then `pendingRemovals()` が `b2`/`a2` の 1 件だけを返す

#### T-06-10: Given: 2 件の保留のうち 1 件を abort する

- [ ] **T-06-10-01**: もう 1 件の新行は pending のまま残る
  - Target: `MappingTable.abortReplacement`
  - Scenario: Given `b1`/`a1` と `b2`/`a2` を `replace` 済み, When `b1`/`a1` の `abortReplacement` を呼ぶ
  - Expected: Then `b2`/`a2` の新行が `notify_status = 2` のままである

#### T-06-11: Given: 完了後にもう一度 replace する (AUTOINCREMENT)

- [ ] **T-06-11-01**: キューの id を再利用しない
  - Target: `MappingTable.replace`
  - Scenario: Given 1 回目の `replace` の `queueId` を `completeRemoval` した, When 同じキーを別の tag で 2 回目の `replace` する
  - Expected: Then 戻り値が 1 回目の `queueId` より大きい

#### T-06-12: Given: 完了済みのキュー行が残っている状態で、同じキーをもう一度 replace する

- [ ] **T-06-12-01**: pendingRemovals は新しい保留の 1 件だけを返す
  - Target: `MappingTable.pendingRemovals`
  - Scenario: Given 1 回目の置換を `completeRemoval` 済みで、2 回目の `replace` をした, When `pendingRemovals()` を呼ぶ
  - Expected: Then 2 回目の保留 1 件だけを返す (完了済みの行を含まない)

---

## T-07: SchedulingService (SVC)

> 共通の前提 (Fake / Mock):
>
> - `env` は `Availability(ok)` を返す Fake。`aumid` は `Kallr.Test`。
> - `scheduler` は `MockToastScheduler` (メモリ上の予約一覧と呼び出し順序の記録、失敗の注入)。`table` は呼び出し記録と失敗の注入ができる `MappingTable` の Fake。
> - `clock.now()` は `2026-11-22T10:00:00` (ローカル)。`machineId` は `a1b2c3d4`。`random` の返す乱数は 1 回目 `0123456789abcdef`、2 回目 `fedcba9876543210`。
> - 生成される Tag: 1 回目 `ADD1`=`20261122100000-a1b2c3d4-0123456789abcdef`、乱数を再生成したとき `ADD2`=`20261122100000-a1b2c3d4-fedcba9876543210`。
> - 既存の Tag: `OLD`=`20261122090000-a1b2c3d4-0123456789abcdef` (b1/a1 の現行)、`PND`=`20261122093000-a1b2c3d4-0123456789abcdef`。
> - `at` の例: `A1`=`2026-11-22T12:00:00+09:00` (now より後)。
> - 停止状態 (置換の保留。キー b1/a1、旧行 `OLD` が superseded、新行 `PND` が pending (at `2026-11-22T13:00:00+09:00`, title `再開後`)):
>   - P2 (段階 2 の前): 予約一覧に `OLD` だけ。
>   - P3 (段階 3 の前): 予約一覧に `OLD` と `PND` の両方。
>   - P4 (段階 4 の前): 予約一覧に `PND` だけ。

### [正常] Normal Cases

#### T-07-01: Given: 対応表に無いキーで add する (新規。SCH-R-004, SCH-R-008, SCH-R-011, IDX-R-004)

- [ ] **T-07-01-01**: 新しい MappingRecord を返す
  - Target: `SchedulingService.add`
  - Scenario: Given 空の対応表と空の予約一覧, When `add(batchId: 'b1', alarmId: 'a1', at: A1, title: 't1', aumid: 'Kallr.Test')` を呼ぶ
  - Expected: Then tag `ADD1`、at `A1`、title `t1`、registeredAt `2026-11-22T10:00:00` の `MappingRecord` を返す

- [ ] **T-07-01-02**: 予約一覧に新しい Tag の予約がちょうど 1 件できる
  - Target: `SchedulingService.add`
  - Scenario: Given 空の対応表と空の予約一覧, When `add` を呼ぶ
  - Expected: Then `scheduler.list('kallr')` が tag `ADD1`、group `kallr`、at `A1` の 1 件だけを返す

- [ ] **T-07-01-03**: 対応表に同じ内容が記録される
  - Target: `SchedulingService.add`
  - Scenario: Given 空の対応表と空の予約一覧, When `add` を呼ぶ
  - Expected: Then `table.get('b1','a1')` が返り値と等しい

- [ ] **T-07-01-04**: 予約の追加が対応表の更新より先である
  - Target: `SchedulingService.add`
  - Scenario: Given 空の対応表と空の予約一覧, When `add` を呼ぶ
  - Expected: Then 呼び出し順が `scheduler.add` → `table.put` である

- [ ] **T-07-01-05**: 通知可否の確認に aumid を渡す
  - Target: `SchedulingService.add`
  - Scenario: Given 空の対応表と空の予約一覧, When `add(aumid: 'Kallr.Test')` を呼ぶ
  - Expected: Then `env.check` が `Kallr.Test` で 1 回呼ばれる

#### T-07-02: Given: 対応表の Tag が予約一覧にある同じキーで add する (置換。SCH-R-005, SCH-R-009, SCH-R-011, IDX-R-005, DR-05, DR-07)

- [ ] **T-07-02-01**: 新しい Tag の MappingRecord を返す
  - Target: `SchedulingService.add`
  - Scenario: Given `b1`/`a1` が `OLD` で対応表と予約一覧にある, When 新しい at `A1` と title `t2` で `add` する
  - Expected: Then tag `ADD1` (`OLD` ではない)、registeredAt `2026-11-22T10:00:00` の `MappingRecord` を返す

- [ ] **T-07-02-02**: 予約一覧に置換前の Tag の予約が無い
  - Target: `SchedulingService.add`
  - Scenario: Given `b1`/`a1` が `OLD` で対応表と予約一覧にある, When `add` する
  - Expected: Then `scheduler.list('kallr')` が tag `ADD1` の 1 件だけを返し、`OLD` を含まない

- [ ] **T-07-02-03**: 対応表は置換後の内容を current として持つ
  - Target: `SchedulingService.add`
  - Scenario: Given `b1`/`a1` が `OLD` で対応表と予約一覧にある, When `add` する
  - Expected: Then `table.get('b1','a1')` が返り値と等しい

- [ ] **T-07-02-04**: 完了後に保留が残らない
  - Target: `SchedulingService.add`
  - Scenario: Given `b1`/`a1` が `OLD` で対応表と予約一覧にある, When `add` する
  - Expected: Then `table.pendingRemovals()` が空である

- [ ] **T-07-02-05**: 4 つの段階が DB 先・追加・削除・DB 完了の順で呼ばれる
  - Target: `SchedulingService.add`
  - Scenario: Given `b1`/`a1` が `OLD` で対応表と予約一覧にある, When `add` する
  - Expected: Then 呼び出し順が `table.replace` → `scheduler.add(ADD1)` → `scheduler.remove(OLD, 'kallr')` → `table.completeRemoval` である

#### T-07-03: Given: 同じ at と title での再 add (SCH-E-09)

- [ ] **T-07-03-01**: 内容が同じでも置換になり新しい Tag になる
  - Target: `SchedulingService.add`
  - Scenario: Given `b1`/`a1` が `OLD`・at `A1`・title `t1` で対応表と予約一覧にある, When 同じ at `A1` と title `t1` で `add` する
  - Expected: Then 返り値の tag が `ADD1` で、`scheduler.list('kallr')` が `ADD1` の 1 件だけを返す

#### T-07-04: Given: 対応表に項目があり、その Tag が予約一覧に無い (発火後。SCH-R-006, SCH-E-08, REQ-F-006)

- [ ] **T-07-04-01**: 新しい MappingRecord を返す
  - Target: `SchedulingService.add`
  - Scenario: Given `b1`/`a1` が `OLD` で対応表にだけある (予約一覧は空), When `add` する
  - Expected: Then tag `ADD1` の `MappingRecord` を返す

- [ ] **T-07-04-02**: 対応表の項目が新しい内容で上書きされる
  - Target: `SchedulingService.add`
  - Scenario: Given `b1`/`a1` が `OLD` で対応表にだけある, When at `A1`・title `t2` で `add` する
  - Expected: Then `table.get('b1','a1')` が tag `ADD1`、title `t2`、registeredAt `2026-11-22T10:00:00` である

- [ ] **T-07-04-03**: 置換の手順を行わない
  - Target: `SchedulingService.add`
  - Scenario: Given `b1`/`a1` が `OLD` で対応表にだけある, When `add` する
  - Expected: Then `table.replace` と `scheduler.remove` が 1 回も呼ばれない

- [ ] **T-07-04-04**: 予約一覧に新しい予約だけがある
  - Target: `SchedulingService.add`
  - Scenario: Given `b1`/`a1` が `OLD` で対応表にだけある, When `add` する
  - Expected: Then `scheduler.list('kallr')` が tag `ADD1` の 1 件だけを返す

#### T-07-05: Given: 段階 2 の前で止まった保留 (P2) があり、別のキーで add する (SCH-R-036, DR-07 再開)

- [ ] **T-07-05-01**: 置換後の予約が OS に追加される
  - Target: `SchedulingService.add`
  - Scenario: Given P2 の状態, When `b2`/`a2` で `add` する
  - Expected: Then `scheduler.add` が tag `PND`、group `kallr`、at `2026-11-22T13:00:00+09:00`、title `再開後` で呼ばれる

- [ ] **T-07-05-02**: 置換前の予約が OS から削除される
  - Target: `SchedulingService.add`
  - Scenario: Given P2 の状態, When `b2`/`a2` で `add` する
  - Expected: Then `scheduler.remove('OLD', 'kallr')` が呼ばれる

- [ ] **T-07-05-03**: 保留が完了して残らない
  - Target: `SchedulingService.add`
  - Scenario: Given P2 の状態, When `b2`/`a2` で `add` する
  - Expected: Then `table.pendingRemovals()` が空で、`table.get('b1','a1')` が tag `PND` の MappingRecord を返す

- [ ] **T-07-05-04**: 保留の処理が、add の分類と追加より先である
  - Target: `SchedulingService.add`
  - Scenario: Given P2 の状態, When `b2`/`a2` で `add` する
  - Expected: Then 呼び出し順が `scheduler.add(PND)` → `scheduler.remove(OLD)` → `table.completeRemoval` → `scheduler.add(ADD1)` である

#### T-07-06: Given: 段階 3 の前で止まった保留 (P3。両方が残る) があり、別のキーで add する (SCH-R-036, DR-07 再開)

- [ ] **T-07-06-01**: 置換後の Tag が予約一覧に既にあるので追加しない
  - Target: `SchedulingService.add`
  - Scenario: Given P3 の状態, When `b2`/`a2` で `add` する
  - Expected: Then tag `PND` での `scheduler.add` が 1 回も呼ばれない

- [ ] **T-07-06-02**: 置換前の予約が OS から削除される
  - Target: `SchedulingService.add`
  - Scenario: Given P3 の状態, When `b2`/`a2` で `add` する
  - Expected: Then `scheduler.remove('OLD', 'kallr')` が呼ばれる

- [ ] **T-07-06-03**: 保留が完了して残らない
  - Target: `SchedulingService.add`
  - Scenario: Given P3 の状態, When `b2`/`a2` で `add` する
  - Expected: Then `table.pendingRemovals()` が空である

#### T-07-07: Given: 段階 4 の前で止まった保留 (P4。置換後の予約だけが残る) があり、別のキーで add する (SCH-R-036, SCH-R-030, DR-07 再開)

- [ ] **T-07-07-01**: 置換前の予約が既に無くても例外を投げない
  - Target: `SchedulingService.add`
  - Scenario: Given P4 の状態 (`scheduler.remove('OLD')` が false を返す), When `b2`/`a2` で `add` する
  - Expected: Then 例外を投げずに `MappingRecord` を返す

- [ ] **T-07-07-02**: 保留が完了して残らない
  - Target: `SchedulingService.add`
  - Scenario: Given P4 の状態, When `b2`/`a2` で `add` する
  - Expected: Then `table.completeRemoval` が呼ばれ、`table.pendingRemovals()` が空である

#### T-07-08: Given: 対応表に項目があり予約もある同じキーを cancel する (SCH-R-014, REQ-F-004)

- [ ] **T-07-08-01**: 予約一覧からその Tag が消える
  - Target: `SchedulingService.cancel`
  - Scenario: Given `b1`/`a1` が `OLD` で対応表と予約一覧にある, When `cancel(batchId: 'b1', alarmId: 'a1')` を呼ぶ
  - Expected: Then `scheduler.list('kallr')` が `OLD` を含まない

- [ ] **T-07-08-02**: 対応表から項目が消える
  - Target: `SchedulingService.cancel`
  - Scenario: Given `b1`/`a1` が `OLD` で対応表と予約一覧にある, When `cancel` を呼ぶ
  - Expected: Then `table.get('b1','a1')` が null を返す

- [ ] **T-07-08-03**: 予約の削除が対応表の削除より先である
  - Target: `SchedulingService.cancel`
  - Scenario: Given `b1`/`a1` が `OLD` で対応表と予約一覧にある, When `cancel` を呼ぶ
  - Expected: Then 呼び出し順が `scheduler.remove('OLD','kallr')` → `table.remove('b1','a1')` である (SCH-DD-07)

#### T-07-09: Given: 保留 (P3) があるキーを cancel する (SCH-R-036)

- [ ] **T-07-09-01**: 置換前と置換後の両方の予約が消える
  - Target: `SchedulingService.cancel`
  - Scenario: Given P3 の状態, When `cancel('b1','a1')` を呼ぶ
  - Expected: Then `scheduler.list('kallr')` が空である

- [ ] **T-07-09-02**: 対応表の項目が消え、保留も残らない
  - Target: `SchedulingService.cancel`
  - Scenario: Given P3 の状態, When `cancel('b1','a1')` を呼ぶ
  - Expected: Then `table.get('b1','a1')` が null で、`table.pendingRemovals()` が空である

- [ ] **T-07-09-03**: 保留の処理 → 読み直し → 予約の削除 → 行の削除の順で動く
  - Target: `SchedulingService.cancel`
  - Scenario: Given P3 の状態, When `cancel('b1','a1')` を呼ぶ
  - Expected: Then 呼び出し順が `scheduler.remove(OLD)` → `table.completeRemoval` → `scheduler.remove(PND)` → `table.remove('b1','a1')` である

#### T-07-10: Given: Tag が対応表と予約一覧の両方にある (SCH-R-017)

- [ ] **T-07-10-01**: 状態は ok になる
  - Target: `SchedulingService.list`
  - Scenario: Given `b1`/`a1` の `OLD` が対応表と予約一覧の両方にある, When `list()` を呼ぶ
  - Expected: Then 1 件の `ScheduleEntry` の `state` が `EntryState.ok` である

- [ ] **T-07-10-02**: ok の要素は項目と予約の両方を持つ
  - Target: `SchedulingService.list`
  - Scenario: Given `b1`/`a1` の `OLD` が対応表と予約一覧の両方にある, When `list()` を呼ぶ
  - Expected: Then その要素の `record` と `toast` がどちらも null でない

#### T-07-11: Given: Tag が対応表にだけある (SCH-R-019)

- [ ] **T-07-11-01**: 状態は stale になる
  - Target: `SchedulingService.list`
  - Scenario: Given `b1`/`a1` の `OLD` が対応表にだけある, When `list()` を呼ぶ
  - Expected: Then 1 件の `state` が `EntryState.stale` である

- [ ] **T-07-11-02**: stale の要素は予約を持たない
  - Target: `SchedulingService.list`
  - Scenario: Given `b1`/`a1` の `OLD` が対応表にだけある, When `list()` を呼ぶ
  - Expected: Then その要素の `toast` が null で、`record` が `OLD` の項目である

#### T-07-12: Given: Tag が予約一覧にだけある (孤立した予約。SCH-R-018, SCH-E-30)

- [ ] **T-07-12-01**: 状態は orphan になる
  - Target: `SchedulingService.list`
  - Scenario: Given `OLD` が予約一覧にだけある, When `list()` を呼ぶ
  - Expected: Then 1 件の `state` が `EntryState.orphan` である

- [ ] **T-07-12-02**: orphan の要素は項目を持たない
  - Target: `SchedulingService.list`
  - Scenario: Given `OLD` が予約一覧にだけある, When `list()` を呼ぶ
  - Expected: Then その要素の `record` が null で、`toast` が `OLD` の予約である

#### T-07-13: Given: 複数の項目と複数の孤立した予約がある (並び。impl §3.3 list)

- [ ] **T-07-13-01**: 項目は (batchId, alarmId) の順に並ぶ
  - Target: `SchedulingService.list`
  - Scenario: Given 対応表に `b1`/`a2` と `b1`/`a1` を `a2` が先になる順で入れ、予約一覧にも両方ある, When `list()` を呼ぶ
  - Expected: Then 要素が `b1`/`a1`、`b1`/`a2` の順に並ぶ

- [ ] **T-07-13-02**: orphan は項目の後に Tag 順で並ぶ
  - Target: `SchedulingService.list`
  - Scenario: Given 対応表に `b1`/`a1` があり、予約一覧にだけ Tag `ZZ...` と `AA...` がある, When `list()` を呼ぶ
  - Expected: Then 並びが `b1`/`a1` (ok)、Tag `AA...` (orphan)、Tag `ZZ...` (orphan) である

#### T-07-14: Given: Tag が予約一覧に無く、通知時刻が now より後の項目を再登録する (SCH-R-021, IDX-DD-13)

- [ ] **T-07-14-01**: registered の一覧に載る
  - Target: `SchedulingService.reRegisterAll`
  - Scenario: Given 対応表に `b1`/`a1` (tag `OLD`、at `A1`、title `t1`) があり予約一覧は空, When `reRegisterAll(aumid: 'Kallr.Test')` を呼ぶ
  - Expected: Then `report.registered` がその項目 1 件で、他の 3 つの一覧が空である

- [ ] **T-07-14-02**: 保存済みの Tag・時刻・title で OS に追加する
  - Target: `SchedulingService.reRegisterAll`
  - Scenario: Given 対応表に `b1`/`a1` (tag `OLD`、at `A1`、title `t1`) があり予約一覧は空, When `reRegisterAll` を呼ぶ
  - Expected: Then `scheduler.add` が tag `OLD` (再生成していない)、group `kallr`、at `A1`、title `t1` で 1 回呼ばれる

- [ ] **T-07-14-03**: 対応表を変えない
  - Target: `SchedulingService.reRegisterAll`
  - Scenario: Given 対応表に `b1`/`a1` (tag `OLD`、at `A1`、title `t1`) があり予約一覧は空, When `reRegisterAll` を呼ぶ
  - Expected: Then `table.all()` が呼び出し前と等しく、`table.put` と `table.replace` が 1 回も呼ばれない

- [ ] **T-07-14-04**: exitCode は 0 である
  - Target: `SchedulingService.reRegisterAll`
  - Scenario: Given 対応表に `b1`/`a1` (tag `OLD`、at `A1`、title `t1`) があり予約一覧は空, When `reRegisterAll` を呼ぶ
  - Expected: Then `report.exitCode` が 0 である

#### T-07-15: Given: Tag が予約一覧に既にある項目を再登録する (SCH-R-023, SCH-E-22)

- [ ] **T-07-15-01**: alreadyPresent の一覧に載る
  - Target: `SchedulingService.reRegisterAll`
  - Scenario: Given `b1`/`a1` の `OLD` が対応表と予約一覧の両方にある, When `reRegisterAll` を呼ぶ
  - Expected: Then `report.alreadyPresent` がその項目 1 件で、他の 3 つの一覧が空である

- [ ] **T-07-15-02**: 重複を作らない
  - Target: `SchedulingService.reRegisterAll`
  - Scenario: Given `b1`/`a1` の `OLD` が対応表と予約一覧の両方にある, When `reRegisterAll` を呼ぶ
  - Expected: Then `scheduler.add` が 1 回も呼ばれない

#### T-07-16: Given: Tag が予約一覧に無く、通知時刻が now より前の項目を再登録する (SCH-R-022, SCH-E-21, SCH-DD-08)

- [ ] **T-07-16-01**: skippedPast の一覧に載る
  - Target: `SchedulingService.reRegisterAll`
  - Scenario: Given 対応表に `b1`/`a1` (tag `OLD`、at `2026-11-22T09:00:00+09:00`) があり予約一覧は空, When `reRegisterAll` を呼ぶ
  - Expected: Then `report.skippedPast` がその項目 1 件である

- [ ] **T-07-16-02**: OS に追加しない
  - Target: `SchedulingService.reRegisterAll`
  - Scenario: Given 対応表に `b1`/`a1` (tag `OLD`、at `2026-11-22T09:00:00+09:00`) があり予約一覧は空, When `reRegisterAll` を呼ぶ
  - Expected: Then `scheduler.add` が 1 回も呼ばれない

- [ ] **T-07-16-03**: 過去のため登録しないことは失敗ではない
  - Target: `SchedulingService.reRegisterAll`
  - Scenario: Given 対応表に `b1`/`a1` (tag `OLD`、at `2026-11-22T09:00:00+09:00`) があり予約一覧は空, When `reRegisterAll` を呼ぶ
  - Expected: Then `report.exitCode` が 0 である

#### T-07-17: Given: 保留 (P3) があるときに再登録する (SCH-R-036)

- [ ] **T-07-17-01**: 置換前の予約が OS から削除される
  - Target: `SchedulingService.reRegisterAll`
  - Scenario: Given P3 の状態, When `reRegisterAll` を呼ぶ
  - Expected: Then `scheduler.remove('OLD', 'kallr')` が呼ばれる

- [ ] **T-07-17-02**: 保留が完了して残らない
  - Target: `SchedulingService.reRegisterAll`
  - Scenario: Given P3 の状態, When `reRegisterAll` を呼ぶ
  - Expected: Then `table.pendingRemovals()` が空である

### [異常] Error Cases

#### T-07-18: Given: 通知可否の確認が「通知できる」でない (SCH-R-003, SCH-E-06, IDX-R-001)

- [ ] **T-07-18-01**: UnavailableException を投げる
  - Target: `SchedulingService.add`
  - Scenario: Given `env.check` が `ok = false` で理由 `AUMID が未登録` を返す, When `add` を呼ぶ
  - Expected: Then `UnavailableException` を投げ、その `availability` が `env.check` の返した値である

- [ ] **T-07-18-02**: OS の予約を一切呼ばない
  - Target: `SchedulingService.add`
  - Scenario: Given `env.check` が `ok = false` を返す, When `add` を呼ぶ
  - Expected: Then `scheduler` の `add`・`remove`・`list` が 1 回も呼ばれない

- [ ] **T-07-18-03**: 対応表を一切呼ばない
  - Target: `SchedulingService.add`
  - Scenario: Given `env.check` が `ok = false` を返す, When `add` を呼ぶ
  - Expected: Then `table` の `get`・`put`・`replace` が 1 回も呼ばれない

- [ ] **T-07-18-04**: 保留の再開もしない
  - Target: `SchedulingService.add`
  - Scenario: Given `env.check` が `ok = false` を返し、P3 の状態である, When `add` を呼ぶ
  - Expected: Then `table.pendingRemovals()` が 1 件のままで、`scheduler.list('kallr')` が `OLD` と `PND` の両方を持つ

#### T-07-19: Given: 過去の at を OS が拒否する新規 add (SCH-E-04, SCH-DD-05)

- [ ] **T-07-19-01**: ScheduleException を 0x80070057 で投げる
  - Target: `SchedulingService.add`
  - Scenario: Given `scheduler.add` が `ScheduleException(0x80070057)` を投げる設定, When 新規の `add` を呼ぶ
  - Expected: Then `hresult` が `0x80070057` の `ScheduleException` を投げる

- [ ] **T-07-19-02**: 対応表を変えない
  - Target: `SchedulingService.add`
  - Scenario: Given `scheduler.add` が `ScheduleException(0x80070057)` を投げる設定, When 新規の `add` を呼んで失敗した
  - Expected: Then `table.get('b1','a1')` が null で、`table.put` が 1 回も呼ばれない

#### T-07-20: Given: 予約件数の上限超過を OS が拒否する新規 add (SCH-E-16)

- [ ] **T-07-20-01**: ScheduleException を 0x80070718 で投げる
  - Target: `SchedulingService.add`
  - Scenario: Given `scheduler.add` が `ScheduleException(0x80070718)` を投げる設定, When 新規の `add` を呼ぶ
  - Expected: Then `hresult` が `0x80070718` の `ScheduleException` を投げる

#### T-07-21: Given: 新規の予約の追加後に対応表の書き込みが失敗する (SCH-E-14, SCH-R-010)

- [ ] **T-07-21-01**: StorageException をそのまま伝える
  - Target: `SchedulingService.add`
  - Scenario: Given `table.put` が `StorageException` を投げる設定, When 新規の `add` を呼ぶ
  - Expected: Then `StorageException` を投げる

- [ ] **T-07-21-02**: 追加した予約は巻き戻さず残る
  - Target: `SchedulingService.add`
  - Scenario: Given `table.put` が `StorageException` を投げる設定, When 新規の `add` を呼んで失敗した
  - Expected: Then `scheduler.list('kallr')` が tag `ADD1` の 1 件を持ち、`scheduler.remove` が 1 回も呼ばれない

- [ ] **T-07-21-03**: 対応表には項目が無い
  - Target: `SchedulingService.add`
  - Scenario: Given `table.put` が `StorageException` を投げる設定, When 新規の `add` を呼んで失敗した
  - Expected: Then `table.get('b1','a1')` が null である

- [ ] **T-07-21-04**: 続く list が孤立した予約として検出する
  - Target: `SchedulingService.list`
  - Scenario: Given 上の失敗の後 (予約一覧に `ADD1` だけがある), When `list()` を呼ぶ
  - Expected: Then tag `ADD1` の要素の `state` が `EntryState.orphan` である

#### T-07-22: Given: Tag の重複が上限の後も続く (SCH-R-007, SCH-E-15, SCH-DD-10)

- [ ] **T-07-22-01**: DuplicateTagException を投げる
  - Target: `SchedulingService.add`
  - Scenario: Given `random` が常に `0123456789abcdef` を返し、その Tag `ADD1` が対応表の `b9`/`a9` に既にある, When `add` を呼ぶ
  - Expected: Then `DuplicateTagException` を投げる

- [ ] **T-07-22-02**: 予約を作らない
  - Target: `SchedulingService.add`
  - Scenario: Given `random` が常に同じ値を返し、その Tag が既にある, When `add` を呼んで失敗した
  - Expected: Then `scheduler.add` が 1 回も呼ばれない

- [ ] **T-07-22-03**: 対応表を変えない
  - Target: `SchedulingService.add`
  - Scenario: Given `random` が常に同じ値を返し、その Tag が既にある, When `add` を呼んで失敗した
  - Expected: Then `table.put` と `table.replace` が 1 回も呼ばれない

#### T-07-23: Given: 置換の段階 1 (DB への記録) が失敗する (SCH-E-11, 3.5 段階 1 の失敗)

- [ ] **T-07-23-01**: StorageException をそのまま伝える
  - Target: `SchedulingService.add`
  - Scenario: Given `b1`/`a1` が `OLD` で対応表と予約一覧にあり、`table.replace` が `StorageException` を投げる設定, When `add` を呼ぶ
  - Expected: Then `StorageException` を投げる

- [ ] **T-07-23-02**: OS の予約に触れない
  - Target: `SchedulingService.add`
  - Scenario: Given 同上, When `add` を呼んで失敗した
  - Expected: Then `scheduler.add` と `scheduler.remove` が 1 回も呼ばれない

- [ ] **T-07-23-03**: 置換前の予約だけが残る
  - Target: `SchedulingService.add`
  - Scenario: Given 同上, When `add` を呼んで失敗した
  - Expected: Then `scheduler.list('kallr')` が `OLD` の 1 件だけを返す

- [ ] **T-07-23-04**: 対応表は置換前の行が current のまま変わらない
  - Target: `SchedulingService.add`
  - Scenario: Given 同上, When `add` を呼んで失敗した
  - Expected: Then `table.get('b1','a1')` が tag `OLD` の MappingRecord を返す

#### T-07-24: Given: 置換の段階 2 (OS の追加) を OS が拒否する (SCH-E-10, SCH-R-010, 3.5 段階 2 の拒否)

- [ ] **T-07-24-01**: ScheduleException をそのまま伝える
  - Target: `SchedulingService.add`
  - Scenario: Given `b1`/`a1` が `OLD` で対応表と予約一覧にあり、`scheduler.add` が `ScheduleException(0x80070057)` を投げる設定, When `add` を呼ぶ
  - Expected: Then `hresult` が `0x80070057` の `ScheduleException` を投げる

- [ ] **T-07-24-02**: 段階 1 の記録を取り消す
  - Target: `SchedulingService.add`
  - Scenario: Given 同上, When `add` を呼んで失敗した
  - Expected: Then `table.abortReplacement` が `table.replace` の返した queueId で 1 回呼ばれる

- [ ] **T-07-24-03**: 対応表は置換前の行が current に戻る
  - Target: `SchedulingService.add`
  - Scenario: Given 同上, When `add` を呼んで失敗した
  - Expected: Then `table.get('b1','a1')` が tag `OLD` の MappingRecord を返す

- [ ] **T-07-24-04**: 保留が残らない
  - Target: `SchedulingService.add`
  - Scenario: Given 同上, When `add` を呼んで失敗した
  - Expected: Then `table.pendingRemovals()` が空である

- [ ] **T-07-24-05**: 置換前の予約だけが残る
  - Target: `SchedulingService.add`
  - Scenario: Given 同上, When `add` を呼んで失敗した
  - Expected: Then `scheduler.list('kallr')` が `OLD` の 1 件だけを返す

- [ ] **T-07-24-06**: 置換前の予約を削除しない
  - Target: `SchedulingService.add`
  - Scenario: Given 同上, When `add` を呼んで失敗した
  - Expected: Then `scheduler.remove` が 1 回も呼ばれない

#### T-07-25: Given: 置換の段階 3 (置換前の予約の削除) が失敗する (SCH-E-12, 3.5 段階 3 の失敗)

- [ ] **T-07-25-01**: ScheduleException をそのまま伝える
  - Target: `SchedulingService.add`
  - Scenario: Given `b1`/`a1` が `OLD` で対応表と予約一覧にあり、`scheduler.remove` が `ScheduleException` を投げる設定, When `add` を呼ぶ
  - Expected: Then `ScheduleException` を投げる

- [ ] **T-07-25-02**: 両方の予約が残る
  - Target: `SchedulingService.add`
  - Scenario: Given 同上, When `add` を呼んで失敗した
  - Expected: Then `scheduler.list('kallr')` が `OLD` と `ADD1` の 2 件を返す

- [ ] **T-07-25-03**: 保留が置換キューに残る
  - Target: `SchedulingService.add`
  - Scenario: Given 同上, When `add` を呼んで失敗した
  - Expected: Then `table.pendingRemovals()` が 1 件を返す

- [ ] **T-07-25-04**: 段階 4 に進まない
  - Target: `SchedulingService.add`
  - Scenario: Given 同上, When `add` を呼んで失敗した
  - Expected: Then `table.completeRemoval` が 1 回も呼ばれない

- [ ] **T-07-25-05**: 巻き戻さない
  - Target: `SchedulingService.add`
  - Scenario: Given 同上, When `add` を呼んで失敗した
  - Expected: Then `table.abortReplacement` が 1 回も呼ばれない

#### T-07-26: Given: 置換の段階 4 (DB の完了) が失敗する (SCH-E-12, 3.5 段階 4 の失敗)

- [ ] **T-07-26-01**: StorageException をそのまま伝える
  - Target: `SchedulingService.add`
  - Scenario: Given `b1`/`a1` が `OLD` で対応表と予約一覧にあり、`table.completeRemoval` が `StorageException` を投げる設定, When `add` を呼ぶ
  - Expected: Then `StorageException` を投げる

- [ ] **T-07-26-02**: 置換後の予約だけが残る
  - Target: `SchedulingService.add`
  - Scenario: Given 同上, When `add` を呼んで失敗した
  - Expected: Then `scheduler.list('kallr')` が `ADD1` の 1 件だけを返す

- [ ] **T-07-26-03**: 保留が置換キューに残る
  - Target: `SchedulingService.add`
  - Scenario: Given 同上, When `add` を呼んで失敗した
  - Expected: Then `table.pendingRemovals()` が 1 件を返す

#### T-07-27: Given: 対応表に無いキーを cancel する (SCH-R-013, SCH-E-17, SCH-DD-06)

- [ ] **T-07-27-01**: NotFoundException を投げる
  - Target: `SchedulingService.cancel`
  - Scenario: Given 空の対応表, When `cancel('b1','a1')` を呼ぶ
  - Expected: Then `NotFoundException` を投げる

- [ ] **T-07-27-02**: OS の予約を削除しない
  - Target: `SchedulingService.cancel`
  - Scenario: Given 空の対応表, When `cancel('b1','a1')` を呼んで失敗した
  - Expected: Then `scheduler.remove` が 1 回も呼ばれない

- [ ] **T-07-27-03**: 対応表を変えない
  - Target: `SchedulingService.cancel`
  - Scenario: Given 空の対応表, When `cancel('b1','a1')` を呼んで失敗した
  - Expected: Then `table.remove` が 1 回も呼ばれない

#### T-07-28: Given: cancel の予約の削除が失敗する (SCH-R-015)

- [ ] **T-07-28-01**: ScheduleException をそのまま伝える
  - Target: `SchedulingService.cancel`
  - Scenario: Given `b1`/`a1` が `OLD` で対応表と予約一覧にあり、`scheduler.remove` が `ScheduleException` を投げる設定, When `cancel` を呼ぶ
  - Expected: Then `ScheduleException` を投げる

- [ ] **T-07-28-02**: 対応表を変えない
  - Target: `SchedulingService.cancel`
  - Scenario: Given 同上, When `cancel` を呼んで失敗した
  - Expected: Then `table.get('b1','a1')` が tag `OLD` の MappingRecord を返し、`table.remove` が 1 回も呼ばれない

#### T-07-29: Given: cancel の予約の削除後に対応表の削除が失敗する (SCH-E-18, SCH-R-015)

- [ ] **T-07-29-01**: StorageException をそのまま伝える
  - Target: `SchedulingService.cancel`
  - Scenario: Given `b1`/`a1` が `OLD` で対応表と予約一覧にあり、`table.remove` が `StorageException` を投げる設定, When `cancel` を呼ぶ
  - Expected: Then `StorageException` を投げる

- [ ] **T-07-29-02**: 予約は消えている
  - Target: `SchedulingService.cancel`
  - Scenario: Given 同上, When `cancel` を呼んで失敗した
  - Expected: Then `scheduler.list('kallr')` が `OLD` を含まない

- [ ] **T-07-29-03**: 項目だけが対応表に残る
  - Target: `SchedulingService.cancel`
  - Scenario: Given 同上, When `cancel` を呼んで失敗した
  - Expected: Then `table.get('b1','a1')` が tag `OLD` の MappingRecord を返す

- [ ] **T-07-29-04**: 続く list が stale として検出する
  - Target: `SchedulingService.list`
  - Scenario: Given 上の失敗の後 (対応表に `OLD` があり予約一覧は空), When `list()` を呼ぶ
  - Expected: Then tag `OLD` の要素の `state` が `EntryState.stale` である

#### T-07-30: Given: list で OS の予約一覧の取得が失敗する (SCH-R-016)

- [ ] **T-07-30-01**: ScheduleException をそのまま伝える
  - Target: `SchedulingService.list`
  - Scenario: Given `scheduler.list` が `ScheduleException` を投げる設定, When `list()` を呼ぶ
  - Expected: Then `ScheduleException` を投げる

#### T-07-31: Given: list で対応表の全件取得が失敗する (SCH-R-016)

- [ ] **T-07-31-01**: StorageException をそのまま伝える
  - Target: `SchedulingService.list`
  - Scenario: Given `table.all` が `StorageException` を投げる設定, When `list()` を呼ぶ
  - Expected: Then `StorageException` を投げる

#### T-07-32: Given: 再登録で通知可否の確認が「通知できる」でない (SCH-R-034, SCH-E-27, SCH-DD-16, IDX-R-007)

- [ ] **T-07-32-01**: UnavailableException を投げる
  - Target: `SchedulingService.reRegisterAll`
  - Scenario: Given `env.check` が `ok = false` を返し、対応表に再登録できる項目が 1 件ある, When `reRegisterAll` を呼ぶ
  - Expected: Then `UnavailableException` を投げる

- [ ] **T-07-32-02**: 何も登録しない
  - Target: `SchedulingService.reRegisterAll`
  - Scenario: Given `env.check` が `ok = false` を返し、対応表に再登録できる項目が 1 件ある, When `reRegisterAll` を呼んで失敗した
  - Expected: Then `scheduler.add` が 1 回も呼ばれない

#### T-07-33: Given: 再登録で 1 件の追加が OS のエラーで失敗する (SCH-R-035, SCH-E-28)

- [ ] **T-07-33-01**: 失敗した項目が理由とともに failed の一覧に載る
  - Target: `SchedulingService.reRegisterAll`
  - Scenario: Given 対応表の `b1`/`a1` の追加で `scheduler.add` が `ScheduleException(0x80070057)` を投げる設定, When `reRegisterAll` を呼ぶ
  - Expected: Then `report.failed` が `b1`/`a1` の項目と空でない理由の 1 件である

- [ ] **T-07-33-02**: exitCode は 2 である
  - Target: `SchedulingService.reRegisterAll`
  - Scenario: Given 同上, When `reRegisterAll` を呼ぶ
  - Expected: Then `report.exitCode` が 2 である

- [ ] **T-07-33-03**: 失敗した項目は registered に載らない
  - Target: `SchedulingService.reRegisterAll`
  - Scenario: Given 同上, When `reRegisterAll` を呼ぶ
  - Expected: Then `report.registered` が空である

- [ ] **T-07-33-04**: 失敗しても対応表を変えない
  - Target: `SchedulingService.reRegisterAll`
  - Scenario: Given 同上, When `reRegisterAll` を呼ぶ
  - Expected: Then `table.all()` が呼び出し前と等しい

#### T-07-34: Given: add の保留の再開 (P2) で、置換後の予約の追加を OS が拒否する (SCH-R-036, SCH-R-010)

- [ ] **T-07-34-01**: 置換前の行が current に戻る
  - Target: `SchedulingService.add`
  - Scenario: Given P2 の状態で `scheduler.add` が `ScheduleException(0x80070057)` を投げる設定 (PND の at は now より後), When `b2`/`a2` で `add` を呼ぶ
  - Expected: Then `table.get('b1','a1')` が tag `OLD` の MappingRecord を返す

- [ ] **T-07-34-02**: 保留が残らない
  - Target: `SchedulingService.add`
  - Scenario: Given 同上, When `add` を呼ぶ
  - Expected: Then `table.abortReplacement` が呼ばれ、`table.pendingRemovals()` が空である

- [ ] **T-07-34-03**: 拒否された置換後の予約は予約一覧に無い
  - Target: `SchedulingService.add`
  - Scenario: Given 同上, When `add` を呼ぶ
  - Expected: Then `scheduler.list('kallr')` が `PND` を含まない

#### T-07-35: Given: add の保留の再開 (P3) で、置換前の予約の削除が失敗する (SCH-R-036)

- [ ] **T-07-35-01**: ScheduleException をそのまま伝える
  - Target: `SchedulingService.add`
  - Scenario: Given P3 の状態で `scheduler.remove` が `ScheduleException` を投げる設定, When `b2`/`a2` で `add` を呼ぶ
  - Expected: Then `ScheduleException` を投げる

- [ ] **T-07-35-02**: 保留が残る
  - Target: `SchedulingService.add`
  - Scenario: Given 同上, When `add` を呼んで失敗した
  - Expected: Then `table.pendingRemovals()` が 1 件を返す

- [ ] **T-07-35-03**: 要求された add の追加に進まない
  - Target: `SchedulingService.add`
  - Scenario: Given 同上, When `add` を呼んで失敗した
  - Expected: Then tag `ADD1` での `scheduler.add` が 1 回も呼ばれない

#### T-07-36: Given: add の保留の再開 (P4) で、DB の完了が失敗する (SCH-R-036)

- [ ] **T-07-36-01**: StorageException をそのまま伝える
  - Target: `SchedulingService.add`
  - Scenario: Given P4 の状態で `table.completeRemoval` が `StorageException` を投げる設定, When `b2`/`a2` で `add` を呼ぶ
  - Expected: Then `StorageException` を投げる

- [ ] **T-07-36-02**: 保留が残る
  - Target: `SchedulingService.add`
  - Scenario: Given 同上, When `add` を呼んで失敗した
  - Expected: Then `table.pendingRemovals()` が 1 件を返す

### [エッジケース] Edge Cases

#### T-07-37: Given: 生成した Tag が予約一覧にだけある Tag と重複する (SCH-R-007, TAG 重複の確認先)

- [ ] **T-07-37-01**: 乱数を再生成した Tag を使う
  - Target: `SchedulingService.add`
  - Scenario: Given 予約一覧にだけ `ADD1` の予約 (別キー `b9`/`a9`、対応表に無い) があり、`random` が `0123456789abcdef`、次に `fedcba9876543210` を返す, When `b1`/`a1` を `add` する
  - Expected: Then 返り値の tag が `ADD2` である

#### T-07-38: Given: 生成した Tag が対応表にだけある (発火済み) Tag と重複する (SCH-E-32, D8)

- [ ] **T-07-38-01**: 乱数を再生成した Tag を使う
  - Target: `SchedulingService.add`
  - Scenario: Given 対応表の `b9`/`a9` に `ADD1` があり予約一覧は空で、`random` が `0123456789abcdef`、次に `fedcba9876543210` を返す, When `b1`/`a1` を `add` する
  - Expected: Then 返り値の tag が `ADD2` である

#### T-07-39: Given: UTF-8 の title (SCH-E-23, REQ-NF-004)

- [ ] **T-07-39-01**: OS の追加に title をそのまま渡す
  - Target: `SchedulingService.add`
  - Scenario: Given title が `会議の開始`, When `add` する
  - Expected: Then `scheduler.add` の title が `会議の開始` で呼ばれる

- [ ] **T-07-39-02**: 返り値の title も同じである
  - Target: `SchedulingService.add`
  - Scenario: Given title が `会議の開始`, When `add` する
  - Expected: Then 返り値の title が `会議の開始` である

#### T-07-40: Given: 置換の途中で置換前の予約が発火済みになる (SCH-E-13, SCH-R-030, SCH-DD-13)

- [ ] **T-07-40-01**: 例外を投げず MappingRecord を返す
  - Target: `SchedulingService.add`
  - Scenario: Given `b1`/`a1` が `OLD` で対応表と予約一覧にあり、`scheduler.remove('OLD')` が false を返す設定, When `add` を呼ぶ
  - Expected: Then 例外を投げず tag `ADD1` の MappingRecord を返す

- [ ] **T-07-40-02**: 段階 4 まで完了する
  - Target: `SchedulingService.add`
  - Scenario: Given 同上, When `add` を呼ぶ
  - Expected: Then `table.completeRemoval` が呼ばれ、`table.pendingRemovals()` が空である

- [ ] **T-07-40-03**: 置換後の予約だけが残る
  - Target: `SchedulingService.add`
  - Scenario: Given 同上, When `add` を呼ぶ
  - Expected: Then `scheduler.list('kallr')` が `ADD1` の 1 件だけを返す

#### T-07-41: Given: 再開のとき、置換後の通知時刻が now より前 (P2。SCH-R-036, 3.5)

> PND の at を `2026-11-22T09:59:59+09:00` (now の 1 秒前) とする。

- [ ] **T-07-41-01**: 置換後の予約を追加しない
  - Target: `SchedulingService.add`
  - Scenario: Given P2 の状態で PND の at が now の 1 秒前, When `b2`/`a2` で `add` を呼ぶ
  - Expected: Then tag `PND` での `scheduler.add` が 1 回も呼ばれない

- [ ] **T-07-41-02**: 置換前の予約を削除する
  - Target: `SchedulingService.add`
  - Scenario: Given 同上, When `add` を呼ぶ
  - Expected: Then `scheduler.remove('OLD', 'kallr')` が呼ばれる

- [ ] **T-07-41-03**: 置換前の行へ戻さず置換後の行を current にする
  - Target: `SchedulingService.add`
  - Scenario: Given 同上, When `add` を呼ぶ
  - Expected: Then `table.abortReplacement` が呼ばれず、`table.get('b1','a1')` が tag `PND` の MappingRecord を返す

- [ ] **T-07-41-04**: 保留が完了して残らない
  - Target: `SchedulingService.add`
  - Scenario: Given 同上, When `add` を呼ぶ
  - Expected: Then `table.pendingRemovals()` が空である

#### T-07-42: Given: 再開のとき、置換後の通知時刻が now と同じ (境界。P2)

- [ ] **T-07-42-01**: now と同じ時刻は過去として扱い追加しない
  - Target: `SchedulingService.add`
  - Scenario: Given P2 の状態で PND の at が `2026-11-22T10:00:00` (now と同じ), When `b2`/`a2` で `add` を呼ぶ
  - Expected: Then tag `PND` での `scheduler.add` が 1 回も呼ばれない

- [ ] **T-07-42-02**: 保留が完了して残らない
  - Target: `SchedulingService.add`
  - Scenario: Given P2 の状態で PND の at が `2026-11-22T10:00:00` (now と同じ), When `b2`/`a2` で `add` を呼ぶ
  - Expected: Then `table.pendingRemovals()` が空である

#### T-07-43: Given: 再開のとき、置換後の通知時刻が now の 1 秒後 (境界。P2)

- [ ] **T-07-43-01**: now より後の時刻は追加する
  - Target: `SchedulingService.add`
  - Scenario: Given P2 の状態で PND の at が `2026-11-22T10:00:01` (now の 1 秒後), When `b2`/`a2` で `add` を呼ぶ
  - Expected: Then tag `PND` での `scheduler.add` が 1 回呼ばれる

#### T-07-44: Given: 保留 (P3) があるキーと同じキーで add する (SCH-R-036)

- [ ] **T-07-44-01**: 保留を処理してから新しい置換を行い、予約が 1 件になる
  - Target: `SchedulingService.add`
  - Scenario: Given P3 の状態, When 同じ `b1`/`a1` で `add` する
  - Expected: Then `scheduler.list('kallr')` が tag `ADD1` の 1 件だけを返す

- [ ] **T-07-44-02**: 保留が残らない
  - Target: `SchedulingService.add`
  - Scenario: Given P3 の状態, When 同じ `b1`/`a1` で `add` する
  - Expected: Then `table.pendingRemovals()` が空である

#### T-07-45: Given: cancel で項目はあるが予約が発火済み (SCH-E-19, SCH-R-030, SCH-DD-13)

- [ ] **T-07-45-01**: 例外を投げずに完了する
  - Target: `SchedulingService.cancel`
  - Scenario: Given `b1`/`a1` が `OLD` で対応表にだけある (`scheduler.remove` が false を返す), When `cancel` を呼ぶ
  - Expected: Then 例外を投げない

- [ ] **T-07-45-02**: 対応表の項目を削除する
  - Target: `SchedulingService.cancel`
  - Scenario: Given 同上, When `cancel` を呼ぶ
  - Expected: Then `table.get('b1','a1')` が null を返す

#### T-07-46: Given: 別のキーの項目と予約がある状態で cancel する

- [ ] **T-07-46-01**: 別のキーの項目と予約は変わらない
  - Target: `SchedulingService.cancel`
  - Scenario: Given `b1`/`a1` (`OLD`) と `b2`/`a2` (`PND`) が対応表と予約一覧の両方にある, When `cancel('b1','a1')` を呼ぶ
  - Expected: Then `table.get('b2','a2')` が tag `PND` を返し、`scheduler.list('kallr')` が `PND` だけを返す

#### T-07-47: Given: 通知可否の確認が「通知できる」でない状態で cancel する (specifications-schedule.md 3.2)

- [ ] **T-07-47-01**: 通知可否の確認を呼ばない
  - Target: `SchedulingService.cancel`
  - Scenario: Given `env.check` が `ok = false` を返し、`b1`/`a1` が対応表と予約一覧にある, When `cancel` を呼ぶ
  - Expected: Then `env.check` が 1 回も呼ばれない

- [ ] **T-07-47-02**: UnavailableException を投げず完了する
  - Target: `SchedulingService.cancel`
  - Scenario: Given `env.check` が `ok = false` を返し、`b1`/`a1` が対応表と予約一覧にある, When `cancel` を呼ぶ
  - Expected: Then 例外を投げず、`table.get('b1','a1')` が null を返す

#### T-07-48: Given: cancel の保留の再開 (P2) で置換後の予約の追加を OS が拒否する (SCH-R-036, SCH-R-010)

- [ ] **T-07-48-01**: 読み直した旧行の Tag の予約を削除する
  - Target: `SchedulingService.cancel`
  - Scenario: Given P2 の状態で `scheduler.add` が `ScheduleException(0x80070057)` を投げる設定 (PND の at は now より後), When `cancel('b1','a1')` を呼ぶ
  - Expected: Then `scheduler.remove` が `PND` ではなく `OLD` で呼ばれる

- [ ] **T-07-48-02**: 対応表の項目を削除する
  - Target: `SchedulingService.cancel`
  - Scenario: Given 同上, When `cancel('b1','a1')` を呼ぶ
  - Expected: Then `table.get('b1','a1')` が null を返す

#### T-07-49: Given: 対応表も予約一覧も空

- [ ] **T-07-49-01**: list は空のリストを返す
  - Target: `SchedulingService.list`
  - Scenario: Given 対応表も予約一覧も空, When `list()` を呼ぶ
  - Expected: Then 空のリストを返す

#### T-07-50: Given: list の予約一覧の取得対象 (2.2)

- [ ] **T-07-50-01**: Group を kallr に固定して予約一覧を取得する
  - Target: `SchedulingService.list`
  - Scenario: Given 通常の状態, When `list()` を呼ぶ
  - Expected: Then `scheduler.list` が引数 `'kallr'` で呼ばれる

#### T-07-51: Given: 孤立した予約がある状態で list する (SCH-R-033, SCH-DD-15)

- [ ] **T-07-51-01**: OS の予約を変更しない
  - Target: `SchedulingService.list`
  - Scenario: Given 予約一覧にだけ `OLD` の予約がある, When `list()` を呼ぶ
  - Expected: Then `scheduler.remove` と `scheduler.add` が 1 回も呼ばれず、`scheduler.list('kallr')` が `OLD` を持つ

- [ ] **T-07-51-02**: 対応表を変更しない
  - Target: `SchedulingService.list`
  - Scenario: Given 予約一覧にだけ `OLD` の予約がある, When `list()` を呼ぶ
  - Expected: Then `table.put`・`table.replace`・`table.remove` が 1 回も呼ばれない

#### T-07-52: Given: 通知可否の確認が「通知できる」でない状態で list する (specifications-schedule.md 3.2)

- [ ] **T-07-52-01**: 通知可否の確認を呼ばず完了する
  - Target: `SchedulingService.list`
  - Scenario: Given `env.check` が `ok = false` を返す, When `list()` を呼ぶ
  - Expected: Then `env.check` が 1 回も呼ばれず、例外を投げない

#### T-07-53: Given: 再登録で通知時刻が now と同じ項目 (境界。SCH-R-022)

- [ ] **T-07-53-01**: now と同じ時刻は skippedPast に載る
  - Target: `SchedulingService.reRegisterAll`
  - Scenario: Given 対応表に at が `2026-11-22T10:00:00` (now と同じ) の項目があり予約一覧は空, When `reRegisterAll` を呼ぶ
  - Expected: Then `report.skippedPast` がその項目 1 件で、`scheduler.add` が 1 回も呼ばれない

#### T-07-54: Given: 再登録で通知時刻が now の 1 秒後の項目 (境界。SCH-R-021)

- [ ] **T-07-54-01**: now の 1 秒後は registered に載る
  - Target: `SchedulingService.reRegisterAll`
  - Scenario: Given 対応表に at が `2026-11-22T10:00:01` (now の 1 秒後) の項目があり予約一覧は空, When `reRegisterAll` を呼ぶ
  - Expected: Then `report.registered` がその項目 1 件である

#### T-07-55: Given: 4 種類の項目が混在し、失敗した項目の後にも項目がある (SCH-R-024, SCH-R-035, SCH-E-28, SCH-E-29)

> 対応表: R1 (未来・予約なし)、R2 (過去・予約なし)、R3 (予約あり)、R4 (未来・予約なし。`scheduler.add` が `ScheduleException(0x80070057)` を投げる)、R5 (未来・予約なし)。処理順は R1 → R5。

- [ ] **T-07-55-01**: registered は失敗の後の項目を含む
  - Target: `SchedulingService.reRegisterAll`
  - Scenario: Given R1〜R5 が上の状態, When `reRegisterAll` を呼ぶ
  - Expected: Then `report.registered` が R1 と R5 である (R4 の失敗で処理を止めない)

- [ ] **T-07-55-02**: failed は R4 だけである
  - Target: `SchedulingService.reRegisterAll`
  - Scenario: Given R1〜R5 が上の状態, When `reRegisterAll` を呼ぶ
  - Expected: Then `report.failed` が R4 の 1 件である

- [ ] **T-07-55-03**: skippedPast は R2 だけである
  - Target: `SchedulingService.reRegisterAll`
  - Scenario: Given R1〜R5 が上の状態, When `reRegisterAll` を呼ぶ
  - Expected: Then `report.skippedPast` が R2 の 1 件である

- [ ] **T-07-55-04**: alreadyPresent は R3 だけである
  - Target: `SchedulingService.reRegisterAll`
  - Scenario: Given R1〜R5 が上の状態, When `reRegisterAll` を呼ぶ
  - Expected: Then `report.alreadyPresent` が R3 の 1 件である

- [ ] **T-07-55-05**: 失敗が 1 件でもあれば exitCode は 2 である
  - Target: `SchedulingService.reRegisterAll`
  - Scenario: Given R1〜R5 が上の状態, When `reRegisterAll` を呼ぶ
  - Expected: Then `report.exitCode` が 2 である

#### T-07-56: Given: 対応表が空

- [ ] **T-07-56-01**: 4 つの一覧がすべて空で exitCode は 0 である
  - Target: `SchedulingService.reRegisterAll`
  - Scenario: Given 対応表が空, When `reRegisterAll` を呼ぶ
  - Expected: Then `registered`・`failed`・`skippedPast`・`alreadyPresent` がすべて空で、`exitCode` が 0 である

---

## Coverage Check

### 除外 (別ファイルが担当)

- SCH-R-001, SCH-R-012, SCH-R-028, SCH-DD-03, SCH-DD-11, SCH-E-01, SCH-E-02, SCH-E-25, IDX-DD-02, IDX-DD-10: `parseArgs` (tasks-cli.md)
- SCH-R-032, SCH-E-31: list の出力書式 (tasks-cli.md)
- SCH-DD-09, IDX-DD-04, IDX-DD-05: 例外から終了コードへの変換 (tasks-cli.md)。本書は投げる例外の型を T-07 で確かめる
- SCH-R-029 の CLI 配線: tasks-cli.md。保存先の差し替え自体は T-05-09, T-05-10
- SCH-E-24: 対象外 (仕様が結果を保証しない)

### 判定規則 (Section 4)

| Source item                       | Task ID(s)                                                                                                                                                                                                 |
| --------------------------------- | ---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| SCH-R-002                         | T-04-01-01, T-04-01-02, T-04-02-01, T-04-03-01, T-04-04-01, T-04-05-01                                                                                                                                     |
| SCH-R-031                         | T-04-09-01, T-04-10-01, T-04-11-01, T-04-13-01〜04, T-04-14-01〜04, T-04-15-01                                                                                                                             |
| SCH-R-001 (c) の解釈不能な `--at` | T-04-06-01, T-04-07-01, T-04-08-01                                                                                                                                                                         |
| SCH-R-003                         | T-07-18-01〜04                                                                                                                                                                                             |
| SCH-R-004                         | T-07-01-01〜05                                                                                                                                                                                             |
| SCH-R-005                         | T-07-02-01〜05, T-07-03-01                                                                                                                                                                                 |
| SCH-R-006                         | T-07-04-01〜04                                                                                                                                                                                             |
| SCH-R-007                         | T-07-22-01〜03, T-07-37-01, T-07-38-01                                                                                                                                                                     |
| SCH-R-008                         | T-07-01-02〜04, T-07-19-01, T-07-19-02, T-07-20-01                                                                                                                                                         |
| SCH-R-009                         | T-06-01-01〜04, T-06-05-01〜05, T-07-02-01〜05                                                                                                                                                             |
| SCH-R-010                         | T-06-06-01〜05, T-07-21-01〜04, T-07-24-01〜06, T-07-34-01〜03, T-07-48-01                                                                                                                                 |
| SCH-R-011                         | T-07-01-02, T-07-02-02                                                                                                                                                                                     |
| SCH-R-036                         | T-07-05-01〜04, T-07-06-01〜03, T-07-07-01〜02, T-07-09-01〜03, T-07-17-01〜02, T-07-34-01〜03, T-07-35-01〜03, T-07-36-01〜02, T-07-41-01〜04, T-07-42-01〜02, T-07-43-01, T-07-44-01〜02, T-07-48-01〜02 |
| SCH-R-013                         | T-07-27-01〜03                                                                                                                                                                                             |
| SCH-R-014                         | T-07-08-01〜03                                                                                                                                                                                             |
| SCH-R-015                         | T-07-28-01〜02, T-07-29-01〜04                                                                                                                                                                             |
| SCH-R-030                         | T-07-07-01, T-07-40-01〜03, T-07-45-01〜02                                                                                                                                                                 |
| SCH-R-016                         | T-07-30-01, T-07-31-01                                                                                                                                                                                     |
| SCH-R-017                         | T-07-10-01〜02                                                                                                                                                                                             |
| SCH-R-018                         | T-07-12-01〜02                                                                                                                                                                                             |
| SCH-R-019                         | T-07-11-01〜02                                                                                                                                                                                             |
| SCH-R-020                         | T-07-13-01〜02, T-07-49-01, T-07-51-01〜02                                                                                                                                                                 |
| SCH-R-033                         | T-07-12-01〜02, T-07-51-01〜02                                                                                                                                                                             |
| SCH-R-034                         | T-07-32-01〜02                                                                                                                                                                                             |
| SCH-R-021                         | T-07-14-01〜04, T-07-54-01                                                                                                                                                                                 |
| SCH-R-022                         | T-07-16-01〜03, T-07-53-01                                                                                                                                                                                 |
| SCH-R-023                         | T-07-15-01〜02                                                                                                                                                                                             |
| SCH-R-024                         | T-07-14-04, T-07-33-02, T-07-55-01〜05, T-07-56-01                                                                                                                                                         |
| SCH-R-035                         | T-07-33-01〜04, T-07-55-01〜02                                                                                                                                                                             |
| SCH-R-025                         | T-05-03-01〜03, T-05-11-01〜02                                                                                                                                                                             |
| SCH-R-026                         | T-05-11-02, T-05-12-02, T-06-07-01〜03, T-06-08-01〜02                                                                                                                                                     |
| SCH-R-027                         | T-05-14-01〜02, T-05-15-01〜02, T-05-16-01                                                                                                                                                                 |
| SCH-R-029                         | T-05-09-01, T-05-10-01, T-05-17-01, T-05-20-01                                                                                                                                                             |

### 例外的なケース (Section 5)

| Source item                                          | Task ID(s)                                             |
| ---------------------------------------------------- | ------------------------------------------------------ |
| SCH-E-03                                             | T-04-04-01, T-04-05-01                                 |
| SCH-E-04                                             | T-04-12-01, T-07-19-01, T-07-19-02                     |
| SCH-E-05                                             | T-04-09-01, T-04-10-01, T-04-13-01〜04, T-04-14-01〜04 |
| SCH-E-06                                             | T-07-18-01〜04                                         |
| SCH-E-07                                             | T-07-02-01〜05                                         |
| SCH-E-08                                             | T-07-04-01〜04                                         |
| SCH-E-09                                             | T-07-03-01                                             |
| SCH-E-10                                             | T-07-24-01〜06, T-06-06-01〜05                         |
| SCH-E-11                                             | T-07-23-01〜04, T-06-07-01〜03                         |
| SCH-E-12                                             | T-07-25-01〜05, T-07-26-01〜03                         |
| SCH-E-13                                             | T-07-40-01〜03                                         |
| SCH-E-14                                             | T-07-21-01〜04                                         |
| SCH-E-15                                             | T-07-22-01〜03                                         |
| SCH-E-16                                             | T-07-20-01                                             |
| SCH-E-17                                             | T-07-27-01〜03                                         |
| SCH-E-18                                             | T-07-29-01〜04                                         |
| SCH-E-19                                             | T-07-45-01〜02                                         |
| SCH-E-20                                             | T-05-14-01〜02                                         |
| SCH-E-21                                             | T-07-16-01〜03, T-07-53-01                             |
| SCH-E-22                                             | T-07-15-01〜02                                         |
| SCH-E-23                                             | T-05-02-05, T-07-39-01〜02                             |
| SCH-E-26                                             | T-05-09-01                                             |
| SCH-E-27                                             | T-07-32-01〜02                                         |
| SCH-E-28                                             | T-07-33-01〜04, T-07-55-01〜05                         |
| SCH-E-29                                             | T-07-55-01〜05                                         |
| SCH-E-30                                             | T-07-12-01〜02, T-07-51-01〜02                         |
| SCH-E-32                                             | T-07-38-01                                             |
| 索引 5 章: 通知設定が無効 / AUMID が未登録のまま add | T-07-18-01〜04                                         |
| 索引 5 章: 発火後の add は新規                       | T-07-04-01〜04                                         |
| 索引 5 章: 対応表の更新失敗後に予約が残る (孤児)     | T-07-21-01〜04                                         |
| 索引 5 章: 置換前の予約の削除失敗 (両方が残る)       | T-07-25-01〜05                                         |
| 索引 5 章: 一括再登録で過去の時刻                    | T-07-16-01〜03                                         |
| 索引 5 章: 通知できない状態の re-register-all        | T-07-32-01〜02                                         |
| 索引 5 章: 削除が「対象が無い」を返す                | T-07-07-01, T-07-40-01〜03, T-07-45-01〜02             |
| 索引 5 章: 孤立した予約                              | T-07-12-01〜02, T-07-51-01〜02                         |
| 索引 5 章: 夏時間の曖昧 / 存在しない                 | T-04-09-01, T-04-10-01, T-04-13-01〜04, T-04-14-01〜04 |

### 設計判断 (Section 2.5)

| Source item                                            | Task ID(s)                                                                                                                 |
| ------------------------------------------------------ | -------------------------------------------------------------------------------------------------------------------------- |
| SCH-DD-01 (置換の 4 段階)                              | T-06-01-01〜04, T-06-05-01〜05, T-06-06-01〜05, T-07-02-05, T-07-23-01〜04, T-07-24-01〜06, T-07-25-01〜05, T-07-26-01〜03 |
| SCH-DD-02 (対応表は SQLite)                            | T-05-01-01, T-05-02-01〜05, T-05-06-01〜04, T-05-07-01                                                                     |
| SCH-DD-04 (オフセット無しはローカル時刻)               | T-04-04-01, T-04-05-01                                                                                                     |
| SCH-DD-05 (過去は OS の 0x80070057)                    | T-04-12-01, T-07-19-01〜02                                                                                                 |
| SCH-DD-06 (cancel の見つからない)                      | T-07-27-01〜03                                                                                                             |
| SCH-DD-07 (cancel は予約 → 対応表の順)                 | T-07-08-03, T-07-29-01〜04                                                                                                 |
| SCH-DD-08 (過去は登録せず一覧へ)                       | T-07-16-01〜03, T-07-53-01                                                                                                 |
| SCH-DD-10 (Tag 重複は再生成 3 回まで)                  | T-07-22-01〜03                                                                                                             |
| SCH-DD-12 (既定の保存先と `--db`)                      | T-05-09-01, T-05-10-01                                                                                                     |
| SCH-DD-13 (削除の「対象が無い」は成功)                 | T-07-07-01, T-07-40-01〜03, T-07-45-01〜02                                                                                 |
| SCH-DD-14 (夏時間)                                     | T-04-09-01, T-04-10-01, T-04-13-01〜04, T-04-14-01〜04                                                                     |
| SCH-DD-15 (孤立した予約は報告だけ)                     | T-07-12-01〜02, T-07-51-01〜02                                                                                             |
| SCH-DD-16 (re-register-all の通知可否の確認と個別失敗) | T-07-32-01〜02, T-07-33-01〜04, T-07-55-01〜05                                                                             |
| IDX-DD-01 (SQLite・トランザクション)                   | T-05-06-01〜04, T-05-11-02, T-06-07-01〜03                                                                                 |
| IDX-DD-03 (`--at` はローカル時刻)                      | T-04-04-01, T-04-05-01                                                                                                     |
| IDX-DD-06 (cancel の見つからない)                      | T-07-27-01〜03                                                                                                             |
| IDX-DD-07 (過去の記録は一覧へ)                         | T-07-16-01〜03                                                                                                             |
| IDX-DD-08 (再生成は 3 回まで)                          | T-07-22-01〜03                                                                                                             |
| IDX-DD-11 (既定の保存先と `--db`)                      | T-05-09-01, T-05-10-01                                                                                                     |
| IDX-DD-13 (re-register-all)                            | T-07-14-01〜04, T-07-15-01〜02, T-07-16-01〜03, T-07-32-01〜02, T-07-55-01〜05                                             |

### 決定記録・索引の規則 (Section 2.6)

| Source item                                                    | Task ID(s)                                     |
| -------------------------------------------------------------- | ---------------------------------------------- |
| DR-05 (追加してから削除)                                       | T-07-02-05, T-07-24-06, T-07-25-02, T-07-40-03 |
| DR-07 決定 1 (DB に意図を先に書く)                             | T-06-01-01〜04, T-07-02-05, T-07-23-02         |
| DR-07 決定 3 (保留からの再開: 段階 2 / 3 / 4)                  | T-07-05-01〜04, T-07-06-01〜03, T-07-07-01〜02 |
| DR-07 決定 4 (再開は冪等。置換後の Tag が既にあれば追加しない) | T-07-06-01                                     |
| 3.5 段階 1 の失敗 (置換前の予約だけが残る)                     | T-07-23-01〜04                                 |
| 3.5 段階 2 の拒否 (置換前の予約だけが残る)                     | T-07-24-01〜06                                 |
| 3.5 段階 3 の失敗 (両方が残る)                                 | T-07-25-01〜05                                 |
| 3.5 段階 4 の失敗 (置換後の予約だけが残る)                     | T-07-26-01〜03                                 |
| 3.5 段階 4 の完了 (失敗状態ではない)                           | T-07-02-01〜05                                 |
| 3.5 段階 3 の後・段階 4 の前 (置換後の予約だけが残る)          | T-07-07-01〜02                                 |
| 3.5 再開時の置換後の時刻が過去                                 | T-07-41-01〜04, T-07-42-01〜02, T-07-43-01     |
| IDX-R-001 (add の最初に通知可否の確認)                         | T-07-18-01〜04                                 |
| IDX-R-002 / IDX-R-003 (分類と Tag の生成)                      | T-07-01-01, T-07-02-01, T-07-04-01, T-07-22-01 |
| IDX-R-004 (新規は追加してから対応表)                           | T-07-01-04                                     |
| IDX-R-005 (置換)                                               | T-07-02-05                                     |
| IDX-R-006 (cancel の順序)                                      | T-07-08-03                                     |
| IDX-R-007 (re-register-all の最初の確認)                       | T-07-32-01〜02                                 |

## Category Balance

| Test Target                      | Normal     | Error     | Edge     | Result |
| -------------------------------- | ---------- | --------- | -------- | ------ |
| T-04: parseAt                    | Normal: 6  | Error: 4  | Edge: 12 | [OK]   |
| T-05: MappingTable / SqliteStore | Normal: 21 | Error: 12 | Edge: 6  | [OK]   |
| T-06: 置換キュー                 | Normal: 19 | Error: 5  | Edge: 4  | [OK]   |
| T-07: SchedulingService          | Normal: 49 | Error: 57 | Edge: 36 | [OK]   |

<!--
Task ID Format: T-<TestTarget>-<Scenario>-<Case>
- TestTarget: 04 = ATP, 05 = MAP, 06 = RPQ, 07 = SVC
- Scenario: 2-digit (対象内で Normal → Error → Edge に連番)
- Case: 2-digit
-->
