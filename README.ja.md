# Kallr（カラー）

**発音**: /ˈkɑːlər/ (KAHL-er)

クロスプラットフォームに対応した、ローカル通知サービスです。

## 開発

pnpm と Dart SDK (`^3.14.0`) が必要です。

| コマンド                 | 用途                                                      |
| ------------------------ | --------------------------------------------------------- |
| `pnpm run test:dart`     | `poc/windows/w1-w7-verify` の Dart テストを実行する       |
| `pnpm run check:dart`    | Dart のフォーマットを確認する (`apps`, `packages`, `poc`) |
| `pnpm run lint:markdown` | Markdown を lint する                                     |

`poc/` には検証用コード (PoC) を置きます。各 PoC は自前の `package.json` にスクリプトを持ちます。
