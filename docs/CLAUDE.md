# mulukhiya-toot-proxy 開発ガイド

## プロジェクト概要

通称「モロヘイヤ」。各種ActivityPub対応インスタンスへの投稿に対して、内容の更新等を行うプロキシ。

- **技術スタック**: Ruby 3.4 / Sinatra 4.1 (via ginseng-web) / Sidekiq 8.0 / Puma / Vue 3
- **DB**: PostgreSQL (Sequel ORM) / Redis
- **テンプレート**: Slim / SASS
- **ginseng-\*系gem**: 自作フレームワーク。必要に応じて全て更新してよい

## ブランチ戦略

| ブランチ | バージョン | 目的 |
|---------|-----------|------|
| `master` | 4.x | Pleroma/Meisskeyユーザーの継続サポート |
| `develop` | 5.0開発 | アーキテクチャ刷新（Mastodon系/Misskey系の2系統） |

### 4.x系メンテナンス方針

- 受け入れる変更: 脆弱性対応、bundle update、小規模バグ修正
- 5.0からのバックポート: 影響が小さく即効性があるもの（P1 Issue）
- Pleroma/Meisskeyの新機能追加はしない

### 4.x系の更新確認手順

```bash
# 1. masterブランチで作業
git checkout master

# 2. bundle update
bundle update

# 3. lint実行
bundle exec rake lint

# 4. 差分確認
git diff Gemfile.lock

# 5. 問題なければコミット
```

## 重要なドキュメント

- [v5-plan.md](v5-plan.md) — 5.0計画、Issue一覧（#4024〜#4063）、優先度付き
- [rack-upgrade-discussion.md](rack-upgrade-discussion.md) — rack 3.2問題の詳細記録（致命的バグの経緯）

## CI

GitHub Actions (`.github/workflows/test.yml`):
- PostgreSQL 15 + Redis 7
- `bundle exec rake lint` (rubocop, slim_lint, erb_lint等)
- 依存: ffmpeg, libpq-dev, libidn11-dev, libvips-dev

## ディレクトリ構成（主要）

```text
app/lib/mulukhiya/
  controller/     # SNS別コントローラ (Mastodon, Misskey, +α)
  service/        # SNS別サービスクライアント
  model/          # SNS別モデル (mastodon/, misskey/, pleroma/, meisskey/)
  handler/        # 投稿処理ハンドラー (41以上)
  listener/       # WebSocketリスナー
  storage/        # Redis/DB永続化
  uri/            # URI解析
  contract/       # バリデーション (dry-validation)
  renderer/       # Slim/CSS/RSS レンダラー
config/
  application.yaml  # メイン設定 (~1000行)
  schema/           # JSONスキーマ (handler/, base.yaml)
  route.yaml        # Rackルーティング
views/              # Slim テンプレート + インラインVue.js
test/               # test-unit ベースのテスト (121ファイル)
```

## 既知の注意事項

### rack 3.2問題

rack 3.2 + Sinatra 4.2 で「異なるアカウントの投稿として送信される」致命的問題が発生した（2025-10-12〜10-26）。
原因未特定のためrack 3.1.xに固定中。5.0で防御策込みで再検証予定。
詳細は [rack-upgrade-discussion.md](rack-upgrade-discussion.md) を参照。

### ginseng-web ブランチ

- stable（使用中）: rack ~> 3.1.14 / Sinatra ~> 4.1.0
- main: rack >= 3.2.3 / Sinatra >= 4.2.0（Sinatraクラス削除済みのため使用不可）

## コーディング規約

- rubocop, slim_lint, erb_lint に準拠
- テスト: test-unit (Mulukhiya::TestCase 基底クラス)
- 設定アクセス: `config['/path/to/key']` (Ginsengのスラッシュ記法)
- ハンドラー設定: `handler_config(:key)` (5.0で記法統一予定)
