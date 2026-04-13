# tomato-shrieker との連携

[tomato-shrieker](https://github.com/pooza/tomato-shrieker) は外部ソース（RSS、Google News、GitHub Release 等）を定型投稿するボット。モロヘイヤとは2つの経路で連携している。

## 1. Webhook（投稿先として）

tomato-shrieker の `WebhookShrieker` がモロヘイヤの Webhook エンドポイントを投稿先として利用する。

### 投稿フロー

1. tomato-shrieker が外部ソースをポーリングし、新規エントリーを検出
2. `WebhookShrieker` が `POST /mulukhiya/webhook/{digest}` に Slack 互換ペイロードを送信
3. モロヘイヤの `WebhookController` がペイロードを受け取り、SNS に転送

### Webhook digest の生成（`Webhook.create_digest`）

digest は以下3要素の SHA256 ハッシュで、Webhook URL の一部として固定化される:

- **SNS の URI**（`/{controller}/url`）— 例: `https://st.mstdn.b-shock.org`
- **OAuth アクセストークン**（DB `oauth_access_tokens.token`）— トークン更新で digest 変化
- **暗号化 salt**（`/crypt/salt`、フォールバック: `/crypt/password`）— #4106 インシデントの原因

**これら3要素のいずれかが変わると digest が変化し、全 Webhook URL が無効になる。** 変更時はインフラノートの「Webhook URL 検証手順」に従い疎通確認を行うこと。回帰テストは `test/unit/model/webhook_digest.rb` にある。

## 2. カスタムフィード（データソースとして）

モロヘイヤのカスタムフィード機能（`CustomFeed`）は、tomato-shrieker から購読されることを前提に設計されたRSS生成機能。

### 仕組み

- モロヘイヤが `config/local.yaml` の `/feed/custom` に定義された外部コマンドを実行し、結果を RSS 2.0 フィードとして `GET /mulukhiya/feed/{path}` で配信
- tomato-shrieker の `FeedSource` がこのフィードを購読し、新規エントリーを各 SNS に投稿
- フィードの更新は `FeedUpdateWorker`（Sidekiq）が定期実行

### 関連コード

- `CustomFeed`（`app/lib/mulukhiya/custom_feed.rb`）— フィード定義・コマンド実行
- `FeedController`（`app/lib/mulukhiya/controller/feed_controller.rb`）— RSS エンドポイント
- `FeedUpdateWorker`（`app/lib/mulukhiya/worker/feed_update_worker.rb`）— 定期更新
- `bin/sample/custom_feed_*.sh` — コマンドのサンプル（2名が利用中）

### 注意事項

- コマンド実行は `CommandLine`（`Open3.capture3`）経由。cure-api で発生した Broken pipe インシデントと同じパターンだが、現時点では問題は起きていない
- カスタムフィードの追加・削除は `config/local.yaml` の編集とサービス再起動が必要

## インシデント履歴

- **#4106**（v5.2.1）: `/crypt/salt` 廃止試行で本番 3/4 台の digest が変化 → tomato-shrieker の全投稿が 404。`/crypt/salt` 優先にリバート

## tomato-shrieker 側のメジャーアップグレード計画

2026-03-17 に tomato-shrieker 側でアーキテクチャ変更を含むメジャーアップグレードの計画が開始された。モロヘイヤで確立した開発プラクティス（セッション開始時の同期手順、Sentry.io 導入、ginseng-piefed 切り出し #4146 等）を横展開する流れ。tomato-shrieker と連携する API・Webhook 仕様に変更が入る場合はモロヘイヤ側にも影響が出る可能性があるため、関連 Issue を継続ウォッチする。
