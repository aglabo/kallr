---
title: "Implementation Tasks (Index): Windows Distribution Verify"
module: kallr/windows-dist-verify
status: Active
version: 1.2.1
created: "2026-11-22 00:00:00"
source: specifications-index.md
---

> 分割したタスクの索引。T-XX は 5 ファイルを通した連番で、重複しない。1 タスク = 1 `it()`。
> 手動検証 (W2〜W4, W7) と `windows/` の FFI 実装は対象外 (implementation-index.md §5.1)。

## Task Summary

| Test Target | 略語     | ファイル             | Scenarios | Cases |
| ----------- | -------- | -------------------- | --------: | ----: |
| T-01        | TAG      | tasks-tag.md         |        10 |    28 |
| T-02        | TAL      | tasks-tag.md         |        13 |    18 |
| T-03        | MID      | tasks-tag.md         |        21 |    34 |
| T-04        | ATP      | tasks-schedule.md    |        18 |    28 |
| T-05        | MAP      | tasks-schedule.md    |        22 |    44 |
| T-06        | RPQ      | tasks-schedule.md    |        14 |    34 |
| T-07        | SVA      | tasks-service.md     |        17 |    54 |
| T-08        | AVL, MNE | tasks-environment.md |        14 |    36 |
| T-09        | W5C      | tasks-environment.md |        14 |    40 |
| T-10        | ARG      | tasks-cli.md         |        31 |    60 |
| T-11        | CLI      | tasks-cli.md         |        24 |    88 |
| T-12        | NID      | tasks-cli.md         |         6 |     6 |
| T-13        | NEV      | tasks-environment.md |        10 |    13 |
| T-14        | SVP      | tasks-service.md     |        13 |    34 |
| T-15        | SVX      | tasks-service.md     |         7 |    17 |
| T-16        | SVL      | tasks-service.md     |        10 |    15 |
| T-17        | SVG      | tasks-service.md     |         9 |    23 |
| T-18        | SVN      | tasks-service.md     |        17 |    21 |
| T-19        | SQA      | tasks-schedule.md    |        12 |    17 |
| 合計        |          |                      |           |   604 |

テスト ID (`T-WDV-<略語>-NN`) は、bdd-coder が実装するときに採番する。

## Resolved Items (2026-11-22)

決定済み。仕様・実装・タスクに反映した。

- 置換で過去の `--at` は段階 2 で OS が拒否し、`abortReplacement` で戻す (SCH-E-04 を直した。T-07-11)
- 再開で OS に拒否されても例外を投げず、abort して続行する (SCH-R-036 を直した。T-14-06-04 を追加)
- `allocateTag` から `clock` 引数を廃止した (T-02-04 を削除。T-02 の番号 04 は欠番)
- 必須オプションの検査は `parseArgs` が行う (T-10-07〜14 のまま)
- 空の batchId と alarmId は、対応表への保存でエラー (StorageException) とする。CLI では `parseArgs` が使い方の誤りにする (T-05-12-03、T-05-12-04 を追加)
- 契約として batchId と alarmId は、前後の空白を削除した値を ID として使い、空でない (T-18-01〜04、T-18-17、T-10-20〜21 を追加)。
  `add` と `cancel` は実行前に検査し、空なら `UsageException` を投げる (T-18-07〜14 を追加)。
- AUMID も同様に、削除後の値を使う (T-10-22、T-11-24 を追加。specifications-index v1.1.2)。
- ライブラリは CLI に依存せず単独で呼べるため、上層の各メソッドの入口で正規化する。
  最初に `normalizeId` を呼び、正規化後の値で、各メソッドがそれぞれ検査する (implementation-index §3.3)。
  下層 (`ToastScheduler`、`MappingTable`、`AumidRegistry` など) は、正規化済みの値を受け取り、公開しない。
  対象は `SchedulingService`、`NotificationEnvironment`、`evaluateAvailability`、`w5Check` である。
  T-18-05〜06、T-18-15〜16、T-08-14、T-09-14、T-12 (NID)、T-13 (NEV) を追加した (specifications-index v1.1.5)。
  `NotificationEnvironment` は、Mock の `AumidRegistry` を使う T-13 (NEV) で自動テストする。
  実機のレジストリでの確認は、最後に手動検証で行う (implementation-verification §4)
- テーブルが 1 つも無い既存ファイル (0 バイトなど) は `empty` とみなして初期化する。
  別のテーブルがある `user_version` 0 のファイルは StorageException とする。
  T-05-16 を直し、T-05-22 を追加した (implementation-schedule v1.1.2)
- 破損ファイルの StorageException は `SqliteStore.open` が投げる。`machineId()` は読み取り失敗と不正な値だけ (T-03-07-01 のまま。implementation-tag v1.0.2)
- `--recorded-permission` は大文字小文字を区別する完全一致 (T-09-13-01 のまま。implementation-environment を更新)
- オプションの値は文字列として扱う。`--name` の直後の 1 語は、`--` で始まっていても常に値とする。`--name=value` は最初の `=` だけで分割する。
  `--title --foo` は title が `--foo` になり、`--title --at 2026-..` は `2026-..` が余分な引数でエラーになる。
  T-10-23〜27 を追加した (specifications-index v1.2.0、implementation-index v1.1.0)
- 各コマンドは、表にある必須と任意のオプションだけを受け付ける。
  他のコマンド用のオプションも、未知として `UsageException` にする。
  T-10-28〜31 を追加した (specifications-index v1.3.0、implementation-index v1.2.0)
- DR-07 の「3 段」と、仕様・実装の 4 段の食い違いは、DR-08 (decision-records.md v3.0.0) が解消した。置換は DB を先に書く 4 段で行い、置換後の行は段 4 まで pending とする
- 仕様の版: specifications-schedule v1.5.0、specifications-index v1.3.0、specifications-verification v1.0.3。
  implementation-index v1.2.0、implementation-schedule v1.1.10。
  implementation-tag v1.0.2、implementation-environment v1.0.5。
  参照元の implementation-index、implementation-verification、db-migration も更新した

## T-07 の分割 (2026-11-24)

シナリオが 40 を超えるのは T-07 (SVC。旧 73 シナリオ / 164 ケース) だけだった。
`SchedulingService` の `add` / `cancel` / `list` / `reRegisterAll`、保留の再開、入力の検査が 1 タスクに混ざっていたため、目的別に 6 タスクへ分けた。
ケース (`it()`) の中身は変えていない。旧 `SVC` は廃止した。

- T-07 は残して「add の新規・置換」とした。残りは T-14〜T-18 とし、T-08〜T-13 は振り直していない。
- 6 タスクは `tasks-service.md` に置く。`tasks-schedule.md` は T-04〜T-06 だけになった。
- シナリオ番号は、各タスクで Normal → Error → Edge の連番に振り直した。ケース番号 (`-NN`) は変えていない。
- 旧 T-07-NN-MM は、次の表で新しい ID に読み替える。

| 新 T-XX | 略語 | 目的                                                   | 旧シナリオ → 新シナリオ                                                      |
| ------- | ---- | ------------------------------------------------------ | ---------------------------------------------------------------------------- |
| T-07    | SVA  | add: 新規・置換・発火後と、その失敗 (段階 1〜4)        | 01〜04 → 01〜04、18〜26 → 05〜13、37〜40 → 14〜17                            |
| T-14    | SVP  | 保留の再開 (add / cancel / reRegisterAll を横断)       | 05〜07 → 01〜03、09 → 04、17 → 05、34〜36 → 06〜08、41〜44 → 09〜12、48 → 13 |
| T-15    | SVX  | cancel (保留の再開を除く)                              | 08 → 01、27〜29 → 02〜04、45〜47 → 05〜07                                    |
| T-16    | SVL  | list                                                   | 10〜13 → 01〜04、30〜31 → 05〜06、49〜52 → 07〜10                            |
| T-17    | SVG  | reRegisterAll (保留の再開を除く)                       | 14〜16 → 01〜03、32〜33 → 04〜05、53〜56 → 06〜09                            |
| T-18    | SVN  | 入力の正規化と検査 (trim、空・空白で `UsageException`) | 65〜68 → 01〜04、70〜71 → 05〜06、57〜64 → 07〜14、72〜73 → 15〜16、69 → 17  |

## T-19 の追加 (2026-11-24)

`SqliteStore` を、基礎層とアプリ用の層に分ける。
基礎層は `SqliteAccess` (`guard` / `transact` / `select` / `execute`)、アプリ用の層は対応表の操作にあたる `SqliteStore` とする。
根拠は implementation-schedule v1.5.0 §2.5 と implementation-index v1.4.0 に置く。

- 分け方は継承ではなくコンポジションとする。マシン ID の保存と読み取りは `SqliteStore` に残し、`BEGIN` … `COMMIT` の形は変えない。
- 移設そのものは振る舞いを変えない。T-03 (MID)、T-05 (MAP)、T-06 (RPQ) の既存のテストを変えずに通すことを、安全網にする。
- 新しい Case は、基礎層を単体で確かめる T-19 (SQA) の 12 シナリオ、17 ケース。`tasks-schedule.md` に置く。
- T-07〜T-18 は使用済みのため、新しい Target は末尾の T-19 とした。既存の ID は振り直していない。

## Open Items (人の判断が要る)

1. 仕様が定めておらず、タスクを書かなかった事項は次のとおり。
   - 日付だけの `--at`
   - 再登録の報告の区切り
   - 通知不可時の re-register-all の標準出力

## Task ID の指定

タスク ID は、4 つのファイルを通して一意です。ID だけで指定できます。
ファイルも示す場合は、`/` で区切り、`<ファイル>/<タスク>` と書きます。

- `<ファイル>`: タスクファイルの名前。`tasks-` と `.md` は省略できる (`tasks-schedule`、`schedule`)。
- `<タスク>`: `T-07`、`T-07-01`、`T-07-01-01` のいずれか。
- 例: `service/T-07-01-01`、`tasks-cli/T-10`
- `<ファイル>` を付けた場合、`<タスク>` はそのファイルにある ID でなければならない。無ければ指定の誤りとする。

この書式を解釈するのは、タスクを実行する側 (`/bdd-coder:bdd-coder`) です。

## Files

- [tasks-tag.md](./tasks-tag.md): T-01〜T-03
- [tasks-schedule.md](./tasks-schedule.md): T-04〜T-06、T-19
- [tasks-service.md](./tasks-service.md): T-07、T-14〜T-18
- [tasks-environment.md](./tasks-environment.md): T-08〜T-09
- [tasks-cli.md](./tasks-cli.md): T-10〜T-11

## Change History

| Date       | Version | Description                                                                                             |
| ---------- | ------- | ------------------------------------------------------------------------------------------------------- |
| 2026-11-22 | 1.0.0   | Initial tasks                                                                                           |
| 2026-11-24 | 1.1.0   | Split T-07 (SVC) into T-07 and T-14 to T-18 by purpose; add tasks-service.md                            |
| 2026-11-24 | 1.2.0   | Add T-19 (SQA, SqliteAccess) to tasks-schedule.md for splitting SqliteStore                             |
| 2026-11-25 | 1.2.1   | T-08 also covers the test target MNE (Mock cases T-08-03, T-08-04; follows implementation-index v1.4.1) |
