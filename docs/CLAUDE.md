# mulukhiya-toot-proxy 開発ガイド

## プロジェクト概要

通称「モロヘイヤ」。各種ActivityPub対応インスタンスへの投稿に対して、内容の更新等を行うプロキシ。

- **技術スタック**: Ruby 3.4 / Sinatra 4.1 (via ginseng-web) / Sidekiq 8.0 / Puma / Vue 3
- **DB**: PostgreSQL (Sequel ORM) / Redis
- **テンプレート**: Slim / SASS
- **ginseng-\*系gem**: 自作フレームワーク。必要に応じて全て更新してよい

## ブランチ戦略

| ブランチ | バージョン | 目的 |
| --- | --- | --- |
| `master` | 4.x | Pleroma/Meisskeyユーザーの継続サポート |
| `develop` | 5.0開発 | アーキテクチャ刷新（Mastodon系/Misskey系の2系統） |

### 4.x系メンテナンス方針

#### 受け入れる変更

- 脆弱性対応（gem更新、コード修正）
- `bundle update`（定期的な依存更新）
- 小規模バグ修正（既存機能の不具合修正）
- 5.0からのバックポート（下記基準を満たすもの）

#### 受け入れない変更

- Pleroma/Meisskeyの新機能追加
- 大規模なリファクタリング
- 新しい外部サービスとの連携追加
- 破壊的な設定変更

#### バックポート判断基準

5.0（develop）の変更を4.x（master）にバックポートする場合、以下を全て満たすこと:

1. **影響範囲が小さい**: 変更ファイルが少なく、既存機能への副作用が限定的
2. **即効性がある**: セキュリティ修正、ユーザーに直接恩恵のあるバグ修正
3. **依存変更を伴わない**: 新しいgemの追加や、既存gemのメジャーバージョン変更を含まない
4. **4.xのSNS構成と互換**: Pleroma/Meisskey含む4タイプ構成で動作すること

v5-plan.md でP1に分類されたIssueがバックポート対象の目安。

### ブランチ命名規則

| 用途 | パターン | 例 |
|------|---------|-----|
| 4.xリリース作業 | `dev/{version}` | `dev/4.35.7` |
| 5.0開発 | `develop` | — |
| 5.0のIssue作業（必要時） | `feature/{issue}` | `feature/4031-remove-meisskey` |

- 通常は `develop` ブランチで直接作業する
- 大規模な変更や並行作業が必要な場合のみ feature ブランチを作成する
- master への統合は PR 経由で行う

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

- [v5-plan.md](v5-plan.md) — 5.0計画、Issue一覧（#4024〜#4070＋過去Issue）、優先度付き
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
  model/          # SNS別モデル (mastodon/, misskey/)
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

## 関連リポジトリ

MastodonとMisskeyのソースコードがローカルに並列配置される。
パスはセッション開始時にユーザーから指示される。

用途:

- SNS側のAPI仕様確認、設定ファイルの参照
- モロヘイヤとの結合動作確認
- 必要に応じてSNS側のコード修正

## 開発サーバー

SSH経由で操作可能。接続情報は `~/.ssh/config` で管理（リポジトリには含めない）。
エイリアス名はセッション開始時にユーザーから指示される。

| 種別     | 台数 | OS       |
|----------|------|----------|
| Mastodon | 3    | FreeBSD  |
| Misskey  | 1    | Ubuntu   |

リモート側の操作（git pull、マイグレーション、サービス再起動等）も可能。

## コーディング規約

- rubocop, slim_lint, erb_lint に準拠
- テスト: test-unit (Mulukhiya::TestCase 基底クラス)
- 設定アクセス: `config['/path/to/key']` (Ginsengのスラッシュ記法)
- ハンドラー設定: `handler_config(:key)` (5.0で記法統一予定)

### RuboCopに含まれない個人規約

以下はユーザーから都度指示される。指示があり次第ここに追記する。

- メソッド末尾でも `return` を省略しない（暗黙のreturnを使わない）
