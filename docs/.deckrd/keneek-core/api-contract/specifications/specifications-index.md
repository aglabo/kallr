---
title: "Design Specification Index: Notification API Contract"
based-on: requirements.md v1.5.3
status: Draft
version: 1.1.4
created: "2026-11-14"
---

> **Normative Statement**
> 本ドキュメントは拘束力のある仕様の索引を定義する。
> 実装は本ドキュメントに適合しなければならない (MUST)。
> RFC 2119 キーワードは本ドキュメントにのみ適用する。
> 本ドキュメント内では、SHALL と MUST、SHALL NOT と MUST NOT は同義であり、拘束力に差はない。
>
> Part of split specification. 本ファイルは分割された 4 ファイルの索引である。

## 1. Overview

### 1.1 Purpose

通知 REST API 契約の Design Specification を 4 ファイルに分割した。
本索引は、その範囲、要件 (REQ・AC) との対応、共通の用語、Open Questions の解決先を一覧にする。
振る舞いの詳細は各ファイルが定義し、本索引では重複させない。

### 1.2 Scope

本書は、振る舞いの規則と分類の意味を定義する。
実装の詳細は対象外とする。

本索引は Rule を持たない。振る舞いの記述が索引と各ファイルで食い違う場合は、各ファイルを正とする (MUST)。

#### 分割ファイルの範囲

| ファイル                        | 担当 REQ                                                   | Rule ID / DD 接頭辞                                     | 概要                                                                                                                                     |
| ------------------------------- | ---------------------------------------------------------- | ------------------------------------------------------- | ---------------------------------------------------------------------------------------------------------------------------------------- |
| `specifications-endpoints.md`   | REQ-F-001, REQ-F-002, REQ-F-005, REQ-F-007                 | `R-EP-C-NNN` / `R-EP-I-NNN` / `R-EP-X-NNN` / `DD-EP-NN` | 4 操作、通知のデータ形状と状態、登録リクエストのスキーマ、再送・キャンセルなどの保証                                                     |
| `specifications-errors.md`      | REQ-F-003, REQ-F-004, REQ-F-006, REQ-F-008                 | `R-ER-C-NNN` / `R-ER-I-NNN` / `R-ER-X-NNN` / `DD-ER-NN` | 共通エラー形式、エラーカタログ、分類と対処方針、拡張規則、認証の外部仕様、外部応答の優先順位                                             |
| `specifications-governance.md`  | REQ-F-009〜012, REQ-NF-001/002, REQ-C-001〜005             | `R-GV-C-NNN` / `R-GV-I-NNN` / `R-GV-X-NNN` / `DD-GV-NN` | 整合確認の記録、バージョン管理、破壊的変更の扱い、ローカル検証、標準適合と配置の制約                                                     |
| `specifications-idempotency.md` | REQ-F-001 (再送と回復の部分), REQ-F-007 (バッチ登録の再送) | `R-ID-C-NNN` / `R-ID-I-NNN` / `R-ID-X-NNN` / `DD-ID-NN` | 再送と冪等性の保証の正本。保証の境界、用語 (`universal-dictionary.md` の UD-ID への参照)、問題 (IP-1〜IP-5) ごとの規則、具体値とシナリオ |

---

## 2. Design Principles

### 2.1 Classification Philosophy

- 正本の優先順位は、decision-records.md (DR-01〜06) を最上位とし、次に確認済み設計の条件、API の確定事項、関数の確定事項の順とする。
- DR を再定義したり、DR と重複する新しい判断を作ったりしない。DR は参照だけにする。
- 内部の実現方法 (トランザクション、重複排除の保存方法、判定アルゴリズム、状態遷移の内部、認証メカニズムの内部、永続化) は、どのファイルにも書かない (MUST NOT)。

### 2.2 Design Assumptions

- 契約の利用者は PWA クライアントのみで、通信は JSON over HTTP のみとする (requirements.md 2 章の前提)。
- 用語の正本は `universal-dictionary.md` とする。3.3 は、本仕様で新たに使う用語の UD-ID を示す。
- 本索引と各ファイルの Rule ID は、上表の接頭辞で衝突しない。

### 2.3 External Design Summary

> **Source**: Derived from the external design dialogue and user-confirmed design direction.

#### Feature Decomposition

| Unit | Responsibility                                         | REQ Coverage                    | 担当ファイル |
| ---- | ------------------------------------------------------ | ------------------------------- | ------------ |
| U1   | Endpoints: バッチ登録・一覧・単体取得・キャンセル      | REQ-F-001                       | endpoints    |
| U2   | Data shape & states: 通知の形状と状態の集合            | REQ-F-005                       | endpoints    |
| U3   | Request schema: `notifications` 配列の検証制約         | REQ-F-002, REQ-C-002            | endpoints    |
| U4   | Error spec: 共通エラー形式とエラーカタログ             | REQ-F-003, REQ-F-004, REQ-F-006 | errors       |
| U5   | Handling policy: code ごとの対処方針と応答なし時の対処 | REQ-F-004                       | errors       |
| U6   | Resend guarantees: 各操作の再送時の振る舞い            | REQ-F-007                       | idempotency  |
| U7   | Auth external spec: 認証必須の宣言と認証の外部仕様     | REQ-F-008, REQ-C-005            | errors       |
| U8   | Versioning: 契約バージョンと API メジャーバージョン    | REQ-F-010, REQ-F-011            | governance   |
| U9   | Validation: オフラインのローカル検証                   | REQ-F-012, REQ-NF-001/002       | governance   |
| U10  | Consistency record: 保証と兄弟 issue の照合結果        | REQ-F-009                       | governance   |

#### Unit Interaction Map

```text
+------------+     +-------------+     +------------+
| U7 Auth    | --> | U1 Endpoints| --> | U2 Shape   |
| [errors]   |     | [endpoints] |     | [endpoints]|
+------------+     +-------------+     +------------+
                     |    |    |
                     |    |    v
                     |    |  +------------+
                     |    |  | U3 Schema  |
                     |    |  | [endpoints]|
                     |    |  +------------+
                     |    v
                     |  +------------+
                     |  | U6 Resend  |
                     |  | [endpoints]|
                     |  +------------+
                     v
                   +------------+     +------------+
                   | U4 Errors  | --> | U5 Policy  |
                   | [errors]   |     | [errors]   |
                   +------------+     +------------+

[governance] U8 Versioning  : U1-U7 を支配する (パス、契約バージョン、破壊的変更の基準)
[governance] U9 Validation  : U1-U4 をオフラインで検査する (U3-U1、U4-U1 の成果物間の照合を含む)
[governance] U10 Record     : U1/U2/U6/U7 の保証を #4/#5/#6 (条件付きで #7) と照合する
```

ファイル間の順序制約は次のとおり。

- U4 のエラー識別子 (code) を変えると、U5 と U10 の該当行に影響する。
- U2 の状態を変えると、U1 (キャンセル)、U6、U10 に影響する。

#### Data Flow Diagram

```text
[PWA request] --> [U7 認証] --> [U1 エンドポイント] --> [U2 通知 / 結果]
                      |               |
                      v               v
               [U4 エラー応答] <-- [U3 入力検証]
                      |
                      v
               [U5 対処方針]

[U9 ローカル検証] : U1-U4 の成果物を検査する (オフライン)
```

複数のエラー条件が同時に成立したときの外部応答の優先順位は、errors で定義する。

### 2.4 Non-Goals

> **Derivation**: All items below originate from REQUIREMENTS Section "Out of Scope".

- 内部の実現方法の定義 ← REQ: Out of Scope #1
  - #4: 登録処理の原子性の実現方法・冪等性と重複排除の実現方法・バリデーションの判定アルゴリズム
  - #5: 照会・キャンセルの判定アルゴリズムと状態遷移の内部
  - #6: loopback・CORS・Origin チェック・ペアリング・認証メカニズムの内部実装
  - #7: SQLite 永続化
  - #8: e2e テスト
- ペアリングエンドポイントの定義 ← REQ: Out of Scope #2
- 認証メカニズムの内部実装 (資格情報の発行、保存、検証) の定義 ← REQ: Out of Scope #3
- 具体的な再試行のアルゴリズム (指数バックオフ、ジッター、最大試行回数など)。契約で保証する必要がある部分を除く ← REQ: Out of Scope #4
- 契約検証の CI 統合 ← REQ: Out of Scope #5

### 2.5 Behavioral Design Decisions

本索引は固有の Design Decision を持たない。
Design Decision は各ファイルが固有の接頭辞 (`DD-EP-NN`、`DD-ER-NN`、`DD-GV-NN`) で管理する。
正式な Decision Record への昇格が必要な場合は `/deckrd dr --add` を使う。

### 2.6 Related Decision Records

> **Reference**: This section lists formal DRs that affect this specification.
> DRs are maintained in `decision-records.md` and are authoritative.

| DR-ID | Title                                                                                       | Phase         | Impact on This Spec                                                                                              |
| ----- | ------------------------------------------------------------------------------------------- | ------------- | ---------------------------------------------------------------------------------------------------------------- |
| DR-01 | 共通エラー形式に RFC 9457 を採用し、`type` と `code` を 1 対 1 で対応させる                 | review-harden | errors の共通エラー形式とエラーカタログの前提。再定義しない                                                      |
| DR-02 | バッチ登録のレスポンスは all-or-nothing の形状とし、部分成功を表す形状を持たない            | review-harden | endpoints のバッチ登録のレスポンス形状の前提                                                                     |
| DR-03 | 外部から観測できる振る舞いの保証を API 契約に含め、内部の実現方法は兄弟 issue に委ねる      | review-harden | 全ファイルの境界。内部の実現方法を書かない根拠                                                                   |
| DR-04 | エラーの分類とクライアントの対処を分離し、エラー識別子の追加を無条件に後方互換としない      | review-harden | errors の分類・対処方針・拡張規則と、governance の破壊的変更の基準の前提                                         |
| DR-05 | 契約確定前の兄弟 issue との整合確認は、保証ごとの照合結果を記録として Specifications に残す | review-harden | governance の整合確認の記録の前提                                                                                |
| DR-06 | バッチ登録の冪等性を、安全性・応答の一貫性・回復可能性に分けて外部契約にする                | spec          | endpoints の 3.8.1 と再送の規則、errors の R-ER-C-009・R-ER-C-013 と 409 の条件、governance の G-16〜G-18 の前提 |

### 2.7 DD to DR Promotion Criteria

> **Purpose**: Guidelines for determining when a DD should be promoted to a formal DR.
> Promotion is a **human judgment** — these criteria inform, not automate.

**Consider promoting a DD when:**

1. Cross-specification Impact — The decision affects multiple specifications or modules
2. Architectural Significance — The decision constrains future design choices
3. Non-trivial Alternatives — Multiple viable options existed
4. Stakeholder Visibility Required — The decision should be reviewable by external parties

**Keep as DD when:**

- Decision is local to this specification only
- No significant alternatives existed
- Rationale is self-evident from context

> **Action**: To promote, run `/deckrd dr --add` with the DD context,
> then update DD Status to `Promoted → DR-xx`.

---

## 3. Behavioral Specification

### 3.1 Input Domain

- Input Type: 本索引は入力を受け取らない。読者が REQ・AC・Open Questions から担当ファイルを引くための参照情報である。
- Assumptions: 各ファイルの記述が正本であり、索引は要約である。

### 3.2 Output Semantics

- Output Meaning: 要件の項目 (REQ、AC、Open Questions) と、それを定義するファイルの対応を示す。
- Possible Outcomes:
  - 担当ファイルが一意に決まる。
  - 複数ファイルが関係する場合は、主担当と関連ファイルを区別して示す。

### 3.3 共通の用語

用語の定義の正本は、モジュール直下の `universal-dictionary.md` とする。分割ファイルは用語を定義し直さず、UD-ID で参照する。

本仕様で新たに使う用語は次のとおりとする。

| 用語                                                            | UD-ID          |
| --------------------------------------------------------------- | -------------- |
| dispatched                                                      | UD-011         |
| missed                                                          | UD-012         |
| エラーカタログ                                                  | UD-017         |
| 照合結果                                                        | UD-028         |
| API が生成した共通エラー形式の 4xx                              | UD-018         |
| バッチ登録の冪等性の用語 (論理操作、送信、登録処理、処理権など) | UD-029〜UD-055 |

---

## 4. Decision Rules

本索引は Decision Rules を持たない。各ファイルの Decision Rules を参照すること。

### 4.1 規則の分類 (全ファイル共通)

各ファイルの Decision Rules は、規則を次の 3 つに分類し、分類を Rule ID の 3 番目のセグメント (`C`・`I`・`X`) で示す。分類は規則の拘束力を変えない。

| 分類                     | ID           | 基準                                                                                                                                                                                |
| ------------------------ | ------------ | ----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| 契約として確定すべき事項 | `R-xx-C-NNN` | クライアントと契約の利用者が観測する、または従うもの。リクエストとレスポンス、応答の意味と分類、エラー形式と識別子、クライアントの義務、契約成果物と版の規則、契約を確定する条件    |
| 実装で保証すべき事項     | `R-xx-I-NNN` | 実装 (サーバー、クライアント、検証ツール、リポジトリ) が満たさなければならない性質と、契約が実現方法を定めずに実装や兄弟 issue に委ねる境界。個々のレスポンスからは直接観測できない |
| 将来の拡張案             | `R-xx-X-NNN` | v1 の範囲外であることを、各ファイルまたは DR が明示しているもの。規範ではない                                                                                                       |

旧 ID (`R-xx-NNN`) は廃止し、再利用しない。旧 ID との対応は、各ファイルの 4 章の対応表による。

| ファイル                        | 参照先                                            |
| ------------------------------- | ------------------------------------------------- |
| `specifications-endpoints.md`   | 4 章 (`R-EP-C-NNN` / `R-EP-I-NNN` / `R-EP-X-NNN`) |
| `specifications-errors.md`      | 4 章 (`R-ER-C-NNN` / `R-ER-I-NNN` / `R-ER-X-NNN`) |
| `specifications-governance.md`  | 4 章 (`R-GV-C-NNN` / `R-GV-I-NNN` / `R-GV-X-NNN`) |
| `specifications-idempotency.md` | 4 章 (`R-ID-C-NNN` / `R-ID-I-NNN` / `R-ID-X-NNN`) |

---

## 5. Edge Cases

本索引のエッジケースとして、各ファイルへの振り分けと、ファイル間の食い違いの扱いを示す。

| Input                                                | Classification                                   | REQ                  | Rationale                                                   |
| ---------------------------------------------------- | ------------------------------------------------ | -------------------- | ----------------------------------------------------------- |
| バッチ登録・一覧・単体取得・キャンセルのエッジケース | endpoints を参照                                 | REQ-F-001, REQ-F-007 | 4 操作の振る舞いは endpoints が定義するため                 |
| エラー応答・認証に関するエッジケース                 | errors を参照                                    | REQ-F-003, REQ-F-008 | エラー形式と認証の外部仕様は errors が定義するため          |
| 索引と各ファイルの記述が食い違う                     | 各ファイルを正とする                             | REQ-F-009            | 索引は要約であり、重複した定義を持たないため                |
| 各ファイルの記述が DR と食い違う                     | DR を正とする                                    | REQ-F-003, REQ-F-007 | DR は最上位の正本であり、各ファイルは DR を再定義しないため |
| 1 つの AC が複数の REQ や複数のファイルにまたがる    | 6.2 の主担当ファイルを正とし、関連ファイルを併記 | 全 REQ               | 担当を一意にし、対応の漏れと重複を防ぐため                  |

---

## 6. Requirements Traceability

### 6.1 REQ → ファイル

| Requirement ID | 担当ファイル           | AC                             | Notes                                    |
| -------------- | ---------------------- | ------------------------------ | ---------------------------------------- |
| REQ-F-001      | endpoints, idempotency | AC-001, AC-010, AC-011, AC-025 |                                          |
| REQ-F-002      | endpoints              | AC-002                         | 独立検証は governance (REQ-C-002) と関連 |
| REQ-F-003      | errors                 | AC-003, AC-018, AC-021         |                                          |
| REQ-F-004      | errors                 | AC-003, AC-017, AC-022         |                                          |
| REQ-F-005      | endpoints              | AC-008                         |                                          |
| REQ-F-006      | errors                 | AC-012, AC-023                 | 破壊的変更の判断基準は governance と関連 |
| REQ-F-007      | endpoints, idempotency | AC-004, AC-019                 | AC-004 は全ファイルに共通                |
| REQ-F-008      | errors                 | AC-006, AC-013                 |                                          |
| REQ-F-009      | governance             | AC-009, AC-020                 |                                          |
| REQ-F-010      | governance             | AC-005, AC-024                 |                                          |
| REQ-F-011      | governance             | AC-005                         |                                          |
| REQ-F-012      | governance             | AC-007                         |                                          |
| REQ-NF-001     | governance             | AC-014                         |                                          |
| REQ-NF-002     | governance             | AC-007                         |                                          |
| REQ-C-001      | governance             | AC-015                         |                                          |
| REQ-C-002      | governance             | AC-002                         | スキーマの定義は endpoints と関連        |
| REQ-C-003      | governance             | AC-016                         |                                          |
| REQ-C-004      | governance             | AC-014                         |                                          |
| REQ-C-005      | governance             | AC-006                         | 認証の外部仕様は errors と関連           |

### 6.2 AC → ファイル

| AC ID  | REQ                   | 主担当ファイル         | 関連ファイル       |
| ------ | --------------------- | ---------------------- | ------------------ |
| AC-001 | REQ-F-001             | endpoints              | —                  |
| AC-002 | REQ-F-002, REQ-C-002  | endpoints              | governance         |
| AC-003 | REQ-F-003, REQ-F-004  | errors                 | —                  |
| AC-004 | REQ-F-007             | endpoints              | errors, governance |
| AC-005 | REQ-F-010, REQ-F-011  | governance             | —                  |
| AC-006 | REQ-F-008, REQ-C-005  | errors                 | governance         |
| AC-007 | REQ-F-012, REQ-NF-002 | governance             | —                  |
| AC-008 | REQ-F-005             | endpoints              | —                  |
| AC-009 | REQ-F-009             | governance             | —                  |
| AC-010 | REQ-F-001             | endpoints              | —                  |
| AC-011 | REQ-F-001             | endpoints              | —                  |
| AC-012 | REQ-F-006             | errors                 | governance         |
| AC-013 | REQ-F-008             | errors                 | —                  |
| AC-014 | REQ-NF-001, REQ-C-004 | governance             | —                  |
| AC-015 | REQ-C-001             | governance             | —                  |
| AC-016 | REQ-C-003             | governance             | —                  |
| AC-017 | REQ-F-004             | errors                 | —                  |
| AC-018 | REQ-F-003             | errors                 | —                  |
| AC-019 | REQ-F-007             | endpoints, idempotency | —                  |
| AC-020 | REQ-F-009             | governance             | —                  |
| AC-021 | REQ-F-003             | errors                 | —                  |
| AC-022 | REQ-F-004             | errors                 | —                  |
| AC-023 | REQ-F-006             | errors                 | —                  |
| AC-024 | REQ-F-010             | governance             | —                  |
| AC-025 | REQ-F-001             | endpoints, idempotency | —                  |

Rule ID 単位の対応 (AC をどの Rule が満たすか) は、各ファイルの Requirements Traceability に定義する。

---

## 7. Open Questions

> **Status**: INCOMPLETE
> 契約の確定条件 (照合結果に「未確認」が残らないこと) は未達である。下記 7.1 はその理由となる未解決事項で、仕様の初稿の記述は完了している。振る舞いを決めていない事項は、各ファイルの Open Questions に残る。

### 7.1 未解決事項

各ファイルの Open Questions を参照すること。全ファイルに横断する未解決事項は次のとおり。

| # | Question                                                                                                                                                                                                                                                                | Source                  | Impact                                                                                                                         |
| - | ----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- | ----------------------- | ------------------------------------------------------------------------------------------------------------------------------ |
| 1 | 兄弟 issue との照合の具体的な手順 (誰がどう照合するか) は未決定である。Owner は契約メンテナ                                                                                                                                                                             | REQ-F-009, DR-05        | governance の照合結果を確定できない。契約の確定までに決める                                                                    |
| 2 | #6 との照合が「未確認」である。対象は認証の資格情報の形式 (Bearer は候補)、403 の発生条件、CORS プリフライトの外部契約、キー空間の共有と認証設計の整合 (governance G-18)                                                                                                | REQ-F-008, DR-03, DR-06 | 確定した保証として扱えない。確定条件を満たすまで、暫定の扱いを維持する                                                         |
| 3 | #4・#5・#7 との照合が「未確認」である。対象は成功の記録の保持 (サーバーで成功が確定した時点 (UD-042) から最低 24 時間、再起動後も保持。governance G-03)、同じキーの排他性と重複登録の防止 (G-16)、登録と成功の記録の原子性と回復、回復できない未確定キーの安全性 (G-17) | REQ-F-007, DR-05, DR-06 | 永続化に依存する保証を確定できない。#7 完了前に保証を満たせない可能性がある。回復の完了と期限は保証しない (endpoints 7 章 #15) |
| 4 | 「Spec 生成時の既定値」(各ファイルで「既定値・レビュー対象」と明記したもの) のユーザーレビューが済んでいない                                                                                                                                                            | 各ファイル              | 値が変わると、該当するファイルの Rule と Edge Case に影響する                                                                  |

### 7.2 requirements.md の Open Questions の解決先

requirements.md の「Owner: Specifications」の 25 件と、設計で追加した 1 件 (#26) を示す。
Rule ID は各ファイルの Requirements Traceability と Decision Rules で確認する。

状態の凡例: 解決 = 仕様として確定、既定値 = 具体値を既定値として記載しレビュー対象、暫定 = 候補として記載、impl = 実装段階に委譲。

| #  | Question                                                                                                  | 解決先ファイル                 | 根拠                                                                                                                                                                                                                                            | 状態                                                                                                          |
| -- | --------------------------------------------------------------------------------------------------------- | ------------------------------ | ----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- | ------------------------------------------------------------------------------------------------------------- |
| 1  | OpenAPI 3.1.x のパッチバージョン                                                                          | governance                     | REQ-C-001                                                                                                                                                                                                                                       | 既定値 (3.1.1) (既定値・レビュー対象)                                                                         |
| 2  | JSON Schema のファイル構成と参照方法                                                                      | endpoints                      | DD-EP-10, governance DD-GV-08                                                                                                                                                                                                                   | 解決 (独立した成果物、相対 `$ref`)                                                                            |
| 3  | `notifications` 配列の構造と検証制約                                                                      | endpoints                      | R-EP-C-018                                                                                                                                                                                                                                      | 解決。maxItems・文字列長は既定値 (既定値・レビュー対象)                                                       |
| 4  | HTTP エンドポイントとレスポンスの詳細 (パス、メソッド、ステータス)                                        | endpoints, errors              | DD-EP-01, R-ER-C-001〜R-ER-C-008、R-ER-C-010〜R-ER-C-012、R-ER-C-014、R-ER-C-015                                                                                                                                                                | 解決 (操作は endpoints、エラーのステータスは errors)                                                          |
| 5  | 一覧取得の絞り込み・並び順・ページング                                                                    | endpoints                      | DD-EP-09                                                                                                                                                                                                                                        | 解決 (`state` 絞り込みのみ、ページングなし)                                                                   |
| 6  | 通知 ID の採番と、リクエストでの ID の扱い                                                                | endpoints                      | DD-EP-03, DD-EP-07                                                                                                                                                                                                                              | 解決 (サーバー採番、不透明な文字列)                                                                           |
| 7  | 発火時刻の表現と、繰り返し通知                                                                            | endpoints                      | R-EP-C-014, R-EP-C-016                                                                                                                                                                                                                          | 解決 (オフセット付き日時、繰り返しは扱わない)                                                                 |
| 8  | `type` の URI の方式と値、対応表の置き場所                                                                | errors                         | DD-ER-03, DD-ER-12                                                                                                                                                                                                                              | 解決 (URN 方式、エラーカタログ 1 か所)                                                                        |
| 9  | `status`・`type`・`code` 以外の必須メンバー                                                               | errors                         | DR-01                                                                                                                                                                                                                                           | 解決 (追加の必須メンバーなし。DD-ER-01)                                                                       |
| 10 | エラー識別子の命名規則と、各ケースの識別子・ステータスコード                                              | errors                         | DD-ER-02                                                                                                                                                                                                                                        | 解決 (`<category>.<name>`)                                                                                    |
| 11 | エラー分類の名前と一覧、未知の識別子からの分類の判別                                                      | errors                         | DD-ER-02                                                                                                                                                                                                                                        | 解決 (接頭辞が分類を表す)                                                                                     |
| 12 | 対処方針と、エラー識別子を得られない場合の対処                                                            | errors                         | R-ER-C-034〜R-ER-C-042、R-ER-I-003, DR-04                                                                                                                                                                                                       | 解決                                                                                                          |
| 13 | 各操作の再送時に観測できる振る舞い                                                                        | idempotency, errors, endpoints | specifications-idempotency.md R-ID-C-101、R-ID-C-201〜R-ID-C-206、R-ID-C-301〜R-ID-C-306、R-ID-C-401、R-ID-C-501、R-ID-I-101〜R-ID-I-105、R-ID-I-401、R-ID-I-402、R-ID-I-501、R-ID-I-502、DR-06、R-ER-C-009、R-ER-C-012、R-ER-C-013、R-ER-C-040 | 解決 (失敗・結果未確定の後の再送を含む)。照合は 7.1 #3 が未確認                                               |
| 14 | キャンセルの結果の意味                                                                                    | endpoints                      | DD-EP-04, R-EP-C-025                                                                                                                                                                                                                            | 解決                                                                                                          |
| 15 | 認証の外部仕様の内容                                                                                      | errors                         | R-ER-C-051〜R-ER-C-057、R-ER-C-060、R-ER-I-004                                                                                                                                                                                                  | 暫定 (Bearer は候補)。#6 照合は未確認 (7.1 #2)                                                                |
| 16 | 整合確認の記録の形式                                                                                      | governance                     | DD-GV-03, DR-05                                                                                                                                                                                                                                 | 解決 (保証 × 照合対象の照合表)                                                                                |
| 17 | `Retry-After` を使うか、使う場合の意味                                                                    | errors                         | DD-ER-09                                                                                                                                                                                                                                        | 既定値 (503 のみ任意) (既定値・レビュー対象)                                                                  |
| 18 | 本文サイズの上限、Content-Type、文字コード                                                                | endpoints, errors              | 3.5、R-EP-C-020、R-ER-C-005、R-ER-C-006                                                                                                                                                                                                         | 既定値 (上限値) (既定値・レビュー対象)。413・415 は errors。Content-Encoding は identity だけ (DR-06 決定 11) |
| 19 | スキーマバリデータと linter の選定                                                                        | governance                     | DD-GV-10                                                                                                                                                                                                                                        | impl (仕様では固定しない)                                                                                     |
| 20 | API メジャーバージョンの識別方法                                                                          | governance                     | DD-GV-02                                                                                                                                                                                                                                        | 解決 (URL パス)                                                                                               |
| 21 | 契約バージョンの管理方法                                                                                  | governance                     | DD-GV-01                                                                                                                                                                                                                                        | 解決 (OpenAPI の `info.version`、SemVer)                                                                      |
| 22 | 破壊的変更と非破壊的変更の判断基準                                                                        | governance                     | DD-GV-04, DR-04                                                                                                                                                                                                                                 | 既定値 (判断基準表) (既定値・レビュー対象)                                                                    |
| 23 | 旧バージョンの非推奨期間                                                                                  | governance                     | DD-GV-05                                                                                                                                                                                                                                        | 既定値 (既定値・レビュー対象)                                                                                 |
| 24 | バージョン間の互換性確認方法                                                                              | governance                     | DD-GV-07                                                                                                                                                                                                                                        | 既定値 (既定値・レビュー対象)                                                                                 |
| 25 | 認証必須の宣言の表現                                                                                      | errors                         | R-ER-C-051                                                                                                                                                                                                                                      | 解決 (`securitySchemes` と全操作の `security`)。方式は暫定                                                    |
| 26 | 認証と検証など、複数のエラーが同時に成立したときの外部応答の順序 (requirements.md に項目なし。設計で追加) | errors                         | DD-ER-05, R-ER-C-001〜R-ER-C-008、R-ER-C-010〜R-ER-C-012、R-ER-C-014〜R-ER-C-018、R-ER-I-001                                                                                                                                                    | 解決                                                                                                          |

Owner が契約メンテナの 2 件は次のとおり。

| Question                            | 状態                                                                   |
| ----------------------------------- | ---------------------------------------------------------------------- |
| 兄弟 issue との照合の具体的な手順   | 未解決 (7.1 #1)                                                        |
| 通知の所有者ごとの分離 (認可の単位) | 解決 (errors DD-ER-11: 分離しない。403 の発生条件の詳細は #6 が決める) |

---

## 8. Change History

| Date       | Version | Description                                                                                                                                                                                                                                                                                                                                                                                                               |
| ---------- | ------- | ------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| 2026-11-14 | 1.0.0   | Initial specification                                                                                                                                                                                                                                                                                                                                                                                                     |
| 2026-11-14 | 1.1.0   | DR-06 と requirements.md v1.5.1 を反映: 2.1 と関連 DR の表に DR-06 を追加。分割ファイルに specifications-idempotency.md (再送と冪等性の保証の正本) を追加し、範囲の表、4 章、機能分解 (U6)、6 章、7.2 #13 の解決先を更新。7.1 #2・#3 に governance G-17・G-18 などの照合対象を追加。7.2 #18 に Content-Encoding を追加。関連 DR の表の DR-01〜05 の Phase を正本に合わせた。7 章の記述完了の範囲と 7.2 の件数を正確にした |
| 2026-11-14 | 1.1.1   | 3.3 共通の用語の定義を `universal-dictionary.md` v1.0.0 に移し、UD-ID の対応表に置き換え (定義の内容は変えない)。1.x のファイル一覧の旧用語 ID を UD-ID の参照に直し、7.1 #3 の保持期間の起点をサーバーで成功が確定した時点 (UD-042) と明記                                                                                                                                                                               |
| 2026-11-14 | 1.1.2   | based-on を requirements.md v1.5.3 に更新。分割ファイルの数を 4 に直し、2.2 の用語の正本を `universal-dictionary.md` に直す                                                                                                                                                                                                                                                                                               |
| 2026-11-14 | 1.1.3   | `specifications-endpoints.md` v2.0.0 に合わせ、Rule ID の形式 (分割ファイルの範囲、4 章) と 7 章の参照を新 ID に更新。規則は変えない。errors・governance・idempotency の ID の振り直し (各 v2.0.0) に合わせ、Rule ID の形式と 7.2 の参照を更新。4.1 に規則の分類の基準 (全ファイル共通) を追加                                                                                                                            |
| 2026-11-15 | 1.1.4   | `specifications-errors.md` v3.1.0 (DR-10 の反映) に合わせ、7.2 #15 の根拠に R-ER-C-060 (401 の応答本文で資格情報の状態を区別しない) を追加。状態 (暫定) は変えない                                                                                                                                                                                                                                                        |
