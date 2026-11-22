---
title: "Implementation Specification: Windows Distribution Verify (Verification)"
based-on: specifications-verification.md v1.0.2
status: Draft
version: 1.0.0
created: "2026-11-22"
---

> implementation-index.md の分割ファイル。W1〜W7 の手動検証で使う WinRT 呼び出しの共通部、エントリポイント、手動検証、実機で測定する事項を定める。

## 1. Overview

対応する仕様は specifications-verification.md (REQ-F-003、008、009、012〜015、018)。
共通の前提、ファイル構成、型は implementation-index.md に従う。

---

## 2. `winrt.dart` (`windows/`)

`poc/windows/w0-3-dartffi/src/w03.dart` から、次を移して再利用する。`w03.dart` 自体は変更しない。

- combase.dll の関数の束縛 (起動系): `RoInitialize`、`RoGetActivationFactory`、`RoActivateInstance`
- combase.dll の関数の束縛 (文字列系): `WindowsCreateString`、`WindowsDeleteString`、`WindowsGetStringRawBuffer`
- `Guid`、`HResultException`、`check`、`hstr`、`release`、`callPtr`、`callHstr`、`getInt32`、`getInt64`、`toWinRtTicks`
- `HResultException` は、`ScheduleException(hresult)` に包んでから上位へ伝える。包む場所は implementation-schedule.md §5.1 の各メソッド。

vtable の index は `w03.dart` で使っているものを、そのまま使う。
`w03.dart` に無い呼び出しは implementation-environment.md §4.2、implementation-schedule.md §5.1 に示す。
index の値は `w03.dart` と WinRT のメタデータで確認してから書く。確認していない値を推測で書かない (REQ-NF-003)。

---

## 3. `bin/kallr_verify.dart`

```dart
Future<void> main(List<String> args) async {
  exit(await run(args,
      env: WinNotificationEnvironment(WinRegistry(), WinNotificationSetting()),
      schedulerFor: (aumid) => WinToastScheduler(aumid),
      permissionProbe: WinPermissionProbe(),
      clock: SystemClock(),
      random: SecureRandomSource(),
      openStore: SqliteStore.open));
}
```

`schedulerFor` は `--aumid` の値を受けて `ToastScheduler` を作る。AUMID の検査 (空を拒否) は `run()` 側で済んでいる。

---

## 4. 手動検証 (自動化しないもの)

実施と記録は verification spec (VER-R-001〜009) に従う。実装が用意するのは、観測に使う CLI (`list`、`show`、`re-register-all`、`w5-check`) だけです。

| 項目                 | 手順の要点                                                                            | 記録先                          |
| -------------------- | ------------------------------------------------------------------------------------- | ------------------------------- |
| W1                   | `register-reg` → `add` → `list` で予約を確認 → 通知の表示                             | `poc-results-windows.md` に追記 |
| W2                   | `add` の直後に kill → 時刻到達後に `list` と通知履歴/目視                             | 同上 (根拠を併記)               |
| W3                   | 別プロセスで `cancel` → `list`                                                        | 同上                            |
| W4 (a)(b)(c)(d)(e)   | 置換、発火後の登録、N 件の登録、同じ Tag/Group の AddToSchedule 単独、各段階での kill | 同上 ((d)(e) は記録のみ)        |
| W5                   | `w5-check` で 3 欄を照合。`ToastNotifier.Setting` の実測値も記録                      | 同上                            |
| W7                   | 再起動/ログオフ後に `list`、`re-register-all`                                         | 同上                            |
| 任意の測定           | 過去時刻、予約一覧の上限範囲、配信猶予                                                | 同上 (合否に含めない)           |
| コンソールの文字化け | 日本語の `--title` と AUMID を登録し、表示と保存が一致するか                          | 同上                            |
| 全体の合否           | VER-R-009 の 3 条件 (W1〜W4、W5 の 3 欄、W7 の記録) を確認                            | 同上                            |

追記は追記のみとし、既存の記述は書き換えない (VER-R-008)。観測していない値は「記載なし」と書き、推測で埋めない。

---

## 5. Open Points (実機で測定する事項)

仕様が実装での選択に委ねた事項のうち、実機でしか決まらないもの。決定した事項は implementation-index.md §7 に置く。

値は推測せず、次の項目を記録する。

- `ToastNotifier.Setting` の値 (登録済み、無効にしたとき、未パッケージでのマニフェストによる無効)
- Tag/Group の文字数の上限と予約件数の上限 (implementation-tag.md §2.4)
- 同じ Tag/Group での `AddToSchedule` 単独の挙動と、置換の原子性
- OS が登録を認識するまでの遅延
- SQLite のネイティブライブラリを、Windows の Dart から読み込めるか (`sqlite3` パッケージが読む DLL の入手方法。最初に確認する)
- WinRT の vtable の index のうち、`w03.dart` に無いもの (§2)

---

## 6. Change History

<!-- SemVer: MAJOR = approach discarded, MINOR = decision criterion added,
     PATCH = clarification only. Keep frontmatter `version` equal to the newest row.
     `based-on` must cite a three-part version that exists in the specifications.
     See docs/.deckrd/rules/deckrd-rule-document-versioning.md -->

| Date       | Version | Description                                                    |
| ---------- | ------- | -------------------------------------------------------------- |
| 2026-11-22 | 1.0.0   | Split from implementation.md v1.0.0 (content moved, unchanged) |
