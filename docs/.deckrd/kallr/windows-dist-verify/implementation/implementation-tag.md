---
title: "Implementation Specification: Windows Distribution Verify (Tag)"
based-on: specifications-tag.md v1.0.0
status: Draft
version: 1.0.2
created: "2026-11-22"
---

> implementation-index.md の分割ファイル。Tag の生成と重複の回避、マシン ID の実装を定める。

## 1. Overview

対応する仕様は specifications-tag.md (REQ-F-007, REQ-F-016, REQ-F-017, REQ-F-019)。
共通の前提、ファイル構成、型は implementation-index.md に従う。

---

## 2. Tag (`tag/`)

対象: REQ-F-007, 016, 017, 019 / TAG-R-001〜010。

### 2.1 インターフェース (`providers.dart`)

```dart
abstract interface class ClockProvider { DateTime now(); }                 // ローカル時刻
abstract interface class RandomSourceProvider { String randomHex64(); }    // 小文字 16 進 16 桁
abstract interface class MachineIdProvider { String machineId(); }         // 小文字 16 進 8 桁
```

- 本番の `ClockProvider` は `DateTime.now()`、`RandomSourceProvider` は `Random.secure()` で 8 バイトを得て 16 桁にする。
  マシン ID の生成用の乱数は 4 バイトを同じ方法で得る。

### 2.2 `generateTag` (`generate_tag.dart`)

```dart
String generateTag({
  required DateTime registeredAt,
  required String machineId,
  required String random,
});
```

手順 (TAG-R-001〜003):

1. 検証する。次のどれかなら `ArgumentError` を投げる。補正せず、既定値も使わない。
   - `registeredAt.year` が 0〜9999 の範囲外
   - `machineId` が `^[0-9a-f]{8}$` に一致しない
   - `random` が `^[0-9a-f]{16}$` に一致しない
2. 日時部分を作る。年は 4 桁、月日時分秒は各 2 桁のゼロ埋め。秒未満は使わない (切り捨て)。`registeredAt` はローカル日時のまま使い、`toUtc()` を呼ばない。
3. `'$datetime-$machineId-$random'` を返す。長さは常に 14 + 1 + 8 + 1 + 16 = 40。

時計、乱数、保存領域を参照しない。同じ入力は同じ出力になる (TAG-R-003)。

### 2.3 `allocateTag` (`tag_allocator.dart`)

```dart
String allocateTag({
  required RandomSourceProvider random,
  required MachineIdProvider machineId,
  required Set<String> existingTags,   // 予約一覧 (Group=kallr) の Tag と対応表の Tag の和集合
  required DateTime registeredAt,      // 呼び出し側が ClockProvider.now() から 1 回だけ得た値。時計は引数に取らない
});
```

- `registeredAt` と `machineId` は 1 回だけ得て、ループ中は変えない。乱数だけを毎回 `random.randomHex64()` で得る (TAG-R-006)。
- ループ: 初回の生成 + 再生成 3 回までの最大 4 回試し、`existingTags` に無い最初の Tag を返す。
  4 回とも重複したら `DuplicateTagException(attempts: 4)` (TAG-R-007, IDX-DD-08)。
- `SchedulingService` が `existingTags` を作る。`allocateTag` 自身は予約一覧と対応表のどちらにも触れない。

### 2.4 長さの維持 (REQ-F-007)

- Tag は 40 文字、Group は `kallr` (5 文字) の固定値で、どちらも 64 文字以下 (TAG-R-004)。定数 `const kGroup = 'kallr';` を `models.dart` に置く。
- N 件の登録 (AC-009) と実機での上限は手動検証で行う (implementation-verification.md §4)。コードは N を制限しない。

---

## 3. `MachineIdProvider` の実装

`machineId()` は次の順で評価する (TAG-R-010 → 008 → 009)。

0. 壊れたファイル (`quick_check` が `ok` でない) は、`SqliteStore.open` が `StorageException` を投げる (SCH-R-027)。`machineId()` に届く前に失敗する。
1. `settings` の `machine_id` の行を読む (key から `id` を引き、`id` で値を読む)。読み取りに失敗、または値が `^[0-9a-f]{8}$` でなければ `StorageException` (新しい値を作らない)。
2. 値があればそれを返す。
3. 行が無ければ、`Random.secure()` の 4 バイトから 8 桁を作り、`settings` に `INSERT` して (トランザクション) 返す。保存に失敗したら値を返さず `StorageException`。
4. 結果をインスタンス内にキャッシュし、同じプロセスでは同じ値を返す。

保存領域 (DB ファイル) が削除されていれば implementation-schedule.md §2.3 の 2 で新しく作られ、新しいマシン ID になる。これは許容する (TAG-DD-04)。

---

## 4. Tests

テスト ID の略語と採番は implementation-index.md §5 に従う。このファイルは、担当する対象の略語と、確認する値だけを示す。

| 略語  | 対象                                    | 主な spec の規則         |
| ----- | --------------------------------------- | ------------------------ |
| `TAG` | `generateTag`                           | TAG-R-001〜004           |
| `TAL` | `allocateTag` (重複回避)                | TAG-R-005〜007, SCH-E-32 |
| `MID` | `MachineIdProvider` の実装 (`settings`) | TAG-R-008〜010           |

| 対象 | 確認する値                                                                                                                                                                                          |
| ---- | --------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| TAG  | 40 文字、14 桁の日時、秒未満の切り捨て、同じ入力で同じ出力、年の範囲外・マシン ID・乱数の桁数/大文字/16 進以外で `ArgumentError`                                                                    |
| TAL  | 重複なしで 1 回目の乱数を採用、予約一覧だけ/対応表だけに重複で再生成、3 回の再生成で成功、4 回とも重複で `DuplicateTagException`、日時とマシン ID が不変                                            |
| MID  | 初回に生成して `settings` に保存、再オープンで同値、行なしで新規生成、`id` 経由で読む、`key` の重複を拒否 (ユニークインデックス)、不正な値/壊れた DB で `StorageException` かつ既存の値を変更しない |

---

## 5. Change History

<!-- SemVer: MAJOR = approach discarded, MINOR = decision criterion added,
     PATCH = clarification only. Keep frontmatter `version` equal to the newest row.
     `based-on` must cite a three-part version that exists in the specifications.
     See docs/.deckrd/rules/deckrd-rule-document-versioning.md -->

| Date       | Version | Description                                                    |
| ---------- | ------- | -------------------------------------------------------------- |
| 2026-11-22 | 1.0.0   | Split from implementation.md v1.0.0 (content moved, unchanged) |
| 2026-11-22 | 1.0.1   | Remove the unused `clock` parameter from `allocateTag` (clarification) |
| 2026-11-22 | 1.0.2   | State that a corrupt file fails in `SqliteStore.open`; `machineId()` fails only on an unreadable or invalid value (clarification) |
