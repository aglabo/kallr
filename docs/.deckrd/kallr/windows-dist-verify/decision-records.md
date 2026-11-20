---
title: "Decision Records: kallr/windows-dist-verify"
module: "kallr/windows-dist-verify"
status: Active
version: 1.0.0
created: "2026-11-20"
---

> This document records architectural and design decisions.
> It is non-normative and exists to preserve rationale.

<!-- textlint-disable ja-technical-writing/sentence-length -->
<!-- textlint-disable ja-technical-writing/max-comma -->
<!-- markdownlint-disable no-duplicate-heading line-length  -->

---

## DR-01: 配布形式は未パッケージ + HKCU 登録とする - 2026-11-20 16:52:33

**Phase**: req
**Status**: Accepted

### Context

Kallr の Windows 向け配布形式が決まっていない。予約通知 (AddToSchedule) を使うには、AUMID (AppUserModelID) を OS に認識させる必要がある。

過去の PoC で、次の事実を確認した。

- 未パッケージの実行ファイルは、`HKCU\Software\Classes\AppUserModelId\<aumid>` に DisplayName を登録するだけで通知を表示できた。
- この登録に管理者権限は要らなかった (HKCU への書き込みのため)。
- スタートメニューのショートカットを作らなくても、通知を表示できた。
- MSIX は署名が必要である。PoC では自己署名証明書を `LocalMachine\TrustedPeople` に入れるため、管理者権限で実行した。
- MSIX の実行自体に管理者権限が要るかは、記載がない。

本検証 (Issue #19) の W1〜W7 は、配布形式を前提に結果を判断する。このため、検証の前に配布形式を決める。

### Decision

Kallr の Windows 向け配布形式は、未パッケージ (通常の実行ファイル) とする。

AUMID は `HKCU\Software\Classes\AppUserModelId\<aumid>` に登録する。

### Scope

- Applies to: Kallr の Windows 向け配布形式と、AUMID の登録先
- Not decided here:
  - MSIX + Dart と AOT exe の検証 → requirements.md の Open Questions で扱う
  - インストーラーなど配布物の作り方 → 未定 (spec 以降で決める)

### Alternatives Considered

| 案        | 不採用の理由                                                                      |
| --------- | --------------------------------------------------------------------------------- |
| MSIX 配布 | 署名が必要で、PoC では署名証明書の導入に管理者権限が必要だったため不採用 (注 1)。 |

注 1: MSIX について、次の 3 点は確かめていない。

- 管理者権限なしで、同じ導入の手順が失敗するか。
- Developer Mode (署名不要) での展開と登録。
- 信頼される証明書での署名。PoC は自己署名だけを試した。

出典: `keneek-core/api-contract/workspaces/redesign/poc-results-windows.md` の PoC-W0 手順 2 (注 1 と未確認の事項)。

### Rationale

最大の理由は、HKCU への AUMID 登録だけで通知が動き、管理者権限も要らない点にある。

- 根拠は、PoC の結果 (`keneek-core/api-contract/workspaces/redesign/poc-results-windows.md`) である。
- ショートカットは任意であり、未パッケージの構成に必須の手順を増やさない。
- MSIX は署名証明書の導入に管理者権限が要り、利用者に求める権限が増える。

### Consequences

- Positive:
  - 管理者権限なしで配布と登録ができる。
  - ショートカットを作らずに通知を表示できる。
- Negative:
  - Kallr 自身に AUMID の登録処理を持たせる必要がある。MSIX ならパッケージから自動で付く。
  - MSIX を、署名証明書の導入に管理者権限が要らない条件で配れるかは、確かめていない。
- Revisit Trigger:
  - 署名証明書の導入に管理者権限が要らない形で MSIX を配布できると確認したときは、本 DR を見直す。

### Related

- requirements/requirements.md: REQ-F-002
- requirements/requirements.md: REQ-F-010
- GitHub Issue: #19

---

## DR-02: 検証対象は Dart FFI とする - 2026-11-20 20:18:24

**Phase**: req
**Status**: Accepted

### Context

Kallr の実装は、複数の OS に対応する観点から、Dart / Flutter を候補にしている。
本検証 (W1〜W7) は、その候補のうち Windows での動作を確かめる。

過去の PoC (PoC-W0 手順 3) で、次の事実を確認した。

- Dart FFI から AddToSchedule を呼べた。予約・一覧・取り消し・表示が通った。
- AUMID (AppUserModelID) の登録は HKCU のレジストリのまま使えた。
- 実装は `dart:ffi` と `package:ffi` だけで書いた。WinRT のインターフェースは、手書きの仮想関数テーブルで呼んだ。

PoC の計画 (poc-plan.md) は、手順 3 が通れば Core を Dart に統一できるとしている。

### Decision

W1〜W5 と W7 の検証は、Dart FFI (`combase.dll` を `dart:ffi` で直接呼ぶ実装) で行う。

### Scope

- Applies to: W1〜W5 と W7 の検証で動かす実装
- Not decided here:
  - バインディングの保守方法 (生成するか、パッケージを採用するか) → 未定 (PoC でも未検討。spec 以降で決める)
  - AOT exe と MSIX + Dart の検証 → requirements.md の Open Questions で扱う
  - `Release` (参照の解放) の扱い → 未定 (PoC では一部しか行っていない。spec 以降で決める)

### Alternatives Considered

| 案                       | 不採用の理由                                                                     |
| ------------------------ | -------------------------------------------------------------------------------- |
| `win32` パッケージを使う | 5.15.0 はトースト関連のインターフェースを含まず、使えなかったため不採用 (注 1)。 |

注 1: `win32` パッケージの 6.x は確かめていない。

出典: `keneek-core/api-contract/workspaces/redesign/poc-results-windows.md` の PoC-W0 手順 3 (実装方式)。

### Rationale

最大の理由は、Dart FFI だけで、検証に必要な操作が通った点にある。

- 根拠は、PoC の結果 (`keneek-core/api-contract/workspaces/redesign/poc-results-windows.md` の PoC-W0 手順 3) である。
- Dart を候補にしているのは、複数の OS に対応するためである。
- AUMID の登録も、DR-01 の HKCU のまま使える。
- 計画の側も、手順 3 が通れば Core を Dart に統一できるとしている (`keneek-core/api-contract/workspaces/redesign/poc-plan.md`)。

### Consequences

- Positive:
  - 検証の結果を、Dart に統一する Core の判断にそのまま使える。
- Negative:
  - 手書きのバインディングは、IID や仮想関数テーブルの位置を間違えても、コンパイルでは検出できない。
  - PoC で呼べたインターフェース以外の位置は、確かめていない。
- Revisit Trigger:
  - AOT exe で FFI の呼び出しが動かないと分かったときは、本 DR を見直す。

### Related

- requirements/requirements.md: REQ-F-001
- requirements/requirements.md: REQ-F-018
- decision-records.md: DR-01
- GitHub Issue: #17 (PoC 手順 3: Dart FFI から AddToSchedule を呼ぶ)
- GitHub Issue: #19

---

## DR-03: 合否は W1〜W4 の成功と W5 の明確化、W7 の結果の記録で判定する - 2026-11-20 20:42:33

**Phase**: req
**Status**: Accepted

### Context

本検証の全体の合否を、何で判定するかが決まっていない。検証項目は W1〜W5 と W7 の 6 つで、性質が異なる。

- W1〜W4 は、予約の作成、kill 後の表示、別プロセスからのキャンセル、同一 ID の置換を確かめる。成功か失敗かを観測できる。
- W5 は、配布形式の制約 (AUMID、インストール方式、実行権限) を特定する。
- W7 は、再起動またはログオフの後に予約が残るかを確かめる。残らない場合は、一括再登録で復旧できるかを確かめる。

PoC の計画 (poc-plan.md の「PoC-W: 合格条件」) は、次のように定めている。

- W1〜W4 は、すべて通す。
- W5 は制約の特定であり、必要なアプリの識別子、インストール方式、実行権限が明確になっていれば合格とする。
- W5 は、両方の配布形式で成功する必要はない。
- W7 は、残らない場合に一括再登録で復旧できるかを確認し、契約に書く保証しない事項として記録する。ゲートでは結果の記録を求める。
- 追加で測る事項は、合否に含めない。

全体の計画 (redesign-plan.md の判定ゲート) は、通過条件に次の 3 つを求めている。

- W1〜W4 が成功していること。
- W5 の制約 (アプリの識別子、インストール方式、実行権限) が記録されていること。
- W7 の結果が記録されていること。

### Decision

本検証は、W1〜W4 がすべて成功し、W5 の 3 項目 (AUMID、インストール方式、実行権限) がすべて明確で、W7 の結果を記録できている場合に合格とする。

W5 の項目が 1 つでも「記載なし」のままの場合は、合格としない。
W7 の確認を行えず、結果を記録できない場合は、合格としない。

記録した W5・W7 の結果の良し悪しは、合否に影響させない。
W5 の項目が不明なことは、良くない結果ではなく、結果が無い状態とする。そのため、合否に影響しない結果には含めない。

任意の測定 (過去時刻、予約一覧、配信猶予) は、合否に含めない。

### Scope

- Applies to: 本検証の全体の合否の判定 (W1〜W5 と W7)
- Not decided here:
  - W7 の対象を、再起動とログオフの両方にするか → requirements.md の Open Questions で扱う
  - 任意の測定の扱い → REQ-F-013 (記録のみ) に従う。本 DR では新たに決めない
  - 「明確」の判定を、どの記述で確かめるか → requirements.md の REQ-F-010 と spec で決める

### Alternatives Considered

| 案                                                        | 不採用の理由                                                                                                                  |
| --------------------------------------------------------- | ----------------------------------------------------------------------------------------------------------------------------- |
| W1〜W5 と W7 のすべての成功を合格とする                   | W5 は両方の配布形式で成功する必要がなく、W7 は OS の挙動に依存してアプリ側で成功を保証できないため不採用。                    |
| W1〜W4 だけを対象にし、W5・W7 は求めない                  | 全体の計画 (redesign-plan.md) の通過条件が、W5 の制約と W7 の結果の記録を求めているため不採用。                               |
| W5 は「記載なし」の項目があっても、記録があれば合格とする | PoC の計画 (poc-plan.md) が、W5 の合格に 3 項目が明確になっていることを求めており、値が不明なまま通すと満たせないため不採用。 |

### Rationale

最大の理由は、PoC の計画が W5 に「3 項目の明確化」を、W7 に「結果の記録」を求めている点にある。W5 の値の良し悪しや、W7 の成功は求めていない。

- PoC の計画 (`keneek-core/api-contract/workspaces/redesign/poc-plan.md` の「PoC-W: 合格条件」) は、W5 を制約の特定とし、必要なアプリの識別子、インストール方式、実行権限が明確になっていれば合格とする。
- 同じ計画は、W7 で残らない場合に一括再登録で復旧できるかを確かめ、ゲートでは結果の記録を求める。
- 全体の計画 (`keneek-core/api-contract/workspaces/redesign/redesign-plan.md` の判定ゲート) も、W5 の制約と W7 の結果が記録されていることを通過条件とする。
- 任意の測定は、PoC の計画が合否に含めないとしている。

### Consequences

- Positive:
  - W5 の値が良くない結果でも、3 項目が明確で W7 の結果を記録できれば、検証を完了できる。
  - W5 の項目が不明なまま、または W7 を確認しないまま、合格と判定されることがない。
- Negative:
  - 結果の評価は、記録を読んで別に行う必要がある。
- Revisit Trigger:
  - W5 や W7 の結果が、W1〜W4 の成立を左右すると分かったときは、本 DR を見直す。

### Related

- requirements/requirements.md: REQ-F-010
- requirements/requirements.md: REQ-F-012
- requirements/requirements.md: REQ-F-013
- requirements/requirements.md: REQ-F-015
- decision-records.md: DR-01
- GitHub Issue: #19

---

## DR-04: Tag は登録時刻 (ローカル日時) + マシン ID + 乱数とし、Group は kallr の固定値とする - 2026-11-20 20:54:43

**Phase**: req
**Status**: Accepted

### Context

予約通知の Tag と Group に、何を設定するかが決まっていない。Tag と Group の組は、予約を特定する複合主キーとして扱われる。

PoC とコードの事実は、次のとおり。

- `poc/windows/w0-3-dartffi/src/w03.dart` は、Group に batch、Tag に alarm をそのまま設定している。ID の長さを Tag と Group の制約に合わせる処理はない。
- `poc/windows/w1-w7-verify/lib/map_toast_key.dart` の `mapToastKey` は、id が maxLength を超えると FNV-1a 64 の 16 桁ハッシュを返す。
- poc-plan.md の W4(c) は、ID の長さを Tag と Group の制約に当てはめ、収まらない場合の対応づけ (ハッシュなど) を決めるとしている。

公式ドキュメントが定める制約は、次のとおり。

- ToastNotification の Tag と Group は、それぞれ最大 64 文字である (Windows 10 Creators Update、ビルド 15063 以降。以前は 16 文字)。
- 予約件数の上限は 4096 件である。超えると AddToSchedule が 0x80070718 で失敗する。

ScheduledToastNotification での Tag の上限は、実機で測っていない。ScheduledToastNotification.Id には、別に 16 文字の制限がある。

出典:

- <https://learn.microsoft.com/en-us/uwp/api/windows.ui.notifications.toastnotification.tag>
- <https://learn.microsoft.com/en-us/uwp/api/windows.ui.notifications.toastnotification.group>
- <https://learn.microsoft.com/en-us/uwp/api/windows.ui.notifications.toastnotifier.addtoschedule>
- <https://learn.microsoft.com/en-us/WINDOWS/APPS/develop/notifications/app-notifications/app-notifications-scheduled>

### Decision

1. 決定 1: Group は固定値 `kallr` とする。
2. 決定 2: Tag は `<登録時刻 YYYYMMDDHHmmss>-<マシン ID 8 桁>-<乱数 16 桁>` の 40 文字とする。16 進は小文字で書く。
   - 登録時刻は、ローカル日時 (YYYYMMDDHHmmss) とする。予約を作成した時刻で、通知する時刻ではない。
   - マシン ID は、Kallr が初回起動時に乱数で作成して保存する 32 bit の値とする。
   - 乱数は、暗号論的乱数の 64 bit とする。
3. 決定 3: (batchId, alarmId) と Tag の対応は、Kallr が持つ対応表で管理する。
4. 決定 4: 登録時に同じ Tag が Group `kallr` の予約一覧に既にあれば、乱数を再生成する。

### Scope

- Applies to: 予約通知の Tag と Group の決め方
- Not decided here:
  - 対応表の保存場所と形式、更新の順序 → requirements.md の Open Questions で扱う (spec で決める)
  - 乱数の生成方法の詳細、再生成の上限回数 → 未定 (spec で決める)
  - ScheduledToastNotification での Tag の実際の上限 → 実機で測定する (REQ-F-007)

### Alternatives Considered

| 案                                             | 不採用の理由                                                 |
| ---------------------------------------------- | ------------------------------------------------------------ |
| `mapToastKey` によるハッシュ (FNV-1a 64)       | 異なる ID が同じ値になりうるため不採用 (注 1)。              |
| ID をそのまま Tag と Group にする (`w03.dart`) | 長さの上限を超える ID を扱えないため不採用。                 |
| 乱数だけの Tag                                 | Tag の文字列順が登録時刻の順にならないため不採用。           |
| 登録時刻を UTC にする                          | マシンの中で完結する用途のため、読みやすさを優先して不採用。 |

注 1: ID からハッシュで Tag を計算する方式は、ハッシュの性質として衝突しうる。出力が入力より短ければ、異なる入力が同じ出力になる場合を避けられない。

### Rationale

最大の理由は、乱数を含む固定長の Tag なら、ID の長さに左右されず、重複を確率と登録前の確認の両方で防げる点にある。

- 40 文字は、公式ドキュメントの上限 64 文字に収まる。実機での上限は、REQ-F-007 で測る。
- 乱数 64 bit は、予約件数の上限 4096 件の中で、衝突の確率を約 4.5×10^-13 に抑える。誕生日問題の近似式 N^2 / 2^65 (N = 4096) による。
- 登録時の既存 Tag の確認で、確率に頼らず重複を防げる。
- 日時を先頭に置くので、通常は Tag の文字列順が登録時刻の順になる。
- 登録時刻をローカル日時にするので、Tag はマシンの中で完結し、読みやすい。
- 一意性は時刻に頼らない。乱数の部分と、登録時の確認で守る。
- 通知時刻でなく登録時刻を使うので、通知時刻の変更は Tag の書式に影響しない。
- Tag は ID から計算できない。そのため、(batchId, alarmId) から Tag を引く対応表が要る (REQ-F-020)。

### Consequences

- Positive:
  - ID の長さにかかわらず、Tag の長さは 40 文字で一定になる。
  - 異なる ID が同じ Tag になることがない。
  - Tag を並べると、通常は登録時刻の順になる。
- Negative:
  - Tag から ID を計算できないため、対応表を保つ必要がある。
  - 夏時間の切り替えやタイムゾーンの変更では、文字列順が登録時刻の順と一致しない場合がある。一意性には影響しない。
  - 対応表の保存場所と更新の順序が決まるまで、cancel と置換の実現方式は決められない。
- Revisit Trigger:
  - 実機で測定した Tag の上限が 40 文字未満だったときは、本 DR を見直す。
  - 予約件数の上限の範囲で Tag の重複が起きたときは、本 DR を見直す。
  - Tag の文字列順が登録時刻の順と一致しないことが、運用で問題になったとき。

### Related

- requirements/requirements.md: REQ-F-007
- requirements/requirements.md: REQ-F-016
- requirements/requirements.md: REQ-F-017
- requirements/requirements.md: REQ-F-019
- requirements/requirements.md: REQ-F-020
- decision-records.md: DR-02
- GitHub Issue: #19

---

## DR-05: 置換は、置換後の予約を追加してから置換前の予約を削除する方式とする - 2026-11-20 21:14:42

**Phase**: req
**Status**: Accepted

### Context

同じ (batchId, alarmId) の未発火の予約を置換する手順が決まっていない。置換の途中でプロセスが止まっても、予約が OS から消えない手順にする必要がある。

事実は、次のとおり。

- 公式ドキュメントに、同じ Tag と Group で AddToSchedule を呼んだときの挙動の記載は見つかっていない。poc-plan.md の W4 (d) も、調査メモは記載なしとしている。
- `poc/windows/w0-3-dartffi/src/w03.dart` の add は、既存の予約を確認せず、削除もしないで AddToSchedule を呼ぶだけである。
- DR-04 により、Tag は登録のたびに別の値を取る。置換前の予約と置換後の予約が、同じ Tag になることはない。

置換の途中で止まったときの状態は、置換の失敗状態として 4 つに分ける。

- 置換前の予約だけが残る
- 置換後の予約だけが残る
- 両方が残る
- どちらも残らない

poc-plan.md の W4 (e) は、この 4 つを「旧予約が残る」「新予約だけ」「両方残る」「どちらも無い」と呼んでいる。

### Decision

同じ (batchId, alarmId) の未発火の予約を置換するときは、次の順で行う。

1. 決定 1: 置換後の Tag を生成し、AddToSchedule で置換後の予約を追加する。次に、対応表を置換後の Tag に更新する。最後に、置換前の Tag を持つ置換前の予約を RemoveFromSchedule で削除する。
2. 決定 2: AddToSchedule が同じ Tag と Group を自動で置換する挙動には、依存しない。

### Scope

- Applies to: 未発火の予約を置換する手順と、追加と削除の順序
- Not decided here:
  - 置換が原子的かどうか → requirements.md の Open Questions で扱う (実機で確かめる。REQ-F-008)
  - 追加と削除の間、または追加と対応表の更新の間で止まったときの回復手順 (対応表に無い Tag の予約の扱いを含む) → 未定 (spec で決める)
  - 対応表の保存場所と形式 → DR-04 の Scope と同じく、spec で決める

### Alternatives Considered

| 案                                                 | 不採用の理由                                                                             |
| -------------------------------------------------- | ---------------------------------------------------------------------------------------- |
| 同じ Tag と Group の AddToSchedule だけに頼る      | 挙動が未確認で、DR-04 の Tag の方式 (登録のたびに異なる Tag) とも合わないため不採用。    |
| 置換前の予約を削除してから、置換後の予約を追加する | 削除と追加の間で止まると、予約が OS に残らない「どちらも残らない」状態になるため不採用。 |

### Rationale

最大の理由は、追加を先にすれば、途中でプロセスが止まっても予約が消えない点にある。安全のため、この順序を選ぶ。

- 削除を先にすると、止まった時点で、置換前の予約も置換後の予約も無くなる。通知は 1 件も出ない。
- 追加を先にすると、止まっても、少なくとも 1 件の予約が残る。
- DR-04 により Tag は登録のたびに異なる。置換後の予約の追加は、置換前の Tag と衝突しない。
- 同じ Tag と Group の挙動は、公式ドキュメントと PoC のどちらにも根拠が無い。確認できていない挙動を、置換の前提にしない。

出典: `keneek-core/api-contract/workspaces/redesign/poc-plan.md` の W4 (d) と (e)。

### Consequences

- Positive:
  - 置換の途中で止まっても、予約が全て消える状態にならない。
  - AddToSchedule の未確認の挙動に、置換の成否が左右されない。
- Negative:
  - 追加と削除の間で止まると、置換前の予約と置換後の予約が「両方が残る」状態になりうる。この場合、置換前の予約が置換前の時刻に通知される。この状態は、REQ-F-009 で記録する。
  - 追加と対応表の更新の間で止まったときの回復手順が決まるまで、対応表に無い Tag の予約の扱いは決められない。
- Revisit Trigger:
  - 実機で、同じ Tag と Group の AddToSchedule が原子的に置換すると分かったときは、本 DR を見直す。
  - 「両方が残る」状態が運用で許容できないと分かったときは、本 DR を見直す。

### Related

- requirements/requirements.md: REQ-F-005
- requirements/requirements.md: REQ-F-008
- requirements/requirements.md: REQ-F-009
- requirements/requirements.md: REQ-F-020
- decision-records.md: DR-04
- universal-dictionary.md: UD-009
- universal-dictionary.md: UD-010
- universal-dictionary.md: UD-011
- universal-dictionary.md: UD-012
- GitHub Issue: #19

---

## DR-06: 通知可否の確認は、OS に依存しないインターフェースに仮想化する - 2026-11-20 21:34:21

**Phase**: req
**Status**: Accepted

### Context

通知できない状態を add の前に検出する必要があるが、その確認の手段は OS ごとに異なる。

事実は、次のとおり。

- Kallr の実装は、複数の OS に対応する観点から、Dart / Flutter を候補にしている (DR-02)。
- 通知を出せるかを確かめる手段は、OS ごとに異なる。
- 過去の PoC では、AUMID (AppUserModelID) が未登録でも AddToSchedule は成功した。通知だけが表示されなかった。
- `poc/windows/w0-3-dartffi/src/w03.dart` の add は、AUMID の登録状態も通知の設定も確認せず、AddToSchedule を呼ぶだけだ。

Windows には、通知の設定を調べる ToastNotifier.Setting がある。
Setting は、通知が有効かどうかを返す。無効のときは、その理由も返す。理由は次の 4 つ (列挙の値のうち、有効を除く全件)。

- アプリ単位の無効
- ユーザーまたは管理者による無効
- グループポリシーによる無効
- マニフェスト未宣言

過去の PoC (未パッケージ) で分かった点は、次のとおり。

- ショートカット付きで即時に通知を出したとき、通知は表示され、Setting は有効を返した (PoC-W0 手順 1)。
- レジストリの登録を削除した後に即時の通知を出すと、通知は表示されなかったが、Setting は有効を返した (未パッケージ版の結果 U3)。
- つまり、AUMID が未登録でも Setting は有効を返す。Setting だけでは、AUMID の未登録を検出できない。
- 記録した未パッケージの実行では、Setting がマニフェスト未宣言を返したことはない。

本検証の構成は、未パッケージ + HKCU 登録で、マニフェストが無い。
マニフェスト未宣言は、アプリがマニフェストでトースト対応を宣言していない状態を表す。公式ドキュメントにも、この構成の記載は見つかっていない。

次の点は、まだ確かめていない。

- (a) AUMID が登録済みの構成で、Setting が有効を返すか (U3 は、登録を削除した後の状態)。
- (b) ユーザーが通知を無効にしたとき、未パッケージ + HKCU 登録の構成で、Setting が無効を返すか。

この確認は検証の作業で、requirements.md の Open Questions に測定として記載済み。

出典:

- <https://learn.microsoft.com/cs-cz/uwp/api/windows.ui.notifications.toastnotifier.setting?view=winrt-26100>
- <https://learn.microsoft.com/en-us/uwp/api/windows.ui.notifications.notificationsetting?view=winrt-26100>
- `keneek-core/api-contract/workspaces/redesign/poc-results-windows.md` の PoC-W0 手順 1
- 同ファイルの PoC-W0 手順 2 の「未パッケージ版の結果 (W01.exe)」(U3)

### Decision

1. 決定 1: 通知可否の確認 (UD-013) と、AUMID の登録・確認・削除は、OS 非依存のインターフェースとして共通ライブラリに置く。
2. 決定 2: Kallr の本体 (add、cancel など) は、そのインターフェースだけを使う。
3. 決定 3: Windows 向けの実装は、HKCU のレジストリ (AUMID の存在と DisplayName) と、ToastNotifier.Setting (通知の有効・無効) で確認する。
4. 決定 4: Android など Windows 以外の実装は、本モジュールの対象外とする。

### Scope

- Applies to: 通知可否の確認と AUMID の登録・確認・削除の呼び出し方、および Windows 向けの確認手段
- Not decided here:
  - 共通ライブラリの置き場所と、インターフェースの形 → requirements.md の Open Questions で扱う
  - Android を実装するモジュールと時期 → 未定
  - 集中モードとロック状態の確認 → 本モジュールでは対象外 (UD-013)。Setting には出ない

### Alternatives Considered

| 案                                                                      | 不採用の理由                                                                                  |
| ----------------------------------------------------------------------- | --------------------------------------------------------------------------------------------- |
| 本体が、レジストリと Windows API を直接呼ぶ (`w03.dart` の改訂前の方式) | 本体が OS に依存し、他の OS に広げられず、自動テストもできないため不採用。                    |
| レジストリの確認だけにする                                              | AUMID の登録状態は分かるが、通知の設定が無効かは分からないため不採用。                        |
| 確認をせずに add する                                                   | 未登録でも add が成功し、通知だけが出ない状態を検出できないため不採用。                       |
| ToastNotifier.Setting だけで確認する                                    | 未パッケージ版の U3 で、AUMID が未登録でも Setting は有効を返し、通知が出なかったため不採用。 |

### Rationale

最大の理由は、OS ごとに異なる確認の手段を、本体から切り離して共通のインターフェースの背後へ置く点だ。

- Kallr は複数の OS への対応を候補にしている (DR-02)。インターフェースを使えば、他の OS の実装に差し替えられる。
- インターフェースを偽の実装へ差し替えられるので、本体の判断を OS から独立して自動テストできる。
- レジストリの確認だけでは、通知の設定が無効かは分からない。Setting は無効の理由まで返すので、Setting も使う。
- Setting だけでは、AUMID の未登録を検出できない。U3 では、未登録でも Setting が有効を返し、通知が出なかった。そのため、レジストリの確認も必要になる。
- 過去の PoC では、AUMID が未登録でも add が成功した。通知できない状態は、add の前に検出する必要がある。
- 根拠は、公式ドキュメント (ToastNotifier.Setting、NotificationSetting) および過去の PoC の結果 (`keneek-core/api-contract/workspaces/redesign/poc-results-windows.md` の PoC-W0 手順 1、手順 2)。

### Consequences

- Positive:
  - 通知できない状態を、add の前に検出できる。
  - 本体の判断を、OS から独立して自動テストできる。
  - Windows 以外の OS の実装を、後から差し替えて追加できる。
- Negative:
  - AUMID が登録済みの構成で、Setting が有効を返すかは確かめていない (a)。
  - ユーザーが通知を無効にしたとき、未パッケージ + HKCU 登録の構成で Setting が無効を返すかは確かめていない (b)。
  - 集中モードとロック状態で通知が出ない場合は、この確認では検出できない。
- Revisit Trigger:
  - Setting が、AUMID の登録済みの構成で有効を返さない、または通知を無効にしても無効の値を返さないと分かったときは、本 DR を見直す。

### Related

- requirements/requirements.md: REQ-F-002
- requirements/requirements.md: REQ-F-021
- decision-records.md: DR-02
- universal-dictionary.md: UD-013
- GitHub Issue: #19

---

## Change History

| Date       | Version | Description                                                   |
| ---------- | ------- | ------------------------------------------------------------- |
| 2026-11-20 | 1.0.0   | Initial release with DR-01, DR-02, DR-03, DR-04, DR-05, DR-06 |
