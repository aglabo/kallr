---
title: "Implementation Tasks: tag"
module: "kallr/windows-dist-verify"
status: Active
created: "2026-11-22 00:00:00"
source: specifications-tag.md
version: 1.0.0
---

<!-- textlint-disable ja-technical-writing/sentence-length -->
<!-- textlint-disable ja-technical-writing/max-comma -->
<!-- markdownlint-disable no-duplicate-heading line-length -->

> This document contains implementation tasks derived from specifications-tag.md.
> Each task corresponds to a single unit test case (`it()` block).
> 手動検証 (AC-009 の N 件登録、実機での Tag 上限) と windows/ FFI 層でしか確認できない項目は対象外とする。

---

## Task Summary

| Test Target                                          | Scenarios | Cases | Status |
| ---------------------------------------------------- | --------- | ----- | ------ |
| T-01: `generateTag` (TAG)                            | 10        | 28    | done   |
| T-02: `allocateTag` (TAL)                            | 13        | 18    | done   |
| T-03: `MachineIdProvider` 実装 / `SqliteStore` (MID) | 21        | 34    | done   |

---

## T-01: generateTag

### [正常] Normal Cases

#### T-01-01: 登録時刻・マシン ID・乱数から 40 文字の Tag を組み立てる

- [x] **T-01-01-01**: 有効な 3 入力から決められた書式の Tag を返す
  - Target: `generateTag`
  - Scenario: Given registeredAt が 2026-11-22 09:05:03 (ローカル)、machineId が `a1b2c3d4`、random が `0123456789abcdef`, When `generateTag` を呼ぶ
  - Expected: Then `20261122090503-a1b2c3d4-0123456789abcdef` を返す (TAG-R-002)

- [x] **T-01-01-02**: 返した Tag は常に 40 文字である
  - Target: `generateTag`
  - Scenario: Given registeredAt が 2026-11-22 09:05:03 (ローカル)、machineId が `a1b2c3d4`、random が `0123456789abcdef`, When `generateTag` を呼ぶ
  - Expected: Then 返した Tag の長さが 40 で、文書上の上限 64 文字以下である (TAG-R-004)

- [x] **T-01-01-03**: 月日時分秒が 1 桁の値でもゼロ埋めの 2 桁にする
  - Target: `generateTag`
  - Scenario: Given registeredAt が 2026-01-02 03:04:05 (ローカル)、machineId が `a1b2c3d4`、random が `0123456789abcdef`, When `generateTag` を呼ぶ
  - Expected: Then 日時部分が `20260102030405` になる (TAG-R-002)

- [x] **T-01-01-04**: ローカル日時を UTC へ変換せず、そのまま使う
  - Target: `generateTag`
  - Scenario: Given registeredAt が 2026-12-31 23:59:59 のローカル日時 (isUtc が false)、machineId が `a1b2c3d4`、random が `0123456789abcdef`, When `generateTag` を呼ぶ
  - Expected: Then 日時部分が `20261231235959` になる (DR-04 決定 2、実装 §2.2 の `toUtc()` 不使用)

#### T-01-02: Group は固定値 kallr である

- [x] **T-01-02-01**: 定数 `kGroup` は `kallr` で、Group の上限 64 文字以下である
  - Target: `kGroup`
  - Scenario: Given `models.dart` の定数 `kGroup`, When 値を参照する
  - Expected: Then `kallr` (5 文字) と等しい (TAG-R-004, DR-04 決定 1)

#### T-01-03: 同じ入力からは同じ Tag を返す

- [x] **T-01-03-01**: 同じ入力で 2 回呼ぶと同じ Tag を返す
  - Target: `generateTag`
  - Scenario: Given registeredAt が 2026-11-22 09:05:03 (ローカル)、machineId が `a1b2c3d4`、random が `0123456789abcdef`, When 同じ入力で `generateTag` を 2 回呼ぶ
  - Expected: Then 2 回の戻り値が等しい (TAG-R-003)

### [異常] Error Cases

#### T-01-04: 登録時刻の年が範囲外である

- [x] **T-01-04-01**: 年が -1 なら `ArgumentError` を投げる
  - Target: `generateTag`
  - Scenario: Given registeredAt の年が -1、machineId が `a1b2c3d4`、random が `0123456789abcdef`, When `generateTag` を呼ぶ
  - Expected: Then `ArgumentError` を投げ、Tag を返さない (TAG-R-001)

- [x] **T-01-04-02**: 年が 10000 なら `ArgumentError` を投げる
  - Target: `generateTag`
  - Scenario: Given registeredAt の年が 10000、machineId が `a1b2c3d4`、random が `0123456789abcdef`, When `generateTag` を呼ぶ
  - Expected: Then `ArgumentError` を投げ、Tag を返さない (TAG-R-001)

#### T-01-05: マシン ID の書式が不正である

- [x] **T-01-05-01**: マシン ID が 7 桁なら `ArgumentError` を投げる
  - Target: `generateTag`
  - Scenario: Given machineId が `a1b2c3d` (7 桁)、有効な registeredAt と random, When `generateTag` を呼ぶ
  - Expected: Then `ArgumentError` を投げる。補正しない (TAG-R-001)

- [x] **T-01-05-02**: マシン ID が 9 桁なら `ArgumentError` を投げる
  - Target: `generateTag`
  - Scenario: Given machineId が `a1b2c3d4e` (9 桁)、有効な registeredAt と random, When `generateTag` を呼ぶ
  - Expected: Then `ArgumentError` を投げる。切り詰めない (TAG-R-001)

- [x] **T-01-05-03**: マシン ID が大文字なら `ArgumentError` を投げる
  - Target: `generateTag`
  - Scenario: Given machineId が `A1B2C3D4`、有効な registeredAt と random, When `generateTag` を呼ぶ
  - Expected: Then `ArgumentError` を投げる。小文字に直さない (TAG-R-001)

- [x] **T-01-05-04**: マシン ID に 16 進以外の文字があれば `ArgumentError` を投げる
  - Target: `generateTag`
  - Scenario: Given machineId が `g1b2c3d4`、有効な registeredAt と random, When `generateTag` を呼ぶ
  - Expected: Then `ArgumentError` を投げる (TAG-R-001)

- [x] **T-01-05-05**: マシン ID が空文字なら `ArgumentError` を投げる
  - Target: `generateTag`
  - Scenario: Given machineId が空文字、有効な registeredAt と random, When `generateTag` を呼ぶ
  - Expected: Then `ArgumentError` を投げる。既定値で補わない (TAG-R-001)

#### T-01-06: 乱数の書式が不正である

- [x] **T-01-06-01**: 乱数が 15 桁なら `ArgumentError` を投げる
  - Target: `generateTag`
  - Scenario: Given random が `0123456789abcde` (15 桁)、有効な registeredAt と machineId, When `generateTag` を呼ぶ
  - Expected: Then `ArgumentError` を投げる (TAG-R-001)

- [x] **T-01-06-02**: 乱数が 17 桁なら `ArgumentError` を投げる
  - Target: `generateTag`
  - Scenario: Given random が `0123456789abcdef0` (17 桁)、有効な registeredAt と machineId, When `generateTag` を呼ぶ
  - Expected: Then `ArgumentError` を投げる (TAG-R-001)

- [x] **T-01-06-03**: 乱数が大文字なら `ArgumentError` を投げる
  - Target: `generateTag`
  - Scenario: Given random が `0123456789ABCDEF`、有効な registeredAt と machineId, When `generateTag` を呼ぶ
  - Expected: Then `ArgumentError` を投げる (TAG-R-001)

- [x] **T-01-06-04**: 乱数に 16 進以外の文字があれば `ArgumentError` を投げる
  - Target: `generateTag`
  - Scenario: Given random が `0123456789abcdeg`、有効な registeredAt と machineId, When `generateTag` を呼ぶ
  - Expected: Then `ArgumentError` を投げる (TAG-R-001)

- [x] **T-01-06-05**: 乱数の末尾に改行があれば `ArgumentError` を投げる
  - Target: `generateTag`
  - Scenario: Given random が `0123456789abcdef
` (16 桁の後ろに改行)、有効な registeredAt と machineId, When `generateTag` を呼ぶ
  - Expected: Then `ArgumentError` を投げる。改行を取り除かない (TAG-R-001)

- [x] **T-01-06-06**: 乱数に `/` (`0` の直前の文字) があれば `ArgumentError` を投げる
  - Target: `generateTag`
  - Scenario: Given random が `0123456789abcde/`、有効な registeredAt と machineId, When `generateTag` を呼ぶ
  - Expected: Then `ArgumentError` を投げる (TAG-R-001: 文字クラスの下端の外側)

- [x] **T-01-06-07**: 乱数に `:` (`9` の直後の文字) があれば `ArgumentError` を投げる
  - Target: `generateTag`
  - Scenario: Given random が `0123456789abcde:`、有効な registeredAt と machineId, When `generateTag` を呼ぶ
  - Expected: Then `ArgumentError` を投げる (TAG-R-001: 数字の上端の外側)

- [x] **T-01-06-08**: 乱数にバッククォート (`a` の直前の文字) があれば `ArgumentError` を投げる
  - Target: `generateTag`
  - Scenario: Given random が `0123456789abcde`` ` (最後の 1 文字がバッククォート)、有効な registeredAt と machineId, When `generateTag` を呼ぶ
  - Expected: Then `ArgumentError` を投げる (TAG-R-001: 文字の下端の外側)

### [エッジケース] Edge Cases

#### T-01-07: 登録時刻に秒未満がある

- [x] **T-01-07-01**: 999 ミリ秒は切り上げずに切り捨てる
  - Target: `generateTag`
  - Scenario: Given registeredAt が 2026-11-22 09:05:03.999 (ローカル)、machineId が `a1b2c3d4`、random が `0123456789abcdef`, When `generateTag` を呼ぶ
  - Expected: Then 日時部分が `20261122090503` になる (TAG-R-002)

#### T-01-08: 年の境界値

- [x] **T-01-08-01**: 年 0 は `0000` として受け入れる
  - Target: `generateTag`
  - Scenario: Given registeredAt が 0000-01-01 00:00:00 (ローカル)、machineId が `a1b2c3d4`、random が `0123456789abcdef`, When `generateTag` を呼ぶ
  - Expected: Then `00000101000000-a1b2c3d4-0123456789abcdef` を返す (TAG-R-001, TAG-R-002)

- [x] **T-01-08-02**: 年 9999 は `9999` として受け入れる
  - Target: `generateTag`
  - Scenario: Given registeredAt が 9999-12-31 23:59:59 (ローカル)、machineId が `a1b2c3d4`、random が `0123456789abcdef`, When `generateTag` を呼ぶ
  - Expected: Then `99991231235959-a1b2c3d4-0123456789abcdef` を返す (TAG-R-001, TAG-R-002)

#### T-01-09: マシン ID と乱数の有効な境界値

- [x] **T-01-09-01**: マシン ID `00000000` は有効な値として受け入れる
  - Target: `generateTag`
  - Scenario: Given machineId が `00000000`、有効な registeredAt と random, When `generateTag` を呼ぶ
  - Expected: Then `ArgumentError` を投げず、40 文字の Tag を返す (TAG-R-001 の誤検出を防ぐ)

- [x] **T-01-09-02**: 乱数 `ffffffffffffffff` は有効な値として受け入れる
  - Target: `generateTag`
  - Scenario: Given random が `ffffffffffffffff`、有効な registeredAt と machineId, When `generateTag` を呼ぶ
  - Expected: Then `ArgumentError` を投げず、40 文字の Tag を返す (TAG-R-001 の誤検出を防ぐ)

- [x] **T-01-09-03**: マシン ID `ffffffff` は有効な値として受け入れる
  - Target: `generateTag`
  - Scenario: Given machineId が `ffffffff`、有効な registeredAt と random, When `generateTag` を呼ぶ
  - Expected: Then `ArgumentError` を投げず、40 文字の Tag を返す (TAG-R-001 の誤検出を防ぐ。文字クラスの上端 `f` を誤って拒否しない)

#### T-01-10: 夏時間の切り替えで同じローカルの秒が 2 回現れる

- [x] **T-01-10-01**: 同じ登録時刻でも乱数が違えば異なる Tag になる
  - Target: `generateTag`
  - Scenario: Given 同じ registeredAt (2026-11-01 01:30:00 ローカル) と machineId `a1b2c3d4`、乱数が `0000000000000001` と `0000000000000002` の 2 通り, When 乱数ごとに `generateTag` を呼ぶ
  - Expected: Then 2 つの日時部分は等しく、Tag 全体は異なる (仕様 5 章の夏時間の行、区別は乱数部分が担う)

---

## T-02: allocateTag

### [正常] Normal Cases

#### T-02-01: 重複がなければ最初の乱数で作った Tag を採用する

- [x] **T-02-01-01**: `existingTags` が空なら 1 回目の乱数の Tag を返す
  - Target: `allocateTag`
  - Scenario: Given `existingTags` が空、registeredAt が 2026-11-22 09:05:03、machineId が `a1b2c3d4`、1 回目の乱数が `0123456789abcdef`, When `allocateTag` を呼ぶ
  - Expected: Then `20261122090503-a1b2c3d4-0123456789abcdef` を返す (TAG-R-005)

- [x] **T-02-01-02**: 重複がなければ `randomHex64` を 1 回だけ呼ぶ
  - Target: `allocateTag`
  - Scenario: Given `existingTags` が空、乱数の取得元が呼び出し回数を数える, When `allocateTag` を呼ぶ
  - Expected: Then `randomHex64` の呼び出しが 1 回である (TAG-R-005)

#### T-02-02: 既存の Tag と重複したら乱数だけを再生成する

- [x] **T-02-02-01**: 1 回目の Tag が `existingTags` にあれば 2 回目の乱数の Tag を返す
  - Target: `allocateTag`
  - Scenario: Given `existingTags` に 1 回目の乱数 (`0123456789abcdef`) の Tag だけがあり、2 回目の乱数が `fedcba9876543210`, When `allocateTag` を呼ぶ
  - Expected: Then 登録時刻とマシン ID は同じで、乱数部分が `fedcba9876543210` の Tag を返す (TAG-R-006, TAG-DD-02, SCH-E-32, SCH-R-007)

- [x] **T-02-02-02**: 再生成しても `machineId()` を呼ぶのは 1 回だけである
  - Target: `allocateTag`
  - Scenario: Given `existingTags` に 1 回目の Tag があり、`MachineIdProvider` が呼び出し回数を数える, When `allocateTag` を呼ぶ
  - Expected: Then `machineId()` の呼び出しが 1 回である (TAG-R-006)

#### T-02-03: allocateTag は existingTags を変更しない

- [x] **T-02-03-01**: 呼び出し後も `existingTags` の内容が変わらない
  - Target: `allocateTag`
  - Scenario: Given `existingTags` に Tag が 1 件あり、重複しない乱数が与えられる, When `allocateTag` を呼ぶ
  - Expected: Then `existingTags` の要素数が 1 のままで、返した Tag が追加されていない (実装 §2.3: 予約一覧と対応表に触れない)

### [異常] Error Cases

#### T-02-05: 4 回とも重複した

- [x] **T-02-05-01**: 4 回とも重複したら `DuplicateTagException` を `attempts: 4` で投げる
  - Target: `allocateTag`
  - Scenario: Given `existingTags` に 4 つの乱数 (`0000000000000001`〜`0000000000000004`) の Tag がすべてあり、乱数の取得元がこの 4 つをこの順に返す, When `allocateTag` を呼ぶ
  - Expected: Then `DuplicateTagException` を投げ、`attempts` が 4 である。Tag を返さない (TAG-R-007, TAG-DD-01, IDX-DD-08)

- [x] **T-02-05-02**: 上限に達したら 5 回目の乱数を取得しない
  - Target: `allocateTag`
  - Scenario: Given 前項と同じ `existingTags` と乱数の取得元 (呼び出し回数を数える), When `allocateTag` を呼ぶ
  - Expected: Then `randomHex64` の呼び出しがちょうど 4 回で止まる (TAG-DD-01, IDX-DD-08)

#### T-02-06: 乱数の取得元が不正な値を返した

- [x] **T-02-06-01**: 乱数が小文字 16 進 16 桁でなければ `ArgumentError` を伝える
  - Target: `allocateTag`
  - Scenario: Given `existingTags` が空で、乱数の取得元が `xyz` を返す, When `allocateTag` を呼ぶ
  - Expected: Then `ArgumentError` を投げる。再生成で隠さず、Tag を返さない (仕様 2.1 の「失敗は黙って補わない」、TAG-R-001)

#### T-02-07: マシン ID を取得できない

- [x] **T-02-07-01**: `machineId()` が `StorageException` を投げたらそのまま伝える
  - Target: `allocateTag`
  - Scenario: Given `existingTags` が空で、`MachineIdProvider` が `StorageException` を投げる, When `allocateTag` を呼ぶ
  - Expected: Then `StorageException` を投げる。Tag を返さない (TAG-R-010 の伝播)

#### T-02-08: マシン ID が不正な値である

- [x] **T-02-08-01**: `machineId()` が `ZZZZZZZZ` を返したら `ArgumentError` を伝える
  - Target: `allocateTag`
  - Scenario: Given `existingTags` が空で、`MachineIdProvider` が `ZZZZZZZZ` を返す, When `allocateTag` を呼ぶ
  - Expected: Then `ArgumentError` を投げる。補正しない (TAG-R-001)

### [エッジケース] Edge Cases

#### T-02-09: 3 回目の再生成で成功する (上限の境界)

- [x] **T-02-09-01**: 最初の 3 回が重複し 4 回目で空きなら 4 回目の Tag を返す
  - Target: `allocateTag`
  - Scenario: Given `existingTags` に乱数 `0000000000000001`〜`0000000000000003` の Tag があり、4 回目の乱数が `0000000000000004`, When `allocateTag` を呼ぶ
  - Expected: Then 乱数部分が `0000000000000004` の Tag を返し、`DuplicateTagException` を投げない (TAG-R-006, TAG-DD-01)

- [x] **T-02-09-02**: 3 回目の再生成で成功したときの `randomHex64` の呼び出しは 4 回である
  - Target: `allocateTag`
  - Scenario: Given 前項と同じ `existingTags` と乱数の取得元 (呼び出し回数を数える), When `allocateTag` を呼ぶ
  - Expected: Then `randomHex64` の呼び出しが 4 回である (初回 + 再生成 3 回、TAG-DD-01)

#### T-02-10: 日時とマシン ID が同じで乱数だけ違う Tag は重複とみなさない

- [x] **T-02-10-01**: 乱数部分が違う既存の Tag があっても 1 回目の Tag を採用する
  - Target: `allocateTag`
  - Scenario: Given `existingTags` に同じ日時・同じマシン ID で乱数が `fedcba9876543210` の Tag だけがあり、1 回目の乱数が `0123456789abcdef`, When `allocateTag` を呼ぶ
  - Expected: Then 乱数部分が `0123456789abcdef` の Tag を返し、`randomHex64` は 1 回だけ呼ばれる (TAG-R-005 の誤検出を防ぐ)

#### T-02-11: 予約件数の上限相当の既存 Tag

- [x] **T-02-11-01**: `existingTags` が 4096 件でも重複しなければ Tag を返す
  - Target: `allocateTag`
  - Scenario: Given `existingTags` に互いに異なる 4096 件の Tag があり、1 回目の乱数がそのどれとも一致しない, When `allocateTag` を呼ぶ
  - Expected: Then 例外を投げずに Tag を返す。コードは件数を制限しない (REQ-F-007、実装 §2.4)

#### T-02-12: 置換でも追加と同じ手順を通る

- [x] **T-02-12-01**: 同じ登録時刻で 2 回目に呼び、1 回目の Tag が `existingTags` にあれば別の Tag を返す
  - Target: `allocateTag`
  - Scenario: Given 1 回目の `allocateTag` の戻り値を `existingTags` に入れ、2 回目の呼び出しでも 1 回目と同じ乱数が先に返る (次の乱数は別の値), When `allocateTag` を再度呼ぶ
  - Expected: Then 2 回目の戻り値は 1 回目と異なる Tag である (DR-05、仕様 5 章の置換の行)

#### T-02-13: 乱数だけが同じ既存 Tag は重複とみなさない

- [x] **T-02-13-01**: 乱数は同じでも、日時とマシン ID が違う既存 Tag だけなら、1 回目の Tag を返す
  - Target: `allocateTag`
  - Scenario: Given `existingTags` に、乱数が 1 回目と同じ `0123456789abcdef` で、日時とマシン ID が違う Tag (`20260101000000-ffffffff-0123456789abcdef`) だけがあり、1 回目の乱数が `0123456789abcdef`, When `allocateTag` を呼ぶ
  - Expected: Then 1 回目の乱数で作った Tag を返し、乱数の取得は 1 回だけである (TAG-R-006: Tag 全体で比べる。乱数部分だけの一致は重複でない)

#### T-02-14: 日時またはマシン ID の片方だけが違う既存 Tag は重複とみなさない

- [x] **T-02-14-01**: 乱数とマシン ID が同じで、日時だけが違う既存 Tag だけなら、1 回目の Tag を返す
  - Target: `allocateTag`
  - Scenario: Given `existingTags` に、乱数とマシン ID が 1 回目と同じで、日時だけが違う Tag (`20260101000000-a1b2c3d4-0123456789abcdef`) だけがあり、1 回目の乱数が `0123456789abcdef`, When `allocateTag` を呼ぶ
  - Expected: Then 1 回目の乱数で作った Tag を返し、乱数の取得は 1 回だけである (TAG-R-006: 日時を除いた比較にならない)

- [x] **T-02-14-02**: 乱数と日時が同じで、マシン ID だけが違う既存 Tag だけなら、1 回目の Tag を返す
  - Target: `allocateTag`
  - Scenario: Given `existingTags` に、乱数と日時が 1 回目と同じで、マシン ID だけが違う Tag (`20261122090503-ffffffff-0123456789abcdef`) だけがあり、1 回目の乱数が `0123456789abcdef`, When `allocateTag` を呼ぶ
  - Expected: Then 1 回目の乱数で作った Tag を返し、乱数の取得は 1 回だけである (TAG-R-006: マシン ID を除いた比較にならない)

---

## T-03: MachineIdProvider 実装 (SqliteStore, settings)

### [正常] Normal Cases

#### T-03-01: 初回にマシン ID を生成して保存する

- [x] **T-03-01-01**: `settings` に行がなければ小文字 16 進 8 桁を返す
  - Target: `MachineIdProvider.machineId` (`SqliteStore`)
  - Scenario: Given 新規作成した DB で `settings` に `machine_id` の行がない, When `machineId()` を初回に呼ぶ
  - Expected: Then 戻り値が `^[0-9a-f]{8}$` に一致する (TAG-R-009)

- [x] **T-03-01-02**: 生成した値を `settings` に key `machine_id` の 1 行として保存する
  - Target: `MachineIdProvider.machineId` (`SqliteStore`)
  - Scenario: Given 新規作成した DB で `settings` に `machine_id` の行がない, When `machineId()` を初回に呼ぶ
  - Expected: Then `settings` に key が `machine_id` で value が戻り値と等しい行がちょうど 1 件ある (TAG-R-009, TAG-DD-03, IDX-DD-01)

- [x] **T-03-01-03**: 生成するマシン ID は、毎回、小文字 16 進 8 桁である (256 回の生成)
  - Target: `MachineIdProvider.machineId` (`SqliteStore`
  - Scenario: Given 新規作成した DB を、別々に 256 回開き、それぞれで `machineId()` を 1 回ずつ呼ぶ, When 256 個の値を集める
  - Expected: Then すべての値が `^[0-9a-f]{8}$` に一致し、2 種類以上の値がある (TAG-R-009: 1 バイトを 2 桁に 0 埋めする。0 埋めが欠けると、約 2 割の確率で 7 桁になる)

#### T-03-02: 保存済みのマシン ID を返す

- [x] **T-03-02-01**: `settings` に `a1b2c3d4` が保存済みならその値を返す
  - Target: `MachineIdProvider.machineId` (`SqliteStore`)
  - Scenario: Given `settings` に key `machine_id`、value `a1b2c3d4` の行 (id が 1) がある, When `machineId()` を呼ぶ
  - Expected: Then `a1b2c3d4` を返し、新しい値を作らない (TAG-R-008)

- [x] **T-03-02-02**: 行の `id` が 1 以外でも key で値を読む
  - Target: `MachineIdProvider.machineId` (`SqliteStore`)
  - Scenario: Given `settings` に key `machine_id`、value `a1b2c3d4` の行 (id が 42) がある, When `machineId()` を呼ぶ
  - Expected: Then `a1b2c3d4` を返す (実装 §3 手順 1: `id` を仮定せず、key で直接読む)

#### T-03-03: 再オープンしても同じ値を返す

- [x] **T-03-03-01**: DB を閉じて同じパスで開き直すと初回と同じ値を返す
  - Target: `MachineIdProvider.machineId` (`SqliteStore`)
  - Scenario: Given 一時ファイルの DB で 1 回目に `machineId()` を呼んで値を得て、`SqliteStore` を開き直した, When 開き直した `SqliteStore` で `machineId()` を呼ぶ
  - Expected: Then 1 回目と同じ値を返す (TAG-R-008, AC-011)

#### T-03-04: 同じインスタンスでは同じ値を返す

- [x] **T-03-04-01**: 同じインスタンスで 2 回呼ぶと同じ値を返す
  - Target: `MachineIdProvider.machineId` (`SqliteStore`)
  - Scenario: Given 新規作成した DB の同じ `MachineIdProvider` インスタンス, When `machineId()` を 2 回呼ぶ
  - Expected: Then 2 回の戻り値が等しい (実装 §3 手順 4)

- [x] **T-03-04-02**: 保存済みの値を読んだあとも、同じインスタンスはその値を返す
  - Target: `MachineIdProvider.machineId` (`SqliteStore`
  - Scenario: Given `settings` に `a1b2c3d4` が保存済みで、`machineId()` を 1 回呼んだあと、その行の value を別の有効な値 (`ffffffff`) に直接書き換えた, When 同じインスタンスで `machineId()` をもう一度呼ぶ
  - Expected: Then 1 回目と同じ `a1b2c3d4` を返す。DB を読み直さない (実装 §3 手順 4: 読み出した値もインスタンス内にキャッシュする)

### [異常] Error Cases

#### T-03-05: 保存済みの値が書式に合わない

- [x] **T-03-05-01**: 保存済みの値が 16 進以外の文字 (`zzzzzzzz`) なら `StorageException` を投げる
  - Target: `MachineIdProvider.machineId` (`SqliteStore`)
  - Scenario: Given `settings` の `machine_id` の value が `zzzzzzzz`, When `machineId()` を呼ぶ
  - Expected: Then `StorageException` を投げ、値を返さない (TAG-R-010)

- [x] **T-03-05-02**: 保存済みの値が 7 桁 (`a1b2c3d`) なら `StorageException` を投げる
  - Target: `MachineIdProvider.machineId` (`SqliteStore`)
  - Scenario: Given `settings` の `machine_id` の value が `a1b2c3d`, When `machineId()` を呼ぶ
  - Expected: Then `StorageException` を投げ、値を返さない (TAG-R-010)

- [x] **T-03-05-03**: 保存済みの値が大文字 (`A1B2C3D4`) なら `StorageException` を投げる
  - Target: `MachineIdProvider.machineId` (`SqliteStore`)
  - Scenario: Given `settings` の `machine_id` の value が `A1B2C3D4`, When `machineId()` を呼ぶ
  - Expected: Then `StorageException` を投げ、値を返さない (TAG-R-010)

- [x] **T-03-05-04**: 保存済みの値が 9 桁 (`a1b2c3d4e`) なら `StorageException` を投げる
  - Target: `MachineIdProvider.machineId` (`SqliteStore`)
  - Scenario: Given `settings` の `machine_id` の value が `a1b2c3d4e`, When `machineId()` を呼ぶ
  - Expected: Then `StorageException` を投げ、値を返さない (TAG-R-010)

- [x] **T-03-05-05**: 保存済みの値が空文字なら `StorageException` を投げる
  - Target: `MachineIdProvider.machineId` (`SqliteStore`)
  - Scenario: Given `settings` の `machine_id` の value が空文字, When `machineId()` を呼ぶ
  - Expected: Then `StorageException` を投げ、値を返さない (TAG-R-010)

- [x] **T-03-05-06**: 保存済みの値の末尾に改行があれば `StorageException` を投げる
  - Target: `MachineIdProvider.machineId` (`SqliteStore`
  - Scenario: Given `settings` の `machine_id` の value が `a1b2c3d4
` (8 桁の後ろに改行), When `machineId()` を呼ぶ
  - Expected: Then `StorageException` を投げる。改行を取り除かず、新しい値を作らない (TAG-R-010)

#### T-03-06: 不正な値は作り直さない

- [x] **T-03-06-01**: 不正な値のとき既存の行を変更せず、新しい行も作らない
  - Target: `MachineIdProvider.machineId` (`SqliteStore`)
  - Scenario: Given `settings` の `machine_id` の value が `zzzzzzzz`, When `machineId()` を呼んで `StorageException` を受ける
  - Expected: Then `settings` の `machine_id` の行は 1 件のままで、value が `zzzzzzzz` のままである (TAG-R-010, TAG-DD-04)

#### T-03-07: DB が壊れている

- [x] **T-03-07-01**: SQLite でないバイト列のファイルを `SqliteStore.open` で開くと `StorageException` を投げる
  - Target: `SqliteStore.open`
  - Scenario: Given SQLite の形式でないバイト列を書いたファイル, When そのパスで `SqliteStore.open` を呼ぶ
  - Expected: Then `StorageException` を投げ、マシン ID を返す手段を渡さない (TAG-R-010, TAG-DD-04)

#### T-03-08: 保存に失敗する

- [x] **T-03-08-01**: 保存に失敗したら値を返さず `StorageException` を投げる
  - Target: `MachineIdProvider.machineId` (`SqliteStore`)
  - Scenario: Given `settings` に `machine_id` の行がなく、INSERT が失敗する接続, When `machineId()` を呼ぶ
  - Expected: Then `StorageException` を投げ、値を返さない (TAG-R-009)

- [x] **T-03-08-02**: 保存に失敗したとき `machine_id` の行を残さない
  - Target: `MachineIdProvider.machineId` (`SqliteStore`)
  - Scenario: Given `settings` に `machine_id` の行がなく、INSERT が失敗する接続, When `machineId()` を呼んで `StorageException` を受ける
  - Expected: Then `settings` に key が `machine_id` の行が 0 件である (IDX-DD-01: トランザクションで途中の状態を残さない)

#### T-03-09: key の重複を拒否する

- [x] **T-03-09-01**: key `machine_id` の行が既にあるとき、同じ key の 2 行目の INSERT は拒否される
  - Target: `SqliteStore` (`settings_key` ユニークインデックス)
  - Scenario: Given `settings` に key `machine_id` の行が 1 件あり, When 同じ key `machine_id` の行を INSERT する
  - Expected: Then 一意制約違反で INSERT が失敗し、`settings` の `machine_id` の行は 1 件のままである (db-migration.md §2)

#### T-03-14: SqliteException 以外の例外で保存に失敗する

- [x] **T-03-14-01**: 保存の INSERT が `SqliteException` 以外の例外を投げたら、ROLLBACK して元の例外をそのまま投げる
  - Target: `MachineIdProvider.machineId` (`SqliteStore`)
  - Scenario: Given `settings` に `machine_id` の行がなく、INSERT が `StateError` を投げる接続, When `machineId()` を呼ぶ
  - Expected: Then `ROLLBACK` を実行し、`StateError` を `StorageException` に変えずにそのまま投げる。値を返さず、キャッシュもしない (TAG-R-009, IDX-DD-01: プログラムの誤りを保存の失敗に見せない)

#### T-03-15: 保存の失敗で ROLLBACK も失敗する

- [x] **T-03-15-01**: INSERT と ROLLBACK の両方が失敗しても、INSERT の失敗理由を `StorageException` で伝える
  - Target: `MachineIdProvider.machineId` (`SqliteStore`)
  - Scenario: Given `settings` に `machine_id` の行がなく、INSERT も続く `ROLLBACK` も `SqliteException` を投げる接続, When `machineId()` を呼ぶ
  - Expected: Then `StorageException` を投げ、そのメッセージは INSERT の失敗理由を含む。`ROLLBACK` の例外で置き換えない。値を返さない (TAG-R-009, IDX-DD-01)

#### T-03-16: マシン ID の読み出しに失敗する

- [x] **T-03-16-01**: `machine_id` の値を読む SELECT が失敗したら、`StorageException` を投げる
  - Target: `MachineIdProvider.machineId` (`SqliteStore`)
  - Scenario: Given `machine_id` の値を読む SELECT が `SqliteException` を投げる接続, When `machineId()` を呼ぶ
  - Expected: Then `StorageException` を投げ、そのメッセージは読み出しに失敗したこととして SQLite のメッセージを含む。値を返さず、新しい値を作って保存しない (BEGIN も INSERT も実行しない)(TAG-R-010, TAG-DD-04)

> T-03-16-02 は欠番とする。値の読み取りが `SELECT value … WHERE key = ?` の 1 本になり (db-migration.md v1.1.2)、「行を探す SELECT」と「値を読む SELECT」を分けて確認する意味がなくなったため。

#### T-03-17: 保存の開始 (BEGIN) に失敗する

- [x] **T-03-17-01**: 保存のトランザクションを開始する `BEGIN` が失敗したら、`StorageException` を投げる
  - Target: `MachineIdProvider.machineId` (`SqliteStore`)
  - Scenario: Given `settings` に `machine_id` の行がなく、`BEGIN` が `SqliteException` を投げる接続, When `machineId()` を呼ぶ
  - Expected: Then `StorageException` を投げ、そのメッセージは保存に失敗したこととして SQLite のメッセージを含む。`SqliteException` をそのまま投げない。INSERT も ROLLBACK も実行せず (開始できなかったトランザクションを巻き戻さない。すでに開いている別のトランザクションを巻き戻すおそれがある)、値を返さず、キャッシュもしない (TAG-R-009, IDX-DD-01)

#### T-03-18: SqliteException 以外の例外で保存に失敗し、ROLLBACK も失敗する

- [x] **T-03-18-01**: INSERT が `SqliteException` 以外の例外を投げ、ROLLBACK も失敗しても、元の例外をそのまま投げる
  - Target: `MachineIdProvider.machineId` (`SqliteStore`)
  - Scenario: Given `settings` に `machine_id` の行がなく、INSERT が `StateError` を投げ、続く `ROLLBACK` が `SqliteException` を投げる接続, When `machineId()` を呼ぶ
  - Expected: Then `StateError` をそのまま投げる。`ROLLBACK` の `SqliteException` で置き換えず、`StorageException` にも変えない。`ROLLBACK` は試みる。値を返さず、キャッシュもしない (TAG-R-009, IDX-DD-01)

#### T-03-19: 保存の確定 (COMMIT) に失敗する

- [x] **T-03-19-01**: `COMMIT` が `SqliteException` を投げたら、ROLLBACK して `StorageException` を投げる
  - Target: `MachineIdProvider.machineId` (`SqliteStore`)
  - Scenario: Given `settings` に `machine_id` の行がなく、`COMMIT` が `SqliteException` を投げる接続, When `machineId()` を呼ぶ
  - Expected: Then `StorageException` を投げ、そのメッセージは保存に失敗したこととして SQLite のメッセージを含む。書き込みは `BEGIN`、`INSERT`、`COMMIT`、`ROLLBACK` の順に実行される。値を返さず、キャッシュもしない (TAG-R-009, IDX-DD-01: 確定できなかった書き込みを残さない)

- [x] **T-03-19-02**: `COMMIT` が `SqliteException` 以外の例外を投げたら、ROLLBACK して元の例外をそのまま投げる
  - Target: `MachineIdProvider.machineId` (`SqliteStore`)
  - Scenario: Given `settings` に `machine_id` の行がなく、`COMMIT` が `StateError` を投げる接続, When `machineId()` を呼ぶ
  - Expected: Then `StateError` を `StorageException` に変えずにそのまま投げる。書き込みは `BEGIN`、`INSERT`、`COMMIT`、`ROLLBACK` の順に実行される。値を返さず、キャッシュもしない (TAG-R-009, IDX-DD-01)

#### T-03-20: 保存済みの値が文字列でない

- [x] **T-03-20-01**: 保存済みの値が `BLOB` なら、`StorageException` を投げる
  - Target: `MachineIdProvider.machineId` (`SqliteStore`)
  - Scenario: Given `settings` の `machine_id` の value が `BLOB` (`a1b2c3d4` のバイト列、`x'6131623263336434'`), When `machineId()` を呼ぶ
  - Expected: Then `StorageException` を投げ (`TypeError` などの別の例外にしない)、そのメッセージは保存済みの値が不正であることを示す。新しい値を作らず、`machine_id` の行を変更せず、値を返さず、キャッシュもしない (TAG-R-010, TAG-DD-04)

- [x] **T-03-20-02**: 保存済みの値が `NULL` なら、`StorageException` を投げる
  - Target: `MachineIdProvider.machineId` (`SqliteStore`)
  - Scenario: Given `value` 列が `NULL` を許す既存の `settings` テーブル (`SqliteStore.open` が `CREATE TABLE IF NOT EXISTS` で作り直さない) に、`machine_id` の value が `NULL` の行があり, When `machineId()` を呼ぶ
  - Expected: Then `StorageException` を投げ (`TypeError` などの別の例外にしない)、そのメッセージは保存済みの値が不正であることを示す。新しい値を作らず、`machine_id` の行を変更せず、値を返さず、キャッシュもしない (TAG-R-010, TAG-DD-04)

#### T-03-21: 保存済みの値が UTF-8 として読めない

- [x] **T-03-21-01**: 保存済みの値が不正な UTF-8 の `TEXT` なら、`StorageException` を投げる
  - Target: `MachineIdProvider.machineId` (`SqliteStore`)
  - Scenario: Given `settings` の `machine_id` の value が、UTF-8 として不正なバイト列を `TEXT` にしたもの (`CAST(x'ff' AS TEXT)`), When `machineId()` を呼ぶ
  - Expected: Then `StorageException` を投げ (`FormatException` などの別の例外にしない)、そのメッセージは保存済みの値が不正であることを示す。新しい値を作らず、`machine_id` の行を変更せず、値を返さず、キャッシュもしない (TAG-R-010, TAG-DD-04)

### [エッジケース] Edge Cases

#### T-03-10: 他の設定だけがある DB

- [x] **T-03-10-01**: `machine_id` 以外の行だけがあれば、マシン ID を新しく生成して保存する
  - Target: `MachineIdProvider.machineId` (`SqliteStore`)
  - Scenario: Given `settings` に key `other`、value `x` の行だけがある, When `machineId()` を呼ぶ
  - Expected: Then `^[0-9a-f]{8}$` に一致する値を返し、`settings` に key `machine_id` の行ができる (TAG-R-009: 保存領域は正常でマシン ID が未保存)

- [x] **T-03-10-02**: マシン ID を生成しても `machine_id` 以外の行を変更しない
  - Target: `MachineIdProvider.machineId` (`SqliteStore`)
  - Scenario: Given `settings` に key `other`、value `x` の行だけがある, When `machineId()` を呼ぶ
  - Expected: Then key `other` の行の value が `x` のままである (TAG-R-009)

#### T-03-11: 保存領域が削除された後の起動

- [x] **T-03-11-01**: DB ファイルを削除して開き直すと、新しいマシン ID を生成して保存する
  - Target: `MachineIdProvider.machineId` (`SqliteStore`)
  - Scenario: Given 一時ファイルの DB で 1 回目に `machineId()` を呼んだ後、DB ファイルを削除した, When 同じパスで `SqliteStore.open` して `machineId()` を呼ぶ
  - Expected: Then エラーにならず、`^[0-9a-f]{8}$` に一致する値を返し、`settings` に `machine_id` の行が 1 件ある (TAG-DD-04: 許容する)

#### T-03-12: 保存済みの値の境界

- [x] **T-03-12-01**: 保存済みの値 `00000000` は有効な値として返す
  - Target: `MachineIdProvider.machineId` (`SqliteStore`)
  - Scenario: Given `settings` の `machine_id` の value が `00000000`, When `machineId()` を呼ぶ
  - Expected: Then `00000000` を返し、`StorageException` を投げない (TAG-R-010 の誤検出を防ぐ)

#### T-03-13: 2 回目の呼び出しで行を増やさない

- [x] **T-03-13-01**: 生成後にもう一度呼んでも `machine_id` の行は 1 件のままである
  - Target: `MachineIdProvider.machineId` (`SqliteStore`)
  - Scenario: Given 新規作成した DB で `machineId()` を 1 回呼んで生成済み, When `machineId()` をもう一度呼ぶ
  - Expected: Then `settings` の `machine_id` の行が 1 件のままである (TAG-R-008)

---

## Coverage Check

| Source item                                                       | Task ID(s)                                                                                                             |
| ----------------------------------------------------------------- | ---------------------------------------------------------------------------------------------------------------------- |
| TAG-R-001                                                         | T-01-04-01〜02, T-01-05-01〜05, T-01-06-01〜04, T-01-08-01〜02, T-01-09-01〜03, T-02-06-01, T-02-08-01, T-01-06-05〜08 |
| TAG-R-002                                                         | T-01-01-01, T-01-01-03, T-01-01-04, T-01-07-01, T-01-08-01〜02                                                         |
| TAG-R-003                                                         | T-01-03-01                                                                                                             |
| TAG-R-004                                                         | T-01-01-02, T-01-02-01                                                                                                 |
| TAG-R-005                                                         | T-02-01-01〜02, T-02-10-01, T-02-12-01                                                                                 |
| TAG-R-006                                                         | T-02-02-01〜02, T-02-09-01, T-02-13-01, T-02-14-01〜02                                                                 |
| TAG-R-007                                                         | T-02-05-01〜02                                                                                                         |
| TAG-R-008                                                         | T-03-02-01〜02, T-03-03-01, T-03-13-01, T-03-04-02                                                                     |
| TAG-R-009                                                         | T-03-01-01〜02, T-03-08-01, T-03-10-01〜02, T-03-14-01, T-03-15-01, T-03-17-01, T-03-18-01, T-03-19-01〜02, T-03-01-03 |
| TAG-R-010                                                         | T-03-05-01〜05, T-03-06-01, T-03-07-01, T-03-12-01, T-03-16-01, T-02-07-01, T-03-20-01〜02, T-03-05-06, T-03-21-01     |
| TAG-DD-01 (再生成の上限 3 回)                                     | T-02-05-01〜02, T-02-09-01〜02                                                                                         |
| TAG-DD-02 (確認先は予約一覧と対応表の両方)                        | T-02-02-01 (注: allocateTag には和集合の `existingTags` として渡る)                                                    |
| TAG-DD-03 (マシン ID は SQLite に保存)                            | T-03-01-02, T-03-03-01                                                                                                 |
| TAG-DD-04 (保存領域なしは新規、読めない/壊れは error)             | T-03-11-01, T-03-06-01, T-03-07-01, T-03-16-01, T-03-20-01〜02, T-03-21-01                                             |
| IDX-DD-01 (SQLite、トランザクション)                              | T-03-01-02, T-03-08-02, T-03-14-01, T-03-15-01, T-03-17-01, T-03-18-01, T-03-19-01〜02                                 |
| IDX-DD-08 (再生成は 3 回まで、超えたら失敗)                       | T-02-05-01〜02, T-02-09-01〜02                                                                                         |
| DR-04 (書式、Group、マシン ID、重複で乱数再生成)                  | T-01-01-01, T-01-01-04, T-01-02-01, T-02-02-01, T-03-01-01〜02                                                         |
| DR-05 (置換でも同じ手順で新しい Tag)                              | T-02-12-01                                                                                                             |
| SCH-E-32 / SCH-R-007 (対応表にだけある Tag も重複)                | T-02-02-01, T-02-05-01                                                                                                 |
| Edge: 秒未満の切り捨て                                            | T-01-07-01                                                                                                             |
| Edge: 年が範囲外                                                  | T-01-04-01〜02                                                                                                         |
| Edge: マシン ID の桁数/大文字/16 進以外                           | T-01-05-01〜05                                                                                                         |
| Edge: 乱数の桁数/大文字/16 進以外                                 | T-01-06-01〜04, T-01-06-05〜08                                                                                         |
| Edge: 夏時間で同じローカル秒が 2 回                               | T-01-10-01                                                                                                             |
| Edge: 夏時間/タイムゾーン変更をまたぐと順序が一致しない場合がある | 対象外 (「場合がある」という非保証の記述で、期待値を固定できない)                                                      |
| Edge: 生成した Tag が予約一覧に既にある                           | T-02-02-01                                                                                                             |
| Edge: 生成した Tag が対応表にだけある                             | T-02-02-01 (和集合の `existingTags` による。仕様の曖昧点として報告)                                                    |
| Edge: 3 回の再生成後も重複                                        | T-02-05-01                                                                                                             |
| Edge: 置換のために Tag を生成する                                 | T-02-12-01                                                                                                             |
| Edge: Tag の実機での上限が 40 文字未満                            | 対象外 (実機での手動検証)                                                                                              |
| Edge: 予約件数の上限 N まで add で登録する                        | 対象外 (AC-009、手動検証)。コードが件数を制限しない点は T-02-11-01                                                     |
| Edge: N+1 件目の登録が失敗する                                    | 対象外 (結果の記録のみ、合否に含めない)                                                                                |
| Edge: 保存領域が存在するのに読めない、または壊れている            | T-03-05-01〜05, T-03-07-01, T-03-06-01                                                                                 |
| Edge: 2 回目の起動                                                | T-03-03-01, T-03-04-01                                                                                                 |
| Edge: 保存領域が削除された後の起動                                | T-03-11-01                                                                                                             |
| Edge: 2 つのプロセスが同時に初めて起動する                        | 対象外 (並行実行は対象外とする決定)                                                                                    |
| 実装 §4: `key` の重複を拒否 (ユニークインデックス)                | T-03-09-01                                                                                                             |
| 実装 §3: `id` を仮定せず、key で直接読む                          | T-03-02-02                                                                                                             |
| 実装 §3: 読み取りに失敗したら `StorageException`                  | T-03-16-01                                                                                                             |
| 実装 §3: 保存に失敗したとき ROLLBACK し、値を返さない             | T-03-08-01〜02, T-03-14-01, T-03-15-01, T-03-17-01, T-03-18-01, T-03-19-01〜02                                         |

**[UNCOVERED]**: なし。

---

## Category Balance

| Test Target                     | Normal | Error | Edge | Result |
| ------------------------------- | -----: | ----: | ---: | ------ |
| T-01: `generateTag`             |      6 |    15 |    7 | [OK]   |
| T-02: `allocateTag`             |      5 |     5 |    8 | [OK]   |
| T-03: `MachineIdProvider` (MID) |      8 |    21 |    5 | [OK]   |

- T-01: `Normal: 6 | Error: 15 | Edge: 7` (T-01-09-03 は、T-01 の完了後に、T-03 のレビューの指摘から追加した)
- T-02: `Normal: 5 | Error: 5 | Edge: 8` (T-02-04 は削除。番号は欠番。T-02-13〜14 は、T-02 の完了後に、レビューの指摘から追加した)
- T-03: `Normal: 8 | Error: 21 | Edge: 5` (T-03-14〜20 は、T-03 の完了後に、レビューの指摘から追加した。番号は Error の節の末尾に並ぶ。T-03-16-02 は欠番)

---

<!--
Task ID Format: T-<TestTarget>-<Scenario>-<Case>
- T-01 = TAG (generateTag), T-02 = TAL (allocateTag), T-03 = MID (MachineIdProvider 実装)
-->
