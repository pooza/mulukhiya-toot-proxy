# mulukhiya-toot-proxy 開発ガイド

## プロジェクト概要

通称「モロヘイヤ」。各種ActivityPub対応インスタンスへの投稿に対して、内容の更新等を行うプロキシ。

- **技術スタック**: Ruby 4.0 / Sinatra 4.1 / Sidekiq 8.1 / Puma / Vue 3
- **DB**: PostgreSQL (Sequel ORM) / Redis
- **テンプレート**: Slim / SASS
- **ginseng-\*系gem**: 自作フレームワーク。必要に応じて全て更新してよい

## 主要ユースケース: プリキュア実況・感想投稿ワークフロー

開発者本人（pooza）は概ね毎晩プリキュアを視聴し、視聴直後に感想を書く活動を数年継続している。加えて、毎朝の挨拶投稿の末尾にその日の番組表まとめ（開始時刻 + 作品名 + 話数 + サブタイトル）を付ける運用も並走している。番組表・実況機能、capsicum のエピソードブラウザ、Annict 連携、エピソード感想投稿、番組表エディタのコピー機能などはすべてこのワークフローを支えるために作られており、プロダクト設計の中心的な駆動力。

設計判断時の評価軸:

- **毎晩のルーチンでどれだけ手数が減るか** を第一の評価軸にする
- ただし「pooza 専用」に作り込まず、**他ユーザーが同じフローに乗れる汎用性** も同等に意識する。capsicum 側 UI は最初から他ユーザー利用を想定した設計に寄せる（実装は pooza 専用で始めても、将来マルチユーザー化できる構造にしておく）
- モロヘイヤ側の管理画面（番組表エディタ等）は当面 pooza 専用で問題ない
- 新機能を提案するときは「毎晩のルーチンのどこが楽になるか」を具体的に述べる

関連: #4227（Annict 視聴記録・感想投稿 API、本ワークフローの最終ピース） / 番組表リニューアル系 #4234-#4237 / #3157（Annict records/:id 経過観察）。

## 設計方針: 本体改造の最小化

モロヘイヤの存在意義は「Mastodon / Misskey 本体への改造を減らす」こと。姉妹サーバーを含む本体側へのパッチを避けて、プロキシ層でふるまいを足す設計。

**理由**: 本体 upstream のバージョンアップや fork 切り替え時の摩擦を最小化するため。パッチが増えるほど upgrade 工数と衝突リスクが膨らむ。

**判断基準**:

- 設計・実装の判断基準として常に「これは本体に手を入れずに実現できるか？」を優先する
- 本体側 DB スキーマ変更（UNIQUE 制約追加、カラム追加等）は原則として行わない
- モロヘイヤが本体より厳しい制約を勝手にかける選択も避ける（upgrade 整合が崩れる）
- TOCTOU レース等、本体と同じ race を抱えている場合はむしろ「本体と揃っている」ことをもって受容する（例: Misskey `/api/sw/register` の SELECT-then-INSERT、5.19.0 R8 判断）
- 例外として PGroonga 採用（pooza/mastodon, pooza/misskey 双方に起票済み）は検討対象。緊急ではないため折を見て実施予定

## 姉妹サーバーとコミュニティ設計

モロヘイヤは複数の SNS サーバーで稼働しており、一部は「姉妹サーバー」の関係にある。

- **姉妹サーバー**: 同じデフォルトハッシュタグを持ち、同一リレーサーバー（`deas.b-shock.co.jp`）に接続しているサーバー同士
- **仕組み**: `DefaultTagHandler` が投稿にデフォルトハッシュタグを自動付与 → リレー経由で姉妹サーバーに伝播 → タグタイムラインが同期し、同じコミュニティとして機能
- **姉妹関係**: デルムリン丼 ↔ ダイスキー（同一管理者）、キュアスタ！ ↔ 外部管理のダイスキー（異なる管理者）

`DefaultTagHandler` は実装としてはシンプルだが、コミュニティ運用の基盤を支える重要なハンドラー。

## カスタムフィードの残置（cure-api との切り分け）

cure-api 独立化（#4144）でカスタム API（`/api/custom`）は完全削除されたが、**カスタムフィード**（`/feed/custom`、`custom_feed.rb` + `command_line.rb`）はモロヘイヤ側に残置されている。利用者は2名。`Open3.capture3` を使うが Bundler 環境切替が無いため EPIPE 系の問題は起きていない。

cure-api 側を触るときに「カスタムフィードも一緒に整理」と思い込まないこと。両者は名前が似ているが完全に別系統。

## media_catalog の実験的扱い（5.23.0〜）

`media_catalog` 機能（`/mulukhiya/api/media`、`/feed/media`、`MediaCatalogUpdateWorker`、Mastodon WebUI のメディアフィード）は 5.23.0 (#4343) で **デフォルト無効化・実験的機能扱い** に変更された。

**経緯**: 本番 Mastodon (zugoga / shallu / lbock) で底値レイテンシ 175 秒級の重 SQL（`media_attachments_pkey` backward scan + 85 万行フィルタアウト）が観測され、2026-05-19 には DB プール枯渇による全サーバー投稿不可障害も発生。本来の最適化（#4323、partial index `idx_mlkhy_statuses_local_catalog` 追加）は本番複数台への段階的展開で 1〜2 週間スケールであり、機能自体が pooza の毎晩ルーチン（Annict + 番組表）と無関係なため、最適化を急ぐより停止する判断に切り替えた。

**現在の状態**:

- `config/application.yaml` の `/mastodon/data/media_catalog` / `/misskey/data/media_catalog` のデフォルトは `false`
- `/features` API で `media_catalog: bool` を露出（capsicum / モロヘイヤ WebUI の事前判定用）
- 有効化したいサーバーは overlay yaml で個別に `true` を設定する（opt-in）
- disabled 時の API は 503 + `{ "available": false, "items": [] }`（404 と区別し「機能未提供」ではなく「現在 OFF」を伝える）
- WebUI / capsicum (pooza/capsicum#606) は features を見て placeholder を出す

**機能再開を判断する場合の手順**:

1. #4323 を on-hold から外す
2. [media-catalog-index-plan.md](media-catalog-index-plan.md) に従い zugoga / shallu / lbock の本番 DB に candidate A の partial index を `CONCURRENTLY` 適用
3. 効果計測（同じ EXPLAIN 比較）後、対象サーバーの overlay yaml で `/mastodon/data/media_catalog: true` を設定
4. `pooza/mastodon` migration PR で index を恒久化（[chubo2 docs/infra-note.md](https://github.com/pooza/chubo2) の daisskey drive_file 先行事例と同パターン）

新規 mulukhiya インストールは無効が既定。本機能を前提に新規実装を入れないこと（再開判断とセットで設計する）。

## tomato-shrieker との連携

詳細は [tomato-shrieker-integration.md](tomato-shrieker-integration.md) を参照。Webhook digest の生成要素・連携フロー・インシデント履歴をまとめている。

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

#### メンテナンスのタイミング

Dependabotセキュリティアラートが発生したときに、セキュリティ対応と合わせて溜まった小修正のバックポートもまとめて行う。

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

## リリース済み: 5.27.0（2026-06-19）

capsicum ナウプレ連携の「URL を自前で返せる経路」を拡張した回。Spotify user-level OAuth + currently-playing API (#4337) と URL→メタ逆引き `/nowplaying/resolve-url` (#4415) を新設。あわせて Misskey プッシュ購読の重複蓄積修正 (#4408)、5.26.0 リリース前レビュー繰越 (#4405)、本リリース前 5観点レビュー由来のログ scrub (#4418)。

- **#4337 feat: Spotify user-level OAuth + currently-playing API** — `GET /spotify/oauth_uri`・`POST /spotify/auth`・`DELETE /spotify/auth`・`GET /spotify/currently_playing` 新設。Authorization Code Flow で per-user トークンを UserConfig（Redis・暗号化）保管し失効/401 時に自動 refresh。client_secret は capsicum に置かずサーバー保持。`features.spotify_enabled`（サーバーゲート）/`spotify_linked`（ユーザー単位）露出。3 エンドポイント（#4382 resolve / currently_playing / #4415 resolve-url）を統一レスポンス形で設計。**ただし Spotify クォータ規約により capsicum #570 が塩漬けのため `user_oauth_enabled` は既定 OFF・全台 OFF で出荷**（連携導線は自動非表示、コード/config 構造は将来復活用に残置）。capsicum #465/#570 連携
- **#4415 feat: ナウプレ resolve-by-URL `POST /mulukhiya/api/nowplaying/resolve-url`** — 共有 URL→メタ（#4382 の title→URL の逆方向）。host 振り分け（Spotify/Apple Music）で `{url, provider, normalized:{title,artist,album}}` or `{url:nil}`。`features.nowplaying_url_resolver` 露出。ユーザー URL を直接 fetch せず ID 抽出のみで固定 API を叩く SSRF-safe 設計。capsicum #729 連携
- **#4408 fix: sw/register の重複 subscription 蓄積を修正** — dedup を `(userId, endpoint)` 単位にし、鍵ローテで残った既存重複行を 1 行へ集約
- **#4405 5.26.0 リリース前 5観点レビュー繰越（黄・緑まとめ）** — 公開 `/word/suggest` の cold-cache 同期 fetch を非同期化、`PronunciationDictionaryUpdateWorker` の size ログを `update` 戻り値から取り無限 enqueue を防止（Codex P1）、体裁修正
- **本リリース前 5観点レビュー赤近い黄インライン (#4418)** — OAuth 認可コード（`code`）が info ログに平文記録されていたのを scrub 対象に追加（`POST /spotify/auth`・既存 `POST /annict/auth` 共通改善）
- **bundle update** — bundler-audit クリーン、Dependabot 0
- ステージング: dev04（FreeBSD・美食丼）/ dev23（Misskey・ダイスキー）で develop=5.27.0 を確認（dev15/dev22 はメンテ外につき対象外）
- **本番デプロイ: 4 台完了**（2026-06-19、shallu / zugoga / lbock / sweep、全台 version 5.27.0 / health 200 全コンポーネント OK）

### 振り返り

**期間**: 5.26.0 リリース 2026-06-09 → 5.27.0 リリース・本番デプロイ 2026-06-19（10 日間）。

**消化**: 5.27.0 マイルストーン Issue 全消化（#4337/#4415/#4408/#4405/#4418 + #4417 ステージング config 戻し）。

**5観点レビュー仕分け**: 真の赤 1 件（Spotify token refresh の同時実行ロストアップデート）だが、**本機能が `user_oauth_enabled:false` で全台 OFF＝ライブ露出ゼロ**のため非ブロックと判断。同 `refresh!` 上の黄群（auth/oauth_uri/delete の alert→log 対称化、Spotify HTTP timeout 明示）と Codex P2（失効トークンクリア）をまとめて #4414（Spotify ハードニング、capsicum #570 復活と同時着手）へ繰越。赤近い黄 1 件（OAuth code ログ scrub）のみ #4418 でインライン同梱。別系統の黄（sw_subscription 集約の非トランザクション race）は #4420 へ。

**Codex 仕分け**: release PR #4412 に P2 1 件（refresh 失効時の stale トークンクリア）。機能 OFF のため #4414 へ集約し、返信 + リアクション付与済み。

## リリース済み: 5.26.0（2026-06-09）

ナウプレ enrich プロキシ (#4382) と読み付き単語サジェスト API (#4397) の新設を主軸に、capsicum 連携（投稿サジェスト・ナウプレ共有 URL 解決）の土台を整えた回。あわせて Program の ProgramFetcher 分割 (#4347)、5.25.0 レビュー送り (#4394) の構造改善、本リリース前 5観点レビュー由来のログ/アラート整備を含む。

- **#4382 feat: ナウプレ enrich プロキシ `POST /mulukhiya/api/nowplaying/resolve`** — Bearer 必須。構造化メタ（title/artist/album）→ Spotify/iTunes 検索 → 共有可能 URL 解決の読み取り専用 enrich。プロバイダ優先 `prefer`（capsicum トグル）> `source_app_name` ヒント > サーバー既定 `/nowplaying/resolve/default_provider`（既定 apple_music、フォールバック許可）。`features.nowplaying_resolver` 露出、整形は capsicum 側でモロヘイヤはステートレス。未使用の旧系統①（`itunes_nowplaying`/`spotify_nowplaying`）を削除し検索ロジックを resolver へ集約（capsicum #466/#484/#668/#570 連携）
- **#4397 feat: 読み付き単語サジェスト API `GET /mulukhiya/api/word/suggest`** — capsicum #614 投稿サジェスト連携。`PronunciationDictionary` が GAS の pron.json を Redis キャッシュし、読み（ひらがな→カタカナ正規化はモロヘイヤ側で吸収）前方一致 → 表層前方一致 → 部分一致でランク付け、同ランクは五十音順タイブレーク（#4403）。`features.word_suggest` を `/word_suggest/urls` 設定有無で `DynamicFeatures::REGISTRY` から動的導出。本体 API #4398、HEAD 非対応ホスト（GAS）の content-length 事前チェック 403 ログ抑止 #4400
- **#4347 refactor: Program クラスを ProgramFetcher へ分割** — fetch/キャッシュ責務を切り出し、rubocop Metrics/ClassLength disable 解除（5.25.0 から送り）
- **#4394 5.25.0 リリース前 5観点レビュー 5.26.0 送り（黄・緑まとめ）** — favorites 400 ログ、program.ics alert 昇格、harness の `test?` ガード、冪等ロック storage/rescue 重複の共通化（`AnnictIdempotencyLockStorage` 抽出）、request ログ本文 scrub、start_time 二段検証、slim 記法ゆれ、api.md 補記
- **本リリース前 5観点レビュー赤近い黄インライン (#4404/#4406)** — 公開 `/word/suggest` 由来の Sentry スパム抑止: `PronunciationDictionary` の Redis 読み/書き失敗（接続障害）を alert→log に倒し、破損（不正 JSON/非配列）のみ alert+invalidate に限定（read #4404 / write は Codex P2 を受け #4406 で対称化）。`nowplaying/resolve`・`word/suggest` のユーザー入力（曲名・検索語）ログ scrub 追加。残り黄・緑は #4405 で 5.27.0 送り
- **bundle update** — Gemfile.lock 変更なし（既に最新、bundler-audit クリーン、Dependabot 0）
- **運用向け設定変更**: word/suggest を有効化するサーバーは `config/local.yaml` に `/word_suggest/urls`（GAS pron.json）設定が必要。未設定なら `features.word_suggest=false` で無効（既定で無害）。`PronunciationDictionaryUpdateWorker` が 10 分毎更新
- ステージング: dev04（FreeBSD・美食丼）/ dev23（Misskey・ダイスキー）で develop=5.26.0 を確認（dev15/dev22 はメンテ外につき対象外）
- **本番デプロイ: 4 台完了**（2026-06-09、shallu / zugoga / lbock / sweep。辞書設定 `/word_suggest/urls`（GAS pron.json）を各サーバー `config/local.yaml` へ投入、全台 `features.word_suggest=true` / version 5.26.0 / health 200）

### 振り返り

**期間**: 5.25.0 リリース・本番デプロイ 2026-06-07 → 5.26.0 リリース 2026-06-09（2 日間）。

**消化**: 5.26.0 マイルストーン Issue 全消化（#4382/#4347/#4394/#4397）。

**5観点レビュー仕分け**: 真の赤 0 件。赤近い黄 2 系統（word/suggest の Redis 障害 Sentry スパム / 入力ログ scrub）をインライン (#4404)、Codex P2（save 側 write の alert スパム）を追い fix (#4406)、残り黄・緑（リダイレクト SSRF 非対称、cold-cache 同期 fetch、docs 表記揺れ・タイポ等）は #4405 にまとめて 5.27.0 送り。

**Codex 仕分け**: ドラフト解除した release PR #4396 に届く Codex レビューは 5観点と重複見込み。#4404 上の P2（Redis 全断時の write 側 alert スパム）は #4406 でインライン対応しリリースに同梱。

## リリース済み: 5.25.0（2026-06-07）

APIController 段階的リファクタの締め (#4285) + 5.23/5.24 レビュー送りの構造改善 + 番組表の iCalendar 出力・開始時刻欄 + Annict review API + 運用ログ整備 + 報告ベース修正を組み合わせた着地回。

- **#4287 feat: 番組表を iCalendar (.ics) 形式で出力** — `GET /mulukhiya/api/program.ics` 新設。tomato-shrieker IcalendarSource 購読想定で認証不要・livecure? ゲート。有効かつ妥当な start_time のエントリを単発イベント化。icalendar gem が SUMMARY 等を自動エスケープ
- **#4366 / #4372 feat: 番組表エディタに開始時刻 (start_time) 欄** — 24 時間制テキスト入力、保存時 `HH:MM` ゼロ埋め正規化。#4286 で見送った分の再実装、#4287 iCalendar の前提
- **#4342 feat: Annict review (作品全体感想) 投稿 API** — `POST /mulukhiya/api/annict/review`、createReview mutation 中継（searchWorks で数値 annictId → Relay node ID 解決、#4339 の前科を review 側で再発させない）。capsicum #592 連携。冪等ロック（Lua CAS、異常頻度の Sentry alert 昇格）を record API と同型実装
- **#4348 refactor: /about の features 動的合流を DynamicFeatures に集約**（5.23 レビュー送り、annict_linked / media_catalog / program_editable の集約）
- **#4285 refactor: PUT /scheduled_status/:id/tags を ScheduledStatusTagUpdater に移設** — #4233 段階的リファクタの 3 件目（最大、ロールバック含む）。ロードマップ完了
- **#4362 ops: Sidekiq 内部ログを syslog へ出し no-reader pipe 消失を防ぐ** — FreeBSD 3 台のログ消失を `Syslog::Logger` 切替 + stdio `/dev/null` reopen で解消（#4264 副次発見）
- **#4377 fix: CustomFeed が null/非配列を返すと FeedUpdateWorker クラッシュ** — RSS20FeedRenderer で防御し空配列フォールバック（Sentry MULUKHIYA-TOOT-PROXY-26 根治）
- **#4383 fix: Misskey favorites/create 冪等 400 パスの副作用非発火を明記・整合**（post_bookmark の PieFed ミラー等を冪等成功時に発火させない）
- **#4389 fix: TestHarness が DSN 上書き後に Postgres singleton を張り直す**（#4379 後続、stale 接続除去）
- **#4379 test: fedi-test-harness 接続情報の test config 注入導線**（DSN/info トークン自動配線、`config.reload` 跨ぎ保持）
- **#4360 test: ProgramTest の auto_update 順序依存修正**
- **リリース前 5観点レビュー赤近い黄インライン (#4395)** — annict record/review の rescue でユーザー入力起因の AuthError(403)/NotFoundError(404) まで Sentry alert していたのを log のみに抑止（反 alert-spam 方針）。廃止語「インスタンス」→「サーバー」整理。残り黄・緑は #4394 で 5.26.0 送り
- **bundle update** — Gemfile.lock 変更なし（既に最新、bundler-audit クリーン、Dependabot 0）
- ステージング: dev04（FreeBSD・美食丼）/ dev23（Misskey・ダイスキー）デプロイ済み（5.25.0 / health 全 OK / WebUI 200 / 新規 program.ics 200 text/calendar）
- **本番デプロイ: 4 台完了**（2026-06-07、zugoga / shallu / lbock / sweep、全台 version 5.25.0 / health 200 / 公開エンドポイント 200）。実況終了後に実施。本デプロイで Sentry MULUKHIYA-TOOT-PROXY-26 が解消
- **デプロイ時の教訓**（[chubo2 infra-history](https://github.com/pooza/chubo2) 参照）: 5.25.0 で `.ruby-version` が 4.0.5 に上がっており、未導入サーバー（今回 shallu）は `rbenv install 4.0.5` が前提。フレッシュ gemset での `bundle install` は rb_sysopen 一過性エラーが出ることがあり再実行で解消。SSH 越しは `bash -lc`（rbenv 読込）必須・サービス再起動は `</dev/null >/dev/null 2>&1` 必須・`bundle install` は省略不可

### 振り返り

**期間**: 5.24.0 リリース 2026-05-28 → 5.25.0 リリース・本番デプロイ 2026-06-07（10 日間）。

**消化**: 5.25.0 マイルストーン Issue 全消化（#4285/#4287/#4342/#4348/#4360/#4362/#4366/#4372/#4377/#4383/#4389 + #4379 関連サブ群）。当初計画の #4351 media_catalog 再有効化は 5.26.0 へ移動 — Gate 検証で partial index だけでは sub-second に届かず、前提として #4393（query 再構成/非正規化、size:L）が必要と判明しブロック。

**5観点レビュー仕分け**: 真の赤 0 件。赤近い黄 2 件（alert spam 抑止 / 廃止語）をインライン (#4395)、残り黄 4 + 緑 4（favorites 400 ログ、program.ics alert 昇格、harness の test? ガード、lock storage/rescue 重複の共通化、request ログ本文 scrub、start_time 二段検証、slim 記法ゆれ、api.md 補記）は #4394 にまとめて 5.26.0 送り。

**運用観察**: media_catalog 再有効化 (#4351) は zugoga 本番 EXPLAIN で partial index 単独では底値レイテンシが sub-second に届かず、query 再構成/非正規化 (#4393) を前提化。5.26.0 主軸候補に昇格。

## 次期マイルストーン: 5.28.0

主軸未確定（テーマレス回想定）。現時点の候補・繰越:

- **#4414 security: Spotify OAuth ハードニング（size:M）** — 5.27.0 リリース前 5観点レビュー + Codex P2 の繰越集約先。token refresh 同時実行のロストアップデート（真の赤）、refresh 失効時の stale トークンクリア、auth/oauth_uri/delete の alert→log 対称化、Spotify HTTP timeout 明示、state(CSRF)。**capsicum #570（Spotify クォータ規約で塩漬け）の復活＝機能有効化と歩調を合わせて着手**。それまでは `user_oauth_enabled:false` で全台 OFF のためライブ露出なし
- **#4420 concurrency: sw_subscription 集約の非トランザクション race（size:S）** — #4408 の後始末。同時 register の狭い窓を `db.transaction` or canonical 決定論化で塞ぐ
- **#4323 perf: media_attachments 関連 index 見直し** — サブ #4393（sub-second 化 query 再構成/非正規化、size:L）が #4351 zugoga 再有効化の前提。実行 runbook は docs/media-catalog-index-plan.md
- #4233 APIController 段階的リファクタは残る長大エンドポイントがあれば随時サブ化（直近サブ #4283/#4284/#4285 は全着地）

## ロードマップ仮置き

Issue #4233 の APIController 段階的リファクタは「1〜2 マイルストーンに 1 件」の方針でサブ Issue 化済み。残ペースで進める想定:

- 5.22.0: #4283 GET /media（最小 24 行）— **完了**
- 5.24.0: #4284 POST /status/tags（中規模 26 行）— **完了**
- 5.25.0: #4285 PUT /scheduled_status/:id/tags（最大 64 行、ロールバック含む、size:L）— **完了**

なお #4233 のサブ Issue（#4283/#4284/#4285）は全て着地。残る長大エンドポイントがあれば #4233 から随時サブ化する。

番組表リニューアル（#4234）はフェーズ4 #4227 を 5.22.0 で達成し全フェーズ完了。capsicum 側は pooza/capsicum#298（v1.26）で対応中。

### on-hold

- #3157 Annict `https://annict.com/@account/records/:id` 形式（Annict API 側に同等機能なし。2026-05-24 再確認でも Record 型に databaseId 相当なし。次回チェック目安 2026-08）
- #3877 Mastodon形式「タグづけ」復活
- #4195/#4196/#4197 ユーザー向けハンドラートグル（API+UI）
- #4229 ostruct gem: gli 2.22+ で runtime 依存解消後に Gemfile から削除（rails-erb-lint の更新待ち）
- #4298 Misskey ドライブの一覧でファイル不可視（Misskey 本体／Object Storage 側の問題、状況変化があれば再開）
- #4301 capsicum #344 向け Misskey avatarDecorations API（capsicum 側の進捗待ち）

### メタ Issue（生きている）

- #4233 APIController: 残る長大エンドポイントの段階的リファクタ（サブ #4283/#4284/#4285、上記ロードマップで進行中）
- #4323 perf: media_attachments 関連 index 見直し（サブ #4393 sub-second 化 query 再構成 / #4351 zugoga 再有効化 / #4352 shallu/lbock 横展開 / #4353 本家 migration / #4375 Misskey track）。**zugoga 本番 EXPLAIN で partial index 単独では sub-second に届かないと判明し、#4393（query 再構成/非正規化、size:L）を #4351 の前提に格上げ**。実行 runbook は docs/media-catalog-index-plan.md（決定ゲート Gate 0〜2 + rollback）。Mastodon は statuses partial index、Misskey は別ルート（drive_file、daisskey で実証済み）

### マイルストーン未設定

（現在なし。本リリース計画で未設定 Issue はすべて 5.24.0 / 5.26.0 に吸収。）

5.22.x 以前のリリースノートは [release-history.md](archive/release-history.md) を参照。

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
- 各コメントについて以下を判定する:
  1. **未返信** → 指摘内容を確認し、対応が必要か判断。必要なら修正コミットまたは Issue 起票、返信してリアクション付与
  2. **返信済みだがリアクション未付与** → 修正コミットの存在を確認し、+1 リアクションを付与
  3. **返信済み・リアクション済み** → 完了。報告不要
- 判定方法: `gh api repos/pooza/mulukhiya-toot-proxy/pulls/{number}/comments --jq` で全コメントを取得し、Codex コメントの `id` に対する `in_reply_to_id` を持つ返信の有無、および Codex コメントへのリアクション（`reactions`）を確認する

### 5. Sentry の新規イシュー確認

- `sentry-cli issues list` で未解決イシューを確認する（`~/.sentryclirc` に認証トークンとデフォルトプロジェクトが設定済み）
- 各イシューの過去コメント（対応経緯）を確認する: `curl -sH "Authorization: Bearer $TOKEN" https://sentry.io/api/0/issues/{issue_id}/comments/ | python3 -m json.tool`
- 新規・未解決のイシューがあれば内容を確認し、対応が必要か判断する（対応が必要なら GitHub Issue を起票）
- 判断結果や対応経緯はコメントとして記録する: `curl -sX POST -H "Authorization: Bearer $TOKEN" -H "Content-Type: application/json" -d '{"text":"コメント内容"}' https://sentry.io/api/0/issues/{issue_id}/comments/`
- `$TOKEN` は `~/.sentryclirc` の `[auth]` セクションから取得する
- Sentry 未導入のプロジェクトではこのステップをスキップする

### 6. 外部リポジトリの同期確認（chubo2）

- `cd ~/repos/chubo2 && git fetch origin` + `git log HEAD..origin/main --oneline` でリモートとの差分を確認
- `docs/infra-note.md` に変更があれば MEMORY.md のインフラセクションに反映が必要か判断
- `gh issue list --state open` で open Issue の変動を確認

### 7. マイルストーンの状態確認

- `docs/CLAUDE.md` と MEMORY.md に記載された次期マイルストーンの Issue が、実際の GitHub 上の状態（open/closed）と一致しているか確認
- クローズ済みの Issue があれば MEMORY.md から除外し、`docs/CLAUDE.md` も必要に応じて更新

### 8. fedi-test-harness の upstream バージョンチェック

- [harness-verified-versions.yaml](harness-verified-versions.yaml) の `last_checked` を見る。**当日から 4 日以上経過していれば**以下を実行（経過していなければスキップ）:
  - `gh api 'repos/mastodon/mastodon/releases?per_page=15'` と `gh api 'repos/misskey-dev/misskey/releases?per_page=15'` で最新リリースを取得（ローカル `gh` は認証済み）
  - 台帳の `mastodon.verified` / `misskey.verified` より**厳密に新しい** stable、または Mastodon の新しい RC（`vX.Y.Z-rc.N`、ベース版が verified より新しいもの）があるか判定
  - 新しいものがあれば、検証を促す（Mastodon RC=約1週間の RC 期間中／Mastodon stable=リリース直後／Misskey=リリース後数日でデプロイ前）。検証フローは台帳ファイル冒頭参照。実検証・bump はその場で着手するか Issue 化するかを相談する
  - 確認したら台帳の `last_checked` を当日に更新してコミット（新規が無くても更新する）
- 専用の cloud/cron ジョブは使わず、この同期手順に織り込む方式（モロヘイヤは作業頻度が高いため十分）。詳細は MEMORY の `feedback_upstream-release-harness-verification`

### 9. MEMORY.md の更新

- 上記で検出した差分（Issue 状態、リリース日の誤り、件数のズレ等）を反映

### 10. 同期結果の報告

- 現在のブランチ・状態、マイルストーンの状況、各確認項目の結果をまとめて報告する

## 情報の記載先ルール

- **課題・タスク** → GitHub Issue で管理（インフラ面の課題は `pooza/chubo2` の Issue として起票）
- **プロジェクト共有すべき知見** → `docs/CLAUDE.md` など git 管理下のファイルに記載
- **インフラ情報** → `pooza/chubo2` リポジトリの `docs/infra-note.md` に記載
- **進捗の同期** → `MEMORY.md` だけでなく `docs/CLAUDE.md` も更新すること。特にリリース済みバージョンの反映（「開発中」→「リリース済み」への変更、次バージョンのセクション追加）を忘れないこと。インフラノート（`pooza/chubo2` の `docs/infra-note.md`）やそのリポジトリの Issue も進捗確認の対象に含めること

## 重要なドキュメント

- [Wiki](https://github.com/pooza/mulukhiya-toot-proxy/wiki) — ユーザー向けドキュメントの正本（5.0対応済み）
- [api.md](api.md) — API リファレンス（capsicum 等クライアント向け）
- [release-notes-template.md](release-notes-template.md) — `gh release create` 用のリリースノート定型フォーマット
- [tomato-shrieker-integration.md](tomato-shrieker-integration.md) — tomato-shrieker との連携仕様
- [ginseng-config-internals.md](ginseng-config-internals.md) — Ginseng::Config 内部構造
- [test-harness.md](test-harness.md) — #4379 chubo2 fedi-test-harness を使った実サーバーテストの手順
- [capsicum-requirements.md](capsicum-requirements.md) — capsicum プロジェクトからの依頼事項
- [media-catalog-index-plan.md](media-catalog-index-plan.md) — #4323 media_catalog index 見直し調査ドラフト（zugoga 本番ベースライン EXPLAIN 取得済み・candidate A 適用方針確定、#4343 で機能をデフォルト無効化したため適用は on-hold）

### アーカイブ (docs/archive/)

完了済み・解決済みのドキュメント。経緯の参照用に保持。

- [v5-plan.md](archive/v5-plan.md) — 5.0計画の記録（全完了）
- [custom-api-redesign.md](archive/custom-api-redesign.md) — カスタムAPI設計見直し（cure-api として分離完了）
- [upgrade-guide-5.0.md](archive/upgrade-guide-5.0.md) — Wiki へのリダイレクト
- [upgrade-guide-5.3.md](archive/upgrade-guide-5.3.md) — Wiki へのリダイレクト
- [postmortem-2025-10-rack32.md](archive/postmortem-2025-10-rack32.md) — rack 3.2トークン汚染インシデント
- [postmortem-2026-03-nodeinfo.md](archive/postmortem-2026-03-nodeinfo.md) — nodeinfo循環呼び出しインシデント

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

### 通常リリース手順

1. **マイルストーンのIssueをすべて消化**
2. **リリース前レビュー**: 下記「リリース前レビュー」の 5 観点並列レビューを実施。必修（赤）のみ本リリースで対応し、残り（黄・緑）は Issue 起票して次リリース以降へ
3. **セキュリティレビュー**: Dependabotアラート確認、`bundle update`、bundler-audit実行。問題があれば修正コミット
4. **ステージング検証（省略不可）**: `develop` をステージング全4台（dev04 / dev15 / dev22 / dev23）にデプロイし、ヘルスチェック・`/mulukhiya/api/about`・WebUI を目視確認する。緊急ホットフィックス以外で省略しない（5.7.0 で省略 → #4159 が発生した教訓）
5. **バージョンバンプ**: `config/application.yaml` の `/mulukhiya/version` を更新
6. **リリースPR作成**: `develop` → `main` へPRを作成
7. **CI緑を確認してマージ**: `gh run list` でステータス確認、`in_progress` なら `gh run watch` で待つ。コードが同一でも CI 結果を踏んでからマージする
8. **タグ・リリースノート作成**: `gh release create vX.Y.Z --target main --title "X.Y.Z"`。フォーマットは [release-notes-template.md](release-notes-template.md) 参照
9. **本番デプロイ**: 全サーバーにデプロイ（sidekiq → puma → listener の順で再起動。monit停止 → restart → monit開始）
10. **リリース後の更新**:
    - docs/CLAUDE.md: 「開発中」→「リリース済み」に変更、次バージョンのセクション追加。**直近 3 マイナーのみ残し、4 マイナー前以前は [archive/release-history.md](archive/release-history.md) へ移動する**（例: 5.20.0 リリース時に 5.17.x をアーカイブへ）
    - Wiki: リリース内容に応じて [Wiki](https://github.com/pooza/mulukhiya-toot-proxy/wiki) の更新が必要か確認（設定変更、API追加、廃止機能など）。**当該バージョンだけでなく直近 2〜3 バージョン分の反映漏れも合わせてチェックする**
    - インフラノート（`pooza/chubo2` の `docs/infra-note.md`）: 作業履歴セクションにデプロイ記録を追記（デプロイ日・バージョン・主な変更内容・特記事項）
    - MEMORY.md: リリース履歴・インフラセクションを同期

### リリース前レビュー

各マイルストーンの Issue が消化済みになった後、バージョンバンプに入る前に実施する。**単一のセキュリティレビューだけでは実用上の問題が取りこぼされる**ため、以下 5 観点を独立したサブエージェントで並列に走らせ、指摘を合流させる。

| 観点 | 焦点 |
| --- | --- |
| セキュリティ | `/security-review` スキル。認証・Bearer トークン取り扱い・シークレット scrub・入力検証 |
| API 契約 | モロヘイヤ固有エンドポイント（`/mulukhiya/api/*`）、Mastodon/Misskey 本家 API 呼び出しの正確性、ginseng-fediverse interface 整合、`docs/api.md` との齟齬 |
| 並行性・ライフサイクル | Sidekiq worker、Sequel 接続プール、Redis 接続、listener の WebSocket 再接続、systemd 前提の daemon 駆動 |
| エラー処理・観測性 | Sentry 計装、`Ginseng::Error` の scrub、`/health` 応答の WARN/NG 判定、ログ出力の個人情報漏洩チェック |
| コーディングスタイル・規約整合性 | rubocop / slim_lint / erb_lint、`handler_config(:key)` 記法、設定のスラッシュ記法、廃止語（「インスタンス」→「サーバー」など） |

対象範囲は `v<前リリース>..develop` の差分。Codex（`chatgpt-codex-connector[bot]`）は PR ready 時に走るので併走させ、重複しない指摘だけを拾う。

指摘は以下の基準で分類し、必要最小限のみ本リリースで対応、残りは Issue 起票して次リリース以降に送る:

- **赤（必修）**: データ破損・セキュリティ・ユーザー可視の機能不全
- **黄（余力があれば）**: 単一の edge case、観測性ギャップ
- **緑（送り）**: 将来の拡張時に顕在化しうる構造改善

capsicum 側で先行運用しており、v1.18 のレビューでは 5 観点でセキュリティ単独では見つからなかった実害バグを複数検出した実績がある（[pooza/capsicum #325](https://github.com/pooza/capsicum/issues/325) の enrichNotifications unread フラグ欠落など）。Codex 停滞時の保険としても機能する。

### ホットフィックス手順

緊急パッチリリースの手順。通常リリースと異なり、develop → main マージではなく main に直接コミットする場合がある。

1. **バージョンバンプ**: `config/application.yaml` の `/mulukhiya/version`（410行目付近）を更新
2. **コミット・プッシュ**: develop（またはmain）にコミットしてプッシュ
3. **mainへマージ**: developで作業した場合は main へPRを作成しマージ
4. **タグ・リリースノート作成**: `gh release create vX.Y.Z --target main --title "X.Y.Z"`
5. **本番デプロイ**: 全サーバーにデプロイ（monit停止 → restart → monit開始）
6. **docs/CLAUDE.md 更新**: リリース済みセクションに追記
7. **Wiki 確認**: リリース内容に応じて [Wiki](https://github.com/pooza/mulukhiya-toot-proxy/wiki) の更新が必要か確認する（設定変更、API追加、廃止機能など）
8. **インフラノート更新**: `pooza/chubo2` の `docs/infra-note.md` 作業履歴セクションにデプロイ記録を追記

バージョンが記載されている場所:

- **`config/application.yaml`** `/mulukhiya/version` — **唯一の正本**。`/mulukhiya/api/about` 等で参照される

### マイルストーン管理

5観点並列レビュー導入（5.19.0〜）以降、レビュー由来の小粒 Issue（仕様補足・docs 修正・単発バリデーション）が大量に発生するようになり、件数では実態を反映しなくなった。**サイズラベル + 重み予算**で管理する。

#### サイズラベル

| ラベル | 想定差分 | 重み |
| --- | --- | --- |
| `size:S` | 50 行未満 / 単発バリデーション・小バグ修正・docs 修正 | 1 |
| `size:M` | 50〜200 行 / 新メソッド・リファクタ単位・契約変更 | 3 |
| `size:L` | 200 行超 / 新エンドポイント・スキーマ変更・複数ファイル横断 | 8 |

新規 Issue 起票時にいずれかを付ける。既存 Issue にも遡及付与する。

#### 重み予算

- 1 マイルストーンの目安: **20〜25 重み**（従来「10 件前後」と接続する感覚値。M を基準に S が混在する想定）
- 上限を超えそうな Issue は次のマイナーバージョンへ送る（緑送り扱い）
- 計画書は作成せず、Issue ＋ マイルストーン ＋ 重み合計で管理する

#### 主軸宣言（任意）

テーマ性の強いリリース（番組表フェーズ系・大規模リファクタ等）では、`size:L` を 1〜2 件「主軸」として「次期マイルストーン」節の冒頭に置く。テーマ性が薄い回（複数系統の集積）は宣言なしで重み合計だけ守る。

モロヘイヤはバックエンド・プロキシの性質上、複数クライアント（capsicum / 純正 WebUI / 外部連携）の要求が並列で来るため、テーマレス回が多い前提で運用する。

### リリースノート

- 定型フォーマットは [release-notes-template.md](release-notes-template.md) を使う（5.18.0 / 5.19.0 形式）。ホットフィックスでも同フォーマット
- セキュリティアップデート（gem のパッチ更新等）は、実質的に影響がなくてもリリースノートに記載する
- 「アップグレード手順」には[更新手順](https://github.com/pooza/mulukhiya-toot-proxy/wiki/%E6%9B%B4%E6%96%B0%E6%89%8B%E9%A0%86)Wikiへのリンクを毎回含める。加えて4.x系ユーザー向け[アップグレードガイド](https://github.com/pooza/mulukhiya-toot-proxy/wiki/4.x-%E2%86%92-5.0-%E3%82%A2%E3%83%83%E3%83%97%E3%82%B0%E3%83%AC%E3%83%BC%E3%83%89%E3%82%AC%E3%82%A4%E3%83%89)へのリンクも当分含める

### Dependabot運用

- `open-pull-requests-limit: 0` により、通常のバージョン更新PRは作成しない
- セキュリティアラートのPRのみ自動生成される
- 通常のgem更新は手動 `bundle update` で管理する
- セキュリティPRへの対応:
  - `bundle update` で既に対応済み → PRをCloseし「Already included via bundle update in commit xxxxx」とコメント
  - 未対応 → PRをマージ
- セキュリティアラートはリリース時の Gemfile.lock 更新で自動クローズされる
- `target-branch`: v4（4.x向け）と develop（5.x向け）の2エントリ
- **bundler-audit**: `rake lint` に統合済み。RubyGems ソースの gem の既知脆弱性を自動スキャンする。`ginseng-*` 系 gem は git ソースのため対象外。`ginseng-*` の依存 gem に脆弱性がある場合は、該当 gem のリポジトリで `bundle update` して対応する

### Codexレビュー確認

PRマージ後にCodex（chatgpt-codex-connector[bot]）のレビューコメントが遅れて届くことがある。セッション開始時に最近マージされたPRのレビューコメントを確認し、未対応の有益な指摘があれば対応すること。

対応後はCodexのコメントに**返信とリアクションの両方を付与する**: 返信で対応内容（コミットハッシュやIssue番号等）を明記し、コメントに `+1` リアクションを付ける。**両方揃って「完了」**。片方だけではセッション同期時に未完了と判定される。

```bash
# 最近マージされたPRのCodexレビューコメントを確認
gh api repos/pooza/mulukhiya-toot-proxy/pulls/{number}/comments \
  --jq '.[] | select(.user.login == "chatgpt-codex-connector[bot]") | {id, body: .body[:200], path: .path, reactions: .reactions.total_count}'

# リアクション付与（対応済み確定時）
gh api repos/pooza/mulukhiya-toot-proxy/pulls/comments/{comment_id}/reactions -X POST -f content=+1
```

Codex が一時的に停滞して自動指摘が出ないことがある。その場合は前述「リリース前レビュー」の 5 観点並列レビューが代替・補完として機能する。

## 既知の注意事項

### rack 3.2問題

rack 3.2 + Sinatra 4.2 で「異なるアカウントの投稿として送信される」致命的問題が発生した（2025-10-12〜10-26）。
防御策（トークン整合性チェック・アカウントID検証）実装済み。rack 3.2.5 + Sinatra 4.1.1 に更新済み（#4053, #4054）。
ステージングでの同時アクセス再現テスト（#4055）完了済み（成功率100%）。
診断スクリプト: `bin/diag/concurrent_token_test.rb`。
詳細は [postmortem-2025-10-rack32.md](archive/postmortem-2025-10-rack32.md) を参照。

### 認証トークンの復号パターン

ユーザー由来の OAuth トークンは「平文」と「暗号化済み（`.encrypt`）」の両形式で入って来うる:

- **平文**: Mastodon / Misskey 純正クライアントが送る生 OAuth トークン、直 API アクセス等
- **暗号化**: モロヘイヤ WebUI / capsicum のように `/oauth/callback` の `access_token_crypt` を localStorage 等に保存して Bearer で送るパス

どちらでも扱えるよう正規化する場合は慣用句 `token.decrypt rescue token` を使う（`Account.get` / `UserConfig` / `AnnictService` / `LineService` / `LineAlertHandler` / `APIController#token` 等）。復号失敗は平文フォールバック。

一方、**管理者が設定ファイルに書く値は暗号化前提**なので `config['/path/to/secret'].decrypt`（rescue なし）とする。失敗＝設定不備でフェイルストップさせるのが正しい（Spotify / YouTube / Sidekiq auth 等）。

Controller 層での注意:

- **APIController#token** はモロヘイヤ固有 API 用。WebUI/capsicum の暗号化 Bearer を受けるので Bearer 分岐でも `.decrypt rescue bearer` する（5.19.1 / #4260 で修正）
- **MastodonController#token / MisskeyController#token** は純正クライアント向けプロキシ。Bearer は平文 OAuth トークン前提でそのままパススルー

内部の `@sns.token` には**常に平文**が入るのが不変条件。これが崩れると `sns.post` / `sns.toot` / Misskey の `body[:i]` / Mastodon の `Authorization: Bearer` 等、SNS 本家へ出る段階で 401 になる。

**Ruby 構文の落とし穴**: `return X rescue Y` を `def ... rescue ... end` のメソッド末尾 rescue と併用すると、`return` が発火せず次行にフォールスルーする（`return X; rescue Y` と解釈される）。必ず `plain = X rescue Y; return plain` か `return (X rescue Y)` と書くこと。5.19.1 の初版修正で実際に踏んだ罠で、[LineAlertHandler#token](app/lib/mulukhiya/handler/line_alert_handler.rb#L17-L19) のように外側 rescue がない関数では同じ書き方が動くため気づきにくい。

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

`config/application.yaml` の主要な構造（詳細は [v5-plan.md](archive/v5-plan.md) を参照）:

```yaml
mastodon:
  capabilities:   # SNS固有の能力 (streaming, reaction, channel, decoration, repost)
  features:       # 機能フラグ (webhook, feed, announcement, annict)
  data:           # データアクセスパターン (account_timeline, favorite_tags, futured_tag, media_catalog)
service:          # 外部サービス設定 (amazon, annict, itunes, line, lemmy, peer_tube, piefed, spotify)
handler:
  pipeline:
    base:         # 共通ハンドラーリスト（Mastodonスーパーセット、実行順の正本）
    misskey:      # Misskey固有オーバーライド (exclude: [...])
webui:
  importmap:      # CDN ESMモジュールのURL管理
```

### user_config 更新時の注意

- `UserConfigStorage#update` は `deep_merge` + `deep_compact` で Redis に保存する
- 値を `null` で送るとそのキーは `deep_compact` で消える。認証解除など「ユーザー設定の削除」操作で利用する想定
- 4.x→5.0 で `service:` 配下に移動した外部サービス設定（annict, spotify, amazon, itunes, line, peer_tube, piefed 等）はフォールバック付き。削除操作では新旧両方のパスに `null` を送る必要がある（#4088 で対応済み）

### ハンドラスキーマと required

- `application.yaml` にデフォルト値があるキーには、ハンドラスキーマで `required` を付けない
- 理由: `local.yaml` で部分上書きする運用のため、required を付けると未上書きキーを持つ正常な設定が validation エラーになる
- スキーマを追加する際はまず `application.yaml` にデフォルトがあるかを確認する

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
- インデントは常に2スペース。見栄えのための位置揃え（代入の右辺にcase/if式を置いて深くインデントする等）は使わない。`x = case ...` ではなく、各分岐内で個別に代入する

### ドキュメント表記規約

- **設定ファイルのパス**: ディレクトリを含めて表記する（`local.yaml` → `config/local.yaml`）
- **設定キーの参照**: Ginseng のスラッシュ記法で表記する（`service:` や `sidekiq.auth.user` ではなく `/service`、`/sidekiq/auth/user`）
- **サーバーの呼称**: 「インスタンス」ではなく「サーバー」を使う
- **UI の呼称**: 「UI」ではなく「WebUI」を使う
- **IP の表記**: 単独で使わず「IP アドレス」と表記する
- **ボットの呼称**: 英名（`info_bot` 等）ではなく日本語の役割名（「お知らせボット」等）を使う
- **ファイル参照**: サンプルファイルやテンプレート等への参照はマークダウンリンクにする
