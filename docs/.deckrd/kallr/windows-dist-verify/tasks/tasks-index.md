---
title: "Implementation Tasks (Index): Windows Distribution Verify"
module: kallr/windows-dist-verify
status: Active
version: 1.0.0
created: "2026-11-22 00:00:00"
source: specifications-index.md
---

> 分割したタスクの索引。T-XX は 4 ファイルを通した連番で、重複しない。1 タスク = 1 `it()`。
> 手動検証 (W2〜W4, W7) と `windows/` の FFI 実装は対象外 (implementation-index.md §5.1)。

## Task Summary

| Test Target | 略語 | ファイル             | Scenarios | Cases |
| ----------- | ---- | -------------------- | --------: | ----: |
| T-01        | TAG  | tasks-tag.md         |        10 |    23 |
| T-02        | TAL  | tasks-tag.md         |        11 |    15 |
| T-03        | MID  | tasks-tag.md         |        13 |    21 |
| T-04        | ATP  | tasks-schedule.md    |        15 |    22 |
| T-05        | MAP  | tasks-schedule.md    |        22 |    44 |
| T-06        | RPQ  | tasks-schedule.md    |        12 |    28 |
| T-07        | SVC  | tasks-schedule.md    |        73 |   164 |
| T-08        | AVL  | tasks-environment.md |        14 |    36 |
| T-09        | W5C  | tasks-environment.md |        14 |    40 |
| T-10        | ARG  | tasks-cli.md         |        22 |    47 |
| T-11        | CLI  | tasks-cli.md         |        24 |    88 |
| T-12        | NID  | tasks-cli.md         |         6 |     6 |
| T-13        | NEV  | tasks-environment.md |        10 |    13 |
| 合計        |      |                      |           |   547 |

テスト ID (`T-WDV-<略語>-NN`) は、bdd-coder が実装するときに採番する。

## Resolved Items (2026-11-22)

決定済み。仕様・実装・タスクに反映した。

- 置換で過去の `--at` は段階 2 で OS が拒否し、`abortReplacement` で戻す (SCH-E-04 を直した。T-07-24)
- 再開で OS に拒否されても例外を投げず、abort して続行する (SCH-R-036 を直した。T-07-34-04 を追加)
- `allocateTag` から `clock` 引数を廃止した (T-02-04 を削除。T-02 の番号 04 は欠番)
- 必須オプションの検査は `parseArgs` が行う (T-10-07〜14 のまま)
- 空の batchId と alarmId は、対応表への保存でエラー (StorageException) とする。CLI では `parseArgs` が使い方の誤りにする (T-05-12-03、T-05-12-04 を追加)
- 契約として batchId と alarmId は、前後の空白を削除した値を ID として使い、空でない (T-07-65〜69、T-10-20〜21 を追加)。
  `add` と `cancel` は実行前に検査し、空なら `UsageException` を投げる (T-07-57〜64 を追加)。
- AUMID も同様に、削除後の値を使う (T-10-22、T-11-24 を追加。specifications-index v1.1.2)。
- ライブラリは CLI に依存せず単独で呼べるため、上層の各メソッドの入口で正規化する。
  最初に `normalizeId` を呼び、正規化後の値で、各メソッドがそれぞれ検査する (implementation-index §3.3)。
  下層 (`ToastScheduler`、`MappingTable`、`AumidRegistry` など) は、正規化済みの値を受け取り、公開しない。
  対象は `SchedulingService`、`NotificationEnvironment`、`evaluateAvailability`、`w5Check` である。
  T-07-70〜73、T-08-14、T-09-14、T-12 (NID)、T-13 (NEV) を追加した (specifications-index v1.1.5)。
  `NotificationEnvironment` は、Mock の `AumidRegistry` を使う T-13 (NEV) で自動テストする。
  実機のレジストリでの確認は、最後に手動検証で行う (implementation-verification §4)
- テーブルが 1 つも無い既存ファイル (0 バイトなど) は `empty` とみなして初期化する。
  別のテーブルがある `user_version` 0 のファイルは StorageException とする。
  T-05-16 を直し、T-05-22 を追加した (implementation-schedule v1.1.2)
- 破損ファイルの StorageException は `SqliteStore.open` が投げる。`machineId()` は読み取り失敗と不正な値だけ (T-03-07-01 のまま。implementation-tag v1.0.2)
- `--recorded-permission` は大文字小文字を区別する完全一致 (T-09-13-01 のまま。implementation-environment を更新)
- DR-07 の「3 段」と、仕様・実装の 4 段の食い違いは、DR-08 (decision-records.md v3.0.0) が解消した。置換は DB を先に書く 4 段で行い、置換後の行は段 4 まで pending とする
- 仕様の版: specifications-schedule v1.5.0、specifications-index v1.1.5、specifications-verification v1.0.3。
  implementation-schedule v1.1.10、implementation-tag v1.0.2、implementation-environment v1.0.5。
  参照元の implementation-index、implementation-verification、db-migration も更新した

## Open Items (人の判断が要る)

1. 仕様が定めておらず、タスクを書かなかった事項は次のとおり。
   - `--` で始まる値
   - 値に `=` を含む場合
   - 他コマンド用のオプション
   - 日付だけの `--at`
   - 再登録の報告の区切り
   - 通知不可時の re-register-all の標準出力

## Task ID の指定

タスク ID は、4 つのファイルを通して一意です。ID だけで指定できます。
ファイルも示す場合は、`/` で区切り、`<ファイル>/<タスク>` と書きます。

- `<ファイル>`: タスクファイルの名前。`tasks-` と `.md` は省略できる (`tasks-schedule`、`schedule`)。
- `<タスク>`: `T-07`、`T-07-01`、`T-07-01-01` のいずれか。
- 例: `schedule/T-07-01-01`、`tasks-cli/T-10`
- `<ファイル>` を付けた場合、`<タスク>` はそのファイルにある ID でなければならない。無ければ指定の誤りとする。

この書式を解釈するのは、タスクを実行する側 (`/bdd-coder:bdd-coder`) です。

## Files

- [tasks-tag.md](./tasks-tag.md): T-01〜T-03
- [tasks-schedule.md](./tasks-schedule.md): T-04〜T-07
- [tasks-environment.md](./tasks-environment.md): T-08〜T-09
- [tasks-cli.md](./tasks-cli.md): T-10〜T-11

## Change History

| Date       | Version | Description   |
| ---------- | ------- | ------------- |
| 2026-11-22 | 1.0.0   | Initial tasks |
