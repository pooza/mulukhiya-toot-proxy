# リリース履歴

CLAUDE.md から分離した過去のリリースノート。直近リリースは [CLAUDE.md](../CLAUDE.md) を参照。

## リリース済み: 5.15.0（2026-04-06）

メディアカタログ API パフォーマンス改善、リモート isCat 判定 API、各種バグ修正。

- **#4211 メディアカタログAPI: N+1クエリの解消** — catalog/feedのself[row[:id]]をwhere(id: ids)の一括取得に変更
- **#4212 メディアカタログAPI: Misskey版SQLパフォーマンス改善** — 冗長なGROUP BY削除、LIMIT/OFFSETをキーワードフィルタ後の外側クエリに移動
- **#4210 メディアカタログAPI: ページネーションメタデータ** — レスポンスを `{items, page, has_next}` 形式に変更。LIMIT+1件取得で次ページ判定。WebUI対応済み。capsicum側も要対応（pooza/capsicum#71）
- **#4206 設定監査: 配列内オブジェクトの不明キー検出** — `detect_unknown_keys` で配列ノードの場合にスキーマの `items` を参照して各要素に再帰
- **#4198 リモートアカウントのisCat判定API** — `POST /mulukhiya/api/account/is_cat` でWebFinger→ActivityPub Actor取得、Redisキャッシュ付き
- **#4217 RemoteTagHandler: リモートタグ欠落修正** — `dic.key?` フィルタを削除し `local_tags.member?` のみに
- **#4215 RSS20FeedRenderer#cache: 例外型を明示**
- **#4214 NowplayingHandler.trim: Artist/Title行が削除されない** — trimロジックのバグを修正
- **#4209 NowplayingHandler.trim: uri.hostがnilの場合のNoMethodError** — nilガード追加
- fix: removal_rule_tagスキーマの重複パス(tags.rules)を削除
- fix: isCat APIでactor取得失敗時にnilをキャッシュしない
- fix: isCat APIのセキュリティ改善（SSRF防止・スレッド安全性・配列上限）
- test: IsCatContract・IsCatStorageのテスト追加、Storage系テストにRedis接続チェック追加

## リリース済み: 5.14.1（2026-04-04）

- fix: about APIで`/status_url`未設定時に500エラーになる問題を修正

## リリース済み: 5.14.0（2026-04-04）

設定監査機能の本格化、ハンドラー画面 UI 刷新、不要設定の廃止。

- **#4118 設定監査API・不要キー検出UI** — `GET /admin/config/audit` でバリデーションエラーと不明キーを検出。本番4台の local.yaml で網羅テスト実施
- **#4117 WebUI: 複雑なハンドラーパラメータ編集（CRUD一覧管理）** — 辞書タグ等の配列・オブジェクト型パラメータを管理画面から編集可能に
- **#4203 about API に `/status_url` を追加**
- **#4202 Misskey 絵文字パレット取得 API** (`GET /mulukhiya/api/emoji/palettes`)
- **#4205 `/ruby/jit`・`/ruby/bundler` 設定を廃止** — YJIT はランタイム判定に変更、bundler 自動実行はカスタム API 分離で不要に
- fix: 設定監査スキーマの偽陽性を解消（`/sentry`, `/service`, `/diag`, `/agent/info/webhook` 等）
- fix: ハンドラー画面の label / description 表示、コンテナ幅拡大、ボタンデザイン統一
- fix: 設定監査レイアウト崩れ修正（バリデーションエラーと不明キーの縦積み）

## リリース済み: 5.13.0（2026-04-03）

rack セキュリティ修正（CVE 13件）とハンドラーメタデータ・TagContainer修正。

- **セキュリティ: rack 3.2.6** — CVE-2026-34829 (High: 無制限チャンクアップロード)、CVE-2026-34827 (High: multipart DoS)、CVE-2026-34785 (High: Static ファイル露出) 他 Medium 9件、Low 1件を修正
- **#4194 ハンドラーに label / description メタデータを追加** — 全44スキーマYAML + Handler#label, #description アクセサ
- **#4199 文章の末尾に `#` が加えられる** — TagContainer で空タグ・nil値をフィルタ。ginseng-fediverse v1.8.22 で gem 側も修正
- **#4191 rc.d スクリプトに redis 依存を追加**
- fix: json-schema gem の MultiJSON 非推奨警告を抑制

## リリース済み: 5.12.1（2026-03-28）

ホットフィックス。Sentry で検出された本番障害 2 件を修正。全4台デプロイ済み。

- **#4193 ImageResizeHandler が type メソッド未実装で ImplementError** — #4184 で `update_metadata` 追加時に `ImageResizeHandler` への `type` 実装を漏らしたリグレッション。`nil` を返すことで早期リターン
- **#4192 Program#update で HTTParty::Response に .to_h を呼んで NoMethodError** — `.parsed_response` に修正

## リリース済み: 5.12.0（2026-03-27）

全5 Issue クローズ。動画アップロード改善、予約投稿タグ編集API、デコレーション復元、短縮URL改善。全4台デプロイ済み。

- **#4188 エピソードブラウザのコマンドトゥートにデコレーション解除を含める**
- **#4187 デコレーション復元APIの追加とタグセット解除時の連動**
- **#4186 予約投稿のタグ編集API** — ScheduledStatusStorage（Redis TTL付き）、ScheduledStatusSaveHandler（post_tootパイプライン先頭に登録）、PUT /scheduled_status/:id/tags
- **#4185 ShortenedURLHandler: youtu.be削除とt.co特別扱い** — youtu.beをホワイトリストから除外、t.coはホワイトリストに依存せずハードコードで常に展開対象
- **#4184 VideoFormatConvertHandlerテスト基盤整備とエッジケース対応** — pix_fmtチェック、video_codec nilガード、音声なし動画へのサイレント音声トラック自動付加、変換後のContent-Type/ファイル名更新
- fix: daemon環境でのOpen3 Broken pipe対策（EPIPE検出時のみ/dev/nullにリオープン）
- 本番Mastodon 3台に`S3_FORCE_SINGLE_REQUEST=true`適用（S3マルチパートダウンロードの動画破損対策）
- Ruby 4.0.2に更新

## リリース済み: 5.10.1（2026-03-22）

Codexレビュー指摘3件の修正。

- **fix: Config#admin_role_ids が空配列を返す** — `positive?`（Ruby Numeric）はSequel DSLではなく正しいSQLに変換されなかった。`> 0` に修正（#4172）
- **fix: StartupNotificationWorker の通知前ステータス保存** — `notify_if_changed` で通知前に `save_status` していたため、通知失敗時にステータスが更新済みになる不整合を修正（#4170 P1）
- **fix: GroupTagHandler#db_display_name のアクセサ経由参照** — Sequelモデルの生カラム値 `account[:display_name]` を直接参照するよう修正（#4169 P2）

## リリース済み: 5.10.0（2026-03-22）

全3 Issue クローズ。HEVC動画対応、about API拡張、ヘルスステータス変更通知。

- **#4168 ヘルスステータス変更時に再通知** — 前回のヘルスステータスをRedisに保存し、5分ごとのチェックで変更（OK→NG、NG→OK）を検出した場合にinfo_botから管理者へ再通知
- **#4172 about APIで管理者ロールIDを返す** — `GET /mulukhiya/api/about` の `config` に `admin_role_ids` フィールドを追加。capsicumの管理者バッジ表示に利用（pooza/capsicum#159）
- **#4171 HEVC動画のアップロード422修正** — VideoFormatConvertHandlerにコーデック互換性チェックを追加。H.265 mp4をlibx264でトランスコードしてからMastodonに送信
- GroupTagHandler#db_display_nameをアクセサ経由に戻す
- bundle update (nokogiri 1.19.2, mcp 0.9.0)

## リリース済み: 5.9.1（2026-03-21）

- **#4167 GroupTagHandler: 空タグ修正** — `db_display_name` が空文字列を返す場合に `#` のみが付加される不具合を修正

## リリース済み: 5.9.0（2026-03-20）

全4 Issue クローズ。カスタムAPI独立デーモン化、PieFed gem切り出し、GroupTagHandler、セキュリティ対応。全4台デプロイ済み。

- **#4144 カスタムAPIを独立デーモンに分離** — Bundler二重管理・Open3.capture3の不安定さを解消。cure-api v3.0.0として独立HTTPサーバーに移行。設計意図は [custom-api-redesign.md](custom-api-redesign.md) を参照
- **#4146 PieFed対応をginseng-piefedに切り出し** — ginseng-piefed gem を新規作成
- **#4164 GroupTagHandler** — PieFed community-hashtag-map 連携によるグループタグ自動付与
- **CVE-2026-33210** json gem format string injection 対応済み
- ginseng-piefed 0.1.1: Service#logger/config未定義バグを修正
- CIでGroupTagHandlerの外部HTTPリクエストを抑制

## リリース済み: 5.8.0（2026-03-16）

全7 Issue/PR クローズ。セキュリティレビュー対応、reblog_labelカスタマイズ、投稿編集APIパススルー（実験的）。

- **#4161 about APIでブースト/リノートのカスタムラベルを返す** — config/local.yamlで `mastodon:/misskey: > status: > reblog_label:` を設定し、capsicumから参照可能に
- **#4162 PUT /api/v1/statuses/:id パススルーの追加（実験的）** — capsicumからの投稿済みメディアALT編集に向けた基盤。capsicum側は継続検討中
- **#4157 Sentry: before_sendフィルタによる秘匿情報スクラビング**
- **#4158 bundler-auditの導入とCI統合** — sinatra CVE-2025-61921 は rack 3.2問題のため ignore 設定
- #4159 フロントJSテストのアサーション修正
- #4155 Wiki: Sentry.ioの設定項目をドキュメントに追加
- #4156 セキュリティレビュー実施済み

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
