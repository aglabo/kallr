---
title: "Design Specification: Notification API Contract — Endpoints and Observable Guarantees"
based-on: requirements.md v1.5.3
status: Draft
version: 1.1.2
created: "2026-11-14"
---

> **Normative Statement**
> 本ドキュメントは拘束力のある要件を定義する。
> 実装は本ドキュメントに適合しなければならない (MUST)。
> RFC 2119 キーワードは本ドキュメントにのみ適用する。
> 本ドキュメント内では、SHALL と MUST、SHALL NOT と MUST NOT は同義であり、拘束力に差はない。
>
> Part of split specification. See `specifications-index.md` for full scope.

## 1. Overview

### 1.1 Purpose

本ドキュメントは、次の 4 つを定義する。

- 通知 REST API の 4 操作 (バッチ登録・一覧取得・単体取得・キャンセル)
- 通知のデータ形状と状態の集合
- 登録リクエストの検証制約
- 外部から観測できる保証 (再送時の振る舞い、キャンセルの結果、バッチの原子性、入力の拒否)

担当する要件は REQ-F-001、REQ-F-002、REQ-F-005、REQ-F-007 とする。

### 1.2 Scope

本書は、振る舞いの規則と分類の意味を定義する。
実装の詳細は対象外とする。

本ファイルが定義しないもの:

- バッチ登録の再送と冪等性の保証。正本は `specifications-idempotency.md` とする
- エラー code・type・HTTP ステータス・分類・対処方針の表 (`specifications-errors.md` が唯一の場所である。本ファイルは code を参照するだけとする)
- 認証の外部仕様の詳細 (`specifications-errors.md`)
- 契約バージョン管理、破壊的変更、契約検証、整合確認の記録 (`specifications-governance.md`)
- 内部の実現方法 (3.11 と R-EP-091 を参照)

---

## 2. Design Principles

### 2.1 Classification Philosophy

- 本仕様は、クライアントがリクエストとレスポンスを通して観測できる事実だけを定義する (DR-03)。
  サーバーが保証をどう実現するかは定義しない。
- 正本の優先順位は、decision-records.md (DR-01〜06) を最上位とし、次に確認済みの設計条件、API の決定、関数の決定の順とする。
  DR が決めた事項は、再定義せず参照する。
- 結果が複数の形で観測され得る箇所 (キャンセルと配信の競合、バッチの成功・`4xx` の失敗・結果未確定) は、
  観測結果が排他的な区分になるように定義する。
- 確定していない事項 (Bearer 認証、兄弟 issue との照合) は、確定した保証として書かない。
  候補または未確認と明記し、Open Questions に残す。

### 2.2 Design Assumptions

- 契約の利用者は PWA であり、通信は JSON over HTTP のみとする。
- 全エンドポイントは認証を必要とする。認証の外部仕様は `specifications-errors.md` が定義する。
- 通知は所有者ごとに分離せず、所有者の違いによるアクセス条件の差を設けない (`specifications-errors.md` DD-ER-11)。
  操作を許可されていない場合の 403 (`auth.forbidden`) は、所有者の違いとは別の条件で返る (R-EP-015)。
- 通知 ID の採番は、サーバーが行う。採番の内部方式は本契約の対象外である (DD-EP-03)。
- 繰り返し通知は v1 で扱わない。1 件の通知は、1 回の発火時刻だけを持つ。
- 「Spec 生成時の既定値」は、具体値で書き、「(既定値・レビュー対象)」を付ける。
  これらはレビューで変更され得る値であり、DR や確認済みの決定ではない。

### 2.3 External Design Summary

> **Source**: Derived from the external design dialogue and user-confirmed design direction.

#### Feature Decomposition

| Unit                     | Responsibility                                                      | REQ Coverage         |
| ------------------------ | ------------------------------------------------------------------- | -------------------- |
| U1 Endpoints             | 4 操作のパス・メソッド・成功ステータス・リクエスト/レスポンスの形状 | REQ-F-001            |
| U2 Data shape            | 通知のデータ形状、状態の集合、外部から観測できる状態遷移規則        | REQ-F-005, REQ-F-007 |
| U3 Request schema        | 登録リクエストと登録済み通知のスキーマ、検証制約、OpenAPI との接続  | REQ-F-002, REQ-F-005 |
| U6 Resend and guarantees | 再送時の振る舞い、キャンセルの結果、バッチの原子性、入力の拒否条件  | REQ-F-001, REQ-F-007 |

#### Unit Interaction Map

```text
+--------------+     +--------------+     +--------------+
| U1 Endpoints | --> | U2 Data shape| --> | U3 Schema    |
+--------------+     +--------------+     +--------------+
      |
      v
+--------------------------+
| U6 Resend and guarantees |
+--------------------------+
      |
      v
(error codes: specifications-errors.md)
```

U1 は U2 と U3 を利用する。U6 は U1 の各操作に対する保証を与える。
エラー code の定義は、本ファイルの外 (`specifications-errors.md`) にある。

#### Data Flow Diagram

```text
[Request] --> [Authentication] --> [Routing/Method/Authorization]
                                          |
                                          v
              [Media type/Content-Encoding/Body size] --> [Idempotency-Key header]
                                                                  |
                                                                  v
                                   [success-confirmed key + same body?] --yes--> [201 (replay)]
                                                                  | no
                                                                  v
              [Input validation] --> [Resource state] --> [Response]
                      |                      |
                      v                      v
             [notifications schema]   [State transition rules]
```

上の図は、複数のエラー条件が同時に成立したときに返す外部応答の優先順位を、上から高い順に示す。
サーバー内部の処理順は表さない。
成功結果の再現 (`specifications-errors.md` R-ER-064) は、先行の検査を通過した送信だけに当てはまる。
先行の検査は、`specifications-errors.md` 4.1 の Step 1〜8 とする。
対象は、認証、ルーティング・メソッド・認可、メディアタイプ・Content-Encoding・本文サイズ、Idempotency-Key ヘッダーの形式の検査とする。
この再現は、入力内容の検証より先に返す。
優先順位の正本は `specifications-errors.md` 4.1 である (R-EP-001)。

### 2.4 Non-Goals

> **Derivation**: All items below originate from REQUIREMENTS Section "Out of Scope".

- 登録処理の原子性の実現方法、冪等性・重複排除の実現方法、バリデーションの判定アルゴリズムの定義 ← REQ: Out of Scope (#4)
- 照会・キャンセルの判定アルゴリズム、状態遷移の内部の実現方法の定義 ← REQ: Out of Scope (#5)
- loopback、CORS、Origin チェック、ペアリング、認証メカニズムの内部実装の定義 ← REQ: Out of Scope (#6)
- SQLite 永続化の定義 ← REQ: Out of Scope (#7)
- e2e テストの定義 ← REQ: Out of Scope (#8)
- ペアリングエンドポイントの定義 ← REQ: Out of Scope
- 具体的な再試行のアルゴリズム (指数バックオフ、ジッター、最大試行回数) の定義 ← REQ: Out of Scope
- 契約検証の CI 統合 ← REQ: Out of Scope

### 2.5 Behavioral Design Decisions

| ID       | Decision                                                                                                                                                                                                              | Rationale                                                                                                                                                        | Affected Rules                         | Status |
| -------- | --------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- | ---------------------------------------------------------------------------------------------------------------------------------------------------------------- | -------------------------------------- | ------ |
| DD-EP-01 | 操作のパスは `/v1/notifications` 系とし、API メジャーバージョンを URL パスの `/v1` で識別する                                                                                                                         | クライアントが利用するバージョンを、リクエストの URL だけで識別できる                                                                                            | R-EP-010〜R-EP-014                     | Active |
| DD-EP-02 | バッチ登録・一覧取得のレスポンスは、通知の配列を `notifications` メンバーに持つ。単体取得・キャンセルは通知そのものを返す                                                                                             | リクエストと同じメンバー名にそろえ、DR-02 の「通知ごとの結果」に登録済み通知の形状 (ID と状態を含む) を使う                                                      | R-EP-011, R-EP-012                     | Active |
| DD-EP-03 | 登録リクエストの要素は、未知のメンバーを拒否する。クライアントは ID を送れない                                                                                                                                        | ID はサーバーが採番する。送られた ID が無視されると、クライアントが指定が効いたと誤解する                                                                        | R-EP-030, R-EP-041                     | Active |
| DD-EP-04 | キャンセルは `scheduled` の通知だけを受け付ける。ほかの状態は、冪等な成功にせずエラーにする                                                                                                                           | #5 の下書きと整合し、再送後の状態をクライアントが GET で確認できる                                                                                               | R-EP-060〜R-EP-062                     | Active |
| DD-EP-05 | `Idempotency-Key` はバッチ登録で必須とする。キャンセルと GET は対象外とする                                                                                                                                           | 二重登録の防止が設計目標であり、キャンセルは状態の確認で再送を判断できる                                                                                         | R-EP-070〜R-EP-079, R-EP-084, R-EP-085 | Active |
| DD-EP-06 | 複数のエラー条件が同時に成立したときの外部応答の優先順位は、`specifications-errors.md` 4.1 を唯一の場所とし、本ファイルでは再定義しない。例外は、成功結果の早期応答 (`specifications-errors.md` R-ER-064) だけとする  | 優先順位を 2 か所に書くと食い違う。本ファイルは参照だけにする (DR-06 決定 6)                                                                                     | R-EP-001                               | Active |
| DD-EP-07 | 形式が不正な通知 ID は、存在しない ID と同じ扱いにする。優先順位も「リソース状態」の段で、存在しない ID と同じとする                                                                                                  | ID は不透明であり、クライアントが形式を判断できない。存在の有無と形式の不正を、応答でも優先順位でも区別すると内部を漏らす                                        | R-EP-013, R-EP-014, R-EP-090           | Active |
| DD-EP-08 | 状態の集合は `scheduled`・`dispatched`・`missed`・`cancelled` の 4 つとする。`dispatched` は OS への引き渡しだけを意味し、画面表示とユーザーの確認を含めない。`missed` を v1 から含める                               | 後から状態を加えると既存クライアントの解釈が変わり、破壊的変更になる。OS への引き渡しと表示・確認を区別しないと、Keneek が観測できない事実を状態が主張してしまう | R-EP-050, R-EP-051                     | Active |
| DD-EP-09 | 一覧取得の絞り込みは省略可能な `state` クエリだけとし、ページングを設けない                                                                                                                                           | 端末内の利用で件数は少ない。省略可能なクエリは後から追加しても後方互換である                                                                                     | R-EP-020〜R-EP-022                     | Active |
| DD-EP-10 | `notifications.schema.json` の中で、登録リクエストと登録済み通知を `$defs` で区別する                                                                                                                                 | 独立して検証できるスキーマを 1 ファイルに保ちつつ、リクエストとレスポンスの形状を取り違えない                                                                    | R-EP-041                               | Active |
| DD-EP-11 | `Idempotency-Key` を成功結果に結び付けるのは、登録の成功 (201) が確定したときだけとする。5xx と応答の喪失は、登録されなかったことの確定とみなさない。詳細の正本は `specifications-idempotency.md` (IP-1、IP-3) とする | 5xx や応答の喪失の後に新規登録として処理すると、二重登録が起き得る (DR-06 決定 9)                                                                                | R-EP-071〜R-EP-079, R-EP-084           | Active |
| DD-EP-12 | 成功が確定したキーに同じ本文で再送されたときは、初回の 201 と本文の写しを返す。詳細の正本は `specifications-idempotency.md` R-ID-202 とする                                                                           | 再送の応答を、時刻に依存し得る入力内容の検証と、通知の現在の状態から切り離す (DR-06 決定 6)                                                                      | R-EP-071                               | Active |

> **Note**: Decisions listed here derive from REQUIREMENTS Design Decisions and the confirmed API decisions.
> If promoting to formal Decision Record, use `/deckrd dr --add`.

**Status Values:**

- `Active` — Currently in effect within this specification
- `Promoted → DR-xx` — Elevated to formal Decision Record (see Section 2.6)

### 2.6 Related Decision Records

> **Reference**: This section lists formal DRs that affect this specification.
> DRs are maintained in `decision-records.md` and are authoritative.

| DR-ID | Title                                                                                       | Phase         | Impact on This Spec                                                                                                                                                                                                                 |
| ----- | ------------------------------------------------------------------------------------------- | ------------- | ----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| DR-01 | 共通エラー形式に RFC 9457 を採用し、`type` と `code` を 1 対 1 で対応させる                 | review-harden | 本ファイルのエラーレスポンスは `application/problem+json` とする。code の定義は `specifications-errors.md` に委ねる                                                                                                                 |
| DR-02 | バッチ登録のレスポンスは all-or-nothing の形状とし、部分成功を表す形状を持たない            | review-harden | R-EP-011 の成功・失敗の 2 形状と、入力順の 1 対 1 対応を決める                                                                                                                                                                      |
| DR-03 | 外部から観測できる振る舞いの保証を API 契約に含め、内部の実現方法は兄弟 issue に委ねる      | review-harden | 再送、キャンセル、原子性、入力拒否を本ファイルで定義し、内部の実現方法を定義しない (R-EP-091)                                                                                                                                       |
| DR-04 | エラーの分類とクライアントの対処を分離し、エラー識別子の追加を無条件に後方互換としない      | review-harden | 対処方針は code ごとに `specifications-errors.md` で定める。本ファイルは再送の結果だけを定義する                                                                                                                                    |
| DR-05 | 契約確定前の兄弟 issue との整合確認は、保証ごとの照合結果を記録として Specifications に残す | review-harden | 本ファイルの保証のうち照合が済んでいないものは、確定した保証として扱わない (7 章)                                                                                                                                                   |
| DR-06 | バッチ登録の冪等性を、安全性・応答の一貫性・回復可能性に分けて外部契約にする                | spec          | 3.8.1 のキーの状態と応答、クライアントから見た論理操作の確定条件、成功結果の再現 (R-EP-071)、409 の条件 (R-EP-072)、処理中の競合の 503 (R-EP-077)、Content-Encoding (R-EP-043)、回復 (R-EP-084)、同じ本文の判定 (R-EP-085) を決める |

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

- Input Type: 認証済みクライアントからの、`/v1` 配下への HTTP リクエスト。
  本文を持つ操作 (バッチ登録) のメディアタイプは `application/json`、文字コードは UTF-8、Content-Encoding は identity だけとする (R-EP-043)
- Assumptions:
  - 認証の成否は、リクエストの資格情報で決まる。認証の外部仕様は `specifications-errors.md` が定義する
  - HTTP メッセージとして受理できないプロトコルレベルのエラーは、本ファイルの対象外とする (`specifications-errors.md` R-ER-015)
  - CORS プリフライト (OPTIONS) は、認証優先規則の例外として別に定義する (`specifications-errors.md` 4.10)。本ファイルの 4 操作には含めない

### 3.2 Output Semantics

- Output Meaning: 成功レスポンスは、操作後の通知、または通知の配列を表す。失敗レスポンスは、`application/problem+json` の単一のエラーを表す
- Possible Outcomes:
  - 成功: 通知 (または通知の配列) を返す
  - 失敗: 共通エラー形式の単一のエラーを返す (code は `specifications-errors.md` を参照)
  - 結果未確定: `5xx` (503 を含む) の場合と、レスポンスを受け取れない場合。`4xx` の失敗レスポンスとは区別し、クライアントが結果を確定できない場合として扱う (R-EP-082)

### 3.3 Operations

すべての操作は認証を必要とする。成功時のステータスと、リクエスト・レスポンスの形状は次のとおりとする。

| Operation  | Method | Path                            | 成功ステータス | リクエスト                                                           | 成功レスポンス                                                       |
| ---------- | ------ | ------------------------------- | -------------- | -------------------------------------------------------------------- | -------------------------------------------------------------------- |
| バッチ登録 | POST   | `/v1/notifications`             | 201            | `Idempotency-Key` ヘッダー (必須) と、`notifications` 配列を持つ本文 | `notifications` 配列。入力と同じ順序・同じ件数で、登録済み通知を持つ |
| 一覧取得   | GET    | `/v1/notifications`             | 200            | 省略可能な `state` クエリ (複数指定可)                               | `notifications` 配列 (登録済み通知。0 件のとき空配列)                |
| 単体取得   | GET    | `/v1/notifications/{id}`        | 200            | パスの通知 ID                                                        | 登録済み通知 1 件                                                    |
| キャンセル | POST   | `/v1/notifications/{id}/cancel` | 200            | パスの通知 ID。本文なし                                              | キャンセル後の登録済み通知 (状態は `cancelled`)                      |

### 3.4 Notification Data Shape

**登録リクエストの要素** (クライアントが送る):

| Member   | 必須 | 意味                                                  |
| -------- | ---- | ----------------------------------------------------- |
| `title`  | はい | 通知の見出し                                          |
| `body`   | はい | 通知の本文                                            |
| `fireAt` | はい | 発火時刻。RFC 3339 の日時で、UTC オフセットを必ず含む |
| `url`    | はい | 通知から遷移する先の URL                              |

**登録済み通知** (サーバーが返す):

| Member        | 必須                                  | 意味                                                               |
| ------------- | ------------------------------------- | ------------------------------------------------------------------ |
| `id`          | はい                                  | サーバーが採番した、不透明な文字列。クライアントは形式を解釈しない |
| `title`       | はい                                  | 登録時の値                                                         |
| `body`        | はい                                  | 登録時の値                                                         |
| `fireAt`      | はい                                  | 発火時刻。RFC 3339 の日時で、UTC オフセットを含む                  |
| `url`         | はい                                  | 登録時の値                                                         |
| `state`       | はい                                  | 状態の集合 (3.6) のいずれか 1 つ                                   |
| `createdAt`   | はい                                  | 登録時刻。RFC 3339 の日時で、UTC オフセットを含む                  |
| `cancelledAt` | `state` が `cancelled` のときだけ持つ | キャンセルが成功した時刻。RFC 3339 の日時で、UTC オフセットを含む  |

### 3.5 Schema Artifact and Validation Constraints

- 登録リクエストの `notifications` 配列は、独立したスキーマ `notifications.schema.json` (JSON Schema Draft 2020-12) で定義する。
  このスキーマは、OpenAPI ドキュメントを使わずに単独で検証できる。
- `notifications.schema.json` は、`$defs` の中で次の 2 つを区別して定義する (DD-EP-10)。
  - 登録リクエスト: `notifications` 配列とその要素
  - 登録済み通知: レスポンスで返す通知の形状
- OpenAPI は、バッチ登録の requestBody で登録リクエストを、レスポンスで登録済み通知を、相対 `$ref` で参照する。
  定義を OpenAPI 側に複製しない。
- OpenAPI のバージョンは 3.1.1 とする (既定値・レビュー対象)。

検証制約 (登録リクエスト):

| 対象                       | 制約                                                                                                              |
| -------------------------- | ----------------------------------------------------------------------------------------------------------------- |
| 本文                       | `notifications` を必須メンバーとして持つオブジェクト。ほかのメンバーは拒否する                                    |
| `notifications`            | 配列。要素数は 1 以上 100 以下 (最大 100 件は既定値・レビュー対象)                                                |
| 要素                       | オブジェクト。`title`・`body`・`fireAt`・`url` を必須とし、未知のメンバーは拒否する                               |
| `title`                    | 文字列。1 文字以上 100 文字以下 (最大 100 文字は既定値・レビュー対象)                                             |
| `body`                     | 文字列。0 文字以上 1000 文字以下 (最大 1000 文字は既定値・レビュー対象)                                           |
| `fireAt`                   | 文字列。RFC 3339 の日時の形式で、UTC オフセットを含む                                                             |
| `url`                      | 文字列。URI の形式。最大 2048 文字 (既定値・レビュー対象)                                                         |
| 本文サイズ                 | 1048576 バイト (1 MiB) 以下 (既定値・レビュー対象)                                                                |
| Content-Encoding           | identity だけ。ヘッダーが無い場合は identity とみなす。それ以外は 415 `request.unsupported_media_type` (R-EP-043) |
| `Idempotency-Key` ヘッダー | 1 文字以上 255 文字以下の、印字可能な ASCII 文字列 (既定値・レビュー対象)                                         |
| 通知 ID (パス)             | 不透明な文字列。最大 64 文字で、使える文字は英数字・`-`・`_` (既定値・レビュー対象)                               |
| `state` クエリ             | 3.6 の 4 つの状態名のいずれか。複数回指定できる                                                                   |

本表の制約に違反したときの code は、制約の種類で分ける (3.10)。

- 本文の JSON の構造と値の制約 (要素数、必須メンバー、未知のメンバー、型・長さ・形式、本文に含めた通知 ID) と、`state` クエリ: `request.invalid`
- 本文サイズ: `request.payload_too_large`。Content-Encoding: `request.unsupported_media_type`
- `Idempotency-Key` ヘッダー: `idempotency.key_missing` または `idempotency.key_invalid`
- パスで指定した通知 ID (単体取得・キャンセル) が存在しない、または形式が不正: `notification.not_found`

バッチ登録の本文に通知 ID を含めることは送信の禁止 (R-EP-030) であり、`request.invalid` で拒否する。パスで既存の通知を指定して見つからない場合とは区別する。

### 3.6 States and Transition Rules

状態の集合 (DD-EP-08):

| State        | 意味                                                                                                        | 終端   |
| ------------ | ----------------------------------------------------------------------------------------------------------- | ------ |
| `scheduled`  | 登録済みで、発火時刻を待っている                                                                            | いいえ |
| `dispatched` | 発火時刻に、Keneek が OS へ通知を引き渡した。画面への表示、およびユーザーの確認は、この状態の意味に含めない | はい   |
| `missed`     | 発火時刻に、OS へ通知を引き渡せなかった                                                                     | はい   |
| `cancelled`  | キャンセルが成功した。以後、OS へ引き渡されない                                                             | はい   |

外部から観測できる状態遷移規則:

| 現在の状態   | 操作 / 契機                | 結果                                                    |
| ------------ | -------------------------- | ------------------------------------------------------- |
| (なし)       | バッチ登録の成功           | 登録済み通知の状態は `scheduled`                        |
| `scheduled`  | キャンセル                 | 成功。状態は `cancelled`                                |
| `scheduled`  | 発火時刻での引き渡しに成功 | 状態は `dispatched`                                     |
| `scheduled`  | 発火時刻での引き渡しに失敗 | 状態は `missed`                                         |
| `dispatched` | キャンセル                 | 拒否 (`notification.not_cancellable`)。状態は変わらない |
| `missed`     | キャンセル                 | 拒否 (`notification.not_cancellable`)。状態は変わらない |
| `cancelled`  | キャンセル                 | 拒否 (`notification.not_cancellable`)。状態は変わらない |
| 終端状態     | (任意の遷移)               | 別の状態へは遷移しない                                  |

引き渡しの検出や、状態の保持の内部の実現方法は定義しない。

### 3.7 Cancel Result Semantics

- キャンセルの成功は、「その通知が以後 OS へ引き渡されない」ことを意味する。
- キャンセルが成功したレスポンスは、状態が `cancelled` で `cancelledAt` を持つ通知を返す。
- キャンセルと発火時刻での引き渡しが競合したとき、観測される結果は次のどちらか一方に確定する。両方が成立することはない。
  - キャンセルが成功する (以後、引き渡されない)
  - キャンセルが拒否される (`notification.not_cancellable`)。通知は `dispatched` または `missed` になる

### 3.8 Resend Behavior

| 操作       | 再送時の振る舞い                                                                                                                                                                 |
| ---------- | -------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| バッチ登録 | `Idempotency-Key` が必須。再送時の振る舞いの正本は `specifications-idempotency.md` とする (キーの状態と応答は R-ID-201、成功結果の再現は R-ID-202、再送の条件は R-ID-302)        |
| 一覧取得   | 安全かつ冪等。再送してもサーバーの状態は変わらない                                                                                                                               |
| 単体取得   | 安全かつ冪等。再送してもサーバーの状態は変わらない                                                                                                                               |
| キャンセル | `Idempotency-Key` の対象外。成功後の再送は `notification.not_cancellable` となる。レスポンスを受け取れずに再送して拒否された場合、クライアントは単体取得で状態を確認して判断する |

#### 3.8.1 Idempotency-Key States (バッチ登録)

本節の正本は `specifications-idempotency.md` とする。本節には、既存の参照を保つための対応だけを置く。

- キーの状態と応答: R-ID-201 (表)、R-ID-202〜R-ID-206
- 重複登録の防止の範囲と、記録の保持・失効・残留リスク: R-ID-101〜R-ID-106
- クライアントの応答の分類、再送の条件、結果の確定、登録し直し: R-ID-301〜R-ID-306
- 停止と回复: R-ID-401〜R-ID-403
- 拒否の副作用、キー空間と認証 (#6) の境界: R-ID-501〜R-ID-503

保証の境界は `specifications-idempotency.md` 2.1 (IP-0) のとおりとする。

### 3.9 Batch Atomicity

バッチ登録の結果は、成功・`4xx` の失敗・結果未確定のいずれか 1 つとして観測される。
クライアントが「その送信は登録していない」と判断できる `4xx` は、API が生成した、`code` を持つ problem 形式の応答に限る。
プロキシなどが返した problem 形式でない `4xx` は、結果未確定として扱う (`specifications-errors.md` R-ER-044、DR-06 決定 9)。

| 観測される結果            | 保証                                                                                                                                                                                                                                                                                                   |
| ------------------------- | ------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------ |
| 成功                      | リクエストに含まれる通知が、すべて登録されている。レスポンスは入力の各要素と 1 対 1・同順で対応する                                                                                                                                                                                                    |
| 失敗 (API が返した `4xx`) | 単一のエラーを返す。そのリクエストによる新規登録は 1 件も残っていない。その送信では登録されなかったことを示す。論理操作 (UD-031) の登録なしの確定 (UD-043) は、`specifications-idempotency.md` R-ID-303 の条件による                                                                                   |
| 失敗 (`5xx`)              | 単一のエラーを返す。そのリクエストの通知は、すべて登録されているか 1 件も登録されていないかのどちらかであり、一部の要素だけが登録された状態は残らない。どちらであるかはクライアントにとって確定しない (結果未確定)。再送の条件と結果の扱いは `specifications-idempotency.md` R-ID-301〜R-ID-304 に従う |
| 結果未確定 (応答なし)     | レスポンスを受け取れない (応答の喪失、タイムアウト)。API が返した `4xx` の失敗と区別し、結果が確定しない場合として扱う。再送の条件と結果の扱いは R-ID-301〜R-ID-304 に従う                                                                                                                             |

保証は、そのリクエストによる新規登録だけに及ぶ。既存の通知は、バッチ登録の成功・失敗のいずれでも削除されず、変更されない。

### 3.10 Input Rejection Conditions

入力を拒否する条件と、使う code を定義する。code の値・type・ステータス・対処方針は `specifications-errors.md` が定義する。
成功が確定したキーへの同じ本文の再送で 201 を再現すること (R-EP-071、`specifications-errors.md` R-ER-064) は拒否ではないため、本表に含めない。

| 条件                                                                                                                                                                                                                                                             | 使う code                        |
| ---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- | -------------------------------- |
| 登録リクエストの本文が、JSON の構造と値の検証制約に違反する (空配列、件数の上限超過、必須メンバーの欠落、未知のメンバー、型・長さ・形式の不正、送信が禁止された通知 ID を本文に含める)。本文サイズ、Content-Encoding、`Idempotency-Key` ヘッダーの違反は含まない | `request.invalid`                |
| 本文が JSON として解釈できない                                                                                                                                                                                                                                   | `request.invalid`                |
| `state` クエリに 4 つの状態名以外の値がある                                                                                                                                                                                                                      | `request.invalid`                |
| `Idempotency-Key` が欠落している                                                                                                                                                                                                                                 | `idempotency.key_missing`        |
| `Idempotency-Key` の形式が不正である                                                                                                                                                                                                                             | `idempotency.key_invalid`        |
| 成功が確定したキーに、別の本文が送られた (`specifications-idempotency.md` R-ID-203)                                                                                                                                                                              | `idempotency.key_conflict`       |
| 処理中または回復待ちのキーに送られた。本文が同じでも異なっても同じ。入力内容が不正なら `request.invalid` が先 (R-ID-204、R-ID-205)                                                                                                                               | `server.unavailable`             |
| 通知 ID が存在しない、または形式が不正である (単体取得・キャンセル)                                                                                                                                                                                              | `notification.not_found`         |
| `scheduled` 以外の状態の通知をキャンセルする                                                                                                                                                                                                                     | `notification.not_cancellable`   |
| 未認証                                                                                                                                                                                                                                                           | `auth.unauthenticated`           |
| 認証済みだが、その操作を許可されていない                                                                                                                                                                                                                         | `auth.forbidden`                 |
| サーバー内部でエラーが発生した                                                                                                                                                                                                                                   | `server.internal`                |
| 未知のパス                                                                                                                                                                                                                                                       | `request.route_not_found`        |
| 許可されないメソッド                                                                                                                                                                                                                                             | `request.method_not_allowed`     |
| `Content-Type` が `application/json` でない、または Content-Encoding が identity 以外である (本文を伴う操作)                                                                                                                                                     | `request.unsupported_media_type` |
| 本文サイズが上限を超える                                                                                                                                                                                                                                         | `request.payload_too_large`      |

### 3.11 Boundary of Internal Realization

本契約は、バッチの原子性・冪等性・重複排除・状態遷移・バリデーションの判定・認証・永続化を、内部でどう実現するかを定義しない。
定義するのは、クライアントが観測できる結果だけとする (R-EP-091)。

---

## 4. Decision Rules

<!--
Rule ID format: R-EP-NNN (sequential, stable)
Rule IDs are referenced in Traceability and Edge Cases.
-->

### 4.1 Response Precedence

| Rule ID  | Rule                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                              |
| -------- | --------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| R-EP-001 | 本ファイルの 4 操作で複数のエラー条件が同時に成立したときの外部応答は、`specifications-errors.md` 4.1 の優先順位に従うこと (MUST)。本ファイルは優先順位を再定義しない (DD-EP-06)。成功結果の早期応答 (`specifications-errors.md` R-ER-064) は、4.1 の Step 1〜8 の検査を通過した送信に限って成立する。Step 1〜8 で拒否される送信 (未認証の 401 など) には、その拒否の応答を返す。優先順位に対する例外は、この早期応答だけとする (DR-06 決定 6)。形式が不正な通知 ID は、存在しない ID と同じ「リソース状態」の段で扱う (DD-EP-07) |
| R-EP-002 | (欠番)                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                            |
| R-EP-003 | (欠番)                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                            |
| R-EP-004 | (欠番)                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                            |
| R-EP-005 | (欠番)                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                            |

R-EP-002〜R-EP-005 は、優先順位を `specifications-errors.md` に一本化したため欠番とする。ID は再利用しない。

### 4.2 Operation Rules

| Rule ID  | Rule                                                                                                                                                                                                                             |
| -------- | -------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| R-EP-010 | バッチ登録は、`POST /v1/notifications` で受け付け、成功時は 201 を返す。リクエストは `Idempotency-Key` ヘッダーと `notifications` 配列を持つこと (MUST)                                                                          |
| R-EP-011 | バッチ登録の成功レスポンスは、入力の各要素に 1 対 1 で、入力と同じ順序・同じ件数の登録済み通知を `notifications` 配列に持つこと (MUST)。レスポンスの形状は成功と失敗の 2 つだけとし、部分成功を表す形状を持たないこと (MUST NOT) |
| R-EP-012 | 一覧取得は、`GET /v1/notifications` で受け付け、成功時は 200 と登録済み通知の `notifications` 配列を返すこと (MUST)。該当が 0 件のときは空配列を返すこと (MUST)                                                                  |
| R-EP-013 | 単体取得は、`GET /v1/notifications/{id}` で受け付け、成功時は 200 と登録済み通知 1 件を返すこと (MUST)。存在しない ID、および形式が不正な ID は、同じく `notification.not_found` で拒否すること (MUST)                           |
| R-EP-014 | キャンセルは、`POST /v1/notifications/{id}/cancel` で受け付け、成功時は 200 とキャンセル後の登録済み通知を返すこと (MUST)。存在しない ID、および形式が不正な ID は `notification.not_found` で拒否すること (MUST)                |
| R-EP-015 | 4 つの操作は、すべて認証を必要とすること (MUST)。未認証は `auth.unauthenticated`、認可されていない場合は `auth.forbidden` で拒否すること (MUST)。通知は所有者ごとに分離しないこと (MUST NOT 分離)                                |

### 4.3 List Rules

| Rule ID  | Rule                                                                                                                                                                                     |
| -------- | ---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| R-EP-020 | 一覧取得は、省略可能な `state` クエリを受け付けること (MUST)。複数回の指定を許し、指定された状態のいずれかに一致する通知を返すこと (MUST)。省略時は、すべての状態の通知を返すこと (MUST) |
| R-EP-021 | 一覧の並びは `fireAt` の昇順とし、`fireAt` が同じ通知は `id` の昇順とすること (MUST)                                                                                                     |
| R-EP-022 | 一覧取得は、ページングを持たず、該当する全件を返すこと (MUST)。絞り込みは `state` クエリだけとする                                                                                       |
| R-EP-023 | `state` クエリに 4 つの状態名以外の値があるときは、`request.invalid` で拒否すること (MUST)                                                                                               |

### 4.4 Data Shape and Schema Rules

| Rule ID  | Rule                                                                                                                                                                                                                                                                                                                      |
| -------- | ------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| R-EP-030 | 通知 ID は、サーバーが採番すること (MUST)。クライアントは ID を送れないこと (MUST NOT)。登録リクエストの要素に ID があるときは、`request.invalid` で拒否すること (MUST)                                                                                                                                                   |
| R-EP-031 | 通知 ID は不透明な文字列とし、クライアントは形式を解釈しないこと (MUST NOT)。契約が定めるのは、最大長と使える文字だけとする                                                                                                                                                                                               |
| R-EP-032 | `fireAt`、`createdAt`、`cancelledAt` は、RFC 3339 の日時で、UTC オフセットを含むこと (MUST)。オフセットのない日時は、`request.invalid` で拒否すること (MUST)                                                                                                                                                              |
| R-EP-033 | 登録済み通知は、3.4 のメンバーを持つこと (MUST)。`cancelledAt` は `state` が `cancelled` のときだけ持つこと (MUST)。すべてのレスポンスの通知は、同一の形状に従うこと (MUST)                                                                                                                                               |
| R-EP-034 | 繰り返し通知は、v1 で扱わないこと (MUST NOT)。1 件の通知は、1 つの `fireAt` だけを持つ                                                                                                                                                                                                                                    |
| R-EP-040 | `notifications.schema.json` は、JSON Schema Draft 2020-12 を `$schema` で宣言し、OpenAPI を使わずに単独で検証できること (MUST)                                                                                                                                                                                            |
| R-EP-041 | `notifications.schema.json` は、`$defs` で登録リクエストと登録済み通知を区別し、3.5 の検証制約のうち、本文の JSON の構造と値の制約を定義すること (MUST)                                                                                                                                                                   |
| R-EP-042 | OpenAPI は、バッチ登録の requestBody と各レスポンスを、`notifications.schema.json` の該当する `$defs` への相対 `$ref` で参照し、定義を複製しないこと (MUST)。参照は、ネットワーク接続なしで解決できること (MUST)                                                                                                          |
| R-EP-043 | 本文を伴う操作の Content-Encoding は identity だけとすること (MUST)。ヘッダーが無い場合は identity とみなし、クライアントに identity の明示を求めないこと (MUST NOT)。identity 以外は `request.unsupported_media_type` で拒否すること (MUST)。付けるヘッダーは `specifications-errors.md` R-ER-025 に従う (DR-06 決定 11) |

### 4.5 State and Cancel Rules

| Rule ID  | Rule                                                                                                                                                                                                 |
| -------- | ---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| R-EP-050 | 通知の状態は、`scheduled`・`dispatched`・`missed`・`cancelled` のいずれか 1 つとすること (MUST)。`dispatched`・`missed`・`cancelled` は終端状態とし、別の状態へ遷移しないこと (MUST NOT)             |
| R-EP-051 | `dispatched` は、発火時刻に OS へ通知を引き渡したことだけを意味すること (MUST)。画面への表示、およびユーザーの確認を意味に含めないこと (MUST NOT)                                                    |
| R-EP-052 | 状態の遷移は、3.6 の表に従うこと (MUST)。登録に成功した通知の状態は `scheduled` とすること (MUST)                                                                                                    |
| R-EP-060 | キャンセルは、`scheduled` の通知だけを受け付けること (MUST)。`cancelled`・`dispatched`・`missed` の通知は、`notification.not_cancellable` で拒否すること (MUST)                                      |
| R-EP-061 | キャンセルと引き渡しが競合したとき、キャンセルの成功か `notification.not_cancellable` による拒否のどちらか一方に確定すること (MUST)。キャンセルが成功した通知は、以後 OS へ引き渡されないこと (MUST) |
| R-EP-062 | キャンセルが成功した後の再送は、`notification.not_cancellable` となること (MUST)。キャンセルは `Idempotency-Key` の対象外とすること                                                                  |

### 4.6 Resend Rules

| Rule ID  | Rule                                                                                                                                                                                                                                                                                                                                              |
| -------- | ------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| R-EP-070 | バッチ登録は、`Idempotency-Key` ヘッダーを必須とすること (MUST)。欠落は `idempotency.key_missing`、形式の不正は `idempotency.key_invalid` で拒否すること (MUST)                                                                                                                                                                                   |
| R-EP-071 | 成功が確定したキーへの同じ本文の再送には、`specifications-idempotency.md` R-ID-202 のとおり、初回の 201 と本文の写しを返すこと (MUST) (DD-EP-12)                                                                                                                                                                                                  |
| R-EP-072 | `idempotency.key_conflict` の条件は、`specifications-idempotency.md` R-ID-203 に従うこと (MUST)                                                                                                                                                                                                                                                   |
| R-EP-073 | 成功の記録の保持は、`specifications-idempotency.md` R-ID-103 に従うこと (MUST)。結果の確定していないキーの扱いは R-ID-105 に従う                                                                                                                                                                                                                  |
| R-EP-074 | 一覧取得と単体取得は、安全かつ冪等であること (MUST)。再送によってサーバーの状態を変えないこと (MUST NOT)                                                                                                                                                                                                                                          |
| R-EP-075 | バッチ登録で `5xx` (503 を含む) を受け取ったとき、またはレスポンスを受け取れなかったとき、クライアントは登録されなかったことの確定とみなさないこと (MUST NOT)。再送の条件と結果の確定は、`specifications-idempotency.md` R-ID-301〜R-ID-304 に従う。キャンセルのレスポンスを受け取れなかったときは、単体取得で状態を確認して判断すること (SHOULD) |
| R-EP-076 | 未記録または登録なしが確定 (サーバー側で把握) のキーへの送信と、同じ登録の意図の登録し直しは、`specifications-idempotency.md` R-ID-201 と R-ID-305 に従うこと (MUST)                                                                                                                                                                              |
| R-EP-077 | 処理中または回復待ちのキーへの送信は、`specifications-idempotency.md` R-ID-204 と R-ID-205 に従うこと (MUST)                                                                                                                                                                                                                                      |
| R-EP-078 | 登録の確定と成功結果の記録の成立は、`specifications-idempotency.md` R-ID-401 に従うこと (MUST)                                                                                                                                                                                                                                                    |
| R-EP-079 | 同じキーの排他性と、保持の保証が有効な間の登録の回数は、`specifications-idempotency.md` R-ID-101 と R-ID-102 に従うこと (MUST)                                                                                                                                                                                                                    |

### 4.7 Atomicity and Rejection Rules

| Rule ID  | Rule                                                                                                                                                                                                                                                                                                                                                                                                                                                   |
| -------- | ------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------ |
| R-EP-080 | バッチ登録が成功レスポンスを返したとき、そのリクエストに含まれる通知は、すべて登録されていること (MUST)                                                                                                                                                                                                                                                                                                                                                |
| R-EP-081 | バッチ登録が共通エラー形式の `4xx` の失敗レスポンスを返したとき、そのリクエストによる新規登録は 1 件も残っていないこと (MUST)。`5xx` の失敗レスポンスを返したとき、そのリクエストの通知は、すべて登録されているか 1 件も登録されていないかのどちらかとし、一部の要素だけが登録された状態を残さないこと (MUST)。どちらであるかはクライアントにとって確定しない。失敗レスポンスは、共通エラー形式の単一のエラーとし、要素ごとの結果を含まないこと (MUST) |
| R-EP-082 | 応答の分類は、`specifications-idempotency.md` R-ID-301 に従うこと (MUST)。`5xx`、problem 形式でないエラー応答、上のどれにも当てはまらない応答、応答なしは、この応答だけでは結果を確定できないものとして扱う。確定済みの成功の確定 (クライアント) は変えない (R-ID-304)。結果の確定の試みは R-ID-302〜R-ID-304 に従い、確定は保証しない (R-ID-403)                                                                                                      |
| R-EP-083 | R-EP-080 と R-EP-081 の保証は、そのリクエストによる新規登録だけに及ぶこと (MUST)。既存の通知の削除や変更を求めないこと (MUST NOT)                                                                                                                                                                                                                                                                                                                      |
| R-EP-084 | 結果の確定していないキーの扱いと、停止後の回復は、`specifications-idempotency.md` R-ID-105、R-ID-402、R-ID-403 に従うこと (MUST)                                                                                                                                                                                                                                                                                                                       |
| R-EP-085 | 「同じ本文」の判定は、`specifications-idempotency.md` R-ID-206 に従うこと (MUST)。クライアントは、再送で初回と同じバイト列を送ること (MUST)                                                                                                                                                                                                                                                                                                            |
| R-EP-090 | 入力を拒否する条件と、拒否に使う code は、3.10 の表に従うこと (MUST)。code の定義そのものは、`specifications-errors.md` を参照すること (MUST)                                                                                                                                                                                                                                                                                                          |
| R-EP-091 | 本契約は、登録処理の原子性の実現方法、冪等性・重複排除の実現方法、バリデーションの判定アルゴリズム、照会・キャンセルの判定アルゴリズム、状態遷移の内部の実現方法、認証メカニズムの内部実装、永続化を、定義しないこと (MUST NOT)                                                                                                                                                                                                                        |

---

## 5. Edge Cases

| Input                                                | Classification                                                            | REQ                  | Rationale                                                                                   |
| ---------------------------------------------------- | ------------------------------------------------------------------------- | -------------------- | ------------------------------------------------------------------------------------------- |
| 未認証のリクエスト (存在しない ID・不正な本文を含む) | `auth.unauthenticated` (R-EP-001、`specifications-errors.md` R-ER-001)    | REQ-F-001, REQ-F-007 | 認証が最優先であり、404 や 409 などの詳細を開示しない (`specifications-errors.md` R-ER-017) |
| `notifications` が空配列                             | `request.invalid` (R-EP-090)                                              | REQ-F-002            | 要素数は 1 以上                                                                             |
| `notifications` が 100 件を超える                    | `request.invalid` (R-EP-090)                                              | REQ-F-002            | 要素数の上限 (既定値・レビュー対象)                                                         |
| 要素に `id` を含む                                   | `request.invalid` (R-EP-030)                                              | REQ-F-005            | ID はサーバーが採番する (DD-EP-03)                                                          |
| `fireAt` にオフセットがない                          | `request.invalid` (R-EP-032)                                              | REQ-F-005            | 発火時刻はオフセット付きの RFC 3339                                                         |
| 本文が JSON でない                                   | `request.invalid` (R-EP-090)                                              | REQ-F-007            | 入力の拒否は、外部から観測できる判定結果                                                    |
| `Content-Type` が `application/json` でない          | `request.unsupported_media_type` (R-EP-090)                               | REQ-F-007            | 優先順位は、入力検証より前                                                                  |
| Content-Encoding が gzip などの identity 以外        | `request.unsupported_media_type` (R-EP-043)                               | REQ-F-007            | v1 は identity だけ (DR-06 決定 11)                                                         |
| 本文が 1 MiB を超える                                | `request.payload_too_large` (R-EP-090)                                    | REQ-F-007            | 本文サイズの上限 (既定値・レビュー対象)                                                     |
| `Idempotency-Key` がない                             | `idempotency.key_missing` (R-EP-070)                                      | REQ-F-007            | バッチ登録では必須 (DD-EP-05)                                                               |
| 一覧に該当が 0 件                                    | 200 と空配列 (R-EP-012)                                                   | REQ-F-001            | 空は正常な結果                                                                              |
| `state=scheduled&state=missed`                       | いずれかに一致する通知を返す (R-EP-020)                                   | REQ-F-001            | 複数指定は、和集合                                                                          |
| `state=unknown`                                      | `request.invalid` (R-EP-023)                                              | REQ-F-001            | 状態名は 4 つに限る                                                                         |
| 存在しない ID の単体取得・キャンセル                 | `notification.not_found` (R-EP-013, R-EP-014)                             | REQ-F-001            | 存在しない通知                                                                              |
| 形式が不正な ID                                      | `notification.not_found` (R-EP-013)                                       | REQ-F-001            | 存在しない ID と同じ扱い (DD-EP-07)                                                         |
| `cancelled` の通知をキャンセル                       | `notification.not_cancellable` (R-EP-060)                                 | REQ-F-001, REQ-F-007 | 冪等な成功にしない (DD-EP-04)                                                               |
| `dispatched` または `missed` の通知をキャンセル      | `notification.not_cancellable` (R-EP-060)                                 | REQ-F-001, REQ-F-007 | 終端状態                                                                                    |
| キャンセルと引き渡しが同時                           | キャンセル成功か `notification.not_cancellable` のどちらか一方 (R-EP-061) | REQ-F-007            | 競合の結果を排他的にする                                                                    |
| キャンセルの応答喪失後の再送                         | 拒否される場合は、単体取得で状態を確認する (R-EP-062, R-EP-075)           | REQ-F-007            | キャンセルは `Idempotency-Key` の対象外                                                     |
| バッチの途中の要素が不正                             | 単一の `request.invalid`。新規登録は 1 件も残らない (R-EP-081)            | REQ-F-001            | 部分成功の形状を持たない (DR-02)                                                            |
| 過去の `fireAt`、バッチ内の同一内容の要素            | 本仕様では未定義 (7 章 #2, #3)                                            | REQ-F-001            | 要件にも確認済みの決定にもないため、挙動を作らない                                          |

再送と冪等性のシナリオは `specifications-idempotency.md` 5.2 に置く。

---

## 6. Requirements Traceability

| Requirement ID | Spec Rule                                                                                                    | Notes                                                                                                         |
| -------------- | ------------------------------------------------------------------------------------------------------------ | ------------------------------------------------------------------------------------------------------------- |
| REQ-F-001      | R-EP-010〜R-EP-015, R-EP-020〜R-EP-023, R-EP-043, R-EP-080〜R-EP-084                                         | 4 操作、バッチの応答形状と原子性                                                                              |
| AC-001         | R-EP-010〜R-EP-014, 3.3                                                                                      | 4 操作がパス・メソッド・リクエスト・レスポンスとともに定義されている                                          |
| AC-010         | R-EP-011, R-EP-081                                                                                           | 成功と失敗の 2 形状。部分成功の形状を持たない                                                                 |
| AC-011         | R-EP-012, R-EP-013, R-EP-014, R-EP-060                                                                       | 一覧は登録済み通知の配列。単体取得・キャンセルは ID で指定する                                                |
| AC-025         | R-EP-075〜R-EP-077, R-EP-079, R-EP-080〜R-EP-084                                                             | 成功・`4xx` の失敗・結果未確定 (`5xx`・応答なし) を区別し、既存通知に及ばない。回復が完了した場合の結果の整合 |
| REQ-F-002      | R-EP-040, R-EP-041, R-EP-042                                                                                 | 独立スキーマと `$defs`、検証制約                                                                              |
| AC-002         | R-EP-040, R-EP-042                                                                                           | `notifications.schema.json` を単独で検証できる                                                                |
| REQ-F-005      | R-EP-030〜R-EP-034, R-EP-050〜R-EP-052                                                                       | データ形状と状態の集合                                                                                        |
| AC-008         | R-EP-033, R-EP-050, R-EP-051, 3.4, 3.6                                                                       | 形状と各状態の名前・意味。遷移の内部は定義しない                                                              |
| REQ-F-007      | R-EP-001, R-EP-043, R-EP-052, R-EP-060〜R-EP-062, R-EP-070〜R-EP-079, R-EP-084, R-EP-085, R-EP-090, R-EP-091 | 外部から観測できる保証                                                                                        |
| AC-004         | R-EP-091, 3.11                                                                                               | 内部の実現方法を定義しないことの明示                                                                          |
| AC-019         | R-EP-052, R-EP-060〜R-EP-062, R-EP-070〜R-EP-079, R-EP-084, R-EP-085, R-EP-090                               | 各操作の再送時の振る舞い、キャンセルの結果、遷移規則、拒否条件と code                                         |
| REQ-F-003      | —                                                                                                            | Covered in: `specifications-errors.md`                                                                        |
| REQ-F-004      | —                                                                                                            | Covered in: `specifications-errors.md`                                                                        |
| REQ-F-006      | —                                                                                                            | Covered in: `specifications-errors.md`                                                                        |
| REQ-F-008      | —                                                                                                            | Covered in: `specifications-errors.md` (R-EP-015 は認証必須を参照するだけとする)                              |
| REQ-F-009      | —                                                                                                            | Covered in: `specifications-governance.md`                                                                    |
| REQ-F-010      | —                                                                                                            | Covered in: `specifications-governance.md`                                                                    |
| REQ-F-011      | —                                                                                                            | Covered in: `specifications-governance.md`                                                                    |
| REQ-F-012      | —                                                                                                            | Covered in: `specifications-governance.md`                                                                    |

再送と冪等性の規則の Traceability は、`specifications-idempotency.md` 6 章も参照する。

---

## 7. Open Questions

> **Status**: INCOMPLETE

解決済みの事項は次のとおりとする。番号は変えず、本表から外した。

- #4: 「同じ本文」は、本文のバイト列の完全な一致とする (DR-06 決定 10、R-EP-085)
- #6: 成功の記録の保持の保証が終わった後の再送の扱いを決めた。重複登録の防止は保証しない。
  応答は、キー照合時点のキーの状態 (UD-039)、先行する検査、入力内容によって決まる (`specifications-idempotency.md` R-ID-201、R-ID-106)。
  成功の記録が残っていれば、同じ本文には初回の 201 の再現、異なる有効な本文には 409 になる。記録が削除された後は、新規の登録になり得る。
  そのキーに処理中または回復待ちの登録処理があれば 503、入力内容が不正なら 400 になる (DR-06 決定 3・決定 4、`specifications-errors.md` R-ER-042)。
  回復できない未確定キーの扱いは、本項の解決に含めない (#15)
- #13: requirements.md v1.5.0 で、REQ-F-001 と AC-025 を `4xx` の失敗と結果未確定 (`5xx`・応答なし) に分けて改訂した

| #  | Question                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                | Source                                         | Impact                                                          |
| -- | --------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- | ---------------------------------------------- | --------------------------------------------------------------- |
| 1  | 資格情報の送信形式として HTTP Bearer を OpenAPI に書くが、これは候補である。#6 との照合は「未確認」であり、確定した保証として扱わない                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                   | REQ-F-008, `specifications-errors.md` R-ER-054 | R-EP-001, R-EP-015 の認証の前提。#6 の DR で変わり得る          |
| 2  | 過去の `fireAt` を登録時に拒否するか、受け付けるか。受け付けた場合の状態 (`missed` か)                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                  | REQ-F-001 (過去の fireAt)                      | 3.5 の検証制約、3.6 の遷移規則                                  |
| 3  | バッチ内に同一内容の要素があるとき、別々の通知として登録するか、拒否するか                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                              | REQ-F-001                                      | R-EP-011 の件数の対応、3.5 の検証制約                           |
| 7  | 次の保証は、兄弟 issue との照合が済んでいない (未確認)。確定した保証として扱わず、`specifications-governance.md` 3.3.3 の照合の記録 (DR-05) で照合する。(a) 成功の記録の保持 (R-EP-073): G-03、#4・#7。(b-1) 再送時の応答 (R-EP-071、R-EP-072): G-02、#4。(b-2) 同じキーの排他性、重複登録の防止、競合時の 503 (R-EP-075〜R-EP-077、R-EP-079): G-16、#4・#7。(c-1) 原子性 (R-EP-080〜R-EP-083): G-01、#4。(c-2) 登録と成功の記録の原子性、回復後の整合、回復できない未確定キーの安全性 (R-EP-078、R-EP-084): G-17、#4・#5・#7 (#5 は回復した結果と照会の結果の整合の確認に限る。#14)。(d-1) `missed` の検出と保持 (R-EP-050〜R-EP-052): G-04、#5・#7。(d-2) キャンセルと引き渡しの競合 (R-EP-060〜R-EP-061): G-05・G-06、#5。(e) キー空間の共有と認証設計の整合 (3.8.1): G-18、#6 (#16) | REQ-F-009, DR-05                               | 照合が済むまで契約を確定できない                                |
| 8  | `url` に許可する形式 (相対 URL を許すか、許可するスキーム)                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                              | REQ-F-005                                      | 3.5 の `url` の制約                                             |
| 9  | レスポンスの `fireAt` で、登録時に送られたオフセットを保持するか、正規化するか                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                          | REQ-F-005                                      | R-EP-032, 3.4                                                   |
| 10 | `missed` と判定する境界 (発火時刻からどれだけ遅れると引き渡せなかったとみなすか) を契約で保証するか                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                     | REQ-F-005, DD-EP-08                            | R-EP-051, 3.6。#5・#7 との照合に依存する                        |
| 12 | 既定値 (OpenAPI 3.1.1、最大 100 件、本文 1 MiB、`title` 100 文字、`body` 1000 文字、`url` 2048 文字、ID 64 文字、キーの 255 文字) のレビュー                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                            | Spec 生成時の既定値                            | 3.5 の検証制約。レビューで変わり得る                            |
| 14 | 結果が未確定の間に、その操作の通知が一覧取得・単体取得に現れ得るか (照会の結果と照合・回復の結果の整合)。#5・#7 との照合が必要                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                          | REQ-F-007, DD-EP-11                            | 3.8.1、R-EP-077、governance G-17                                |
| 15 | 回復の完了、回復の期限、回復できない未確定キーの扱い (DR-06 決定 14)。本ファイルは、回復できないキーが安全に再利用できない場合があり、503 が返り続け得ることだけを定める。#4・#7 との実現可能性の照合は「未確認」                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                       | REQ-F-007, DR-06                               | R-EP-084、3.8.1                                                 |
| 16 | Idempotency-Key の空間を API インスタンス全体で共有すること (DR-06 決定 15) と、#6 の認証設計の整合。対象は、認証主体が異なる場合のキーの衝突、資格情報の更新・再発行による影響、キー空間の共有と登録結果を参照する権限の分離、成功結果の再現による情報開示の可能性。認証方式と認可方式は本ファイルで決めない。#6 との照合は「未確認」                                                                                                                                                                                                                                                                                                                                                                                                                                                  | REQ-F-008, DR-06                               | 3.8.1                                                           |
| 17 | `fireAt` を過ぎてから `dispatched` か `missed` に決まるまでの間に、通知がどの状態に見えるか。その間のキャンセルをどう扱うか。方針案 (承認済み・未反映): その間は `scheduled` のまま見え、キャンセルは R-EP-061 に従う                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                   | REQ-F-005                                      | 3.6、R-EP-061                                                   |
| 18 | 発火時刻の判定に使う時計 (サーバーの時計か)、端末のスリープ、時計の変更、プロセスの停止中に `fireAt` を過ぎた通知の状態。本書の設計判断 (DD-EP) として決める (未決定)                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                   | REQ-F-005                                      | 3.6、#10                                                        |
| 19 | 一覧取得・単体取得・キャンセルに付いた `Idempotency-Key`、未知のクエリ、本文の扱い。方針案: `Idempotency-Key` は無視し、未知のクエリと本文は `request.invalid` とする。本書の設計判断 (DD-EP) として決める (具体値は未決定)                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                             | REQ-F-005, REQ-F-007                           | 3.3〜3.5、`specifications-errors.md` 4.1                        |
| 20 | 比較と入力の規則。方針案 (承認済み・未反映): 並びの `fireAt` は UTC に直した時刻で比べ、同じ時刻の `id` は文字列として比べる (R-EP-021)。文字数は Unicode のコードポイントで数える。`state` クエリは空の値と区切り文字を不正とし、重複は和集合、値は小文字だけとする。上限 (件数・長さ・本文サイズ) はそれぞれ独立に判定し、各要素が制約を満たしていても 413 になり得る。`url` の形式は #8、403 の条件は `specifications-errors.md` 7 章 #2 で扱う                                                                                                                                                                                                                                                                                                                                      | REQ-F-002, REQ-F-005                           | R-EP-020〜R-EP-023、3.5、#12                                    |
| 21 | 利用者は単一の PWA という前提に対して、複数のタブ、複数の PWA インスタンス、再読み込み直後の再送が同時に起き得ることを、契約でどう扱うか                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                | REQ-F-007                                      | 2.2、`specifications-idempotency.md` R-ID-101                   |
| 22 | Non-Goals: 終端状態 (`dispatched`・`missed`・`cancelled`) の通知の保持期間と削除の手段、一覧が大きくなるリスク、通知の更新 (内容の変更、再スケジュール) を v1 の対象外と明記するか                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                      | REQ-F-005                                      | 2.4、R-EP-022                                                   |
| 23 | レスポンスに未知のメンバーが含まれ得るか (リクエストは未知のメンバーを拒否する)。新しい DR として決める (未決定)                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                        | REQ-F-010                                      | 3.5、`specifications-governance.md`                             |
| 24 | キャンセルに成功した通知を再起動の後も引き渡さない保証 (R-EP-061) が、#7 の永続化に依存するか。`specifications-governance.md` G-05・G-06 の照合対象に #7 を加えるか                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                     | REQ-F-009, DR-05                               | R-EP-061、G-05、G-06                                            |
| 25 | Open Questions の ID を `OQ-EP-nn` の形式にするか (index と governance からの参照も同時に直す)                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                          | -                                              | 7 章、`specifications-index.md`、`specifications-governance.md` |

---

## 8. Change History

| Date       | Version | Description                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                   |
| ---------- | ------- | ------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| 2026-11-14 | 1.0.0   | Initial specification                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                         |
| 2026-11-14 | 1.1.0   | DR-06 と requirements.md v1.5.0、specifications-errors.md v1.1.0 を反映: 3.8.1 をキーの状態と応答、記録の失効、回復、クライアントから見た論理操作で書き直し。R-EP-043 (Content-Encoding)、R-EP-084 (回復)、R-EP-085 (同じ本文の判定)、DD-EP-12 (201 と本文の写しの再現) を追加。3.8.1 に Idempotency-Key の空間の共有 (DR-06 決定 15) を明記。R-EP-001、R-EP-071、R-EP-072、R-EP-075〜R-EP-079、R-EP-081、R-EP-082、DD-EP-05、DD-EP-06、DD-EP-11、3.1、3.2、3.5、3.8、3.9、3.10、Edge Cases、Traceability を更新。Open Questions #4、#6、#13 を解決済みにし、#15 を追加。3.8.1 にキーの状態ごとの応答の要約と、キー空間と #6 の照合点を追加。R-EP-073 を成功の記録の保持に限定し、未確定キーを手放さない規則を R-EP-084 に移動。Open Questions #7 を責務ごとに整理し、#16 を追加。横断レビューの指摘を反映: R-EP-079 を保持の保証の期間に限定。3.8.1 に残留リスク (保持期間の後の遅延送信)、処理中の 503 の注記、サーバーとクライアントの「登録なし」の区別を追加。3.9、R-EP-075、R-EP-082 で再送は確定を保証しないと明記し、API が返す 4xx に限定。3.5、3.10、R-EP-041 で `request.invalid` を本文の JSON の制約に限定し、本文中の通知 ID とパスの通知 ID を区別。R-EP-085 に比較対象のバイト列を明記。Open Questions #7 を governance の照合の行に対応付け。2.1 を DR-01〜06 にする。based-on を requirements.md v1.5.1 にする。2 回目の横断レビューの指摘を反映: 再送の開始の期限とキーの照合の時点を区別し、`Retry-After` と期限の関係を追加。クライアント側の応答の表で契約に適合する 201 と problem 形式でないエラー応答を区別。登録なしの判断の意味を統一。同じ登録の意図の登録し直しに制限を限定。2.2 の所有者とアクセス条件の記述、2.3 の図、Open Questions #14 の参照を修正。再送と冪等性の保証の正本を specifications-idempotency.md に移し、3.8.1、R-EP-071〜R-EP-079、R-EP-082、R-EP-084、R-EP-085、DD-EP-11、DD-EP-12、3.8、3.9、3.10 を参照中心に書き換え、冪等性のシナリオを移動。2.3 の先行の検査を errors 4.1 の Step 1〜8 と同じ列挙にした |
| 2026-11-14 | 1.1.1   | 3.2 の API が返した `4xx` の意味を、その送信についての結果に限定し、論理操作の登録なしの確定 (UD-043) は R-ID-303 によると明記 (Q-9)。based-on を requirements.md v1.5.3 に更新。R-EP-082 を、応答単独では確定できないことと、確定済みの成功は変えないことにそろえる。R-EP-001 を、成功結果の早期応答は Step 1〜8 を通過した送信に限ると改め、優先順位の再定義をやめる (Q-7)。解決済みの #6 の要約に、409・503・400 になる場合を加える (Q-8。規則は変えない)                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                  |
| 2026-11-14 | 1.1.2   | 7 章に Open Questions #17〜#25 を追加 (DR-06 の反映で次回の改訂に回した項目を、作業メモから移す。規則は変えない)                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                              |
