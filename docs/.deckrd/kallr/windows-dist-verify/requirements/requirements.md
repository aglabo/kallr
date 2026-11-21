---
title: "Requirements: Windows Distribution Verify"
module: "kallr/windows-dist-verify"
status: Draft
version: 1.2.0
created: "2026-11-20"
---

> **Normative Statement**
> This document defines binding requirements.
> Implementations MUST conform to this document.
> RFC 2119 keywords apply to this document only.

## 1. Overview

### 1.1 Purpose

Windows で OS の予約通知 (AddToSchedule) を、採用する配布形式 (未パッケージ + HKCU 登録) で使えるかを確認する。
確認する点は、プロセスを kill した後も通知が出ること、Tag の一意性と置換が成り立つこと。
本文書は Issue #19 の検証項目 W1〜W5 と W7、および合否基準を定める。W6 は Issue #18 で扱うため、本文書の対象外とする。

### 1.2 Scope

- W1〜W4 (予約作成、kill 後の表示、別プロセスからのキャンセル、同一 ID の置換)
- W4-c として、Tag の文字数の上限と予約件数の上限の測定
- W5 (AUMID・インストール方式・実行権限の記録と整合チェック)
- W7 (再起動またはログオフ→ログイン後の予約と、一括再登録による復旧の記録)
- 任意の測定 (過去時刻、予約一覧、配信猶予) の記録
- Tag の生成、対応表、予約の追加・置換・取り消し、通知可否の確認のインターフェースの実装 (テスト駆動)
- 結果の `poc-results-windows.md` への追記

**Out of Scope**:

- W6 (PWA から localhost の Dart HTTP サーバーを呼ぶ検証。Issue #18 で扱う)
- Windows 以外の OS
- `apps/` と `packages/` への PoC コードの配置
- MSIX + Dart と AOT exe の検証 (未確認事項として Open Questions に記録)
- 任意の測定の合否判定
- Android など Windows 以外の、通知可否の確認の実装 (インターフェースは REQ-F-021 で OS 非依存にする)
- `mapToastKey` の採用 (本検証では、ハッシュで Tag を短縮しない。既存コードの削除は spec で決めた)

## 2. Context

- Target Environment: Windows 専用。配布形式は未パッケージ + HKCU 登録。検証対象は Dart FFI (`poc/windows/` 配下)
- Related Components:
  - `poc/windows/w1-w7-verify/lib/map_toast_key.dart` (`mapToastKey`、実装済み)
    - 本検証の Tag には使わない
    - テストは T-WDV-MTK-* の 6 件
  - `poc/windows/w0-3-dartffi/src/w03.dart` (FFI 試作)
    - コマンド: add / list / cancel / show / register-reg / unregister-reg
    - 現在の対応づけ: Tag=alarm、Group=batch (本検証では Tag を生成値、Group を `kallr` の固定値に変える)
    - 既定の AUMID: Kallr.Poc.W01
    - 登録先: `HKCU\Software\Classes\AppUserModelId\<aumid>`
  - `poc-results-windows.md` (過去の PoC 結果と本検証の追記先)
    - 場所: `docs/.deckrd/keneek-core/api-contract/workspaces/redesign/` 配下
  - `docs/.deckrd/keneek-core/api-contract/workspaces/redesign/poc-plan.md`
    - PoC-W 合格条件の出典 (70〜113 行目)
    - W4-c は本文書が置き換える
- Assumptions:
  - 過去の PoC 結果: 未パッケージ + HKCU の AUMID 登録は管理者権限なしで動く
    - 出典: `poc-results-windows.md` (レジストリ登録だけなら管理者権限は要らない)
  - 過去の PoC 結果: MSIX は自己署名で署名し、証明書の導入は管理者権限で実行した
    - 管理者権限なしで同じ手順が失敗するかは未確認 (同ファイルの注 1)
    - 出典: `poc-results-windows.md` の導入方法と権限の比較表
  - 過去の PoC 結果: AUMID が未登録だと add は成功するが通知は表示されない。過去の時刻は 0x80070057 になる
    - 過去の時刻の 0x80070057 の出典: `poc-results-windows.md` (2 回とも指定ミスによる)
  - 過去の PoC 結果: add のプロセス終了後に通知が表示された (W2 の予備結果)
  - Tag と Group の文字数の上限は、公式ドキュメントでは 64 文字 (Windows 10 ビルド 15063 以降。それ以前は 16 文字)
    - 出典: Microsoft Learn の ToastNotification.Tag と ToastNotification.Group (<https://learn.microsoft.com/en-us/uwp/api/windows.ui.notifications.toastnotification.tag>)
  - 上の上限は ToastNotification の記述であり、ScheduledToastNotification での値は未測定
    - ScheduledToastNotification.Id の文字数の上限は、公式ドキュメントでは 16 文字。Tag とは別のプロパティとして区別する
  - 文字数は UTF-16 code unit 数で数える
  - 予約件数の上限は、公式ドキュメントでは 4096 件 (超えると 0x80070718)
    - 4096 件の出典: Microsoft Learn の ToastNotifier.AddToSchedule (<https://learn.microsoft.com/en-us/uwp/api/windows.ui.notifications.toastnotifier.addtoschedule>)
    - 0x80070718 との対応は、Microsoft の公式ページに直接の記述が見つからず、転載ページの記述による。実機で確認する
  - 件数の上限の適用範囲 (アプリ単位、システム全体) と、発火済みの予約を数えるかは未確認
  - PoC のラベル (W1 など) はテストケース ID ではない

### System Context Diagram

```text
[検証担当者] --> +-----------------------------+ --> [Windows 通知 API]
 (add/cancel)    |                             |     (AddToSchedule /
                 |  Windows Distribution       |      GetScheduledToast
                 |  Verify (add / cancel /     |      Notifications)
                 |  Tag generator)             |
[検証担当者] <-- |                             | --> [HKCU レジストリ]
 (結果の確認)    +-----------------------------+     (AUMID 登録)
                              |
                              +--> [poc-results-windows.md]
                                   (結果の追記)
```

## 3. Design Decisions (Summary)

<!-- Decision Records live at the module root (`<modulePath>/decision-records.md`),
     shared by req / spec / impl / tasks. From `requirements/`, link with `../`. -->

| ID    | Decision                                                                              | Linked Record                |
| ----- | ------------------------------------------------------------------------------------- | ---------------------------- |
| DR-01 | 配布形式は未パッケージ + HKCU 登録とする (module.md の記述に基づく)                   | ../decision-records.md#DR-01 |
| DR-02 | 検証対象は Dart FFI とする                                                            | ../decision-records.md#DR-02 |
| DR-03 | 合否は W1〜W4 の成功と W5 の明確化、W7 の結果の記録で判定する                         | ../decision-records.md#DR-03 |
| DR-04 | Tag は登録時刻 (ローカル日時) + マシン ID + 乱数とし、Group は `kallr` の固定値とする | ../decision-records.md#DR-04 |
| DR-05 | 置換は、置換後の予約を追加してから置換前の予約を削除する方式とする                    | ../decision-records.md#DR-05 |
| DR-06 | 通知可否の確認は、OS に依存しないインターフェースに仮想化する                         | ../decision-records.md#DR-06 |

DR 本体は `../decision-records.md` に置く。

## 4. Functional Requirements

### REQ-F-001: add による予約作成 (W1)

- EARS Type: Event-driven

```text
GIVEN AUMID が HKCU に登録済みである
  WHEN 検証担当者が --batch, --alarm, --at, --title を指定して add を実行する
THEN the system SHALL AddToSchedule で予約を作成し、
     対応表に (--batch, --alarm) と生成した Tag を記録し、
     GetScheduledToastNotifications の戻り値に、その Tag、Group=kallr、
     配信時刻=--at の値を持つ要素がちょうど 1 件含まれる状態にする。
```

**Rationale**: W1 の合格条件。確認手段は GetScheduledToastNotifications と定められている。
Tag は REQ-F-016 の書式で生成する。

**Acceptance Criteria**:

| AC ID  | Scenario               |
| ------ | ---------------------- |
| AC-001 | add で予約が作成される |

### REQ-F-002: 通知できない状態での add の拒否

- EARS Type: Unwanted behavior

```text
GIVEN 通知できる状態でない (AUMID の未登録、DisplayName が空、または通知設定が無効)
  NOT DO 予約の作成、および AUMID の登録
THEN the system SHALL 通知できない理由を示すエラーで add を終了し、
     予約を作成せず、HKCU にも書き込まない。
```

**Rationale**: 登録は register-reg の責務とする。未登録のまま add が成功すると通知が表示されない (過去の PoC 結果) ため、失敗を早期に検出する。
確認は REQ-F-021 のインターフェース経由で行う。集中モードとロック状態は、確認の対象に含まれない。

**Acceptance Criteria**:

| AC ID  | Scenario                            |
| ------ | ----------------------------------- |
| AC-004 | 未登録 AUMID では add が失敗する    |
| AC-012 | 通知の設定が無効なら add が失敗する |

### REQ-F-003: kill 後の通知表示 (W2)

- EARS Type: Event-driven

```text
GIVEN add が予約を作成し、その add のプロセスを kill した
  WHEN --at で指定した時刻に到達する
THEN the system SHALL 通知を表示し、予約一覧 (GetScheduledToastNotifications) から
     該当の予約が消え、通知履歴に該当の通知が存在する状態にする。
     通知履歴を取得できない場合の合格の条件は、予約一覧から該当の予約が消えたことと、
     検証担当者が通知の表示を目視で確認したことの両方とする。
```

**Rationale**: W2 の合格条件。判定は、通知履歴 (アクションセンターに残る通知) を API で取得して機械的に行うことを優先する。
未パッケージのアプリで取得できない場合は、予約一覧から消えたことと人の目視の併用に切り替える (Open Questions 参照)。
併用の判定は、通知の内容・AUMID・Tag の対応を機械的に検証できない。
通知の無効設定、集中モード、ロック状態でも、表示されないことがある。この限界は結果に記録する。

**Acceptance Criteria**:

| AC ID  | Scenario                      |
| ------ | ----------------------------- |
| AC-002 | kill 後も指定時刻に表示される |

### REQ-F-004: 別プロセスからのキャンセル (W3)

- EARS Type: Event-driven

```text
GIVEN 別の起動 (先に終了したプロセス) が未発火の予約を作成している
  WHEN 新しいプロセスが --batch と --alarm を指定して cancel を実行する
THEN the system SHALL 対応表から該当の Tag を引いて予約を取り消し、
     GetScheduledToastNotifications の戻り値にその Tag の要素が含まれない状態にする。
```

**Rationale**: W3 の合格条件。Tag は乱数を含み ID から再計算できないため、対応表を使う (理由は REQ-F-020)。

**Acceptance Criteria**:

| AC ID  | Scenario                             |
| ------ | ------------------------------------ |
| AC-003 | 別プロセスから予約をキャンセルできる |

### REQ-F-005: 発火前の置換 (W4-a)

- EARS Type: Event-driven

```text
GIVEN 同じ batchId/alarmId の未発火の予約が存在する
  WHEN 検証担当者が同じ --batch と --alarm で、別の --at または --title を指定して add を実行する
THEN the system SHALL 置換後の予約を新しい Tag で追加し、対応表を置換後の Tag に更新してから、
     置換前の予約を削除し、GetScheduledToastNotifications の戻り値に置換前の Tag の要素が含まれず、
     置換後の Tag の要素が新しい内容でちょうど 1 件含まれる状態にする。
```

**Rationale**: W4 (a) の合格条件。置換は「追加してから削除」とし (DR-05)、AddToSchedule が同じ Tag/Group を自動で置換する挙動には依存しない。
追加を先にする目的は、途中で停止しても予約を消さないこと。置換のたびに、登録時刻と乱数から置換後の Tag を生成する。
置換前の予約、置換後の予約、置換の失敗状態の意味は、universal-dictionary.md の UD-009 から UD-012 に従う。

**Acceptance Criteria**:

| AC ID  | Scenario                 |
| ------ | ------------------------ |
| AC-006 | 発火前の予約を置換できる |

### REQ-F-006: 発火後の登録 (W4-b)

- EARS Type: Event-driven

```text
GIVEN 同じ batchId/alarmId の予約が発火済みで、予約一覧に対応表の Tag の要素がない
  WHEN 検証担当者が同じ --batch と --alarm で、未来の時刻の --at を指定して add を実行する
THEN the system SHALL add を成功 (終了コード 0) させ、
     予約一覧に新しい Tag の要素が、新しい --at の値でちょうど 1 件含まれる状態にする。
```

**Rationale**: W4 (b) の合格条件。発火後の登録は、置換ではなく新しい予約として扱う (poc-plan.md)。
終了コードと予約一覧の値で判定する。実機での確認は手動検証とする。

**Acceptance Criteria**:

| AC ID  | Scenario                                 |
| ------ | ---------------------------------------- |
| AC-007 | 発火後の同じ ID の登録は新しい予約になる |

### REQ-F-007: Tag の長さと予約件数の上限 (W4-c)

- EARS Type: Event-driven

```text
GIVEN Tag の文字数の上限 (maxLength) と予約件数の上限 (N) を実機で測定した
  WHEN 検証担当者が N 件の予約を add で登録する
THEN the system SHALL 生成する Tag の文字数を maxLength 以下に保ち、
     N 件すべての登録を成功させ、予約一覧の Group=kallr の Tag がすべて異なる状態にする。
```

**Rationale**: W4 (c) の合格条件。poc-plan.md は ID の長さをハッシュで収める案を想定していた。
本検証は乱数を含む固定長の Tag に変え (DR-04)、衝突しないことを、実機で測定した範囲 (N 件以内) で確認する。
件数の上限は poc-plan.md では任意の測定だが、衝突を確認する範囲を決めるため、ここでは合否の前提に含める。
N+1 件目の失敗は、結果の記録のみとする。文字数は UTF-16 code unit 数で数える。

**Acceptance Criteria**:

| AC ID  | Scenario                                  |
| ------ | ----------------------------------------- |
| AC-009 | 上限の件数まで登録しても Tag が重複しない |

### REQ-F-008: 置換の方式の記録 (W4-d)

- EARS Type: Event-driven

```text
GIVEN W4 (a) の置換を実施した
  WHEN 検証担当者が置換の方式を確認する
THEN 検証担当者 SHALL 採用した置換の方式 (追加してから削除) と、その結果を poc-results-windows.md に記録する。
     参考として、同じ Tag/Group での AddToSchedule 単独の挙動 (置換されるか、重複するか) も記録する。
```

**Rationale**: W4 (d) の確認項目。置換が原子的かどうかは未確認であり、Open Questions に記す。
採用する方式は DR-05 で決めるため、AddToSchedule 単独の挙動は合否に含めない。

### REQ-F-009: 4 つの失敗状態の記録 (W4-e)

- EARS Type: Event-driven

```text
GIVEN 置換の途中でプロセスを停止させた
  WHEN 検証担当者が停止後の予約一覧を確認する
THEN 検証担当者 SHALL 「置換前の予約だけが残る」「置換後の予約だけが残る」「両方が残る」「どちらも残らない」のうち
     観測された状態を、停止させた段階とともに記録する。
```

**Rationale**: W4 (e) の確認項目。再現の具体的な手段は plan に「各段階の間に kill を差し込む」とだけ書かれており、Open Questions に記す。
追加の後で削除の前に停止すると、「両方が残る」になると予想される。
4 つの状態の名称は、poc-plan.md の W4 (e) の「旧予約が残る」「新予約だけ」「両方残る」「どちらも無い」に対応する (UD-012)。

### REQ-F-010: W5 の記録

- EARS Type: Event-driven

```text
GIVEN 検証担当者が W5 の確認を実施した
  WHEN 結果を poc-results-windows.md に記録する
THEN 検証担当者 SHALL AUMID、インストール方式、実行権限の 3 項目のそれぞれに記録欄を設け、
     各欄を「確認した値」で埋め、3 項目すべてを明確にする。
     「記載なし」の欄が 1 つでも残る場合は、W5 を合格としない。
  AND the system SHALL 3 項目の記録が完備しているかを w5-check で機械的に判定し、未明確の欄を報告する。
```

**Rationale**: W5 の合格条件。poc-plan.md は、必要なアプリの識別子、インストール方式、実行権限が明確になっていることを求める。
値の良し悪しは問わない。確認できていない値を推測で埋めてはならない。確認できるまでは、W5 は合格としない。

**Acceptance Criteria**:

| AC ID  | Scenario                                      |
| ------ | --------------------------------------------- |
| AC-014 | W5 の「記載なし」の欄が未明確として報告される |

### REQ-F-011: W5 の整合チェック

- EARS Type: Event-driven

```text
GIVEN W5 の 3 項目が記録されている
  WHEN E2E の整合チェックを実行する
THEN the system SHALL 記録した値と、実際に観測できる状態
     (HKCU の登録の有無、実行時の権限) が一致するかを機械的に判定し、
     不一致は W5 の不合格ではなく記録の誤りとして報告する。
```

**Rationale**: 記録の正確さを機械的に担保しつつ、W5 のゲートは記録の完備のみとするため。

**Acceptance Criteria**:

| AC ID  | Scenario                                    |
| ------ | ------------------------------------------- |
| AC-005 | W5 の記録の不一致が記録の誤りとして扱われる |

### REQ-F-012: W7 の記録

- EARS Type: Event-driven

```text
GIVEN 予約が存在する状態である
  WHEN 検証担当者が再起動、またはログオフ→ログインのいずれかを行い、その後に予約一覧を確認し、一括再登録を実行する
THEN 検証担当者 SHALL 実施した操作 (再起動か、ログオフ→ログインか) と、その後の予約の有無と、
     一括再登録で復旧できたかどうかを記録する。
     再起動だけ、またはログオフ→ログインだけの実施でも、W7 の記録として足りる。
```

**Rationale**: W7 の記録項目。Issue は「再起動またはログオフ」とするため、どちらか一方の実施でよい。記録のときに、実施した操作も記録する。

### REQ-F-013: 任意の測定の記録

- EARS Type: Event-driven

```text
GIVEN 任意の測定 (過去時刻、予約一覧、配信猶予) を実施した
  WHEN 検証担当者が結果を記録する
THEN 検証担当者 SHALL 測定結果を記録のみとして残し、W1〜W4 の合否には含めない。
```

**Rationale**: Issue #19 の指定による。4096 件の上限は、REQ-F-007 の前提として W4-c で測定するため、ここには含めない。

### REQ-F-014: 結果の追記

- EARS Type: Event-driven

```text
GIVEN W1〜W5 および W7 の確認が完了した
  WHEN 検証担当者が結果をまとめる
THEN 検証担当者 SHALL 結果を poc-results-windows.md に追記し、既存の記述を書き換えない。
```

**Rationale**: 目標に「結果を poc-results-windows.md に追記する」とある。

### REQ-F-015: 全体の合否

- EARS Type: Event-driven

```text
GIVEN W1〜W4、W5、W7 の確認が完了した
  WHEN 検証担当者が全体の合否を判定する
THEN 検証担当者 SHALL W1〜W4 がすべて成功し、W5 の 3 項目がすべて明確で、
     かつ W7 の記録 (再起動、ログオフ→ログインのどちらか 1 つ以上) が揃っている場合に限り合格と判定する。
```

**Rationale**: poc-plan.md の PoC-W 合格条件に基づくゲート。

### REQ-F-016: Tag の生成

- EARS Type: Event-driven

```text
GIVEN 登録時刻 (ローカル日時)、マシン ID、64 bit の乱数が与えられる
  WHEN Tag を生成する
THEN the system SHALL `<YYYYMMDDHHmmss>-<マシン ID 8 桁>-<乱数 16 桁>` の書式 (16 進は小文字) で
     40 文字の Tag を返し、同じ入力からは同じ Tag を返す。
     日時部分を先頭に置くため、通常は Tag の文字列順が登録時刻の順になる。
     夏時間の切り替えやタイムゾーンの変更では、一致しない場合がある。
```

**Rationale**: DR-04 の Tag の仕様。時刻、マシン ID、乱数は引数で受け取り、乱数と時計に依存しない純粋な関数とする。
こうすると、書式と文字数を自動テストで確認できる。乱数は暗号論的乱数を使う。

**Acceptance Criteria**:

| AC ID  | Scenario                   |
| ------ | -------------------------- |
| AC-008 | Tag が決められた書式になる |

### REQ-F-017: Tag の重複の回避

- EARS Type: Unwanted behavior

```text
GIVEN 生成した Tag が、予約一覧の Group=kallr に既に存在する
  NOT DO 同じ Tag での予約の追加
THEN the system SHALL 乱数部分を再生成して重複のない Tag で予約するか、
     再生成の上限回数を超えたらエラーで終了し、予約を作成しない。
```

**Rationale**: 乱数の重複確率は小さいが、登録前の確認で構造的に衝突を防ぐ。上限回数は spec で決める。

**Acceptance Criteria**:

| AC ID  | Scenario                    |
| ------ | --------------------------- |
| AC-010 | 重複した Tag は再生成される |

### REQ-F-018: PoC コードの配置禁止

- EARS Type: Unwanted behavior

```text
GIVEN 本検証の成果物を作成する
  NOT DO apps/ と packages/ への PoC コードの配置
THEN the system SHALL PoC コードを poc/ 配下にのみ置く。
```

**Rationale**: REQ-C-001 の制約を満たすため。

### REQ-F-019: マシン ID の生成と保存

- EARS Type: Event-driven

```text
GIVEN マシン ID がまだ保存されていない
  WHEN Kallr が初めて起動する
THEN the system SHALL 32 bit の乱数を 8 桁の 16 進で生成して保存し、
     以降の起動では、保存した同じ値を使う。
```

**Rationale**: Tag の一部 (REQ-F-016)。マシンごとに異なる値とし、再起動の前後で変えない。

**Acceptance Criteria**:

| AC ID  | Scenario                             |
| ------ | ------------------------------------ |
| AC-011 | 2 回目の起動では同じマシン ID を使う |

### REQ-F-020: 対応表

- EARS Type: Ubiquitous

```text
the system SHALL (batchId, alarmId) から Tag を引ける対応表を持ち、
同じ (batchId, alarmId) に対して有効な Tag を 1 つだけ保つ。
```

**Rationale**: Tag は乱数を含み、ID から再計算できない。cancel と置換は、この表で置換前の Tag を探す。
保存場所と形式、更新の順序は spec で決めた。

### REQ-F-021: 通知可否の確認と設定の仮想化

- EARS Type: Ubiquitous

```text
the system SHALL 通知の可否の確認、AUMID の登録・確認・削除を、OS 非依存のインターフェースとして共通ライブラリに提供し、
Kallr (add / cancel などの本体) はそのインターフェースだけを使う。
Windows 向けの実装は、HKCU のレジストリ (AUMID の存在と DisplayName) と
ToastNotifier.Setting (通知の有効・無効) を使って確認する。
```

**Rationale**: OS 固有の確認を本体から分離する (DR-06)。他の OS (Android など) の実装と差し替えられる。
インターフェースは Mock に差し替えられるため、本体の判断を自動テストで確認できる。
Android の実装は本検証の対象外とする。

**Acceptance Criteria**:

| AC ID  | Scenario                                     |
| ------ | -------------------------------------------- |
| AC-013 | Kallr は仮想化したインターフェースだけを使う |

## 5. Non-Functional Requirements

### REQ-NF-001: Maintainability

実装は保守可能でなければならない (MUST)。OS 固有の呼び出し (FFI) は、インターフェースの背後に置き、OS に依存しないロジックから分離する。
通知可否の確認とレジストリの操作は、仮想化したインターフェースの背後に置く (REQ-F-021)。

### REQ-NF-002: Testability

W1〜W4 の各合格条件は、「どの値になれば合格か」の形で書かなければならない (MUST)。
値には、観測できるもの (GetScheduledToastNotifications の戻り値、通知履歴、終了コードなど) を使う。
測定: REQ-F-001〜REQ-F-007 の THEN 節の 100% が観測可能な値で記述されている。
自動化の方法は spec / impl で決める。

### REQ-NF-003: No Speculation

ドキュメントに書かれていない事項を、推測で埋めてはならない (MUST NOT)。
使い分けは次のとおり。結果の記録欄で確認できていない値は、「記載なし」と書く。資料から確認できない事項は、「未確認」と書く。
測定: 結果の記録欄の空欄と推測値が 0 件であること。ただし W5 の 3 欄に「記載なし」が残る場合は、REQ-F-010 により W5 を合格としない。

### REQ-NF-004: Portability

実装は UTF-8 入力に対応しなければならない (MUST)。

## 6. Constraints

### REQ-C-001: PoC コードの配置

PoC のコードを `apps/` と `packages/` に置いてはならない。

### REQ-C-002: テスト駆動の範囲

実装は、可能な限りすべて、テスト駆動 (BDD の RGR サイクル) で行う。インターフェースの背後にある OS 固有の部分は、Mock でテストする。
FFI の呼び出しと実機での確認 (kill、再起動、ログオフ→ログイン) は手動検証とする。

### REQ-C-003: ラベルの扱い

PoC のラベル (W1 など) は、テストケース ID と別物とする。テスト ID は別途採番する。

### REQ-C-004: 対象環境

本検証は Windows のみを対象とする。

## 7. User Stories

| Story ID | Role         | Goal                                                                                  | Reason                                                 | Related Requirements            |
| -------- | ------------ | ------------------------------------------------------------------------------------- | ------------------------------------------------------ | ------------------------------- |
| US-001   | 検証担当者   | add で未発火の予約を作成し、予約一覧で確認する                                        | 予約通知が採用する配布形式で使えるかを判断する         | REQ-F-001                       |
| US-002   | 検証担当者   | 通知できない状態 (AUMID の未登録、DisplayName が空、通知設定が無効) で add を実行する | 通知が表示されない状態を、add のエラーで見逃さない     | REQ-F-002                       |
| US-003   | 検証担当者   | プロセスを kill した後に、指定時刻の通知の表示を確認する                              | アプリ終了後も予約通知が働くかを判断する               | REQ-F-003                       |
| US-004   | 検証担当者   | 別の起動から予約をキャンセルし、同じ ID で置換する                                    | 再起動後のプロセスから予約を管理できるかを判断する     | REQ-F-004, REQ-F-005            |
| US-005   | 検証担当者   | AUMID・インストール方式・実行権限を記録し、実態と照合する                             | 配布形式の前提を、根拠のある値で残す                   | REQ-F-010, REQ-F-011            |
| US-006   | 検証担当者   | 再起動またはログオフ→ログイン後の予約と一括再登録の結果を記録する                     | 予約が失われた場合の復旧手段を判断する                 | REQ-F-012                       |
| US-007   | 検証担当者   | 発火後に同じ ID で add を実行し、新しい予約になることを確認する                       | 置換と、発火後の登録を区別する                         | REQ-F-006                       |
| US-008   | 検証担当者   | 上限の件数まで add で登録し、Tag の重複と文字数を確認する                             | 衝突しないことを、実機で測定した範囲で確認する         | REQ-F-007                       |
| US-009   | 検証担当者   | 置換の方式と、停止時の 4 つの失敗状態を記録する                                       | 置換が原子的かどうかが未確認のため、観測した状態を残す | REQ-F-008, REQ-F-009            |
| US-010   | 検証担当者   | 任意の測定結果を、合否に含めず記録する                                                | Issue #19 の指定に従い、測定結果だけを残す             | REQ-F-013                       |
| US-011   | 検証担当者   | 結果を poc-results-windows.md に追記し、全体の合否を判定する                          | 既存の記述を残し、合否の基準を 1 つに固定する          | REQ-F-014, REQ-F-015            |
| US-012   | 検証担当者   | PoC コードを poc/ 配下にのみ置く                                                      | apps/ と packages/ に PoC コードを混ぜない             | REQ-F-018                       |
| US-013   | Kallr の本体 | 登録時刻・マシン ID・乱数から Tag を生成し、重複を避ける                              | 予約ごとに衝突しない一意な Tag を付ける                | REQ-F-016, REQ-F-017, REQ-F-019 |
| US-014   | Kallr の本体 | (batchId, alarmId) から Tag を対応表で引く                                            | Tag は乱数を含み、ID から再計算できない                | REQ-F-020                       |
| US-015   | Kallr の本体 | 通知可否の確認を、OS 非依存のインターフェース経由で実行する                           | OS 固有の確認を本体から分離し、Mock で自動テストする   | REQ-F-021                       |

## 8. Acceptance Criteria

```gherkin
# AC-001: add で予約が作成される
# Requirement: REQ-F-001
Scenario: add で予約が作成される
  Given AUMID が HKCU に登録済みである
  When  --batch, --alarm, --at, --title を指定して add を実行する
  Then  対応表に生成した Tag が記録され、GetScheduledToastNotifications の戻り値に、その Tag、Group=kallr、配信時刻=--at の要素がちょうど 1 件含まれる

# AC-002: kill 後も指定時刻に表示される
# Requirement: REQ-F-003
Scenario: kill 後も指定時刻に表示される
  Given add が予約を作成し、その add のプロセスを kill した
  When  --at の時刻に到達する
  Then  予約一覧から該当の予約が消え、通知履歴に該当の通知が存在する

# AC-003: 別プロセスから予約をキャンセルできる
# Requirement: REQ-F-004
Scenario: 別プロセスから予約をキャンセルできる
  Given 先に終了したプロセスが未発火の予約を作成している
  When  新しいプロセスが同じ --batch と --alarm で cancel を実行する
  Then  GetScheduledToastNotifications の戻り値に対応表の Tag の要素が含まれない

# AC-004: 未登録 AUMID では add が失敗する
# Requirement: REQ-F-002
Scenario: 未登録 AUMID では add が失敗する
  Given AUMID が HKCU に登録されていない
  When  add を実行する
  Then  エラーで終了し、予約は作成されず、HKCU への書き込みも行われない

# AC-012: 通知の設定が無効なら add が失敗する
# Requirement: REQ-F-002
Scenario: 通知の設定が無効なら add が失敗する
  Given AUMID は登録済みで、通知の設定が無効である
  When  add を実行する
  Then  通知できない理由を示すエラーで終了し、予約は作成されない

# AC-013: Kallr は仮想化したインターフェースだけを使う
# Requirement: REQ-F-021
Scenario: Kallr は仮想化したインターフェースだけを使う
  Given 通知可否の確認が、Mock に差し替えられている
  When  add を実行する
  Then  Mock の戻り値に従って add が成功または失敗し、レジストリと Windows API は呼ばれない

# AC-005: W5 の記録の不一致が記録の誤りとして扱われる
# Requirement: REQ-F-011
Scenario: W5 の記録の不一致が記録の誤りとして扱われる
  Given W5 の AUMID 欄に、HKCU の実際の登録と異なる値が記録されている
  When  E2E の整合チェックを実行する
  Then  不一致が記録の誤りとして報告され、W5 の合否は記録の完備のみで判定される

# AC-014: W5 の「記載なし」の欄が未明確として報告される
# Requirement: REQ-F-010
Scenario: W5 の「記載なし」の欄が未明確として報告される
  Given W5 の記録欄のうち 1 つが「記載なし」である
  When  w5-check を実行する
  Then  その欄が未明確として報告され、W5 は合格としない

# AC-006: 発火前の予約を置換できる
# Requirement: REQ-F-005
Scenario: 発火前の予約を置換できる
  Given 同じ batchId/alarmId の未発火の予約が存在する
  When  同じ --batch と --alarm で別の --at または --title を指定して add を実行する
  Then  予約一覧に置換前の Tag の要素がなく、置換後の Tag の要素が新しい --at でちょうど 1 件含まれる

# AC-007: 発火後の同じ ID の登録は新しい予約になる
# Requirement: REQ-F-006
Scenario: 発火後の同じ ID の登録は新しい予約になる
  Given 同じ batchId/alarmId の予約が発火済みで、予約一覧に対応表の Tag の要素がない
  When  同じ --batch と --alarm で未来の --at を指定して add を実行する
  Then  終了コードが 0 で、予約一覧に新しい Tag の要素が新しい --at でちょうど 1 件含まれる

# AC-008: Tag が決められた書式になる
# Requirement: REQ-F-016
Scenario: Tag が決められた書式になる
  Given 登録時刻 (ローカル日時)、マシン ID、64 bit の乱数が与えられている
  When  Tag を生成する
  Then  Tag は `<YYYYMMDDHHmmss>-<マシン ID 8 桁>-<乱数 16 桁>` の 40 文字で、同じ入力からは同じ値が得られる

# AC-009: 上限の件数まで登録しても Tag が重複しない
# Requirement: REQ-F-007
Scenario: 上限の件数まで登録しても Tag が重複しない
  Given 実機で測定した Tag の maxLength と予約件数の上限 N がある
  When  N 件の予約を add で登録する
  Then  N 件すべてが成功し、Group=kallr の Tag がすべて異なり、各 Tag の文字数が maxLength 以下である

# AC-010: 重複した Tag は再生成される
# Requirement: REQ-F-017
Scenario: 重複した Tag は再生成される
  Given 生成した Tag が予約一覧の Group=kallr に既に存在する
  When  add を実行する
  Then  乱数部分が再生成され、重複のない Tag で予約が作成される

# AC-011: 2 回目の起動では同じマシン ID を使う
# Requirement: REQ-F-019
Scenario: 2 回目の起動では同じマシン ID を使う
  Given 初回の起動でマシン ID が生成され、保存されている
  When  Kallr を再び起動する
  Then  保存された同じマシン ID が使われる
```

## 9. Open Questions

| Question                                                                                                                 | Type         | Impact Area       | Owner      |
| ------------------------------------------------------------------------------------------------------------------------ | ------------ | ----------------- | ---------- |
| 4 つの失敗状態を再現する具体的な手段 (plan は「各段階の間に kill を差し込む」とだけ書く)                                 | Procedure    | REQ-F-009         | TBD        |
| 置換が原子的かどうか                                                                                                     | Verification | REQ-F-005, 008    | TBD        |
| 未パッケージのアプリで通知履歴を取得できるか。取得できない場合は、予約一覧から消えたこと + 人の目視の併用に切り替える    | Verification | REQ-F-003         | TBD        |
| 目視の併用では、通知の内容・AUMID・Tag の対応を機械的に検証できない。この限界を許容するか                                | Risk         | REQ-F-003         | TBD        |
| MSIX + Dart と AOT exe の検証                                                                                            | Scope        | REQ-F-010         | TBD        |
| ScheduledToastNotification での Tag の文字数の上限 (公式ドキュメントは 64 文字。実機で測定)                              | Measurement  | REQ-F-007         | 検証担当者 |
| 予約件数の上限 (公式ドキュメントは 4096 件) が、アプリ単位かシステム全体か、発火済みを数えるか                           | Measurement  | REQ-F-007         | 検証担当者 |
| ToastNotifier.Setting が、AUMID の登録済みの構成で Enabled を返すか。通知を無効にしたとき、無効の値を返すか (実機で測定) | Measurement  | REQ-F-002, 021    | 検証担当者 |
| 共通ライブラリの置き場所とインターフェースの形。Android の実装を行うモジュールと時期                                     | Design       | REQ-F-021         | TBD        |
| 検証の成果物 (結果の追記) の担当者は検証担当者でよいか                                                                   | Ownership    | REQ-F-014         | TBD        |
| REQ-F-006: 発火後の登録の成否を、終了コード 0 と予約一覧の値で判定する条件を定めた。API が返す具体的な値は未確認         | EARS/THEN    | REQ-F-006 outcome | TBD        |
| poc-plan.md の W4-c (ID の長さをハッシュで収める案) と、4096 件の測定を任意とする記述を、本文書に合わせて改訂するか      | Consistency  | REQ-F-007, 013    | TBD        |

## 10. Traceability

| REQ ID     | AC IDs         | Type           |
| ---------- | -------------- | -------------- |
| REQ-F-001  | AC-001         | Functional     |
| REQ-F-002  | AC-004, AC-012 | Functional     |
| REQ-F-003  | AC-002         | Functional     |
| REQ-F-004  | AC-003         | Functional     |
| REQ-F-005  | AC-006         | Functional     |
| REQ-F-006  | AC-007         | Functional     |
| REQ-F-007  | AC-009         | Functional     |
| REQ-F-008  | N/A            | Functional     |
| REQ-F-009  | N/A            | Functional     |
| REQ-F-010  | AC-014         | Functional     |
| REQ-F-011  | AC-005         | Functional     |
| REQ-F-012  | N/A            | Functional     |
| REQ-F-013  | N/A            | Functional     |
| REQ-F-014  | N/A            | Functional     |
| REQ-F-015  | N/A            | Functional     |
| REQ-F-016  | AC-008         | Functional     |
| REQ-F-017  | AC-010         | Functional     |
| REQ-F-018  | N/A            | Functional     |
| REQ-F-019  | AC-011         | Functional     |
| REQ-F-020  | AC-003, AC-006 | Functional     |
| REQ-F-021  | AC-013         | Functional     |
| REQ-NF-001 | N/A            | Non-Functional |
| REQ-NF-002 | N/A            | Non-Functional |
| REQ-NF-003 | N/A            | Non-Functional |
| REQ-NF-004 | N/A            | Non-Functional |
| REQ-C-001  | N/A            | Constraint     |
| REQ-C-002  | N/A            | Constraint     |
| REQ-C-003  | N/A            | Constraint     |
| REQ-C-004  | N/A            | Constraint     |

## 11. Change History

<!-- SemVer: MAJOR = requirement removed / approach discarded,
     MINOR = requirement / AC / DR added, PATCH = clarification only.
     Keep frontmatter `version` equal to the newest row below.
     See docs/.deckrd/rules/deckrd-rule-document-versioning.md -->

| Date       | Version | Description                                                                                                                                                                                                                                                                                                                                                |
| ---------- | ------- | ---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| 2026-11-20 | 1.0.0   | Initial release (計画メッセージ(チャット文)を全面置換)                                                                                                                                                                                                                                                                                                     |
| 2026-11-20 | 1.1.0   | Revise REQ-C-002, REQ-NF-001: test-driven development applies to all implementation where possible                                                                                                                                                                                                                                                         |
| 2026-11-20 | 1.1.1   | Clarify the term: use Mock instead of 偽の実装                                                                                                                                                                                                                                                                                                             |
| 2026-11-21 | 1.2.0   | W7: accept either a restart or a logoff-and-login; REQ-F-010: check W5 completeness in w5-check (add AC-014); fix inconsistencies found in review; state that W6 belongs to Issue #18; separate 記載なし (record placeholder) from 未確認 (unconfirmed in sources); cite sources for assumptions; rewrite User Stories as facts and cover all requirements |
