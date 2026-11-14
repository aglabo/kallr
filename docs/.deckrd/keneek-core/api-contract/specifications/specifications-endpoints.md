---
title: "Design Specification: Notification API Contract — Endpoints and Observable Guarantees"
based-on: requirements.md v1.5.3
status: Draft
version: 2.2.0
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
- エラー code・type・HTTP ステータス・分類・対処方針の表。`specifications-errors.md` が唯一の場所であり、本ファイルは code を参照するだけとする
- 認証の外部仕様の詳細 (`specifications-errors.md`)
- 契約バージョン管理、破壊的変更、契約検証、整合確認の記録 (`specifications-governance.md`)
- 内部の実現方法 (3.11 と R-EP-I-001 を参照)

---

## 2. Design Principles

### 2.1 Classification Philosophy

- 本仕様は、クライアントがリクエストとレスポンスを通して観測できる事実だけを定義する (DR-03)。
  サーバーが保証をどう実現するかは定義しない。
- 正本の優先順位は、decision-records.md (DR-01〜09) を最上位とし、次に確認済みの設計条件、API の決定、関数の決定の順とする。
  DR が決めた事項は、再定義せず参照する。
- 結果が複数の形で観測され得る箇所 (キャンセルと配信の競合、バッチの成功・`4xx` の失敗・結果未確定) は、
  観測結果が排他的な区分になるように定義する。
- 確定していない事項 (Bearer 認証、兄弟 issue との照合) は、確定した保証として書かない。
  候補または未確認と明記し、Open Questions に残す。

### 2.2 Design Assumptions

- 契約の利用者は PWA であり、通信は JSON over HTTP のみとする。
- 全エンドポイントは認証を必要とする。認証の外部仕様は `specifications-errors.md` が定義する。
- 通知は所有者ごとに分離せず、所有者の違いによるアクセス条件の差を設けない (`specifications-errors.md` DD-ER-11)。
  操作を認可されていない場合の 403 (`auth.forbidden`) は、所有者の違いとは別の条件で返る (R-EP-C-007)。
  その発生条件の詳細は issue #6 が決める。本書は条件を定めない。
  追跡先は、`specifications-errors.md` 7 章 #2、`specifications-governance.md` G-11 である (照合結果は未確認)。
- 通知 ID の採番は、サーバーが行う (DD-EP-03、R-EP-C-012)。採番の内部方式は本契約の対象外である (R-EP-C-013)。
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

U4 (エラー仕様) と U5 (対処方針) は `specifications-errors.md` が担当するため、本表に含めない。
全ユニットの分担は `specifications-index.md` の Feature Decomposition を参照する。

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
成功結果の再現 (`specifications-errors.md` R-ER-C-009) は、先行の検査を通過した送信だけに当てはまる。
先行の検査は、`specifications-errors.md` 4.1 の Step 1〜8 とする。
対象は、認証、ルーティング・メソッド・認可、メディアタイプ・Content-Encoding・本文サイズ、Idempotency-Key ヘッダーの形式の検査とする。
この再現は、入力内容の検証より先に返す。
優先順位の正本は `specifications-errors.md` 4.1 である (R-EP-C-001)。

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

| ID       | Decision                                                                                                                                                                                                               | Rationale                                                                                                                                                        | Affected Rules                                 | Status |
| -------- | ---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- | ---------------------------------------------------------------------------------------------------------------------------------------------------------------- | ---------------------------------------------- | ------ |
| DD-EP-01 | 操作のパスは `/v1/notifications` 系とし、API メジャーバージョンを URL パスの `/v1` で識別する                                                                                                                          | クライアントが利用するバージョンを、リクエストの URL だけで識別できる                                                                                            | R-EP-C-002〜R-EP-C-006                         | Active |
| DD-EP-02 | バッチ登録・一覧取得のレスポンスは、通知の配列を `notifications` メンバーに持つ。単体取得・キャンセルは通知そのものを返す                                                                                              | リクエストと同じメンバー名にそろえ、DR-02 の「通知ごとの結果」に登録済み通知の形状 (ID と状態を含む) を使う                                                      | R-EP-C-003, R-EP-C-004                         | Active |
| DD-EP-03 | 登録リクエストの要素は、未知のメンバーを拒否する。クライアントは ID を送らない                                                                                                                                         | ID はサーバーが採番する。送られた ID が無視されると、指定が効いたとクライアントが誤解する                                                                        | R-EP-C-012, R-EP-C-018                         | Active |
| DD-EP-04 | キャンセルは `scheduled` の通知だけを受け付ける。ほかの状態は、冪等な成功にせずエラーにする                                                                                                                            | issue #5 の下書きと整合し、再送後の状態をクライアントが GET で確認できる                                                                                         | R-EP-C-024〜R-EP-C-026, R-EP-I-007             | Active |
| DD-EP-05 | `Idempotency-Key` はバッチ登録で必須とする。キャンセルと GET は対象外とする                                                                                                                                            | 二重登録の防止が設計目標であり、キャンセルは状態の確認で再送を判断できる                                                                                         | R-EP-C-027〜R-EP-C-034, R-EP-I-002〜R-EP-I-005 | Active |
| DD-EP-06 | 複数のエラー条件が同時に成立したときの外部応答の優先順位は、`specifications-errors.md` 4.1 を唯一の場所とし、本ファイルでは再定義しない。例外は、成功結果の早期応答 (`specifications-errors.md` R-ER-C-009) だけとする | 優先順位を 2 か所に書くと食い違う。本ファイルは参照だけにする (DR-06 決定 6)                                                                                     | R-EP-C-001                                     | Active |
| DD-EP-07 | 形式が不正な通知 ID は、存在しない ID と同じ扱いにする。優先順位も「リソース状態」の段で、存在しない ID と同じとする                                                                                                   | ID は不透明であり、クライアントが形式を判断できない。存在の有無と形式の不正を、応答でも優先順位でも区別すると内部を漏らす                                        | R-EP-C-001, R-EP-C-005, R-EP-C-006, R-EP-C-039 | Active |
| DD-EP-08 | 状態の集合は `scheduled`・`dispatched`・`missed`・`cancelled` の 4 つとする。`dispatched` は OS への引き渡しだけを意味し、画面表示とユーザーの確認を含めない。`missed` を v1 から含める                                | 後から状態を加えると既存クライアントの解釈が変わり、破壊的変更になる。OS への引き渡しと表示・確認を区別しないと、Keneek が観測できない事実を状態が主張してしまう | R-EP-C-021, R-EP-C-022                         | Active |
| DD-EP-09 | 一覧取得の絞り込みは省略可能な `state` クエリだけとし、ページングを設けない                                                                                                                                            | 端末内の利用で件数は少ない。省略可能なクエリは後から追加しても後方互換である                                                                                     | R-EP-C-008〜R-EP-C-011                         | Active |
| DD-EP-10 | `notifications.schema.json` の中で、登録リクエストと登録済み通知を `$defs` で区別する                                                                                                                                  | 独立して検証できるスキーマを 1 ファイルに保ちつつ、リクエストとレスポンスの形状を取り違えない                                                                    | R-EP-C-018, R-EP-C-045                         | Active |
| DD-EP-11 | `Idempotency-Key` を成功結果に結び付けるのは、登録の成功 (201) が確定したときだけとする。5xx と応答の喪失は、登録されなかったことの確定とみなさない。詳細の正本は `specifications-idempotency.md` (IP-1、IP-3) とする  | 5xx や応答の喪失の後に新規登録として処理すると、二重登録が起き得る (DR-06 決定 9)                                                                                | R-EP-C-028〜R-EP-C-033, R-EP-I-002〜R-EP-I-005 | Active |
| DD-EP-12 | 成功が確定したキーに同じ本文で再送されたときは、初回の 201 と本文の写しを返す。詳細の正本は `specifications-idempotency.md` R-ID-C-202 とする                                                                          | 再送の応答を、時刻に依存し得る入力内容の検証と、通知の現在の状態から切り離す (DR-06 決定 6)                                                                      | R-EP-C-028                                     | Active |

> **Note**: Decisions listed here derive from REQUIREMENTS Design Decisions and the confirmed API decisions.
> If promoting to formal Decision Record, use `/deckrd dr --add`.

**Status Values:**

- `Active` — Currently in effect within this specification
- `Promoted → DR-xx` — Elevated to formal Decision Record (see Section 2.6)

### 2.6 Related Decision Records

> **Reference**: This section lists formal DRs that affect this specification.
> DRs are maintained in `decision-records.md` and are authoritative.

| DR-ID | Title                                                                                            | Phase         | Impact on This Spec                                                                                                                                                                                                                             |
| ----- | ------------------------------------------------------------------------------------------------ | ------------- | ----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| DR-01 | 共通エラー形式に RFC 9457 を採用し、`type` と `code` を 1 対 1 で対応させる                      | review-harden | 本ファイルのエラーレスポンスは `application/problem+json` とする。code の定義は `specifications-errors.md` に委ねる                                                                                                                             |
| DR-02 | バッチ登録のレスポンスは all-or-nothing の形状とし、部分成功を表す形状を持たない                 | review-harden | R-EP-C-003 の成功・失敗の 2 形状と、入力順の 1 対 1 対応を決める                                                                                                                                                                                |
| DR-03 | 外部から観測できる振る舞いの保証を API 契約に含め、内部の実現方法は兄弟 issue に委ねる           | review-harden | 再送、キャンセル、原子性、入力拒否を本ファイルで定義し、内部の実現方法を定義しない (R-EP-I-001)                                                                                                                                                 |
| DR-04 | エラーの分類とクライアントの対処を分離し、エラー識別子の追加を無条件に後方互換としない           | review-harden | 対処方針は code ごとに `specifications-errors.md` で定める。本ファイルは再送の結果だけを定義する                                                                                                                                                |
| DR-05 | 契約確定前の兄弟 issue との整合確認は、保証ごとの照合結果を記録として Specifications に残す      | review-harden | 本ファイルの保証のうち照合が済んでいないものは、確定した保証として扱わない (7 章)                                                                                                                                                               |
| DR-06 | バッチ登録の冪等性を、安全性・応答の一貫性・回復可能性に分けて外部契約にする                     | spec          | 3.8.1 のキーの状態と応答、クライアントから見た論理操作の確定条件、成功結果の再現 (R-EP-C-028)、409 の条件 (R-EP-C-029)、処理中の競合の 503 (R-EP-C-033)、Content-Encoding (R-EP-C-020)、回復 (R-EP-I-005)、同じ本文の判定 (R-EP-C-034) を決める |
| DR-07 | 一覧の並びと長さの上限は実装言語によらない方法で比べ、`state` クエリの値と上限の判定を一意にする | review-harden | 並びの比べ方 (R-EP-C-009)、`state` クエリの値 (R-EP-C-011)、長さの上限の数え方 (R-EP-C-040)、上限の独立した判定 (R-EP-C-041) を決める                                                                                                           |
| DR-08 | 発火時刻を過ぎた通知は、引き渡しの結果が決まるまで `scheduled` として観測される                  | review-harden | `fireAt` を過ぎた通知の観測される状態とその間のキャンセル (R-EP-C-042、3.6) を決める                                                                                                                                                            |
| DR-09 | キャンセルの応答を 3 つに分類し、結果未確定のときにクライアントが結論を出すことを禁じる          | review-harden | キャンセルの応答の分類 (R-EP-C-043)、結果未確定のときの判断の禁止 (R-EP-C-044)、単体取得で確認する条件 (R-EP-C-031、3.8) を決める                                                                                                               |

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

<!-- textlint-disable ja-technical-writing/sentence-length -->

- Input Type: 認証済みクライアントからの、`/v1` 配下への HTTP リクエスト。
  本文を持つ操作 (バッチ登録) のメディアタイプは `application/json`、文字コードは UTF-8 とする (メディアタイプの拒否は 3.10、R-EP-C-039。`charset` の扱いは 7 章 #26)。
  Content-Encoding は identity だけとする (R-EP-C-020)
- Assumptions:
  - 認証の成否は、リクエストの資格情報で決まる。認証の外部仕様は `specifications-errors.md` が定義する
  - HTTP メッセージとして受理できないプロトコルレベルのエラーは、本ファイルの対象外とする (`specifications-errors.md` R-ER-C-016)
  - CORS プリフライト (OPTIONS) は、認証優先規則の例外として別に定義する (`specifications-errors.md` 4.10)。本ファイルの 4 操作には含めない

<!-- textlint-enable ja-technical-writing/sentence-length -->

### 3.2 Output Semantics

- Output Meaning: 成功レスポンスは、操作後の通知、または通知の配列を表す。
  成功レスポンスのメディアタイプは `application/json` とする (2.2 の JSON over HTTP)。
  API 自身が生成するエラーレスポンス (`4xx`・`5xx`) は、共通エラー形式 (UD-013。`application/problem+json`、DR-01) の単一のエラーを表す。
  本書の「失敗レスポンス」(R-EP-C-036 など) は、このエラーレスポンスを指す。
  次の Possible Outcomes の「失敗」は、このうち API が生成した共通エラー形式の 4xx (UD-018) だけを指す
- Possible Outcomes:
  - 成功: 通知 (または通知の配列) を返す
  - 失敗: API が生成した共通エラー形式の 4xx (UD-018) の、単一のエラーを返す (code は `specifications-errors.md` を参照)
  - 結果未確定: `5xx` (503 を含む)、共通エラー形式でないエラー応答 (4xx・5xx)、
    上のどれにも当てはまらない応答 (契約に適合しない 2xx など)、応答なし。
    API が生成した `4xx` の失敗レスポンスとは区別し、その応答だけでは結果を確定できないものとして扱う。
    分類の正本は `specifications-idempotency.md` R-ID-C-301 とする (R-EP-C-037)

### 3.3 Operations

すべての操作は認証を必要とする。成功時のステータスと、リクエスト・レスポンスの形状は次のとおりとする。

| Operation  | Method | Path                            | 成功ステータス | リクエスト                                                           | 成功レスポンス                                                       |
| ---------- | ------ | ------------------------------- | -------------- | -------------------------------------------------------------------- | -------------------------------------------------------------------- |
| バッチ登録 | POST   | `/v1/notifications`             | 201            | `Idempotency-Key` ヘッダー (必須) と、`notifications` 配列を持つ本文 | `notifications` 配列。入力と同じ順序・同じ件数で、登録済み通知を持つ |
| 一覧取得   | GET    | `/v1/notifications`             | 200            | 省略可能な `state` クエリ (複数指定可)                               | `notifications` 配列 (登録済み通知。0 件のとき空配列)                |
| 単体取得   | GET    | `/v1/notifications/{id}`        | 200            | パスの通知 ID                                                        | 登録済み通知 1 件                                                    |
| キャンセル | POST   | `/v1/notifications/{id}/cancel` | 200            | パスの通知 ID。本文なし                                              | キャンセル後の登録済み通知 (状態は `cancelled`)                      |

契約に定義されたパスとメソッドは、本表のものだけとする。本表以外への要求は、`specifications-errors.md` の既存の規則で拒否する。

- 本表のどのパスにも該当しないリクエスト (`/v1` 以外のバージョンのパスを含む): 404 `request.route_not_found` (R-ER-C-002)
- 本表のパスに該当するが、本表にないメソッド (HEAD を含む): 405 `request.method_not_allowed` (R-ER-C-003)
- 複数の条件が同時に成立したときの優先順位 (未認証の 401 が先など) は `specifications-errors.md` 4.1 に従う (R-EP-C-001)
- CORS プリフライト (OPTIONS) は、本節の対象外とする (3.1、`specifications-errors.md` 4.10)

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

- 登録リクエストの本文とその `notifications` 配列は、独立したスキーマで定義する。
  ファイルは `notifications.schema.json` (JSON Schema Draft 2020-12) とする。
  このスキーマは、OpenAPI ドキュメントを使わずに単独で検証できる。
- `notifications.schema.json` は、`$defs` の中で次の 3 つを区別して定義する (DD-EP-10、R-EP-C-045)。
  - 登録リクエスト: 本文のオブジェクト (`notifications` を必須メンバーとして持ち、ほかのメンバーを拒否する) と、`notifications` 配列とその要素
  - 登録済み通知: レスポンスで返す通知の形状
  - 応答本文: 登録済み通知の配列を `notifications` メンバーに持つオブジェクト (一覧取得とバッチ登録の成功レスポンス。DD-EP-02)。
    未知のメンバーを含み得るかは定めない (7 章 #23)
- OpenAPI は、バッチ登録の requestBody で登録リクエストを、相対 `$ref` で参照する。
  レスポンスは、通知そのものを返すものは登録済み通知を、`notifications` メンバーを持つものは応答本文を、相対 `$ref` で参照する。
  定義を OpenAPI 側に複製しない。
- OpenAPI のバージョンは 3.1.1 とする (既定値・レビュー対象)。

検証制約 (登録リクエスト):

| 対象                       | 制約                                                                                                                |
| -------------------------- | ------------------------------------------------------------------------------------------------------------------- |
| 本文                       | `notifications` を必須メンバーとして持つオブジェクト。ほかのメンバーは拒否する                                      |
| `notifications`            | 配列。要素数は 1 以上。最大 100 件 (既定値・レビュー対象)                                                           |
| 要素                       | オブジェクト。`title`・`body`・`fireAt`・`url` を必須とし、未知のメンバーは拒否する                                 |
| `title`                    | 文字列。1 文字以上。最大 100 文字 (既定値・レビュー対象)                                                            |
| `body`                     | 文字列。0 文字以上。最大 1000 文字 (既定値・レビュー対象)                                                           |
| `fireAt`                   | 文字列。RFC 3339 の日時の形式で、UTC オフセットを含む                                                               |
| `url`                      | 文字列。URI の形式。最大 2048 文字 (既定値・レビュー対象)                                                           |
| 本文サイズ                 | 1048576 バイト (1 MiB) 以下 (既定値・レビュー対象)                                                                  |
| Content-Encoding           | identity だけ。ヘッダーが無い場合は identity とみなす。それ以外は 415 `request.unsupported_media_type` (R-EP-C-020) |
| `Idempotency-Key` ヘッダー | 1 文字以上 255 文字以下の、印字可能な ASCII 文字列 (既定値・レビュー対象)                                           |
| 通知 ID (パス)             | 不透明な文字列。最大 64 文字で、使える文字は英数字・`-`・`_` (既定値・レビュー対象)                                 |
| `state` クエリ             | 3.6 の 4 つの状態名のいずれかと、小文字で過不足なく一致する値。複数回指定できる (R-EP-C-008、R-EP-C-011)            |

本表の長さの上限 (`title`・`body`・`url`・`Idempotency-Key`・通知 ID) は、Unicode のコードポイントの数で判定する (R-EP-C-040)。
件数・長さ・本文サイズの上限は、それぞれ独立に判定する (R-EP-C-041)。
各要素が件数と長さの上限を満たしていても、本文サイズの上限を超えれば `request.payload_too_large` で拒否する (R-EP-C-041)。複数の違反が同時に成立したときの応答は、R-EP-C-001 に従う。

本表の制約に違反したときの code は、制約の種類で分ける (3.10)。

- 本文の JSON の構造と値の制約 (要素数、必須メンバー、未知のメンバー、型・長さ・形式、本文に含めた通知 ID) と、`state` クエリ: `request.invalid`
- 本文サイズ: `request.payload_too_large`。Content-Encoding: `request.unsupported_media_type`
- `Idempotency-Key` ヘッダー: `idempotency.key_missing` または `idempotency.key_invalid`
- パスで指定した通知 ID (単体取得・キャンセル) が存在しない、または形式が不正: `notification.not_found`

バッチ登録の本文に通知 ID を含めることは送信の禁止 (R-EP-C-012) であり、`request.invalid` で拒否する。パスで既存の通知を指定して見つからない場合とは区別する。

### 3.6 States and Transition Rules

状態の集合 (DD-EP-08):

| State        | 意味                                                                                                                                                     | 終端   |
| ------------ | -------------------------------------------------------------------------------------------------------------------------------------------------------- | ------ |
| `scheduled`  | 登録済みで、OS への引き渡しの結果がまだ決まっていない。`fireAt` を過ぎていても、`dispatched` または `missed` に遷移するまではこの状態とする (R-EP-C-042) | いいえ |
| `dispatched` | 発火時刻に、Keneek が OS へ通知を引き渡した。画面への表示、およびユーザーの確認は、この状態の意味に含めない                                              | はい   |
| `missed`     | 発火時刻に、OS へ通知を引き渡せなかった                                                                                                                  | はい   |
| `cancelled`  | キャンセルが成功した。以後、OS へ引き渡されない                                                                                                          | はい   |

外部から観測できる状態遷移規則:

| 現在の状態   | 操作 / 契機                                         | 結果                                                                           |
| ------------ | --------------------------------------------------- | ------------------------------------------------------------------------------ |
| (なし)       | バッチ登録の成功                                    | 登録済み通知の状態は `scheduled`                                               |
| `scheduled`  | キャンセル                                          | 成功。状態は `cancelled`                                                       |
| `scheduled`  | `fireAt` を過ぎたが、引き渡しの結果が決まっていない | 状態は `scheduled` のまま。この間のキャンセルは R-EP-C-025 に従う (R-EP-C-042) |
| `scheduled`  | 発火時刻での引き渡しに成功                          | 状態は `dispatched`                                                            |
| `scheduled`  | 発火時刻での引き渡しに失敗                          | 状態は `missed`                                                                |
| `dispatched` | キャンセル                                          | 拒否 (`notification.not_cancellable`)。状態は変わらない                        |
| `missed`     | キャンセル                                          | 拒否 (`notification.not_cancellable`)。状態は変わらない                        |
| `cancelled`  | キャンセル                                          | 拒否 (`notification.not_cancellable`)。状態は変わらない                        |
| 終端状態     | (任意の遷移)                                        | 別の状態へは遷移しない                                                         |

引き渡しの検出や、状態の保持の内部の実現方法は定義しない。

### 3.7 Cancel Result Semantics

- キャンセルの成功は、「その通知が以後 OS へ引き渡されない」ことを意味する。
- キャンセルが成功したレスポンスは、状態が `cancelled` で `cancelledAt` を持つ通知を返す。
- キャンセルと発火時刻での引き渡しが競合したとき、観測される結果は次のどちらか一方に確定する。両方が成立することはない。
  - キャンセルが成功する (以後、引き渡されない)
  - キャンセルが拒否される (`notification.not_cancellable`)。通知は `dispatched` または `missed` になる

### 3.8 Resend Behavior

| 操作       | 再送時の振る舞い                                                                                                                                                                                                                                                                                                                                  |
| ---------- | ------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| バッチ登録 | `Idempotency-Key` が必須。再送時の振る舞いの正本は `specifications-idempotency.md` とする (キーの状態と応答は R-ID-C-201、成功結果の再現は R-ID-C-202、再送の条件は R-ID-C-302)                                                                                                                                                                   |
| 一覧取得   | 安全かつ冪等。再送してもサーバーの状態は変わらない                                                                                                                                                                                                                                                                                                |
| 単体取得   | 安全かつ冪等。再送してもサーバーの状態は変わらない                                                                                                                                                                                                                                                                                                |
| キャンセル | `Idempotency-Key` の対象外。成功後の再送は `notification.not_cancellable` となる。応答は成功・拒否・結果未確定の 3 つに分類する (R-EP-C-043)。結果未確定の応答や、その後の再送の `notification.not_cancellable` だけから、キャンセルの結果を判断しない (R-EP-C-044)。この 2 つの場合、クライアントは単体取得で状態を確認して判断する (R-EP-C-031) |

#### 3.8.1 Idempotency-Key States (バッチ登録)

本節の正本は `specifications-idempotency.md` とする。本節には、既存の参照を保つための対応だけを置く。

- キーの状態と応答: R-ID-C-201 (表)、R-ID-C-202〜R-ID-C-206
- 重複登録の防止の範囲と、記録の保持・失効・残留リスク: R-ID-C-101、R-ID-I-101〜R-ID-I-105
- クライアントの応答の分類、再送の条件、結果の確定、登録し直し: R-ID-C-301〜R-ID-C-306
- 停止と回復: R-ID-C-401、R-ID-I-401、R-ID-I-402
- 拒否の副作用、キー空間と認証 (issue #6) の境界: R-ID-C-501、R-ID-I-501、R-ID-I-502

保証の境界は `specifications-idempotency.md` 2.1 (IP-0) のとおりとする。

### 3.9 Batch Atomicity

バッチ登録の結果は、成功・`4xx` の失敗・結果未確定の 3 つの区分のいずれか 1 つとして観測される。
結果未確定は、`5xx`、共通エラー形式でないエラー応答、上のどれにも当てはまらない応答、応答なしを含む。下の表では、観測される形ごとに行を分ける。
分類の正本は `specifications-idempotency.md` R-ID-C-301 とする (R-EP-C-037)。
クライアントが「その送信は登録していない」と判断できる `4xx` は、API が生成した、`code` を持つ共通エラー形式の応答に限る。
プロキシなどが返した共通エラー形式でない `4xx` は、結果未確定として扱う (`specifications-errors.md` R-ER-C-042、DR-06 決定 9)。

| 観測される結果            | 保証                                                                                                                                                                                                                                                                                                         |
| ------------------------- | ------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------ |
| 成功                      | リクエストに含まれる通知が、すべて登録されている。レスポンスは入力の各要素と 1 対 1・同順で対応する                                                                                                                                                                                                          |
| 失敗 (API が返した `4xx`) | 単一のエラーを返す。そのリクエストによる新規登録は 1 件も残っていない。その送信では登録されなかったことを示す。論理操作 (UD-031) の登録なしの確定 (UD-043。UD-ID の正本は `universal-dictionary.md`、対応は `specifications-idempotency.md` 3.1) は、`specifications-idempotency.md` R-ID-C-303 の条件による |
| 結果未確定 (`5xx`)        | 単一のエラーを返す。そのリクエストの通知は、すべて登録されているか 1 件も登録されていないかのどちらかであり、一部の要素だけが登録された状態は残らない。どちらであるかはクライアントにとって確定しない (結果未確定)。再送の条件と結果の扱いは `specifications-idempotency.md` R-ID-C-301〜R-ID-C-304 に従う   |
| 結果未確定 (その他の応答) | 共通エラー形式でないエラー応答 (4xx・5xx)、または上のどれにも当てはまらない応答 (契約に適合しない 2xx など)。この応答だけでは結果を確定できない (R-EP-C-037、R-ID-C-301)。再送の条件と結果の扱いは R-ID-C-301〜R-ID-C-304 に従う                                                                             |
| 結果未確定 (応答なし)     | レスポンスを受け取れない (応答の喪失、タイムアウト)。API が返した `4xx` の失敗と区別し、結果が確定しない場合として扱う。再送の条件と結果の扱いは R-ID-C-301〜R-ID-C-304 に従う                                                                                                                               |

保証は、そのリクエストによる新規登録だけに及ぶ。既存の通知は、バッチ登録の成功・失敗のいずれでも削除されず、変更されない。

### 3.10 Input Rejection Conditions

入力を拒否する条件と、使う code を定義する。code の値・type・ステータス・対処方針は `specifications-errors.md` が定義する。
成功が確定したキーへの同じ本文の再送で 201 を再現すること (R-EP-C-028、`specifications-errors.md` R-ER-C-009) は拒否ではないため、本表に含めない。

| 条件                                                                                                                                                                                                                                                             | 使う code                        |
| ---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- | -------------------------------- |
| 登録リクエストの本文が、JSON の構造と値の検証制約に違反する (空配列、件数の上限超過、必須メンバーの欠落、未知のメンバー、型・長さ・形式の不正、送信が禁止された通知 ID を本文に含める)。本文サイズ、Content-Encoding、`Idempotency-Key` ヘッダーの違反は含まない | `request.invalid`                |
| 本文が JSON として解釈できない                                                                                                                                                                                                                                   | `request.invalid`                |
| `state` クエリに 4 つの状態名以外の値がある                                                                                                                                                                                                                      | `request.invalid`                |
| `Idempotency-Key` が欠落している                                                                                                                                                                                                                                 | `idempotency.key_missing`        |
| `Idempotency-Key` の形式が不正である                                                                                                                                                                                                                             | `idempotency.key_invalid`        |
| 成功が確定したキーに、別の本文が送られた (`specifications-idempotency.md` R-ID-C-203)                                                                                                                                                                            | `idempotency.key_conflict`       |
| 処理中または回復待ちのキーに送られた。本文が同じでも異なっても同じ。入力内容が不正なら `request.invalid` が先 (R-ID-C-204、R-ID-C-205)                                                                                                                           | `server.unavailable`             |
| 通知 ID が存在しない、または形式が不正である (単体取得・キャンセル)                                                                                                                                                                                              | `notification.not_found`         |
| `scheduled` 以外の状態の通知をキャンセルする                                                                                                                                                                                                                     | `notification.not_cancellable`   |
| 未認証                                                                                                                                                                                                                                                           | `auth.unauthenticated`           |
| 認証済みだが、その操作を認可されていない                                                                                                                                                                                                                         | `auth.forbidden`                 |
| サーバー内部でエラーが発生した                                                                                                                                                                                                                                   | `server.internal`                |
| 未知のパス                                                                                                                                                                                                                                                       | `request.route_not_found`        |
| 許可されないメソッド                                                                                                                                                                                                                                             | `request.method_not_allowed`     |
| `Content-Type` が `application/json` でない、または Content-Encoding が identity 以外である (本文を伴う操作)                                                                                                                                                     | `request.unsupported_media_type` |
| 本文サイズが上限を超える                                                                                                                                                                                                                                         | `request.payload_too_large`      |

### 3.11 Boundary of Internal Realization

本契約は、バッチの原子性・冪等性・重複排除・状態遷移・バリデーションの判定・認証・永続化を、内部でどう実現するかを定義しない。
定義するのは、クライアントが観測できる結果だけとする (R-EP-I-001)。

---

## 4. Decision Rules

<!--
Rule ID format:
  R-EP-C-NNN  契約として確定すべき事項 (sequential, stable)
  R-EP-I-NNN  実装で保証すべき事項 (sequential, stable)
  R-EP-X-NNN  将来の拡張案 (sequential, stable。規範ではない)
旧 R-EP-NNN は 4.4 の対応表のとおり廃止し、再利用しない。
Rule IDs are referenced in Traceability and Edge Cases.
-->

本章は、規則を次の 3 つに分類する。分類は規則の拘束力を変えない。
v2.0.0 の時点で、規則の文言は、ID の参照を除いて v1.1.2 の R-EP-NNN から変えていない。
1 つの規則が 2 つの分類にまたがる R-EP-061 と R-EP-081 だけは、分類ごとに文を分けた (4.4)。
v2.1.0 以降の規則の改訂と追加は、8 章に記す。

| 分類                     | ID           | 基準                                                                                                                                    |
| ------------------------ | ------------ | --------------------------------------------------------------------------------------------------------------------------------------- |
| 契約として確定すべき事項 | `R-EP-C-NNN` | クライアントが送るもの・受け取るもの、応答の意味と分類、クライアントの義務。個々のリクエストとレスポンスで観測できる                    |
| 実装で保証すべき事項     | `R-EP-I-NNN` | サーバーが内部で維持しなければならない性質。個々のレスポンスからは直接観測できない。実現方法は契約に定めない (DR-03 決定 2、R-EP-I-001) |
| 将来の拡張案             | `R-EP-X-NNN` | v1 の範囲外であることを、本書または DR が明示しているもの。規範ではない。v1 の振る舞いは、参照先の R-EP-C が定める                      |

R-EP-C のうちクライアントの義務 (R-EP-C-013、R-EP-C-034、R-EP-C-044 など) は、サーバーの応答からは観測できない。これらはクライアント実装の適合性で検証する。

分類 (C/I/X) と、兄弟 issue との照合の状態は、別々の軸とする。分類の基準は `specifications-index.md` 4.1 に合わせる。

- 照合の状態は、7 章 #7 の照合の項目と `specifications-governance.md` 3.3.3 の照合の記録で管理する (DR-05)。R-EP-C と R-EP-I のどちらも照合の対象になり得る。
- 照合待ちの規則とは、7 章 #7 の照合の項目に挙がり、照合結果 (UD-028) がまだ「整合」になっていない規則をいう。
- 照合待ちの規則も、本書の規則として有効であり、拘束力を持つ。照合待ちであることは、規則を無効にしない。
- 照合待ちの規則は、照合が済むまで、契約として確定した保証とはしない (DR-05)。照合の結果によっては、規則を改訂する。
- 照合待ちの規則と 7 章 #7 の項目の対応は、R-EP-C を 4.1 の冒頭に、R-EP-I を 4.2 の「照合」列に示す。

### 4.1 契約として確定すべき事項 (R-EP-C)

次の R-EP-C は照合待ちである (7 章 #7)。照合待ちの扱いは 4 章冒頭のとおりとする。

| 照合 (7 章 #7) | 照合待ちの R-EP-C                  |
| -------------- | ---------------------------------- |
| (b-1)          | R-EP-C-028, R-EP-C-029             |
| (b-2)          | R-EP-C-031〜R-EP-C-033             |
| (c-1)          | R-EP-C-035〜R-EP-C-038             |
| (d-1)          | R-EP-C-021〜R-EP-C-023, R-EP-C-042 |
| (d-2)          | R-EP-C-024, R-EP-C-025             |

R-EP-C-031 のうち、キャンセルの結果を単体取得で確認する部分 (DR-09 決定 4) は、本表の (b-2) の対象ではない。
この部分の信頼性は 7 章 #28 の決定に依存する (R-EP-C-031 の本文、7 章 #28)。
R-EP-C-043 と R-EP-C-044 は、7 章 #7 の照合の項目に含まれないため、本表に載せない。
応答を受け取れないときの対処の保証 (`specifications-governance.md` G-15) との対応は、記録されていない (未確認)。
7 章 #28 の決定後に再確認する規則は、7 章 #28 と 7 章 #31 に挙げる。
7 章 #28 には R-EP-C-031・R-EP-C-044 を、7 章 #31 には R-EP-C-035・R-EP-C-036・R-EP-I-006・R-EP-I-007 を挙げている。

一覧取得・単体取得の結果の位置づけを、次に示す。この注記は規範ではなく、新しい義務を加えない。

- 状態の参照: 一覧取得と単体取得は、通知の状態を参照する手段であり、この注記はその利用を制限しない。取得が返す状態の契約 (R-EP-C-042 など) も変えない。
- 参考情報: 取得の結果は、クライアントが次の操作を選ぶための参考情報として使える。R-EP-C-031 の確認は、この使い方の 1 つである。
- 確定の保証との区別: 成功応答の結果が後の取得に反映される時期は、7 章 #28 で未決定である。
  そのため本契約は、取得の結果だけで R-EP-C-035・R-EP-C-036・R-EP-I-006・R-EP-I-007 の保証の成否を断定できることを、保証しない。

この注記は、7 章 #28 の決定後に見直す。

#### 4.1.1 Response Precedence

| Rule ID    | Rule                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                |
| ---------- | ----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| R-EP-C-001 | 本ファイルの 4 操作で複数のエラー条件が同時に成立したときの外部応答は、`specifications-errors.md` 4.1 の優先順位に従うこと (MUST)。本ファイルは優先順位を再定義しない (DD-EP-06)。成功結果の早期応答 (`specifications-errors.md` R-ER-C-009) は、4.1 の Step 1〜8 の検査を通過した送信に限って成立する。Step 1〜8 で拒否される送信 (未認証の 401 など) には、その拒否の応答を返す。優先順位に対する例外は、この早期応答だけとする (DR-06 決定 6)。形式が不正な通知 ID は、存在しない ID と同じ「リソース状態」の段で扱う (DD-EP-07) |

#### 4.1.2 Operations

| Rule ID    | Rule                                                                                                                                                                                                                             |
| ---------- | -------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| R-EP-C-002 | バッチ登録は、`POST /v1/notifications` で受け付け、成功時は 201 を返す。リクエストは `Idempotency-Key` ヘッダーと `notifications` 配列を持つこと (MUST)                                                                          |
| R-EP-C-003 | バッチ登録の成功レスポンスは、入力の各要素に 1 対 1 で、入力と同じ順序・同じ件数の登録済み通知を `notifications` 配列に持つこと (MUST)。レスポンスの形状は成功と失敗の 2 つだけとし、部分成功を表す形状を持たないこと (MUST NOT) |
| R-EP-C-004 | 一覧取得は、`GET /v1/notifications` で受け付け、成功時は 200 と登録済み通知の `notifications` 配列を返すこと (MUST)。該当が 0 件のときは空配列を返すこと (MUST)                                                                  |
| R-EP-C-005 | 単体取得は、`GET /v1/notifications/{id}` で受け付け、成功時は 200 と登録済み通知 1 件を返すこと (MUST)。存在しない ID、および形式が不正な ID は、同じく `notification.not_found` で拒否すること (MUST)                           |
| R-EP-C-006 | キャンセルは、`POST /v1/notifications/{id}/cancel` で受け付け、成功時は 200 とキャンセル後の登録済み通知を返すこと (MUST)。存在しない ID、および形式が不正な ID は `notification.not_found` で拒否すること (MUST)                |
| R-EP-C-007 | 4 つの操作は、すべて認証を必要とすること (MUST)。未認証は `auth.unauthenticated`、認可されていない場合は `auth.forbidden` で拒否すること (MUST)。通知を所有者ごとに分離しないこと (MUST NOT)                                     |

#### 4.1.3 List

| Rule ID    | Rule                                                                                                                                                                                                                                                                                                                                        |
| ---------- | ------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| R-EP-C-008 | 一覧取得は、省略可能な `state` クエリを受け付けること (MUST)。複数回の指定を許し、指定された状態のいずれかに一致する通知を返すこと (MUST)。省略時は、すべての状態の通知を返すこと (MUST)                                                                                                                                                    |
| R-EP-C-009 | 一覧の並びは、`fireAt` を UTC に直した時刻の昇順とすること (MUST)。時刻が同じ通知は、`id` を Unicode のコードポイントの順で比べた昇順とすること (MUST)。送られたオフセットの書き方によって順序を変えないこと (MUST NOT) (DR-07 決定 1)                                                                                                      |
| R-EP-C-010 | 一覧取得は、ページングを持たず、該当する全件を返すこと (MUST)。絞り込みは `state` クエリだけとする                                                                                                                                                                                                                                          |
| R-EP-C-011 | `state` クエリの各値は、3.6 の 4 つの状態名のどれかと、小文字で過不足なく一致しなければならない (MUST)。一致しない値 (空の値、区切り文字を含む値 (`scheduled,missed` など)、大文字を含む値を含む) があるときは、`request.invalid` で拒否すること (MUST)。同じ値が重複して指定されたときは、1 回の指定と同じに扱うこと (MUST) (DR-07 決定 3) |

#### 4.1.4 Data Shape and Schema

| Rule ID    | Rule                                                                                                                                                                                                                                                                                                                                                                                                                                                                                      |
| ---------- | ----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| R-EP-C-012 | 通知 ID は、サーバーが採番すること (MUST)。クライアントは ID を送らないこと (MUST NOT)。登録リクエストの要素に ID があるときは、`request.invalid` で拒否すること (MUST)                                                                                                                                                                                                                                                                                                                   |
| R-EP-C-013 | 通知 ID は不透明な文字列とし、クライアントは形式を解釈しないこと (MUST NOT)。契約が定めるのは、最大長と使える文字だけとする                                                                                                                                                                                                                                                                                                                                                               |
| R-EP-C-014 | `fireAt`、`createdAt`、`cancelledAt` は、RFC 3339 の日時で、UTC オフセットを含むこと (MUST)。オフセットのない日時は、`request.invalid` で拒否すること (MUST)                                                                                                                                                                                                                                                                                                                              |
| R-EP-C-015 | 登録済み通知は、3.4 のメンバーを持つこと (MUST)。`cancelledAt` は `state` が `cancelled` のときだけ持つこと (MUST)。すべてのレスポンスの通知は、同一の形状に従うこと (MUST)                                                                                                                                                                                                                                                                                                               |
| R-EP-C-016 | 繰り返し通知は、v1 で扱わないこと (MUST NOT)。1 件の通知は、1 つの `fireAt` だけを持つ                                                                                                                                                                                                                                                                                                                                                                                                    |
| R-EP-C-017 | `notifications.schema.json` は、JSON Schema Draft 2020-12 を `$schema` で宣言し、OpenAPI を使わずに単独で検証できること (MUST)                                                                                                                                                                                                                                                                                                                                                            |
| R-EP-C-018 | `notifications.schema.json` は、`$defs` で登録リクエストと登録済み通知を区別し、3.5 の検証制約のうち、本文の JSON の構造と値の制約を定義すること (MUST)                                                                                                                                                                                                                                                                                                                                   |
| R-EP-C-019 | OpenAPI は、バッチ登録の requestBody と各レスポンスを、`notifications.schema.json` の該当する `$defs` への相対 `$ref` で参照し、定義を複製しないこと (MUST)。参照は、ネットワーク接続なしで解決できること (MUST)                                                                                                                                                                                                                                                                          |
| R-EP-C-045 | `notifications.schema.json` は、`$defs` で、登録リクエストの本文、登録済み通知、応答本文の 3 つを区別して定義すること (MUST)。登録リクエストの本文は、`notifications` を必須メンバーとして持ち、ほかのメンバーを拒否するオブジェクトとする。応答本文は、一覧取得とバッチ登録の成功レスポンスの本文であり、登録済み通知の配列を `notifications` メンバーに持つオブジェクトとする (DD-EP-02、R-EP-C-003、R-EP-C-004)。応答本文が未知のメンバーを含み得るかは、本規則では定めない (7 章 #23) |
| R-EP-C-020 | 本文を伴う操作の Content-Encoding は identity だけとすること (MUST)。ヘッダーが無い場合は identity とみなし、クライアントに identity の明示を求めないこと (MUST NOT)。identity 以外は `request.unsupported_media_type` で拒否すること (MUST)。付けるヘッダーは `specifications-errors.md` R-ER-C-025 に従う (DR-06 決定 11)                                                                                                                                                               |
| R-EP-C-040 | 3.5 の長さの上限は、Unicode のコードポイントの数で判定すること (MUST)。UTF-16 のコードユニットの数やバイト数で判定しないこと (MUST NOT) (DR-07 決定 2)                                                                                                                                                                                                                                                                                                                                    |
| R-EP-C-041 | 件数・長さ・本文サイズの上限は、それぞれ独立に判定すること (MUST)。各要素が件数と長さの上限を満たしていても、本文サイズが上限を超えれば `request.payload_too_large` で拒否すること (MUST)。複数の違反が同時に成立したときの応答は、R-EP-C-001 に従う (DR-07 決定 4)                                                                                                                                                                                                                       |

#### 4.1.5 State and Cancel

| Rule ID    | Rule                                                                                                                                                                                                                                                                                        |
| ---------- | ------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| R-EP-C-021 | 通知の状態は、`scheduled`・`dispatched`・`missed`・`cancelled` のいずれか 1 つとすること (MUST)。`dispatched`・`missed`・`cancelled` は終端状態とし、別の状態へ遷移しないこと (MUST NOT)                                                                                                    |
| R-EP-C-022 | `dispatched` は、発火時刻に OS へ通知を引き渡したことだけを意味すること (MUST)。画面への表示、およびユーザーの確認を意味に含めないこと (MUST NOT)                                                                                                                                           |
| R-EP-C-023 | 状態の遷移は、3.6 の表に従うこと (MUST)。登録に成功した通知の状態は `scheduled` とすること (MUST)                                                                                                                                                                                           |
| R-EP-C-024 | キャンセルは、`scheduled` の通知だけを受け付けること (MUST)。`cancelled`・`dispatched`・`missed` の通知は、`notification.not_cancellable` で拒否すること (MUST)                                                                                                                             |
| R-EP-C-025 | キャンセルと引き渡しが競合したとき、キャンセルの成功か `notification.not_cancellable` による拒否のどちらか一方に確定すること (MUST)。キャンセルが成功した通知を以後 OS へ引き渡さないことは、R-EP-I-007 が定める                                                                            |
| R-EP-C-026 | WHEN キャンセルが成功した後に、そのキャンセルを再送したとき、`notification.not_cancellable` となること (MUST)。キャンセルは `Idempotency-Key` の対象外とすること                                                                                                                            |
| R-EP-C-042 | WHEN `scheduled` の通知が `fireAt` を過ぎ、`dispatched` にも `missed` にも遷移していないとき、その通知は `scheduled` として観測されること (MUST)。その間のキャンセルは、R-EP-C-025 に従い、成功か `notification.not_cancellable` による拒否のどちらか一方に確定する (DR-08)                 |
| R-EP-C-043 | キャンセルの応答は、次の 3 つに分類すること (MUST)。成功: 契約に適合する 200。拒否: API が生成した、`code` を持つ共通エラー形式の 4xx。結果未確定: 5xx、共通エラー形式でないエラー応答、契約に適合しない応答、応答なし。分類はバッチ登録の応答の分類 (R-EP-C-037) にそろえる (DR-09 決定 1) |
| R-EP-C-044 | クライアントは、結果未確定の応答から、キャンセルの成功や失敗を判断しないこと (MUST NOT)。結果未確定の後の再送が `notification.not_cancellable` で拒否されたことだけを根拠に、最初のキャンセルが失敗したと判断しないこと (MUST NOT) (DR-09 決定 2・決定 3)                                   |

#### 4.1.6 Resend

| Rule ID    | Rule                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                      |
| ---------- | ------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| R-EP-C-027 | バッチ登録は、`Idempotency-Key` ヘッダーを必須とすること (MUST)。欠落は `idempotency.key_missing`、形式の不正は `idempotency.key_invalid` で拒否すること (MUST)                                                                                                                                                                                                                                                                                                                                                           |
| R-EP-C-028 | 成功が確定したキーへの同じ本文の再送には、`specifications-idempotency.md` R-ID-C-202 のとおり、初回の 201 と本文の写しを返すこと (MUST) (DD-EP-12)                                                                                                                                                                                                                                                                                                                                                                        |
| R-EP-C-029 | `idempotency.key_conflict` の条件は、`specifications-idempotency.md` R-ID-C-203 に従うこと (MUST)                                                                                                                                                                                                                                                                                                                                                                                                                         |
| R-EP-C-030 | 一覧取得と単体取得は、安全かつ冪等であること (MUST)。再送によってサーバーの状態を変えないこと (MUST NOT)                                                                                                                                                                                                                                                                                                                                                                                                                  |
| R-EP-C-031 | バッチ登録で `5xx` (503 を含む) を受け取ったとき、またはレスポンスを受け取れなかったとき、クライアントは登録されなかったことの確定とみなさないこと (MUST NOT)。再送の条件と結果の確定は、`specifications-idempotency.md` R-ID-C-301〜R-ID-C-304 に従う。WHEN キャンセルの応答が結果未確定だった (R-EP-C-043)、または結果未確定の後の再送が `notification.not_cancellable` で拒否されたとき、単体取得で状態を確認して判断すること (SHOULD)。この確認の信頼性は 7 章 #28 の決定に依存するため、MUST にしない (DR-09 決定 4) |
| R-EP-C-032 | 未記録または登録なしが確定 (サーバー側で把握) のキーへの送信と、同じ登録の意図の登録し直しは、`specifications-idempotency.md` R-ID-C-201 と R-ID-C-305 に従うこと (MUST)                                                                                                                                                                                                                                                                                                                                                  |
| R-EP-C-033 | 処理中または回復待ちのキーへの送信は、`specifications-idempotency.md` R-ID-C-204 と R-ID-C-205 に従うこと (MUST)                                                                                                                                                                                                                                                                                                                                                                                                          |
| R-EP-C-034 | 「同じ本文」の判定は、`specifications-idempotency.md` R-ID-C-206 に従うこと (MUST)。クライアントは、再送で初回と同じバイト列を送ること (MUST)                                                                                                                                                                                                                                                                                                                                                                             |

#### 4.1.7 Batch Result and Rejection

| Rule ID    | Rule                                                                                                                                                                                                                                                                                                                                                                                                                            |
| ---------- | ------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| R-EP-C-035 | バッチ登録が成功レスポンスを返したとき、そのリクエストに含まれる通知は、すべて登録されていること (MUST)                                                                                                                                                                                                                                                                                                                         |
| R-EP-C-036 | WHEN バッチ登録が、API が生成した共通エラー形式の `4xx` (UD-018) の失敗レスポンスを返したとき、そのリクエストによる新規登録は 1 件も残っていないこと (MUST)。`5xx` の失敗レスポンスを返したとき、そのリクエストの通知がすべて登録されているか 1 件も登録されていないか (R-EP-I-006) のどちらであるかは、クライアントにとって確定しない。失敗レスポンスは、共通エラー形式の単一のエラーとし、要素ごとの結果を含まないこと (MUST) |
| R-EP-C-037 | 応答の分類は、`specifications-idempotency.md` R-ID-C-301 に従うこと (MUST)。`5xx`、共通エラー形式でないエラー応答、上のどれにも当てはまらない応答、応答なしは、この応答だけでは結果を確定できないものとして扱う。確定済みの成功の確定 (クライアント) は変えない (R-ID-C-304)。結果の確定の試みは R-ID-C-302〜R-ID-C-304 に従い、確定は保証しない (R-ID-C-401)                                                                   |
| R-EP-C-038 | R-EP-C-035、R-EP-C-036、R-EP-I-006 の保証は、そのリクエストによる新規登録だけに及ぶこと (MUST)。既存の通知の削除や変更を求めないこと (MUST NOT)                                                                                                                                                                                                                                                                                 |
| R-EP-C-039 | 入力を拒否する条件と、拒否に使う code は、3.10 の表に従うこと (MUST)。code の定義そのものは、`specifications-errors.md` を参照すること (MUST)                                                                                                                                                                                                                                                                                   |

### 4.2 実装で保証すべき事項 (R-EP-I)

本節の規則も、契約として拘束力を持つ (MUST)。契約が定めるのは、外部から観測される結果としての性質だけとする。どう実現するかは定めない (R-EP-I-001)。
「照合」列は、7 章 #7 の照合の項目を示す。照合が済むまで、確定した保証として扱わない (DR-05)。照合待ちの扱いは 4 章冒頭のとおりとする。

| Rule ID    | Rule                                                                                                                                                                                                                                                                   | 照合 (7 章 #7) |
| ---------- | ---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- | -------------- |
| R-EP-I-001 | 本契約は、登録処理の原子性の実現方法、冪等性・重複排除の実現方法、バリデーションの判定アルゴリズム、照会・キャンセルの判定アルゴリズム、状態遷移の内部の実現方法、認証メカニズムの内部実装、永続化を、定義しないこと (MUST NOT)                                        | —              |
| R-EP-I-002 | 成功の記録の保持は、`specifications-idempotency.md` R-ID-I-103 に従うこと (MUST)。結果の確定していないキーの扱いは R-ID-I-104 に従う                                                                                                                                   | (a)            |
| R-EP-I-003 | 同じキーの排他性と、保持の保証が有効な間の登録の回数は、`specifications-idempotency.md` R-ID-I-101 と R-ID-I-102 に従うこと (MUST)                                                                                                                                     | (b-2)          |
| R-EP-I-004 | 登録の確定と成功結果の記録の成立は、`specifications-idempotency.md` R-ID-I-401 に従うこと (MUST)                                                                                                                                                                       | (c-2)          |
| R-EP-I-005 | 結果の確定していないキーの扱いと、停止後の回復は、`specifications-idempotency.md` R-ID-C-401、R-ID-I-104、R-ID-I-402 に従うこと (MUST)                                                                                                                                 | (c-2)          |
| R-EP-I-006 | バッチ登録が `5xx` の失敗レスポンスを返したとき、そのリクエストの通知は、すべて登録されているか 1 件も登録されていないかのどちらかとし、一部の要素だけが登録された状態を残さないこと (MUST)。どちらであるかがクライアントにとって確定しないことは、R-EP-C-036 が定める | (c-1)          |
| R-EP-I-007 | キャンセルが成功した通知は、以後 OS へ引き渡されないこと (MUST)。キャンセルと引き渡しの競合の確定は、R-EP-C-025 が定める                                                                                                                                               | (d-2)          |

### 4.3 将来の拡張案 (R-EP-X)

本節は規範ではない。v1 の振る舞いは「v1 の契約」列の規則が定める。

| ID         | 拡張の対象                                                       | v1 の契約                                                      | 根拠                                                    | 関連                               |
| ---------- | ---------------------------------------------------------------- | -------------------------------------------------------------- | ------------------------------------------------------- | ---------------------------------- |
| R-EP-X-001 | 一覧取得のページングと、`state` 以外の絞り込み                   | ページングを持たず、絞り込みは `state` だけ (R-EP-C-010)       | DD-EP-09 (省略可能なクエリは、後から追加しても後方互換) | 7 章 #22 (一覧が大きくなるリスク)  |
| R-EP-X-002 | 繰り返し通知                                                     | 扱わない。1 件の通知は 1 つの `fireAt` だけを持つ (R-EP-C-016) | 2.2                                                     | —                                  |
| R-EP-X-003 | identity 以外の Content-Encoding                                 | identity だけ (R-EP-C-020)                                     | DR-06 決定 11 (v1 が扱うのは identity だけ)             | —                                  |
| R-EP-X-004 | 通知の更新 (内容の変更、再スケジュール) と、終端状態の通知の削除 | 4 操作に含まれない (3.3)                                       | DR-06 決定 16 (更新操作は別の契約で定める)              | 7 章 #22 (v1 の対象外と明記するか) |

- レスポンスへのメンバーの追加が後方互換になるかは、7 章 #23 で未決定である。
- 状態の追加は破壊的変更になるため、拡張案に含めない (DD-EP-08)。

### 4.4 Rule ID Mapping (v1.1.2 → v2.0.0)

旧 ID は廃止し、再利用しない。8 章の 1.1.2 以前の行は、旧 ID のまま記す。

| 旧 ID              | 新 ID                  | 備考                                                           |
| ------------------ | ---------------------- | -------------------------------------------------------------- |
| R-EP-001           | R-EP-C-001             |                                                                |
| R-EP-002〜R-EP-005 | —                      | v1.1.2 で欠番 (優先順位を `specifications-errors.md` に一本化) |
| R-EP-010           | R-EP-C-002             |                                                                |
| R-EP-011           | R-EP-C-003             |                                                                |
| R-EP-012           | R-EP-C-004             |                                                                |
| R-EP-013           | R-EP-C-005             |                                                                |
| R-EP-014           | R-EP-C-006             |                                                                |
| R-EP-015           | R-EP-C-007             |                                                                |
| R-EP-020           | R-EP-C-008             |                                                                |
| R-EP-021           | R-EP-C-009             |                                                                |
| R-EP-022           | R-EP-C-010             | 拡張案は R-EP-X-001                                            |
| R-EP-023           | R-EP-C-011             |                                                                |
| R-EP-030           | R-EP-C-012             |                                                                |
| R-EP-031           | R-EP-C-013             |                                                                |
| R-EP-032           | R-EP-C-014             |                                                                |
| R-EP-033           | R-EP-C-015             |                                                                |
| R-EP-034           | R-EP-C-016             | 拡張案は R-EP-X-002                                            |
| R-EP-040           | R-EP-C-017             |                                                                |
| R-EP-041           | R-EP-C-018             |                                                                |
| R-EP-042           | R-EP-C-019             |                                                                |
| R-EP-043           | R-EP-C-020             | 拡張案は R-EP-X-003                                            |
| R-EP-050           | R-EP-C-021             |                                                                |
| R-EP-051           | R-EP-C-022             |                                                                |
| R-EP-052           | R-EP-C-023             |                                                                |
| R-EP-060           | R-EP-C-024             |                                                                |
| R-EP-061           | R-EP-C-025、R-EP-I-007 | 分割: 競合の確定 (C)、キャンセル後に引き渡さない (I)           |
| R-EP-062           | R-EP-C-026             |                                                                |
| R-EP-070           | R-EP-C-027             |                                                                |
| R-EP-071           | R-EP-C-028             |                                                                |
| R-EP-072           | R-EP-C-029             |                                                                |
| R-EP-073           | R-EP-I-002             |                                                                |
| R-EP-074           | R-EP-C-030             |                                                                |
| R-EP-075           | R-EP-C-031             |                                                                |
| R-EP-076           | R-EP-C-032             |                                                                |
| R-EP-077           | R-EP-C-033             |                                                                |
| R-EP-078           | R-EP-I-004             |                                                                |
| R-EP-079           | R-EP-I-003             |                                                                |
| R-EP-080           | R-EP-C-035             |                                                                |
| R-EP-081           | R-EP-C-036、R-EP-I-006 | 分割: 応答の意味と結果の不確定 (C)、5xx の原子性 (I)           |
| R-EP-082           | R-EP-C-037             |                                                                |
| R-EP-083           | R-EP-C-038             |                                                                |
| R-EP-084           | R-EP-I-005             |                                                                |
| R-EP-085           | R-EP-C-034             |                                                                |
| R-EP-090           | R-EP-C-039             |                                                                |
| R-EP-091           | R-EP-I-001             |                                                                |

---

## 5. Edge Cases

| Input                                                                 | Classification                                                                                                                           | REQ                  | Rationale                                                                                       |
| --------------------------------------------------------------------- | ---------------------------------------------------------------------------------------------------------------------------------------- | -------------------- | ----------------------------------------------------------------------------------------------- |
| 未認証のリクエスト (存在しない ID・不正な本文を含む)                  | `auth.unauthenticated` (R-EP-C-001、`specifications-errors.md` R-ER-C-001)                                                               | REQ-F-001, REQ-F-007 | 認証が最優先であり、404 や 409 などの詳細を開示しない (`specifications-errors.md` R-ER-C-017)   |
| `notifications` が空配列                                              | `request.invalid` (R-EP-C-039)                                                                                                           | REQ-F-002            | 要素数は 1 以上                                                                                 |
| `notifications` が 100 件を超える                                     | `request.invalid` (R-EP-C-039)                                                                                                           | REQ-F-002            | 要素数の上限 (既定値・レビュー対象)                                                             |
| 要素に `id` を含む                                                    | `request.invalid` (R-EP-C-012)                                                                                                           | REQ-F-005            | ID はサーバーが採番する (DD-EP-03)                                                              |
| `fireAt` にオフセットがない                                           | `request.invalid` (R-EP-C-014)                                                                                                           | REQ-F-005            | 発火時刻はオフセット付きの RFC 3339                                                             |
| 本文が JSON でない                                                    | `request.invalid` (R-EP-C-039)                                                                                                           | REQ-F-007            | 入力の拒否は、外部から観測できる判定結果                                                        |
| `Content-Type` が `application/json` でない                           | `request.unsupported_media_type` (R-EP-C-039)                                                                                            | REQ-F-007            | 優先順位は、入力検証より前                                                                      |
| Content-Encoding が gzip などの identity 以外                         | `request.unsupported_media_type` (R-EP-C-020)                                                                                            | REQ-F-007            | v1 は identity だけ (DR-06 決定 11)                                                             |
| 本文が 1 MiB を超える                                                 | `request.payload_too_large` (R-EP-C-039)                                                                                                 | REQ-F-007            | 本文サイズの上限 (既定値・レビュー対象)                                                         |
| `fireAt` が RFC 3339 の日時の形式でない                               | `request.invalid` (R-EP-C-039)                                                                                                           | REQ-F-005            | 発火時刻の形式 (3.5)                                                                            |
| `title`・`body`・`url` が長さの上限を超える                           | `request.invalid` (R-EP-C-039)                                                                                                           | REQ-F-002            | 長さの上限 (既定値・レビュー対象)。Unicode のコードポイントの数で判定する (R-EP-C-040)          |
| 各要素は件数と長さの上限を満たすが、本文が 1 MiB を超える             | `request.payload_too_large` (R-EP-C-041)                                                                                                 | REQ-F-002            | 上限はそれぞれ独立に判定する。本文のバイト数はコードポイントの数から決まらない (DR-07)          |
| `Idempotency-Key` がない                                              | `idempotency.key_missing` (R-EP-C-027)                                                                                                   | REQ-F-007            | バッチ登録では必須 (DD-EP-05)                                                                   |
| `Idempotency-Key` の形式が不正                                        | `idempotency.key_invalid` (R-EP-C-027)                                                                                                   | REQ-F-007            | キーの形式 (3.5。既定値・レビュー対象)                                                          |
| 一覧に該当が 0 件                                                     | 200 と空配列 (R-EP-C-004)                                                                                                                | REQ-F-001            | 空は正常な結果                                                                                  |
| `state=scheduled&state=missed`                                        | いずれかに一致する通知を返す (R-EP-C-008)                                                                                                | REQ-F-001            | 複数指定は、和集合                                                                              |
| `state=unknown`                                                       | `request.invalid` (R-EP-C-011)                                                                                                           | REQ-F-001            | 状態名は 4 つに限る                                                                             |
| `state=` (空の値)                                                     | `request.invalid` (R-EP-C-011)                                                                                                           | REQ-F-001            | 4 つの状態名のどれとも一致しない (DR-07 決定 3)                                                 |
| `state=scheduled,missed`                                              | `request.invalid` (R-EP-C-011)                                                                                                           | REQ-F-001            | 複数の指定は、複数回の指定だけで表す (R-EP-C-008)                                               |
| `state=Scheduled`                                                     | `request.invalid` (R-EP-C-011)                                                                                                           | REQ-F-001            | 値は小文字だけ                                                                                  |
| `state=scheduled&state=scheduled`                                     | 1 回の指定と同じ結果を返す (R-EP-C-011)                                                                                                  | REQ-F-001            | 重複は和集合                                                                                    |
| 同じ時刻の `fireAt` を異なるオフセットで登録した複数の通知            | 一覧では同じ時刻として並び、`id` の順になる (R-EP-C-009)                                                                                 | REQ-F-001            | UTC に直して比べる (DR-07 決定 1)                                                               |
| `fireAt` を過ぎ、引き渡しの結果が決まっていない通知の取得・キャンセル | 状態は `scheduled`。キャンセルは成功か `notification.not_cancellable` のどちらか一方 (R-EP-C-042, R-EP-C-025)                            | REQ-F-005, REQ-F-007 | 状態の集合を変えない (DR-08、DD-EP-08)                                                          |
| 存在しない ID の単体取得・キャンセル                                  | `notification.not_found` (R-EP-C-005, R-EP-C-006)                                                                                        | REQ-F-001            | 存在しない通知                                                                                  |
| 形式が不正な ID                                                       | `notification.not_found` (R-EP-C-005)                                                                                                    | REQ-F-001            | 存在しない ID と同じ扱い (DD-EP-07)                                                             |
| `cancelled` の通知をキャンセル                                        | `notification.not_cancellable` (R-EP-C-024)                                                                                              | REQ-F-001, REQ-F-007 | 冪等な成功にしない (DD-EP-04)                                                                   |
| `dispatched` または `missed` の通知をキャンセル                       | `notification.not_cancellable` (R-EP-C-024)                                                                                              | REQ-F-001, REQ-F-007 | 終端状態                                                                                        |
| キャンセルと引き渡しが同時                                            | キャンセル成功か `notification.not_cancellable` のどちらか一方 (R-EP-C-025)                                                              | REQ-F-007            | 競合の結果を排他的にする                                                                        |
| キャンセルの応答喪失後の再送                                          | `notification.not_cancellable` だけから最初のキャンセルの失敗を判断しない。単体取得で状態を確認する (R-EP-C-026, R-EP-C-031, R-EP-C-044) | REQ-F-007            | キャンセルは `Idempotency-Key` の対象外。成功後の再送と発火済みの通知は同じ code になる (DR-09) |
| キャンセルで 5xx または 共通エラー形式でない応答を受け取った          | 結果未確定。成功とも失敗とも判断しない (R-EP-C-043, R-EP-C-044)                                                                          | REQ-F-007            | 分類をバッチ登録 (R-EP-C-037) にそろえる (DR-09)                                                |
| バッチの途中の要素が不正                                              | 単一の `request.invalid`。新規登録は 1 件も残らない (R-EP-C-036)                                                                         | REQ-F-001            | 部分成功の形状を持たない (DR-02)                                                                |
| 過去の `fireAt`、バッチ内の同一内容の要素                             | 本仕様では未定義 (7 章 #2, #3)                                                                                                           | REQ-F-001            | 要件にも確認済みの決定にもないため、挙動を作らない                                              |

再送と冪等性のシナリオは `specifications-idempotency.md` 5.2 に置く。
409 `idempotency.key_conflict` と、処理中・回復待ちの 503 もここに含む。

認証・認可・ルーティング・メソッドの拒否は `specifications-errors.md` 5 章に置く。
403 `auth.forbidden`、404 `request.route_not_found`、405 `request.method_not_allowed` が該当する。
複数の条件が同時に成立する場合も、同じ 5 章に置く。

---

## 6. Requirements Traceability

| Requirement ID | Spec Rule                                                                                                              | Notes                                                                                                         |
| -------------- | ---------------------------------------------------------------------------------------------------------------------- | ------------------------------------------------------------------------------------------------------------- |
| REQ-F-001      | R-EP-C-002〜R-EP-C-011, R-EP-C-020, R-EP-C-035〜R-EP-C-038, R-EP-I-005, R-EP-I-006                                     | 4 操作、バッチの応答形状と原子性                                                                              |
| AC-001         | R-EP-C-002〜R-EP-C-006, 3.3                                                                                            | 4 操作がパス・メソッド・リクエスト・レスポンスとともに定義されている                                          |
| AC-010         | R-EP-C-003, R-EP-C-036                                                                                                 | 成功と失敗の 2 形状。部分成功の形状を持たない                                                                 |
| AC-011         | R-EP-C-004〜R-EP-C-006, R-EP-C-024                                                                                     | 一覧は登録済み通知の配列。単体取得・キャンセルは ID で指定する                                                |
| AC-025         | R-EP-C-031〜R-EP-C-033, R-EP-C-035〜R-EP-C-038, R-EP-I-003, R-EP-I-005, R-EP-I-006                                     | 成功・`4xx` の失敗・結果未確定 (`5xx`・応答なし) を区別し、既存通知に及ばない。回復が完了した場合の結果の整合 |
| REQ-F-002      | R-EP-C-017〜R-EP-C-019, R-EP-C-040, R-EP-C-041, R-EP-C-045                                                             | 独立スキーマと `$defs`、検証制約、長さの数え方と上限の独立した判定                                            |
| AC-002         | R-EP-C-017, R-EP-C-019                                                                                                 | `notifications.schema.json` を単独で検証できる                                                                |
| REQ-F-005      | R-EP-C-012〜R-EP-C-016, R-EP-C-021〜R-EP-C-023, R-EP-C-042                                                             | データ形状と状態の集合。`fireAt` を過ぎた通知の観測される状態                                                 |
| AC-008         | R-EP-C-015, R-EP-C-021, R-EP-C-022, 3.4, 3.6                                                                           | 形状と各状態の名前・意味。遷移の内部は定義しない                                                              |
| REQ-F-007      | R-EP-C-001, R-EP-C-020, R-EP-C-023〜R-EP-C-034, R-EP-C-039, R-EP-C-042〜R-EP-C-044, R-EP-I-001〜R-EP-I-005, R-EP-I-007 | 外部から観測できる保証                                                                                        |
| AC-004         | R-EP-I-001, 3.11                                                                                                       | 内部の実現方法を定義しないことの明示                                                                          |
| AC-019         | R-EP-C-023〜R-EP-C-034, R-EP-C-039, R-EP-C-042〜R-EP-C-044, R-EP-I-002〜R-EP-I-005, R-EP-I-007                         | 各操作の再送時の振る舞い、キャンセルの結果、遷移規則、拒否条件と code                                         |
| REQ-F-003      | —                                                                                                                      | Covered in: `specifications-errors.md`                                                                        |
| REQ-F-004      | —                                                                                                                      | Covered in: `specifications-errors.md`                                                                        |
| REQ-F-006      | —                                                                                                                      | Covered in: `specifications-errors.md`                                                                        |
| REQ-F-008      | —                                                                                                                      | Covered in: `specifications-errors.md` (R-EP-C-007 は認証必須を参照するだけとする)                            |
| REQ-F-009      | —                                                                                                                      | Covered in: `specifications-governance.md`                                                                    |
| REQ-F-010      | —                                                                                                                      | Covered in: `specifications-governance.md`                                                                    |
| REQ-F-011      | —                                                                                                                      | Covered in: `specifications-governance.md`                                                                    |
| REQ-F-012      | —                                                                                                                      | Covered in: `specifications-governance.md`                                                                    |

再送と冪等性の規則の Traceability は、`specifications-idempotency.md` 6 章も参照する。

---

## 7. Open Questions

> **Status**: INCOMPLETE

本章の「#N」と、他の章の「7 章 #N」は Open Questions の番号を、「issue #N」は兄弟 issue を指す。#5 と #11 は欠番とする。

解決済みの事項は次のとおりとする。番号は変えず、本表から外した。

<!-- textlint-disable ja-technical-writing/sentence-length -->

- #4: 「同じ本文」は、本文のバイト列の完全な一致とする (DR-06 決定 10、R-EP-C-034)
- #6: 成功の記録の保持の保証が終わった後の再送の扱いを決めた。重複登録の防止は保証しない。
  応答は、キー照合時点のキーの状態 (UD-039)、先行する検査、入力内容によって決まる (`specifications-idempotency.md` R-ID-C-201、R-ID-I-105)。
  成功の記録が残っていれば、同じ本文には初回の 201 の再現、異なる有効な本文には 409 になる。記録が削除された後は、新規の登録になり得る。
  そのキーに処理中または回復待ちの登録処理があれば 503、入力内容が不正なら 400 になる (DR-06 決定 3・決定 4、`specifications-errors.md` R-ER-C-040)。
  回復できない未確定キーの扱いは、本項の解決に含めない (#15)
- #13: requirements.md v1.5.0 で、REQ-F-001 と AC-025 を `4xx` の失敗と結果未確定 (`5xx`・応答なし) に分けて改訂した
- #17: `fireAt` を過ぎてから `dispatched` か `missed` に決まるまでの間、通知は `scheduled` として観測される。その間のキャンセルは R-EP-C-025 に従う (DR-08、R-EP-C-042、3.6)。
  `missed` の判定の境界 (#10)、発火時刻の判定に使う時計 (#18)、状態の変化が取得に反映される時期 (#28) は、本項の解決に含めない
- #20: 並びは `fireAt` を UTC に直した時刻と、`id` のコードポイントの順で比べる (R-EP-C-009)。`state` クエリの値は 4 つの状態名との小文字での完全一致とし、重複は和集合とする (R-EP-C-011)。
  長さの上限はコードポイントの数で判定し (R-EP-C-040)、件数・長さ・本文サイズの上限はそれぞれ独立に判定する (R-EP-C-041) (DR-07)。
  `url` の形式 (#8)、上限の既定値 (#12)、未知のクエリ (#19)、空白だけの値と制御文字 (#27) は、本項の解決に含めない
- #29: `notifications.schema.json` は、`$defs` で、登録リクエストの本文 (オブジェクト)、登録済み通知、応答本文の 3 つを区別して定義する (R-EP-C-045)。
  応答本文の未知のメンバー (#23) は、本項の解決に含めない
- #31: 一覧取得・単体取得の結果の位置づけを、4.1 の注記に書いた (規範ではない)。R-EP-C-035・R-EP-C-036・R-EP-I-006・R-EP-I-007 の本文は変えない。
  反映の保証 (#28) は、本項の解決に含めない

<!-- textlint-enable ja-technical-writing/sentence-length -->

| #  | Question                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                     | Source                                           | Impact                                                                                              |
| -- | -------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- | ------------------------------------------------ | --------------------------------------------------------------------------------------------------- |
| 1  | 資格情報の送信形式として HTTP Bearer を OpenAPI に書くが、これは候補である。issue #6 との照合は「未確認」であり、確定した保証として扱わない                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                  | REQ-F-008, `specifications-errors.md` R-ER-C-052 | R-EP-C-001, R-EP-C-007 の認証の前提。issue #6 の DR で変わり得る                                    |
| 2  | 過去の `fireAt` を登録時に拒否するか、受け付けるか。受け付けた場合の状態 (`missed` か)。遠い未来の `fireAt` に上限を設けるか                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                 | REQ-F-001 (過去の fireAt)                        | 3.5 の検証制約、3.6 の遷移規則                                                                      |
| 3  | バッチ内に同一内容の要素があるとき、別々の通知として登録するか、拒否するか                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                   | REQ-F-001                                        | R-EP-C-003 の件数の対応、3.5 の検証制約                                                             |
| 7  | 次の保証は、兄弟 issue との照合が済んでいない (未確認)。確定した保証として扱わず、`specifications-governance.md` 3.3.3 の照合の記録 (DR-05) で照合する。(a) 成功の記録の保持 (R-EP-I-002): G-03、issue #4・issue #7。(b-1) 再送時の応答 (R-EP-C-028、R-EP-C-029): G-02、issue #4。(b-2) 同じキーの排他性、重複登録の防止、競合時の 503 (R-EP-C-031〜R-EP-C-033、R-EP-I-003): G-16、issue #4・issue #7。(c-1) 原子性 (R-EP-C-035〜R-EP-C-038、R-EP-I-006): G-01、issue #4。(c-2) 登録と成功の記録の原子性、回復後の整合、回復できない未確定キーの安全性 (R-EP-I-004、R-EP-I-005): G-17、issue #4・issue #5・issue #7 (issue #5 は回復した結果と照会の結果の整合の確認に限る。7 章 #14)。(d-1) `missed` の検出と保持、`fireAt` を過ぎた通知の観測される状態 (R-EP-C-021〜R-EP-C-023、R-EP-C-042): G-04、issue #5・issue #7。(d-2) キャンセルと引き渡しの競合 (R-EP-C-024、R-EP-C-025、R-EP-I-007): G-05・G-06、issue #5。(e) キー空間の共有と認証設計の整合 (3.8.1): G-18、issue #6 (7 章 #16) | REQ-F-009, DR-05                                 | 照合が済むまで契約を確定できない                                                                    |
| 8  | `url` に許可する形式 (相対 URL を許すか、許可するスキーム)                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                   | REQ-F-005                                        | 3.5 の `url` の制約                                                                                 |
| 9  | レスポンスの `fireAt` で、登録時に送られたオフセットを保持するか、正規化するか。秒未満の精度を受け付けるか、保持するか                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                       | REQ-F-005                                        | R-EP-C-014, 3.4                                                                                     |
| 10 | `missed` と判定する境界 (発火時刻からどれだけ遅れると引き渡せなかったとみなすか) を契約で保証するか。あわせて、`dispatched` に遷移する外部の条件を決める。次の 4 つは同じ意味ではない。(1) OS の通知 API の呼び出しが例外やエラーを返さない、(2) OS が通知の要求を受理する、(3) OS が通知を表示する、(4) 利用者が通知を確認する。(3) と (4) は、`dispatched` の意味に含めないことが決まっている (DD-EP-08、R-EP-C-022)。(1) と (2) のどちらを条件にするか、Windows と Android で共通に保証できる範囲は、対応する API の仕様を確認した後に DR として決める。確認が済むまで条件を確定しない (explore レビュー Q-B1)。プラットフォームごとの判定の方法は implementation で扱う                                                                                                                                                                                                                                                                                                                  | REQ-F-005, DD-EP-08                              | R-EP-C-022, 3.6。issue #5・issue #7 との照合に依存する                                              |
| 12 | 既定値 (OpenAPI 3.1.1、最大 100 件、本文 1 MiB、`title` 100 文字、`body` 1000 文字、`url` 2048 文字、ID 64 文字、キーの 255 文字) のレビュー                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                 | Spec 生成時の既定値                              | 3.5 の検証制約。レビューで変わり得る                                                                |
| 14 | 結果が未確定の間に、その操作の通知が一覧取得・単体取得に現れ得るか (照会の結果と照合・回復の結果の整合)。issue #5・issue #7 との照合が必要                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                   | REQ-F-007, DD-EP-11                              | 3.8.1、R-EP-C-033、governance G-17                                                                  |
| 15 | 回復の完了、回復の期限、回復できない未確定キーの扱い (DR-06 決定 14)。本ファイルは、回復できないキーが安全に再利用できない場合があり、503 が返り続け得ることだけを定める。issue #4・issue #7 との実現可能性の照合は「未確認」                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                | REQ-F-007, DR-06                                 | R-EP-I-005、3.8.1                                                                                   |
| 16 | Idempotency-Key の空間を API インスタンス全体で共有すること (DR-06 決定 15) と、issue #6 の認証設計の整合。対象は、認証主体が異なる場合のキーの衝突、資格情報の更新・再発行による影響、キー空間の共有と登録結果を参照する権限の分離、成功結果の再現による情報開示の可能性。認証方式と認可方式は本ファイルで決めない。issue #6 との照合は「未確認」                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                           | REQ-F-008, DR-06                                 | 3.8.1                                                                                               |
| 18 | 発火時刻の判定に使う時計 (サーバーの時計か)、端末のスリープ、時計の変更、プロセスの停止中に `fireAt` を過ぎた通知の状態。本書の設計判断 (DD-EP) として決める (未決定)                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                        | REQ-F-005                                        | 3.6、#10                                                                                            |
| 19 | 一覧取得・単体取得・キャンセルに付いた `Idempotency-Key`、未知のクエリ、本文の扱い。方針案: `Idempotency-Key` は無視し、未知のクエリと本文は `request.invalid` とする。本書の設計判断 (DD-EP) として決める (具体値は未決定)                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                  | REQ-F-005, REQ-F-007                             | 3.3〜3.5、`specifications-errors.md` 4.1                                                            |
| 21 | 利用者は単一の PWA という前提に対して、複数のタブ、複数の PWA インスタンス、再読み込み直後の再送が同時に起き得ることを、契約でどう扱うか                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                     | REQ-F-007                                        | 2.2、`specifications-idempotency.md` R-ID-I-101                                                     |
| 22 | Non-Goals: 終端状態 (`dispatched`・`missed`・`cancelled`) の通知の保持期間と削除の手段、一覧が大きくなるリスク、通知の更新 (内容の変更、再スケジュール) を v1 の対象外と明記するか。あわせて、次の論点を保持期間とは別に決める。保持期間を決めても、これらは決まらない。(a) 全件を返す一覧取得の応答サイズに上限を設けるか、(b) 上限を超えたときの外部の応答、(c) ページングの要否 (explore レビュー Q-C4)                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                   | REQ-F-005                                        | 2.4、R-EP-C-010                                                                                     |
| 23 | レスポンスに未知のメンバーが含まれ得るか (リクエストは未知のメンバーを拒否する)。新しい DR として決める (未決定)                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                             | REQ-F-010                                        | 3.5、`specifications-governance.md`                                                                 |
| 24 | キャンセルに成功した通知を再起動の後も引き渡さない保証 (R-EP-I-007) が、issue #7 の永続化に依存するか。`specifications-governance.md` G-05・G-06 の照合対象に issue #7 を加えるか                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                            | REQ-F-009, DR-05                                 | R-EP-I-007、G-05、G-06                                                                              |
| 25 | Open Questions の ID を `OQ-EP-nn` の形式にするか (index と governance からの参照も同時に直す)                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                               | —                                                | 7 章、`specifications-index.md`、`specifications-governance.md`                                     |
| 26 | `Content-Type` のパラメーター (`charset`) と UTF-8 の BOM の扱い。方針案 (未承認): `application/json` に `charset=utf-8` が付いた場合は受け付け、ほかの charset は 415 `request.unsupported_media_type` とする。BOM の扱いは未決定。`specifications-errors.md` R-ER-C-005 の「サポート対象」の範囲と合わせて決める                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                           | REQ-F-007                                        | 3.1、3.5、`specifications-errors.md` R-ER-C-005                                                     |
| 27 | `title`・`body` について、空白だけの値と制御文字を受け付けるか (未決定)                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                      | REQ-F-005                                        | 3.5、R-EP-C-040                                                                                     |
| 28 | 成功レスポンスの後の一覧取得・単体取得に、その結果が反映されることを契約で保証するか (未決定)。論点を次の 3 つに分ける。(a) バッチ登録の 201 の後に、登録した通知が一覧取得・単体取得に現れるか。(b) キャンセルの 200 の後に、一覧取得・単体取得で `cancelled` が観測されるか。(c) `dispatched`・`missed` への遷移が、一覧取得・単体取得にいつ反映されるか (DR-08 の対象外とした事項)。この保証を前提にする規則は、R-EP-C-031 の単体取得による確認 (DR-09 決定 4 で SHOULD にとどめた)、R-EP-C-044 の後の確認、`specifications-errors.md` R-ER-C-041 である。issue #5 (照会) と issue #7 (永続化) との照合が必要 (DR-05)。関係する保証は `specifications-governance.md` G-04・G-05・G-08 (いずれも未確認) とする。保証を決めたときは DR として記録し、governance 3.3.3 に保証の行を加える。結果未確定の間の現れ方は #14 で扱う                                                                                                                                                               | REQ-F-007, DR-05                                 | R-EP-C-031、R-EP-C-042〜R-EP-C-044、3.8、#14、governance G-04・G-05・G-08                           |
| 30 | `Idempotency-Key` の「印字可能な ASCII 文字列」が空白 (0x20) を含むか。`url` の「URI の形式」が準拠する定義は #8 で扱う (harden レビューで扱う)                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                              | fix レビュー TS-05                               | 3.5、R-EP-C-027、#8                                                                                 |
| 32 | 「再送」を、キャンセル・一覧取得・単体取得にも使っている (3.8、R-EP-C-026、R-EP-C-030、5 章)。`universal-dictionary.md` UD-033 の再送は、同じ Idempotency-Key と同じ本文で行うバッチ登録の 2 回目以降の送信に限る。本書の語を変えるか、UD-033 を広げるか (未決定)                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                            | `universal-dictionary.md` UD-033                 | 3.8、R-EP-C-026、R-EP-C-030、5 章                                                                   |
| 33 | 本書は「結果未確定」を応答の分類の名前に使う (3.2、3.9、R-EP-C-037、R-EP-C-043)。`universal-dictionary.md` UD-045 の未確定は、クライアントの結果の判断である。応答の分類を辞書に加えるか、本書の言い方を変えるか。`specifications-idempotency.md` R-ID-C-301 と合わせて決める (未決定)                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                       | `universal-dictionary.md` UD-045                 | 3.2、3.9、R-EP-C-037、R-EP-C-043、R-ID-C-301                                                        |
| 34 | `notification.not_cancellable` は、`cancelled` と `dispatched`・`missed` を区別しない。候補: (1) 現状を維持する、(2) 拒否の応答に現在の状態を載せる (共通エラー形式の拡張メンバー)、(3) `cancelled` のときだけ別の code を設ける。どの候補も未採用であり、現行の契約 (R-EP-C-024、R-EP-C-026) は変えていない。(2) と (3) は既存のクライアントが受け取る応答を変えるため、互換性の扱いを含めて決める。比べる観点は、R-EP-C-044 の必要性、キャンセルと引き渡しの競合、複数のタブや端末からのキャンセル (#21)、レスポンスのメンバーの追加 (#23)、単体取得への反映 (#28)、エラー識別子の追加の扱い (DR-04) とする。DR として決める (未決定)                                                                                                                                                                                                                                                                                                                                                      | explore レビュー Q-A1                            | DD-EP-04、R-EP-C-024、R-EP-C-026、R-EP-C-031、R-EP-C-044、`specifications-errors.md`、#21、#23、#28 |
| 35 | `dispatched`・`missed` に遷移した時刻を、登録済み通知のメンバーとして公開するか (`cancelledAt` だけがある)。まず、公開する必要があるかを決める。メンバーの名前・数・形は、必要と決めた後に決める。公開する場合は、#23 (レスポンスのメンバーの追加)、#10 (`missed` の境界)、#18 (時計) の決定を前提にする (未決定)                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                            | explore レビュー Q-C2                            | 3.4、R-EP-C-015、#10、#18、#23                                                                      |
| 36 | 一覧取得の 1 回の応答が、単一の時点の状態を表すか。取得の途中で状態が変わったとき、同じ通知が異なる状態で現れること、`state` で絞り込んだ結果から抜け落ちることを許すか。#28 と合わせて決める (未決定)                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                       | explore レビュー G-03                            | R-EP-C-004、R-EP-C-008〜R-EP-C-010、#28                                                             |
| 37 | 成功応答 (201・200) のヘッダーのうち、`Content-Type` 以外 (`Location` など) を契約に含めるか。必須・任意・契約の対象外のどれとするか。HTTP が定めるヘッダー (`Content-Length`、`Date` など) は、本契約の判断の対象に含めない。成功結果の再現 (`specifications-idempotency.md` R-ID-C-202) で再現するヘッダーの範囲も、同じ判断で決まる。エラー応答のヘッダーは `specifications-errors.md` R-ER-C-025・R-ER-C-026 が定める (未決定)                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                           | explore レビュー Q-C6・G-05                      | 3.2、3.3、`specifications-errors.md` R-ER-C-025                                                     |
| 38 | Unicode の入力について、次の 2 つを別々に決める。(a) 長さの判定 (R-EP-C-040) の前に正規化 (NFC・NFD) を行うか、送られたままのコードポイントで数えるか。(b) 対になっていないサロゲート (`\uD800` のエスケープなど) を含む入力を `request.invalid` にするか。外部の許容と拒否の条件は本書で、検証の方法は implementation で扱う (未決定)                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                       | explore レビュー Q-B3                            | 3.5、R-EP-C-040、#27                                                                                |
| 39 | JSON と日時の境界入力の扱い: 重複したメンバー名、日時の年の範囲、うるう秒 (`23:59:60`)。登録リクエストの値はすべて文字列のため、数値の範囲は未知のメンバー (R-EP-C-018 で拒否) に限られるかも確かめる。次は本項に含めない。BOM は #26、`fireAt` のオフセットの保持と秒未満の精度は #9、発火時刻の判定に使う時計は #18 で扱う。オフセットを必須とすること (R-EP-C-014) は決定済みであり、本項で見直さない (未決定)                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                            | explore レビュー A-05・G-04                      | 3.5、R-EP-C-014、R-EP-C-018、R-EP-C-034、#26                                                        |
| 40 | 本文サイズの上限 (3.5) を数える対象のバイト列を決める。転送のための符号化 (`Transfer-Encoding`。`chunked` など) を外した後のメッセージ本文で数えるかを決める。内容の符号化 (`Content-Encoding`) は identity だけであり (R-EP-C-020)、identity 以外は本文サイズの検査より先に 415 になる (`specifications-errors.md` 4.1)。そのため、内容の符号化を復元した本文は対象にならない。「同じ本文」の判定 (`specifications-idempotency.md` R-ID-C-206) は、転送のための符号化を外したメッセージ本文のバイト列を使う。上限の超過を本文の読み取りの途中で検出したとき、413 を返すか、接続を切ることを許すかも決める。読み取りの方式は implementation で扱う (未決定)                                                                                                                                                                                                                                                                                                                                  | explore レビュー Q-B6                            | 3.5、R-EP-C-041、`specifications-idempotency.md` R-ID-C-206                                         |

---

## 8. Change History

| Date       | Version | Description                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                   |
| ---------- | ------- | ------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| 2026-11-14 | 1.0.0   | Initial specification                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                         |
| 2026-11-14 | 1.1.0   | DR-06 と requirements.md v1.5.0、specifications-errors.md v1.1.0 を反映: 3.8.1 をキーの状態と応答、記録の失効、回復、クライアントから見た論理操作で書き直し。R-EP-043 (Content-Encoding)、R-EP-084 (回復)、R-EP-085 (同じ本文の判定)、DD-EP-12 (201 と本文の写しの再現) を追加。3.8.1 に Idempotency-Key の空間の共有 (DR-06 決定 15) を明記。R-EP-001、R-EP-071、R-EP-072、R-EP-075〜R-EP-079、R-EP-081、R-EP-082、DD-EP-05、DD-EP-06、DD-EP-11、3.1、3.2、3.5、3.8、3.9、3.10、Edge Cases、Traceability を更新。Open Questions #4、#6、#13 を解決済みにし、#15 を追加。3.8.1 にキーの状態ごとの応答の要約と、キー空間と #6 の照合点を追加。R-EP-073 を成功の記録の保持に限定し、未確定キーを手放さない規則を R-EP-084 に移動。Open Questions #7 を責務ごとに整理し、#16 を追加。横断レビューの指摘を反映: R-EP-079 を保持の保証の期間に限定。3.8.1 に残留リスク (保持期間の後の遅延送信)、処理中の 503 の注記、サーバーとクライアントの「登録なし」の区別を追加。3.9、R-EP-075、R-EP-082 で再送は確定を保証しないと明記し、API が返す 4xx に限定。3.5、3.10、R-EP-041 で `request.invalid` を本文の JSON の制約に限定し、本文中の通知 ID とパスの通知 ID を区別。R-EP-085 に比較対象のバイト列を明記。Open Questions #7 を governance の照合の行に対応付け。2.1 を DR-01〜06 にする。based-on を requirements.md v1.5.1 にする。2 回目の横断レビューの指摘を反映: 再送の開始の期限とキーの照合の時点を区別し、`Retry-After` と期限の関係を追加。クライアント側の応答の表で契約に適合する 201 と problem 形式でないエラー応答を区別。登録なしの判断の意味を統一。同じ登録の意図の登録し直しに制限を限定。2.2 の所有者とアクセス条件の記述、2.3 の図、Open Questions #14 の参照を修正。再送と冪等性の保証の正本を specifications-idempotency.md に移し、3.8.1、R-EP-071〜R-EP-079、R-EP-082、R-EP-084、R-EP-085、DD-EP-11、DD-EP-12、3.8、3.9、3.10 を参照中心に書き換え、冪等性のシナリオを移動。2.3 の先行の検査を errors 4.1 の Step 1〜8 と同じ列挙にした |
| 2026-11-14 | 1.1.1   | 3.2 の API が返した `4xx` の意味を、その送信についての結果に限定し、論理操作の登録なしの確定 (UD-043) は R-ID-303 によると明記 (Q-9)。based-on を requirements.md v1.5.3 に更新。R-EP-082 を、応答単独では確定できないことと、確定済みの成功は変えないことにそろえる。R-EP-001 を、成功結果の早期応答は Step 1〜8 を通過した送信に限ると改め、優先順位の再定義をやめる (Q-7)。解決済みの #6 の要約に、409・503・400 になる場合を加える (Q-8。規則は変えない)                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                  |
| 2026-11-14 | 1.1.2   | 7 章に Open Questions #17〜#25 を追加 (DR-06 の反映で次回の改訂に回した項目を、作業メモから移す。規則は変えない)                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                              |
| 2026-11-14 | 2.0.0   | 規則を、契約として確定すべき事項 (R-EP-C)、実装で保証すべき事項 (R-EP-I)、将来の拡張案 (R-EP-X。規範ではない) に分類し、ID を振り直す (4 章)。分類の基準 (4 章冒頭) と旧 ID との対応表 (4.4) を追加。R-EP-061 は競合の確定 (R-EP-C-025) とキャンセル後に引き渡さないこと (R-EP-I-007) に、R-EP-081 は応答の意味と結果の不確定 (R-EP-C-036) と 5xx の原子性 (R-EP-I-006) に、文を分けた。規則の内容と拘束力は変えない。旧 ID は廃止し、再利用しない。1〜7 章の参照を新 ID に更新。ID 体系の非互換な変更のため MAJOR とする。`specifications-errors.md`・`specifications-idempotency.md` の ID の振り直し (各 v2.0.0) に合わせ、R-ER と R-ID の参照を更新                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                       |
| 2026-11-14 | 2.0.1   | explore レビューの指摘を反映した明確化 (契約の意味と Rule ID は変えない)。3.2 に成功レスポンスのメディアタイプ `application/json` (2.2 の前提) を明記し、結果未確定の範囲を R-EP-C-037 / R-ID-C-301 にそろえる (problem 形式でない応答、契約に適合しない応答を含める)。3.9 を 3 つの区分と観測される形の関係で説明し、`5xx` の行の名前を結果未確定にし、その他の応答の行を追加。3.3 に、本表以外のパスとメソッド (HEAD を含む) は errors R-ER-C-002 / R-ER-C-003 と 4.1 の優先順位による、と参照を追加。4 章で、規則の分類 (C/I/X) と兄弟 issue との照合の状態を別の軸にし、R-EP-I の基準から照合を外す (index 4.1 に合わせる)。照合待ちの規則は有効で拘束力を持つが、確定した保証とはしないことを明記し、照合待ちの R-EP-C の一覧を 4.1 に追加。2.3 に U4・U5 の担当を注記。5 章に `fireAt` の形式、長さの上限、`Idempotency-Key` の形式の行と、errors 5 章・idempotency 5.2 への参照を追加。3.8.1 の誤字 (回复 → 回復) を修正。Open Questions #2・#9 に論点を追加し、#26〜#28 を追加                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                        |
| 2026-11-14 | 2.1.0   | DR-07〜DR-09 を反映: R-EP-C-009 (並びを UTC の時刻と `id` のコードポイントの順で比べる)、R-EP-C-011 (`state` クエリの値の完全一致と重複の扱い)、R-EP-C-031 (キャンセルを単体取得で確認する条件) を改訂。R-EP-C-040 (長さの上限をコードポイントの数で判定)、R-EP-C-041 (上限の独立した判定)、R-EP-C-042 (`fireAt` を過ぎた通知は `scheduled` として観測される)、R-EP-C-043 (キャンセルの応答の分類)、R-EP-C-044 (結果未確定のときの判断の禁止) を追加。2.6、3.5、3.6、3.8、4.1 の照合待ちの表 ((d-1) に R-EP-C-042)、Edge Cases、Traceability を更新。Open Questions #17・#20 を解決済みにし、#7・#27 の参照を更新。#28 を論点 (a)〜(c)、前提にする規則、照合対象と関係する保証で整理 (保証は未決定のまま)                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                     |
| 2026-11-15 | 2.1.1   | fix レビューの指摘を反映した明確化 (契約の意味と Rule ID は変えない)。用語の統一: 3.2 で、「失敗レスポンス」は API 自身が生成するエラーレスポンス (`4xx`・`5xx`) を、結果の区分の「失敗」は UD-018 の 4xx だけを指すと示す (共通エラー形式は UD-013 を参照し、定義し直さない)。「許可」を「認可」に統一 (2.2、3.10)。エラー応答の形式名を「共通エラー形式」に統一し、3.2 で `application/problem+json` との対応を示す。兄弟 issue を「issue #N」と書き、Open Questions の番号と区別する (2.5、3.8.1、7 章)。照合待ちの規則の定義を 4 章冒頭に追加。検証性: R-EP-C-012・DD-EP-03 の「送れない」を「送らない」に、3.5 の「payload_too_large になり得る」を R-EP-C-041 にそろえる。クライアントの義務はクライアント実装の適合性で検証すると 4 章冒頭に注記。構造: 4 章冒頭の「文言を変えていない」を v2.0.0 時点に限定。3.5 の既定値の目印を 2.2 の書き方にそろえる。1.2 の括弧内の文を外す。参照: 2.1 を DR-01〜09 に、2.2 の採番の参照を DD-EP-03・R-EP-C-012・R-EP-C-013 に、3.1 のメディアタイプと Content-Encoding の参照を分ける。3.9 に UD-ID の正本を明記。DD-EP-07 に R-EP-C-001、DD-EP-09 に R-EP-C-011 を加える。3.3 の R-ER 参照の出典を本文で示す。7 章に #5・#11 が欠番であることを注記。誤字: R-EP-C-007 の「(MUST NOT 分離)」、DD-EP-03 の語順、#25 の Source 欄。fix レビューで扱わなかった S-03・TS-05・TS-03 を Open Questions #29〜#31 に追加。`universal-dictionary.md` との用語の不一致 (再送、結果未確定) を #32・#33 に追加                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                              |
| 2026-11-15 | 2.1.2   | explore レビューの指摘を反映した明確化と Open Questions の追加 (契約の意味と Rule ID は変えない): 2.2 に 403 の発生条件の追跡先 (`specifications-errors.md` 7 章 #2、G-11) を明記。4.1 の照合待ちの表に、R-EP-C-031 のキャンセルの部分と R-EP-C-043・R-EP-C-044 の扱いを注記。Open Questions #10・#22 に論点を加え、#34〜#40 を追加 (規則は変えない)。4.1 の注記に、#28 の決定後に再確認する規則の追跡先と G-15 との対応が未確認であることを加え、#10・#22・#34〜#40 の論点を区別して書き直す                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                 |
| 2026-11-15 | 2.1.3   | harden レビューの指摘を反映した明確化 (契約の意味と Rule ID は変えない)。R-EP-C-026・R-EP-C-031・R-EP-C-036・R-EP-C-042 の条件を WHEN の形で書き直す (条件、適用範囲、強さ、例外は変えない。R-EP-C-042 は起点の状態 `scheduled` を書き出し、R-EP-C-036 は UD-018 を参照する)。4.1 に、一覧取得・単体取得の結果の位置づけを注記として追加し (規範ではない)、7 章 #31 を解決済みにする                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                          |
| 2026-11-15 | 2.2.0   | harden レビューの GF-01 を反映: R-EP-C-045 を追加し、`notifications.schema.json` の `$defs` で、登録リクエストの本文 (オブジェクト)、登録済み通知、応答本文 (`notifications` メンバーを持つ一覧取得・バッチ登録の成功レスポンスの本文) を区別する。応答本文の未知のメンバーは定めない (#23)。3.5 の第 1〜第 3 項目をこれにそろえ、DD-EP-10 の Affected Rules と 6 章の REQ-F-002 に R-EP-C-045 を加える。R-EP-C-018・R-EP-C-019 の文言は変えない。7 章 #29 を解決済みにする                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                   |
