---
title: "Implementation Tasks: cli"
module: "kallr/windows-dist-verify"
status: Active
created: "2026-11-22 00:00:00"
source: specifications-index.md
version: 1.0.0
---

<!-- textlint-disable ja-technical-writing/sentence-length -->
<!-- textlint-disable ja-technical-writing/max-comma -->
<!-- markdownlint-disable no-duplicate-heading line-length -->
<!-- cspell:words frobnicate sched -->

> This document contains implementation tasks derived from specifications.
> Each task corresponds to a single unit test case (`it()` block).
> 対象は CLI 層 (`parseArgs` と `run()`)。`SchedulingService` / `evaluateAvailability` / `w5Check` / Tag の内部は別ファイルの対象で、CLI のテストでは Fake / Mock として扱う。

---

## Task Summary

| Test Target           | Scenarios | Cases | Status  |
| --------------------- | --------: | ----: | ------- |
| T-10: ARG parseArgs   |        31 |    60 | pending |
| T-11: CLI run()       |        24 |    88 | pending |
| T-12: NID normalizeId |         6 |     6 | pending |

<!-- Status may be: pending | in progress | done -->

---

## T-10: ARG parseArgs

### [正常] Normal Cases

#### T-10-01: add を全オプション (必須と `--db`) で解析する

- [ ] **T-10-01-01**: command が `add` になる
  - Target: `parseArgs`
  - Scenario: Given `add --batch b1 --alarm a1 --at 2026-12-01T09:00:00+09:00 --title t --aumid app.x --db d.sqlite3`, When `parseArgs` を呼ぶ
  - Expected: Then `command` が `add` である

- [ ] **T-10-01-02**: options のキーが `--` を除いた名前になり値が対応する
  - Target: `parseArgs`
  - Scenario: Given `add --batch b1 --alarm a1 --at 2026-12-01T09:00:00+09:00 --title t --aumid app.x --db d.sqlite3`, When `parseArgs` を呼ぶ
  - Expected: Then `options` が `batch`、`alarm`、`at`、`title`、`aumid`、`db` の 6 キーを持ち、値がそれぞれ指定した値と一致する

#### T-10-02: add 以外の各コマンドを必須オプションだけで解析する

- [ ] **T-10-02-01**: `cancel` を解析する
  - Target: `parseArgs`
  - Scenario: Given `cancel --batch b1 --alarm a1 --aumid app.x`, When `parseArgs` を呼ぶ
  - Expected: Then `command` が `cancel` で、`options` の `batch`、`alarm`、`aumid` が指定した値である

- [ ] **T-10-02-02**: `list` を解析する
  - Target: `parseArgs`
  - Scenario: Given `list --aumid app.x`, When `parseArgs` を呼ぶ
  - Expected: Then `command` が `list` で、`options['aumid']` が `app.x` である

- [ ] **T-10-02-03**: `re-register-all` を解析する
  - Target: `parseArgs`
  - Scenario: Given `re-register-all --aumid app.x`, When `parseArgs` を呼ぶ
  - Expected: Then `command` が `re-register-all` で、`options['aumid']` が `app.x` である

- [ ] **T-10-02-04**: `show` を解析する
  - Target: `parseArgs`
  - Scenario: Given `show --aumid app.x`, When `parseArgs` を呼ぶ
  - Expected: Then `command` が `show` で、`options['aumid']` が `app.x` である

- [ ] **T-10-02-05**: `register-reg` を解析する
  - Target: `parseArgs`
  - Scenario: Given `register-reg --aumid app.x --display-name Kallr`, When `parseArgs` を呼ぶ
  - Expected: Then `command` が `register-reg` で、`options` の `aumid` と `display-name` が指定した値である

- [ ] **T-10-02-06**: `unregister-reg` を解析する
  - Target: `parseArgs`
  - Scenario: Given `unregister-reg --aumid app.x`, When `parseArgs` を呼ぶ
  - Expected: Then `command` が `unregister-reg` で、`options['aumid']` が `app.x` である

- [ ] **T-10-02-07**: `w5-check` を `--aumid` だけで解析する
  - Target: `parseArgs`
  - Scenario: Given `w5-check --aumid app.x`, When `parseArgs` を呼ぶ
  - Expected: Then `command` が `w5-check` で、`options['aumid']` が `app.x` である

#### T-10-03: `--name=value` 形式を解析する

- [ ] **T-10-03-01**: `--aumid=app.x` が `--aumid app.x` と同じ結果になる
  - Target: `parseArgs`
  - Scenario: Given `list --aumid=app.x`, When `parseArgs` を呼ぶ
  - Expected: Then `options['aumid']` が `app.x` である

#### T-10-04: 任意オプションの省略を既定値で補わない

- [ ] **T-10-04-01**: add で `--db` を省略しても `db` キーを作らない
  - Target: `parseArgs`
  - Scenario: Given `add --batch b1 --alarm a1 --at 2026-12-01T09:00:00+09:00 --title t --aumid app.x` (`--db` なし), When `parseArgs` を呼ぶ
  - Expected: Then 例外を投げず、`options` に `db` キーが含まれない

- [ ] **T-10-04-02**: w5-check で `--recorded-*` を省略しても `recorded-*` キーを作らない
  - Target: `parseArgs`
  - Scenario: Given `w5-check --aumid app.x` (`--recorded-aumid`、`--recorded-permission`、`--recorded-install-method` なし), When `parseArgs` を呼ぶ
  - Expected: Then 例外を投げず、`options` に `recorded-aumid`、`recorded-permission`、`recorded-install-method` のキーが含まれない

#### T-10-20: `--batch` の値の前後に空白がある

- [ ] **T-10-20-01**: `--batch " b1 "` は前後の空白を削除した値になる
  - Target: `parseArgs`
  - Scenario: Given `add --batch " b1 " --alarm a1 --at 2026-12-01T09:00:00+09:00 --title t --aumid app.x`, When `parseArgs` を呼ぶ
  - Expected: Then `options['batch']` が `b1` である

#### T-10-21: `--alarm` の値の前後に空白がある

- [ ] **T-10-21-01**: `--alarm " a1 "` は前後の空白を削除した値になる
  - Target: `parseArgs`
  - Scenario: Given `add --batch b1 --alarm " a1 " --at 2026-12-01T09:00:00+09:00 --title t --aumid app.x`, When `parseArgs` を呼ぶ
  - Expected: Then `options['alarm']` が `a1` である

#### T-10-22: `--aumid` の値の前後に空白がある

- [ ] **T-10-22-01**: `--aumid " app.x "` は前後の空白を削除した値になる
  - Target: `parseArgs`
  - Scenario: Given `add --batch b1 --alarm a1 --at 2026-12-01T09:00:00+09:00 --title t --aumid " app.x "`, When `parseArgs` を呼ぶ
  - Expected: Then `options['aumid']` が `app.x` である

#### T-10-23: `--` で始まる値

- [ ] **T-10-23-01**: `--name` の直後の語が `--` で始まっても、値として取る
  - Target: `parseArgs`
  - Scenario: Given `add --batch b1 --alarm a1 --at 2026-12-01T09:00:00+09:00 --title --foo --aumid app.x`, When `parseArgs` を呼ぶ
  - Expected: Then 例外を投げず、`options['title']` が `--foo` である

#### T-10-24: `=` を含む値 (`--name=value` 形式)

- [ ] **T-10-24-01**: `--title=a=b` は最初の `=` だけで分割する
  - Target: `parseArgs`
  - Scenario: Given `add --batch b1 --alarm a1 --at 2026-12-01T09:00:00+09:00 --title=a=b --aumid app.x`, When `parseArgs` を呼ぶ
  - Expected: Then `options['title']` が `a=b` である

#### T-10-25: `=` を含む値 (`--name value` 形式)

- [ ] **T-10-25-01**: `--title a=b` の値は `a=b` のまま保持する
  - Target: `parseArgs`
  - Scenario: Given `add --batch b1 --alarm a1 --at 2026-12-01T09:00:00+09:00 --title a=b --aumid app.x`, When `parseArgs` を呼ぶ
  - Expected: Then `options['title']` が `a=b` である

#### T-10-26: 識別子の値が `--` で始まる

- [ ] **T-10-26-01**: `--batch --foo` は識別子 `--foo` として扱う
  - Target: `parseArgs`
  - Scenario: Given `add --batch --foo --alarm a1 --at 2026-12-01T09:00:00+09:00 --title t --aumid app.x`, When `parseArgs` を呼ぶ
  - Expected: Then 例外を投げず、`options['batch']` が `--foo` である (欠落とは扱わない)

### [異常] Error Cases

#### T-10-05: コマンド名が不正な引数列

- [ ] **T-10-05-01**: 引数が空
  - Target: `parseArgs`
  - Scenario: Given 空の引数列 `[]`, When `parseArgs` を呼ぶ
  - Expected: Then `UsageException` を投げる

- [ ] **T-10-05-02**: 未知のコマンド
  - Target: `parseArgs`
  - Scenario: Given `frobnicate --aumid app.x`, When `parseArgs` を呼ぶ
  - Expected: Then `UsageException` を投げる

- [ ] **T-10-05-03**: 先頭がオプションでコマンドが無い
  - Target: `parseArgs`
  - Scenario: Given `--aumid app.x` (先頭がコマンド名でない), When `parseArgs` を呼ぶ
  - Expected: Then `UsageException` を投げる

#### T-10-06: オプションの形式が不正

- [ ] **T-10-06-01**: 未知のオプション
  - Target: `parseArgs`
  - Scenario: Given `list --aumid app.x --unknown x`, When `parseArgs` を呼ぶ
  - Expected: Then `UsageException` を投げる

- [ ] **T-10-06-02**: 最後のオプションの値が無い
  - Target: `parseArgs`
  - Scenario: Given `list --aumid` (値なしで終わる), When `parseArgs` を呼ぶ
  - Expected: Then `UsageException` を投げる

- [ ] **T-10-06-03**: 同じオプションの重複
  - Target: `parseArgs`
  - Scenario: Given `list --aumid a --aumid b`, When `parseArgs` を呼ぶ
  - Expected: Then `UsageException` を投げる

- [ ] **T-10-06-04**: `--` で始まらない余分な引数
  - Target: `parseArgs`
  - Scenario: Given `list --aumid app.x extra` (`--name value` の組にならない `extra`), When `parseArgs` を呼ぶ
  - Expected: Then `UsageException` を投げる

#### T-10-07: add の必須オプションの欠落

- [ ] **T-10-07-01**: `--batch` が無い
  - Target: `parseArgs`
  - Scenario: Given `add --alarm a1 --at 2026-12-01T09:00:00+09:00 --title t --aumid app.x`, When `parseArgs` を呼ぶ
  - Expected: Then `UsageException` を投げる (既定値で補わない。IDX-DD-02)

- [ ] **T-10-07-02**: `--alarm` が無い
  - Target: `parseArgs`
  - Scenario: Given `add --batch b1 --at 2026-12-01T09:00:00+09:00 --title t --aumid app.x`, When `parseArgs` を呼ぶ
  - Expected: Then `UsageException` を投げる

- [ ] **T-10-07-03**: `--at` が無い
  - Target: `parseArgs`
  - Scenario: Given `add --batch b1 --alarm a1 --title t --aumid app.x`, When `parseArgs` を呼ぶ
  - Expected: Then `UsageException` を投げる

- [ ] **T-10-07-04**: `--title` が無い
  - Target: `parseArgs`
  - Scenario: Given `add --batch b1 --alarm a1 --at 2026-12-01T09:00:00+09:00 --aumid app.x`, When `parseArgs` を呼ぶ
  - Expected: Then `UsageException` を投げる

- [ ] **T-10-07-05**: `--aumid` が無い
  - Target: `parseArgs`
  - Scenario: Given `add --batch b1 --alarm a1 --at 2026-12-01T09:00:00+09:00 --title t`, When `parseArgs` を呼ぶ
  - Expected: Then `UsageException` を投げる (IDX-DD-10)

#### T-10-08: cancel の必須オプションの欠落

- [ ] **T-10-08-01**: `--batch` が無い
  - Target: `parseArgs`
  - Scenario: Given `cancel --alarm a1 --aumid app.x`, When `parseArgs` を呼ぶ
  - Expected: Then `UsageException` を投げる

- [ ] **T-10-08-02**: `--alarm` が無い
  - Target: `parseArgs`
  - Scenario: Given `cancel --batch b1 --aumid app.x`, When `parseArgs` を呼ぶ
  - Expected: Then `UsageException` を投げる

- [ ] **T-10-08-03**: `--aumid` が無い
  - Target: `parseArgs`
  - Scenario: Given `cancel --batch b1 --alarm a1`, When `parseArgs` を呼ぶ
  - Expected: Then `UsageException` を投げる

#### T-10-09: list の必須オプションの欠落

- [ ] **T-10-09-01**: `--aumid` が無い
  - Target: `parseArgs`
  - Scenario: Given `list` (オプションなし), When `parseArgs` を呼ぶ
  - Expected: Then `UsageException` を投げる

#### T-10-10: re-register-all の必須オプションの欠落

- [ ] **T-10-10-01**: `--aumid` が無い
  - Target: `parseArgs`
  - Scenario: Given `re-register-all` (オプションなし), When `parseArgs` を呼ぶ
  - Expected: Then `UsageException` を投げる

#### T-10-11: show の必須オプションの欠落

- [ ] **T-10-11-01**: `--aumid` が無い
  - Target: `parseArgs`
  - Scenario: Given `show` (オプションなし), When `parseArgs` を呼ぶ
  - Expected: Then `UsageException` を投げる

#### T-10-12: register-reg の必須オプションの欠落

- [ ] **T-10-12-01**: `--aumid` が無い
  - Target: `parseArgs`
  - Scenario: Given `register-reg --display-name Kallr`, When `parseArgs` を呼ぶ
  - Expected: Then `UsageException` を投げる

- [ ] **T-10-12-02**: `--display-name` が無い
  - Target: `parseArgs`
  - Scenario: Given `register-reg --aumid app.x`, When `parseArgs` を呼ぶ
  - Expected: Then `UsageException` を投げる (ENV-R-017、IDX-DD-10)

#### T-10-13: unregister-reg の必須オプションの欠落

- [ ] **T-10-13-01**: `--aumid` が無い
  - Target: `parseArgs`
  - Scenario: Given `unregister-reg` (オプションなし), When `parseArgs` を呼ぶ
  - Expected: Then `UsageException` を投げる

#### T-10-14: w5-check の必須オプションの欠落

- [ ] **T-10-14-01**: `--aumid` が無い
  - Target: `parseArgs`
  - Scenario: Given `w5-check --recorded-aumid app.x` (`--aumid` なし), When `parseArgs` を呼ぶ
  - Expected: Then `UsageException` を投げる

### [エッジケース] Edge Cases

#### T-10-15: 識別子と表示名の空文字・空白だけの値

- [ ] **T-10-15-01**: add の `--batch ""` (空文字)
  - Target: `parseArgs`
  - Scenario: Given `add --batch "" --alarm a1 --at 2026-12-01T09:00:00+09:00 --title t --aumid app.x`, When `parseArgs` を呼ぶ
  - Expected: Then 欠落と同じく `UsageException` を投げる (SCH-R-001)

- [ ] **T-10-15-02**: add の `--batch "   "` (空白だけ)
  - Target: `parseArgs`
  - Scenario: Given `add --batch "   " --alarm a1 --at 2026-12-01T09:00:00+09:00 --title t --aumid app.x`, When `parseArgs` を呼ぶ
  - Expected: Then `trim()` 後に空として `UsageException` を投げる

- [ ] **T-10-15-03**: cancel の `--alarm "   "` (空白だけ)
  - Target: `parseArgs`
  - Scenario: Given `cancel --batch b1 --alarm "   " --aumid app.x`, When `parseArgs` を呼ぶ
  - Expected: Then `UsageException` を投げる (SCH-R-012)

- [ ] **T-10-15-04**: list の `--aumid "   "` (空白だけ)
  - Target: `parseArgs`
  - Scenario: Given `list --aumid "   "`, When `parseArgs` を呼ぶ
  - Expected: Then `UsageException` を投げる (SCH-R-028、ENV-E-08)

- [ ] **T-10-15-05**: register-reg の `--display-name "   "` (空白だけ)
  - Target: `parseArgs`
  - Scenario: Given `register-reg --aumid app.x --display-name "   "`, When `parseArgs` を呼ぶ
  - Expected: Then `UsageException` を投げる (ENV-E-21、IDX-DD-10)

- [ ] **T-10-15-06**: `=` 形式の空の値 `--batch=`
  - Target: `parseArgs`
  - Scenario: Given `add --batch= --alarm a1 --at 2026-12-01T09:00:00+09:00 --title t --aumid app.x`, When `parseArgs` を呼ぶ
  - Expected: Then 空の値として `UsageException` を投げる

#### T-10-16: 非 ASCII の文字列を変換しない

- [ ] **T-10-16-01**: `--title` の日本語と絵文字がそのまま保持される
  - Target: `parseArgs`
  - Scenario: Given `add ... --title "会議🔔"` (他は有効な必須オプション), When `parseArgs` を呼ぶ
  - Expected: Then `options['title']` が `会議🔔` と一致する (REQ-NF-004)

#### T-10-17: 空白を含む値の保持

- [ ] **T-10-17-01**: `--title "a b"` の内部の空白が保持される
  - Target: `parseArgs`
  - Scenario: Given `add ... --title "a b"` (他は有効な必須オプション), When `parseArgs` を呼ぶ
  - Expected: Then `options['title']` が `a b` である

#### T-10-18: 任意オプションの空白だけの値は解析で拒否しない

- [ ] **T-10-18-01**: w5-check の `--recorded-aumid "   "`
  - Target: `parseArgs`
  - Scenario: Given `w5-check --aumid app.x --recorded-aumid "   "`, When `parseArgs` を呼ぶ
  - Expected: Then 例外を投げず、判定 (未明確) は `w5Check` に委ねる (ENV-R-019)

#### T-10-19: オプションの並び順

- [ ] **T-10-19-01**: 並びを逆にしても同じ結果
  - Target: `parseArgs`
  - Scenario: Given `cancel --aumid app.x --alarm a1 --batch b1` (T-10-02-01 と逆順), When `parseArgs` を呼ぶ
  - Expected: Then `options` が T-10-02-01 と同じ内容になる

#### T-10-27: 値として取った語の後に余分な引数が残る

- [ ] **T-10-27-01**: `--title` の直後の `--at` は値になり、続く語が余分な引数でエラーになる
  - Target: `parseArgs`
  - Scenario: Given `add --batch b1 --alarm a1 --title --at 2026-12-01T09:00:00+09:00 --aumid app.x` (`--title` の値を省略し、`--at` を続ける), When `parseArgs` を呼ぶ
  - Expected: Then `--at` を title の値として取り、続く `2026-12-01T09:00:00+09:00` が `--` で始まらない余分な引数のため `UsageException` を投げる (T-10-06-04)

#### T-10-28: `--db` を受け付けないコマンドに `--db` を渡す

- [ ] **T-10-28-01**: show に `--db` を渡す
  - Target: `parseArgs`
  - Scenario: Given `show --aumid app.x --db x.db`, When `parseArgs` を呼ぶ
  - Expected: Then `UsageException` を投げる (T-10-06-01)

- [ ] **T-10-28-02**: register-reg に `--db` を渡す
  - Target: `parseArgs`
  - Scenario: Given `register-reg --aumid app.x --display-name N --db x.db`, When `parseArgs` を呼ぶ
  - Expected: Then `UsageException` を投げる

- [ ] **T-10-28-03**: unregister-reg に `--db` を渡す
  - Target: `parseArgs`
  - Scenario: Given `unregister-reg --aumid app.x --db x.db`, When `parseArgs` を呼ぶ
  - Expected: Then `UsageException` を投げる

#### T-10-29: 他のコマンド用の必須オプションを渡す

- [ ] **T-10-29-01**: list に `--batch` を渡す
  - Target: `parseArgs`
  - Scenario: Given `list --aumid app.x --batch b1`, When `parseArgs` を呼ぶ
  - Expected: Then `UsageException` を投げる

- [ ] **T-10-29-02**: cancel に `--title` を渡す
  - Target: `parseArgs`
  - Scenario: Given `cancel --batch b1 --alarm a1 --aumid app.x --title t`, When `parseArgs` を呼ぶ
  - Expected: Then `UsageException` を投げる

- [ ] **T-10-29-03**: show に `--alarm` を渡す
  - Target: `parseArgs`
  - Scenario: Given `show --aumid app.x --alarm a1`, When `parseArgs` を呼ぶ
  - Expected: Then `UsageException` を投げる

#### T-10-30: `--recorded-*` を w5-check 以外に渡す

- [ ] **T-10-30-01**: list に `--recorded-aumid` を渡す
  - Target: `parseArgs`
  - Scenario: Given `list --aumid app.x --recorded-aumid app.x`, When `parseArgs` を呼ぶ
  - Expected: Then `UsageException` を投げる

#### T-10-31: `--display-name` を register-reg 以外に渡す

- [ ] **T-10-31-01**: show に `--display-name` を渡す
  - Target: `parseArgs`
  - Scenario: Given `show --aumid app.x --display-name N`, When `parseArgs` を呼ぶ
  - Expected: Then `UsageException` を投げる

---

## T-11: CLI run()

> 共通の前提: `run()` へ Fake / Mock の `env`、`schedulerFor`、`permissionProbe`、`clock`、`random`、`openStore` と、`StringBuffer` の `out` / `err` を渡す。`SchedulingService` は `run()` の内部で Fake に対して動く。

### [正常] Normal Cases

#### T-11-01: 各コマンドの正常終了

- [ ] **T-11-01-01**: add が成功して 0 を返す
  - Target: `run`
  - Scenario: Given 通知できる Mock の env と有効な add の引数, When `run` を呼ぶ
  - Expected: Then 終了コードが 0 である

- [ ] **T-11-01-02**: cancel が成功して 0 を返す
  - Target: `run`
  - Scenario: Given 対応表に (b1, a1) がある状態と `cancel --batch b1 --alarm a1 --aumid app.x`, When `run` を呼ぶ
  - Expected: Then 終了コードが 0 である

- [ ] **T-11-01-03**: list が成功して 0 を返す
  - Target: `run`
  - Scenario: Given 対応表に 1 件ある状態と `list --aumid app.x`, When `run` を呼ぶ
  - Expected: Then 終了コードが 0 である

- [ ] **T-11-01-04**: re-register-all が失敗なしで 0 を返す
  - Target: `run`
  - Scenario: Given 通知できる env と、登録対象 1 件が成功する Fake scheduler, When `re-register-all --aumid app.x` で `run` を呼ぶ
  - Expected: Then 終了コードが 0 である

- [ ] **T-11-01-05**: show が ok 真で 0 を返す
  - Target: `run`
  - Scenario: Given `env.check` が `ok == true` を返す Mock, When `show --aumid app.x` で `run` を呼ぶ
  - Expected: Then 終了コードが 0 である

- [ ] **T-11-01-06**: register-reg が成功して 0 を返す
  - Target: `run`
  - Scenario: Given `env.register` が成功する Mock, When `register-reg --aumid app.x --display-name Kallr` で `run` を呼ぶ
  - Expected: Then 終了コードが 0 である

- [ ] **T-11-01-07**: unregister-reg が成功して 0 を返す
  - Target: `run`
  - Scenario: Given 登録が存在する Mock の env, When `unregister-reg --aumid app.x` で `run` を呼ぶ
  - Expected: Then 終了コードが 0 である

- [ ] **T-11-01-08**: w5-check が全欄一致で 0 を返す
  - Target: `run`
  - Scenario: Given AUMID が登録済みで権限が `user` の Mock と `w5-check --aumid app.x --recorded-aumid app.x --recorded-permission user --recorded-install-method unpackaged`, When `run` を呼ぶ
  - Expected: Then 終了コードが 0 である (ENV-R-019)

#### T-11-02: add の標準出力

- [ ] **T-11-02-01**: 成功時に新しい Tag だけを 1 行で出す
  - Target: `run`
  - Scenario: Given 成功する add と Tag `T1` を返す Fake, When `run` を呼ぶ
  - Expected: Then `out` の内容が Tag と改行の 1 行だけである

#### T-11-03: openStore に渡す保存先

- [ ] **T-11-03-01**: add が `--db` の値で openStore を呼ぶ
  - Target: `run`
  - Scenario: Given 有効な add の引数に `--db d1.sqlite3`, When `run` を呼ぶ
  - Expected: Then `openStore` が `d1.sqlite3` を受け取って 1 回呼ばれる (IDX-DD-11)

- [ ] **T-11-03-02**: add で `--db` を省略すると既定の保存先で openStore を呼ぶ
  - Target: `run`
  - Scenario: Given `--db` を含まない有効な add の引数, When `run` を呼ぶ
  - Expected: Then `openStore` が既定の保存先 (`defaultDbPath` の値) を受け取って呼ばれる

- [ ] **T-11-03-03**: cancel が `--db` の値で openStore を呼ぶ
  - Target: `run`
  - Scenario: Given `cancel --batch b1 --alarm a1 --aumid app.x --db d2.sqlite3`, When `run` を呼ぶ
  - Expected: Then `openStore` が `d2.sqlite3` を受け取って呼ばれる

- [ ] **T-11-03-04**: list が `--db` の値で openStore を呼ぶ
  - Target: `run`
  - Scenario: Given `list --aumid app.x --db d3.sqlite3`, When `run` を呼ぶ
  - Expected: Then `openStore` が `d3.sqlite3` を受け取って呼ばれる

- [ ] **T-11-03-05**: re-register-all が `--db` の値で openStore を呼ぶ
  - Target: `run`
  - Scenario: Given `re-register-all --aumid app.x --db d4.sqlite3`, When `run` を呼ぶ
  - Expected: Then `openStore` が `d4.sqlite3` を受け取って呼ばれる

#### T-11-04: add の依存の受け渡し

- [ ] **T-11-04-01**: add が `env.check` を 1 回呼ぶ
  - Target: `run`
  - Scenario: Given 通知できる Mock の env と有効な add の引数, When `run` を呼ぶ
  - Expected: Then `env.check` が 1 回呼ばれる (IDX-R-001)

- [ ] **T-11-04-02**: `--aumid` の値で schedulerFor を呼ぶ
  - Target: `run`
  - Scenario: Given `--aumid app.x` を含む有効な add の引数, When `run` を呼ぶ
  - Expected: Then `schedulerFor` が `app.x` を受け取って呼ばれる

#### T-11-05: list の出力書式

- [ ] **T-11-05-01**: ok の 1 件が、タブ区切りの 1 行 6 項目になる
  - Target: `run`
  - Scenario: Given 状態が ok の 1 件 (batchId=b1、alarmId=a1、Tag=T1、title=t) を返す list, When `run` を呼ぶ
  - Expected: Then `out` が 1 行で、タブ区切りの `batchId`、`alarmId`、`tag`、通知時刻、`title`、状態 `ok` をこの順に持つ (SCH-R-032)

- [ ] **T-11-05-02**: 通知時刻がローカルのオフセット付き ISO 8601 になる
  - Target: `run`
  - Scenario: Given 通知時刻が 2026-12-01T09:00 (ローカル) の ok の 1 件, When `list` で `run` を呼ぶ
  - Expected: Then 4 番目の項目がオフセット付きの ISO 8601 (例 `2026-12-01T09:00:00.000+09:00`) である

- [ ] **T-11-05-03**: orphan の batchId・alarmId・title が `-` になる
  - Target: `run`
  - Scenario: Given 状態が orphan の 1 件 (対応表に行が無い), When `list` で `run` を呼ぶ
  - Expected: Then 1 番目、2 番目、5 番目の項目 (`batchId`、`alarmId`、`title`) が `-` で、Tag と状態 `orphan` は出力される

- [ ] **T-11-05-04**: stale の通知時刻が対応表の値になる
  - Target: `run`
  - Scenario: Given 状態が stale の 1 件 (予約一覧に無く、対応表の `at` が 2026-12-01T09:00), When `list` で `run` を呼ぶ
  - Expected: Then 4 番目の項目が対応表の `at` の値で、状態が `stale` である

#### T-11-06: re-register-all の出力書式

- [ ] **T-11-06-01**: 先頭の 4 行が件数を持つ
  - Target: `run`
  - Scenario: Given registered 1、failed 0、skippedPast 1、alreadyPresent 0 の報告, When `re-register-all` で `run` を呼ぶ
  - Expected: Then `out` の先頭 4 行が順に `registered: 1`、`failed: 0`、`skippedPast: 1`、`alreadyPresent: 0` である

- [ ] **T-11-06-02**: 4 行の後に各一覧を 1 件 1 行で出す
  - Target: `run`
  - Scenario: Given registered に (b1, a1, T1) の 1 件がある報告, When `re-register-all` で `run` を呼ぶ
  - Expected: Then 先頭 4 行の後に、`batchId`、`alarmId`、`tag` を含む 1 行が出る

- [ ] **T-11-06-03**: failed の行に理由が追加される
  - Target: `run`
  - Scenario: Given failed に理由 `0x80070057` の 1 件がある報告, When `re-register-all` で `run` を呼ぶ
  - Expected: Then 該当の行が `batchId`、`alarmId`、`tag` に続けて理由 `0x80070057` を含む

#### T-11-07: show の出力書式

- [ ] **T-11-07-01**: 5 行を決まった順で出す
  - Target: `run`
  - Scenario: Given 登録済み、DisplayName あり、setting が `enabled`、ok 真の Availability, When `show --aumid app.x` で `run` を呼ぶ
  - Expected: Then `out` が `registered: true`、`displayNameSet: true`、`setting: enabled`、`ok: true`、`reason: ...` の順の 5 行である

- [ ] **T-11-07-02**: setting の行に列挙値の名前が出る
  - Target: `run`
  - Scenario: Given setting が `disabledForUser` の Availability, When `show` で `run` を呼ぶ
  - Expected: Then `setting: disabledForUser` の行が出る

#### T-11-08: w5-check の出力書式

- [ ] **T-11-08-01**: AUMID 欄が `field: status (recorded=..., observed=...)` の形で出る
  - Target: `run`
  - Scenario: Given 記録した AUMID が登録済みで一致する Mock, When `w5-check` で `run` を呼ぶ
  - Expected: Then AUMID 欄の行が `aumid: <status> (recorded=app.x, observed=...)` の書式で出る

- [ ] **T-11-08-02**: install-method 欄が `not checked` と表示される
  - Target: `run`
  - Scenario: Given `--recorded-install-method unpackaged` を含む w5-check の引数, When `run` を呼ぶ
  - Expected: Then install-method 欄の行に `not checked` が出て、記録した値 `unpackaged` も表示される

#### T-11-09: 環境系コマンドの配線

- [ ] **T-11-09-01**: show が `env.check` を 1 回呼ぶ
  - Target: `run`
  - Scenario: Given `show --aumid app.x`, When `run` を呼ぶ
  - Expected: Then `env.check` が `app.x` を受け取って 1 回呼ばれる

- [ ] **T-11-09-02**: register-reg が `env.register` に AUMID と表示名を渡す
  - Target: `run`
  - Scenario: Given `register-reg --aumid app.x --display-name Kallr`, When `run` を呼ぶ
  - Expected: Then `env.register` が `app.x` と `Kallr` を受け取って 1 回呼ばれる

- [ ] **T-11-09-03**: unregister-reg が `env.unregister` に AUMID を渡す
  - Target: `run`
  - Scenario: Given `unregister-reg --aumid app.x`, When `run` を呼ぶ
  - Expected: Then `env.unregister` が `app.x` を受け取って 1 回呼ばれる

#### T-11-24: `--aumid` の値の前後に空白がある

- [ ] **T-11-24-01**: 前後の空白を削除した AUMID で通知可否の確認をする
  - Target: `run`
  - Scenario: Given `env.check` が `ok == true` を返す Mock, When `show --aumid " app.x "` で `run` を呼ぶ
  - Expected: Then `env.check` が `app.x` で呼ばれる

### [異常] Error Cases

#### T-11-10: 例外から終了コードへの変換

- [ ] **T-11-10-01**: `UsageException` が 1 になる
  - Target: `run`
  - Scenario: Given `add` から `--batch` を除いた引数, When `run` を呼ぶ
  - Expected: Then 終了コードが 1 である

- [ ] **T-11-10-02**: `ArgumentError` が 1 になる
  - Target: `run`
  - Scenario: Given add の処理中に `ArgumentError` を投げる Fake (random), When 有効な add の引数で `run` を呼ぶ
  - Expected: Then 終了コードが 1 である

- [ ] **T-11-10-03**: add の `UnavailableException` が 3 になる
  - Target: `run`
  - Scenario: Given `env.check` が `ok == false` を返す Mock, When 有効な add の引数で `run` を呼ぶ
  - Expected: Then 終了コードが 3 である

- [ ] **T-11-10-04**: re-register-all の `UnavailableException` が 3 になる
  - Target: `run`
  - Scenario: Given `env.check` が `ok == false` を返す Mock, When `re-register-all --aumid app.x` で `run` を呼ぶ
  - Expected: Then 終了コードが 3 である (IDX-DD-13)

- [ ] **T-11-10-05**: `NotFoundException` が 2 になる
  - Target: `run`
  - Scenario: Given `env.unregister` が `NotFoundException` を投げる Mock, When `unregister-reg --aumid app.x` で `run` を呼ぶ
  - Expected: Then 終了コードが 2 である (IDX-DD-06)

- [ ] **T-11-10-06**: `DuplicateTagException` が 2 になる
  - Target: `run`
  - Scenario: Given Tag の重複が上限を超えて `DuplicateTagException` が出る Fake, When 有効な add の引数で `run` を呼ぶ
  - Expected: Then 終了コードが 2 である

- [ ] **T-11-10-07**: `ScheduleException` が 2 になる
  - Target: `run`
  - Scenario: Given `scheduler.add` が `ScheduleException(hresult: 0x80070057)` を投げる Fake, When 有効な add の引数で `run` を呼ぶ
  - Expected: Then 終了コードが 2 である

- [ ] **T-11-10-08**: `RegistryException` が 2 になる
  - Target: `run`
  - Scenario: Given `env.register` が `RegistryException(win32Code: 5)` を投げる Mock, When `register-reg --aumid app.x --display-name Kallr` で `run` を呼ぶ
  - Expected: Then 終了コードが 2 である

- [ ] **T-11-10-09**: `StorageException` が 2 になる
  - Target: `run`
  - Scenario: Given `openStore` が `StorageException` を投げる Fake, When `list --aumid app.x` で `run` を呼ぶ
  - Expected: Then 終了コードが 2 である

- [ ] **T-11-10-10**: 上記以外の例外が 2 になり、例外が `run` の外へ出ない
  - Target: `run`
  - Scenario: Given `openStore` が `StateError` を投げる Fake, When `list --aumid app.x` で `run` を呼ぶ
  - Expected: Then `run` が例外を投げず、終了コード 2 で完了する (IDX-DD-05)

#### T-11-11: 標準エラーの内容

- [ ] **T-11-11-01**: `UsageException` の message が出る
  - Target: `run`
  - Scenario: Given `add` から `--batch` を除いた引数, When `run` を呼ぶ
  - Expected: Then `err` に `UsageException` の `message` が含まれる

- [ ] **T-11-11-02**: `ArgumentError` の message が出る
  - Target: `run`
  - Scenario: Given add の処理中に message `bad tag` の `ArgumentError` を投げる Fake, When 有効な add の引数で `run` を呼ぶ
  - Expected: Then `err` に `bad tag` が含まれる

- [ ] **T-11-11-03**: `UnavailableException` の `availability.reason` が出る
  - Target: `run`
  - Scenario: Given `env.check` が reason `AUMID is not registered` の `ok == false` を返す Mock, When 有効な add の引数で `run` を呼ぶ
  - Expected: Then `err` に `AUMID is not registered` が含まれる

- [ ] **T-11-11-04**: `NotFoundException` の message が出る
  - Target: `run`
  - Scenario: Given `env.unregister` が message `not registered` の `NotFoundException` を投げる Mock, When `unregister-reg --aumid app.x` で `run` を呼ぶ
  - Expected: Then `err` に `not registered` が含まれる

- [ ] **T-11-11-05**: `DuplicateTagException` の message が出る
  - Target: `run`
  - Scenario: Given Tag の重複で `DuplicateTagException(attempts: 4)` が出る Fake, When 有効な add の引数で `run` を呼ぶ
  - Expected: Then `err` に例外の message (`toString()` が返す理由) が含まれる

- [ ] **T-11-11-06**: `ScheduleException` の message に HRESULT が含まれる
  - Target: `run`
  - Scenario: Given `scheduler.add` が `ScheduleException(hresult: 0x80070057)` を投げる Fake, When 有効な add の引数で `run` を呼ぶ
  - Expected: Then `err` に message と HRESULT `0x80070057` が含まれる

- [ ] **T-11-11-07**: `RegistryException` の message に Win32 コードが含まれる
  - Target: `run`
  - Scenario: Given `env.register` が `RegistryException(win32Code: 5)` を投げる Mock, When `register-reg` で `run` を呼ぶ
  - Expected: Then `err` に message と Win32 コード `5` が含まれる

- [ ] **T-11-11-08**: `StorageException` の message が出る
  - Target: `run`
  - Scenario: Given `openStore` が message `db is corrupted` の `StorageException` を投げる Fake, When `list --aumid app.x` で `run` を呼ぶ
  - Expected: Then `err` に `db is corrupted` が含まれる

- [ ] **T-11-11-09**: 上記以外の例外は `toString()` が出る
  - Target: `run`
  - Scenario: Given `openStore` が `StateError('boom')` を投げる Fake, When `list --aumid app.x` で `run` を呼ぶ
  - Expected: Then `err` に `StateError('boom').toString()` の文字列が含まれる

#### T-11-12: 通知できない状態での副作用

- [ ] **T-11-12-01**: add が予約を追加しない
  - Target: `run`
  - Scenario: Given `env.check` が `ok == false` を返す Mock, When 有効な add の引数で `run` を呼ぶ
  - Expected: Then `scheduler.add` が 1 回も呼ばれない (IDX-R-001)

- [ ] **T-11-12-02**: add が HKCU へ書き込まない
  - Target: `run`
  - Scenario: Given `env.check` が `ok == false` を返す Mock, When 有効な add の引数で `run` を呼ぶ
  - Expected: Then `env.register` が 1 回も呼ばれない

- [ ] **T-11-12-03**: add が標準出力に何も出さない
  - Target: `run`
  - Scenario: Given `env.check` が `ok == false` を返す Mock, When 有効な add の引数で `run` を呼ぶ
  - Expected: Then `out` が空である (Tag を出さない)

- [ ] **T-11-12-04**: re-register-all が何も登録しない
  - Target: `run`
  - Scenario: Given `env.check` が `ok == false` を返す Mock と、対応表に未来の通知時刻の 1 件, When `re-register-all --aumid app.x` で `run` を呼ぶ
  - Expected: Then `scheduler.add` が 1 回も呼ばれない (IDX-R-007)

#### T-11-13: 使い方の誤りでの副作用なし

- [ ] **T-11-13-01**: add の `--batch` 欠落で openStore を呼ばない
  - Target: `run`
  - Scenario: Given `add` から `--batch` を除いた引数, When `run` を呼ぶ
  - Expected: Then `openStore` が呼ばれない

- [ ] **T-11-13-02**: add の `--batch` 欠落で予約を追加しない
  - Target: `run`
  - Scenario: Given `add` から `--batch` を除いた引数, When `run` を呼ぶ
  - Expected: Then `scheduler.add` が呼ばれない (SCH-R-001 副作用なし)

- [ ] **T-11-13-03**: add の `--at` が解釈できないとき 1 を返す
  - Target: `run`
  - Scenario: Given `--at not-a-date` を含む add の引数, When `run` を呼ぶ
  - Expected: Then 終了コードが 1 である (SCH-R-001 (c))

- [ ] **T-11-13-04**: add の `--at` が解釈できないとき予約を追加しない
  - Target: `run`
  - Scenario: Given `--at not-a-date` を含む add の引数, When `run` を呼ぶ
  - Expected: Then `scheduler.add` が呼ばれない

- [ ] **T-11-13-05**: show の `--aumid` 欠落で `env.check` を呼ばない
  - Target: `run`
  - Scenario: Given `show` (オプションなし), When `run` を呼ぶ
  - Expected: Then 終了コードが 1 で、`env.check` が呼ばれない (ENV-E-22)

- [ ] **T-11-13-06**: register-reg の `--display-name` 欠落で HKCU へ書き込まない
  - Target: `run`
  - Scenario: Given `register-reg --aumid app.x` (`--display-name` なし), When `run` を呼ぶ
  - Expected: Then 終了コードが 1 で、`env.register` が呼ばれない (ENV-E-20)

- [ ] **T-11-13-07**: register-reg の `--display-name` が空白だけのとき HKCU へ書き込まない
  - Target: `run`
  - Scenario: Given `register-reg --aumid app.x --display-name "   "`, When `run` を呼ぶ
  - Expected: Then 終了コードが 1 で、`env.register` が呼ばれない (ENV-E-21)

#### T-11-14: show で ok が偽

- [ ] **T-11-14-01**: 終了コードが 3 になる
  - Target: `run`
  - Scenario: Given `env.check` が `ok == false` を返す Mock, When `show --aumid app.x` で `run` を呼ぶ
  - Expected: Then 終了コードが 3 である (IDX-DD-12、ENV-E-23)

- [ ] **T-11-14-02**: 終了コードを返す前に確認の結果を 5 行で表示する
  - Target: `run`
  - Scenario: Given `env.check` が `ok == false` (reason `AUMID is not registered`) を返す Mock, When `show --aumid app.x` で `run` を呼ぶ
  - Expected: Then `out` に `ok: false` を含む 5 行が出ている

- [ ] **T-11-14-03**: 値による分岐であり、標準エラーに何も出さない
  - Target: `run`
  - Scenario: Given `env.check` が `ok == false` を返す Mock, When `show --aumid app.x` で `run` を呼ぶ
  - Expected: Then `err` が空である (`UnavailableException` を使わない。ENV-R-018)

- [ ] **T-11-14-04**: 確認の読み取りが失敗すると 2 になる
  - Target: `run`
  - Scenario: Given `env.check` が `RegistryException` を投げる Mock, When `show --aumid app.x` で `run` を呼ぶ
  - Expected: Then 終了コードが 2 である (ENV-E-24。「通知できない」の 3 と区別する)

#### T-11-15: w5-check の記録の誤り

- [ ] **T-11-15-01**: `--recorded-aumid` が無いとき 2 になる
  - Target: `run`
  - Scenario: Given `w5-check --aumid app.x --recorded-permission user --recorded-install-method unpackaged` (`--recorded-aumid` なし), When `run` を呼ぶ
  - Expected: Then 終了コードが 2 である (ENV-E-27)

- [ ] **T-11-15-02**: 報告を表示した上で 2 を返す
  - Target: `run`
  - Scenario: Given `w5-check --aumid app.x --recorded-permission user --recorded-install-method unpackaged` (`--recorded-aumid` なし), When `run` を呼ぶ
  - Expected: Then `out` に欄ごとの結果が出力されている (終了コードを返す前に表示する)

- [ ] **T-11-15-03**: 記録した AUMID が HKCU に無いと終了コード 2 を返す
  - Target: `run`
  - Scenario: Given 記録した AUMID `app.y` が HKCU に未登録の Mock, When `w5-check --aumid app.x --recorded-aumid app.y --recorded-permission user --recorded-install-method unpackaged` で `run` を呼ぶ
  - Expected: Then 終了コードが 2 である (ENV-E-17)

- [ ] **T-11-15-04**: 記録した権限が観測した権限と異なるとき 2 になる
  - Target: `run`
  - Scenario: Given `permissionProbe` が `user` を返す Mock, When `--recorded-permission administrator` で `w5-check` の `run` を呼ぶ
  - Expected: Then 終了コードが 2 である (ENV-E-18)

- [ ] **T-11-15-05**: install-method が `記載なし` のとき 2 になる
  - Target: `run`
  - Scenario: Given `--recorded-install-method 記載なし` を含む w5-check の引数, When `run` を呼ぶ
  - Expected: Then 終了コードが 2 である (ENV-E-29)

- [ ] **T-11-15-06**: `--recorded-permission` の値が不正なとき 1 になる
  - Target: `run`
  - Scenario: Given `--recorded-permission root` を含む w5-check の引数, When `run` を呼ぶ
  - Expected: Then 終了コードが 1 である (権限の値は `user` と `administrator` だけ。ENV-DD-12)

#### T-11-16: re-register-all の個別の失敗

- [ ] **T-11-16-01**: 失敗が 1 件あると 2 になる
  - Target: `run`
  - Scenario: Given 登録対象 1 件の `scheduler.add` が `ScheduleException` を投げる Fake, When `re-register-all --aumid app.x` で `run` を呼ぶ
  - Expected: Then 終了コードが 2 である (IDX-DD-13)

- [ ] **T-11-16-02**: 失敗があっても報告を表示する
  - Target: `run`
  - Scenario: Given 登録対象 1 件の `scheduler.add` が `ScheduleException` を投げる Fake, When `re-register-all --aumid app.x` で `run` を呼ぶ
  - Expected: Then `out` の先頭 4 行に `failed: 1` が含まれる

### [エッジケース] Edge Cases

#### T-11-17: env.check を呼ばないコマンド

- [ ] **T-11-17-01**: cancel は `env.check` を呼ばない
  - Target: `run`
  - Scenario: Given `cancel --batch b1 --alarm a1 --aumid app.x`, When `run` を呼ぶ
  - Expected: Then `env.check` が 1 回も呼ばれない

- [ ] **T-11-17-02**: list は `env.check` を呼ばない
  - Target: `run`
  - Scenario: Given `list --aumid app.x`, When `run` を呼ぶ
  - Expected: Then `env.check` が 1 回も呼ばれない

- [ ] **T-11-17-03**: register-reg は `env.check` を呼ばない (事前確認しない)
  - Target: `run`
  - Scenario: Given `register-reg --aumid app.x --display-name Kallr`, When `run` を呼ぶ
  - Expected: Then `env.check` が 1 回も呼ばれない

- [ ] **T-11-17-04**: unregister-reg は `env.check` を呼ばない
  - Target: `run`
  - Scenario: Given `unregister-reg --aumid app.x`, When `run` を呼ぶ
  - Expected: Then `env.check` が 1 回も呼ばれない

#### T-11-18: openStore を呼ばないコマンド

- [ ] **T-11-18-01**: show は `openStore` を呼ばない
  - Target: `run`
  - Scenario: Given `show --aumid app.x`, When `run` を呼ぶ
  - Expected: Then `openStore` が 1 回も呼ばれない (SQLite を作らない)

- [ ] **T-11-18-02**: register-reg は `openStore` を呼ばない
  - Target: `run`
  - Scenario: Given `register-reg --aumid app.x --display-name Kallr`, When `run` を呼ぶ
  - Expected: Then `openStore` が 1 回も呼ばれない

- [ ] **T-11-18-03**: unregister-reg は `openStore` を呼ばない
  - Target: `run`
  - Scenario: Given `unregister-reg --aumid app.x`, When `run` を呼ぶ
  - Expected: Then `openStore` が 1 回も呼ばれない

- [ ] **T-11-18-04**: w5-check は `openStore` を呼ばない
  - Target: `run`
  - Scenario: Given `w5-check --aumid app.x`, When `run` を呼ぶ
  - Expected: Then `openStore` が 1 回も呼ばれない

#### T-11-19: 通知できない状態でも実行できるコマンド

- [ ] **T-11-19-01**: cancel は `env.check` が `ok == false` でも 0 を返す
  - Target: `run`
  - Scenario: Given `env.check` が `ok == false` を返す Mock と、対応表に (b1, a1) がある状態, When `cancel --batch b1 --alarm a1 --aumid app.x` で `run` を呼ぶ
  - Expected: Then 終了コードが 0 である (cancel は 3 を返さない)

- [ ] **T-11-19-02**: list は `env.check` が `ok == false` でも 0 を返す
  - Target: `run`
  - Scenario: Given `env.check` が `ok == false` を返す Mock, When `list --aumid app.x` で `run` を呼ぶ
  - Expected: Then 終了コードが 0 である (list は 3 を返さない)

#### T-11-20: show の通知設定が未評価

- [ ] **T-11-20-01**: `setting` が null のとき `(not evaluated)` を出し、作った値を出さない
  - Target: `run`
  - Scenario: Given `setting == null` の Availability (確認が途中で打ち切られた) を返す Mock, When `show --aumid app.x` で `run` を呼ぶ
  - Expected: Then `setting: (not evaluated)` の行が出て、`NotificationSetting` の名前を含まない (ENV-DD-10)

#### T-11-21: 空の結果

- [ ] **T-11-21-01**: list の結果が 0 件のとき標準出力が空
  - Target: `run`
  - Scenario: Given 対応表と予約一覧がどちらも空, When `list --aumid app.x` で `run` を呼ぶ
  - Expected: Then `out` が空で、終了コードが 0 である

- [ ] **T-11-21-02**: re-register-all の 4 つの一覧がすべて空のとき 4 行だけが出る
  - Target: `run`
  - Scenario: Given 対応表が空, When `re-register-all --aumid app.x` で `run` を呼ぶ
  - Expected: Then `out` が `registered: 0`、`failed: 0`、`skippedPast: 0`、`alreadyPresent: 0` の 4 行だけで、終了コードが 0 である

#### T-11-22: 過去のため登録しなかった記録だけがある re-register-all

- [ ] **T-11-22-01**: failed が空なら skippedPast があっても 0 になる
  - Target: `run`
  - Scenario: Given 対応表に通知時刻が過去の 1 件だけがある状態, When `re-register-all --aumid app.x` で `run` を呼ぶ
  - Expected: Then 終了コードが 0 である (IDX-DD-07)

#### T-11-23: 成功時の標準エラー

- [ ] **T-11-23-01**: add の成功時に標準エラーへ何も出さない
  - Target: `run`
  - Scenario: Given 成功する add, When `run` を呼ぶ
  - Expected: Then `err` が空である

## T-12: NID normalizeId

### [正常] Normal Cases

#### T-12-01: 前後に半角空白がある値

- [ ] **T-12-01-01**: 前後の空白を削除した値を返す
  - Target: `normalizeId`
  - Scenario: Given `" b1 "`, When `normalizeId` を呼ぶ
  - Expected: Then `b1` を返す

#### T-12-02: 空白のない値

- [ ] **T-12-02-01**: 値を変えずに返す
  - Target: `normalizeId`
  - Scenario: Given `"b1"`, When `normalizeId` を呼ぶ
  - Expected: Then `b1` を返す

### [異常] Error Cases

#### T-12-03: 空白だけの値

- [ ] **T-12-03-01**: 例外にせず空文字を返す (検査は呼び出し側のメソッドが行う)
  - Target: `normalizeId`
  - Scenario: Given `"   "`, When `normalizeId` を呼ぶ
  - Expected: Then 空文字を返し、例外を投げない

### [エッジケース] Edge Cases

#### T-12-04: タブと改行で囲まれた値

- [ ] **T-12-04-01**: タブと改行も削除する
  - Target: `normalizeId`
  - Scenario: Given `"\t b1 \n"`, When `normalizeId` を呼ぶ
  - Expected: Then `b1` を返す

#### T-12-05: 内側に空白がある値

- [ ] **T-12-05-01**: 内側の空白は変えない
  - Target: `normalizeId`
  - Scenario: Given `" b 1 "`, When `normalizeId` を呼ぶ
  - Expected: Then `b 1` を返す

#### T-12-06: 空文字

- [ ] **T-12-06-01**: 空文字のまま返す
  - Target: `normalizeId`
  - Scenario: Given `""`, When `normalizeId` を呼ぶ
  - Expected: Then 空文字を返し、例外を投げない

---

## Coverage Check

| Source item                                                                                                   | Task ID(s)                                                                                                                                   |
| ------------------------------------------------------------------------------------------------------------- | -------------------------------------------------------------------------------------------------------------------------------------------- |
| impl §4.2 先頭の引数がコマンド名 (無い / 未知)                                                                | T-10-05-01, T-10-05-02, T-10-05-03                                                                                                           |
| impl §4.2 `--name value` の組と ParsedArgs (options のキー)                                                   | T-10-01-01, T-10-01-02, T-10-02-01〜T-10-02-07, T-10-19-01                                                                                   |
| impl §4.2 `--name=value`                                                                                      | T-10-03-01, T-10-15-06                                                                                                                       |
| impl §4.2 未知のオプション / 値の欠落 / 重複 / 余分な引数                                                     | T-10-06-01, T-10-06-02, T-10-06-03, T-10-06-04                                                                                               |
| impl §4.1 add の必須 5 オプション (IDX-DD-02, SCH-R-001, SCH-E-01)                                            | T-10-07-01〜T-10-07-05                                                                                                                       |
| impl §4.1 cancel の必須 3 オプション (SCH-R-012)                                                              | T-10-08-01〜T-10-08-03                                                                                                                       |
| impl §4.1 list / re-register-all の `--aumid` (SCH-R-028, SCH-E-25)                                           | T-10-09-01, T-10-10-01                                                                                                                       |
| impl §4.1 show / unregister-reg / w5-check の `--aumid` (ENV-R-017, ENV-E-22)                                 | T-10-11-01, T-10-13-01, T-10-14-01, T-11-13-05                                                                                               |
| impl §4.1 register-reg の `--aumid` / `--display-name` (IDX-DD-10, ENV-E-20)                                  | T-10-12-01, T-10-12-02, T-11-13-06                                                                                                           |
| impl §4.1 任意オプション (`--db`, `--recorded-*`) の省略                                                      | T-10-04-01, T-10-04-02                                                                                                                       |
| impl §4.2 空・空白だけの値 (batch/alarm/aumid/display-name; SCH-R-001, SCH-E-02, ENV-E-08, ENV-E-21)          | T-10-15-01〜T-10-15-06, T-11-13-07                                                                                                           |
| impl §4.2 前後の空白を削除した値を使う (batch/alarm/aumid。仕様 3.3, specifications-index 3.1)                | T-10-20-01, T-10-21-01, T-10-22-01, T-11-24-01                                                                                               |
| 識別子の正規化 (specifications-index 3.1。implementation-index §3.3)                                          | T-12-01-01〜T-12-06-01                                                                                                                       |
| impl §4.2 UTF-8 のまま扱う (REQ-NF-004)                                                                       | T-10-16-01, T-10-17-01                                                                                                                       |
| impl §4.2 `--` で始まる値・`=` を含む値 (直後の語は常に値、`=` は最初の 1 つで分割。specifications-index 3.1) | T-10-23-01, T-10-24-01, T-10-25-01, T-10-26-01, T-10-27-01                                                                                   |
| impl §4.2 コマンドの表に無いオプションは、他のコマンド用でも未知 (specifications-index 3.1)                   | T-10-28-01〜T-10-28-03, T-10-29-01〜T-10-29-03, T-10-30-01, T-10-31-01                                                                       |
| ENV-R-019 `--recorded-*` の空白は ARG で拒否しない                                                            | T-10-18-01                                                                                                                                   |
| impl §4.3 正常終了 → 終了コード 0                                                                             | T-11-01-01〜T-11-01-08                                                                                                                       |
| impl §4.3 `UsageException` / `ArgumentError` → 1                                                              | T-11-10-01, T-11-10-02, T-11-13-03, T-11-15-06                                                                                               |
| impl §4.3 `UnavailableException` → 3 (add / re-register-all)                                                  | T-11-10-03, T-11-10-04                                                                                                                       |
| impl §4.3 `NotFoundException` / `DuplicateTagException` / `ScheduleException` → 2                             | T-11-10-05, T-11-10-06, T-11-10-07                                                                                                           |
| impl §4.3 `RegistryException` / `StorageException` → 2                                                        | T-11-10-08, T-11-10-09                                                                                                                       |
| impl §4.3 上記以外の例外 → 2 (`run` は例外を投げない、IDX-DD-05)                                              | T-11-10-10                                                                                                                                   |
| impl §4.3 標準エラーの内容 (message / reason / HRESULT / Win32 / toString)                                    | T-11-11-01〜T-11-11-09                                                                                                                       |
| IDX-DD-04 終了コード 0/1/2/3 の 4 種                                                                          | T-11-01-*, T-11-10-*, T-11-14-01                                                                                                             |
| IDX-DD-05 変換点は `run()` 1 か所                                                                             | T-11-10-01〜T-11-10-10                                                                                                                       |
| IDX-DD-10 / ENV-R-017 `--aumid`・`--display-name` 欠落は 1                                                    | T-10-07-05, T-10-12-02, T-11-13-05, T-11-13-06                                                                                               |
| IDX-DD-11 `--db` で保存先を差し替え / 既定の保存先                                                            | T-11-03-01〜T-11-03-05, T-10-04-01                                                                                                           |
| IDX-DD-12 / ENV-R-018 show: ok 偽で 3、値による分岐                                                           | T-11-01-05, T-11-14-01, T-11-14-02, T-11-14-03, T-11-14-04                                                                                   |
| IDX-DD-12 / ENV-R-019 w5-check: 0 / 2、W5 の合否は変えない                                                    | T-11-01-08, T-11-15-01〜T-11-15-05                                                                                                           |
| IDX-DD-13 / IDX-R-007 re-register-all の最初の確認と 3、失敗で 2                                              | T-11-10-04, T-11-12-04, T-11-16-01, T-11-16-02, T-11-22-01                                                                                   |
| IDX-R-001 add の最初の確認と副作用なし (§5 通知不可の add)                                                    | T-11-04-01, T-11-10-03, T-11-12-01, T-11-12-02, T-11-12-03                                                                                   |
| SCH-R-001 (c) `--at` が解釈できない → 1、副作用なし                                                           | T-11-13-03, T-11-13-04                                                                                                                       |
| SCH-R-001 / SCH-R-028 使い方の誤りは副作用なし                                                                | T-11-13-01, T-11-13-02                                                                                                                       |
| impl §4.3 cancel / list は `env.check` を呼ばない                                                             | T-11-17-01, T-11-17-02, T-11-19-01, T-11-19-02                                                                                               |
| impl env §3.1 register-reg は事前確認しない、unregister-reg の配線                                            | T-11-17-03, T-11-17-04, T-11-09-02, T-11-09-03                                                                                               |
| impl env §3.1 show / register-reg / unregister-reg / w5-check は `openStore` を呼ばない                       | T-11-18-01〜T-11-18-04                                                                                                                       |
| impl sched §4.1 add の配線 (schedulerFor, env.check, Tag 出力)                                                | T-11-02-01, T-11-04-01, T-11-04-02, T-11-23-01                                                                                               |
| impl sched §4.2 list の出力書式 (SCH-R-032, SCH-E-31)                                                         | T-11-05-01〜T-11-05-04, T-11-21-01                                                                                                           |
| impl sched §4.2 re-register-all の出力書式                                                                    | T-11-06-01〜T-11-06-03, T-11-21-02                                                                                                           |
| impl env §3.2 show の出力書式 / `(not evaluated)` (ENV-DD-10)                                                 | T-11-07-01, T-11-07-02, T-11-20-01                                                                                                           |
| impl env §3.2 w5-check の出力書式 / install-method は `not checked`                                           | T-11-08-01, T-11-08-02                                                                                                                       |
| impl env §3.1 show の配線 (`env.check`)                                                                       | T-11-09-01                                                                                                                                   |
| ENV-E-23 / ENV-E-24 show の ok 偽 / 読み取り失敗                                                              | T-11-14-01, T-11-14-04                                                                                                                       |
| ENV-E-17 / ENV-E-18 / ENV-E-27 / ENV-E-29 w5-check の記録の誤り                                               | T-11-15-03, T-11-15-04, T-11-15-01, T-11-15-05                                                                                               |
| IDX-DD-06 cancel の対象なし (NotFound) は 2                                                                   | T-11-10-05                                                                                                                                   |
| IDX-DD-08 Tag 重複の上限超過は 2                                                                              | T-11-10-06                                                                                                                                   |
| DR-05 / DR-06 / DR-07                                                                                         | 置換の順序 (DR-05, DR-07, DR-08) は SchedulingService、IF の仮想化 (DR-06) は AVL の対象。CLI は Fake を注入する構成で T-11-* 全体が利用する |
| [UNCOVERED]                                                                                                   | (なし)                                                                                                                                       |

---

## Category Balance

| Test Target           | Normal | Error | Edge | Result |
| --------------------- | -----: | ----: | ---: | ------ |
| T-10: ARG parseArgs   |     19 |    22 |   19 | [OK]   |
| T-11: CLI run()       |     31 |    42 |   15 | [OK]   |
| T-12: NID normalizeId |      2 |     1 |    3 | [OK]   |

<!--
Task ID Format: T-<TestTarget>-<Scenario>-<Case>
- TestTarget: 2-digit (10 = ARG, 11 = CLI, 12 = NID)
- Scenario: 2-digit, continues across Normal -> Error -> Edge within a target
- Case: 2-digit

Example: T-11-10-03 = TestTarget 11, Scenario 10, Case 03
-->
