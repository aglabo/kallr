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
| T-02        | TAL  | tasks-tag.md            |        12 |    16 |
| T-03        | MID  | tasks-tag.md            |        13 |    21 |
| T-04        | ATP  | tasks-schedule.md       |        15 |    22 |
| T-05        | MAP  | tasks-schedule.md       |        21 |    39 |
| T-06        | RPQ  | tasks-schedule.md       |        12 |    28 |
| T-07        | SVC  | tasks-schedule.md       |        56 |   142 |
| T-08        | AVL  | tasks-environment.md    |        13 |    35 |
| T-09        | W5C  | tasks-environment.md    |        13 |    39 |
| T-10        | ARG  | tasks-cli.md            |        19 |    44 |
| T-11        | CLI  | tasks-cli.md            |        23 |    87 |
| 合計        |      |                         |           |   496 |

テスト ID (`T-WDV-<略語>-NN`) は、bdd-coder が実装するときに採番する。

## Open Items (人の判断が要る)

仕様または実装が定めていない事項。タスクは仮定で書いたものがあり、決まったら該当タスクを直す。

1. SCH-E-04 と §3.5: 置換で過去の `--at` が段階 1 で失敗するのか、段階 2 の OS 拒否 + `abortReplacement` か (T-07-24 は段階 2 で記述)
2. SCH-R-036: 再開で拒否されたとき add / reRegisterAll が例外を投げるか (T-07-34 は DB と scheduler の状態だけを検査)
3. DR-07 は「3 段」、仕様と実装は 4 段。pending 行が current になる時点も DR と仕様で異なる (仕様と実装に従った)
4. 空ファイルの SQLite (`user_version` 0) を db-migration §3.1 は `empty` 扱い、実装は StorageException (T-05-16 は後者)
5. `allocateTag` の `clock` 引数は未使用か (T-02-04-01 は「無視される」と仮定)
6. 破損 DB の StorageException を投げるのは `SqliteStore.open` か `machineId()` か (T-03-07-01 は `open`)
7. 必須オプションの検査は `parseArgs` か `run()` か (T-10-07〜14 は `parseArgs` と仮定)
8. w5-check の `--recorded-permission` は大文字小文字を区別するか (T-09-13-01 は区別)
9. 仕様が定めておらずタスクを書かなかった事項: `--` で始まる値、値に `=` を含む場合、他コマンド用のオプション、日付だけの `--at`、再登録の報告の区切り、通知不可時の re-register-all の標準出力
10. 文書の不整合: implementation-index.md §1.2 が specifications-schedule v1.1.0 を引くが実体は v1.2.0

## Files

- [tasks-tag.md](./tasks-tag.md): T-01〜T-03
- [tasks-schedule.md](./tasks-schedule.md): T-04〜T-07
- [tasks-environment.md](./tasks-environment.md): T-08〜T-09
- [tasks-cli.md](./tasks-cli.md): T-10〜T-11

## Change History

| Date       | Version | Description   |
| ---------- | ------- | ------------- |
| 2026-11-22 | 1.0.0   | Initial tasks |
