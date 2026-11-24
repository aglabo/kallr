---
title: "Implementation Tasks: service"
module: kallr/windows-dist-verify
status: Active
created: "2026-11-24 00:00:00"
source: specifications-schedule.md
version: 1.0.0
---

<!-- textlint-disable ja-technical-writing/sentence-length -->
<!-- textlint-disable ja-technical-writing/max-comma -->
<!-- markdownlint-disable no-duplicate-heading line-length -->

> This document contains implementation tasks derived from specifications-schedule.md.
> Each task corresponds to a single unit test case (`it()` block).
> 対象は `SchedulingService` を目的別に分けた T-07 (SVA)、T-14 (SVP)、T-15 (SVX)、T-16 (SVL)、T-17 (SVG)、T-18 (SVN)。
> 分割の経緯と旧シナリオ番号との対応は tasks-index.md の「T-07 の分割」を参照する。
> `parseAt` (T-04)、`MappingTable` (T-05)、置換キュー (T-06) は tasks-schedule.md が扱う。

---

## Task Summary

| Test Target                                       | Scenarios | Cases | Status  |
| ------------------------------------------------- | --------- | ----- | ------- |
| T-07: SchedulingService.add: 新規・置換 (SVA)     | 17        | 54    | done |
| T-14: SchedulingService: 保留の再開 (SVP)         | 13        | 34    | pending |
| T-15: SchedulingService.cancel (SVX)              | 7         | 17    | pending |
| T-16: SchedulingService.list (SVL)                | 10        | 15    | pending |
| T-17: SchedulingService.reRegisterAll (SVG)       | 9         | 23    | pending |
| T-18: SchedulingService: 入力の正規化と検査 (SVN) | 17        | 21    | pending |

<!-- Status may be: pending | in progress | done -->

---

## 共通の前提

> 共通の前提 (Fake / Mock):
>
> - `env` は `Availability(ok)` を返す Fake。`aumid` は `Kallr.Test`。
> - `scheduler` は `MockToastScheduler` (メモリ上の予約一覧と呼び出し順序の記録、失敗の注入)。`table` は呼び出し記録と失敗の注入ができる `MappingTable` の Fake。
> - `clock.now()` は `2026-11-22T10:00:00` (ローカル)。`machineId` は `a1b2c3d4`。`random` の返す乱数は 1 回目 `0123456789abcdef`、2 回目 `fedcba9876543210`。
> - 生成される Tag: 1 回目 `ADD1`=`20261122100000-a1b2c3d4-0123456789abcdef`、乱数を再生成したとき `ADD2`=`20261122100000-a1b2c3d4-fedcba9876543210`。
> - 既存の Tag: `OLD`=`20261122090000-a1b2c3d4-0123456789abcdef` (b1/a1 の現行)、`PND`=`20261122093000-a1b2c3d4-0123456789abcdef`。
> - `at` の例: `A1`=`2026-11-22T12:00:00+09:00` (now より後)。
> - `at` に時差が無い値 (`2026-11-22T10:00:00` など) は、マシンのローカル時刻として扱う (IDX-DD-03)。時差を付けた値は、その時差のまま絶対時刻として扱う。
> - 停止状態 (置換の保留。キー b1/a1、旧行 `OLD` が superseded、新行 `PND` が pending (at `2026-11-22T13:00:00+09:00`, title `再開後`)):
>   - P2 (段階 2 の前): 予約一覧に `OLD` だけ。
>   - P3 (段階 3 の前): 予約一覧に `OLD` と `PND` の両方。
>   - P4 (段階 4 の前): 予約一覧に `PND` だけ。

---

## T-07: SchedulingService.add: 新規・置換 (SVA)

### [正常] Normal Cases

#### T-07-01: Given: 対応表に無いキーで add する (新規。SCH-R-004, SCH-R-008, SCH-R-011, IDX-R-004)

- [x] **T-07-01-01**: 新しい MappingRecord を返す
  - Target: `SchedulingService.add`
  - Scenario: Given 空の対応表と空の予約一覧, When `add(batchId: 'b1', alarmId: 'a1', at: A1, title: 't1', aumid: 'Kallr.Test')` を呼ぶ
  - Expected: Then tag `ADD1`、at `A1`、title `t1`、registeredAt `2026-11-22T10:00:00` の `MappingRecord` を返す

- [x] **T-07-01-02**: 予約一覧に新しい Tag の予約がちょうど 1 件できる
  - Target: `SchedulingService.add`
  - Scenario: Given 空の対応表と空の予約一覧, When `add` を呼ぶ
  - Expected: Then `scheduler.list('kallr')` が tag `ADD1`、group `kallr`、at `A1` の 1 件だけを返す

- [x] **T-07-01-03**: 対応表に同じ内容が記録される
  - Target: `SchedulingService.add`
  - Scenario: Given 空の対応表と空の予約一覧, When `add` を呼ぶ
  - Expected: Then `table.get('b1','a1')` が返り値と等しい

- [x] **T-07-01-04**: 予約の追加が対応表の更新より先である
  - Target: `SchedulingService.add`
  - Scenario: Given 空の対応表と空の予約一覧, When `add` を呼ぶ
  - Expected: Then 呼び出し順が `scheduler.add` → `table.put` である

- [x] **T-07-01-05**: 通知可否の確認に aumid を渡す
  - Target: `SchedulingService.add`
  - Scenario: Given 空の対応表と空の予約一覧, When `add(aumid: 'Kallr.Test')` を呼ぶ
  - Expected: Then `env.check` が `Kallr.Test` で 1 回呼ばれる

#### T-07-02: Given: 対応表の Tag が予約一覧にある同じキーで add する (置換。SCH-R-005, SCH-R-009, SCH-R-011, IDX-R-005, DR-05, DR-07, DR-08)

- [x] **T-07-02-01**: 新しい Tag の MappingRecord を返す
  - Target: `SchedulingService.add`
  - Scenario: Given `b1`/`a1` が `OLD` で対応表と予約一覧にある, When 新しい at `A1` と title `t2` で `add` する
  - Expected: Then tag `ADD1` (`OLD` ではない)、registeredAt `2026-11-22T10:00:00` の `MappingRecord` を返す

- [x] **T-07-02-02**: 予約一覧に置換前の Tag の予約が無い
  - Target: `SchedulingService.add`
  - Scenario: Given `b1`/`a1` が `OLD` で対応表と予約一覧にある, When `add` する
  - Expected: Then `scheduler.list('kallr')` が tag `ADD1` の 1 件だけを返し、`OLD` を含まない

- [x] **T-07-02-03**: 対応表は置換後の内容を current として持つ
  - Target: `SchedulingService.add`
  - Scenario: Given `b1`/`a1` が `OLD` で対応表と予約一覧にある, When `add` する
  - Expected: Then `table.get('b1','a1')` が返り値と等しい

- [x] **T-07-02-04**: 完了後に保留が残らない
  - Target: `SchedulingService.add`
  - Scenario: Given `b1`/`a1` が `OLD` で対応表と予約一覧にある, When `add` する
  - Expected: Then `table.pendingRemovals()` が空である

- [x] **T-07-02-05**: 4 つの段階が DB 先・追加・削除・DB 完了の順で呼ばれる
  - Target: `SchedulingService.add`
  - Scenario: Given `b1`/`a1` が `OLD` で対応表と予約一覧にある, When `add` する
  - Expected: Then 呼び出し順が `table.replace` → `scheduler.add(ADD1)` → `scheduler.remove(OLD, 'kallr')` → `table.completeRemoval` である

#### T-07-03: Given: 同じ at と title での再 add (SCH-E-09)

- [x] **T-07-03-01**: 内容が同じでも置換として扱い、新しい Tag を付ける
  - Target: `SchedulingService.add`
  - Scenario: Given `b1`/`a1` が `OLD`・at `A1`・title `t1` で対応表と予約一覧にある, When 同じ at `A1` と title `t1` で `add` する
  - Expected: Then 返り値の tag が `ADD1` で、`scheduler.list('kallr')` が `ADD1` の 1 件だけを返す

#### T-07-04: Given: 対応表に項目があり、その Tag が予約一覧に無い (発火済み。SCH-R-006, SCH-E-08, REQ-F-006)

- [x] **T-07-04-01**: 新しい MappingRecord を返す
  - Target: `SchedulingService.add`
  - Scenario: Given `b1`/`a1` が `OLD` で対応表にだけある (予約一覧は空), When `add` する
  - Expected: Then tag `ADD1` の `MappingRecord` を返す

- [x] **T-07-04-02**: 対応表の項目が新しい内容で上書きされる
  - Target: `SchedulingService.add`
  - Scenario: Given `b1`/`a1` が `OLD` で対応表にだけある, When at `A1`・title `t2` で `add` する
  - Expected: Then `table.get('b1','a1')` が tag `ADD1`、title `t2`、registeredAt `2026-11-22T10:00:00` である

- [x] **T-07-04-03**: 置換の手順を行わない
  - Target: `SchedulingService.add`
  - Scenario: Given `b1`/`a1` が `OLD` で対応表にだけある, When `add` する
  - Expected: Then `table.replace` と `scheduler.remove` が 1 回も呼ばれない

- [x] **T-07-04-04**: 予約一覧に新しい予約だけがある
  - Target: `SchedulingService.add`
  - Scenario: Given `b1`/`a1` が `OLD` で対応表にだけある, When `add` する
  - Expected: Then `scheduler.list('kallr')` が tag `ADD1` の 1 件だけを返す

### [異常] Error Cases

#### T-07-05: Given: 通知可否の確認が「通知できる」でない (SCH-R-003, SCH-E-06, IDX-R-001)

- [x] **T-07-05-01**: UnavailableException を投げる
  - Target: `SchedulingService.add`
  - Scenario: Given `env.check` が `ok = false` で理由 `AUMID が未登録` を返す, When `add` を呼ぶ
  - Expected: Then `UnavailableException` を投げ、その `availability` が `env.check` の返した値である

- [x] **T-07-05-02**: OS の予約を一切呼ばない
  - Target: `SchedulingService.add`
  - Scenario: Given `env.check` が `ok = false` を返す, When `add` を呼ぶ
  - Expected: Then `scheduler` の `add`・`remove`・`list` が 1 回も呼ばれない

- [x] **T-07-05-03**: 対応表を一切呼ばない
  - Target: `SchedulingService.add`
  - Scenario: Given `env.check` が `ok = false` を返す, When `add` を呼ぶ
  - Expected: Then `table` の `get`・`put`・`replace` が 1 回も呼ばれない

- [x] **T-07-05-04**: 保留の再開もしない
  - Target: `SchedulingService.add`
  - Scenario: Given `env.check` が `ok = false` を返し、P3 の状態である, When `add` を呼ぶ
  - Expected: Then `table.pendingRemovals()` が 1 件のままで、`scheduler.list('kallr')` が `OLD` と `PND` の両方を持つ

#### T-07-06: Given: 過去の at を OS が拒否する新規 add (SCH-E-04, SCH-DD-05)

- [x] **T-07-06-01**: ScheduleException を 0x80070057 で投げる
  - Target: `SchedulingService.add`
  - Scenario: Given `scheduler.add` が `ScheduleException(0x80070057)` を投げる設定, When 新規の `add` を呼ぶ
  - Expected: Then `hresult` が `0x80070057` の `ScheduleException` を投げる

- [x] **T-07-06-02**: 対応表を変えない
  - Target: `SchedulingService.add`
  - Scenario: Given `scheduler.add` が `ScheduleException(0x80070057)` を投げる設定, When 新規の `add` を呼んで失敗した
  - Expected: Then `table.get('b1','a1')` が null で、`table.put` が 1 回も呼ばれない

#### T-07-07: Given: 予約件数の上限超過を OS が拒否する新規 add (SCH-E-16)

- [x] **T-07-07-01**: ScheduleException を 0x80070718 で投げる
  - Target: `SchedulingService.add`
  - Scenario: Given `scheduler.add` が `ScheduleException(0x80070718)` を投げる設定, When 新規の `add` を呼ぶ
  - Expected: Then `hresult` が `0x80070718` の `ScheduleException` を投げる

#### T-07-08: Given: 新規の予約の追加後に対応表の書き込みが失敗する (SCH-E-14, SCH-R-010)

- [x] **T-07-08-01**: StorageException をそのまま伝える
  - Target: `SchedulingService.add`
  - Scenario: Given `table.put` が `StorageException` を投げる設定, When 新規の `add` を呼ぶ
  - Expected: Then `StorageException` を投げる

- [x] **T-07-08-02**: 追加した予約は巻き戻さず残る
  - Target: `SchedulingService.add`
  - Scenario: Given `table.put` が `StorageException` を投げる設定, When 新規の `add` を呼んで失敗した
  - Expected: Then `scheduler.list('kallr')` が tag `ADD1` の 1 件を持ち、`scheduler.remove` が 1 回も呼ばれない

- [x] **T-07-08-03**: 対応表には項目が無い
  - Target: `SchedulingService.add`
  - Scenario: Given `table.put` が `StorageException` を投げる設定, When 新規の `add` を呼んで失敗した
  - Expected: Then `table.get('b1','a1')` が null である

- [x] **T-07-08-04**: 続く list が孤立した予約として検出する
  - Target: `SchedulingService.list`
  - Scenario: Given 上の失敗の後 (予約一覧に `ADD1` だけがある), When `list()` を呼ぶ
  - Expected: Then tag `ADD1` の要素の `state` が `EntryState.orphan` である

#### T-07-09: Given: Tag の重複が上限の後も続く (SCH-R-007, SCH-E-15, SCH-DD-10)

- [x] **T-07-09-01**: DuplicateTagException を投げる
  - Target: `SchedulingService.add`
  - Scenario: Given `random` が常に `0123456789abcdef` を返し、その Tag `ADD1` が対応表の `b9`/`a9` に既にある, When `add` を呼ぶ
  - Expected: Then `DuplicateTagException` を投げる

- [x] **T-07-09-02**: 予約を作らない
  - Target: `SchedulingService.add`
  - Scenario: Given `random` が常に同じ値を返し、その Tag が既にある, When `add` を呼んで失敗した
  - Expected: Then `scheduler.add` が 1 回も呼ばれない

- [x] **T-07-09-03**: 対応表を変えない
  - Target: `SchedulingService.add`
  - Scenario: Given `random` が常に同じ値を返し、その Tag が既にある, When `add` を呼んで失敗した
  - Expected: Then `table.put` と `table.replace` が 1 回も呼ばれない

#### T-07-10: Given: 置換の段階 1 (DB への記録) が失敗する (SCH-E-11, 3.5 段階 1 の失敗)

- [x] **T-07-10-01**: StorageException をそのまま伝える
  - Target: `SchedulingService.add`
  - Scenario: Given `b1`/`a1` が `OLD` で対応表と予約一覧にあり、`table.replace` が `StorageException` を投げる設定, When `add` を呼ぶ
  - Expected: Then `StorageException` を投げる

- [x] **T-07-10-02**: OS の予約に触れない
  - Target: `SchedulingService.add`
  - Scenario: Given 同上, When `add` を呼んで失敗した
  - Expected: Then `scheduler.add` と `scheduler.remove` が 1 回も呼ばれない

- [x] **T-07-10-03**: 置換前の予約だけが残る
  - Target: `SchedulingService.add`
  - Scenario: Given 同上, When `add` を呼んで失敗した
  - Expected: Then `scheduler.list('kallr')` が `OLD` の 1 件だけを返す

- [x] **T-07-10-04**: 対応表は置換前の行が current のまま変わらない
  - Target: `SchedulingService.add`
  - Scenario: Given 同上, When `add` を呼んで失敗した
  - Expected: Then `table.get('b1','a1')` が tag `OLD` の MappingRecord を返す

#### T-07-11: Given: 置換の段階 2 (OS の追加) を OS が拒否する (SCH-E-10, SCH-R-010, 3.5 段階 2 の拒否)

- [x] **T-07-11-01**: ScheduleException をそのまま伝える
  - Target: `SchedulingService.add`
  - Scenario: Given `b1`/`a1` が `OLD` で対応表と予約一覧にあり、`scheduler.add` が `ScheduleException(0x80070057)` を投げる設定, When `add` を呼ぶ
  - Expected: Then `hresult` が `0x80070057` の `ScheduleException` を投げる

- [x] **T-07-11-02**: 段階 1 の記録を取り消す
  - Target: `SchedulingService.add`
  - Scenario: Given 同上, When `add` を呼んで失敗した
  - Expected: Then `table.abortReplacement` が `table.replace` の返した queueId で 1 回呼ばれる

- [x] **T-07-11-03**: 対応表は置換前の行が current に戻る
  - Target: `SchedulingService.add`
  - Scenario: Given 同上, When `add` を呼んで失敗した
  - Expected: Then `table.get('b1','a1')` が tag `OLD` の MappingRecord を返す

- [x] **T-07-11-04**: 保留が残らない
  - Target: `SchedulingService.add`
  - Scenario: Given 同上, When `add` を呼んで失敗した
  - Expected: Then `table.pendingRemovals()` が空である

- [x] **T-07-11-05**: 置換前の予約だけが残る
  - Target: `SchedulingService.add`
  - Scenario: Given 同上, When `add` を呼んで失敗した
  - Expected: Then `scheduler.list('kallr')` が `OLD` の 1 件だけを返す

- [x] **T-07-11-06**: 置換前の予約を削除しない
  - Target: `SchedulingService.add`
  - Scenario: Given 同上, When `add` を呼んで失敗した
  - Expected: Then `scheduler.remove` が 1 回も呼ばれない

#### T-07-12: Given: 置換の段階 3 (置換前の予約の削除) が失敗する (SCH-E-12, 3.5 段階 3 の失敗)

- [x] **T-07-12-01**: ScheduleException をそのまま伝える
  - Target: `SchedulingService.add`
  - Scenario: Given `b1`/`a1` が `OLD` で対応表と予約一覧にあり、`scheduler.remove` が `ScheduleException` を投げる設定, When `add` を呼ぶ
  - Expected: Then `ScheduleException` を投げる

- [x] **T-07-12-02**: 両方の予約が残る
  - Target: `SchedulingService.add`
  - Scenario: Given 同上, When `add` を呼んで失敗した
  - Expected: Then `scheduler.list('kallr')` が `OLD` と `ADD1` の 2 件を返す

- [x] **T-07-12-03**: 保留が置換キューに残る
  - Target: `SchedulingService.add`
  - Scenario: Given 同上, When `add` を呼んで失敗した
  - Expected: Then `table.pendingRemovals()` が 1 件を返す

- [x] **T-07-12-04**: 段階 4 に進まない
  - Target: `SchedulingService.add`
  - Scenario: Given 同上, When `add` を呼んで失敗した
  - Expected: Then `table.completeRemoval` が 1 回も呼ばれない

- [x] **T-07-12-05**: 巻き戻さない
  - Target: `SchedulingService.add`
  - Scenario: Given 同上, When `add` を呼んで失敗した
  - Expected: Then `table.abortReplacement` が 1 回も呼ばれない

#### T-07-13: Given: 置換の段階 4 (DB の完了) が失敗する (SCH-E-12, 3.5 段階 4 の失敗)

- [x] **T-07-13-01**: StorageException をそのまま伝える
  - Target: `SchedulingService.add`
  - Scenario: Given `b1`/`a1` が `OLD` で対応表と予約一覧にあり、`table.completeRemoval` が `StorageException` を投げる設定, When `add` を呼ぶ
  - Expected: Then `StorageException` を投げる

- [x] **T-07-13-02**: 置換後の予約だけが残る
  - Target: `SchedulingService.add`
  - Scenario: Given 同上, When `add` を呼んで失敗した
  - Expected: Then `scheduler.list('kallr')` が `ADD1` の 1 件だけを返す

- [x] **T-07-13-03**: 保留が置換キューに残る
  - Target: `SchedulingService.add`
  - Scenario: Given 同上, When `add` を呼んで失敗した
  - Expected: Then `table.pendingRemovals()` が 1 件を返す

### [エッジケース] Edge Cases

#### T-07-14: Given: 生成した Tag が予約一覧にだけある Tag と重複する (SCH-R-007, TAG 重複の確認先)

- [x] **T-07-14-01**: 乱数を再生成した Tag を使う
  - Target: `SchedulingService.add`
  - Scenario: Given 予約一覧にだけ `ADD1` の予約 (別キー `b9`/`a9`、対応表に無い) があり、`random` が `0123456789abcdef`、次に `fedcba9876543210` を返す, When `b1`/`a1` を `add` する
  - Expected: Then 返り値の tag が `ADD2` である

#### T-07-15: Given: 生成した Tag が対応表にだけある (発火済み) Tag と重複する (SCH-E-32, D8)

- [x] **T-07-15-01**: 乱数を再生成した Tag を使う
  - Target: `SchedulingService.add`
  - Scenario: Given 対応表の `b9`/`a9` に `ADD1` があり予約一覧は空で、`random` が `0123456789abcdef`、次に `fedcba9876543210` を返す, When `b1`/`a1` を `add` する
  - Expected: Then 返り値の tag が `ADD2` である

#### T-07-16: Given: UTF-8 の title (SCH-E-23, REQ-NF-004)

- [x] **T-07-16-01**: OS の追加に title をそのまま渡す
  - Target: `SchedulingService.add`
  - Scenario: Given title が `会議の開始`, When `add` する
  - Expected: Then `scheduler.add` の title が `会議の開始` で呼ばれる

- [x] **T-07-16-02**: 返り値の title も同じである
  - Target: `SchedulingService.add`
  - Scenario: Given title が `会議の開始`, When `add` する
  - Expected: Then 返り値の title が `会議の開始` である

#### T-07-17: Given: 置換の途中で置換前の予約が発火済みになる (SCH-E-13, SCH-R-030, SCH-DD-13)

- [x] **T-07-17-01**: 例外を投げず MappingRecord を返す
  - Target: `SchedulingService.add`
  - Scenario: Given `b1`/`a1` が `OLD` で対応表と予約一覧にあり、`scheduler.remove('OLD')` が false を返す設定, When `add` を呼ぶ
  - Expected: Then 例外を投げず tag `ADD1` の MappingRecord を返す

- [x] **T-07-17-02**: 段階 4 まで完了する
  - Target: `SchedulingService.add`
  - Scenario: Given 同上, When `add` を呼ぶ
  - Expected: Then `table.completeRemoval` が呼ばれ、`table.pendingRemovals()` が空である

- [x] **T-07-17-03**: 置換後の予約だけが残る
  - Target: `SchedulingService.add`
  - Scenario: Given 同上, When `add` を呼ぶ
  - Expected: Then `scheduler.list('kallr')` が `ADD1` の 1 件だけを返す

---

## T-14: SchedulingService: 保留の再開 (SVP)

### [正常] Normal Cases

#### T-14-01: Given: 段階 2 の前で止まった保留 (P2) があり、別のキーで add する (SCH-R-036, DR-07 再開)

- [ ] **T-14-01-01**: 置換後の予約が OS に追加される
  - Target: `SchedulingService.add`
  - Scenario: Given P2 の状態, When `b2`/`a2` で `add` する
  - Expected: Then `scheduler.add` が tag `PND`、group `kallr`、at `2026-11-22T13:00:00+09:00`、title `再開後` で呼ばれる

- [ ] **T-14-01-02**: 置換前の予約が OS から削除される
  - Target: `SchedulingService.add`
  - Scenario: Given P2 の状態, When `b2`/`a2` で `add` する
  - Expected: Then `scheduler.remove('OLD', 'kallr')` が呼ばれる

- [ ] **T-14-01-03**: 保留が完了して残らない
  - Target: `SchedulingService.add`
  - Scenario: Given P2 の状態, When `b2`/`a2` で `add` する
  - Expected: Then `table.pendingRemovals()` が空で、`table.get('b1','a1')` が tag `PND` の MappingRecord を返す

- [ ] **T-14-01-04**: 保留の処理が、add の分類と追加より先である
  - Target: `SchedulingService.add`
  - Scenario: Given P2 の状態, When `b2`/`a2` で `add` する
  - Expected: Then 呼び出し順が `scheduler.add(PND)` → `scheduler.remove(OLD)` → `table.completeRemoval` → `scheduler.add(ADD1)` である

#### T-14-02: Given: 段階 3 の前で止まった保留 (P3。両方が残る) があり、別のキーで add する (SCH-R-036, DR-07 再開)

- [ ] **T-14-02-01**: 置換後の Tag が予約一覧に既にあるので追加しない
  - Target: `SchedulingService.add`
  - Scenario: Given P3 の状態, When `b2`/`a2` で `add` する
  - Expected: Then tag `PND` での `scheduler.add` が 1 回も呼ばれない

- [ ] **T-14-02-02**: 置換前の予約が OS から削除される
  - Target: `SchedulingService.add`
  - Scenario: Given P3 の状態, When `b2`/`a2` で `add` する
  - Expected: Then `scheduler.remove('OLD', 'kallr')` が呼ばれる

- [ ] **T-14-02-03**: 保留が完了して残らない
  - Target: `SchedulingService.add`
  - Scenario: Given P3 の状態, When `b2`/`a2` で `add` する
  - Expected: Then `table.pendingRemovals()` が空である

#### T-14-03: Given: 段階 4 の前で止まった保留 (P4。置換後の予約だけが残る) があり、別のキーで add する (SCH-R-036, SCH-R-030, DR-07 再開)

- [ ] **T-14-03-01**: 置換前の予約が既に無くても例外を投げない
  - Target: `SchedulingService.add`
  - Scenario: Given P4 の状態 (`scheduler.remove('OLD')` が false を返す), When `b2`/`a2` で `add` する
  - Expected: Then 例外を投げずに `MappingRecord` を返す

- [ ] **T-14-03-02**: 保留が完了して残らない
  - Target: `SchedulingService.add`
  - Scenario: Given P4 の状態, When `b2`/`a2` で `add` する
  - Expected: Then `table.completeRemoval` が呼ばれ、`table.pendingRemovals()` が空である

#### T-14-04: Given: 保留 (P3) があるキーを cancel する (SCH-R-036)

- [ ] **T-14-04-01**: 置換前と置換後の両方の予約が消える
  - Target: `SchedulingService.cancel`
  - Scenario: Given P3 の状態, When `cancel('b1','a1')` を呼ぶ
  - Expected: Then `scheduler.list('kallr')` が空である

- [ ] **T-14-04-02**: 対応表の項目が消え、保留も残らない
  - Target: `SchedulingService.cancel`
  - Scenario: Given P3 の状態, When `cancel('b1','a1')` を呼ぶ
  - Expected: Then `table.get('b1','a1')` が null で、`table.pendingRemovals()` が空である

- [ ] **T-14-04-03**: 保留の処理 → 読み直し → 予約の削除 → 行の削除の順で動く
  - Target: `SchedulingService.cancel`
  - Scenario: Given P3 の状態, When `cancel('b1','a1')` を呼ぶ
  - Expected: Then 呼び出し順が `scheduler.remove(OLD)` → `table.completeRemoval` → `scheduler.remove(PND)` → `table.remove('b1','a1')` である

#### T-14-05: Given: 保留 (P3) があるときに再登録する (SCH-R-036)

- [ ] **T-14-05-01**: 置換前の予約が OS から削除される
  - Target: `SchedulingService.reRegisterAll`
  - Scenario: Given P3 の状態, When `reRegisterAll` を呼ぶ
  - Expected: Then `scheduler.remove('OLD', 'kallr')` が呼ばれる

- [ ] **T-14-05-02**: 保留が完了して残らない
  - Target: `SchedulingService.reRegisterAll`
  - Scenario: Given P3 の状態, When `reRegisterAll` を呼ぶ
  - Expected: Then `table.pendingRemovals()` が空である

### [異常] Error Cases

#### T-14-06: Given: add の保留の再開 (P2) で、置換後の予約の追加を OS が拒否する (SCH-R-036, SCH-R-010)

- [ ] **T-14-06-01**: 置換前の行が current に戻る
  - Target: `SchedulingService.add`
  - Scenario: Given P2 の状態で `scheduler.add` が `ScheduleException(0x80070057)` を投げる設定 (PND の at は now より後), When `b2`/`a2` で `add` を呼ぶ
  - Expected: Then `table.get('b1','a1')` が tag `OLD` の MappingRecord を返す

- [ ] **T-14-06-02**: 保留が残らない
  - Target: `SchedulingService.add`
  - Scenario: Given 同上, When `add` を呼ぶ
  - Expected: Then `table.abortReplacement` が呼ばれ、`table.pendingRemovals()` が空である

- [ ] **T-14-06-03**: 拒否された置換後の予約は予約一覧に無い
  - Target: `SchedulingService.add`
  - Scenario: Given 同上, When `add` を呼ぶ
  - Expected: Then `scheduler.list('kallr')` が `PND` を含まない

- [ ] **T-14-06-04**: 拒否されても `add` は例外を投げない
  - Target: `SchedulingService.add`
  - Scenario: Given 同上, When `add` を呼ぶ
  - Expected: Then `add` が `ScheduleException` を投げずに完了する (SCH-R-036: 拒否は abortReplacement で戻し、例外にしない)

#### T-14-07: Given: add の保留の再開 (P3) で、置換前の予約の削除が失敗する (SCH-R-036)

- [ ] **T-14-07-01**: ScheduleException をそのまま伝える
  - Target: `SchedulingService.add`
  - Scenario: Given P3 の状態で `scheduler.remove` が `ScheduleException` を投げる設定, When `b2`/`a2` で `add` を呼ぶ
  - Expected: Then `ScheduleException` を投げる

- [ ] **T-14-07-02**: 保留が残る
  - Target: `SchedulingService.add`
  - Scenario: Given 同上, When `add` を呼んで失敗した
  - Expected: Then `table.pendingRemovals()` が 1 件を返す

- [ ] **T-14-07-03**: 要求された add の追加に進まない
  - Target: `SchedulingService.add`
  - Scenario: Given 同上, When `add` を呼んで失敗した
  - Expected: Then tag `ADD1` での `scheduler.add` が 1 回も呼ばれない

#### T-14-08: Given: add の保留の再開 (P4) で、DB の完了が失敗する (SCH-R-036)

- [ ] **T-14-08-01**: StorageException をそのまま伝える
  - Target: `SchedulingService.add`
  - Scenario: Given P4 の状態で `table.completeRemoval` が `StorageException` を投げる設定, When `b2`/`a2` で `add` を呼ぶ
  - Expected: Then `StorageException` を投げる

- [ ] **T-14-08-02**: 保留が残る
  - Target: `SchedulingService.add`
  - Scenario: Given 同上, When `add` を呼んで失敗した
  - Expected: Then `table.pendingRemovals()` が 1 件を返す

### [エッジケース] Edge Cases

#### T-14-09: Given: 再開のとき、置換後の通知時刻が now より前 (P2。SCH-R-036, 3.5)

> PND の at を `2026-11-22T09:59:59+09:00` (now の 1 秒前) とする。

- [ ] **T-14-09-01**: 置換後の予約を追加しない
  - Target: `SchedulingService.add`
  - Scenario: Given P2 の状態で PND の at が now の 1 秒前, When `b2`/`a2` で `add` を呼ぶ
  - Expected: Then tag `PND` での `scheduler.add` が 1 回も呼ばれない

- [ ] **T-14-09-02**: 置換前の予約を削除する
  - Target: `SchedulingService.add`
  - Scenario: Given 同上, When `add` を呼ぶ
  - Expected: Then `scheduler.remove('OLD', 'kallr')` が呼ばれる

- [ ] **T-14-09-03**: 置換前の行へ戻さず置換後の行を current にする
  - Target: `SchedulingService.add`
  - Scenario: Given 同上, When `add` を呼ぶ
  - Expected: Then `table.abortReplacement` が呼ばれず、`table.get('b1','a1')` が tag `PND` の MappingRecord を返す

- [ ] **T-14-09-04**: 保留が完了して残らない
  - Target: `SchedulingService.add`
  - Scenario: Given 同上, When `add` を呼ぶ
  - Expected: Then `table.pendingRemovals()` が空である

#### T-14-10: Given: 再開のとき、置換後の通知時刻が now と同じ (境界。P2)

- [ ] **T-14-10-01**: now と同じ時刻は過去として扱い追加しない
  - Target: `SchedulingService.add`
  - Scenario: Given P2 の状態で PND の at が `2026-11-22T10:00:00` (now と同じ), When `b2`/`a2` で `add` を呼ぶ
  - Expected: Then tag `PND` での `scheduler.add` が 1 回も呼ばれない

- [ ] **T-14-10-02**: 保留が完了して残らない
  - Target: `SchedulingService.add`
  - Scenario: Given P2 の状態で PND の at が `2026-11-22T10:00:00` (now と同じ), When `b2`/`a2` で `add` を呼ぶ
  - Expected: Then `table.pendingRemovals()` が空である

#### T-14-11: Given: 再開のとき、置換後の通知時刻が now の 1 秒後 (境界。P2)

- [ ] **T-14-11-01**: now より後の時刻は追加する
  - Target: `SchedulingService.add`
  - Scenario: Given P2 の状態で PND の at が `2026-11-22T10:00:01` (now の 1 秒後), When `b2`/`a2` で `add` を呼ぶ
  - Expected: Then tag `PND` での `scheduler.add` が 1 回呼ばれる

#### T-14-12: Given: 保留 (P3) があるキーと同じキーで add する (SCH-R-036)

- [ ] **T-14-12-01**: 保留を処理してから新たに置換し、予約が 1 件になる
  - Target: `SchedulingService.add`
  - Scenario: Given P3 の状態, When 同じ `b1`/`a1` で `add` する
  - Expected: Then `scheduler.list('kallr')` が tag `ADD1` の 1 件だけを返す

- [ ] **T-14-12-02**: 保留が残らない
  - Target: `SchedulingService.add`
  - Scenario: Given P3 の状態, When 同じ `b1`/`a1` で `add` する
  - Expected: Then `table.pendingRemovals()` が空である

#### T-14-13: Given: cancel の保留の再開 (P2) で置換後の予約の追加を OS が拒否する (SCH-R-036, SCH-R-010)

- [ ] **T-14-13-01**: 読み直した旧行の Tag の予約を削除する
  - Target: `SchedulingService.cancel`
  - Scenario: Given P2 の状態で `scheduler.add` が `ScheduleException(0x80070057)` を投げる設定 (PND の at は now より後), When `cancel('b1','a1')` を呼ぶ
  - Expected: Then `scheduler.remove` が `PND` ではなく `OLD` で呼ばれる

- [ ] **T-14-13-02**: 対応表の項目を削除する
  - Target: `SchedulingService.cancel`
  - Scenario: Given 同上, When `cancel('b1','a1')` を呼ぶ
  - Expected: Then `table.get('b1','a1')` が null を返す

---

## T-15: SchedulingService.cancel (SVX)

### [正常] Normal Cases

#### T-15-01: Given: 対応表に項目があり予約もある同じキーを cancel する (SCH-R-014, REQ-F-004)

- [ ] **T-15-01-01**: 予約一覧からその Tag が消える
  - Target: `SchedulingService.cancel`
  - Scenario: Given `b1`/`a1` が `OLD` で対応表と予約一覧にある, When `cancel(batchId: 'b1', alarmId: 'a1')` を呼ぶ
  - Expected: Then `scheduler.list('kallr')` が `OLD` を含まない

- [ ] **T-15-01-02**: 対応表から項目が消える
  - Target: `SchedulingService.cancel`
  - Scenario: Given `b1`/`a1` が `OLD` で対応表と予約一覧にある, When `cancel` を呼ぶ
  - Expected: Then `table.get('b1','a1')` が null を返す

- [ ] **T-15-01-03**: 予約の削除が対応表の削除より先である
  - Target: `SchedulingService.cancel`
  - Scenario: Given `b1`/`a1` が `OLD` で対応表と予約一覧にある, When `cancel` を呼ぶ
  - Expected: Then 呼び出し順が `scheduler.remove('OLD','kallr')` → `table.remove('b1','a1')` である (SCH-DD-07)

### [異常] Error Cases

#### T-15-02: Given: 対応表に無いキーを cancel する (SCH-R-013, SCH-E-17, SCH-DD-06)

- [ ] **T-15-02-01**: NotFoundException を投げる
  - Target: `SchedulingService.cancel`
  - Scenario: Given 空の対応表, When `cancel('b1','a1')` を呼ぶ
  - Expected: Then `NotFoundException` を投げる

- [ ] **T-15-02-02**: OS の予約を削除しない
  - Target: `SchedulingService.cancel`
  - Scenario: Given 空の対応表, When `cancel('b1','a1')` を呼んで失敗した
  - Expected: Then `scheduler.remove` が 1 回も呼ばれない

- [ ] **T-15-02-03**: 対応表を変えない
  - Target: `SchedulingService.cancel`
  - Scenario: Given 空の対応表, When `cancel('b1','a1')` を呼んで失敗した
  - Expected: Then `table.remove` が 1 回も呼ばれない

#### T-15-03: Given: cancel の予約の削除が失敗する (SCH-R-015)

- [ ] **T-15-03-01**: ScheduleException をそのまま伝える
  - Target: `SchedulingService.cancel`
  - Scenario: Given `b1`/`a1` が `OLD` で対応表と予約一覧にあり、`scheduler.remove` が `ScheduleException` を投げる設定, When `cancel` を呼ぶ
  - Expected: Then `ScheduleException` を投げる

- [ ] **T-15-03-02**: 対応表を変えない
  - Target: `SchedulingService.cancel`
  - Scenario: Given 同上, When `cancel` を呼んで失敗した
  - Expected: Then `table.get('b1','a1')` が tag `OLD` の MappingRecord を返し、`table.remove` が 1 回も呼ばれない

#### T-15-04: Given: cancel の予約の削除後に対応表の削除が失敗する (SCH-E-18, SCH-R-015)

- [ ] **T-15-04-01**: StorageException をそのまま伝える
  - Target: `SchedulingService.cancel`
  - Scenario: Given `b1`/`a1` が `OLD` で対応表と予約一覧にあり、`table.remove` が `StorageException` を投げる設定, When `cancel` を呼ぶ
  - Expected: Then `StorageException` を投げる

- [ ] **T-15-04-02**: 予約は消えている
  - Target: `SchedulingService.cancel`
  - Scenario: Given 同上, When `cancel` を呼んで失敗した
  - Expected: Then `scheduler.list('kallr')` が `OLD` を含まない

- [ ] **T-15-04-03**: 項目だけが対応表に残る
  - Target: `SchedulingService.cancel`
  - Scenario: Given 同上, When `cancel` を呼んで失敗した
  - Expected: Then `table.get('b1','a1')` が tag `OLD` の MappingRecord を返す

- [ ] **T-15-04-04**: 続く list が stale として検出する
  - Target: `SchedulingService.list`
  - Scenario: Given 上の失敗の後 (対応表に `OLD` があり予約一覧は空), When `list()` を呼ぶ
  - Expected: Then tag `OLD` の要素の `state` が `EntryState.stale` である

### [エッジケース] Edge Cases

#### T-15-05: Given: cancel で項目はあるが予約が発火済み (SCH-E-19, SCH-R-030, SCH-DD-13)

- [ ] **T-15-05-01**: 例外を投げずに完了する
  - Target: `SchedulingService.cancel`
  - Scenario: Given `b1`/`a1` が `OLD` で対応表にだけある (`scheduler.remove` が false を返す), When `cancel` を呼ぶ
  - Expected: Then 例外を投げない

- [ ] **T-15-05-02**: 対応表の項目を削除する
  - Target: `SchedulingService.cancel`
  - Scenario: Given 同上, When `cancel` を呼ぶ
  - Expected: Then `table.get('b1','a1')` が null を返す

#### T-15-06: Given: 別のキーの項目と予約がある状態で cancel する

- [ ] **T-15-06-01**: 別のキーの項目と予約は変わらない
  - Target: `SchedulingService.cancel`
  - Scenario: Given `b1`/`a1` (`OLD`) と `b2`/`a2` (`PND`) が対応表と予約一覧の両方にある, When `cancel('b1','a1')` を呼ぶ
  - Expected: Then `table.get('b2','a2')` が tag `PND` を返し、`scheduler.list('kallr')` が `PND` だけを返す

#### T-15-07: Given: 通知可否の確認が「通知できる」でない状態で cancel する (specifications-schedule.md 3.2)

- [ ] **T-15-07-01**: 通知可否の確認を呼ばない
  - Target: `SchedulingService.cancel`
  - Scenario: Given `env.check` が `ok = false` を返し、`b1`/`a1` が対応表と予約一覧にある, When `cancel` を呼ぶ
  - Expected: Then `env.check` が 1 回も呼ばれない

- [ ] **T-15-07-02**: UnavailableException を投げず完了する
  - Target: `SchedulingService.cancel`
  - Scenario: Given `env.check` が `ok = false` を返し、`b1`/`a1` が対応表と予約一覧にある, When `cancel` を呼ぶ
  - Expected: Then 例外を投げず、`table.get('b1','a1')` が null を返す

---

## T-16: SchedulingService.list (SVL)

### [正常] Normal Cases

#### T-16-01: Given: Tag が対応表と予約一覧の両方にある (SCH-R-017)

- [ ] **T-16-01-01**: 状態は ok になる
  - Target: `SchedulingService.list`
  - Scenario: Given `b1`/`a1` の `OLD` が対応表と予約一覧の両方にある, When `list()` を呼ぶ
  - Expected: Then 1 件の `ScheduleEntry` の `state` が `EntryState.ok` である

- [ ] **T-16-01-02**: ok の要素は項目と予約の両方を持つ
  - Target: `SchedulingService.list`
  - Scenario: Given `b1`/`a1` の `OLD` が対応表と予約一覧の両方にある, When `list()` を呼ぶ
  - Expected: Then その要素の `record` と `toast` がどちらも null でない

#### T-16-02: Given: Tag が対応表にだけある (SCH-R-019)

- [ ] **T-16-02-01**: 状態は stale になる
  - Target: `SchedulingService.list`
  - Scenario: Given `b1`/`a1` の `OLD` が対応表にだけある, When `list()` を呼ぶ
  - Expected: Then 1 件の `state` が `EntryState.stale` である

- [ ] **T-16-02-02**: stale の要素は予約を持たない
  - Target: `SchedulingService.list`
  - Scenario: Given `b1`/`a1` の `OLD` が対応表にだけある, When `list()` を呼ぶ
  - Expected: Then その要素の `toast` が null で、`record` が `OLD` の項目である

#### T-16-03: Given: Tag が予約一覧にだけある (孤立した予約。SCH-R-018, SCH-E-30)

- [ ] **T-16-03-01**: 状態は orphan になる
  - Target: `SchedulingService.list`
  - Scenario: Given `OLD` が予約一覧にだけある, When `list()` を呼ぶ
  - Expected: Then 1 件の `state` が `EntryState.orphan` である

- [ ] **T-16-03-02**: orphan の要素は項目を持たない
  - Target: `SchedulingService.list`
  - Scenario: Given `OLD` が予約一覧にだけある, When `list()` を呼ぶ
  - Expected: Then その要素の `record` が null で、`toast` が `OLD` の予約である

#### T-16-04: Given: 複数の項目と複数の孤立した予約がある (並び。implementation-schedule.md §3.3 list)

- [ ] **T-16-04-01**: 項目は (batchId, alarmId) の順に並ぶ
  - Target: `SchedulingService.list`
  - Scenario: Given 対応表に `b1`/`a2` と `b1`/`a1` を `a2` が先になる順で入れ、予約一覧にも両方ある, When `list()` を呼ぶ
  - Expected: Then 要素が `b1`/`a1`、`b1`/`a2` の順に並ぶ

- [ ] **T-16-04-02**: orphan は項目の後に Tag 順で並ぶ
  - Target: `SchedulingService.list`
  - Scenario: Given 対応表に `b1`/`a1` があり、予約一覧にだけ Tag `ZZ...` と `AA...` がある, When `list()` を呼ぶ
  - Expected: Then 並びが `b1`/`a1` (ok)、Tag `AA...` (orphan)、Tag `ZZ...` (orphan) である

### [異常] Error Cases

#### T-16-05: Given: list で OS の予約一覧の取得が失敗する (SCH-R-016)

- [ ] **T-16-05-01**: ScheduleException をそのまま伝える
  - Target: `SchedulingService.list`
  - Scenario: Given `scheduler.list` が `ScheduleException` を投げる設定, When `list()` を呼ぶ
  - Expected: Then `ScheduleException` を投げる

#### T-16-06: Given: list で対応表の全件取得が失敗する (SCH-R-016)

- [ ] **T-16-06-01**: StorageException をそのまま伝える
  - Target: `SchedulingService.list`
  - Scenario: Given `table.all` が `StorageException` を投げる設定, When `list()` を呼ぶ
  - Expected: Then `StorageException` を投げる

### [エッジケース] Edge Cases

#### T-16-07: Given: 対応表と予約一覧がどちらも空

- [ ] **T-16-07-01**: list は空のリストを返す
  - Target: `SchedulingService.list`
  - Scenario: Given 対応表と予約一覧がどちらも空, When `list()` を呼ぶ
  - Expected: Then 空のリストを返す

#### T-16-08: Given: list の予約一覧の取得対象 (specifications-schedule.md 2.2)

- [ ] **T-16-08-01**: Group を kallr に固定して予約一覧を取得する
  - Target: `SchedulingService.list`
  - Scenario: Given 通常の状態, When `list()` を呼ぶ
  - Expected: Then `scheduler.list` が引数 `'kallr'` で呼ばれる

#### T-16-09: Given: 孤立した予約がある状態で list する (SCH-R-033, SCH-DD-15)

- [ ] **T-16-09-01**: OS の予約を変更しない
  - Target: `SchedulingService.list`
  - Scenario: Given 予約一覧にだけ `OLD` の予約がある, When `list()` を呼ぶ
  - Expected: Then `scheduler.remove` と `scheduler.add` が 1 回も呼ばれず、`scheduler.list('kallr')` が `OLD` を持つ

- [ ] **T-16-09-02**: 対応表を変更しない
  - Target: `SchedulingService.list`
  - Scenario: Given 予約一覧にだけ `OLD` の予約がある, When `list()` を呼ぶ
  - Expected: Then `table.put`・`table.replace`・`table.remove` が 1 回も呼ばれない

#### T-16-10: Given: 通知可否の確認が「通知できる」でない状態で list する (specifications-schedule.md 3.2)

- [ ] **T-16-10-01**: 通知可否の確認を呼ばず完了する
  - Target: `SchedulingService.list`
  - Scenario: Given `env.check` が `ok = false` を返す, When `list()` を呼ぶ
  - Expected: Then `env.check` が 1 回も呼ばれず、例外を投げない

---

## T-17: SchedulingService.reRegisterAll (SVG)

### [正常] Normal Cases

#### T-17-01: Given: Tag が予約一覧に無く、通知時刻が now より後の項目を再登録する (SCH-R-021, IDX-DD-13)

- [ ] **T-17-01-01**: registered の一覧に載る
  - Target: `SchedulingService.reRegisterAll`
  - Scenario: Given 対応表に `b1`/`a1` (tag `OLD`、at `A1`、title `t1`) があり予約一覧は空, When `reRegisterAll(aumid: 'Kallr.Test')` を呼ぶ
  - Expected: Then `report.registered` がその項目 1 件で、他の 3 つの一覧が空である

- [ ] **T-17-01-02**: 保存済みの Tag・時刻・title で OS に追加する
  - Target: `SchedulingService.reRegisterAll`
  - Scenario: Given 対応表に `b1`/`a1` (tag `OLD`、at `A1`、title `t1`) があり予約一覧は空, When `reRegisterAll` を呼ぶ
  - Expected: Then `scheduler.add` が tag `OLD` (再生成していない)、group `kallr`、at `A1`、title `t1` で 1 回呼ばれる

- [ ] **T-17-01-03**: 対応表を変えない
  - Target: `SchedulingService.reRegisterAll`
  - Scenario: Given 対応表に `b1`/`a1` (tag `OLD`、at `A1`、title `t1`) があり予約一覧は空, When `reRegisterAll` を呼ぶ
  - Expected: Then `table.all()` が呼び出し前と等しく、`table.put` と `table.replace` が 1 回も呼ばれない

- [ ] **T-17-01-04**: exitCode は 0 である
  - Target: `SchedulingService.reRegisterAll`
  - Scenario: Given 対応表に `b1`/`a1` (tag `OLD`、at `A1`、title `t1`) があり予約一覧は空, When `reRegisterAll` を呼ぶ
  - Expected: Then `report.exitCode` が 0 である

#### T-17-02: Given: Tag が予約一覧に既にある項目を再登録する (SCH-R-023, SCH-E-22)

- [ ] **T-17-02-01**: alreadyPresent の一覧に載る
  - Target: `SchedulingService.reRegisterAll`
  - Scenario: Given `b1`/`a1` の `OLD` が対応表と予約一覧の両方にある, When `reRegisterAll` を呼ぶ
  - Expected: Then `report.alreadyPresent` がその項目 1 件で、他の 3 つの一覧が空である

- [ ] **T-17-02-02**: 重複を作らない
  - Target: `SchedulingService.reRegisterAll`
  - Scenario: Given `b1`/`a1` の `OLD` が対応表と予約一覧の両方にある, When `reRegisterAll` を呼ぶ
  - Expected: Then `scheduler.add` が 1 回も呼ばれない

#### T-17-03: Given: Tag が予約一覧に無く、通知時刻が now より前の項目を再登録する (SCH-R-022, SCH-E-21, SCH-DD-08)

- [ ] **T-17-03-01**: skippedPast の一覧に載る
  - Target: `SchedulingService.reRegisterAll`
  - Scenario: Given 対応表に `b1`/`a1` (tag `OLD`、at `2026-11-22T09:00:00+09:00`) があり予約一覧は空, When `reRegisterAll` を呼ぶ
  - Expected: Then `report.skippedPast` がその項目 1 件である

- [ ] **T-17-03-02**: OS に追加しない
  - Target: `SchedulingService.reRegisterAll`
  - Scenario: Given 対応表に `b1`/`a1` (tag `OLD`、at `2026-11-22T09:00:00+09:00`) があり予約一覧は空, When `reRegisterAll` を呼ぶ
  - Expected: Then `scheduler.add` が 1 回も呼ばれない

- [ ] **T-17-03-03**: 過去のため登録しないことは失敗ではない
  - Target: `SchedulingService.reRegisterAll`
  - Scenario: Given 対応表に `b1`/`a1` (tag `OLD`、at `2026-11-22T09:00:00+09:00`) があり予約一覧は空, When `reRegisterAll` を呼ぶ
  - Expected: Then `report.exitCode` が 0 である

### [異常] Error Cases

#### T-17-04: Given: 再登録で通知可否の確認が「通知できる」でない (SCH-R-034, SCH-E-27, SCH-DD-16, IDX-R-007)

- [ ] **T-17-04-01**: UnavailableException を投げる
  - Target: `SchedulingService.reRegisterAll`
  - Scenario: Given `env.check` が `ok = false` を返し、対応表に再登録できる項目が 1 件ある, When `reRegisterAll` を呼ぶ
  - Expected: Then `UnavailableException` を投げる

- [ ] **T-17-04-02**: 何も登録しない
  - Target: `SchedulingService.reRegisterAll`
  - Scenario: Given `env.check` が `ok = false` を返し、対応表に再登録できる項目が 1 件ある, When `reRegisterAll` を呼んで失敗した
  - Expected: Then `scheduler.add` が 1 回も呼ばれない

#### T-17-05: Given: 再登録で 1 件の追加が OS のエラーで失敗する (SCH-R-035, SCH-E-28)

- [ ] **T-17-05-01**: 失敗した項目が理由とともに failed の一覧に載る
  - Target: `SchedulingService.reRegisterAll`
  - Scenario: Given 対応表の `b1`/`a1` の追加で `scheduler.add` が `ScheduleException(0x80070057)` を投げる設定, When `reRegisterAll` を呼ぶ
  - Expected: Then `report.failed` が `b1`/`a1` の項目と空でない理由の 1 件である

- [ ] **T-17-05-02**: exitCode は 2 である
  - Target: `SchedulingService.reRegisterAll`
  - Scenario: Given 同上, When `reRegisterAll` を呼ぶ
  - Expected: Then `report.exitCode` が 2 である

- [ ] **T-17-05-03**: 失敗した項目は registered に載らない
  - Target: `SchedulingService.reRegisterAll`
  - Scenario: Given 同上, When `reRegisterAll` を呼ぶ
  - Expected: Then `report.registered` が空である

- [ ] **T-17-05-04**: 失敗しても対応表を変えない
  - Target: `SchedulingService.reRegisterAll`
  - Scenario: Given 同上, When `reRegisterAll` を呼ぶ
  - Expected: Then `table.all()` が呼び出し前と等しい

### [エッジケース] Edge Cases

#### T-17-06: Given: 再登録で通知時刻が now と同じ項目 (境界。SCH-R-022)

- [ ] **T-17-06-01**: now と同じ時刻は skippedPast に載る
  - Target: `SchedulingService.reRegisterAll`
  - Scenario: Given 対応表に at が `2026-11-22T10:00:00` (now と同じ) の項目があり予約一覧は空, When `reRegisterAll` を呼ぶ
  - Expected: Then `report.skippedPast` がその項目 1 件で、`scheduler.add` が 1 回も呼ばれない

#### T-17-07: Given: 再登録で通知時刻が now の 1 秒後の項目 (境界。SCH-R-021)

- [ ] **T-17-07-01**: now の 1 秒後は registered に載る
  - Target: `SchedulingService.reRegisterAll`
  - Scenario: Given 対応表に at が `2026-11-22T10:00:01` (now の 1 秒後) の項目があり予約一覧は空, When `reRegisterAll` を呼ぶ
  - Expected: Then `report.registered` がその項目 1 件である

#### T-17-08: Given: 4 種類の項目が混在し、失敗した項目の後にも項目がある (SCH-R-024, SCH-R-035, SCH-E-28, SCH-E-29)

> 対応表: R1 (未来・予約なし)、R2 (過去・予約なし)、R3 (予約あり)、R4 (未来・予約なし。`scheduler.add` が `ScheduleException(0x80070057)` を投げる)、R5 (未来・予約なし)。処理順は R1 → R5。

- [ ] **T-17-08-01**: registered は失敗の後の項目を含む
  - Target: `SchedulingService.reRegisterAll`
  - Scenario: Given R1〜R5 が上の状態, When `reRegisterAll` を呼ぶ
  - Expected: Then `report.registered` が R1 と R5 である (R4 の失敗で処理を止めない)

- [ ] **T-17-08-02**: failed は R4 だけである
  - Target: `SchedulingService.reRegisterAll`
  - Scenario: Given R1〜R5 が上の状態, When `reRegisterAll` を呼ぶ
  - Expected: Then `report.failed` が R4 の 1 件である

- [ ] **T-17-08-03**: skippedPast は R2 だけである
  - Target: `SchedulingService.reRegisterAll`
  - Scenario: Given R1〜R5 が上の状態, When `reRegisterAll` を呼ぶ
  - Expected: Then `report.skippedPast` が R2 の 1 件である

- [ ] **T-17-08-04**: alreadyPresent は R3 だけである
  - Target: `SchedulingService.reRegisterAll`
  - Scenario: Given R1〜R5 が上の状態, When `reRegisterAll` を呼ぶ
  - Expected: Then `report.alreadyPresent` が R3 の 1 件である

- [ ] **T-17-08-05**: 失敗が 1 件でもあれば exitCode は 2 である
  - Target: `SchedulingService.reRegisterAll`
  - Scenario: Given R1〜R5 が上の状態, When `reRegisterAll` を呼ぶ
  - Expected: Then `report.exitCode` が 2 である

#### T-17-09: Given: 対応表が空

- [ ] **T-17-09-01**: 4 つの一覧がすべて空で exitCode は 0 である
  - Target: `SchedulingService.reRegisterAll`
  - Scenario: Given 対応表が空, When `reRegisterAll` を呼ぶ
  - Expected: Then `registered`・`failed`・`skippedPast`・`alreadyPresent` がすべて空で、`exitCode` が 0 である

---

## T-18: SchedulingService: 入力の正規化と検査 (SVN)

### [正常] Normal Cases

#### T-18-01: Given: add の batchId の前後に空白がある (契約。仕様 3.3)

- [ ] **T-18-01-01**: 返り値の batchId は前後の空白を削除した値になる
  - Target: `SchedulingService.add`
  - Scenario: Given `batchId` が `" b1 "`、`alarmId` が `a1`, When `add` を呼ぶ
  - Expected: Then 返り値の `batchId` が `b1` である

- [ ] **T-18-01-02**: 対応表は前後の空白を削除したキーで保存される
  - Target: `SchedulingService.add`
  - Scenario: Given `batchId` が `" b1 "`、`alarmId` が `a1`, When `add` を呼ぶ
  - Expected: Then `table.get('b1','a1')` が項目を返す

#### T-18-02: Given: add の alarmId の前後に空白がある (契約。仕様 3.3)

- [ ] **T-18-02-01**: 返り値の alarmId は前後の空白を削除した値になる
  - Target: `SchedulingService.add`
  - Scenario: Given `batchId` が `b1`、`alarmId` が `" a1 "`, When `add` を呼ぶ
  - Expected: Then 返り値の `alarmId` が `a1` である

#### T-18-03: Given: cancel の batchId の前後に空白がある (契約。仕様 3.3)

- [ ] **T-18-03-01**: 前後の空白を削除したキーの項目を取り消す
  - Target: `SchedulingService.cancel`
  - Scenario: Given 対応表と予約一覧に `b1`/`a1` の項目と予約があり、`batchId` が `" b1 "`, When `cancel` を呼ぶ
  - Expected: Then `table.get('b1','a1')` が null になり、予約一覧から該当の予約が消える

#### T-18-04: Given: cancel の alarmId の前後に空白がある (契約。仕様 3.3)

- [ ] **T-18-04-01**: 前後の空白を削除したキーの項目を取り消す
  - Target: `SchedulingService.cancel`
  - Scenario: Given 対応表と予約一覧に `b1`/`a1` の項目と予約があり、`alarmId` が `" a1 "`, When `cancel` を呼ぶ
  - Expected: Then `table.get('b1','a1')` が null になり、予約一覧から該当の予約が消える

#### T-18-05: Given: add の aumid の前後に空白がある (契約。specifications-index 3.1)

- [ ] **T-18-05-01**: 前後の空白を削除した aumid で通知可否の確認をする
  - Target: `SchedulingService.add`
  - Scenario: Given `aumid` が `" Kallr.Test "`、ほかは有効な値, When `add` を呼ぶ
  - Expected: Then `env.check` が `Kallr.Test` で呼ばれる

#### T-18-06: Given: reRegisterAll の aumid の前後に空白がある (契約。specifications-index 3.1)

- [ ] **T-18-06-01**: 前後の空白を削除した aumid で通知可否の確認をする
  - Target: `SchedulingService.reRegisterAll`
  - Scenario: Given `aumid` が `" Kallr.Test "`, When `reRegisterAll` を呼ぶ
  - Expected: Then `env.check` が `Kallr.Test` で呼ばれる

### [異常] Error Cases

#### T-18-07: Given: add の batchId が空文字 (契約。仕様 3.3, IDX-DD-02, SCH-R-001)

- [ ] **T-18-07-01**: `UsageException` を投げる
  - Target: `SchedulingService.add`
  - Scenario: Given `batchId` が `""`、ほかは有効な値, When `add` を呼ぶ
  - Expected: Then `UsageException` を投げる

- [ ] **T-18-07-02**: `env.check` を呼ばない
  - Target: `SchedulingService.add`
  - Scenario: Given `batchId` が `""`、呼び出しを記録する Fake `env`, When `add` を呼ぶ
  - Expected: Then `env.check` が 1 度も呼ばれない

- [ ] **T-18-07-03**: `table` と `scheduler` に触れない
  - Target: `SchedulingService.add`
  - Scenario: Given `batchId` が `""`, When `add` を呼ぶ
  - Expected: Then `table` と `scheduler` の呼び出し記録が空である

#### T-18-08: Given: add の alarmId が空文字 (契約。仕様 3.3, IDX-DD-02, SCH-R-001)

- [ ] **T-18-08-01**: `UsageException` を投げる
  - Target: `SchedulingService.add`
  - Scenario: Given `alarmId` が `""`、ほかは有効な値, When `add` を呼ぶ
  - Expected: Then `UsageException` を投げる

#### T-18-09: Given: add の batchId が空白だけ (契約。仕様 3.3, IDX-DD-02, SCH-R-001)

- [ ] **T-18-09-01**: `UsageException` を投げる
  - Target: `SchedulingService.add`
  - Scenario: Given `batchId` が `"   "`、ほかは有効な値, When `add` を呼ぶ
  - Expected: Then `UsageException` を投げる

#### T-18-10: Given: add の alarmId が空白だけ (契約。仕様 3.3, IDX-DD-02, SCH-R-001)

- [ ] **T-18-10-01**: `UsageException` を投げる
  - Target: `SchedulingService.add`
  - Scenario: Given `alarmId` が `"   "`、ほかは有効な値, When `add` を呼ぶ
  - Expected: Then `UsageException` を投げる

#### T-18-11: Given: cancel の batchId が空文字 (契約。仕様 3.3, IDX-DD-02, SCH-R-001)

- [ ] **T-18-11-01**: `UsageException` を投げる
  - Target: `SchedulingService.cancel`
  - Scenario: Given `batchId` が `""`, When `cancel` を呼ぶ
  - Expected: Then `UsageException` を投げる

- [ ] **T-18-11-02**: `table` に触れない
  - Target: `SchedulingService.cancel`
  - Scenario: Given `batchId` が `""`, When `cancel` を呼ぶ
  - Expected: Then `table` の呼び出し記録が空で、`NotFoundException` ではない

#### T-18-12: Given: cancel の alarmId が空文字 (契約。仕様 3.3, IDX-DD-02, SCH-R-001)

- [ ] **T-18-12-01**: `UsageException` を投げる
  - Target: `SchedulingService.cancel`
  - Scenario: Given `alarmId` が `""`, When `cancel` を呼ぶ
  - Expected: Then `UsageException` を投げる

#### T-18-13: Given: cancel の batchId が空白だけ (契約。仕様 3.3, IDX-DD-02, SCH-R-001)

- [ ] **T-18-13-01**: `UsageException` を投げる
  - Target: `SchedulingService.cancel`
  - Scenario: Given `batchId` が `"   "`, When `cancel` を呼ぶ
  - Expected: Then `UsageException` を投げる

#### T-18-14: Given: cancel の alarmId が空白だけ (契約。仕様 3.3, IDX-DD-02, SCH-R-001)

- [ ] **T-18-14-01**: `UsageException` を投げる
  - Target: `SchedulingService.cancel`
  - Scenario: Given `alarmId` が `"   "`, When `cancel` を呼ぶ
  - Expected: Then `UsageException` を投げる

#### T-18-15: Given: add の aumid が空白だけ (契約。specifications-index 3.1)

- [ ] **T-18-15-01**: `UsageException` を投げ、`env.check` を呼ばない
  - Target: `SchedulingService.add`
  - Scenario: Given `aumid` が `"   "`、ほかは有効な値, When `add` を呼ぶ
  - Expected: Then `UsageException` を投げ、`env.check` が 1 度も呼ばれない

#### T-18-16: Given: reRegisterAll の aumid が空白だけ (契約。specifications-index 3.1)

- [ ] **T-18-16-01**: `UsageException` を投げ、何も登録しない
  - Target: `SchedulingService.reRegisterAll`
  - Scenario: Given `aumid` が `"   "`, When `reRegisterAll` を呼ぶ
  - Expected: Then `UsageException` を投げ、`scheduler` の呼び出し記録が空である

### [エッジケース] Edge Cases

#### T-18-17: Given: 対応表に `b1`/`a1` があり、前後に空白のある `" b1 "` で add する (契約。仕様 3.3)

- [ ] **T-18-17-01**: 空白を削除した同じキーなので、新規ではなく置換として扱う
  - Target: `SchedulingService.add`
  - Scenario: Given 対応表と予約一覧に `b1`/`a1` の項目と予約があり、`batchId` が `" b1 "`, When `add` を呼ぶ
  - Expected: Then 置換の手順になり、`scheduler.add` の後に `scheduler.remove(OLD)` が呼ばれる

---

## Coverage Check

### 除外 (別ファイルが担当)

- SCH-R-001, SCH-R-012, SCH-R-028, SCH-DD-03, SCH-DD-11, SCH-E-01, SCH-E-02, SCH-E-25, IDX-DD-02, IDX-DD-10: `parseArgs` (tasks-cli.md)。空・空白の検査を `SchedulingService` で確かめるのは T-18
- SCH-R-032, SCH-E-31: list の出力書式 (tasks-cli.md)
- SCH-DD-09, IDX-DD-04, IDX-DD-05: 例外から終了コードへの変換 (tasks-cli.md)。本書は投げる例外の型を確かめる
- SCH-R-025〜027, SCH-R-029, SCH-R-009 の置換キュー単体、SCH-R-002, SCH-R-031: tasks-schedule.md (T-04〜T-06)
- SCH-E-24: 対象外 (仕様が結果を保証しない)

### 判定規則 (Section 4)

| Source item                                                                                                 | Task ID(s)                                                                                                                                                                                                             |
| ----------------------------------------------------------------------------------------------------------- | ---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| SCH-R-003                                                                                                   | T-07-05-01〜04                                                                                                                                                                                                         |
| SCH-R-004                                                                                                   | T-07-01-01〜05                                                                                                                                                                                                         |
| SCH-R-005                                                                                                   | T-07-02-01〜05, T-07-03-01                                                                                                                                                                                             |
| SCH-R-006                                                                                                   | T-07-04-01〜04                                                                                                                                                                                                         |
| SCH-R-007                                                                                                   | T-07-09-01〜03, T-07-14-01, T-07-15-01                                                                                                                                                                                 |
| 契約 (仕様 3.3。batchId と alarmId を trim し、削除後の値を ID に使う。空なら実行前の検査で UsageException) | T-18-01-01〜02, T-18-02-01, T-18-03-01, T-18-04-01, T-18-05-01, T-18-06-01, T-18-07-01〜03, T-18-08-01, T-18-09-01, T-18-10-01, T-18-11-01〜02, T-18-12-01, T-18-13-01, T-18-14-01, T-18-15-01, T-18-16-01, T-18-17-01 |
| D8 (Tag の重複確認は予約一覧と対応表の両方。specifications-index.md 7.2)                                    | T-07-14-01, T-07-15-01                                                                                                                                                                                                 |
| SCH-R-008                                                                                                   | T-07-01-02〜04, T-07-06-01, T-07-06-02, T-07-07-01                                                                                                                                                                     |
| SCH-R-009                                                                                                   | T-07-02-01〜05                                                                                                                                                                                                         |
| SCH-R-010                                                                                                   | T-07-08-01〜04, T-07-11-01〜06, T-14-06-01〜04, T-14-13-01                                                                                                                                                             |
| SCH-R-011                                                                                                   | T-07-01-02, T-07-02-02                                                                                                                                                                                                 |
| SCH-R-036                                                                                                   | T-14-01-01〜04, T-14-02-01〜03, T-14-03-01〜02, T-14-04-01〜03, T-14-05-01〜02, T-14-06-01〜04, T-14-07-01〜03, T-14-08-01〜02, T-14-09-01〜04, T-14-10-01〜02, T-14-11-01, T-14-12-01〜02, T-14-13-01〜02             |
| SCH-R-013                                                                                                   | T-15-02-01〜03                                                                                                                                                                                                         |
| SCH-R-014                                                                                                   | T-15-01-01〜03                                                                                                                                                                                                         |
| SCH-R-015                                                                                                   | T-15-03-01〜02, T-15-04-01〜04                                                                                                                                                                                         |
| SCH-R-030                                                                                                   | T-07-17-01〜03, T-14-03-01, T-15-05-01〜02                                                                                                                                                                             |
| SCH-R-016                                                                                                   | T-16-05-01, T-16-06-01                                                                                                                                                                                                 |
| SCH-R-017                                                                                                   | T-16-01-01〜02                                                                                                                                                                                                         |
| SCH-R-018                                                                                                   | T-16-03-01〜02                                                                                                                                                                                                         |
| SCH-R-019                                                                                                   | T-16-02-01〜02                                                                                                                                                                                                         |
| SCH-R-020                                                                                                   | T-16-04-01〜02, T-16-07-01, T-16-09-01〜02                                                                                                                                                                             |
| SCH-R-033                                                                                                   | T-16-03-01〜02, T-16-09-01〜02                                                                                                                                                                                         |
| SCH-R-034                                                                                                   | T-17-04-01〜02                                                                                                                                                                                                         |
| SCH-R-021                                                                                                   | T-17-01-01〜04, T-17-07-01                                                                                                                                                                                             |
| SCH-R-022                                                                                                   | T-17-03-01〜03, T-17-06-01                                                                                                                                                                                             |
| SCH-R-023                                                                                                   | T-17-02-01〜02                                                                                                                                                                                                         |
| SCH-R-024                                                                                                   | T-17-01-04, T-17-05-02, T-17-08-01〜05, T-17-09-01                                                                                                                                                                     |
| SCH-R-035                                                                                                   | T-17-05-01〜04, T-17-08-01〜02                                                                                                                                                                                         |

### 例外的なケース (Section 5)

| Source item                                          | Task ID(s)                                 |
| ---------------------------------------------------- | ------------------------------------------ |
| SCH-E-04                                             | T-07-06-01, T-07-06-02, T-07-11-01〜06     |
| SCH-E-06                                             | T-07-05-01〜04                             |
| SCH-E-07                                             | T-07-02-01〜05                             |
| SCH-E-08                                             | T-07-04-01〜04                             |
| SCH-E-09                                             | T-07-03-01                                 |
| SCH-E-10                                             | T-07-11-01〜06                             |
| SCH-E-11                                             | T-07-10-01〜04                             |
| SCH-E-12                                             | T-07-12-01〜05, T-07-13-01〜03             |
| SCH-E-13                                             | T-07-17-01〜03                             |
| SCH-E-14                                             | T-07-08-01〜04                             |
| SCH-E-15                                             | T-07-09-01〜03                             |
| SCH-E-16                                             | T-07-07-01                                 |
| SCH-E-17                                             | T-15-02-01〜03                             |
| SCH-E-18                                             | T-15-04-01〜04                             |
| SCH-E-19                                             | T-15-05-01〜02                             |
| SCH-E-21                                             | T-17-03-01〜03, T-17-06-01                 |
| SCH-E-22                                             | T-17-02-01〜02                             |
| SCH-E-23                                             | T-07-16-01〜02                             |
| SCH-E-27                                             | T-17-04-01〜02                             |
| SCH-E-28                                             | T-17-05-01〜04, T-17-08-01〜05             |
| SCH-E-29                                             | T-17-08-01〜05                             |
| SCH-E-30                                             | T-16-03-01〜02, T-16-09-01〜02             |
| SCH-E-32                                             | T-07-15-01                                 |
| 索引 5 章: 通知設定が無効 / AUMID が未登録のまま add | T-07-05-01〜04                             |
| 索引 5 章: 発火後の add は新規                       | T-07-04-01〜04                             |
| 索引 5 章: 対応表の更新失敗後に予約が残る (孤児)     | T-07-08-01〜04                             |
| 索引 5 章: 置換前の予約の削除失敗 (両方が残る)       | T-07-12-01〜05                             |
| 索引 5 章: 一括再登録で過去の時刻                    | T-17-03-01〜03                             |
| 索引 5 章: 通知できない状態の re-register-all        | T-17-04-01〜02                             |
| 索引 5 章: 削除が「対象が無い」を返す                | T-07-17-01〜03, T-14-03-01, T-15-05-01〜02 |
| 索引 5 章: 孤立した予約                              | T-16-03-01〜02, T-16-09-01〜02             |

### 設計判断 (Section 2.5)

| Source item                                            | Task ID(s)                                                                     |
| ------------------------------------------------------ | ------------------------------------------------------------------------------ |
| SCH-DD-01 (置換の 4 段階)                              | T-07-02-05, T-07-10-01〜04, T-07-11-01〜06, T-07-12-01〜05, T-07-13-01〜03     |
| SCH-DD-05 (過去は OS の 0x80070057)                    | T-07-06-01〜02                                                                 |
| SCH-DD-06 (cancel の見つからない)                      | T-15-02-01〜03                                                                 |
| SCH-DD-07 (cancel は予約 → 対応表の順)                 | T-15-01-03, T-15-04-01〜04                                                     |
| SCH-DD-08 (過去は登録せず一覧へ)                       | T-17-03-01〜03, T-17-06-01                                                     |
| SCH-DD-10 (Tag 重複は再生成 3 回まで)                  | T-07-09-01〜03                                                                 |
| SCH-DD-13 (削除の「対象が無い」は成功)                 | T-07-17-01〜03, T-14-03-01, T-15-05-01〜02                                     |
| SCH-DD-15 (孤立した予約は報告だけ)                     | T-16-03-01〜02, T-16-09-01〜02                                                 |
| SCH-DD-16 (re-register-all の通知可否の確認と個別失敗) | T-17-04-01〜02, T-17-05-01〜04, T-17-08-01〜05                                 |
| IDX-DD-06 (cancel の見つからない)                      | T-15-02-01〜03                                                                 |
| IDX-DD-07 (過去の記録は一覧へ)                         | T-17-03-01〜03                                                                 |
| IDX-DD-08 (再生成は 3 回まで)                          | T-07-09-01〜03                                                                 |
| IDX-DD-13 (re-register-all)                            | T-17-01-01〜04, T-17-02-01〜02, T-17-03-01〜03, T-17-04-01〜02, T-17-08-01〜05 |

### 決定記録・索引の規則 (Section 2.6)

| Source item                                                    | Task ID(s)                                     |
| -------------------------------------------------------------- | ---------------------------------------------- |
| DR-05 (追加してから削除)                                       | T-07-02-05, T-07-11-06, T-07-12-02, T-07-17-03 |
| DR-08 決定 1 (DB を先に書く 4 段。DR-07 決定 1 を置き換え)     | T-07-02-05, T-07-10-02                         |
| DR-08 決定 3 / DR-07 決定 3 (保留からの再開: 段階 2 / 3 / 4)   | T-14-01-01〜04, T-14-02-01〜03, T-14-03-01〜02 |
| DR-07 決定 4 (再開は冪等。置換後の Tag が既にあれば追加しない) | T-14-02-01                                     |
| 3.5 段階 1 の失敗 (置換前の予約だけが残る)                     | T-07-10-01〜04                                 |
| 3.5 段階 2 の拒否 (置換前の予約だけが残る)                     | T-07-11-01〜06                                 |
| 3.5 段階 3 の失敗 (両方が残る)                                 | T-07-12-01〜05                                 |
| 3.5 段階 4 の失敗 (置換後の予約だけが残る)                     | T-07-13-01〜03                                 |
| 3.5 段階 4 の完了 (失敗状態ではない)                           | T-07-02-01〜05                                 |
| 3.5 段階 3 の後・段階 4 の前 (置換後の予約だけが残る)          | T-14-03-01〜02                                 |
| 3.5 再開時の置換後の時刻が過去                                 | T-14-09-01〜04, T-14-10-01〜02, T-14-11-01     |
| IDX-R-001 (add の最初に通知可否の確認)                         | T-07-05-01〜04                                 |
| IDX-R-002 / IDX-R-003 (分類と Tag の生成)                      | T-07-01-01, T-07-02-01, T-07-04-01, T-07-09-01 |
| IDX-R-004 (新規は追加してから対応表)                           | T-07-01-04                                     |
| IDX-R-005 (置換)                                               | T-07-02-05                                     |
| IDX-R-006 (cancel の順序)                                      | T-15-01-03                                     |
| IDX-R-007 (re-register-all の最初の確認)                       | T-17-04-01〜02                                 |

## Category Balance

| Test Target                                 | Normal     | Error     | Edge     | Result |
| ------------------------------------------- | ---------- | --------- | -------- | ------ |
| T-07: SchedulingService.add: 新規・置換     | Normal: 15 | Error: 32 | Edge: 7  | [OK]   |
| T-14: SchedulingService: 保留の再開         | Normal: 14 | Error: 9  | Edge: 11 | [OK]   |
| T-15: SchedulingService.cancel              | Normal: 3  | Error: 9  | Edge: 5  | [OK]   |
| T-16: SchedulingService.list                | Normal: 8  | Error: 2  | Edge: 5  | [OK]   |
| T-17: SchedulingService.reRegisterAll       | Normal: 9  | Error: 6  | Edge: 8  | [OK]   |
| T-18: SchedulingService: 入力の正規化と検査 | Normal: 7  | Error: 13 | Edge: 1  | [OK]   |

<!--
Task ID Format: T-<TestTarget>-<Scenario>-<Case>
- TestTarget: 07 = SVA, 14 = SVP, 15 = SVX, 16 = SVL, 17 = SVG, 18 = SVN
- Scenario: 2-digit (対象内で Normal → Error → Edge に連番)
- Case: 2-digit
-->
