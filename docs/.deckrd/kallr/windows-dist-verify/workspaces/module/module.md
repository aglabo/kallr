---
title: windows-dist-verify
test_scope: WDV
owns:
  - poc/windows/w1-w7-verify/**
---

## windows-dist-verify

Issue #19 の PoC-W (W1〜W5、W7) を、未パッケージ + HKCU 登録の配布形式で検証するための Dart コード。
実装は、可能な限りすべて、テスト駆動で行う。FFI の呼び出しと実機での確認 (kill、再起動、ログオフ) は手動検証とする。

## テスト対象の略語

| 略語  | 対象                                                                                |
| ----- | ----------------------------------------------------------------------------------- |
| `ATP` | `parseAt`                                                                           |
| `MDL` | `kGroup` (`models.dart` の共有定数)                                                 |
| `MAP` | `SqliteStore` (`MappingTable` 実装)                                                 |
| `MID` | `SqliteStore` (`MachineIdProvider` 実装)                                            |
| `RPQ` | 置換キュー (`replace` / `pendingRemovals` / `completeRemoval` / `abortReplacement`) |
| `SQA` | `SqliteAccess` (`guard` / `transact` / `select` / `execute`)                        |
| `SCH` | `openDatabase`                                                                      |
| `DDP` | `defaultDbPath`                                                                     |
| `MTK` | `mapToastKey`                                                                       |
| `TAG` | `generateTag`                                                                       |
| `TAL` | `allocateTag`                                                                       |
| `SVA` | `SchedulingService.add` (新規・置換)                                                 |
| `SVL` | `SchedulingService.list`                                                            |
| `AVL` | `evaluateAvailability`                                                              |
| `MNE` | `MockNotificationEnvironment` (`check` / `register` / `unregister`)                 |
| `ERR` | `errors.dart` の例外型と `Hresult`                                                  |
| `AVO` | `Availability`                                                                      |
| `STO` | `ScheduledToast`                                                                    |
