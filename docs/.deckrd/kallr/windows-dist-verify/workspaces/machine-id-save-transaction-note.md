# machineId の保存をトランザクションなしにできるか (T-05 で決める)

状態: 保留 (2026-11-22 に、利用者が「今は見送り、T-05 のトランザクション設計で決める」と決めた)

## 現状

`SqliteStore._saveNewMachineId` は、`BEGIN`、`INSERT`、`COMMIT` で保存し、失敗したら `ROLLBACK` する。
`BEGIN` の失敗だけは、開始していないトランザクションを巻き戻さないよう、`ROLLBACK` しない (T-03-17-01)。

## 検討した案

読んでから、行がないときだけ、1 文で書く。

```sql
SELECT value FROM settings WHERE key = ?;                 -- 値があれば、ここで終わる (読み取りだけ)
INSERT INTO settings (key, value) VALUES (?, ?)
  ON CONFLICT (key) DO UPDATE SET key = key RETURNING value;   -- 行がないときだけ。1 文なので原子的
```

- 利点: `BEGIN`/`COMMIT`/`ROLLBACK` の処理が要らなくなる。SELECT と INSERT の間に別のプロセスが書いても、同じ値に収束する。
- 動作確認: 同梱の SQLite は 3.54.1 で、`RETURNING` (3.35 以上) と `ON CONFLICT` (3.24 以上) を満たす。2 回呼ぶと、元の値を返し、行は 1 件のままだった。

## 見送った理由

- 1 文だけの案 (毎回 `INSERT … ON CONFLICT … RETURNING`) は採らない。有効な値があっても、毎回、書き込みロックを取り、読み取り専用の DB で失敗する。
- 「1 文の書き込みは、トランザクションで包まなくてよい」とするには、上流の規則を変える必要がある。
  - `specifications-index.md` の IDX-DD-01 (「書き込みはトランザクションで行い、途中の状態を残さない」)
  - `specifications-schedule.md` の SCH-R-026
  - `implementation-schedule.md` §2.3 の 3 (「書き込みはすべて `BEGIN` … `COMMIT` で囲む」)
- 次の Target (`MappingTable` の置換など) は、複数の文をまとめて書くので、トランザクションの処理が、いずれ必要になる。`machineId` だけ外しても、全体の簡素化は小さい。

## T-05 で決めること

1. トランザクションの共通の補助関数を作るか。作るなら、`machineId` も、それを使えば、規則を変えずに同じ簡素化になる。
2. 補助関数を作らず、1 文の書き込みを、規則の例外として認めるか。認めるなら、上の 3 つの規則を更新する。

## 例外にした場合に影響する Case とテスト

- Case: T-03-14-01、T-03-15-01、T-03-17-01 (欠番にする)。T-03-08-01、T-03-08-02 (1 文の失敗に書き直す)。
- テスト: T-WDV-MID-17、18、33、34、35 (削除または書き直し)。偽の DB のスイッチ `insertThrowsStateError`、`rollbackFails`、`beginFails`。

## T-05 で一緒に決めること: `sqlite_store.dart` の分割

状態: 保留 (2026-11-22 に、利用者が「メモに足す」と決めた。今は分けない)

`SqliteStore` は、将来、次の 2 つを持つ。変わる理由が別なので、T-05 の最初に、ファイルを分けることを検討する。

- 接続と初期化: ファイルの有無の判定、親ディレクトリの作成、`PRAGMA quick_check`、`PRAGMA user_version` の判定、3 つのテーブル (`notifications`、`replacement_queue`、`settings`) と索引の作成、将来の版の移行 (implementation-schedule.md §2.3、db-migration.md §3)。
- 通常のデータ操作: `MappingTable` の CRUD、置換キュー、`MachineIdProvider` (`machineId`)。

### 分け方の案

```text
lib/store/
  schema.dart            DDL、版 (user_version)、quick_check、初期化・移行
                         Database openDatabase(String path)   // 開く、検査、初期化まで。SqliteException は StorageException に変える
  sqlite_store.dart      CRUD (MappingTable、MachineIdProvider)
                         SqliteStore.open(path) は openDatabase(path) を呼び、SqliteStore.fromDatabase に渡すだけ
  mapping_table.dart     (IF。設計どおり)
  default_db_path.dart   (設計どおり)
```

- `SqliteStore.fromDatabase(db)` は、スキーマを作らずに `Database` を包む入口で、すでに CRUD 側の入口になっている。
- テストも分かれる。T-WDV-MID-05 (スキーマ作成の失敗) と T-WDV-MID-16 (SQLite でないファイル) は初期化側。`machineId` の読み書きは CRUD 側。初期化側は `schema.unit.spec.dart` に分け、`module.md` の略語表に新しい行 (例: `SCM`) を足す。
- 設計書の更新が要る: implementation-index.md §2 のモジュール構成にファイルを足す (版を上げる)。

### 今は分けない理由

- 初期化の部分が、`settings` 用の DDL 1 つ (10 行ほど) だけで、分ける利点がまだない。
- 分け方は T-05 の要件 (`quick_check`、`user_version`、3 テーブルの DDL、トランザクションの補助関数をどこに置くか) で決まる。早く分けると、置き直しになりやすい。
- 設計書の更新が要るので、T-05 の設計の更新と一緒にしたほうが、1 回で済む。

### ファイル名について

`sqlite_store.dart` / `SqliteStore` の名前は変えない (2026-11-22 に、利用者が決めた。SQLite 専用の実装なので、`db_store` にしない)。
