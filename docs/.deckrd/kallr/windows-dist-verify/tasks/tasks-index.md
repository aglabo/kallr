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

| Test Target | 略語 | ファイル                | Scenarios | Cases |
| ----------- | ---- | ----------------------- | --------: | ----: |
| T-01        | TAG  | tasks-tag.md            |        10 |    23 |
| T-02        | TAL  | tasks-tag.md            |        11 |    15 |
| T-03        | MID  | tasks-tag.md            |        13 |    21 |
| T-04        | ATP  | tasks-schedule.md       |        15 |    22 |
| T-05        | MAP  | tasks-schedule.md       |        22 |    42 |
| T-06        | RPQ  | tasks-schedule.md       |        12 |    28 |
| T-07        | SVC  | tasks-schedule.md       |        56 |   143 |
| T-08        | AVL  | tasks-environment.md    |        13 |    35 |
| T-09        | W5C  | tasks-environment.md    |        13 |    39 |
| T-10        | ARG  | tasks-cli.md            |        19 |    44 |
| T-11        | CLI  | tasks-cli.md            |        23 |    87 |
| 合計        |      |                         |           |   499 |

テスト ID (`T-WDV-<略語>-NN`) は、bdd-coder が実装するときに採番する。

## Resolved Items (2026-11-22)

決定済み。仕様・実装・タスクに反映した。

- 置換で過去の `--at` は段階 2 で OS が拒否し、`abortReplacement` で戻す (SCH-E-04 を直した。T-07-24)
- 再開で OS に拒否されても例外を投げず、abort して続行する (SCH-R-036 を直した。T-07-34-04 を追加)
- `allocateTag` から `clock` 引数を廃止した (T-02-04 を削除。T-02 の番号 04 は欠番)
- 必須オプションの検査は `parseArgs` が行う (T-10-07〜14 のまま)
- テーブルが 1 つも無い既存ファイル (0 バイトなど) は `empty` とみなして初期化する。別のテーブルがある `user_version` 0 のファイルは StorageException (T-05-16 を直し、T-05-22 を追加。implementation-schedule v1.1.2)
- 破損ファイルの StorageException は `SqliteStore.open` が投げる。`machineId()` は読み取り失敗と不正な値だけ (T-03-07-01 のまま。implementation-tag v1.0.2)
- `--recorded-permission` は大文字小文字を区別する完全一致 (T-09-13-01 のまま。implementation-environment を更新)
- 仕様の版: specifications-schedule v1.3.0。implementation-schedule v1.1.2、implementation-tag v1.0.2、implementation-environment v1.0.1。implementation-index の参照版も更新した

## Open Items (人の判断が要る)

1. DR-07 は「3 段」、仕様と実装は 4 段。pending 行が current になる時点も DR と仕様で異なる (仕様と実装に従った)
2. 仕様が定めておらずタスクを書かなかった事項: `--` で始まる値、値に `=` を含む場合、他コマンド用のオプション、日付だけの `--at`、再登録の報告の区切り、通知不可時の re-register-all の標準出力

## Files

- [tasks-tag.md](./tasks-tag.md): T-01〜T-03
- [tasks-schedule.md](./tasks-schedule.md): T-04〜T-07
- [tasks-environment.md](./tasks-environment.md): T-08〜T-09
- [tasks-cli.md](./tasks-cli.md): T-10〜T-11

## Change History

| Date       | Version | Description   |
| ---------- | ------- | ------------- |
| 2026-11-22 | 1.0.0   | Initial tasks |
