---
title: "OS Notification API Survey (Windows / Android)"
description: "DR-11 (dispatched / missed の判定条件) の根拠として、OS の通知 API の公式ドキュメントを確認した結果"
date: "2026-11-15"
status: draft
---

<!-- textlint-disable ja-technical-writing/sentence-length -->

## 1. 目的

DR-11 (Proposed) の決定 1・決定 2 が前提にする OS の通知 API の振る舞いを、公式ドキュメントで確認する。
確認できなかった事項は「記載なし」とし、推測で補わない。

確認日: 2026-11-15。出典は Microsoft Learn と Android Developers に限る。

## 2. 確認結果の要約

| 確認事項                                      | Windows                                                                                                                                                                       | Android                                                                                                                                                                  |
| --------------------------------------------- | ----------------------------------------------------------------------------------------------------------------------------------------------------------------------------- | ------------------------------------------------------------------------------------------------------------------------------------------------------------------------ |
| 1. 呼び出しが正常終了したときに保証されること | 記載なし。`Show` は `void` で、「表示する」と説明するだけ                                                                                                                     | 記載なし。`notify` は `void` で、「ステータスバーに表示するために通知を投稿する」と説明するだけ                                                                          |
| 2. OS の受理を明示的に観測できるか            | できない。受理・表示を知らせるイベントはない。UWP の失敗は非同期の `Failed` イベントで通知される                                                                              | 直接はできない。`getActiveNotifications()` (API 23) で投稿済みの通知を列挙できるが、反映の時期は記載なし                                                                 |
| 3. 通知が無効なとき例外やエラーを返すか       | `Show` については記載なし。UWP では非同期の `Failed` イベントで知らされる (最も多い原因は設定によるブロック)                                                                  | 記載なし。無効なときは「表示されない」「送れない」とだけ書かれている                                                                                                     |
| 4. 通知可否を判定できる範囲                   | `ToastNotifier.Setting` / `AppNotificationManager.Setting` でアプリ・ユーザー・グループポリシー・マニフェストによるブロックを判定できる。集中モード (Focus Assist) は記載なし | `areNotificationsEnabled()` でアプリ単位の可否を判定できる。チャネル・チャネルグループの無効、一時停止 (`areNotificationsPaused()`)、おやすみモードは別の API で判定する |
| 5. 確認と呼び出しの間に状態が変わった場合     | 記載なし                                                                                                                                                                      | 記載なし。状態の変化を知らせるブロードキャストはある                                                                                                                     |

## 3. Windows

### 3.1 ToastNotifier.Show (UWP)

- 戻り値は `void`。説明は "Displays the specified toast notification."
- 正常終了時の保証内容 (表示・キュー・受理) は記載なし
- ブロックされているときに例外を投げるかは記載なし
- 出典: <https://learn.microsoft.com/en-us/uwp/api/windows.ui.notifications.toastnotifier.show>

### 3.2 ToastNotification のイベント

- イベントは `Activated`・`Dismissed`・`Failed` だけで、受理や表示を知らせるイベントはない
- `Failed`: "Occurs when an error is caused when Windows attempts to raise a toast notification."
- `Failed` の Remarks: "The most common failure that you'll see when you raise a toast is a settings error,
  for instance a block on toast notifications for this user."
  この状況は、イベントで処理するより、`Show` の前に `ToastNotifier.Setting` を確かめるよう勧めている
- `Dismissed` は、通知が画面から消えたとき (期限切れ・利用者の消去・アプリの非表示) に発生する
- 出典:
  - <https://learn.microsoft.com/en-us/uwp/api/windows.ui.notifications.toastnotification>
  - <https://learn.microsoft.com/en-us/uwp/api/windows.ui.notifications.toastnotification.failed>
  - <https://learn.microsoft.com/en-us/uwp/api/windows.ui.notifications.toastdismissalreason>

### 3.3 ToastNotifier.Setting / NotificationSetting (UWP)

- 説明: "Gets a value that tells you whether there is an app, user, or system block that prevents the display of a toast notification."
- 値: `Enabled`、`DisabledForApplication`、`DisabledForUser`、`DisabledByGroupPolicy`、`DisabledByManifest`
- 複数の段階で無効なときは、範囲の最も広い設定を返す
- 集中モード・おやすみモード・静かな時間を反映するかは記載なし。`Setting` が例外を投げるかも記載なし
- 出典:
  - <https://learn.microsoft.com/en-us/uwp/api/windows.ui.notifications.toastnotifier.setting>
  - <https://learn.microsoft.com/en-us/uwp/api/windows.ui.notifications.notificationsetting>

### 3.4 AppNotificationManager (Windows App SDK)

- `Show` は `void`。説明は "Displays the specified app notification in Action Center." 呼び出しの前に `Register` が必要
- 無効なときの振る舞いと例外は記載なし。クイックスタートには、管理者権限で動くアプリでは "will fail silently and no notification will be displayed" とある
- `Setting` の値は UWP と同じ 5 つに `Unsupported` を加えたもの
- `Failed` に当たるイベントを持たない (イベントは `NotificationInvoked` だけ)
- 出典:
  - <https://learn.microsoft.com/en-us/windows/windows-app-sdk/api/winrt/microsoft.windows.appnotifications.appnotificationmanager.show>
  - <https://learn.microsoft.com/en-us/windows/windows-app-sdk/api/winrt/microsoft.windows.appnotifications.appnotificationmanager>
  - <https://learn.microsoft.com/en-us/windows/windows-app-sdk/api/winrt/microsoft.windows.appnotifications.appnotificationsetting>
  - <https://learn.microsoft.com/en-us/windows/apps/develop/notifications/app-notifications/app-notifications-quickstart>

## 4. Android

### 4.1 NotificationManager.notify

- 戻り値は `void`。説明は "Post a notification to be shown in the status bar."
- 正常終了時に投稿・表示が保証されるかは記載なし
- 無効なときに例外を投げるかは記載なし
- 出典: <https://developer.android.com/reference/android/app/NotificationManager>

### 4.2 受理の観測

- `getActiveNotifications()` (API 23):
  "Recover a list of active notifications: ones that have been posted by the calling app
  that have not yet been dismissed by the user or cancel(String, int)ed by the app."
- `notify` から戻った通知がこの一覧に現れるか、またその時期は記載なし
- 出典: <https://developer.android.com/reference/android/app/NotificationManager>

### 4.3 通知が無効な場合

- Android 13 以降で `POST_NOTIFICATIONS` を許可されないとき: "your app can't send notifications unless it qualifies for an exemption."
  "All notification channels are blocked, except for a few specific roles."
- チャネルを指定しない通知 (API 26 以降): "the notification doesn't appear and the system logs an error."
- チャネルの重要度 `NONE`: ステータスバー・シェードのどちらにも現れない
- チャネルグループやアプリがブロックされているとき: "notifications posted to this channel will not be shown to the user"
- どの場合も、`notify` が例外を投げるかは記載なし
- 出典:
  - <https://developer.android.com/develop/ui/views/notifications/notification-permission>
  - <https://developer.android.com/develop/ui/views/notifications/channels>
  - <https://developer.android.com/reference/android/app/NotificationChannel>

### 4.4 通知可否の判定

- `areNotificationsEnabled()` (API 24): "Returns whether notifications from the calling package are enabled." 通知の権限のページは、送る前にこれで確かめるよう勧めている
- `areNotificationsEnabled()` がチャネルやチャネルグループの無効を含むかは記載なし
- `areNotificationsPaused()` (API 29): "Returns whether notifications from this package are temporarily hidden."
- `getCurrentInterruptionFilter()` (API 23、おやすみモード): 割り込み (音・振動) を許す通知を決める。抑制された通知が投稿されるかは記載なし
- 出典:
  - <https://developer.android.com/reference/android/app/NotificationManager>
  - <https://developer.android.com/reference/androidx/core/app/NotificationManagerCompat>
  - <https://developer.android.com/develop/ui/views/notifications/notification-permission>

### 4.5 状態の変化とレート制限

- 確認と呼び出しの間の状態の変化については記載なし。状態の変化を知らせるブロードキャスト (`ACTION_APP_BLOCK_STATE_CHANGED` など、API 28) はある
- 投稿を黙って捨てるレート制限や件数の上限は、確認したページには記載なし

## 5. DR-11 への含意

- 「呼び出しの正常終了」は、両 OS とも「OS の受理」や「表示」を意味しない。2 つを同じ意味として扱えない
- 「呼び出しがエラーを返さない」は、通知が無効な場合を検出する手段にならない。どちらの OS でも、無効なときに同期的なエラーを返すとは書かれていない
- 両 OS に共通して検証できる通知可否は、「呼び出しの前に、アプリ単位の通知可否を確認する API が『有効』を返した」ことに限られる。
  Android のチャネル・一時停止・おやすみモードは Windows に対応する確認手段がなく、Windows の集中モードは記載がない
- 確認と呼び出しの間の状態の変化は、どちらの OS も扱いを定めていない
- Windows (UWP) の `Failed` イベントは、`Show` の後から非同期に発生し得る。Windows App SDK には対応するイベントがない
