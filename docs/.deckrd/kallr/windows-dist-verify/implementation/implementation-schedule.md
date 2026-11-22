---
title: "Implementation Specification: Windows Distribution Verify (Schedule)"
based-on: specifications-schedule.md v1.1.0
status: Draft
version: 1.0.0
created: "2026-11-22"
---

> implementation-index.md の分割ファイル。対応表 (SQLite) の実装、予約の追加・取り消し・置換・再登録、これらの CLI を定める。

## 1. Overview

対応する仕様は specifications-schedule.md (REQ-F-001、004、005、006、020)。
DB の設計は db-migration.md が正本。共通の前提、ファイル構成、型は implementation-index.md に従う。

---

## 2. Store (`store/`)

対象: REQ-F-019, 020 / SCH-R-025〜027, 029 / TAG-R-008〜010。

### 2.1 保存先

- 既定のパス: `%LOCALAPPDATA%\kallr\w1-w7-verify\mappings.sqlite3` (SCH-DD-12 の「実装で決める」を、ここで決める)。
  `LOCALAPPDATA` が無い場合は `StorageException`。
  ローミングしない領域を使うのは、マシン ID と OS の予約の情報が、そのマシン固有のためです。
- `--db <path>` があればそれを使う (SCH-R-029)。
- 親ディレクトリが無ければ作る。ファイルが無ければ空の対応表として新規に作る (specifications-schedule.md §3.3 の初回の利用)。

### 2.2 スキーマ

テーブル、列、インデックス、外部キー、版 (`PRAGMA user_version`) の定義は、db-migration.md §2〜§3 を正本とする。本書は DDL を重ねて持たない。

- 列とプログラムの項目の対応は db-migration.md §2.5 に従う。`id` は内部の物理 ID で、`MappingRecord` には持たない。
- (`group_name`, `tag`) の UNIQUE が SCH-R-025 の「Tag は対応表の全体で一意」を DB 側でも守る。
- `at` は UTC の絶対時刻として保存し、読み戻して `DateTime.parse(...)` で同じ時刻を復元する (再登録で同じ時刻を使うため)。
- `title` は UTF-8 のまま保存する (SCH-E-23)。
- マシン ID は `settings` の `machine_id` キーに 1 行だけ持つ。`settings` の読み書きと削除は、key から `id` を引いて、`id` 経由で行う。

### 2.3 接続の開き方

`SqliteStore.open(String path)` が 1 つの `Database` を開き、`MappingTable` と `MachineIdProvider` の両方を返す。

1. ファイルが存在する場合:
   - 開く。`SqliteException` は `StorageException` に変える。
   - `PRAGMA quick_check` を実行し、結果が `ok` でなければ `StorageException` (壊れている。作り直さない。SCH-R-027)。
   - `PRAGMA user_version` が 1 以外なら `StorageException`。
2. ファイルが存在しない場合: ファイルを作り、`user_version = 1` とスキーマを作成する。
3. 書き込みはすべて `BEGIN` … `COMMIT` で囲み、例外時は `ROLLBACK` して `StorageException` に変える (SCH-R-026)。

### 2.4 `MappingTable`

```dart
abstract interface class MappingTable {
  MappingRecord? get(String batchId, String alarmId);
  void put(MappingRecord record);              // 同じ (batchId, alarmId) は値を置換する (id は不変)
  int replace(MappingRecord record);           // 有効な行を superseded にし、新行 (pending) とキューの行を 1 トランザクションで追加する。キューの id を返す
  List<PendingRemoval> pendingRemovals();      // old_id が NULL でない置換キューの行
  void completeRemoval(int queueId);           // 旧行を削除し、新行を current にする (old_id は NULL になる)
  void abortReplacement(int queueId);          // 新行とキューの行を削除し、旧行を current に戻す
  void remove(String batchId, String alarmId);
  List<MappingRecord> all();
  Set<String> tags();                          // 重複回避用
}
```

- `put` は、現行の行が無ければ `INSERT`、あれば `UPDATE` を 1 トランザクションで実行する。`UPDATE` でも `id` は変わらない。`group_name` には `kGroup` を入れる。
- `replace` は、1 トランザクションで次を行う。
  - 有効な行 (旧行) の `notify_status` を 0 (`superseded`) にする。
  - 新しい行を `notify_status = 2` (`pending`) で追加する。
  - `(new_id, old_id)` を `replacement_queue` に追加する。
- `completeRemoval` は、1 トランザクションで旧行を削除し、新行を `notify_status = 1` にする。`ON DELETE SET NULL` で `old_id` が NULL になる。
- `abortReplacement` は、OS が置換後の予約の追加を拒否したときに使う。
  1 トランザクションで、新行を削除 (`ON DELETE CASCADE` でキューの行も消える) し、旧行を `notify_status = 1` に戻す。
- 別の通知が同じ (Group, Tag) を持つと UNIQUE 違反になり、`StorageException` を投げて何も変えない。
- `get`、`remove`、`all` は有効な行 (`notify_status` が 1 または 2) だけを対象にする。`tags()` は旧行を含む全行の Tag を返す。旧行は OS にまだ残っているためです。
- `PendingRemoval` は `queueId`、`oldTag`、`group`、置換後の `MappingRecord` を持つ値型で、`models.dart` に置く。
- 接続ごとに `PRAGMA foreign_keys = ON` を実行する。
- テーブルの設計は db-migration.md §2 に従う。
- `remove` は対象が無くてもエラーにしない (存在確認は呼び出し側)。

---

## 3. Scheduling (`schedule/`)

対象: REQ-F-001, 004〜006, 012 / SCH-R-001〜035。

### 3.1 `ToastScheduler` (`toast_scheduler.dart`)

```dart
abstract interface class ToastScheduler {
  /// OS が拒否したら ScheduleException(hresult) を投げる
  void add({required String tag, required String group,
            required DateTime at, required String title});
  /// 削除できたら true。該当する予約が無い (発火済み) ときは false。失敗は ScheduleException
  bool remove(String tag, String group);
  List<ScheduledToast> list(String group);
}
```

`MockToastScheduler` (`test/support/`) は、メモリ上の予約を持つ。次を外から設定できる。

- 次の `add` / `remove` / `list` で `ScheduleException` を投げる (失敗状態の再現)
- 現在時刻より前の `at` の `add` を `ScheduleException(0x80070057)` で拒否する
- 呼び出しの順序の記録 (置換の「追加 → 対応表 → 削除」の確認に使う)

### 3.2 `--at` の解釈 (`parse_at.dart`)

```dart
DateTime parseAt(String text, {Duration Function(DateTime utc) offsetAt = _systemOffsetAt});
```

SCH-R-002, 031 / SCH-DD-04, 14。

1. 末尾が `Z` または `±hh:mm` のオフセットなら、`DateTime.parse` の結果をそのまま絶対時刻として返す (UTC に変換して保持)。
2. オフセットが無ければ、年月日時分秒を取り出して「ローカルの壁時計時刻」として扱い、次の手順で瞬間に解決する。`offsetAt(utc)` は、その瞬間のローカルのオフセットを返す関数で、テストでは夏時間の規則を差し替える。
   - 壁時計時刻を UTC の値として読んだものを `w` とする。
   - 候補のオフセットを `{offsetAt(w - 24h), offsetAt(w + 24h)}` とする。
   - 各候補 `o` について、瞬間 `i = w - o` を作り、`offsetAt(i) == o` なら有効とする。
   - 有効な候補が 0 個なら (夏時間の進みで存在しない時刻) `UsageException`。
   - 有効な候補が 2 個なら (夏時間の戻りで曖昧) 早いほうの瞬間を使う。
   - 1 個ならその瞬間を使う。
3. 解釈できない文字列は `UsageException`。
4. 過去の時刻は検査しない。OS のエラー (0x80070057) をそのまま失敗とする (SCH-DD-05)。

### 3.3 `SchedulingService` (`scheduling_service.dart`)

```dart
final class SchedulingService {
  SchedulingService({
    required NotificationEnvironment env,
    required ToastScheduler scheduler,
    required MappingTable table,
    required ClockProvider clock,
    required RandomSourceProvider random,
    required MachineIdProvider machineId,
  });

  MappingRecord add({required String batchId, required String alarmId,
                     required DateTime at, required String title, required String aumid});
  void cancel({required String batchId, required String alarmId});
  List<ScheduleEntry> list();
  ReRegisterReport reRegisterAll({required String aumid});
}
```

`aumid` は `env.check` にだけ渡す。`ToastScheduler` は、Windows 実装がコンストラクタで受け取った AUMID を保持するため、メソッドでは AUMID を受け取らない。

#### add (SCH-R-003〜011, IDX-R-001〜005)

1. `final a = env.check(aumid);` `a.ok` が偽なら `UnavailableException(a)`。ここより前に副作用を起こさない。続けて `resumePending()` を呼ぶ (下の「保留の再開」。SCH-R-036)。
2. 分類する。
   - `rec = table.get(batchId, alarmId)`、`toasts = scheduler.list(kGroup)` を得る。
   - `rec == null` → 新規。
   - `rec != null` かつ `toasts` に `rec.tag` がある → 置換。
   - `rec != null` かつ `toasts` に `rec.tag` が無い → 新規 (発火後。対応表の値を置換)。
3. Tag: `existing = {...toasts.map(tag), ...table.tags()}`。`registeredAt = clock.now()` を 1 回得て `allocateTag(...)` を呼ぶ。
   上限超過は `DuplicateTagException` (予約と対応表のどちらも変えない)。
4. 新規 (SCH-R-008): `scheduler.add(...)` → `table.put(newRecord)`。
5. 置換 (SCH-R-009, 3.5。段階は 3.5 の番号):
   1. 段階 1: `queueId = table.replace(newRecord)` (DB を 1 トランザクションで更新する)
   2. 段階 2: `scheduler.add(新しい Tag, ...)`。OS が拒否したら `table.abortReplacement(queueId)` を呼んでから例外を伝える
   3. 段階 3: `scheduler.remove(oldTag, kGroup)` (false でも成功扱い。SCH-R-030)
   4. 段階 4: `table.completeRemoval(queueId)`
6. どの段階の例外も捕まえず、そのまま呼び出し側へ伝える。巻き戻しは、段階 2 の拒否のときの `abortReplacement` だけ (SCH-R-010)。それ以外は保留をキューに残す。
7. 成功したら新しい `MappingRecord` を返す。`at` は絶対時刻、`registeredAt` は `clock.now()`。

#### 保留の再開 (SCH-R-036)

`add` と `reRegisterAll` は、`env.check` の後に `resumePending()` を呼ぶ。`cancel` も、対象の前に呼ぶ。

1. `toasts = scheduler.list(kGroup)` を得る。
2. `table.pendingRemovals()` の各行について、次を行う。
   1. 置換後の Tag が `toasts` に無ければ、`scheduler.add` で追加する (置換後の `MappingRecord` の値を使う)。
      OS が拒否したら `table.abortReplacement(queueId)` を呼び、その行の再開を終える。
   2. `scheduler.remove(oldTag, kGroup)` を呼ぶ (false でも成功扱い)。
   3. `table.completeRemoval(queueId)` を呼ぶ。
3. 例外は伝える。保留は残る。

#### cancel (SCH-R-012〜015, 030)

1. `rec = table.get(...)`。null なら `NotFoundException` (何も変えない)。
2. `resumePending()` で置換の保留を先に処理する。残すと、`table.remove` の `ON DELETE CASCADE` でキューの行が消え、旧行の削除が漏れるため。
3. `scheduler.remove(rec.tag, kGroup)` を呼ぶ。戻り値が false でも続ける (SCH-R-030)。例外なら対応表を変えずに伝える。
4. `table.remove(...)`。

#### list (SCH-R-016〜020, 032, 033)

1. `records = table.all()`、`toasts = scheduler.list(kGroup)` を得る。どちらかが失敗すれば例外を伝える。
2. Tag を鍵にして突き合わせる。
   - 両方にある → `ok`
   - 予約一覧にだけある → `orphan` (報告するだけ。何も変えない)
   - 対応表にだけある → `stale`
3. 並びは `records` の (batchId, alarmId) 順、続けて orphan を Tag 順にする。

#### reRegisterAll (SCH-R-034, 021〜024, 035)

1. `env.check(aumid)` が ok でなければ `UnavailableException` (何も登録しない)。
2. `toasts = scheduler.list(kGroup)`、`now = clock.now()`。
3. `table.all()` の各項目を次のとおり処理する。
   - Tag が `toasts` にある → `alreadyPresent`
   - Tag が無く、`at` が `now` 以前 → `skippedPast`
   - Tag が無く、`at` が `now` より後 → `scheduler.add(保存済みの Tag, kGroup, at, title)`。成功なら `registered`、
     `ScheduleException` なら `failed(reason)` に入れて続行する。
4. 対応表は変えない。Tag は再生成しない。
5. `ReRegisterReport` を返す。`exitCode` は失敗が 1 件でもあれば 2 (SCH-R-024)。

---

## 4. CLI (schedule 系のコマンド)

共通の引数の解析と `run()` は implementation-index.md §4 に従う。ここでは、予約に関するコマンドの配線と出力書式を定める。

### 4.1 コマンドの配線

| コマンド        | 処理                                                                                                         |
| --------------- | ------------------------------------------------------------------------------------------------------------ |
| add             | 引数を検査 → `parseAt(--at)` → `openStore(--db ?? 既定)` → `SchedulingService.add` → Tag を 1 行で標準出力へ |
| cancel          | 引数を検査 → `SchedulingService.cancel`                                                                      |
| list            | 引数を検査 → `SchedulingService.list` → 1 件を 1 行で出力                                                    |
| re-register-all | 引数を検査 → `SchedulingService.reRegisterAll` → 4 つの一覧を出力                                            |

`add` / `cancel` / `list` / `re-register-all` は `--db` を受け取り、対応表を使う。

### 4.2 出力書式 (`format.dart`)

SCH-R-032 と未解決事項 (list の区切り) を、次のとおり決める。

- list: 1 件 1 行、タブ区切りで `batchId  alarmId  tag  通知時刻  title  状態`。通知時刻はオフセット付きの ISO 8601 (ローカルのオフセット)。
  orphan の `batchId`、`alarmId`、`title` は `-`。stale の通知時刻は対応表の値。
- re-register-all: 先頭に次の 4 行を出す。
  - `registered: n`
  - `failed: n`
  - `skippedPast: n`
  - `alreadyPresent: n`
  - 続けて各一覧を 1 件 1 行で出す (`batchId  alarmId  tag`)。failed は理由を追加する。
- add: 成功時は新しい Tag だけを標準出力に 1 行で出す。

---

## 5. Windows Implementation (`windows/`)

OS に触れる部分。自動テストの対象にせず、手動検証で確かめる (REQ-C-002)。`ToastScheduler` (§3.1) の IF を実装するだけで、判断のロジックを持たない。

### 5.1 `win_toast_scheduler.dart` (`ToastScheduler`)

AUMID をコンストラクタで受け取り、`ToastNotifier` を 1 つ保持する。

- `add`: `ScheduledToastNotification` を作って予約に追加する。
  - 作成には `IScheduledToastNotificationFactory` を使う。表示内容は `title` を持つ ToastGeneric の XML とする。
  - `Tag` と `Group` を設定して `ToastNotifier.AddToSchedule` を呼ぶ。
  - `at` は `toWinRtTicks(at.toUtc())` で渡す。
  - `HResultException` は `ScheduleException(hresult)` に変える。
  - 過去の時刻は事前に検査せず、OS の 0x80070057 をそのまま伝える (SCH-DD-05)。
- `list`: `GetScheduledToastNotifications` を取得し、`Group == group` の要素の `Tag` と配信時刻を `ScheduledToast` に変える。
- `remove`: まず `list(group)` で該当の Tag を探す。
  見つからなければ false を返す (発火済み。SCH-R-030)。見つかれば `RemoveFromSchedule` を呼び true を返す。OS の失敗は `ScheduleException`。
- COM の `Release` は、取得したオブジェクトごとに `try` / `finally` で呼ぶ。配信猶予や `Release` の扱いの未確認事項は、手動検証で記録する
  (specifications-verification.md §7 #6, #10)。

---

## 6. Tests

テスト ID の略語と採番は implementation-index.md §5 に従う。このファイルは、担当する対象の略語と、確認する値だけを示す。

| 略語  | 対象                                                                                | 主な spec の規則                                |
| ----- | ----------------------------------------------------------------------------------- | ----------------------------------------------- |
| `MAP` | `MappingTable` (通知の行) と `SqliteStore`                                          | SCH-R-025〜027, SCH-R-029, SCH-E-20, 26         |
| `RPQ` | 置換キュー (`replace` / `pendingRemovals` / `completeRemoval` / `abortReplacement`) | SCH-R-009, SCH-R-010, SCH-R-030, SCH-R-036, 3.5 |
| `ATP` | `parseAt`                                                                           | SCH-R-002, SCH-R-031                            |
| `SVC` | `SchedulingService`                                                                 | SCH-R-003〜024, 030, 033〜035, 3.5              |

| 対象 | 確認する値                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                             |
| ---- | -------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| MAP  | put/get/remove/all (有効な行 `notify_status` が 1 または 2 だけが対象)、同じキーへの `put` で `id` が不変、新規の行の `group_name` が `kGroup`、別の通知と同じ (Group, Tag) で `StorageException` かつ変更なし、`PRAGMA foreign_keys` が ON、`user_version` が 1 以外または壊れたファイルで `StorageException` かつファイル不変、`--db` 指定、親ディレクトリの作成                                                                                                                                                                     |
| RPQ  | `replace` で新しい行が pending (2) で追加され旧行が superseded (0) になる、キューに `(new_id, old_id)` が入る、`replace` の途中で失敗するとどちらも変わらない、`pendingRemovals` が旧行の Tag と Group と置換後の値を `id` 順に返す、`completeRemoval` で旧行が消え新行が current (1) になり `old_id` が NULL になる、完了済みの行が `pendingRemovals` に出ない、`abortReplacement` で新行とキューの行が消え旧行が current に戻る、新行の削除でキューの行も消える、`tags` が旧行の Tag を含む、`all` が旧行を含まず pending の行を含む |
| ATP  | オフセット付き、オフセットなし (ローカル)、解釈できない文字列、夏時間で曖昧 (早いほう)、存在しない時刻で `UsageException` (`offsetAt` を差し替えて)                                                                                                                                                                                                                                                                                                                                                                                    |
| SVC  | add 新規/置換/発火後の新規、`Unavailable` で副作用なし、置換の呼び出し順序 (`replace` → 予約の追加 → 旧 Tag の予約の削除 → `completeRemoval`)、3.5 の各段階の失敗状態 (段階 1 の失敗、段階 2 の拒否で `abortReplacement`、段階 3 の失敗、段階 4 の失敗)、止まった保留を次の add と reRegisterAll が先に処理し (置換後の Tag が OS に既にあれば追加しない)、cancel が保留の処理 → 予約の削除 → 行の削除の順で動くことと `NotFound`、list の ok/orphan/stale、reRegisterAll の 4 分類と exitCode と対応表の不変                          |

---

## 7. Change History

<!-- SemVer: MAJOR = approach discarded, MINOR = decision criterion added,
     PATCH = clarification only. Keep frontmatter `version` equal to the newest row.
     `based-on` must cite a three-part version that exists in the specifications.
     See docs/.deckrd/rules/deckrd-rule-document-versioning.md -->

| Date       | Version | Description                                                    |
| ---------- | ------- | -------------------------------------------------------------- |
| 2026-11-22 | 1.0.0   | Split from implementation.md v1.0.0 (content moved, unchanged) |
