# リリース履歴

CLAUDE.md から分離した過去のリリースノート。直近リリースは [CLAUDE.md](../CLAUDE.md) を参照。

## リリース済み: 5.21.2（2026-05-04）

ホットフィックス。`MediaCatalogUpdateWorker` の DB クエリ劣化が 2026-05-01 zugoga (デルムリン丼) に続き 2026-05-04 shallu (美食丼) でも再発し、本番でユーザーログイン・連合受信が止まる事象が観測された問題への対処。

- **#4306 fix: MediaCatalogUpdateWorker を OFFSET → cursor ページングに切替** — `app/lib/mulukhiya/worker/media_catalog_update_worker.rb` の `pages.times` ループを cursor ベースに置換。SQL テンプレート (`app/query/mastodon/media_catalog.sql.erb`) は #4220 で既に cursor 分岐実装済みだったため、worker 側で `cursor:` を渡すだけの最小変更。OFFSET ページングの典型劣化（成功 10 秒 ⇄ 劣化 数百秒の二極化）が解消され、PostgreSQL を長時間専有して Mastodon Web (port 3000) の `POST /inbox` 等を 60 秒タイムアウトに追い込む経路が断たれる。中期項目（専用キュー分離 / index 見直し）は #4322 / #4323 として 5.22.0 / 5.23.0 へ分離

## リリース済み: 5.21.1（2026-05-02）

ホットフィックス。5.21.0 で番組表エディタの「追加タグ」を空にして保存すると `GET /api/program` のレスポンスから `extra_tags` フィールド自体が欠落し、Mastodon WebUI 側で番組表全体が表示されなくなる回帰を修正。

- **#4320 fix: GET /api/program のレスポンスで extra_tags を常に配列に正規化** — 5.21.0 #4282 で番組表エディタが空欄を `null` で送信するようになり、`Program#update_entry` が `nil` を「キー削除」として処理した結果、`extra_tags` が空のエントリで API レスポンスからフィールド自体が欠落していた。`Program#data` で読み出し時に `extra_tags` を必ず配列に正規化することで、ストレージ層の `null=削除` セマンティクスを維持しつつ API レスポンスを安定させる。既存エントリ（5.21.0 で `extra_tags` が消えたもの）にも遡及効果

## リリース済み: 5.21.0（2026-05-02）

番組表エディタ品質確保とリリース前 5観点並列レビュー赤対応。番組表リニューアル（#4234）のフェーズ3 #4237 はフェーズ2 #4236 のエディタ実装で実質達成済みと整理してクローズ、フェーズ4 #4227 を 5.22.0 主軸に組み込み。

- **#4270 feat: ProgramEntryContract に長さ・パターン制約を追加（DoS 緩和）** — `MAX_KEY_SIZE=64` / `MAX_TEXT_SIZE=200` / `MAX_TAGS=32` / `MAX_TAG_SIZE=64` / `KEY_FORMAT=/\A[A-Za-z0-9_-]+\z/`
- **#4274 feat: PUT /admin/program/entry/:key を真の部分更新できるようにする** — `ProgramEntryUpdateContract` を新設、`null` でキー削除セマンティクス
- **#4258 chore: APIController#token の params[:token] フォールバック完全廃止** — capsicum プリセットサーバー全台 5.18+ 確認済み（2026-04-22）。以降の認証は `Authorization: Bearer` のみ
- **#4267 fix: Sinatra error ハンドラが Ginseng::Error 以外で落ちて 500 が無ログになる問題の改善**
- **#4268 fix: 連合しない投稿（チャンネル / localOnly）でタグ付与系ハンドラがスキップされない** — `Handler#non_federated_payload?` を導入し `tagging_handler` / `default_tag_handler` で投稿前にスキップ
- **#4273 fix: Program#update_cache 失敗時に invalidate_cache でフェイルセーフ** — Redis 書き込み失敗時の YAML/Redis 乖離を防ぐ
- **#4275 fix: /program/works/:id/episodes の `url` を正しく返す** — `AnnictService#episodes` が空文字を返していた
- **#4282 fix: 番組表エディタで optional フィールドを空にしてもクリアできない** — フォーム保存時に空フィールドを `null` で送るよう修正、`ProgramEntryUpdateContract` の null セマンティクスと組み合わせて削除可能に
- **#4276 chore: ProgramEntryContract をホワイトリスト経由で抽出する** — `PARAMS_KEYS` 定数で許可キーを定義
- **リリース前レビュー赤対応** — Controller#error の非 Ginseng エラー経路（#4267 で導入）でクライアントレスポンスに `e.message` 生値を返していた問題を修正。レスポンス body を `'Internal Server Error'` 固定に、ログは `e.log(path: ...)` 経由で `/logger/mask_fields` 適用に統一
- **#4237 chore: フェーズ3 を B 案でクローズ** — フェーズ2 のエディタ実装が旧フローを上流から置き換える設計だったため、フェーズ3 のスコープは実質達成。残った掃除タスクは #4308 で 5.22.0 へ
- **bundle update** — minitest 6.0.6 / sequel 5.104.0
- **マイルストーン管理を重み予算ベース (size:S/M/L) に移行** — 5観点レビュー由来の小粒 Issue が大量発生して件数目安が機能しなくなったため、重み合計 20〜25 を目安に運用変更。docs/CLAUDE.md の「マイルストーン管理」節を更新
- **積み残し**: 5観点並列レビュー黄送り 11 件は #4309〜#4319 として 5.22.0 / 5.23.0 へ分配。ステージング乖離は [chubo2#36](https://github.com/pooza/chubo2/issues/36)
- 本番デプロイ: 4 台（zugoga / lbock / shallu / sweep）

## リリース済み: 5.20.2（2026-05-01）

ホットフィックス。`MediaCatalogUpdateWorker` の DB クエリ劣化で Sidekiq `default` キューが詰まり、ユーザー操作起点ジョブ（タグセットクリア通知ほか）が数十分遅延する事象に対する応急処置。

- **#4306 fix: media_catalog_update のスケジュール間隔を 3m → 30m に緩和** — OFFSET ベースクエリが 170〜200 秒に劣化、1 ジョブ完走 12〜16 分 × `every: 3m` 投入で concurrency=5 のスロットを使い切り、`default` キュー全体を塞いでいた。デルムリン丼本番（zugoga）で 6,749 件滞留・最古 25 時間前を観測。`UserTagInitializeWorker` の `at:` 経路（タグセットクリア通知）が想定 4 分→実 43 分遅延、`DecorationInitializeWorker` 等も同様に遅延。発生レートを抑える短期対処。cursor ページング切替・専用キュー分離など根治対応は #4306 で別途対応。関連: 真因が同じため #4302（cron 経路の遅延）/ #4303（タグセットクリア通知遅延報告）も解消見込み
- 本番デプロイは zugoga（デルムリン丼）のみ実施。他サーバ（shallu / lbock / sweep）は同症状の確認後に別途対応

## リリース済み: 5.20.1（2026-04-30）

ホットフィックス。Misskey ドライブのアップロード時に `folderId` がドロップされ、画像がユーザーの既定アップロード先フォルダに格納されない回帰を修正。

- **#4297 fix: Misskey ドライブのアップロードで folderId が無視され既定フォルダに入らない** — `MisskeyController#post '/api/drive/files/create'` が `params[:folderId]` を `sns.upload` に渡しておらず、Misskey 純正 WebUI 等が送出する `defaultUploadFolderId` がドロップされていた。本番 syslog で `folderId` 送出を実証。`folderId` を含めて転送するよう修正。ginseng-fediverse 1.8.23 で `MisskeyService#upload` 側でも `folderId` を受け付けるよう拡張済み（ダイスキー本番でりゅうがさん報告）
- **bundle update** — ginseng-fediverse 1.8.22 → 1.8.23
- 本番デプロイは Misskey 系のダイスキー本番のみ実施、ステージングは dev23 のみ実施（Mastodon 系には無関係なため）

ドライブ閲覧側（「ファイルが見えずフォルダのみ表示される」症状）は nginx で `/api/drive/files`、`/api/drive/folders` が本体直結のためモロヘイヤ無関係。Misskey 本体 / Linode Object Storage 側として別途調査。

## リリース済み: 5.20.0（2026-04-28）

番組表エディタ実装（フェーズ2）、/sw/register 強化、リリース前レビュー赤対応。

- **#4236 feat: 番組表エディタ（フェーズ2）の実装** — admin 限定 CRUD UI、Annict 検索連携で `series` / `subtitle` / `episode` / `annict_work_id` / `annict_episode_id` を自動補完。`var/program.yaml` を Single Source of Truth とする
- **#4256 feat: POST /mulukhiya/api/sw/register にレート制限を導入** — `RateLimitStorage` 新規追加、アカウント単位で window 内回数制限（5.19.0 リリース前レビュー R4 の送り）
- **#4259 feat: /sw/register に endpoint ホスト allowlist を追加** — `config['/sw/register/allowed_hosts']` で許可ホストを設定可能（空 = 無制限）（5.19.0 R3 の送り）
- **#4262 fix: register_sw_subscription の存在チェックから sendReadMessage を除外** — 5.19.0 Codex P2 の送り、冪等性
- **リリース前レビュー赤対応** — `/admin/program/entry` 4 ルートの `e.log` → `e.alert` 昇格、`Program#next_annict_episode` の独自 logger を `e.alert` に統一、`views/program.slim` 有効列の命名修正
- **bundle update** — nokogiri 1.19.3
- **積み残し**: 5 観点並列レビューの赤・黄を Issue 化（#4269〜#4280、12 件）→ 5.21.0 で対応

## リリース済み: 5.19.1（2026-04-23）

ホットフィックス。モロヘイヤ WebUI / capsicum で認証 Bearer トークンが通らず更新系 API が 401 で失敗する回帰を修正。

- **#4260 fix: APIController#token の Bearer 分岐で暗号化トークンを復号** — `/oauth/callback` が発行する `access_token_crypt` を `Authorization: Bearer` で受けた際に生値のまま `@sns.token` に入り、SNS 本家への API コール (`sns.repost` / `sns.toot` / Misskey の `body[:i]` / Mastodon の `Authorization: Bearer`) で 401 になっていた。影響していた機能: WebUI「削除してタグづけ」、capsicum 予約投稿タグ付け、`/sw/register` / `/unregister`（5.19.0 Codex P1 指摘と同根）。`MastodonController` / `MisskeyController` のプロキシ経路（純正クライアントの平文 Bearer 前提）は無変更

## リリース済み: 5.19.0（2026-04-22）

Misskey Web Push 登録プロキシ API の追加 (capsicum プッシュ通知対応)、WebUI の Bearer ヘッダー化、Poipiku 対応廃止、スキーマバリデーション見直し、段階的リファクタ、リリース前レビュー手順の導入。

- **#4254 feat: Misskey Web Push 登録プロキシ API (POST /mulukhiya/api/sw/register / /unregister)** — Misskey 本家の GHSA-7pxq-6xx9-xpgm 対応を踏まえた境界張り直し。`write:account` スコープ要求 + `sw_subscription` テーブルへ直接 INSERT + Misskey Redis キャッシュ無効化
- **#4230 feat: WebUI の GET トークン送信を Authorization ヘッダーに移行** — GET クエリ経由のトークン送出を廃止。後方互換として `params[:token]` フォールバックは 5.21.0 で完全廃止予定
- **#4255 fix: リリース前レビューで検出した赤 7 件を修正** — SSRF ガード / 冪等性仕様整合 / Redis プール漏れ / /tagging/tag/search rescue 復活 / e.alert 昇格 / /health に misskey_redis 追加 / Sentry PII scrub 拡張
- **#4251 fix: スキーマバリデーションで未設定の任意項目が required エラーになる** — 5.18.0 #4245 の取り残し
- **#4253 refactor: POST /tagging/tag/search を TagSearchService に移設** — 親 #4233 段階的リファクタ
- **#4250 chore: ポイピク (Poipiku) 対応機能の全廃止**
- **is_cat キャッシュ TTL デフォルトを 6h → 1h に変更** — 運用観察のため
- **リリース前レビュー手順をプロジェクトガイドに導入** — 5 観点並列サブエージェント + Codex リアクション運用 (capsicum 側から移植)
- **bundle update**

## リリース済み: 5.18.0（2026-04-17）

番組表永続化・Postgres ヘルスチェック改善・is_cat キャッシュ制御・puma/parallel メジャー更新。

- **#4235 feat: 番組表の永続 YAML ストア導入・Program クラス差し替え** — `var/program.yaml` を Single Source of Truth とし Redis は読みキャッシュに。外部 URL pull 機構は維持、既存 API 契約は変更なし
- **#4244 feat: Postgres.health に WARN 分類、通知にヒステリシス導入** — プール枯渇を WARN として区別し、スポット誤報を抑制
- **#4248 feat: is_cat キャッシュの TTL を設定可能にし、デフォルトを 6 時間に短縮**
- **#4249 feat: is_cat キャッシュ管理の rake タスクを追加**
- **#4245 fix: base.yaml の top-level required を merged 検証前提に見直し** — ginseng-core #477 追随
- **#4243 fix: postgres.pool.size の既定値を 4 → 10 に引き上げ** — Sequel::PoolTimeout を回避
- **#4247 fix: fetch_actor が ActivityPub レスポンスをパースできていなかった**
- **fix: Misskey メディアカタログの next_cursor を note_id ベースに修正**（Codex レビュー指摘）
- **fix: Ginseng::ApplicationError を Ginseng::Error に修正**（Sentry MULUKHIYA-TOOT-PROXY-10）
- **#4241 chore: parallel 2.0 へ更新**
- **#4240 chore: puma 8.0 へ更新** — 明示的に `tcp://0.0.0.0` を bind

## リリース済み: 5.17.0（2026-04-14）

Postgres ヘルスチェック・接続プール・API 認証の改善。

- **#4228 fix: Postgres.health が Mastodon API 応答に依存していた問題を修正** — `SELECT 1` を直接実行。goatdeam の PostgreSQL 停止誤報を解消
- **#4232 feat: Postgres 接続プールサイズ・タイムアウトを設定可能にする** — `/postgres/pool/{size,timeout}` を local.yaml で上書き可能に。zugoga の Sequel::PoolTimeout 対策
- **#4223 fix: APIController で Authorization: Bearer ヘッダー認証に対応（security）** — GET クエリにトークンが漏れる問題を修正
- **#4238 fix: Authorization ヘッダが Bearer 形式の場合のみトークンとして採用**
- **#4207 refactor: /emoji/palettes の実装を MisskeyService に移設** — APIController を 42行 → 9行に縮小
- **#4222 feat: メディアカタログキャッシュの管理 rake タスクを追加**
- **#4226 docs: メディアカタログ API のレスポンス形式をドキュメントに反映**
- **#4240/#4241 chore: puma/parallel をピン留めし bundle update 巻き込みを回避**

## リリース済み: 5.16.1（2026-04-09）

ホットフィックス。絵文字ショートコードのタグ化退行修正と gem 互換性修正。

- **#4224 RemoteTagHandler: 絵文字ショートコードがタグとして復活する退行を修正** — `strict_key?` で strict 辞書由来キーのみ除外し、#4089 と #4217 を両立
- **rspotify fork 参照に切替（Ruby 4.0 互換）** — mime-types 2.99.3 の SyntaxError を解消

## リリース済み: 5.16.0（2026-04-07）

メディアカタログ集中改善。

- **#4219 メディアカタログ: ステータスURLが不正になる環境がある** — S3_ALIAS_HOST環境でドメイン・パスが不正。`/mastodon/attachment/base_url` 設定を追加
- **#4220 メディアカタログ: 大規模インスタンスでのクエリパフォーマンス改善** — Redisキャッシュ+Sidekiq定期ジョブ+カーソルページング
- **#4221 emoji/palettes API: scopeカラムのARRAYリテラル型不一致** — capsicumから修正済み・動作確認完了
- **ginseng-postgres#96 SQLインジェクション対策** — QueryTemplate#escape追加、全テンプレート適用

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
