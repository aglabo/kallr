---
title: "Universal Dictionary: kallr/windows-dist-verify"
module: "kallr/windows-dist-verify"
status: Draft
version: 2.0.0
created: "2026-11-20"
---

> **本書の位置付け**
> 本書は、モジュール kallr/windows-dist-verify の用語と概念の唯一の正本とする。
> requirements、decision records、specifications、implementation、tasks が、本書を共有する。
> 判断は DR、要求と振る舞いは requirements と specifications が定める。本書は判断の代替物ではない。

## 1. 本書の規則

- 本書は、概念の定義と概念どうしの関係を定め、安定した UD-ID を割り当てる。
- 行動の義務 (MUST・SHOULD など) や具体値は、本書で定めない。正本は「関連規則」に挙げる文書とする。
- ほかの文書は、用語の意味を定義し直さず、UD-ID で参照する。
- UD-ID は `UD-<章コード>-NNN` の形式とする。章コードは章ごとに割り当て、連番は章コードごとに 001 から数える。
  書式は docs/.deckrd/rules/deckrd-rule-document-model.md に従う。
- UD-ID は振り直さず、廃止した番号も再利用しない。用語が別の章へ移っても、ID は変えない。
- 各用語は、定義の直後に次の項目を示す。該当しない項目は省略する。

| 項目       | 意味                                                 |
| ---------- | ---------------------------------------------------- |
| 抽象度     | 概念・状態と判断・時間と範囲・具体のいずれか         |
| 確定状況   | 確定・未確定のいずれか                               |
| 構成要素   | この概念を構成する概念                               |
| 対立・区別 | 意味が異なるのに取り違えやすい概念                   |
| 関連       | 上の関係にあたらない、関係する概念                   |
| 定義根拠   | 定義の意味の根拠となる記述                           |
| 関連規則   | この概念を使って判断・義務・具体値を定める DR や要件 |

### 章コード

| 章            | 章コード |
| ------------- | -------- |
| 2. 予約       | RSV      |
| 3. 時刻と識別 | TID      |
| 4. 置換       | RPL      |
| 5. 通知可否   | NTF      |
| 6. テスト     | TST      |
| 7. 記録の値   | REC      |

## 2. 予約

### UD-RSV-001 予約

AddToSchedule で OS に登録した、指定した通知時刻に表示される通知の予定。

- 抽象度: 概念
- 確定状況: 確定
- 構成要素: UD-RSV-003、UD-RSV-004、UD-TID-002
- 対立・区別: UD-TID-004 (Kallr が持つ表)
- 関連: UD-RSV-002
- 定義根拠: poc-plan.md の PoC-W 合格条件 (W1)

### UD-RSV-002 予約一覧

GetScheduledToastNotifications が返す、OS に残っている予約の一覧。予約の有無の証拠にできるのは、この一覧だけとする。

- 抽象度: 概念
- 確定状況: 確定
- 対立・区別: UD-TID-004 (Kallr 側の表の内容は、予約の有無の証拠にしない)
- 関連: UD-RSV-001
- 定義根拠: poc-plan.md の PoC-W 合格条件 (W1)
- 関連規則: requirements.md REQ-F-001

### UD-RSV-003 Tag

予約を識別する文字列。Group と組になって、予約を一意に特定する。

- 抽象度: 具体
- 確定状況: 確定
- 関連: UD-RSV-004、UD-TID-001、UD-TID-002、UD-TID-003、UD-TID-004
- 定義根拠: Microsoft Learn の ToastNotification.Tag
- 関連規則: DR-04、requirements.md REQ-F-007、REQ-F-016

### UD-RSV-004 Group

予約を束ねる OS の属性。Tag と組になって、予約を一意に特定する。

- 抽象度: 具体
- 確定状況: 確定
- 関連: UD-RSV-003
- 定義根拠: Microsoft Learn の ToastNotification.Group
- 関連規則: DR-04、requirements.md REQ-F-001

## 3. 時刻と識別

### UD-TID-001 登録時刻

予約を作成した時刻。ローカル日時で表す。

- 抽象度: 時間・範囲
- 確定状況: 確定
- 対立・区別: UD-TID-002 (通知を表示する時刻)
- 関連: UD-RSV-003
- 定義根拠: DR-04
- 関連規則: DR-04、requirements.md REQ-F-016

### UD-TID-002 通知時刻

予約の通知が表示される時刻。add の `--at` で指定する。

- 抽象度: 時間・範囲
- 確定状況: 確定
- 対立・区別: UD-TID-001 (予約を作成した時刻)
- 関連: UD-RSV-001
- 定義根拠: poc-plan.md の PoC-W 合格条件 (W1)
- 関連規則: requirements.md REQ-F-001

### UD-TID-003 マシン ID

Kallr が初回起動時に乱数で作成して保存する、マシンごとの識別子。Tag の一部になる。

- 抽象度: 具体
- 確定状況: 確定
- 関連: UD-RSV-003
- 定義根拠: DR-04
- 関連規則: DR-04、requirements.md REQ-F-019

### UD-TID-004 対応表

Kallr が持つ、(batchId, alarmId) から Tag を引く表。

- 抽象度: 概念
- 確定状況: 確定
- 対立・区別: UD-RSV-002 (OS に残る予約の一覧)
- 関連: UD-RSV-003
- 定義根拠: DR-04
- 関連規則: DR-04、DR-05、requirements.md REQ-F-020

## 4. 置換

### UD-RPL-001 置換

同じ (batchId, alarmId) の未発火の予約を、別の内容の予約に取り替えること。発火後の登録は、置換ではなく新規の登録とする。

- 抽象度: 概念
- 確定状況: 確定
- 構成要素: UD-RPL-002、UD-RPL-003
- 対立・区別: 発火後の同じ ID の登録 (poc-plan.md の W4(b))
- 関連: UD-RPL-004
- 定義根拠: poc-plan.md の PoC-W 合格条件 (W4)
- 関連規則: DR-05、requirements.md REQ-F-005、REQ-F-006

### UD-RPL-002 置換前の予約

置換の対象になる、既存の未発火の予約。置換が完了すると、OS に残らない。

- 抽象度: 概念
- 確定状況: 確定
- 対立・区別: UD-RPL-003
- 関連: UD-RPL-001
- 定義根拠: DR-05
- 関連規則: DR-05、requirements.md REQ-F-005

### UD-RPL-003 置換後の予約

置換によって追加する、新しい内容の予約。置換前の予約とは異なる Tag を持つ。

- 抽象度: 概念
- 確定状況: 確定
- 対立・区別: UD-RPL-002。発火後の同じ ID の登録で作る予約
- 関連: UD-RPL-001
- 定義根拠: DR-05
- 関連規則: DR-05、requirements.md REQ-F-005

### UD-RPL-004 置換の失敗状態

置換の途中でプロセスが止まったときに、OS に残る予約の組み合わせ。次の 4 つのいずれかになる。

- 置換前の予約だけが残る (poc-plan.md の名称は「旧予約が残る」)
- 置換後の予約だけが残る (同じく「新予約だけ」)
- 両方が残る (同じく「両方残る」)
- どちらも残らない (同じく「どちらも無い」)

項目:

- 抽象度: 状態・判断
- 確定状況: 確定
- 関連: UD-RPL-001、UD-RPL-002、UD-RPL-003
- 定義根拠: poc-plan.md の PoC-W 合格条件 (W4(e))
- 関連規則: DR-05、requirements.md REQ-F-009

## 5. 通知可否

### UD-NTF-001 通知可否の確認

通知を表示できる状態かを調べる確認。AUMID の登録状態と、通知の設定を対象にする。集中モードとロック状態は、対象に含まない。

- 抽象度: 状態・判断
- 確定状況: 確定
- 関連: UD-RSV-001
- 定義根拠: DR-06
- 関連規則: DR-06、requirements.md REQ-F-002、REQ-F-021

## 6. テスト

### UD-TST-001 Mock

テストで、インターフェースの背後にある実装の代わりに差し替える、テスト用の実装。戻り値を指定でき、呼び出されたかを確認できる。

- 抽象度: 概念
- 確定状況: 確定
- 対立・区別: 実機での手動検証 (OS を実際に呼ぶ確認)
- 関連: UD-NTF-001
- 定義根拠: requirements.md REQ-C-002
- 関連規則: DR-06、requirements.md REQ-C-002、REQ-F-021

## 7. 記録の値

### UD-REC-001 記載なし

結果の記録欄で、確認できていない値に書く語。欄を空にしたり、推測した値を入れたりしない。

- 抽象度: 状態・判断
- 確定状況: 確定
- 対立・区別: UD-REC-002 (資料から確認できない事項。記録欄の値ではない)
- 関連: UD-REC-003
- 定義根拠: requirements.md REQ-NF-003
- 関連規則: DR-03、requirements.md REQ-NF-003、REQ-F-010

### UD-REC-002 未確認

資料や過去の結果から確認できない事項。Assumptions と Open Questions で使う。確認するまで、推測で埋めない。

- 抽象度: 状態・判断
- 確定状況: 確定
- 対立・区別: UD-REC-001 (結果の記録欄で、確認できていない値に書く語)
- 関連: UD-REC-003
- 定義根拠: requirements.md REQ-NF-003
- 関連規則: requirements.md REQ-NF-003

### UD-REC-003 未明確

W5 の記録欄が、確認した値で埋まっていない状態。欄が空、空白だけ、または「記載なし」のとき、未明確になる。w5-check が報告する。

- 抽象度: 状態・判断
- 確定状況: 確定
- 関連: UD-REC-001
- 定義根拠: requirements.md REQ-F-010
- 関連規則: DR-03、requirements.md REQ-F-010

---

## 8. 旧 ID との対応

1.1.0 までの `UD-NNN` は、2.0.0 で次の ID に移行した。旧 ID は、過去のコミットメッセージを読むときにだけ使う。

| 旧 ID  | 新 ID      | 用語           |
| ------ | ---------- | -------------- |
| UD-001 | UD-RSV-001 | 予約           |
| UD-002 | UD-RSV-002 | 予約一覧       |
| UD-003 | UD-RSV-003 | Tag            |
| UD-004 | UD-RSV-004 | Group          |
| UD-005 | UD-TID-001 | 登録時刻       |
| UD-006 | UD-TID-002 | 通知時刻       |
| UD-007 | UD-TID-003 | マシン ID      |
| UD-008 | UD-TID-004 | 対応表         |
| UD-009 | UD-RPL-001 | 置換           |
| UD-010 | UD-RPL-002 | 置換前の予約   |
| UD-011 | UD-RPL-003 | 置換後の予約   |
| UD-012 | UD-RPL-004 | 置換の失敗状態 |
| UD-013 | UD-NTF-001 | 通知可否の確認 |
| UD-014 | UD-TST-001 | Mock           |
| UD-015 | UD-REC-001 | 記載なし       |
| UD-016 | UD-REC-002 | 未確認         |
| UD-017 | UD-REC-003 | 未明確         |

---

## 9. Change History

<!-- SemVer: MAJOR = a term's meaning changed or a term removed, MINOR = a term or an item added,
     PATCH = clarification that keeps the meaning. Keep frontmatter `version` equal to the newest row.
     See docs/.deckrd/rules/deckrd-rule-document-versioning.md -->

| Date       | Version | Description                                                                                                                                                                                                                             |
| ---------- | ------- | --------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| 2026-11-20 | 1.0.0   | Initial release。予約、Tag、置換などの 13 語を定義する                                                                                                                                                                                  |
| 2026-11-20 | 1.1.0   | Add UD-TST-001 Mock; add UD-REC-001 記載なし, UD-REC-002 未確認, UD-REC-003 未明確                                                                                                                                                      |
| 2026-11-21 | 2.0.0   | Rename UD-ID to UD-<CODE>-NNN per chapter; add the chapter table and the old-to-new mapping. 17 terms, no meaning change. Checked: decision-records, requirements, specifications-index/schedule/verification (references renamed only) |
