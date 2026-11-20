---
title: windows-dist-verify
test_scope: WDV
owns:
  - poc/windows/w1-w7-verify/**
---

## windows-dist-verify

Issue #19 の PoC-W (W1〜W5、W7) を、未パッケージ + HKCU 登録の配布形式で検証するための Dart コード。
OS に依存しない純粋なロジックだけを、テスト駆動で実装する。FFI の呼び出しと実機での確認 (kill、再起動、ログオフ) は手動検証とする。

## テスト対象の略語

| 略語  | 対象          |
| ----- | ------------- |
| `MTK` | `mapToastKey` |
