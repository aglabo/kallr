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

## 6. 予約通知と PWA 連携の調査 (2026-11-16)

`redesign/redesign-plan.md` 第 5 章の確認項目について、公式文書を確認した。
各項目は、事実 (公式文書に書かれていること。短い原文の引用と URL を添える)、推論 (事実からの本調査の判断)、未確認 (取得したページに記載がなかったこと) に分ける。
「記載なし」は、取得したページに書かれていないという意味であり、公式文書全体に書かれていないことを示さない。
取得できなかったページは各節の末尾に挙げる。

### 6.1 Windows: 予約トースト (`ToastNotifier.AddToSchedule` ほか)

確認したページ:

- `https://learn.microsoft.com/en-us/uwp/api/windows.ui.notifications.toastnotifier.addtoschedule`
- `https://learn.microsoft.com/en-us/uwp/api/windows.ui.notifications.toastnotifier.removefromschedule`
- `https://learn.microsoft.com/en-us/uwp/api/windows.ui.notifications.toastnotifier.getscheduledtoastnotifications`
- `https://learn.microsoft.com/en-us/uwp/api/windows.ui.notifications.scheduledtoastnotification`

事実:

| 項目             | 事実                                                                                                                                                                                    |
| ---------------- | --------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| 対応するアプリ   | `AddToSchedule`・`RemoveFromSchedule`・`GetScheduledToastNotifications` は、"only supported in applications which use WinRT as their default application framework" とある              |
| 予約の識別子     | `ScheduledToastNotification` は `Id` (開発者が指定する値)、`Tag` ("uniquely identifies a toast notification inside a Group")、`Group` を持つ                                            |
| キャンセルと一覧 | `RemoveFromSchedule` は指定した `ScheduledToastNotification` の予約表示を取り消す。取り消す対象は `GetScheduledToastNotifications` で得た一覧から選ぶ。サンプルは `Id` で一致を判定する |
| 一覧の内容       | `GetScheduledToastNotifications` は、そのアプリが予約した `ScheduledToastNotification` の一覧を返す。この型は `Content`・`DeliveryTime`・`Group`・`Id`・`Tag` を持つ                    |
| 過去の時刻       | 過去の時刻は、エラー (例外) の原因として挙げられている。具体的な例外の種類は記載なし。"Make sure that the scheduled notification time ... is in the future."                            |
| 件数の上限       | 4096 件を超えると失敗する ("will fail if you attempt to schedule more than 4096 notifications"、0x80070718)。ちょうど 4096 件の扱いは記載なし                                           |

推論:

- 一覧から予約を識別して取り消せるので、`batchId` と `alarmId` を `Id` や `Tag`・`Group` に対応づければ、取り消しは実現できる見込みがある。実機の確認が要る (W3)
- 過去の時刻がエラーの原因として挙げられているので、Windows アダプターは『過去の `fireAt` は再登録しない』 (Q2) に合わせやすい。Android は過去の時刻で即座に発火する (6.3) ため、プラットフォーム間で動作が違う

未確認 (記載なし):

- 同じ `Tag` と `Group` で再度 `AddToSchedule` したときに、置換・失敗・重複のどれになるか (W4(d))
- デスクトップ (Win32・パッケージ化なし・パッケージ化あり) のアプリが使えないという明示的な記載。確認できたのは『WinRT を既定のフレームワークとするアプリのみ』という制限の文言だけ。Flutter や Dart の実行ファイルがこれに当たるかは分からない
- 最短のリードタイム、配信猶予 (5 分とされた主張を含む)、PC の停止中やスリープ中の配信の扱い。**5 分の猶予という主張は、確認したページに記載がない。事実として扱わない**
- アプリの終了、サインアウト、再起動の後も予約が残るか (W2・W7)
- パッケージ化しないデスクトップアプリのアプリ識別子 (AUMID) とスタートメニューのショートカットの要件
- `Tag`・`Group` の文字数の上限 (確認できた上限は件数 4096 のみ)
- 一覧の各要素に `Content` などが実際に入るかの明示

取得できなかったページ:

- `.../tiles-and-notifications/send-local-toast` (404)
- スケジュールトーストのガイド (リンクを辿れず、URL を推測しなかった)

### 6.2 Windows: Task Scheduler (予約通知が使えない場合の代替)

確認したページ:

- `https://learn.microsoft.com/en-us/windows-server/administration/windows-commands/schtasks-create`
  (前半は原文。後半は要約で、`/st`・`/rl`・ONCE の節は誤りがあったため使わない)
- `https://learn.microsoft.com/en-us/windows-server/administration/windows-commands/schtasks-delete`
- `https://learn.microsoft.com/en-us/windows/win32/taskschd/time-trigger-example--c---`
- `https://learn.microsoft.com/en-us/windows/win32/api/taskschd/nf-taskschd-itaskfolder-registertaskdefinition`
- `https://learn.microsoft.com/en-us/windows/win32/taskschd/task-scheduler-start-page` (導入部のみ)

事実:

| 項目               | 事実                                                                                                                                                                                                                 |
| ------------------ | -------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| 一回だけの予約     | `schtasks /create /tn <名前> /tr <コマンド> /sc once /sd <日付> /st <時刻>` で、日時を指定して任意のコマンドを実行する予約を作れる。API では `TASK_TRIGGER_TIME` の時刻トリガー                                      |
| 過去の日時         | "Schtasks won't let you schedule a task to run once if the date and time specified are in the past."                                                                                                                 |
| 対話ログオンの条件 | `/it` は、実行ユーザーがログオンしているときだけ実行する。API の `TASK_LOGON_INTERACTIVE_TOKEN` は "User must already be logged on"                                                                                  |
| 画面表示           | ログオン種別が対話型のとき、メッセージボックスのアクションは表示される (RegisterTaskDefinition の Remarks)。システム権限で実行したタスクは、利用者が表示や操作をできない                                             |
| 削除と置き換え     | `schtasks /delete /tn <名前> [/f]` で名前を指定して削除する。`/create ... /f` は、同名のタスクがあっても警告を出さずに作る。API の `TASK_CREATE_OR_UPDATE` は、新規または更新として登録する。タスク名は 238 文字以内 |

推論:

- 1回限りの時刻トリガーで、通知コマンドを起動する方式は、仕組みとして成り立つ見込みがある。時刻の管理を OS に委譲する原則は保てる
- 名前での削除と更新 (`/f` や `TASK_CREATE_OR_UPDATE`) があるので、`batchId` と `alarmId` から作ったタスク名で、置換とキャンセルを表せる見込みがある。ただし、置換が途中で失敗したときの振る舞いは別に確かめる

未確認 (記載なし):

- トースト通知をタスクから表示できるか (確認できたのはメッセージボックスの記述のみ)
- `StartWhenAvailable` の挙動、`WakeToRun`、PC の停止中やスリープ中、利用者のログオフ中のトリガーの扱い
- `schtasks` のログオン種別の既定値

取得できなかったページ: `StartWhenAvailable`・`ITimeTrigger`・`ITaskFolder::DeleteTask`・`TASK_LOGON_TYPE` の各ページ (リンクを辿れなかった)。

### 6.3 Android: AlarmManager・PendingIntent・BroadcastReceiver

確認したページ:

- `https://developer.android.com/develop/background-work/services/alarms`
- `https://developer.android.com/about/versions/14/changes/schedule-exact-alarms`
- `https://developer.android.com/reference/android/app/AlarmManager` (先頭約 4 万文字は原文。残りは要約)
- `https://developer.android.com/reference/android/app/PendingIntent` (同上)
- `https://developer.android.com/reference/android/content/BroadcastReceiver`
- `https://developer.android.com/develop/background-work/background-tasks/broadcasts`

事実:

| 項目                 | 事実                                                                                                                                                                                                                                                                                                                                                  |
| -------------------- | ----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| 再起動               | "By default, all alarms are canceled when a device shuts down." 復元は `RECEIVE_BOOT_COMPLETED` を宣言し、`ACTION_BOOT_COMPLETED` を受ける Receiver で再設定する。ただし "this only works if the app has already been launched by the user at least once"                                                                                             |
| 同一性               | `PendingIntent` の照合は `Intent.filterEquals` と同じ部分で行う。extras だけが違う Intent は別の `PendingIntent` にならない ("This does *not* happen.")。`AlarmManager.set` は、同じ Intent の既存アラームを置き換える                                                                                                                                |
| フラグ               | `FLAG_UPDATE_CURRENT` は、既存の `PendingIntent` を残して extras を新しい Intent の内容に置き換える。`FLAG_CANCEL_CURRENT` は、新しく作る前に現在のものを取り消す                                                                                                                                                                                     |
| 取り消し             | `AlarmManager.cancel(PendingIntent)` で、`filterEquals` が一致するアラームを取り消す。`PendingIntent.cancel()` は、作成したアプリだけができる                                                                                                                                                                                                         |
| 過去の時刻           | "If the stated trigger time is in the past, the alarm will be triggered immediately."                                                                                                                                                                                                                                                                 |
| 一覧                 | 設定済みのアラームを列挙する API は、公開メソッドの表に見当たらない (列挙できないという明示の記載ではない)。`getNextAlarmClock()` は、任意のアプリが `setAlarmClock` で設定したアラームだけが対象                                                                                                                                                     |
| 正確なアラームの権限 | `SCHEDULE_EXACT_ALARM` は利用者が許可し、利用者とシステムが取り消せる。取り消されると、将来の正確なアラームは取り消される (ガイドは『アプリが停止する』とも書く。`AlarmManager` のページは、`setExact` などで設定したアラームが削除されると書く)。`USE_EXACT_ALARM` は自動で付与され、利用者は取り消せない。Google Play の方針の対象 (用途が限られる) |
| Android 14 の既定    | Android 13 以上を対象とする新しくインストールしたアプリには、`SCHEDULE_EXACT_ALARM` は既定で付与されない (拒否が既定)                                                                                                                                                                                                                                 |
| 権限取り消しの通知   | 権限が付与されたときに `ACTION_SCHEDULE_EXACT_ALARM_PERMISSION_STATE_CHANGED` が送られるが、取り消したときは送られない                                                                                                                                                                                                                                |
| Receiver の時間      | `onReceive` はメインスレッドで動き、約 10 秒のタイムアウトがある。`goAsync()` を呼んでも制限は変わらない。非フォアグラウンドの放送では 30 秒程度までとされる                                                                                                                                                                                          |
| Receiver からの起動  | "Don't start activities from broadcast receivers" (通知を勧める。出典は放送のページ `.../background-tasks/broadcasts`)。`onReceive` の後にシステムはプロセスをいつでも止め得る。背景起動のページは、`BroadcastReceiver` を『必要な背景起動』の例として挙げており、禁止とは書いていない                                                                |
| Doze                 | "Alarms don't fire when the device is in Doze mode." Doze を抜けるまで延期される。ただし、`setAlarmClock` や `*AllowWhileIdle` の系統は Doze 中も動く。`setExact` は他の省電力措置が働いていない場合に限る                                                                                                                                            |

推論:

- アラームの識別は、Intent の data (ID を含む URI) で行い、extras は内容の更新にだけ使う。extras に ID を入れても別のアラームにならないため、PoC の A1・A8 はこの前提で組んである
- 『アラームを OS が保持する』は、再起動すると成り立たない。Q5・一括再登録の方針と整合する
- `SCHEDULE_EXACT_ALARM` が既定で拒否されるので、正確な時刻を契約に書くなら、権限の案内か、近似の時刻を許す方針が要る (A7)
- Receiver で通知を表示するだけなら、10 秒の制限内に収まる見込みがある。SQLite の読み出しの時間は実測が要る (A2)

未確認 (記載なし):

- アプリを Force Stop した後のアラームと放送の扱い (A1b)
- Android 13 での `SCHEDULE_EXACT_ALARM` の既定値
- Google Play の方針の具体的な文言 (`support.google.com` のページは未取得)
- App Standby の挙動
- `PendingIntent` の同一性で、`filterEquals` の項目 (action・data・type・class・categories) を個別に挙げた記述 (data が使われることは AlarmManager の説明から推論した)

取得できなかったページ: `.../alarms/schedule` (リンクが見当たらず、URL を推測しなかった)。

### 6.4 Android: App Links・背景からの起動・Web Share Target

確認したページ:

- `https://developer.android.com/training/app-links/verify-android-applinks`
- `https://developer.android.com/training/app-links/about`
- `https://developer.android.com/guide/components/activities/background-starts`
- `https://developer.android.com/guide/components/intents-filters` (後半は要約)
- `https://developer.chrome.com/docs/capabilities/web-apis/web-share-target`

事実:

| 項目                      | 事実                                                                                                                                                                                                                         |
| ------------------------- | ---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| App Links の要件          | `https://<hostname>/.well-known/assetlinks.json` を配信し、`sha256_cert_fingerprints` がアプリの署名証明書と一致する。`android:autoVerify="true"` と、`VIEW`・`BROWSABLE`・`DEFAULT`・`http`/`https` の intent-filter が要る |
| 検証が示すもの            | "App Links require verification of domain ownership, preventing other apps from intercepting your links." ドメインの所有とアプリの関連づけの検証であり、個々のリクエストや呼び出し元の認証は記載がない                       |
| Intent フィルターの安全性 | "Using an intent filter isn't a secure way to prevent other apps from starting your components."                                                                                                                             |
| 背景からの Activity 起動  | Android 10 以降、背景からの起動に制限がある。例外は、可視のウィンドウを持つ場合、システムが送った `PendingIntent` (通知のタップなど)、`SYSTEM_ALERT_WINDOW` の許可などの列挙。`BroadcastReceiver` は例外のリストにない       |
| Web Share Target          | インストール済みの Web アプリが共有の受け取り先として OS に登録できる。Android では `url` フィールドは空になる。共有元のページへ応答を返す仕組みの記載はない                                                                 |

推論:

- App Links だけでは、任意のサイトによる同じリンクの起動を防げない。要求ごとの認可 (トークンなど) の導入は必須とみられる (Q12・A4)
- アプリから Web ページへ結果を返す仕組みは、確認した範囲にない。結果を PWA へ返す経路は、PoC で成立を確かめる必要がある (Q8・A5)
- アラームの発火時に Activity を起動する設計は、制限の例外にないので避ける。通知の表示だけにする (A1・A2) 方針と整合する

未確認 (記載なし):

- App Links が localhost や私的なオリジンで動くか
- 呼び出し元アプリを判別する手段 (`getReferrer` など)
- アラームの放送から Activity を起動できるか
- インストール済み PWA が、リンクをネイティブアプリで開く仕組み (リンクの取り込み・ナビゲーションの取り込み)。ページは未取得

取得できなかったページ: リンクの取り込みに関するページ、`create-deeplinks` (受信した URI の読み取り)、背景タスクの概要。

### 6.5 Chrome: Local Network Access (PWA から localhost を呼ぶ場合)

確認したページ:

- `https://developer.chrome.com/blog/local-network-access` (2025-06-09 公開、2025-09-29 更新)
- `https://developer.chrome.com/blog/pna-on-hold.md.txt` (2024-10-09)

事実:

- 公開サイトから、ローカルネットワークや loopback (`127.0.0.0/8`) への要求は、利用者がサイトに権限を与えることを要求する方向にある
  ("requiring the user grant the site permission before such requests can be made")
- 記事の範囲は最初のマイルストーンで、公開ネットワークからの要求を対象とする。権限を要求できるのはセキュアコンテキストに限る
- Chrome 138 で opt-in のフラグ (`chrome://flags/#local-network-access-check`)
- 更新注記は "The Local Network Access permission prompt is launching in Chrome 142."
- Chrome 138 時点では、WebSocket・WebTransport・WebRTC は権限の対象外。Chrome 139 以降での対応は予定として書かれている。現在の状態は未確認
- Private Network Access のプリフライトは "not currently enforced" で保留中。Local Network Access がそれに代わる

推論:

- 公開された https の PWA から localhost のサーバーを呼ぶ構成では、利用者の許可が求められる。
  PoC-W6 は、この許可の流れで成立するかを確かめる必要がある。
  Android の A5 候補 (1) (一時的なローカル HTTP サーバー) も同じ制約を受ける見込みがある
- 本調査の日付は 2026-11-16 で、取得したページは 2025-09-29 更新のもの。その後の状態 (出荷済みか、変更されたか) は未確認

未確認 (記載なし):

- サーバー側が送るヘッダー (`Access-Control-Allow-Private-Network` など) の要否
- インストール済み PWA の扱い
- `localhost` を、混在コンテンツの検査で『信頼できる可能性がある』とみなす記述 (定義は loopback を含むが、例外の列挙に `localhost` や `127.0.0.1` は挙がっていない)

取得できなかったページ: Local Network Access の仕様 (`wicg.github.io`)、Private Network Access の仕様。

### 6.6 設計への影響 (推論)

- 『5 分の配信猶予』『Windows の予約の永続性』は、取得したページに記載がない。契約へ書く前の確認は PoC (W2・W7) で行う
- Windows の `AddToSchedule` は『WinRT を既定のフレームワークとするアプリのみ』の制限がある。
  Flutter や Dart のサーバーが対象かは、PoC-W0 で確かめる。
  使えない場合の代替は Task Scheduler で、仕組みとしては成り立つ見込みがあるが、トースト表示は未確認
- 過去の `fireAt` の扱いは、Windows (エラーの原因として挙げられている) と Android (即時に発火) で違う。Q2 の『再登録しない』は、両方で通知の暴発を防ぐ意味がある
- 呼び出し元の検証 (Q12) は、App Links やブラウザの仕組みだけでは足りない見込みで、要求ごとの認可を設計する必要がある
- 結果の返却 (Q8) は、公式文書に仕組みが見つからない。PoC の A5 の結果を待つ
