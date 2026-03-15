# mulukhiya-toot-proxy 開発ガイド

## プロジェクト概要

通称「モロヘイヤ」。各種ActivityPub対応インスタンスへの投稿に対して、内容の更新等を行うプロキシ。

- **技術スタック**: Ruby 4.0 / Sinatra 4.1 / Sidekiq 8.1 / Puma / Vue 3
- **DB**: PostgreSQL (Sequel ORM) / Redis
- **テンプレート**: Slim / SASS
- **ginseng-\*系gem**: 自作フレームワーク。必要に応じて全て更新してよい

## 姉妹サーバーとコミュニティ設計

モロヘイヤは複数の SNS サーバーで稼働しており、一部は「姉妹サーバー」の関係にある。

- **姉妹サーバー**: 同じデフォルトハッシュタグを持ち、同一リレーサーバー（`deas.b-shock.co.jp`）に接続しているサーバー同士
- **仕組み**: `DefaultTagHandler` が投稿にデフォルトハッシュタグを自動付与 → リレー経由で姉妹サーバーに伝播 → タグタイムラインが同期し、同じコミュニティとして機能
- **姉妹関係**: デルムリン丼 ↔ ダイスキー（同一管理者）、キュアスタ！ ↔ 外部管理のダイスキー（異なる管理者）

`DefaultTagHandler` は実装としてはシンプルだが、コミュニティ運用の基盤を支える重要なハンドラー。

## ブランチ戦略

| ブランチ | バージョン | 目的 |
| --- | --- | --- |
| `main` | 5.x (デフォルト) | リリース済み安定版。clone時にユーザーが得るブランチ |
| `develop` | 5.x | 開発ブランチ。日常の作業はここで行う |
| `v4` | 4.x | Pleroma/Meisskeyユーザーの継続サポート |

### リリースフロー

1. `develop` で開発・コミット
2. リリース時に `develop` → `main` へPRを作成しマージ
3. `main` でタグを打ちリリース

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

5.x（main）の変更を4.x（v4）にバックポートする場合、以下を全て満たすこと:

1. **影響範囲が小さい**: 変更ファイルが少なく、既存機能への副作用が限定的
2. **即効性がある**: セキュリティ修正、ユーザーに直接恩恵のあるバグ修正
3. **依存変更を伴わない**: 新しいgemの追加や、既存gemのメジャーバージョン変更を含まない
4. **4.xのSNS構成と互換**: Pleroma/Meisskey含む4タイプ構成で動作すること

v5-plan.md でP1に分類されたIssueがバックポート対象の目安。

### ブランチ命名規則

| 用途                      | パターン          | 例                                |
|---------------------------|-------------------|-----------------------------------|
| 4.xリリース作業           | `dev/{version}`   | `dev/4.35.7`                      |
| 5.xのIssue作業（必要時）  | `feature/{issue}` | `feature/4031-remove-meisskey`    |

- 通常は `develop` ブランチで作業する
- 大規模な変更や並行作業が必要な場合のみ feature ブランチを作成し、`develop` にマージする

### 4.x系の更新確認手順

```bash
# 1. v4ブランチで作業
git checkout v4

# 2. bundle update
bundle update

# 3. lint実行
bundle exec rake lint

# 4. 差分確認
git diff Gemfile.lock

# 5. 問題なければコミット
```

## 予定: 5.8.0 — セキュリティレビュー対応

- #4155 Wiki: Sentry.ioの設定項目をドキュメントに追加
- #4157 Sentry: before_sendフィルタによる秘匿情報スクラビング — #4156 セキュリティレビューの指摘対応
- #4158 bundler-auditの導入とCI統合 — #4156 セキュリティレビューの指摘対応
- #4156 セキュリティレビュー — 上記完了でクローズ
- ~~#4159 フロントJSテストのアサーション修正~~ — クローズ済み
- ~~#4161 about APIでブースト/リノートのカスタムラベルを返す~~ — クローズ済み

## 予定: 5.9.0 — アーキテクチャ整理

- #4144 カスタムAPI/カスタムフィードを独立デーモンに分離 — Bundler二重管理・Open3.capture3の不安定さを解消。元の独立デーモン形式に戻す
- #4146 PieFed対応をginseng-piefedに切り出し — tomato-shriekerとの共有が動機。#4145 完了が前提

## 予定: 5.10.0 — WebUI拡張

- #4117 WebUI: 複雑なハンドラーパラメータ編集（CRUD一覧管理） — オブジェクト配列や深いネスト構造を持つパラメータの一覧管理UI
- #4118 WebUI: サービス連携・システム設定の編集と不要設定の自動検出

## リリース済み: 5.7.0（2026-03-14）

全5 Issue クローズ。Sentry エラートラッキング導入、Misskey localOnly フラグ、フロントエンド JS モジュール抽出。セキュリティレビュー（#4156）実施済み。

- **#4154 Sentry.ioによるエラートラッキングの導入** — sentry-ruby + sentry-sidekiq。既存のalertメソッドにSentry.capture_exceptionを統合。DSNはconfig/local.yamlの`/sentry/dsn`で設定
- **#4153 Misskey: 内部DMにlocalOnlyフラグを設定する** — コマンドトゥート、お知らせボット通知DM、ボットメンション時のDM強制変更でlocalOnly: trueを設定
- **#4140 config.slimのフォーム処理ロジックを外部JSに抽出** — config_form.jsに10個の純粋関数を抽出、27テストケース追加
- **#4141 テンプレート内JSの段階的なモジュール抽出** — webui_utils.jsに6個の純粋関数を抽出、18テストケース追加
- #4152 Annict連携セクションの認証要件をドキュメントで修正

## リリース済み: 5.6.0（2026-03-11）

全5 Issue クローズ。Lemmy 対応廃止、ストリーミング死活監視の再導入、capsicum エピソードブラウザ向け API 整備。

- **#4143 ヘルスチェックにストリーミングプロセスの死活監視を追加** — `/api/v1/streaming/health` への直接チェックに変更し、小規模サーバーでの誤検知を防止
- **#4145 Lemmy対応を廃止し、PiefedClipperを自立化** — LemmyClipper を削除し、PiefedClipper を独立化
- **#4150 `GET /annict/oauth_uri` エンドポイントを追加** — capsicum のエピソードブラウザから Annict OAuth 認可を開始するためのエンドポイント
- #4137 ナウプレ系ハンドラーの tagging パラメータを廃止
- #4139 アップロード時のペイロード調整をginseng-fediverseに移動
- #4148 capsicum エピソードブラウザ向け API ドキュメントの整備

## リリース済み: 5.5.1（2026-03-08）

ホットフィックス。全8サーバーデプロイ済み。

- **#4142 ヘルスチェックからstreaming死活監視を除外** — 小規模サーバーで10分間イベントがないだけでhealth全体が503になり、monitの不要な再起動を誘発していた

## リリース済み: 5.5.0（2026-03-08）

全8 Issue クローズ。WebUI ハンドラーパラメータ編集の拡張、リスナー死活監視、フロントエンドテスト基盤導入。全8サーバーデプロイ済み。

- **#4116 WebUI: object型・配列型ハンドラーパラメータの編集に対応** — スキーマ定義に基づくネストされたオブジェクトや配列の追加・削除をWebUIから直接編集可能に
- **#4124 リスナーのWebSocket死活監視と安全な停止** — 指数バックオフによる再接続、Redisイベント記録、SIGTERM/SIGINTでの安全な停止
- **#4131 フロントエンドJSのブラウザテスト基盤導入** — Mocha/Chaiによるブラウザテストランナー。handler_form.js を抽出し26テストケースを実装（MulukhiyaLib 30件と合わせ計56件）
- **#4134 Misskey: アップロード時にセンシティブ・説明が保存されない問題を修正**
- **#4136 Mastodon: アップロード時にalt textが保存されない問題を修正**
- #4132 WebUI: ハンドラー設定パネルがイベントセクションを突き抜ける問題を修正
- #4133 WebUI: ハンドラーが含まれないイベントを非表示にする
- #4138 local.yaml未存在時のスキーマバリデーションエラーを修正

## リリース済み: 5.4.0（2026-03-04）

全5 Issue クローズ。WebUI ハンドラーパラメータ編集機能の追加と `/about` API の修正。全8サーバーデプロイ済み。

- **#4115 WebUI: 軽量ハンドラーパラメータの編集機能** — boolean・数値・文字列などの単純なパラメータを WebUI から直接編集可能に
- **#4128 `/about` の capabilities・features が空になる問題を修正**
- **#4129 メディアカタログ: Misskey 環境でステータス URL が不正になる問題を修正**
- #4126 起動時の標準出力メッセージを廃止
- #4127 CI ログの Sequel::Error メッセージを抑制

## リリース済み: 5.3.0（2026-03-02）

全12 Issue クローズ。nodeinfo 循環呼び出し問題を解消した重要リリース。ステージング検証（zugoga）完了後にリリース。

- **#4121 nodeinfo 依存の見直し** — nodeinfo を Redis にキャッシュし、循環呼び出し・429 エラー・WebUI のレスポンス低下を解消。詳細は [postmortem-2026-03-nodeinfo.md](postmortem-2026-03-nodeinfo.md) を参照
- **#4098 daemon-spawn gem 廃止** — プロセス管理を OS の init システムに委任。`rake start/stop/restart` を廃止しサービスマネージャへ誘導
- **#4113 `/mulukhiya/api/about` のレスポンス拡張（capsicum 対応）** — `status.label`、`status.max_length`、`theme.color`、`capabilities`、`features`、`handlers` を追加
- **#4125 起動通知 DM** — お知らせボットから管理者へヘルスチェック結果 + スキーマチェック結果を DM 通知
- **#4123 ListenerDaemon.health の PID ファイル非依存化** — `pgrep` フォールバック追加。rc.d の stop に `pkill -9` フォールバック追加
- #4102 WebUI での設定編集機能の拡充
- #4119 FreeBSD rc.d: listener restart 時にログが流れ続ける問題の修正
- #4075 `with_indifferent_access` を `Sinatra::IndifferentHash` に統一
- #4108 Webhook.create の digest 照合を効率化、#4109 エラーレスポンス改善
- #4114 未使用ハンドラースキーマ・パラメータの削除、#4110 Webhook digest 回帰テスト追加

## リリース済み: 5.2.1（2026-03-01）

緊急パッチリリース。全8サーバーデプロイ済み。

- **#4106 Webhook URL が無効になる不具合の修正** — 5.2.0 で `Webhook.create_digest` の salt 取得を `/crypt/salt` → `Crypt.password` に変更したが、両者が異なる値のサーバーで digest が変化し Webhook が 404 になった。`/crypt/salt` 優先にリバート

## リリース済み: 5.2.0（2026-02-28）

全7 Issue クローズ。全8サーバーデプロイ済み。

- **#4096 実況デコレーションの時限付き自動解除** — 番組終了後にアバターデコレーションを自動で剥がす（Misskey `i/update`）
  - Misskey 側: [pooza/misskey#404](https://github.com/pooza/misskey/issues/404) もクローズ（TagsetWidget で `decoration.minutes` を追加送信）
  - 検証時に発見した問題と対策:
    - トークン競合: `UserConfigCommandHandler` で token 保存を update より前に移動（async worker が古いトークンを読む問題）
    - API body sanitization: `DecorationApplyWorker` で `avatarDecorations` の各要素を valid_keys のみに slice（レスポンス専用フィールドの混入防止）
    - Misskey ロール設定: ベースロールのデコレーション上限を +1 する必要あり（追加で1枠使うため）
- #4094 HTTPクライアント統一、#4101 CommandLine.exec タイムアウト
- #4082 Sidekiqワーカーテスト、#4099 Worker個別コンテキストログ、#4103 テストの外部API依存解消
- #4105 FreeBSD rc.d 起動ブロック原因切り分け（Mastodon streaming が主犯 → [pooza/mastodon#900](https://github.com/pooza/mastodon/issues/900)）

## セッション開始時の同期手順

会話の最初に「進捗を同期してください」等の指示があった場合、以下の手順を実行する。

### 1. プロジェクトガイドの読み込み

- `docs/CLAUDE.md` を読む（プロジェクトのルール・構造・履歴の正本）
- `MEMORY.md` は自動ロードされるので、両者の整合性を意識する

### 2. リモートとの同期・状態確認

- `git fetch origin` — **最初に必ず実行**。リモートが正本であり、ローカルの状態を信用しない
- `git log HEAD..origin/develop --oneline` — リモートに未取り込みのコミットがないか確認。差分があればpullを検討
- `git log --oneline -10` — 直近のコミット履歴
- `gh issue list --state open` — open Issue一覧
- `gh pr list --state open` — open PR一覧

### 3. Dependabotセキュリティアラート

- `gh api repos/pooza/mulukhiya-toot-proxy/dependabot/alerts` で open アラートを確認
- 0件なら対応不要、あれば提案

### 4. Codexレビューコメントの確認

- 最近マージされたPR（`gh pr list --state merged --limit 5`）を取得
- 各PRに対して `gh api repos/pooza/mulukhiya-toot-proxy/pulls/{number}/comments` でCodex（`chatgpt-codex-connector[bot]`）のコメントを確認
- 未返信のコメントがあれば内容を確認し、対応が必要か判断

### 5. 外部リポジトリの同期確認（chubo2）

- `cd ~/repos/chubo2 && git fetch origin` + `git log HEAD..origin/main --oneline` でリモートとの差分を確認
- `docs/infra-note.md` に変更があれば MEMORY.md のインフラセクションに反映が必要か判断
- `gh issue list --state open` で open Issue の変動を確認

### 6. マイルストーンの状態確認

- `docs/CLAUDE.md` と MEMORY.md に記載された次期マイルストーンの Issue が、実際の GitHub 上の状態（open/closed）と一致しているか確認
- クローズ済みの Issue があれば MEMORY.md から除外し、`docs/CLAUDE.md` も必要に応じて更新

### 7. MEMORY.md の更新

- 上記で検出した差分（Issue 状態、リリース日の誤り、件数のズレ等）を反映

### 8. 同期結果の報告

- 現在のブランチ・状態、マイルストーンの状況、各確認項目の結果をまとめて報告する

## 情報の記載先ルール

- **課題・タスク** → GitHub Issue で管理（インフラ面の課題は `pooza/chubo2` の Issue として起票）
- **プロジェクト共有すべき知見** → `docs/CLAUDE.md` や `docs/v5-plan.md` など git 管理下のファイルに記載
- **インフラ情報** → `pooza/chubo2` リポジトリの `docs/infra-note.md` に記載
- **進捗の同期** → `MEMORY.md` だけでなく `docs/CLAUDE.md` も更新すること。特にリリース済みバージョンの反映（「開発中」→「リリース済み」への変更、次バージョンのセクション追加）を忘れないこと。インフラノート（`pooza/chubo2` の `docs/infra-note.md`）やそのリポジトリの Issue も進捗確認の対象に含めること

## 重要なドキュメント

- [Wiki](https://github.com/pooza/mulukhiya-toot-proxy/wiki) — ユーザー向けドキュメントの正本（5.0対応済み）
- [v5-plan.md](v5-plan.md) — 5.0計画の記録（全完了。5.1以降はIssue＋マイルストーンで管理）
- [upgrade-guide-5.0.md](upgrade-guide-5.0.md) — Wikiの[4.x → 5.0 アップグレードガイド](https://github.com/pooza/mulukhiya-toot-proxy/wiki/4.x-%E2%86%92-5.0-%E3%82%A2%E3%83%83%E3%83%97%E3%82%B0%E3%83%AC%E3%83%BC%E3%83%89%E3%82%AC%E3%82%A4%E3%83%89)へのリダイレクト
- [postmortem-2025-10-rack32.md](postmortem-2025-10-rack32.md) — rack 3.2トークン汚染インシデントの記録
- [postmortem-2026-03-nodeinfo.md](postmortem-2026-03-nodeinfo.md) — nodeinfo循環呼び出しによる本番全面停止の記録

## CI

GitHub Actions (`.github/workflows/test.yml`):

- Redis 7 サービスコンテナ（PostgreSQLは不使用: CIではDB依存テストを行わない方針）
- matrix strategy: `controller: [mastodon, misskey]` の2並列
- `bundle exec rake lint` (rubocop, slim_lint, erb_lint等)
- `bundle exec rake test` (test-unit、DB依存テストは自動スキップ)
- 個別テスト実行: `bin/test.rb ケース名`
- 依存: ffmpeg, libidn11-dev, libvips-dev

## ディレクトリ構成（主要）

```text
app/lib/mulukhiya/
  controller/     # SNS別コントローラ (Mastodon, Misskey, +α)
  service/        # SNS別サービスクライアント
  model/          # SNS別モデル (mastodon/, misskey/)
  handler/        # 投稿処理ハンドラー (42)
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
test/
  unit/handler/   # ハンドラーテスト (44)
  unit/worker/    # ワーカーテスト (12)
  unit/service/   # サービステスト (9)
  unit/uri/       # URIテスト (11)
  unit/model/     # モデルテスト (13)
  unit/daemon/    # デーモンテスト (3)
  unit/lib/       # その他ユーティリティテスト (35)
  contract/       # バリデーションテスト (11)
  fixture/        # テストフィクスチャ
```

## リリース運用

### バージョニング方針

- パッチリリース（5.0.x 等）は致命的な不具合時のみ
- 通常の機能追加・改善はマイナーバージョン（5.1.0 等）でまとめてリリース

### ホットフィックス手順

緊急パッチリリースの手順。通常リリースと異なり、develop → main マージではなく main に直接コミットする場合がある。

1. **バージョンバンプ**: `config/application.yaml` の `/mulukhiya/version`（410行目付近）を更新
2. **コミット・プッシュ**: develop（またはmain）にコミットしてプッシュ
3. **mainへマージ**: developで作業した場合は main へPRを作成しマージ
4. **タグ・リリースノート作成**: `gh release create vX.Y.Z --target main --title "X.Y.Z"`
5. **本番デプロイ**: 全サーバーにデプロイ（monit停止 → restart → monit開始）
6. **docs/CLAUDE.md 更新**: リリース済みセクションに追記
7. **Wiki 確認**: リリース内容に応じて [Wiki](https://github.com/pooza/mulukhiya-toot-proxy/wiki) の更新が必要か確認する（設定変更、API追加、廃止機能など）

バージョンが記載されている場所:

- **`config/application.yaml`** `/mulukhiya/version` — **唯一の正本**。`/mulukhiya/api/about` 等で参照される

### マイルストーン管理

- 1マイルストーンあたり10件前後で区切る（平均的なボリュームのIssueを基準とし、粒度の大きなIssueがある場合は件数を減らして調整する）
- 優先度の低いIssueは次のマイナーバージョンへ送る
- 計画書は作成せず、Issue＋マイルストーンで管理する
- セキュリティレビュー（[#4156](https://github.com/pooza/mulukhiya-toot-proxy/issues/4156)）は各マイルストーンの Issue をすべて消化した後、リリース直前に毎度実施する

### リリースノート

- セキュリティアップデート（gem のパッチ更新等）は、実質的に影響がなくてもリリースノートに記載する

### Dependabot運用

- `open-pull-requests-limit: 0` により、通常のバージョン更新PRは作成しない
- セキュリティアラートのPRのみ自動生成される
- 通常のgem更新は手動 `bundle update` で管理する
- セキュリティPRへの対応:
  - `bundle update` で既に対応済み → PRをCloseし「Already included via bundle update in commit xxxxx」とコメント
  - 未対応 → PRをマージ
- セキュリティアラートはリリース時の Gemfile.lock 更新で自動クローズされる
- `target-branch`: v4（4.x向け）と develop（5.x向け）の2エントリ

### Codexレビュー確認

PRマージ後にCodex（chatgpt-codex-connector[bot]）のレビューコメントが遅れて届くことがある。セッション開始時に最近マージされたPRのレビューコメントを確認し、未対応の有益な指摘があれば対応すること。

対応後はCodexのコメントに返信し、対応内容（コミットハッシュやIssue番号等）を記載する。

```bash
# 最近マージされたPRのCodexレビューコメントを確認
gh api repos/pooza/mulukhiya-toot-proxy/pulls/{number}/comments \
  --jq '.[] | select(.user.login == "chatgpt-codex-connector[bot]") | {body: .body[:200], path: .path}'
```

## 既知の注意事項

### rack 3.2問題

rack 3.2 + Sinatra 4.2 で「異なるアカウントの投稿として送信される」致命的問題が発生した（2025-10-12〜10-26）。
防御策（トークン整合性チェック・アカウントID検証）実装済み。rack 3.2.5 + Sinatra 4.1.1 に更新済み（#4053, #4054）。
ステージングでの同時アクセス再現テスト（#4055）完了済み（成功率100%）。
診断スクリプト: `bin/diag/concurrent_token_test.rb`。
詳細は [postmortem-2025-10-rack32.md](postmortem-2025-10-rack32.md) を参照。

### Webhook digest の安定性

`Webhook.create_digest` は Webhook URL の一部となる digest を生成する。入力は SNS の URI、OAuth トークン、`/crypt/salt`（フォールバック: `/crypt/password`）の3要素。
これらの値や生成ロジックを変更すると Webhook URL が変化し、外部連携（tomato-shrieker 等）が 404 になる。
5.2.0 で `/crypt/salt` 廃止により発生（#4106、5.2.1 で修正）。この領域の変更は慎重に行うこと。

### デーモン管理

daemon-spawn gem は廃止済み（#4098）。`Ginseng::Daemon` はスタンドアロンクラスとしてフォアグラウンド実行する。デーモン化は OS の init システムに委任する。

- **FreeBSD (rc.d)**: `daemon(8)` でバックグラウンド化。stop は `bin/xxx_daemon.rb stop`（PID ファイル経由で TERM 送信）
- **Ubuntu (systemd)**: `Type=simple`、`ExecStop=/bin/kill -TERM $MAINPID`
- **デプロイ時**: rc.d スクリプト / systemd unit の更新が必要（[config/sample/](../config/sample/) 参照）

### ginseng-web

- `Ginseng::Web::Sinatra` ラッパークラスは廃止済み（v1.3.45）
- Controller は `Sinatra::Base` を直接継承
- rack >= 3.1.14 / Sinatra ~> 4.1.0
- デフォルトブランチ: main（2026-02-22にstableからリネーム済み。他のginseng-*も全てmainに統一済み）

### 番組表システム（Program）

キュアスタ！等で稼働する番組表機能。Mastodon 側にも改造があり、以下のフローで更新される:

1. Mastodon（WebUI）→ POST `/mulukhiya/api/program/update`（モロヘイヤに更新要求）
2. モロヘイヤ `ProgramUpdateWorker`（Sidekiq）→ GAS エンドポイントから最新データ取得 → Redis 更新
3. Mastodon → GET `/mulukhiya/api/program`（更新後のデータ取得）→ 自身の番組表表示を更新

- **データソース**: `/program/urls` に設定した外部 URL（GAS 等）から JSON を取得。302 リダイレクトは HTTParty が自動追従
- **スケジューラ**: Sidekiq Scheduler で毎分 `ProgramUpdateWorker` を実行
- **有効条件**: `livecure?` → `/program/urls` が空でないこと

番組表が更新されない場合の切り分け:

1. **Sidekiq が稼働しているか** — `ProgramUpdateWorker` は Sidekiq 経由で実行されるため、Sidekiq 停止時はスケジュール実行も POST 経由のジョブも処理されない
2. **GAS エンドポイントが応答するか** — サーバーから `curl -sL` で `/program/urls` の URL を直接取得して確認
3. **Redis のキャッシュが古くないか** — `GET /mulukhiya/api/program` のレスポンスと GAS の最新データを比較

## v5.0 設定構造の概要

`config/application.yaml` の主要な構造（詳細は [v5-plan.md](v5-plan.md) を参照）:

```yaml
mastodon:
  capabilities:   # SNS固有の能力 (streaming, reaction, channel, decoration, repost)
  features:       # 機能フラグ (webhook, feed, announcement, annict)
  data:           # データアクセスパターン (account_timeline, favorite_tags, futured_tag, media_catalog)
service:          # 外部サービス設定 (amazon, annict, itunes, line, lemmy, peer_tube, piefed, poipiku, spotify)
handler:
  pipeline:
    base:         # 共通ハンドラーリスト（Mastodonスーパーセット、実行順の正本）
    misskey:      # Misskey固有オーバーライド (exclude: [...])
webui:
  importmap:      # CDN ESMモジュールのURL管理
```

## 関連リポジトリ

MastodonとMisskeyのソースコードがローカルに並列配置される。
パスはセッション開始時にユーザーから指示される。

用途:

- SNS側のAPI仕様確認、設定ファイルの参照
- モロヘイヤとの結合動作確認
- 必要に応じてSNS側のコード修正

### capsicum

[capsicum](https://github.com/pooza/capsicum) はFlutterベースのMastodon / Misskey クライアント。
モロヘイヤ導入済みサーバーでは拡張機能が利用可能になる設計。

- Issue相互参照: `pooza/capsicum#XXXX`
- API仕様: [docs/api.md](api.md) — capsicumが利用するモロヘイヤ固有エンドポイントのリファレンス
- API変更時: [docs/api.md](api.md) を更新し、破壊的変更がある場合は capsicum リポジトリに Issue を起票する

## 開発サーバー・インフラ

SSH経由で操作可能。接続情報は `~/.ssh/config` で管理（リポジトリには含めない）。
エイリアス名はセッション開始時にユーザーから指示される。

| 種別     | 台数 | OS       |
|----------|------|----------|
| Mastodon | 3    | FreeBSD  |
| Misskey  | 1    | Ubuntu   |

リモート側の操作（git pull、マイグレーション、サービス再起動等）も可能。

サーバー構成・SSH接続・デプロイ手順・チューニング設定等の詳細は [pooza/chubo2 インフラノート](https://github.com/pooza/chubo2/blob/main/docs/infra-note.md) を参照。

## push前の必須手順

1. `bundle exec rubocop`（lint通ること）
2. `bundle update`（依存更新後も動作すること）
3. `bundle exec rake lint`（更新後のlintも通ること）
4. その上で push

## コーディング規約

- rubocop, slim_lint, erb_lint に準拠
- 機能追加・バグ修正には対応するテストを書くこと（CIで実行可能な範囲で。DB依存・外部API依存のテストは無理に書かなくてよい）
- テスト: test-unit (Mulukhiya::TestCase 基底クラス)
- モック: WebMock (`require 'webmock/test_unit'` でtest-unitと統合済み。デフォルトはネット許可、モック使用テストで `WebMock.disable_net_connect!` を明示呼出)
- 設定アクセス: `config['/path/to/key']` (Ginsengのスラッシュ記法)
- ハンドラー設定: `handler_config(:key)` (5.0でシンボル記法に統一完了、ネストはYAML構造で表現)

### テスト作成ガイド

テストは `Mulukhiya::TestCase`（`Ginseng::TestCase` 継承）を基底クラスとする。

#### disable? パターン

test-unitのライフサイクルは `setup` → `run_test` → `teardown`。
`disable?` が `true` を返すと `run_test` はスキップされるが、**`setup` は常に実行される**。
DB接続や外部サービスに依存する `setup` では、冒頭に `return if disable?` を追加すること。

```ruby
def disable?
  return true unless Environment.dbms_class&.config?  # DB未接続ならスキップ
  return true unless test_token                        # トークン未設定ならスキップ
  return super
end

def setup
  return if disable?  # setupも保護する
  @model = SomeModel.new
end
```

#### CI環境でのスキップ条件

CIでは `config/local.yaml` に `controller: mastodon|misskey` のみ設定される。
以下は未設定のため、該当チェックでテストが自動スキップされる:

- `Environment.dbms_class&.config?` → PostgreSQL DSN未設定
- `test_token` → OAuthトークン未設定
- `account` → トークン経由のアカウント取得不可

#### Handler経由の間接DB依存

一見DB無関係なクラスも、Handler初期化チェーンを通じてDB接続を要求する場合がある:

`TagContainer.new` → `normalize` → `TaggingHandler` → `Handler#initialize` → `SNSService` → `account_class` → `Sequel::Model` → DB必須

このようなケースでは `disable?` に `Environment.dbms_class&.config?` チェックを入れるか、
`rescue` で例外を捕捉して `true` を返す。

### RuboCopに含まれない個人規約

以下はユーザーから都度指示される。指示があり次第ここに追記する。

- メソッド末尾でも `return` を省略しない（暗黙のreturnを使わない）

### ドキュメント表記規約

- **設定ファイルのパス**: ディレクトリを含めて表記する（`local.yaml` → `config/local.yaml`）
- **設定キーの参照**: Ginseng のスラッシュ記法で表記する（`service:` や `sidekiq.auth.user` ではなく `/service`、`/sidekiq/auth/user`）
- **サーバーの呼称**: 「インスタンス」ではなく「サーバー」を使う
- **UI の呼称**: 「UI」ではなく「WebUI」を使う
- **IP の表記**: 単独で使わず「IP アドレス」と表記する
- **ボットの呼称**: 英名（`info_bot` 等）ではなく日本語の役割名（「お知らせボット」等）を使う
- **ファイル参照**: サンプルファイルやテンプレート等への参照はマークダウンリンクにする
