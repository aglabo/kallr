---
title: "Implementation Tasks: schedule"
module: kallr/windows-dist-verify
status: Active
created: "2026-11-22 00:00:00"
source: specifications-schedule.md
version: 1.2.0
---

<!-- textlint-disable ja-technical-writing/sentence-length -->
<!-- textlint-disable ja-technical-writing/max-comma -->
<!-- markdownlint-disable no-duplicate-heading line-length -->

> This document contains implementation tasks derived from specifications-schedule.md.
> Each task corresponds to a single unit test case (`it()` block).
> 対象は T-04 (ATP)、T-05 (MAP)、T-06 (RPQ)、T-19 (SQA)。Tag の生成 (T-01〜T-03)、`SchedulingService` (T-07, T-14〜T-18。tasks-service.md)、CLI (T-10, T-11)、AVL / W5C は別ファイルが扱う。

---

## Task Summary

| Test Target                            | Scenarios | Cases | Status |
| -------------------------------------- | --------- | ----- | ------ |
| T-04: parseAt (ATP)                    | 18        | 28    | done   |
| T-05: MappingTable / SqliteStore (MAP) | 22        | 44    | done   |
| T-06: 置換キュー (RPQ)                 | 14        | 34    | done   |
| T-19: SqliteAccess (SQA)               | 12        | 17    | done   |

<!-- Status may be: pending | in progress | done -->

---

## T-04: parseAt (ATP)

> `offsetAt` は次の 2 種類を使う。
>
> - 固定: 常に指定のオフセットを返す (例: 固定 +09:00)。
> - NY 規則: 米国東部の夏時間。`2026-03-08T07:00:00Z` 以降は -04:00、`2026-11-01T06:00:00Z` 以降は -05:00 (それ以前は直前の値)。

### [正常] Normal Cases

#### T-04-01: Given: オフセット +09:00 付きの文字列

- [x] **T-04-01-01**: +09:00 の文字列を同じ絶対時刻に解釈する
  - Target: `parseAt`
  - Scenario: Given `"2026-11-22T09:30:00+09:00"`, When `parseAt` を呼ぶ
  - Expected: Then `2026-11-22T00:30:00Z` と同じ瞬間を返す

- [x] **T-04-01-02**: オフセット付きの結果は UTC で保持する
  - Target: `parseAt`
  - Scenario: Given `"2026-11-22T09:30:00+09:00"`, When `parseAt` を呼ぶ
  - Expected: Then 返した `DateTime` の `isUtc` が true である

#### T-04-02: Given: `Z` 付きの文字列

- [x] **T-04-02-01**: `Z` の文字列を UTC の絶対時刻に解釈する
  - Target: `parseAt`
  - Scenario: Given `"2026-11-22T00:30:00Z"`, When `parseAt` を呼ぶ
  - Expected: Then `2026-11-22T00:30:00Z` と同じ瞬間を返す

#### T-04-03: Given: 負のオフセット -05:00 付きの文字列

- [x] **T-04-03-01**: -05:00 の文字列を同じ絶対時刻に解釈する
  - Target: `parseAt`
  - Scenario: Given `"2026-11-22T09:30:00-05:00"`, When `parseAt` を呼ぶ
  - Expected: Then `2026-11-22T14:30:00Z` と同じ瞬間を返す

#### T-04-04: Given: オフセット無しの文字列と、固定 +09:00 の `offsetAt` (SCH-R-002, SCH-DD-04)

- [x] **T-04-04-01**: オフセット無しの文字列をローカル時刻として解決する
  - Target: `parseAt`
  - Scenario: Given `"2026-11-22T09:30:00"` と固定 +09:00 の `offsetAt`, When `parseAt` を呼ぶ
  - Expected: Then `2026-11-22T00:30:00Z` と同じ瞬間を返す

#### T-04-05: Given: オフセット無しの文字列と、固定 -05:00 の `offsetAt` (JST 前提でないこと。SCH-E-03)

- [x] **T-04-05-01**: ローカルのオフセットに従い、JST を仮定しない
  - Target: `parseAt`
  - Scenario: Given `"2026-11-22T09:30:00"` と固定 -05:00 の `offsetAt`, When `parseAt` を呼ぶ
  - Expected: Then `2026-11-22T14:30:00Z` と同じ瞬間を返す

#### T-04-16: Given: 日付のみの文字列 (SCH-R-002, SCH-DD-17, SCH-E-33)

- [x] **T-04-16-01**: 日付のみは、ローカルの 00:00:00 として解決する (+09:00)
  - Target: `parseAt`
  - Scenario: Given `"2026-11-22"` と固定 +09:00 の `offsetAt`, When `parseAt` を呼ぶ
  - Expected: Then `2026-11-21T15:00:00Z` と同じ瞬間を返す

- [x] **T-04-16-02**: 日付のみは、ローカルのオフセットに従う (-05:00)
  - Target: `parseAt`
  - Scenario: Given `"2026-11-22"` と固定 -05:00 の `offsetAt`, When `parseAt` を呼ぶ
  - Expected: Then `2026-11-22T05:00:00Z` と同じ瞬間を返す

### [異常] Error Cases

#### T-04-06: Given: 日時として解釈できない文字列 (SCH-R-001 (c))

- [x] **T-04-06-01**: 解釈できない文字列は使い方の誤りになる
  - Target: `parseAt`
  - Scenario: Given `"tomorrow"`, When `parseAt` を呼ぶ
  - Expected: Then `UsageException` を投げる

#### T-04-07: Given: 空文字

- [x] **T-04-07-01**: 空文字は使い方の誤りになる
  - Target: `parseAt`
  - Scenario: Given `""`, When `parseAt` を呼ぶ
  - Expected: Then `UsageException` を投げる

#### T-04-08: Given: 存在しない暦の日付

- [x] **T-04-08-01**: 13 月 45 日は使い方の誤りになる
  - Target: `parseAt`
  - Scenario: Given `"2026-13-45T09:30:00"`, When `parseAt` を呼ぶ
  - Expected: Then `UsageException` を投げる

#### T-04-09: Given: 夏時間の進みで存在しないローカル時刻 (SCH-R-031, SCH-E-05, SCH-DD-14)

- [x] **T-04-09-01**: 存在しない時刻は使い方の誤りになる
  - Target: `parseAt`
  - Scenario: Given `"2026-03-08T02:30:00"` と NY 規則の `offsetAt`, When `parseAt` を呼ぶ
  - Expected: Then `UsageException` を投げる

#### T-04-17: Given: 日付のみの不正な文字列 (SCH-DD-17, SCH-E-33)

- [x] **T-04-17-01**: 存在しない暦の日付のみは使い方の誤りになる
  - Target: `parseAt`
  - Scenario: Given `"2026-02-30"`, When `parseAt` を呼ぶ
  - Expected: Then `UsageException` を投げる

- [x] **T-04-17-02**: 日付にオフセットだけを付けた文字列は使い方の誤りになる
  - Target: `parseAt`
  - Scenario: Given `"2026-11-22+09:00"`, When `parseAt` を呼ぶ
  - Expected: Then `UsageException` を投げる

### [エッジケース] Edge Cases

#### T-04-10: Given: 夏時間の戻りで曖昧なローカル時刻 (SCH-R-031, SCH-E-05)

- [x] **T-04-10-01**: 曖昧な時刻は早いほうの瞬間を使う
  - Target: `parseAt`
  - Scenario: Given `"2026-11-01T01:30:00"` と NY 規則の `offsetAt`, When `parseAt` を呼ぶ
  - Expected: Then 早いほうの `2026-11-01T05:30:00Z` と同じ瞬間を返す (遅いほうの `06:30:00Z` ではない)

#### T-04-11: Given: 曖昧な時間帯の明示オフセット付き文字列 (T-04-10 との対比)

- [x] **T-04-11-01**: 明示オフセットは夏時間の規則に左右されない
  - Target: `parseAt`
  - Scenario: Given `"2026-11-01T01:30:00-05:00"` と NY 規則の `offsetAt`, When `parseAt` を呼ぶ
  - Expected: Then `2026-11-01T06:30:00Z` と同じ瞬間を返す (早いほうに寄せない)

#### T-04-12: Given: 過去の時刻 (SCH-DD-05)

- [x] **T-04-12-01**: 過去の時刻を検査しない
  - Target: `parseAt`
  - Scenario: Given `"2000-01-01T00:00:00Z"`, When `parseAt` を呼ぶ
  - Expected: Then 例外を投げず、`2000-01-01T00:00:00Z` と同じ瞬間を返す

#### T-04-13: Given: 曖昧な時間帯の境界 (NY 規則)

- [x] **T-04-13-01**: 曖昧になる直前の 00:59:59 は曖昧でない
  - Target: `parseAt`
  - Scenario: Given `"2026-11-01T00:59:59"` と NY 規則の `offsetAt`, When `parseAt` を呼ぶ
  - Expected: Then `2026-11-01T04:59:59Z` と同じ瞬間を返す

- [x] **T-04-13-02**: 曖昧な時間帯の先頭 01:00:00 は早いほうを使う
  - Target: `parseAt`
  - Scenario: Given `"2026-11-01T01:00:00"` と NY 規則の `offsetAt`, When `parseAt` を呼ぶ
  - Expected: Then `2026-11-01T05:00:00Z` と同じ瞬間を返す

- [x] **T-04-13-03**: 曖昧な時間帯の末尾 01:59:59 は早いほうを使う
  - Target: `parseAt`
  - Scenario: Given `"2026-11-01T01:59:59"` と NY 規則の `offsetAt`, When `parseAt` を呼ぶ
  - Expected: Then `2026-11-01T05:59:59Z` と同じ瞬間を返す

- [x] **T-04-13-04**: 曖昧でなくなる 02:00:00 は標準時の瞬間になる
  - Target: `parseAt`
  - Scenario: Given `"2026-11-01T02:00:00"` と NY 規則の `offsetAt`, When `parseAt` を呼ぶ
  - Expected: Then `2026-11-01T07:00:00Z` と同じ瞬間を返す

#### T-04-14: Given: 存在しない時間帯の境界 (NY 規則)

- [x] **T-04-14-01**: 存在しなくなる直前の 01:59:59 は有効である
  - Target: `parseAt`
  - Scenario: Given `"2026-03-08T01:59:59"` と NY 規則の `offsetAt`, When `parseAt` を呼ぶ
  - Expected: Then `2026-03-08T06:59:59Z` と同じ瞬間を返す

- [x] **T-04-14-02**: 存在しない時間帯の先頭 02:00:00 は使い方の誤りになる
  - Target: `parseAt`
  - Scenario: Given `"2026-03-08T02:00:00"` と NY 規則の `offsetAt`, When `parseAt` を呼ぶ
  - Expected: Then `UsageException` を投げる

- [x] **T-04-14-03**: 存在しない時間帯の末尾 02:59:59 は使い方の誤りになる
  - Target: `parseAt`
  - Scenario: Given `"2026-03-08T02:59:59"` と NY 規則の `offsetAt`, When `parseAt` を呼ぶ
  - Expected: Then `UsageException` を投げる

- [x] **T-04-14-04**: 存在し直す 03:00:00 は有効である
  - Target: `parseAt`
  - Scenario: Given `"2026-03-08T03:00:00"` と NY 規則の `offsetAt`, When `parseAt` を呼ぶ
  - Expected: Then `2026-03-08T07:00:00Z` と同じ瞬間を返す

#### T-04-15: Given: 夏時間の規則がある地域の、切り替えと無関係な時刻

- [x] **T-04-15-01**: 切り替えと無関係な夏の時刻は 1 つの瞬間に決まる
  - Target: `parseAt`
  - Scenario: Given `"2026-07-01T12:00:00"` と NY 規則の `offsetAt`, When `parseAt` を呼ぶ
  - Expected: Then `2026-07-01T16:00:00Z` と同じ瞬間を返す

#### T-04-18: Given: 夏時間の切り替え日の日付のみ (NY 規則。00:00:00 は切り替え時刻より前なので、通常の解決になる。SCH-DD-17)

- [x] **T-04-18-01**: 進みの日の日付のみは、標準時の 00:00:00 になる
  - Target: `parseAt`
  - Scenario: Given `"2026-03-08"` と NY 規則の `offsetAt`, When `parseAt` を呼ぶ
  - Expected: Then `2026-03-08T05:00:00Z` と同じ瞬間を返す

- [x] **T-04-18-02**: 戻りの日の日付のみは、夏時間の 00:00:00 になる
  - Target: `parseAt`
  - Scenario: Given `"2026-11-01"` と NY 規則の `offsetAt`, When `parseAt` を呼ぶ
  - Expected: Then `2026-11-01T04:00:00Z` と同じ瞬間を返す

---

## T-05: MappingTable / SqliteStore (MAP)

> 共通の前提: 一時ディレクトリの SQLite を使う。`MappingRecord` の例は (batchId `b1`, alarmId `a1`, tag `20261122090000-a1b2c3d4-0123456789abcdef`, at `2026-11-22T12:00:00+09:00`, title `t1`, registeredAt `2026-11-22T09:00:00` (ローカル))。
> DB の内容は、テストが SQLite を直接読んで確認する。

### [正常] Normal Cases

#### T-05-01: Given: 空の対応表に put した後 (SCH-R-025)

- [x] **T-05-01-01**: put した項目を get で同じ値のまま引ける
  - Target: `MappingTable.get`
  - Scenario: Given 空の対応表に `b1` / `a1` の項目を `put` した, When `get('b1','a1')` を呼ぶ
  - Expected: Then 全フィールドが等しい `MappingRecord` を返す

#### T-05-02: Given: 保存形式 (db-migration.md §2.2)

- [x] **T-05-02-01**: `at` は UTC の ISO 8601 で保存する
  - Target: `MappingTable.put`
  - Scenario: Given `at` が `2026-11-22T12:00:00+09:00` の項目, When `put` する
  - Expected: Then `notifications.at` の値が `2026-11-22T03:00:00.000Z` である

- [x] **T-05-02-02**: 読み戻した `at` は同じ絶対時刻になる
  - Target: `MappingTable.get`
  - Scenario: Given `at` が `2026-11-22T12:00:00+09:00` の項目を `put` した, When `get` する
  - Expected: Then 返した `at` が `2026-11-22T03:00:00Z` と同じ瞬間である

- [x] **T-05-02-03**: `registeredAt` はオフセット無しのローカル日時で保存し、ローカルのまま読み戻す
  - Target: `MappingTable.put`
  - Scenario: Given `registeredAt` が `2026-11-22T09:00:00` (ローカル) の項目, When `put` して `get` する
  - Expected: Then `notifications.registered_at` が `2026-11-22T09:00:00.000` で、返した `registeredAt` の `isUtc` が false である

- [x] **T-05-02-04**: `group_name` に `kallr` を入れる
  - Target: `MappingTable.put`
  - Scenario: Given 新規の項目, When `put` する
  - Expected: Then `notifications.group_name` が `kallr` である

- [x] **T-05-02-05**: title の UTF-8 文字をそのまま保存する (SCH-E-23)
  - Target: `MappingTable.put`
  - Scenario: Given title が `会議の開始` の項目, When `put` して `get` する
  - Expected: Then 返した title が `会議の開始` と等しい

#### T-05-03: Given: 同じ (batchId, alarmId) に 2 回 put する (SCH-R-025)

- [x] **T-05-03-01**: 2 回目の値で上書きされる
  - Target: `MappingTable.put`
  - Scenario: Given `b1` / `a1` に tag `...-0123456789abcdef` を `put` 済み, When 同じキーに別の tag・at・title で `put` する
  - Expected: Then `get('b1','a1')` が 2 回目の値を返す

- [x] **T-05-03-02**: 上書きでも物理 ID は変わらない
  - Target: `MappingTable.put`
  - Scenario: Given `b1` / `a1` を `put` 済みで `notifications.id` を控えた, When 同じキーに別の tag で `put` する
  - Expected: Then `notifications.id` が控えた値のままである

- [x] **T-05-03-03**: 有効な項目は 1 つだけである
  - Target: `MappingTable.all`
  - Scenario: Given 同じキーに 2 回 `put` した, When `all()` を呼ぶ
  - Expected: Then 要素数が 1 である

#### T-05-04: Given: 項目を remove した後

- [x] **T-05-04-01**: remove した項目は get で引けない
  - Target: `MappingTable.remove`
  - Scenario: Given `b1` / `a1` を `put` 済み, When `remove('b1','a1')` を呼ぶ
  - Expected: Then `get('b1','a1')` が null を返す

- [x] **T-05-04-02**: remove した項目は all に含まれない
  - Target: `MappingTable.remove`
  - Scenario: Given `b1` / `a1` を `put` 済み, When `remove('b1','a1')` を呼ぶ
  - Expected: Then `all()` が空である

#### T-05-05: Given: 異なるキーを 2 件 put した後

- [x] **T-05-05-01**: all は 2 件を返す
  - Target: `MappingTable.all`
  - Scenario: Given `b1`/`a1` と `b1`/`a2` を `put` 済み, When `all()` を呼ぶ
  - Expected: Then 2 件の `MappingRecord` を返す

- [x] **T-05-05-02**: tags は 2 件の Tag を返す
  - Target: `MappingTable.tags`
  - Scenario: Given `b1`/`a1` と `b1`/`a2` を `put` 済み, When `tags()` を呼ぶ
  - Expected: Then 2 件の Tag を含む `Set` を返す

#### T-05-06: Given: 存在しないパスに SqliteStore を開く (SCH-R-027, 初回の利用)

- [x] **T-05-06-01**: ファイルが作られる
  - Target: `SqliteStore.open`
  - Scenario: Given 存在しない `new.sqlite3` のパス, When `open` する
  - Expected: Then そのパスにファイルが作られる

- [x] **T-05-06-02**: `user_version` が 1 になる
  - Target: `SqliteStore.open`
  - Scenario: Given 存在しない `new.sqlite3` のパス, When `open` する
  - Expected: Then `PRAGMA user_version` が 1 である

- [x] **T-05-06-03**: 3 つのテーブルが作られる
  - Target: `SqliteStore.open`
  - Scenario: Given 存在しない `new.sqlite3` のパス, When `open` する
  - Expected: Then `notifications`、`replacement_queue`、`settings` の 3 テーブルが存在する

- [x] **T-05-06-04**: 空の対応表として始まる
  - Target: `SqliteStore.open`
  - Scenario: Given 存在しない `new.sqlite3` のパス, When `open` して `all()` を呼ぶ
  - Expected: Then 空のリストを返す

#### T-05-07: Given: 正常な既存ファイルを開き直す

- [x] **T-05-07-01**: 保存済みの項目を読める
  - Target: `SqliteStore.open`
  - Scenario: Given `b1`/`a1` を `put` して閉じた正常なファイル, When 同じパスを `open` して `get('b1','a1')` を呼ぶ
  - Expected: Then `put` した値と等しい `MappingRecord` を返す

#### T-05-08: Given: 接続の設定

- [x] **T-05-08-01**: 外部キー制約が有効である
  - Target: `SqliteStore.open`
  - Scenario: Given 開いた接続, When `PRAGMA foreign_keys` を読む
  - Expected: Then 値が 1 (ON) である

#### T-05-09: Given: `--db` で指定した保存先 (SCH-R-029, SCH-E-26, SCH-DD-12)

- [x] **T-05-09-01**: 指定したパスのファイルを使う
  - Target: `SqliteStore.open`
  - Scenario: Given `--db` 相当のパス `<tmp>/custom/x.sqlite3` (親ディレクトリあり), When `open` して `put` する
  - Expected: Then そのパスのファイルに項目が保存されている

#### T-05-10: Given: `--db` が無いときの既定の保存先 (SCH-R-029, SCH-DD-12)

- [x] **T-05-10-01**: LOCALAPPDATA 配下の既定のパスを返す
  - Target: `defaultDbPath`
  - Scenario: Given 環境変数 `LOCALAPPDATA` が `C:\Users\tester\AppData\Local`, When 既定の保存先を求める
  - Expected: Then `C:\Users\tester\AppData\Local/kallr/w1-w7-verify/mappings.sqlite3` を返す (`LOCALAPPDATA` の後ろは `/` 区切り)

### [異常] Error Cases

#### T-05-11: Given: 別のキーが持つ Tag と同じ Tag の項目を put する (SCH-R-025, SCH-R-026)

- [x] **T-05-11-01**: UNIQUE 違反は StorageException になる
  - Target: `MappingTable.put`
  - Scenario: Given `b1`/`a1` が tag `T1` を持つ, When `b2`/`a2` に同じ tag `T1` で `put` する
  - Expected: Then `StorageException` を投げる

- [x] **T-05-11-02**: 失敗した put は何も変えない
  - Target: `MappingTable.put`
  - Scenario: Given `b1`/`a1` が tag `T1` を持つ, When `b2`/`a2` に同じ tag `T1` で `put` して失敗した
  - Expected: Then `all()` が失敗前と同じ 1 件のままである

#### T-05-12: Given: 識別子 (batchId, alarmId) が空文字の項目 (specifications-schedule.md 3.3 の制約)

- [x] **T-05-12-01**: 空の batchId は StorageException になる
  - Target: `MappingTable.put`
  - Scenario: Given batchId が `""` の項目, When `put` する
  - Expected: Then `StorageException` を投げる

- [x] **T-05-12-02**: 空の batchId の項目は保存されない
  - Target: `MappingTable.put`
  - Scenario: Given batchId が `""` の項目, When `put` して失敗した
  - Expected: Then `all()` が空である

- [x] **T-05-12-03**: 空の alarmId は StorageException になる
  - Target: `MappingTable.put`
  - Scenario: Given alarmId が `""` の項目, When `put` する
  - Expected: Then `StorageException` を投げる

- [x] **T-05-12-04**: 空の alarmId の項目は保存されない
  - Target: `MappingTable.put`
  - Scenario: Given alarmId が `""` の項目, When `put` して失敗した
  - Expected: Then `all()` が空である

#### T-05-13: Given: Tag の長さが 40 でない項目 (db-migration.md §2.2 の CHECK)

- [x] **T-05-13-01**: 39 文字の Tag は StorageException になる
  - Target: `MappingTable.put`
  - Scenario: Given tag が 39 文字の項目, When `put` する
  - Expected: Then `StorageException` を投げる

- [x] **T-05-13-02**: 41 文字の Tag は StorageException になる
  - Target: `MappingTable.put`
  - Scenario: Given tag が 41 文字の項目, When `put` する
  - Expected: Then `StorageException` を投げる

#### T-05-14: Given: 壊れたファイル (SCH-R-027, SCH-E-20)

- [x] **T-05-14-01**: 壊れたファイルは StorageException になる
  - Target: `SqliteStore.open`
  - Scenario: Given 100 バイトの SQLite でない文字列を書いた既存ファイル, When `open` する
  - Expected: Then `StorageException` を投げる

- [x] **T-05-14-02**: 壊れたファイルは作り直さない
  - Target: `SqliteStore.open`
  - Scenario: Given 100 バイトの SQLite でない文字列を書いた既存ファイル, When `open` して失敗した
  - Expected: Then ファイルのバイト列が `open` の前と同じである

#### T-05-15: Given: `user_version` が 2 の既存ファイル (db-migration.md §3.1)

- [x] **T-05-15-01**: 未定義の版は StorageException になる
  - Target: `SqliteStore.open`
  - Scenario: Given `PRAGMA user_version = 2` の正常な SQLite ファイル, When `open` する
  - Expected: Then `StorageException` を投げる

- [x] **T-05-15-02**: 未定義の版のファイルは変更しない
  - Target: `SqliteStore.open`
  - Scenario: Given `PRAGMA user_version = 2` の正常な SQLite ファイル, When `open` して失敗した
  - Expected: Then ファイルのバイト列が `open` の前と同じである

#### T-05-16: Given: `user_version` が 0 で、別のテーブルがある既存ファイル (別のアプリの DB)

- [x] **T-05-16-01**: テーブルがあって版が 1 以外のファイルは StorageException になる
  - Target: `SqliteStore.open`
  - Scenario: Given `user_version` が 0 で、テーブル `other` を持つ既存ファイル, When `open` する
  - Expected: Then `StorageException` を投げる (db-migration.md §3.1: `empty` はテーブルが 1 つも無いときだけ)

- [x] **T-05-16-02**: 別のテーブルがあるファイルは変更しない
  - Target: `SqliteStore.open`
  - Scenario: Given 同上, When `open` する
  - Expected: Then ファイルのバイト列が `open` の前と同じである (スキーマを作らない)

#### T-05-17: Given: 環境変数 LOCALAPPDATA が無い

- [x] **T-05-17-01**: 既定の保存先を決められず StorageException になる
  - Target: `defaultDbPath`
  - Scenario: Given 環境変数 `LOCALAPPDATA` が未設定, When 既定の保存先を求める
  - Expected: Then `StorageException` を投げる

### [エッジケース] Edge Cases

#### T-05-18: Given: 存在しないキーの remove

- [x] **T-05-18-01**: 存在しないキーの remove は例外を投げない
  - Target: `MappingTable.remove`
  - Scenario: Given `b1`/`a1` だけが `put` 済み, When `remove('b9','a9')` を呼ぶ
  - Expected: Then 例外を投げない

- [x] **T-05-18-02**: 存在しないキーの remove は他の項目を変えない
  - Target: `MappingTable.remove`
  - Scenario: Given `b1`/`a1` だけが `put` 済み, When `remove('b9','a9')` を呼ぶ
  - Expected: Then `get('b1','a1')` が元の値を返す

#### T-05-19: Given: 空の対応表

- [x] **T-05-19-01**: 空の対応表の all は空のリストを返す
  - Target: `MappingTable.all`
  - Scenario: Given 何も `put` していない対応表, When `all()` を呼ぶ
  - Expected: Then 空のリストを返す

- [x] **T-05-19-02**: 空の対応表の tags は空の集合を返す
  - Target: `MappingTable.tags`
  - Scenario: Given 何も `put` していない対応表, When `tags()` を呼ぶ
  - Expected: Then 空の `Set` を返す

#### T-05-20: Given: 親ディレクトリが無い保存先 (db-migration.md / implementation-schedule.md §2.1)

- [x] **T-05-20-01**: 親ディレクトリを作って開く
  - Target: `SqliteStore.open`
  - Scenario: Given 存在しない `<tmp>/a/b/c` を親に持つ `x.sqlite3` のパス, When `open` する
  - Expected: Then 親ディレクトリが作られ、例外を投げずにファイルが作られる

#### T-05-21: Given: 同じキー・同じ Tag で title だけ変えて put する

- [x] **T-05-21-01**: 自分自身の Tag との重複は UNIQUE 違反にならない
  - Target: `MappingTable.put`
  - Scenario: Given `b1`/`a1` が tag `T1` で `put` 済み, When 同じキーを同じ tag `T1` で title だけ `t2` にして `put` する
  - Expected: Then 例外を投げず、`get('b1','a1')` の title が `t2` である

#### T-05-22: Given: 0 バイトの既存ファイル (テーブルが 1 つも無い)

- [x] **T-05-22-01**: 0 バイトの既存ファイルは新規作成と同じように初期化され、例外を投げない
  - Target: `SqliteStore.open`
  - Scenario: Given 0 バイトの既存ファイル, When `open` する
  - Expected: Then 例外を投げず、`PRAGMA user_version` が 1 になる (db-migration.md §3.1: `empty` から `initial` へ)

- [x] **T-05-22-02**: 初期化されたファイルに 3 つのテーブルが作られる
  - Target: `SqliteStore.open`
  - Scenario: Given 同上, When `open` する
  - Expected: Then テーブル `notifications`、`replacement_queue`、`settings` が存在する

---

## T-06: 置換キュー (RPQ)

> 共通の前提: 旧行は (`b1`,`a1`, tag `OLD`=`20261122090000-a1b2c3d4-0123456789abcdef`, at `2026-11-22T12:00:00+09:00`, title `旧`) で current。
> 置換後の `MappingRecord` は (`b1`,`a1`, tag `PND`=`20261122093000-a1b2c3d4-0123456789abcdef`, at `2026-11-22T13:00:00+09:00`, title `新`)。
> `notify_status` は 1 = current、2 = pending、0 = superseded。DB の内容は SQLite を直接読んで確認する。

### [正常] Normal Cases

#### T-06-01: Given: 旧行が current の状態で replace した直後 (SCH-R-009 段階 1, SCH-DD-01)

- [x] **T-06-01-01**: 置換後の行が pending で追加される
  - Target: `MappingTable.replace`
  - Scenario: Given 旧行が current, When 置換後の `MappingRecord` で `replace` する
  - Expected: Then tag `PND` の行が `notify_status = 2` で存在する

- [x] **T-06-01-02**: 旧行が superseded になる
  - Target: `MappingTable.replace`
  - Scenario: Given 旧行が current, When 置換後の `MappingRecord` で `replace` する
  - Expected: Then tag `OLD` の行が `notify_status = 0` である

- [x] **T-06-01-03**: キューに (新行の id, 旧行の id) が入る
  - Target: `MappingTable.replace`
  - Scenario: Given 旧行が current, When 置換後の `MappingRecord` で `replace` する
  - Expected: Then `replacement_queue` に `new_id` が新行の id、`old_id` が旧行の id の行がちょうど 1 件ある

- [x] **T-06-01-04**: 戻り値はキューの行の id である
  - Target: `MappingTable.replace`
  - Scenario: Given 旧行が current, When 置換後の `MappingRecord` で `replace` する
  - Expected: Then 戻り値が `replacement_queue.id` と等しい

#### T-06-02: Given: replace 直後の参照 (implementation-schedule.md §2.4)

- [x] **T-06-02-01**: get は置換後の行を返す
  - Target: `MappingTable.get`
  - Scenario: Given `replace` した直後, When `get('b1','a1')` を呼ぶ
  - Expected: Then tag `PND` の `MappingRecord` を返す

- [x] **T-06-02-02**: all は旧行を含まず pending の行を含む
  - Target: `MappingTable.all`
  - Scenario: Given `replace` した直後, When `all()` を呼ぶ
  - Expected: Then tag `PND` の 1 件だけを返す

- [x] **T-06-02-03**: tags は旧行の Tag を含む
  - Target: `MappingTable.tags`
  - Scenario: Given `replace` した直後, When `tags()` を呼ぶ
  - Expected: Then `OLD` と `PND` の両方を含む

#### T-06-03: Given: 保留が 1 件ある

- [x] **T-06-03-01**: pendingRemovals は旧行の Tag・Group・置換後の値を返す
  - Target: `MappingTable.pendingRemovals`
  - Scenario: Given `replace` した直後, When `pendingRemovals()` を呼ぶ
  - Expected: Then 1 件で、`queueId` が `replace` の戻り値、`oldTag` が `OLD`、`group` が `kallr`、置換後の `MappingRecord` が tag `PND` の値である

#### T-06-04: Given: 保留が 2 件ある

- [x] **T-06-04-01**: pendingRemovals は queueId の昇順で返す
  - Target: `MappingTable.pendingRemovals`
  - Scenario: Given `b1`/`a1` を先に、`b2`/`a2` を後に `replace` した, When `pendingRemovals()` を呼ぶ
  - Expected: Then `b1`/`a1` の保留、`b2`/`a2` の保留の順で 2 件を返す

#### T-06-05: Given: 保留を completeRemoval した後 (SCH-R-009 段階 4)

- [x] **T-06-05-01**: 旧行が削除される
  - Target: `MappingTable.completeRemoval`
  - Scenario: Given `replace` 済みで `queueId` を得た, When `completeRemoval(queueId)` を呼ぶ
  - Expected: Then tag `OLD` の行が `notifications` に存在しない

- [x] **T-06-05-02**: 新行が current になる
  - Target: `MappingTable.completeRemoval`
  - Scenario: Given `replace` 済みで `queueId` を得た, When `completeRemoval(queueId)` を呼ぶ
  - Expected: Then tag `PND` の行が `notify_status = 1` である

- [x] **T-06-05-03**: キューの行は残り `old_id` が NULL になる
  - Target: `MappingTable.completeRemoval`
  - Scenario: Given `replace` 済みで `queueId` を得た, When `completeRemoval(queueId)` を呼ぶ
  - Expected: Then `replacement_queue` の該当行が残り、`old_id` が NULL である

- [x] **T-06-05-04**: 完了済みの行は pendingRemovals に出ない
  - Target: `MappingTable.pendingRemovals`
  - Scenario: Given `completeRemoval` 済み, When `pendingRemovals()` を呼ぶ
  - Expected: Then 空のリストを返す

- [x] **T-06-05-05**: tags から旧行の Tag が消える
  - Target: `MappingTable.tags`
  - Scenario: Given `completeRemoval` 済み, When `tags()` を呼ぶ
  - Expected: Then `PND` を含み、`OLD` を含まない

#### T-06-06: Given: 保留を abortReplacement した後 (SCH-R-010)

- [x] **T-06-06-01**: 新行が削除される
  - Target: `MappingTable.abortReplacement`
  - Scenario: Given `replace` 済みで `queueId` を得た, When `abortReplacement(queueId)` を呼ぶ
  - Expected: Then tag `PND` の行が `notifications` に存在しない

- [x] **T-06-06-02**: キューの行も削除される
  - Target: `MappingTable.abortReplacement`
  - Scenario: Given `replace` 済みで `queueId` を得た, When `abortReplacement(queueId)` を呼ぶ
  - Expected: Then `replacement_queue` に該当行が存在しない (`ON DELETE CASCADE`)

- [x] **T-06-06-03**: 旧行が current に戻る
  - Target: `MappingTable.abortReplacement`
  - Scenario: Given `replace` 済みで `queueId` を得た, When `abortReplacement(queueId)` を呼ぶ
  - Expected: Then tag `OLD` の行が `notify_status = 1` である

- [x] **T-06-06-04**: get は旧行の値を返す
  - Target: `MappingTable.get`
  - Scenario: Given `abortReplacement` 済み, When `get('b1','a1')` を呼ぶ
  - Expected: Then tag `OLD` の `MappingRecord` を返す

- [x] **T-06-06-05**: 取り消した保留は pendingRemovals に出ない
  - Target: `MappingTable.pendingRemovals`
  - Scenario: Given `abortReplacement` 済み, When `pendingRemovals()` を呼ぶ
  - Expected: Then 空のリストを返す

### [異常] Error Cases

#### T-06-07: Given: 置換後の Tag が別のキーの Tag と衝突する replace (SCH-R-026, SCH-E-11)

- [x] **T-06-07-01**: StorageException になる
  - Target: `MappingTable.replace`
  - Scenario: Given `b9`/`a9` が tag `PND` を持つ, When `b1`/`a1` を tag `PND` で `replace` する
  - Expected: Then `StorageException` を投げる

- [x] **T-06-07-02**: 旧行は current のまま変わらない
  - Target: `MappingTable.replace`
  - Scenario: Given `b9`/`a9` が tag `PND` を持つ, When `b1`/`a1` を tag `PND` で `replace` して失敗した
  - Expected: Then tag `OLD` の行が `notify_status = 1` である

- [x] **T-06-07-03**: 新行とキューの行は作られない
  - Target: `MappingTable.replace`
  - Scenario: Given `b9`/`a9` が tag `PND` を持つ, When `b1`/`a1` を tag `PND` で `replace` して失敗した
  - Expected: Then `replacement_queue` が 0 件で、`notifications` に pending の行が無い

#### T-06-08: Given: 置換後の Tag が旧行の Tag と同じ replace

- [x] **T-06-08-01**: StorageException になる
  - Target: `MappingTable.replace`
  - Scenario: Given 旧行の tag が `OLD`, When `b1`/`a1` を tag `OLD` で `replace` する
  - Expected: Then `StorageException` を投げる

- [x] **T-06-08-02**: 旧行は current のまま変わらない
  - Target: `MappingTable.replace`
  - Scenario: Given 旧行の tag が `OLD`, When `b1`/`a1` を tag `OLD` で `replace` して失敗した
  - Expected: Then tag `OLD` の行が `notify_status = 1` である

#### T-06-13: Given: 置換する旧行 (current な行) が無い replace (番号は既存 ID を振り直さないため末尾)

- [x] **T-06-13-01**: StorageException になる
  - Target: `MappingTable.replace`
  - Scenario: Given `b1`/`a1` の行が無い, When `b1`/`a1` を tag `PND` で `replace` する
  - Expected: Then `StorageException` を投げる

- [x] **T-06-13-02**: 新行とキューの行は作られない
  - Target: `MappingTable.replace`
  - Scenario: Given `b1`/`a1` の行が無い, When `b1`/`a1` を tag `PND` で `replace` して失敗した
  - Expected: Then `notifications` と `replacement_queue` が 0 件である

### [エッジケース] Edge Cases

#### T-06-09: Given: 2 件の保留のうち 1 件を complete する

- [x] **T-06-09-01**: もう 1 件は保留のまま残る
  - Target: `MappingTable.completeRemoval`
  - Scenario: Given `b1`/`a1` と `b2`/`a2` を `replace` 済み, When `b1`/`a1` の `completeRemoval` を呼ぶ
  - Expected: Then `pendingRemovals()` が `b2`/`a2` の 1 件だけを返す

#### T-06-10: Given: 2 件の保留のうち 1 件を abort する

- [x] **T-06-10-01**: もう 1 件の新行は pending のまま残る
  - Target: `MappingTable.abortReplacement`
  - Scenario: Given `b1`/`a1` と `b2`/`a2` を `replace` 済み, When `b1`/`a1` の `abortReplacement` を呼ぶ
  - Expected: Then `b2`/`a2` の新行が `notify_status = 2` のままである

#### T-06-11: Given: 完了後にもう一度 replace する (AUTOINCREMENT)

- [x] **T-06-11-01**: キューの id を再利用しない
  - Target: `MappingTable.replace`
  - Scenario: Given 1 回目の `replace` の `queueId` を `completeRemoval` した, When 同じキーを別の tag で 2 回目の `replace` する
  - Expected: Then 戻り値が 1 回目の `queueId` より大きい

#### T-06-12: Given: 完了済みのキュー行が残っている状態で、同じキーをもう一度 replace する

- [x] **T-06-12-01**: pendingRemovals は新しい保留の 1 件だけを返す
  - Target: `MappingTable.pendingRemovals`
  - Scenario: Given 1 回目の置換を `completeRemoval` 済みで、2 回目の `replace` をした, When `pendingRemovals()` を呼ぶ
  - Expected: Then 2 回目の保留 1 件だけを返す (完了済みの行を含まない)

#### T-06-14: Given: 前の置換が未完了 (旧行 A が superseded、前の置換後の行 B が pending) の状態で、同じキーをもう一度 replace する (番号は既存 ID を振り直さないため末尾)

> 前提: A = tag `OLD`、B = (`b1`,`a1`, tag `PND`)、キューは (B, A)。置換後の `MappingRecord` C は (`b1`,`a1`, tag `PN2`=`20261122100000-a1b2c3d4-0123456789abcdef`, at `2026-11-22T14:00:00+09:00`, title `新2`)。

- [x] **T-06-14-01**: 前の置換後の行 B が削除される
  - Target: `MappingTable.replace`
  - Scenario: Given 前の置換が未完了, When C で `replace` する
  - Expected: Then tag `PND` の行が `notifications` に存在しない

- [x] **T-06-14-02**: キューの行は最新の 1 件だけで (C の id, A の id) である
  - Target: `MappingTable.replace`
  - Scenario: Given 前の置換が未完了, When C で `replace` する
  - Expected: Then `replacement_queue` に `new_id` が C の id、`old_id` が A の id の行がちょうど 1 件だけある (B のキューの行は無い)

- [x] **T-06-14-03**: 最初の旧行 A は superseded のまま残り、C が pending で追加される
  - Target: `MappingTable.replace`
  - Scenario: Given 前の置換が未完了, When C で `replace` する
  - Expected: Then tag `OLD` の行が `notify_status = 0`、tag `PN2` の行が `notify_status = 2` である

- [x] **T-06-14-04**: 戻り値は新しいキューの行の id である
  - Target: `MappingTable.replace`
  - Scenario: Given 前の置換が未完了, When C で `replace` する
  - Expected: Then 戻り値が `replacement_queue.id` と等しく、前の `replace` の戻り値とは異なる

---

## T-19: SqliteAccess (SQA)

> `SqliteStore` から基礎層を分ける移設 (implementation-schedule.md §2.5)。
> 移設そのものは振る舞いを変えない。既存の MAP (T-05)、MID (T-03)、RPQ (T-06) のテストを変えずに通すことが、移設の安全網である。
> 新しい Case は、基礎層 `SqliteAccess` を単体で確かめる。テストは、一時ファイルの SQLite か、メモリ上の SQLite で行う。
> `SqliteStore.open` と `SqliteStore.fromDatabase` の公開の形は変えない。
> 番号は既存 ID を振り直さないため末尾 (T-19) とする。

### [正常] Normal Cases

#### T-19-01: Given: 成功する action を guard に渡す

- [x] **T-19-01-01**: 戻り値をそのまま返す
  - Target: `SqliteAccess.guard`
  - Scenario: Given 42 を返す action, When `guard('p: ', action)` を呼ぶ
  - Expected: Then 42 を返す

#### T-19-02: Given: 成功する body を transact に渡す

- [x] **T-19-02-01**: body の戻り値を返す
  - Target: `SqliteAccess.transact`
  - Scenario: Given 1 行を `INSERT` して 42 を返す body, When `transact('p: ', body)` を呼ぶ
  - Expected: Then 42 を返す

- [x] **T-19-02-02**: 変更が確定する
  - Target: `SqliteAccess.transact`
  - Scenario: Given 1 行を `INSERT` する body, When `transact('p: ', body)` を呼ぶ
  - Expected: Then 別の接続から、その 1 行を読める

#### T-19-03: Given: 値をバインドした select

- [x] **T-19-03-01**: 条件に合う行だけを返す
  - Target: `SqliteAccess.select`
  - Scenario: Given `a = 1` と `a = 2` の 2 行があるテーブル, When `select('SELECT a FROM t WHERE a = ?', [2])` を呼ぶ
  - Expected: Then `a = 2` の 1 行だけを返す

#### T-19-04: Given: 3 行のうち 2 行に当たる UPDATE を execute した直後

- [x] **T-19-04-01**: updatedRows が 2 である
  - Target: `SqliteAccess.updatedRows`
  - Scenario: Given 3 行のうち 2 行に当たる `UPDATE` を `execute` した, When `updatedRows` を読む
  - Expected: Then 2 を返す

#### T-19-05: Given: AUTOINCREMENT のテーブルに 1 行を INSERT した直後

- [x] **T-19-05-01**: lastInsertRowId が追加した行の id である
  - Target: `SqliteAccess.lastInsertRowId`
  - Scenario: Given AUTOINCREMENT のテーブルに 1 行を `INSERT` した, When `lastInsertRowId` を読む
  - Expected: Then 追加した行の `id` と等しい

### [異常] Error Cases

#### T-19-06: Given: SqliteException を投げる action を guard に渡す (存在しないテーブルを SELECT する)

- [x] **T-19-06-01**: StorageException になる
  - Target: `SqliteAccess.guard`
  - Scenario: Given 存在しないテーブルを `SELECT` する action, When `guard('p: ', action)` を呼ぶ
  - Expected: Then `StorageException` を投げる

- [x] **T-19-06-02**: メッセージは prefix の後ろに SQLite のメッセージが続く
  - Target: `SqliteAccess.guard`
  - Scenario: Given 存在しないテーブルを `SELECT` する action, When `guard('p: ', action)` を呼んで失敗した
  - Expected: Then メッセージが渡した prefix で始まり、SQLite のメッセージ (`no such table`) を含む

#### T-19-07: Given: SqliteException 以外の例外を投げる action を guard に渡す

- [x] **T-19-07-01**: 同じ例外がそのまま出る
  - Target: `SqliteAccess.guard`
  - Scenario: Given `StateError` を投げる action, When `guard('p: ', action)` を呼ぶ
  - Expected: Then `StateError` を投げる (`StorageException` に変えない)

#### T-19-08: Given: SqliteException を投げる body を transact に渡す (1 行を INSERT した後に存在しないテーブルを SELECT する)

- [x] **T-19-08-01**: StorageException になる
  - Target: `SqliteAccess.transact`
  - Scenario: Given 1 行を `INSERT` した後に存在しないテーブルを `SELECT` する body, When `transact('p: ', body)` を呼ぶ
  - Expected: Then `StorageException` を投げる

- [x] **T-19-08-02**: 変更は取り消される
  - Target: `SqliteAccess.transact`
  - Scenario: Given 1 行を `INSERT` した後に存在しないテーブルを `SELECT` する body, When `transact('p: ', body)` を呼んで失敗した
  - Expected: Then `INSERT` した行が残っていない

#### T-19-09: Given: SqliteException 以外の例外を投げる body を transact に渡す (1 行を INSERT した後に StateError を投げる)

- [x] **T-19-09-01**: 同じ例外がそのまま出る
  - Target: `SqliteAccess.transact`
  - Scenario: Given 1 行を `INSERT` した後に `StateError` を投げる body, When `transact('p: ', body)` を呼ぶ
  - Expected: Then `StateError` を投げる (`StorageException` に変えない)

- [x] **T-19-09-02**: 変更は取り消される
  - Target: `SqliteAccess.transact`
  - Scenario: Given 1 行を `INSERT` した後に `StateError` を投げる body, When `transact('p: ', body)` を呼んで失敗した
  - Expected: Then `INSERT` した行が残っていない

### [エッジケース] Edge Cases

#### T-19-10: Given: すでにトランザクションが開いているときに transact を呼ぶ (BEGIN が失敗する)

- [x] **T-19-10-01**: StorageException になる
  - Target: `SqliteAccess.transact`
  - Scenario: Given `execute('BEGIN')` で外側のトランザクションを開いてある, When `transact('p: ', body)` を呼ぶ
  - Expected: Then `StorageException` を投げる

- [x] **T-19-10-02**: 外側のトランザクションは取り消されず、COMMIT できる
  - Target: `SqliteAccess.transact`
  - Scenario: Given `execute('BEGIN')` で外側のトランザクションを開き 1 行を `INSERT` してある, When `transact('p: ', body)` が失敗した後に `execute('COMMIT')` を呼ぶ
  - Expected: Then 外側で `INSERT` した行が、別の接続から読める

#### T-19-11: Given: 条件に合う行が無い select

- [x] **T-19-11-01**: 空の結果を返す
  - Target: `SqliteAccess.select`
  - Scenario: Given 空のテーブル, When `select('SELECT a FROM t WHERE a = ?', [1])` を呼ぶ
  - Expected: Then 空の結果を返す (例外を投げない)

#### T-19-12: Given: params を省略した select

- [x] **T-19-12-01**: バインドなしで実行される
  - Target: `SqliteAccess.select`
  - Scenario: Given `?` を含まない SQL `SELECT 1 AS n`, When `params` を省略して `select` を呼ぶ
  - Expected: Then `n` が 1 の 1 行を返す

---

## Coverage Check

### 除外 (別ファイルが担当)

- SCH-R-001, SCH-R-012, SCH-R-028, SCH-DD-03, SCH-DD-11, SCH-E-01, SCH-E-02, SCH-E-25, IDX-DD-02, IDX-DD-10: `parseArgs` (tasks-cli.md)
- SCH-R-032, SCH-E-31: list の出力書式 (tasks-cli.md)
- SCH-DD-09, IDX-DD-04, IDX-DD-05: 例外から終了コードへの変換 (tasks-cli.md)
- SCH-R-003〜008, SCH-R-011, SCH-R-013〜024, SCH-R-030, SCH-R-033〜036、SCH-E-06〜09, SCH-E-12〜19, SCH-E-21, SCH-E-22, SCH-E-27〜30, SCH-E-32: `SchedulingService` (tasks-service.md)。SCH-R-009, SCH-R-010, SCH-E-04, SCH-E-10, SCH-E-11, SCH-DD-01 は置換キュー側 (本書 T-06) と `SchedulingService` 側 (tasks-service.md) の両方で確かめる
- SCH-R-029 の CLI 配線: tasks-cli.md。保存先の差し替え自体は T-05-09, T-05-10
- SCH-E-24: 対象外 (仕様が結果を保証しない)

### 判定規則 (Section 4)

| Source item                       | Task ID(s)                                                                                                             |
| --------------------------------- | ---------------------------------------------------------------------------------------------------------------------- |
| SCH-R-002                         | T-04-01-01, T-04-01-02, T-04-02-01, T-04-03-01, T-04-04-01, T-04-05-01, T-04-16-01〜02, T-04-17-01〜02, T-04-18-01〜02 |
| SCH-R-031                         | T-04-09-01, T-04-10-01, T-04-11-01, T-04-13-01〜04, T-04-14-01〜04, T-04-15-01                                         |
| SCH-R-001 (c) の解釈不能な `--at` | T-04-06-01, T-04-07-01, T-04-08-01                                                                                     |
| SCH-R-009                         | T-06-01-01〜04, T-06-05-01〜05                                                                                         |
| SCH-R-010                         | T-06-06-01〜05                                                                                                         |
| SCH-R-025                         | T-05-03-01〜03, T-05-11-01〜02                                                                                         |
| SCH-R-026                         | T-05-11-02, T-05-12-02, T-05-12-04, T-06-07-01〜03, T-06-08-01〜02, T-19-08-01〜02, T-19-09-01〜02, T-19-10-01〜02     |
| SCH-R-027                         | T-05-14-01〜02, T-05-15-01〜02, T-05-16-01〜02, T-05-22-01〜02                                                         |
| SCH-R-029                         | T-05-09-01, T-05-10-01, T-05-17-01, T-05-20-01                                                                         |

### 例外的なケース (Section 5)

| Source item                          | Task ID(s)                                             |
| ------------------------------------ | ------------------------------------------------------ |
| SCH-E-03                             | T-04-04-01, T-04-05-01                                 |
| SCH-E-04                             | T-04-12-01                                             |
| SCH-E-05                             | T-04-09-01, T-04-10-01, T-04-13-01〜04, T-04-14-01〜04 |
| SCH-E-10                             | T-06-06-01〜05                                         |
| SCH-E-11                             | T-06-07-01〜03                                         |
| SCH-E-20                             | T-05-14-01〜02                                         |
| SCH-E-23                             | T-05-02-05                                             |
| SCH-E-26                             | T-05-09-01                                             |
| SCH-E-33                             | T-04-16-01〜02, T-04-17-01〜02, T-04-18-01〜02         |
| 索引 5 章: 夏時間の曖昧 / 存在しない | T-04-09-01, T-04-10-01, T-04-13-01〜04, T-04-14-01〜04 |

### 設計判断 (Section 2.5)

| Source item                                    | Task ID(s)                                                                                                 |
| ---------------------------------------------- | ---------------------------------------------------------------------------------------------------------- |
| SCH-DD-01 (置換の 4 段階)                      | T-06-01-01〜04, T-06-05-01〜05, T-06-06-01〜05                                                             |
| SCH-DD-02 (対応表は SQLite)                    | T-05-01-01, T-05-02-01〜05, T-05-06-01〜04, T-05-07-01                                                     |
| SCH-DD-04 (オフセット無しはローカル時刻)       | T-04-04-01, T-04-05-01                                                                                     |
| SCH-DD-05 (過去は OS の 0x80070057)            | T-04-12-01                                                                                                 |
| SCH-DD-12 (既定の保存先と `--db`)              | T-05-09-01, T-05-10-01                                                                                     |
| SCH-DD-14 (夏時間)                             | T-04-09-01, T-04-10-01, T-04-13-01〜04, T-04-14-01〜04                                                     |
| SCH-DD-17 (日付のみは 00:00:00 のローカル時刻) | T-04-16-01〜02, T-04-17-01〜02, T-04-18-01〜02                                                             |
| IDX-DD-01 (SQLite・トランザクション)           | T-05-06-01〜04, T-05-11-02, T-06-07-01〜03, T-19-02-01〜02, T-19-08-01〜02, T-19-09-01〜02, T-19-10-01〜02 |
| IDX-DD-03 (`--at` はローカル時刻)              | T-04-04-01, T-04-05-01                                                                                     |
| IDX-DD-11 (既定の保存先と `--db`)              | T-05-09-01, T-05-10-01                                                                                     |

### 決定記録・索引の規則 (Section 2.6)

| Source item                                                   | Task ID(s)                         |
| ------------------------------------------------------------- | ---------------------------------- |
| DR-08 決定 1 (DB を先に書く 4 段。DR-07 決定 1 を置き換え)    | T-06-01-01〜04                     |
| DR-08 決定 2 (置換後の行は段 4 まで pending。段 4 で current) | T-06-01-01, T-06-02-02, T-06-05-02 |

## Category Balance

| Test Target                      | Normal     | Error     | Edge     | Result |
| -------------------------------- | ---------- | --------- | -------- | ------ |
| T-04: parseAt                    | Normal: 8  | Error: 6  | Edge: 14 | [OK]   |
| T-05: MappingTable / SqliteStore | Normal: 21 | Error: 15 | Edge: 8  | [OK]   |
| T-06: 置換キュー                 | Normal: 19 | Error: 7  | Edge: 8  | [OK]   |
| T-19: SqliteAccess               | Normal: 6  | Error: 7  | Edge: 4  | [OK]   |

<!--
Task ID Format: T-<TestTarget>-<Scenario>-<Case>
- TestTarget: 04 = ATP, 05 = MAP, 06 = RPQ, 19 = SQA
- Scenario: 2-digit (対象内で Normal → Error → Edge に連番)
- Case: 2-digit
-->
