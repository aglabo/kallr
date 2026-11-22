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

| Test Target                                          | Scenarios | Cases | Status      |
|------------------------------------------------------|-----------|-------|-------------|
| T-01: `generateTag` (TAG)                            | 10        | 23    | in progress |
| T-02: `allocateTag` (TAL)                            | 12        | 16    | pending     |
| T-03: `MachineIdProvider` 実装 / `SqliteStore` (MID) | 13        | 21    | pending     |

---

## T-01: generateTag

### [正常] Normal Cases

#### T-01-01: 登録時刻・マシン ID・乱数から 40 文字の Tag を組み立てる

- [ ] **T-01-01-01**: 有効な 3 入力から決められた書式の Tag を返す
  - Target: `generateTag`
  - Scenario: Given registeredAt が 2026-11-22 09:05:03 (ローカル)、machineId が `a1b2c3d4`、random が `0123456789abcdef`, When `generateTag` を呼ぶ
  - Expected: Then `20261122090503-a1b2c3d4-0123456789abcdef` を返す (TAG-R-002)

- [ ] **T-01-01-02**: 返した Tag は常に 40 文字である
  - Target: `generateTag`
  - Scenario: Given registeredAt が 2026-11-22 09:05:03 (ローカル)、machineId が `a1b2c3d4`、random が `0123456789abcdef`, When `generateTag` を呼ぶ
  - Expected: Then 返した Tag の長さが 40 で、文書上の上限 64 文字以下である (TAG-R-004)

- [ ] **T-01-01-03**: 月日時分秒が 1 桁の値でもゼロ埋めの 2 桁にする
  - Target: `generateTag`
  - Scenario: Given registeredAt が 2026-01-02 03:04:05 (ローカル)、machineId が `a1b2c3d4`、random が `0123456789abcdef`, When `generateTag` を呼ぶ
  - Expected: Then 日時部分が `20260102030405` になる (TAG-R-002)

- [ ] **T-01-01-04**: ローカル日時を UTC に変換せずに使う
  - Target: `generateTag`
  - Scenario: Given registeredAt が 2026-12-31 23:59:59 のローカル日時 (isUtc が false)、machineId が `a1b2c3d4`、random が `0123456789abcdef`, When `generateTag` を呼ぶ
  - Expected: Then 日時部分が `20261231235959` になる (DR-04 決定 2、実装 §2.2 の `toUtc()` 不使用)

#### T-01-02: Group は固定値 kallr である

- [ ] **T-01-02-01**: 定数 `kGroup` は `kallr` で、Group の上限 64 文字以下である
  - Target: `kGroup`
  - Scenario: Given `models.dart` の定数 `kGroup`, When 値を参照する
  - Expected: Then `kallr` (5 文字) と等しい (TAG-R-004, DR-04 決定 1)

#### T-01-03: 同じ入力からは同じ Tag を返す

- [ ] **T-01-03-01**: 同じ入力で 2 回呼ぶと同じ Tag を返す
  - Target: `generateTag`
  - Scenario: Given registeredAt が 2026-11-22 09:05:03 (ローカル)、machineId が `a1b2c3d4`、random が `0123456789abcdef`, When 同じ入力で `generateTag` を 2 回呼ぶ
  - Expected: Then 2 回の戻り値が等しい (TAG-R-003)

### [異常] Error Cases

#### T-01-04: 登録時刻の年が範囲外である

- [ ] **T-01-04-01**: 年が -1 なら `ArgumentError` を投げる
  - Target: `generateTag`
  - Scenario: Given registeredAt の年が -1、machineId が `a1b2c3d4`、random が `0123456789abcdef`, When `generateTag` を呼ぶ
  - Expected: Then `ArgumentError` を投げ、Tag を返さない (TAG-R-001)

- [ ] **T-01-04-02**: 年が 10000 なら `ArgumentError` を投げる
  - Target: `generateTag`
  - Scenario: Given registeredAt の年が 10000、machineId が `a1b2c3d4`、random が `0123456789abcdef`, When `generateTag` を呼ぶ
  - Expected: Then `ArgumentError` を投げ、Tag を返さない (TAG-R-001)

#### T-01-05: マシン ID の書式が不正である

- [ ] **T-01-05-01**: マシン ID が 7 桁なら `ArgumentError` を投げる
  - Target: `generateTag`
  - Scenario: Given machineId が `a1b2c3d` (7 桁)、有効な registeredAt と random, When `generateTag` を呼ぶ
  - Expected: Then `ArgumentError` を投げる。補正しない (TAG-R-001)

- [ ] **T-01-05-02**: マシン ID が 9 桁なら `ArgumentError` を投げる
  - Target: `generateTag`
  - Scenario: Given machineId が `a1b2c3d4e` (9 桁)、有効な registeredAt と random, When `generateTag` を呼ぶ
  - Expected: Then `ArgumentError` を投げる。切り詰めない (TAG-R-001)

- [ ] **T-01-05-03**: マシン ID が大文字なら `ArgumentError` を投げる
  - Target: `generateTag`
  - Scenario: Given machineId が `A1B2C3D4`、有効な registeredAt と random, When `generateTag` を呼ぶ
  - Expected: Then `ArgumentError` を投げる。小文字に直さない (TAG-R-001)

- [ ] **T-01-05-04**: マシン ID に 16 進以外の文字があれば `ArgumentError` を投げる
  - Target: `generateTag`
  - Scenario: Given machineId が `g1b2c3d4`、有効な registeredAt と random, When `generateTag` を呼ぶ
  - Expected: Then `ArgumentError` を投げる (TAG-R-001)

- [ ] **T-01-05-05**: マシン ID が空文字なら `ArgumentError` を投げる
  - Target: `generateTag`
  - Scenario: Given machineId が空文字、有効な registeredAt と random, When `generateTag` を呼ぶ
  - Expected: Then `ArgumentError` を投げる。既定値で補わない (TAG-R-001)

#### T-01-06: 乱数の書式が不正である

- [ ] **T-01-06-01**: 乱数が 15 桁なら `ArgumentError` を投げる
  - Target: `generateTag`
  - Scenario: Given random が `0123456789abcde` (15 桁)、有効な registeredAt と machineId, When `generateTag` を呼ぶ
  - Expected: Then `ArgumentError` を投げる (TAG-R-001)

- [ ] **T-01-06-02**: 乱数が 17 桁なら `ArgumentError` を投げる
  - Target: `generateTag`
  - Scenario: Given random が `0123456789abcdef0` (17 桁)、有効な registeredAt と machineId, When `generateTag` を呼ぶ
  - Expected: Then `ArgumentError` を投げる (TAG-R-001)

- [ ] **T-01-06-03**: 乱数が大文字なら `ArgumentError` を投げる
  - Target: `generateTag`
  - Scenario: Given random が `0123456789ABCDEF`、有効な registeredAt と machineId, When `generateTag` を呼ぶ
  - Expected: Then `ArgumentError` を投げる (TAG-R-001)

- [ ] **T-01-06-04**: 乱数に 16 進以外の文字があれば `ArgumentError` を投げる
  - Target: `generateTag`
  - Scenario: Given random が `0123456789abcdeg`、有効な registeredAt と machineId, When `generateTag` を呼ぶ
  - Expected: Then `ArgumentError` を投げる (TAG-R-001)

### [エッジケース] Edge Cases

#### T-01-07: 登録時刻に秒未満がある

- [ ] **T-01-07-01**: 999 ミリ秒は切り上げずに切り捨てる
  - Target: `generateTag`
  - Scenario: Given registeredAt が 2026-11-22 09:05:03.999 (ローカル)、machineId が `a1b2c3d4`、random が `0123456789abcdef`, When `generateTag` を呼ぶ
  - Expected: Then 日時部分が `20261122090503` になる (TAG-R-002)

#### T-01-08: 年の境界値

- [ ] **T-01-08-01**: 年 0 は `0000` として受け入れる
  - Target: `generateTag`
  - Scenario: Given registeredAt が 0000-01-01 00:00:00 (ローカル)、machineId が `a1b2c3d4`、random が `0123456789abcdef`, When `generateTag` を呼ぶ
  - Expected: Then `00000101000000-a1b2c3d4-0123456789abcdef` を返す (TAG-R-001, TAG-R-002)

- [ ] **T-01-08-02**: 年 9999 は `9999` として受け入れる
  - Target: `generateTag`
  - Scenario: Given registeredAt が 9999-12-31 23:59:59 (ローカル)、machineId が `a1b2c3d4`、random が `0123456789abcdef`, When `generateTag` を呼ぶ
  - Expected: Then `99991231235959-a1b2c3d4-0123456789abcdef` を返す (TAG-R-001, TAG-R-002)

#### T-01-09: マシン ID と乱数の有効な境界値

- [ ] **T-01-09-01**: マシン ID `00000000` は有効な値として受け入れる
  - Target: `generateTag`
  - Scenario: Given machineId が `00000000`、有効な registeredAt と random, When `generateTag` を呼ぶ
  - Expected: Then `ArgumentError` を投げず、40 文字の Tag を返す (TAG-R-001 の誤検出を防ぐ)

- [ ] **T-01-09-02**: 乱数 `ffffffffffffffff` は有効な値として受け入れる
  - Target: `generateTag`
  - Scenario: Given random が `ffffffffffffffff`、有効な registeredAt と machineId, When `generateTag` を呼ぶ
  - Expected: Then `ArgumentError` を投げず、40 文字の Tag を返す (TAG-R-001 の誤検出を防ぐ)

#### T-01-10: 夏時間の切り替えで同じローカルの秒が 2 回現れる

- [ ] **T-01-10-01**: 同じ登録時刻でも乱数が違えば異なる Tag になる
  - Target: `generateTag`
  - Scenario: Given 同じ registeredAt (2026-11-01 01:30:00 ローカル) と machineId `a1b2c3d4`、乱数が `0000000000000001` と `0000000000000002` の 2 通り, When 乱数ごとに `generateTag` を呼ぶ
  - Expected: Then 2 つの日時部分は等しく、Tag 全体は異なる (5 章の夏時間の行、区別は乱数部分が担う)

---

## T-02: allocateTag

### [正常] Normal Cases

#### T-02-01: 重複がなければ最初の乱数で作った Tag を採用する

- [ ] **T-02-01-01**: `existingTags` が空なら 1 回目の乱数の Tag を返す
  - Target: `allocateTag`
  - Scenario: Given `existingTags` が空、registeredAt が 2026-11-22 09:05:03、machineId が `a1b2c3d4`、1 回目の乱数が `0123456789abcdef`, When `allocateTag` を呼ぶ
  - Expected: Then `20261122090503-a1b2c3d4-0123456789abcdef` を返す (TAG-R-005)

- [ ] **T-02-01-02**: 重複がなければ `randomHex64` を 1 回だけ呼ぶ
  - Target: `allocateTag`
  - Scenario: Given `existingTags` が空、乱数の取得元が呼び出し回数を数える, When `allocateTag` を呼ぶ
  - Expected: Then `randomHex64` の呼び出しが 1 回である (TAG-R-005)

#### T-02-02: 既存の Tag と重複したら乱数だけを再生成する

- [ ] **T-02-02-01**: 1 回目の Tag が `existingTags` にあれば 2 回目の乱数の Tag を返す
  - Target: `allocateTag`
  - Scenario: Given `existingTags` に 1 回目の乱数 (`0123456789abcdef`) の Tag だけがあり、2 回目の乱数が `fedcba9876543210`, When `allocateTag` を呼ぶ
  - Expected: Then 登録時刻とマシン ID は同じで、乱数部分が `fedcba9876543210` の Tag を返す (TAG-R-006, TAG-DD-02, SCH-E-32, SCH-R-007)

- [ ] **T-02-02-02**: 再生成しても `machineId()` を呼ぶのは 1 回だけである
  - Target: `allocateTag`
  - Scenario: Given `existingTags` に 1 回目の Tag があり、`MachineIdProvider` が呼び出し回数を数える, When `allocateTag` を呼ぶ
  - Expected: Then `machineId()` の呼び出しが 1 回である (TAG-R-006)

#### T-02-03: allocateTag は existingTags を変更しない

- [ ] **T-02-03-01**: 呼び出し後も `existingTags` の内容が変わらない
  - Target: `allocateTag`
  - Scenario: Given `existingTags` に Tag が 1 件あり、重複しない乱数が与えられる, When `allocateTag` を呼ぶ
  - Expected: Then `existingTags` の要素数が 1 のままで、返した Tag が追加されていない (実装 §2.3: 予約一覧と対応表に触れない)

#### T-02-04: 登録時刻は呼び出し側が与えた値を使う

- [ ] **T-02-04-01**: `clock` が別の時刻を返しても `registeredAt` 引数の時刻を使う
  - Target: `allocateTag`
  - Scenario: Given `registeredAt` が 2026-11-22 09:05:03 で、`FakeClock` が 2030-01-01 00:00:00 を返す, When `allocateTag` を呼ぶ
  - Expected: Then Tag の日時部分が `20261122090503` になる (実装 §2.3: 呼び出し側が 1 回だけ得た値をループ中は変えない)

### [異常] Error Cases

#### T-02-05: 4 回とも重複した

- [ ] **T-02-05-01**: 4 回とも重複したら `DuplicateTagException` を `attempts: 4` で投げる
  - Target: `allocateTag`
  - Scenario: Given `existingTags` に 4 つの乱数 (`0000000000000001`〜`0000000000000004`) の Tag がすべてあり、乱数の取得元がこの 4 つをこの順に返す, When `allocateTag` を呼ぶ
  - Expected: Then `DuplicateTagException` を投げ、`attempts` が 4 である。Tag を返さない (TAG-R-007, TAG-DD-01, IDX-DD-08)

- [ ] **T-02-05-02**: 上限に達したら 5 回目の乱数を取得しない
  - Target: `allocateTag`
  - Scenario: Given 前項と同じ `existingTags` と乱数の取得元 (呼び出し回数を数える), When `allocateTag` を呼ぶ
  - Expected: Then `randomHex64` の呼び出しがちょうど 4 回で止まる (TAG-DD-01, IDX-DD-08)

#### T-02-06: 乱数の取得元が不正な値を返した

- [ ] **T-02-06-01**: 乱数が 16 桁の 16 進でなければ `ArgumentError` を伝える
  - Target: `allocateTag`
  - Scenario: Given `existingTags` が空で、乱数の取得元が `xyz` を返す, When `allocateTag` を呼ぶ
  - Expected: Then `ArgumentError` を投げる。再生成で隠さず、Tag を返さない (2.1 失敗は黙って補わない、TAG-R-001)

#### T-02-07: マシン ID を取得できない

- [ ] **T-02-07-01**: `machineId()` が `StorageException` を投げたらそのまま伝える
  - Target: `allocateTag`
  - Scenario: Given `existingTags` が空で、`MachineIdProvider` が `StorageException` を投げる, When `allocateTag` を呼ぶ
  - Expected: Then `StorageException` を投げる。Tag を返さない (TAG-R-010 の伝播)

#### T-02-08: マシン ID が不正な値である

- [ ] **T-02-08-01**: `machineId()` が `ZZZZZZZZ` を返したら `ArgumentError` を伝える
  - Target: `allocateTag`
  - Scenario: Given `existingTags` が空で、`MachineIdProvider` が `ZZZZZZZZ` を返す, When `allocateTag` を呼ぶ
  - Expected: Then `ArgumentError` を投げる。補正しない (TAG-R-001)

### [エッジケース] Edge Cases

#### T-02-09: 3 回目の再生成で成功する (上限の境界)

- [ ] **T-02-09-01**: 最初の 3 回が重複し 4 回目で空きなら 4 回目の Tag を返す
  - Target: `allocateTag`
  - Scenario: Given `existingTags` に乱数 `0000000000000001`〜`0000000000000003` の Tag があり、4 回目の乱数が `0000000000000004`, When `allocateTag` を呼ぶ
  - Expected: Then 乱数部分が `0000000000000004` の Tag を返し、`DuplicateTagException` を投げない (TAG-R-006, TAG-DD-01)

- [ ] **T-02-09-02**: 3 回目の再生成で成功したときの `randomHex64` の呼び出しは 4 回である
  - Target: `allocateTag`
  - Scenario: Given 前項と同じ `existingTags` と乱数の取得元 (呼び出し回数を数える), When `allocateTag` を呼ぶ
  - Expected: Then `randomHex64` の呼び出しが 4 回である (初回 + 再生成 3 回、TAG-DD-01)

#### T-02-10: 日時とマシン ID が同じで乱数だけ違う Tag は重複とみなさない

- [ ] **T-02-10-01**: 乱数部分が違う既存の Tag があっても 1 回目の Tag を採用する
  - Target: `allocateTag`
  - Scenario: Given `existingTags` に同じ日時・同じマシン ID で乱数が `fedcba9876543210` の Tag だけがあり、1 回目の乱数が `0123456789abcdef`, When `allocateTag` を呼ぶ
  - Expected: Then 乱数部分が `0123456789abcdef` の Tag を返し、`randomHex64` は 1 回だけ呼ばれる (TAG-R-005 の誤検出を防ぐ)

#### T-02-11: 予約件数の上限相当の既存 Tag

- [ ] **T-02-11-01**: `existingTags` が 4096 件でも重複しなければ Tag を返す
  - Target: `allocateTag`
  - Scenario: Given `existingTags` に互いに異なる 4096 件の Tag があり、1 回目の乱数がそのどれとも一致しない, When `allocateTag` を呼ぶ
  - Expected: Then 例外を投げずに Tag を返す。コードは件数を制限しない (REQ-F-007、実装 §2.4)

#### T-02-12: 置換でも追加と同じ手順を通る

- [ ] **T-02-12-01**: 同じ登録時刻で 2 回目に呼び、1 回目の Tag が `existingTags` にあれば別の Tag を返す
  - Target: `allocateTag`
  - Scenario: Given 1 回目の `allocateTag` の戻り値を `existingTags` に入れ、2 回目の呼び出しでも 1 回目と同じ乱数が先に返る (次の乱数は別の値), When `allocateTag` を再度呼ぶ
  - Expected: Then 2 回目の戻り値は 1 回目と異なる Tag である (DR-05、5 章の置換の行)

---

## T-03: MachineIdProvider 実装 (SqliteStore, settings)

### [正常] Normal Cases

#### T-03-01: 初回にマシン ID を生成して保存する

- [ ] **T-03-01-01**: `settings` に行がなければ小文字 16 進 8 桁を返す
  - Target: `MachineIdProvider.machineId` (`SqliteStore`)
  - Scenario: Given 新規作成した DB で `settings` に `machine_id` の行がない, When `machineId()` を初回に呼ぶ
  - Expected: Then 戻り値が `^[0-9a-f]{8}$` に一致する (TAG-R-009)

- [ ] **T-03-01-02**: 生成した値を `settings` に key `machine_id` の 1 行として保存する
  - Target: `MachineIdProvider.machineId` (`SqliteStore`)
  - Scenario: Given 新規作成した DB で `settings` に `machine_id` の行がない, When `machineId()` を初回に呼ぶ
  - Expected: Then `settings` に key が `machine_id` で value が戻り値と等しい行がちょうど 1 件ある (TAG-R-009, TAG-DD-03, IDX-DD-01)

#### T-03-02: 保存済みのマシン ID を返す

- [ ] **T-03-02-01**: `settings` に `a1b2c3d4` が保存済みならその値を返す
  - Target: `MachineIdProvider.machineId` (`SqliteStore`)
  - Scenario: Given `settings` に key `machine_id`、value `a1b2c3d4` の行 (id が 1) がある, When `machineId()` を呼ぶ
  - Expected: Then `a1b2c3d4` を返し、新しい値を作らない (TAG-R-008)

- [ ] **T-03-02-02**: 行の `id` が 1 以外でも key から `id` を引いて値を読む
  - Target: `MachineIdProvider.machineId` (`SqliteStore`)
  - Scenario: Given `settings` に key `machine_id`、value `a1b2c3d4` の行 (id が 42) がある, When `machineId()` を呼ぶ
  - Expected: Then `a1b2c3d4` を返す (実装 §3 手順 1、db-migration §2 の物理 ID 経由の読み取り)

#### T-03-03: 再オープンしても同じ値を返す

- [ ] **T-03-03-01**: DB を閉じて同じパスで開き直すと初回と同じ値を返す
  - Target: `MachineIdProvider.machineId` (`SqliteStore`)
  - Scenario: Given 一時ファイルの DB で 1 回目に `machineId()` を呼んで値を得て、`SqliteStore` を開き直した, When 開き直した `SqliteStore` で `machineId()` を呼ぶ
  - Expected: Then 1 回目と同じ値を返す (TAG-R-008, AC-011)

#### T-03-04: 同じインスタンスでは同じ値を返す

- [ ] **T-03-04-01**: 同じインスタンスで 2 回呼ぶと同じ値を返す
  - Target: `MachineIdProvider.machineId` (`SqliteStore`)
  - Scenario: Given 新規作成した DB の同じ `MachineIdProvider` インスタンス, When `machineId()` を 2 回呼ぶ
  - Expected: Then 2 回の戻り値が等しい (実装 §3 手順 4)

### [異常] Error Cases

#### T-03-05: 保存済みの値が書式に合わない

- [ ] **T-03-05-01**: 保存済みの値が 16 進以外の文字 (`zzzzzzzz`) なら `StorageException` を投げる
  - Target: `MachineIdProvider.machineId` (`SqliteStore`)
  - Scenario: Given `settings` の `machine_id` の value が `zzzzzzzz`, When `machineId()` を呼ぶ
  - Expected: Then `StorageException` を投げ、値を返さない (TAG-R-010)

- [ ] **T-03-05-02**: 保存済みの値が 7 桁 (`a1b2c3d`) なら `StorageException` を投げる
  - Target: `MachineIdProvider.machineId` (`SqliteStore`)
  - Scenario: Given `settings` の `machine_id` の value が `a1b2c3d`, When `machineId()` を呼ぶ
  - Expected: Then `StorageException` を投げ、値を返さない (TAG-R-010)

- [ ] **T-03-05-03**: 保存済みの値が大文字 (`A1B2C3D4`) なら `StorageException` を投げる
  - Target: `MachineIdProvider.machineId` (`SqliteStore`)
  - Scenario: Given `settings` の `machine_id` の value が `A1B2C3D4`, When `machineId()` を呼ぶ
  - Expected: Then `StorageException` を投げ、値を返さない (TAG-R-010)

- [ ] **T-03-05-04**: 保存済みの値が 9 桁 (`a1b2c3d4e`) なら `StorageException` を投げる
  - Target: `MachineIdProvider.machineId` (`SqliteStore`)
  - Scenario: Given `settings` の `machine_id` の value が `a1b2c3d4e`, When `machineId()` を呼ぶ
  - Expected: Then `StorageException` を投げ、値を返さない (TAG-R-010)

- [ ] **T-03-05-05**: 保存済みの値が空文字なら `StorageException` を投げる
  - Target: `MachineIdProvider.machineId` (`SqliteStore`)
  - Scenario: Given `settings` の `machine_id` の value が空文字, When `machineId()` を呼ぶ
  - Expected: Then `StorageException` を投げ、値を返さない (TAG-R-010)

#### T-03-06: 不正な値は作り直さない

- [ ] **T-03-06-01**: 不正な値のとき既存の行を変更せず、新しい行も作らない
  - Target: `MachineIdProvider.machineId` (`SqliteStore`)
  - Scenario: Given `settings` の `machine_id` の value が `zzzzzzzz`, When `machineId()` を呼んで `StorageException` を受ける
  - Expected: Then `settings` の `machine_id` の行は 1 件のままで、value が `zzzzzzzz` のままである (TAG-R-010, TAG-DD-04)

#### T-03-07: DB が壊れている

- [ ] **T-03-07-01**: SQLite でないバイト列のファイルを `SqliteStore.open` で開くと `StorageException` を投げる
  - Target: `SqliteStore.open`
  - Scenario: Given SQLite の形式でないバイト列を書いたファイル, When そのパスで `SqliteStore.open` を呼ぶ
  - Expected: Then `StorageException` を投げ、マシン ID を返す手段を渡さない (TAG-R-010, TAG-DD-04)

#### T-03-08: 保存に失敗する

- [ ] **T-03-08-01**: 保存に失敗したら値を返さず `StorageException` を投げる
  - Target: `MachineIdProvider.machineId` (`SqliteStore`)
  - Scenario: Given `settings` に `machine_id` の行がなく、INSERT が失敗する接続, When `machineId()` を呼ぶ
  - Expected: Then `StorageException` を投げ、値を返さない (TAG-R-009)

- [ ] **T-03-08-02**: 保存に失敗したとき `machine_id` の行を残さない
  - Target: `MachineIdProvider.machineId` (`SqliteStore`)
  - Scenario: Given `settings` に `machine_id` の行がなく、INSERT が失敗する接続, When `machineId()` を呼んで `StorageException` を受ける
  - Expected: Then `settings` に key が `machine_id` の行が 0 件である (IDX-DD-01: トランザクションで途中の状態を残さない)

#### T-03-09: key の重複を拒否する

- [ ] **T-03-09-01**: key `machine_id` の行が既にあるとき、同じ key の 2 行目の INSERT は拒否される
  - Target: `SqliteStore` (`settings_key` ユニークインデックス)
  - Scenario: Given `settings` に key `machine_id` の行が 1 件あり, When 同じ key `machine_id` の行を INSERT する
  - Expected: Then 一意制約違反で INSERT が失敗し、`settings` の `machine_id` の行は 1 件のままである (db-migration §2)

### [エッジケース] Edge Cases

#### T-03-10: 他の設定だけがある DB

- [ ] **T-03-10-01**: `machine_id` 以外の行だけがあれば、マシン ID を新しく生成して保存する
  - Target: `MachineIdProvider.machineId` (`SqliteStore`)
  - Scenario: Given `settings` に key `other`、value `x` の行だけがある, When `machineId()` を呼ぶ
  - Expected: Then `^[0-9a-f]{8}$` に一致する値を返し、`settings` に key `machine_id` の行ができる (TAG-R-009: 保存領域は正常でマシン ID が未保存)

- [ ] **T-03-10-02**: マシン ID を生成しても `machine_id` 以外の行を変更しない
  - Target: `MachineIdProvider.machineId` (`SqliteStore`)
  - Scenario: Given `settings` に key `other`、value `x` の行だけがある, When `machineId()` を呼ぶ
  - Expected: Then key `other` の行の value が `x` のままである (TAG-R-009)

#### T-03-11: 保存領域が削除された後の起動

- [ ] **T-03-11-01**: DB ファイルを削除して開き直すと、新しいマシン ID を生成して保存する
  - Target: `MachineIdProvider.machineId` (`SqliteStore`)
  - Scenario: Given 一時ファイルの DB で 1 回目に `machineId()` を呼んだ後、DB ファイルを削除した, When 同じパスで `SqliteStore.open` して `machineId()` を呼ぶ
  - Expected: Then エラーにならず、`^[0-9a-f]{8}$` に一致する値を返し、`settings` に `machine_id` の行が 1 件ある (TAG-DD-04: 許容する)

#### T-03-12: 保存済みの値の境界

- [ ] **T-03-12-01**: 保存済みの値 `00000000` は有効な値として返す
  - Target: `MachineIdProvider.machineId` (`SqliteStore`)
  - Scenario: Given `settings` の `machine_id` の value が `00000000`, When `machineId()` を呼ぶ
  - Expected: Then `00000000` を返し、`StorageException` を投げない (TAG-R-010 の誤検出を防ぐ)

#### T-03-13: 2 回目の呼び出しで行を増やさない

- [ ] **T-03-13-01**: 生成後にもう一度呼んでも `machine_id` の行は 1 件のままである
  - Target: `MachineIdProvider.machineId` (`SqliteStore`)
  - Scenario: Given 新規作成した DB で `machineId()` を 1 回呼んで生成済み, When `machineId()` をもう一度呼ぶ
  - Expected: Then `settings` の `machine_id` の行が 1 件のままである (TAG-R-008)

---

## Coverage Check

| Source item                                                       | Task ID(s)                                                                                             |
|-------------------------------------------------------------------|--------------------------------------------------------------------------------------------------------|
| TAG-R-001                                                         | T-01-04-01〜02, T-01-05-01〜05, T-01-06-01〜04, T-01-08-01〜02, T-01-09-01〜02, T-02-06-01, T-02-08-01 |
| TAG-R-002                                                         | T-01-01-01, T-01-01-03, T-01-01-04, T-01-07-01, T-01-08-01〜02                                         |
| TAG-R-003                                                         | T-01-03-01                                                                                             |
| TAG-R-004                                                         | T-01-01-02, T-01-02-01                                                                                 |
| TAG-R-005                                                         | T-02-01-01〜02, T-02-10-01, T-02-12-01                                                                 |
| TAG-R-006                                                         | T-02-02-01〜02, T-02-09-01                                                                             |
| TAG-R-007                                                         | T-02-05-01〜02                                                                                         |
| TAG-R-008                                                         | T-03-02-01〜02, T-03-03-01, T-03-13-01                                                                 |
| TAG-R-009                                                         | T-03-01-01〜02, T-03-08-01, T-03-10-01〜02                                                             |
| TAG-R-010                                                         | T-03-05-01〜05, T-03-06-01, T-03-07-01, T-03-12-01, T-02-07-01                                         |
| TAG-DD-01 (再生成の上限 3 回)                                     | T-02-05-01〜02, T-02-09-01〜02                                                                         |
| TAG-DD-02 (確認先は予約一覧と対応表の両方)                        | T-02-02-01 (注: allocateTag には和集合の `existingTags` として渡る)                                    |
| TAG-DD-03 (マシン ID は SQLite に保存)                            | T-03-01-02, T-03-03-01                                                                                 |
| TAG-DD-04 (保存領域なしは新規、読めない/壊れは error)             | T-03-11-01, T-03-06-01, T-03-07-01                                                                     |
| IDX-DD-01 (SQLite、トランザクション)                              | T-03-01-02, T-03-08-02                                                                                 |
| IDX-DD-08 (再生成は 3 回まで、超えたら失敗)                       | T-02-05-01〜02, T-02-09-01〜02                                                                         |
| DR-04 (書式、Group、マシン ID、重複で乱数再生成)                  | T-01-01-01, T-01-01-04, T-01-02-01, T-02-02-01, T-03-01-01〜02                                         |
| DR-05 (置換でも同じ手順で新しい Tag)                              | T-02-12-01                                                                                             |
| SCH-E-32 / SCH-R-007 (対応表にだけある Tag も重複)                | T-02-02-01, T-02-05-01                                                                                 |
| Edge: 秒未満の切り捨て                                            | T-01-07-01                                                                                             |
| Edge: 年が範囲外                                                  | T-01-04-01〜02                                                                                         |
| Edge: マシン ID の桁数/大文字/16 進以外                           | T-01-05-01〜05                                                                                         |
| Edge: 乱数の桁数/大文字/16 進以外                                 | T-01-06-01〜04                                                                                         |
| Edge: 夏時間で同じローカル秒が 2 回                               | T-01-10-01                                                                                             |
| Edge: 夏時間/タイムゾーン変更をまたぐと順序が一致しない場合がある | 対象外 (「場合がある」という非保証の記述で、期待値を固定できない)                                      |
| Edge: 生成した Tag が予約一覧に既にある                           | T-02-02-01                                                                                             |
| Edge: 生成した Tag が対応表にだけある                             | T-02-02-01 (和集合の `existingTags` による。仕様の曖昧点として報告)                                    |
| Edge: 3 回の再生成後も重複                                        | T-02-05-01                                                                                             |
| Edge: 置換のために Tag を生成する                                 | T-02-12-01                                                                                             |
| Edge: Tag の実機での上限が 40 文字未満                            | 対象外 (実機での手動検証)                                                                              |
| Edge: 予約件数の上限 N まで add で登録する                        | 対象外 (AC-009、手動検証)。コードが件数を制限しない点は T-02-11-01                                     |
| Edge: N+1 件目の登録が失敗する                                    | 対象外 (結果の記録のみ、合否に含めない)                                                                |
| Edge: 保存領域が存在するのに読めない、または壊れている            | T-03-05-01〜05, T-03-07-01, T-03-06-01                                                                 |
| Edge: 2 回目の起動                                                | T-03-03-01, T-03-04-01                                                                                 |
| Edge: 保存領域が削除された後の起動                                | T-03-11-01                                                                                             |
| Edge: 2 つのプロセスが同時に初めて起動する                        | 対象外 (並行実行は対象外とする決定)                                                                    |
| 実装 §4: `key` の重複を拒否 (ユニークインデックス)                | T-03-09-01                                                                                             |
| 実装 §4: `id` 経由で読む                                          | T-03-02-02                                                                                             |

[UNCOVERED]: なし

---

## Category Balance

| Test Target                        | Normal | Error | Edge | Result |
| ---------------------------------- | -----: | ----: | ---: | ------ |
| T-01: `generateTag`                | 6      | 11    | 6    | [OK]   |
| T-02: `allocateTag`                | 6      | 5     | 5    | [OK]   |
| T-03: `MachineIdProvider` (MID)    | 6      | 10    | 5    | [OK]   |

- T-01: `Normal: 6 | Error: 11 | Edge: 6`
- T-02: `Normal: 6 | Error: 5 | Edge: 5`
- T-03: `Normal: 6 | Error: 10 | Edge: 5`

---

<!--
Task ID Format: T-<TestTarget>-<Scenario>-<Case>
- T-01 = TAG (generateTag), T-02 = TAL (allocateTag), T-03 = MID (MachineIdProvider 実装)
-->
