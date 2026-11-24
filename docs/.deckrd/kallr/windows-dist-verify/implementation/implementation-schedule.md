---
title: "Implementation Specification: Windows Distribution Verify (Schedule)"
based-on: specifications-schedule.md v1.6.0
status: Draft
version: 1.5.0
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

- 既定のパス: `%LOCALAPPDATA%/kallr/w1-w7-verify/mappings.sqlite3` (SCH-DD-12 の「実装で決める」を、ここで決める)。
  `LOCALAPPDATA` の後ろの区切りは `/` に統一する (Windows API も `/` を受け付ける)。
  `LOCALAPPDATA` が無い場合は `StorageException`。
  この解決は、`default_db_path.dart` の次の関数が行う。
  `environment` には `Platform.environment` を渡す。
  `String defaultDbPath(Map<String, String> environment)`
  ローミングしない領域を使うのは、マシン ID と OS の予約の情報が、そのマシン固有のためです。
- `--db <path>` があればそれを使う (SCH-R-029)。
- 親ディレクトリが無ければ作る。ファイルが無ければ空の対応表として新規に作る (specifications-schedule.md §3.3 の初回の利用)。

### 2.2 スキーマ

テーブル、列、インデックス、外部キー、版 (`PRAGMA user_version`) の定義は、db-migration.md §2〜§3 を正本とする。本書は DDL を重ねて持たない。

- 列とプログラムの項目の対応は db-migration.md §2.5 に従う。`id` は内部の物理 ID で、`MappingRecord` には持たない。
- (`group_name`, `tag`) の UNIQUE が SCH-R-025 の「Tag は対応表の全体で一意」を DB 側でも守る。
- `at` は UTC の絶対時刻として保存し、読み戻して `DateTime.parse(...)` で同じ時刻を復元する (再登録で同じ時刻を使うため)。
- `title` は UTF-8 のまま保存する (SCH-E-23)。
- マシン ID は `settings` の `machine_id` キーに 1 行だけ持つ。`settings` の値の読み取りは、key で直接行う (`SELECT value FROM settings WHERE key = ?`)。書き込みと削除は、key から `id` を引いて、`id` 経由で行う。

### 2.3 接続の開き方

`SqliteStore.open(String path)` が 1 つの `Database` を開き、`MappingTable` と `MachineIdProvider` の両方を返す。

1. ファイルが存在する場合:
   - 開く。`SqliteException` は `StorageException` に変える。
   - `PRAGMA quick_check` を実行し、結果が `ok` でなければ `StorageException` (壊れている。作り直さない。SCH-R-027)。
   - `PRAGMA user_version` が 0 で、テーブルが 1 つも無い (`sqlite_master` が空) 場合は、`empty` とみなす。
     新規作成と同じ初期化を行う (スキーマの作成と `user_version = 1`。db-migration.md §3.1)。
   - 上記以外で `PRAGMA user_version` が 1 以外なら `StorageException` (別のアプリの DB を初期化しない。ファイルは変えない)。
2. ファイルが存在しない場合: ファイルを作り、`user_version = 1` とスキーマを作成する。
3. 書き込みはすべて `BEGIN` … `COMMIT` で囲み、例外時は `ROLLBACK` して `StorageException` に変える (SCH-R-026)。
   この囲みと変換は `SqliteAccess.transact` が行う (§2.5)。

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

### 2.5 層の分け方 (`sqlite_access.dart` と `sqlite_store.dart`)

`SqliteStore` が持つ処理を、SQL の実行を支える基礎層と、対応表の操作にあたるアプリ用の層に分ける。
継承ではなくコンポジションとし、`SqliteStore` が `SqliteAccess` を 1 つ持つ。

| 層       | 型 (ファイル)                         | 持つもの                                                                                                                  | 持たないもの                                                                 |
| -------- | ------------------------------------- | ------------------------------------------------------------------------------------------------------------------------- | ---------------------------------------------------------------------------- |
| 基礎層   | `SqliteAccess` (`sqlite_access.dart`) | SQL の実行 (`select` / `execute`)、`SqliteException` の `StorageException` への変換、`BEGIN` … `COMMIT` と `ROLLBACK`     | テーブル名・列名・SQL 文、`MappingRecord` などの値型、`notify_status` の意味 |
| アプリ用 | `SqliteStore` (`sqlite_store.dart`)   | `MappingTable` と `MachineIdProvider` の実装、SQL 文、`notify_status` の enum、行と値型の変換、マシン ID の読み取りと保存 | `SqliteException` の変換、`BEGIN` / `COMMIT` / `ROLLBACK` の直接の実行       |

```dart
final class SqliteAccess {
  SqliteAccess(Database db);                                   // db の所有を引き取る (close が閉じる)
  ResultSet select(String sql, [List<Object?> params = const []]);
  void execute(String sql, [List<Object?> params = const []]);
  int get updatedRows;                                         // 直前の execute が変えた行数
  int get lastInsertRowId;
  T guard<T>(String failurePrefix, T Function() action);       // SqliteException → StorageException('$failurePrefix${e.message}')
  T transact<T>(String failurePrefix, T Function() body);      // guard の中で BEGIN … COMMIT
  void close();
}
```

- `guard` は `SqliteException` だけを変える。`FormatException` など、それ以外の例外はそのまま通す。
- `transact` は `guard` の中で `runInTransaction` (`transaction.dart`) を呼ぶ。`runInTransaction` の規則は変えない。
  - `BEGIN` の失敗は、`ROLLBACK` をせず `StorageException` へ変える (すでに開いている側のトランザクションを取り消さないため)。
  - `body` が `SqliteException` を投げたら `ROLLBACK` し、`StorageException` にする。
  - `body` がそれ以外の例外を投げたら `ROLLBACK` し、同じ例外を投げ直す。
- `SqliteStore.open`、`SqliteStore.fromDatabase(Database)`、`close` の公開の形は変えない。
  `fromDatabase` は、渡された `Database` を `SqliteAccess` で包む。`SqliteStore` は `SqliteAccess` を外へ見せない。
- 対応表の SQL 文、`StorageException` のメッセージ、トランザクションの境界は、移す前と変えない。
  この分割は、振る舞いを変えない移設にあたる。
- マシン ID の保存 (`BEGIN` → `INSERT` → `COMMIT`) の形は変えない。`transact` を通して呼ぶだけにする。
  マシン ID の読み取りは `FormatException` を自分で扱うため、`select` を直接呼び、`guard` を通さない。
- `SqliteAccess` は `lib/kallr_verify.dart` から export しない (implementation-index.md §2 の下層)。

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

`MockToastScheduler` (`lib/schedule/__tests__/`) は、メモリ上の予約を持つ。次を外から設定できる。

- 次の `add` / `remove` / `list` で `ScheduleException` を投げる (失敗状態の再現)
- 現在時刻より前の `at` の `add` を `ScheduleException(0x80070057)` で拒否する
- 呼び出しの順序の記録 (置換の「追加 → 対応表 → 削除」の確認に使う)

### 3.2 `--at` の解釈 (`parse_at.dart`)

```dart
DateTime parseAt(String text, {Duration Function(DateTime utc) offsetAt = _systemOffsetAt});
```

SCH-R-002, 031 / SCH-DD-04, 14, 17。

0. 前後の空白を除いた文字列が日付のみ (`^\d{4}-\d{2}-\d{2}$`) なら、`T00:00:00` を補って手順 2 へ進む。
   - `DateTime.parse` は日付のみをプラットフォームのローカル時刻として読むため、手順 1 には流さない。
   - 存在しない日付 (`2026-02-30`) は手順 3 と同じく `UsageException`。
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

契約として、`batchId` と `alarmId` は空でない。
`add` と `cancel` は、最初に `normalizeId` で `batchId` と `alarmId` を正規化し、以降はその戻り値を使う (implementation-index.md §3.3)。
`add` と `reRegisterAll` は、`aumid` も同じく正規化する。正規化後に空なら、各メソッドが `UsageException` を投げる。
`ToastScheduler` と `MappingTable` は下層であり、正規化済みの値を受け取る。公開しない。
この検査は、`env.check`、保留の再開、`table` と `scheduler` の呼び出しより前に行う。副作用は無い。

`aumid` は `env.check` にだけ渡す。`ToastScheduler` は、Windows 実装がコンストラクタで受け取った AUMID を保持するため、メソッドでは AUMID を受け取らない。

#### add (SCH-R-003〜011, IDX-R-001〜005)

0. 識別子の検査 (契約)。`batchId`、`alarmId`、`aumid` を `normalizeId` で正規化し、以降はその戻り値を使う。どれかが空なら `UsageException`。
1. `final a = env.check(aumid);` `a.ok` が偽なら `UnavailableException(a)`。ここより前に副作用を起こさない。続けて `resumePending()` を呼ぶ (下の「保留の再開」。SCH-R-036)。
2. 分類する。
   - `rec = table.get(batchId, alarmId)`、`toasts = scheduler.list(kGroup)` を得る。
   - `rec == null` → 新規。
   - `rec != null` かつ `toasts` に `rec.tag` がある → 置換。
   - `rec != null` かつ `toasts` に `rec.tag` が無い → 新規 (発火後。対応表の値を置換)。
3. Tag: `existing = {...toasts.map(tag), ...table.tags()}`。`registeredAt = clock.now()` を 1 回得る。
   続けて `allocateTag(random:, machineId:, existingTags:, registeredAt:)` を呼ぶ。
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

1. `toasts = scheduler.list(kGroup)`、`now = clock.now()` を得る。
2. `table.pendingRemovals()` の各行について、次を行う。
   1. 置換後の `at` が `now` 以前なら、追加しない。発火済みか未登録かは区別しない (3.5)。次の手順 3 へ進む。
      `abortReplacement` で旧行へ戻すと、旧い時刻に同じ通知が再び鳴るため、戻さない。
   2. `at` が `now` より後で、置換後の Tag が `toasts` に無ければ、`scheduler.add` で追加する (置換後の `MappingRecord` の値を使う)。
      OS が拒否したら `table.abortReplacement(queueId)` を呼び、例外を投げずにその行の再開を終える (SCH-R-036)。
   3. `scheduler.remove(oldTag, kGroup)` を呼ぶ (false でも成功扱い)。
   4. `table.completeRemoval(queueId)` を呼ぶ。
3. 例外は伝える。保留は残る。

#### cancel (SCH-R-012〜015, 030)

0. 識別子の検査 (契約)。`batchId` と `alarmId` を `normalizeId` で正規化し、以降はその戻り値を使う。どちらかが空なら `UsageException`。何も呼ばない。
1. `table.get(...)` が null なら `NotFoundException` (何も変えない)。
2. `resumePending()` で置換の保留を先に処理する。残すと、`table.remove` の `ON DELETE CASCADE` でキューの行が消え、旧行の削除が漏れるため。
3. `rec = table.get(...)` を読み直す。再開で `abortReplacement` が走ると、行の Tag が変わるため。読み直しで null なら `NotFoundException` (何も変えない)。
4. `scheduler.remove(rec.tag, kGroup)` を呼ぶ。戻り値が false でも続ける (SCH-R-030)。例外なら対応表を変えずに伝える。
5. `table.remove(...)`。

#### list (SCH-R-016〜020, 032, 033)

1. `records = table.all()`、`toasts = scheduler.list(kGroup)` を得る。どちらかが失敗すれば例外を伝える。
2. Tag を鍵にして突き合わせる。
   - 両方にある → `ok`
   - 予約一覧にだけある → `orphan` (報告するだけ。何も変えない)
   - 対応表にだけある → `stale`
3. 並びは `records` の (batchId, alarmId) 順、続けて orphan を Tag 順にする。

#### reRegisterAll (SCH-R-034, 021〜024, 035)

0. 識別子の検査 (契約)。`aumid` を `normalizeId` で正規化し、以降はその戻り値を使う。空なら `UsageException`。何も呼ばない。
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

| 略語  | 対象                                                                                | 主な spec の規則                                      |
| ----- | ----------------------------------------------------------------------------------- | ----------------------------------------------------- |
| `MAP` | `MappingTable` (通知の行) と `SqliteStore`                                          | SCH-R-025〜027, SCH-R-029, SCH-E-20, 26               |
| `RPQ` | 置換キュー (`replace` / `pendingRemovals` / `completeRemoval` / `abortReplacement`) | SCH-R-009, SCH-R-010, SCH-R-030, SCH-R-036, 3.5       |
| `SQA` | `SqliteAccess` (`guard` / `transact` / `select` / `execute`)                        | SCH-R-026, 2.5                                        |
| `ATP` | `parseAt`                                                                           | SCH-R-002, SCH-R-031                                  |
| `SVA` | `SchedulingService.add` (新規・置換・発火後と、その失敗)                            | SCH-R-003〜011, 3.5                                   |
| `SVP` | `SchedulingService` の保留の再開 (add / cancel / reRegisterAll)                     | SCH-R-010, 030, 036, 3.5                              |
| `SVX` | `SchedulingService.cancel`                                                          | SCH-R-013〜015, 030                                   |
| `SVL` | `SchedulingService.list`                                                            | SCH-R-016〜020, 033                                   |
| `SVG` | `SchedulingService.reRegisterAll`                                                   | SCH-R-021〜024, 034, 035                              |
| `SVN` | `SchedulingService` の入力の正規化と検査                                            | specifications-schedule 3.3, specifications-index 3.1 |

| 対象 | 確認する値                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                             |
| ---- | -------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| MAP  | put/get/remove/all (有効な行 `notify_status` が 1 または 2 だけが対象)、同じキーへの `put` で `id` が不変、新規の行の `group_name` が `kGroup`、別の通知と同じ (Group, Tag) で `StorageException` かつ変更なし、`PRAGMA foreign_keys` が ON、`user_version` が 1 以外または壊れたファイルで `StorageException` かつファイル不変、`--db` 指定、親ディレクトリの作成                                                                                                                                                                     |
| RPQ  | `replace` で新しい行が pending (2) で追加され旧行が superseded (0) になる、キューに `(new_id, old_id)` が入る、`replace` の途中で失敗するとどちらも変わらない、`pendingRemovals` が旧行の Tag と Group と置換後の値を `id` 順に返す、`completeRemoval` で旧行が消え新行が current (1) になり `old_id` が NULL になる、完了済みの行が `pendingRemovals` に出ない、`abortReplacement` で新行とキューの行が消え旧行が current に戻る、新行の削除でキューの行も消える、`tags` が旧行の Tag を含む、`all` が旧行を含まず pending の行を含む |
| SQA  | `guard` が戻り値をそのまま返し、`SqliteException` を prefix 付きの `StorageException` に変え、それ以外の例外は変えない、`transact` が成功でコミットし、`SqliteException` で `ROLLBACK` して `StorageException` に変え、それ以外の例外で `ROLLBACK` して同じ例外を投げ直す、すでに開いているトランザクションの中の `BEGIN` の失敗で `ROLLBACK` せず外側を保つ、`select` が値をバインドして行を返し (行が無ければ空、`params` を省略できる)、`execute` の後の `updatedRows` と `lastInsertRowId`                                         |
| ATP  | オフセット付き、オフセットなし (ローカル)、解釈できない文字列、夏時間で曖昧 (早いほう)、存在しない時刻で `UsageException` (`offsetAt` を差し替えて)                                                                                                                                                                                                                                                                                                                                                                                    |
| SVA  | add 新規/置換/発火後の新規、`Unavailable` で副作用なし、置換の呼び出し順序 (`replace` → 予約の追加 → 旧 Tag の予約の削除 → `completeRemoval`)、3.5 の各段階の失敗状態 (段階 1 の失敗、段階 2 の拒否で `abortReplacement`、段階 3 の失敗、段階 4 の失敗)、Tag の重複の再生成                                                                                                                                                                                                                                                            |
| SVP  | 止まった保留を次の add と reRegisterAll が先に処理し (置換後の Tag が OS に既にあれば追加しない。置換後の `at` が `now` 以前なら追加せず、旧行へ戻さずに完了する。`at == now` も含む)、cancel が保留の処理 → 対象の読み直し → 予約の削除 → 行の削除の順で動くこと (再開で `abortReplacement` が走っても、戻った旧行の Tag の予約を削除する)、再開の各段階 (P2 / P3 / P4) の失敗                                                                                                                                                        |
| SVX  | cancel の予約の削除 → 対応表の削除の順序と `NotFound`、発火済みでも成功すること、各段階の失敗、`Unavailable` でも通知可否の確認を呼ばないこと                                                                                                                                                                                                                                                                                                                                                                                          |
| SVL  | list の ok/orphan/stale、並び、取得の失敗、孤立した予約を変更しないこと                                                                                                                                                                                                                                                                                                                                                                                                                                                                |
| SVG  | reRegisterAll の 4 分類と exitCode と対応表の不変、個別の失敗で止まらないこと、`now` との境界                                                                                                                                                                                                                                                                                                                                                                                                                                          |
| SVN  | batchId・alarmId・aumid の前後の空白の削除、空・空白だけのときに `UsageException` を投げ、他の呼び出しをしないこと                                                                                                                                                                                                                                                                                                                                                                                                                     |

---

## 7. Change History

<!-- SemVer: MAJOR = approach discarded, MINOR = decision criterion added,
     PATCH = clarification only. Keep frontmatter `version` equal to the newest row.
     `based-on` must cite a three-part version that exists in the specifications.
     See docs/.deckrd/rules/deckrd-rule-document-versioning.md -->

| Date       | Version | Description                                                                                                                    |
| ---------- | ------- | ------------------------------------------------------------------------------------------------------------------------------ |
| 2026-11-22 | 1.0.0   | Split from implementation.md v1.0.0 (content moved, unchanged)                                                                 |
| 2026-11-22 | 1.1.0   | resumePending skips adding a past replacement; cancel re-reads the target after resume                                         |
| 2026-11-22 | 1.1.1   | Follow specifications-schedule v1.3.0; allocateTag has no clock argument                                                       |
| 2026-11-22 | 1.1.2   | An existing file with no tables is initialized like a new one; other `user_version` mismatches still raise StorageException    |
| 2026-11-22 | 1.1.3   | Name the default path function `defaultDbPath` (clarification)                                                                 |
| 2026-11-22 | 1.1.4   | Follow specifications-schedule v1.3.1 (DR-08 citation)                                                                         |
| 2026-11-22 | 1.1.5   | Contract: batchId and alarmId are non-empty; add and cancel check them first and throw UsageException                          |
| 2026-11-22 | 1.1.6   | Follow specifications-schedule v1.4.0 (contract in 3.3); judge emptiness after trim                                            |
| 2026-11-22 | 1.1.7   | Follow specifications-schedule v1.5.0; the trimmed batchId and alarmId are used as the ID                                      |
| 2026-11-22 | 1.1.8   | add and reRegisterAll trim aumid at their entry (specifications-index v1.1.3)                                                  |
| 2026-11-22 | 1.1.9   | add, cancel and reRegisterAll normalize identifiers with requireId (implementation-index §3.3)                                 |
| 2026-11-22 | 1.1.10  | Use normalizeId with a check in each method; the lower layer is not public                                                     |
| 2026-11-22 | 1.2.0   | parseAt reads a date-only `--at` as 00:00:00 local time (3.2); follow specifications-schedule v1.6.0                           |
| 2026-11-22 | 1.2.1   | Mock location follows the new test layout: `lib/schedule/__tests__/` (implementation-index v1.3.0)                             |
| 2026-11-22 | 1.2.2   | Read a `settings` value directly by key; writes and deletes still go through `id` (clarification; db-migration v1.1.2)         |
| 2026-11-23 | 1.2.3   | The default DB path uses `/` as the separator after `LOCALAPPDATA` (clarification)                                             |
| 2026-11-24 | 1.2.4   | Split the test target `SVC` into SVA, SVP, SVX, SVL, SVG and SVN by purpose (6; follows tasks-index v1.1.0)                    |
| 2026-11-24 | 1.3.0   | `replace` with no current row throws StorageException and changes nothing                                                      |
| 2026-11-24 | 1.4.0   | `replace` on a pending current row cancels the earlier replacement and keeps only the latest                                   |
| 2026-11-24 | 1.5.0   | Split `SqliteStore` into the base layer `SqliteAccess` and the application layer by composition (2.5); add the test target SQA |
