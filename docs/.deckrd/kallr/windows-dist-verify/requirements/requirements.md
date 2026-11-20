# Requirements: windows-dist-verify

計画を `C:\Users\atsushifx\.claude\plans\prompt-stateless-bachman.md` に書きました。
プランモードのため、`requirements.md` と `decision-records.md` はまだ作っていません。
plan 承認用の ExitPlanMode ツールがこの環境では使えませんでした。このメッセージで承認をお願いします。

## 確認で見つけたこと

- `docs/.deckrd/kallr/windows-dist-verify/requirements/requirements.md` が既にあります。ただし中身は要件文書ではなく、以前の計画メッセージ(チャット文)でした。新規作成ではなく、全面上書きが必要です。
- `decision-records.md` はモジュール直下にまだありません。
- `module.md` は雛形のままです(`owns` が TODO)。今回は変更しません。
- `poc-results-windows.md` への追記は実装フェーズで行います。今回は触りません。

## 作る内容

- `requirements.md`
  - テンプレートの 11 節を、LANG=ja で埋めます。見出しを英語、図を ASCII にします。
  - Functional Requirements は EARS 形式にします。対象は次のとおりです。
    - `add` / `cancel` の追加
    - W1〜W4(a〜e)
    - W5 と W7 の記録
    - 任意測定の記録のみ
    - 結果の追記
  - 「`apps/` と `packages/` にコードを置かない」は NOT DO で書きます。
  - 入力に書かれていない事項は作らず、Open Questions に回します。
    - W1〜W4 が「通る」ことの判定基準
    - W5 の「明確である」の基準
    - 4 つの失敗状態を再現する手段
    - 置換が原子的かどうか
    - MSIX+Dart、AOT exe などの未確認事項
- `decision-records.md`(ADR 形式、4 件)
  - DR-01: 配布形式は未パッケージ + HKCU 登録
  - DR-02: 検証対象は Dart FFI
  - DR-03: W7 は再起動とログオフの両方
  - DR-04: 合否は W1〜W4 のみ

承認をもらったら、`deckrd-rule-workflow.md` など 3 本のルールと DR 作成ガイドラインを先に読んでから書きます。
その後、ID の重複と EARS の GIVEN/THEN を確認します。
version と Change History の一致、markdownlint も確認します。
`apps/` と `packages/` に変更がないことも確認します。
