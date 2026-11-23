---
title: "DB Migration: Windows Distribution Verify"
based-on: implementation-index.md v1.0.1
status: Draft
version: 1.1.2
created: "2026-11-22"
---

## 1. Overview

### 1.1 Purpose

対応表とマシン ID を保存する SQLite の設計を定めます。扱うのは、テーブル、列、関連、版、移行の規則です。
テーブルの設計は本書 §2 が正本です。implementation-schedule.md §2.2 は、本書を参照します。
プログラムの処理 (置換の手順、接続時の判定、テスト) は implementation-schedule.md が定めます。本書は、列とプログラミング言語の項目との対応だけを示します。

### 1.2 Scope

- 対象は `mappings.sqlite3` 1 ファイルです (implementation-schedule.md §2.1)。
- 現行の版は 1 だけです。移行の実装はまだありません。
- 将来スキーマを変えるときの規則を、先に決めておきます。

---

## 2. Table Design

基準は「通知」です。1 件の予約済み通知を `notifications` の 1 行で表します。
置換のときは、置換後の通知を新しい行として追加します。置換前の行と置換後の行の対応は、`replacement_queue` に持ちます。

### 2.1 Key

通知は 3 つの ID を持ちます。

| 種類      | 列                      | 型      | 役割                                                       |
| --------- | ----------------------- | ------- | ---------------------------------------------------------- |
| 物理 ID   | `id`                    | INTEGER | 行を指す内部の主キー。SQLite が採番する。外へ出さない      |
| 論理 ID   | `group_name` + `tag`    | TEXT×2  | OS の予約と突き合わせる Group と Tag (TAG-R-002)。組で一意 |
| 利用者 ID | `batch_id` + `alarm_id` | TEXT×2  | 呼び出し側が付ける識別子。現行の行の中で一意               |

- 物理 ID は `INTEGER PRIMARY KEY AUTOINCREMENT` です。削除した番号を再利用しません。
- (`group_name`, `tag`) は `UNIQUE` です (SCH-R-025)。
- (`batch_id`, `alarm_id`) は、有効な行 (`notify_status` が 1 または 2) の中だけで一意にします。置換中は旧行 (0) と新行 (2) が同じ組を持つためです。
- `group` は SQL の予約語です。列名は `group_name` とします。
- 物理 ID は `MappingRecord` にも CLI の出力にも出しません。

### 2.2 Tables

```sql
CREATE TABLE notifications (
  id            INTEGER PRIMARY KEY AUTOINCREMENT,
  group_name    TEXT NOT NULL CHECK (length(group_name) BETWEEN 1 AND 64),
  tag           TEXT NOT NULL CHECK (length(tag) = 40),
  batch_id      TEXT NOT NULL CHECK (batch_id <> ''),
  alarm_id      TEXT NOT NULL CHECK (alarm_id <> ''),
  at            TEXT NOT NULL,
  title         TEXT NOT NULL,
  registered_at TEXT NOT NULL,
  notify_status INTEGER NOT NULL DEFAULT 1 CHECK (notify_status IN (0, 1, 2)),
  UNIQUE (group_name, tag)
);

CREATE UNIQUE INDEX notifications_current
  ON notifications (batch_id, alarm_id) WHERE notify_status IN (1, 2);

CREATE TABLE replacement_queue (
  id     INTEGER PRIMARY KEY AUTOINCREMENT,
  new_id INTEGER NOT NULL REFERENCES notifications(id) ON DELETE CASCADE,
  old_id INTEGER REFERENCES notifications(id) ON DELETE SET NULL
);

CREATE INDEX replacement_queue_pending
  ON replacement_queue (id) WHERE old_id IS NOT NULL;

CREATE TABLE settings (
  id    INTEGER PRIMARY KEY AUTOINCREMENT,
  key   TEXT NOT NULL CHECK (key <> ''),
  value TEXT NOT NULL
);

CREATE UNIQUE INDEX settings_key ON settings (key);
```

- `group_name` には常に `kGroup` (`kallr`) を入れます。Group は固定値ですが、OS の予約と同じ組で引けるように持ちます。
- `at` は UTC の ISO 8601 です (例 `2026-11-21T01:02:03.000Z`)。
- `registered_at` はローカル日時の ISO 8601 で、オフセットを付けません。
- 接続ごとに `PRAGMA foreign_keys = ON` を実行します。
- `settings` は、kallr の設定を 1 行 1 値で持つテーブルです。マシン ID もここに置きます。key は §3.3 に示します。
- 行は物理 ID (`id`) で指します。読み書きと削除は `id` 経由で行います。
- ただし `settings` の値の読み取りは、`id` を引かずに、key で直接読みます (`SELECT value FROM settings WHERE key = ?`)。`settings_key` の一意インデックスが 1 回の検索で行を特定するためです。

### 2.3 Replacement Queue

| 列       | 意味                                                             |
| -------- | ---------------------------------------------------------------- |
| `new_id` | 置換後の通知の物理 ID (`notifications.id`)                       |
| `old_id` | 置換前の通知の物理 ID。OS から消して旧行を削除すると NULL になる |

- 保留中の行は `old_id IS NOT NULL` の行です。NULL の行は完了済みで、記録として残します。
- 旧行を削除すると、`ON DELETE SET NULL` で `old_id` が NULL になります。

### 2.4 Relations

| 子                         | 親                 | 多重度 | 親の削除時の動作       |
| -------------------------- | ------------------ | ------ | ---------------------- |
| `replacement_queue.new_id` | `notifications.id` | N : 1  | 子の行も削除 (CASCADE) |
| `replacement_queue.old_id` | `notifications.id` | N : 1  | 子の値を NULL にする   |

- 1 つの通知の行は、`new_id` と `old_id` のどちらでも、キューに複数回現れることがあります。
- 有効な行 (`notify_status` が 1 または 2) は、(`batch_id`, `alarm_id`) ごとに高々 1 つです。

### 2.5 Name Conversion

列名 (code) と Dart のフィールド、仕様上の用語の対応です。

| 列 (code)                     | `MappingRecord` のフィールド | 仕様の用語      |
| ----------------------------- | ---------------------------- | --------------- |
| `notifications.id`            | (持たない)                   | 物理 ID         |
| `notifications.group_name`    | (持たない。`kGroup`)         | Group           |
| `notifications.tag`           | `tag`                        | Tag             |
| `notifications.batch_id`      | `batchId`                    | batchId         |
| `notifications.alarm_id`      | `alarmId`                    | alarmId         |
| `notifications.at`            | `at`                         | 通知時刻        |
| `notifications.title`         | `title`                      | タイトル        |
| `notifications.registered_at` | `registeredAt`               | 登録時刻        |
| `notifications.notify_status` | (持たない)                   | 通知の状態      |
| `replacement_queue.new_id`    | (持たない)                   | 置換後の物理 ID |
| `replacement_queue.old_id`    | (持たない)                   | 置換前の物理 ID |
| `settings.id`                 | (持たない)                   | 物理 ID         |
| `settings.key`                | 設定名 (例 `machine_id`)     | 設定の key      |
| `settings.value`              | 設定の値 (文字列)            | 設定の値        |

---

## 3. Version Management

版は SQLite の `PRAGMA user_version` で管理します。独自の版テーブルは作りません。

### 3.1 Version Table

| code (`user_version`) | name      | 状態 | 内容                                                                |
| --------------------: | --------- | ---- | ------------------------------------------------------------------- |
|                     0 | `empty`   | 内部 | ファイルが無い、またはテーブルが 1 つも無い                         |
|                     1 | `initial` | 現行 | `notifications`、`replacement_queue`、`settings` の 3 テーブル (§2) |
|                   2〜 | (未定義)  | 予約 | 将来の変更に使う。定義するまで読み込まない                          |

- `empty` は保存されません。新規作成のときに `initial` へ直接進みます。
- 名前は、ログやエラーメッセージで版を示すためのものです。保存する値は code だけです。

### 3.2 Notify Status Code

`notifications.notify_status` の code と名前です。DB に保存する値は code だけです。

| code (`notify_status`) | name         | 意味                                                 |
| ---------------------: | ------------ | ---------------------------------------------------- |
|                      1 | `current`    | 現行の通知。(`batch_id`, `alarm_id`) ごとに高々 1 つ |
|                      2 | `pending`    | 置換後の行。置換の段階 4 が済むまでの状態 (DR-08)    |
|                      0 | `superseded` | 置換された旧行。OS から消した後に削除する            |

- 状態を足すときは、`CHECK` を広げる移行 (版 2 以降) を行います。`CHECK` は `ALTER` で変えられないためです。
- 列名に `notify_` を付けるのは、他の状態 (`status`) と区別するためです。

### 3.3 Table Code

`settings` テーブルは `key` と `value` の組で値を持ちます。`key` の code と意味は次のとおりです。

| key (code)   | name      | value の形式      | 導入した版 |
| ------------ | --------- | ----------------- | ---------: |
| `machine_id` | マシン ID | 小文字 16 進 8 桁 |          1 |

新しい key を足しても、`user_version` は上げません。値の追加はスキーマの変更にあたらないためです。

---

## 4. Migration Rules

移行を足すときは、次の規則を守ります。

1. 前進だけ: N → N+1 の移行を 1 段ずつ積みます。後戻り (ダウングレード) は作りません。
2. 1 段 1 トランザクション: 移行の SQL と `PRAGMA user_version = N+1` を同じ `BEGIN` … `COMMIT` に入れます。失敗したら `ROLLBACK` し、版は変わりません (SCH-R-026)。
3. 事前の退避: 移行の前に、同じ場所へ `mappings.sqlite3.bak-v<N>` をコピーします。コピーに失敗したら移行しません。
4. 失敗は止める: 移行が失敗したら、途中の版のまま使いません (SCH-R-027)。
5. データを失わない: 列の削除と型の変更は、新しいテーブルを作ってから行を写し、最後に入れ替えます。
6. 版の記録: 移行を足すたびに、§3.1 の表へ行を足し、本書の version と Change History を更新します。

---

## 5. Migration Steps

| from | to | name      | 内容                                                                                         |
| ---: | -: | --------- | -------------------------------------------------------------------------------------------- |
|    0 |  1 | `initial` | 新規作成。`notifications`、`replacement_queue`、`settings` を作り、`user_version = 1` にする |

- 0 → 1 は移行ではなく初回の作成です。`CREATE TABLE IF NOT EXISTS` を使います。
- 2 以降の段は、必要になった時点でこの表へ足します。

---

## 6. Change History

| version | date       | 内容                                                                                            |
| ------- | ---------- | ----------------------------------------------------------------------------------------------- |
| 1.0.0   | 2026-11-22 | 初版。通知テーブルと置換キューの設計、関連、版 1 の定義、移行の規則                             |
| 1.1.0   | 2026-11-22 | `settings` の追加、`notify_status` と `pending` (DR-07)                                         |
| 1.1.1   | 2026-11-22 | `pending` が段階 4 まで続く根拠として DR-08 を引用                                              |
| 1.1.2   | 2026-11-22 | `settings` の値は、`id` を引かずに key で直接読む (明確化。`id` 経由の規則は、更新と削除に限る) |
