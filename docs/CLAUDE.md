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

## リリース済み: 5.24.0（2026-05-28）

5.23 レビュー送り消化 + 番組表エディタ拡張 + 報告ベース新規対応 + capsicum お知らせ通知連携を中心とする整理・小粒着地回。テーマ性は薄いが capsicum 側の機能解放に必要な API 改善（#4354 / #4355）と毎晩ルーチン補助（#4286 番組表まとめコピー）を組み合わせた。

- **#4272 feat: auto_update 有効時は番組表エディタを参照専用にする** — 書き込み 4 ルートが 409 Conflict を返し、WebUI 側は `features.program_editable` で編集 UI を出し分け
- **#4286 feat: 番組表エディタの有効エントリをまとめてクリップボードへコピー** — 毎朝の挨拶投稿運用支援。最小スコープ実装（`start_time` 欄追加は見送り、貼り付け後に手編集する運用）。Issue 本来スコープの開始時刻フィールド + iCalendar 出力 (#4287) は 5.25.0 送り
- **#4284 refactor: POST /status/tags を StatusTagAddService に移設** — #4233 段階的リファクタの 2 件目（26 行）
- **#4344 feat: status post の custom emoji shortcode 前後に ZWSP 自動挿入ハンドラを追加** — fedibird ユーザー報告起点。Mastodon target のみ介入。Codex P2 指摘で時刻形式 `12:34:56` 等の誤マッチを回避するため SHORTCODE_PATTERN を英字/`_` 始まりに限定
- **#4265 fix: メディアアップロードの 413 を Sentry alert 対象から外しユーザー向けメッセージへ変換** — `Ginseng::HTTP#upload` 経由の本家 413 (MAX_ATTACHMENT_FILE_SIZE 超過) をユーザー入力起因として扱い、Sentry MULUKHIYA-TOOT-PROXY-1T を抑止。本家 mastodon/misskey 両 controller に `handle_upload_gateway_error` ヘルパを追加
- **#4264 daemon 調査** — 本番 4 台に SSH 確認し production モード起動・stdio 状態・Environment.type すべて対応不要と判定してクローズ。副次発見の Sidekiq ログ消失 (FreeBSD 3 台で no-reader pipe へ書き込み) は #4362 として 5.25.0 送り
- **#4354 feat: features.announcement_push を /api/about で公開** — capsicum お知らせ通知連携。フラグ参照で push 配信 UI を出し分け
- **#4355 feat: GET /announcement/list を追加** — capsicum-relay (capsicum-relay#14) からの公開キャッシュ参照用、認証不要
- **#4345 fix: AnnictRecordLockStorage#release を compare-and-delete に変更** — TTL 跨ぎで他人ロックを誤削除しない、Lua CAS
- **#4346 feat: AnnictRecordLockStorage 冪等性ロックの異常頻度を Sentry alert に昇格** — 1 分 bucket / account_id 単位で `alert_threshold` (既定 10) 到達時に alert
- **#4349 refactor: /media disabled 応答を MediaCatalogDisabledRenderer に切り出し** — #4343 整理の継続
- **リリース前 5観点レビュー赤近い黄インライン対応** — EmojiSpacingHandler の `result.push(rewritten:)` が投稿本文 (DM 含む) を info ログへ流出させていたのを `inserted: count` メタ情報のみに圧縮。Program editor 4 ルートで `Ginseng::ConflictError` (409) が `e.alert` で Sentry alert spam を生んでいたのを ConflictError 限定で info ログ + alert 抑止する分岐に変更
- **リリース前 5観点レビュー docs 追記** — docs/api.md に `features.announcement_push` と `GET /announcement/list` を追記
- **5観点レビュー次リリース送り** — #4364 で黄 (episode_id alert payload, 暗黙 return 3 箇所, shortcode 単一文字コメント) + 緑 (EMPTY_PAYLOAD freeze, `lock&.` ノイズ, EVALSHA キャッシュ) をまとめて 5.25.0 へ
- **bundle update** — json 2.19.7
- 本番デプロイ: 4 台（zugoga / lbock / shallu / sweep）

### 振り返り

**期間**: 5.23.0 リリース 2026-05-23 → 5.24.0 リリース 2026-05-28（5 日間）。本リリース 8 PR + 5観点赤・黄インライン 1 コミット + bundle update + version bump。

**消化**: 11 Issue（番組表系 2 + capsicum 連携 2 + 5.23 レビュー送り 3 + 段階的リファクタ 1 + 調査 1 + 報告ベース 1 + 413 適正化 1）。#4287 / #4342 は 5.25.0 送り。

**主軸**: 当初「テーマレス回」と宣言、結果としては (1) 番組表エディタ系 (#4272/#4286)、(2) capsicum お知らせ通知連携 (#4354/#4355)、(3) ZWSP ハンドラ (#4344)、(4) 413 適正化 (#4265) の 4 系統が並列で着地。`pooza` 側の deploy 要求 (4354/4355) を起点に 5/28 中の短期リリースに向けて 1 セッション完結で残作業をすべて捌いた。

**5観点レビュー仕分け**: 真の赤なし。赤近い黄 2 件 (emoji_spacing 本文ログ流出 / Program editor ConflictError Sentry spam) を hotfix インライン、docs 追記 (announcement_push / announcement_list) もインライン、残り黄 3 件 + 緑 3 件は #4364 にまとめて 5.25.0 送り。

**Codex 仕分け**: PR #4356 (#4272) 上の P2 は #4360 として 5.25.0 送り。PR #4361 (#4344) 上の P2 (時刻形式誤マッチ) はインライン即修正してリアクション付与。

**運用観察**:

- `#4264` 調査で本番 FreeBSD 3 台の Sidekiq ログが no-reader pipe へ書き込まれ完全消失していることが判明。これまで Sentry の致命エラーしか観測できていなかった。#4362 で Mulukhiya::Logger (syslog) 経由へ切替検討
- PR ベース指定漏れ事故 — `gh pr create` が repo default (main) をベースに採用する仕様で、3 PR が main 起点でマージされ main / develop が diverge。merge commit で修復したが、次回以降 `gh pr create --base develop` の指定を徹底する必要

**反省**:

- `gh pr create --base develop` の指定漏れで意図しない main 起点マージが 3 件発生。CI が通っただけでマージしてしまったため気づくのが遅れた。PR 作成直後に `gh pr view <num> --json baseRefName` を確認するワークフローを徹底
- EmojiSpacingHandler の本文ログ流出は新ハンドラ開発時のテンプレ判断 (`result.push(text:)` で text の中身をどこまで残すか) の問題。今後新ハンドラを書く際は「Reporter に乗る値が info ログへ流れる」点を意識する

## リリース済み: 5.23.0（2026-05-23）

5.22 リリース前 5観点並列レビューの黄送り掃き出しと、本リリース前 5観点並列レビュー対応を主とする「整理回」。あわせて本番で観測された重 SQL 病理（2026-05-19 障害、底値レイテンシ 175 秒級）を受け、メディアカタログ機能を実験的扱いとしデフォルト無効化する運用判断を反映（#4343）。

- **#4343 feat: media_catalog をデフォルト無効化し disabled シグナルを返す** — `data.media_catalog` のデフォルトを `false` に反転（実験的機能扱い）。disabled 時の `/mulukhiya/api/media`・`/mulukhiya/feed/media` は **404 ではなく 503** + body `{"available": false, ...}` を返し、`/about` の `features.media_catalog` で discovery 可能にした。経緯と再開判断は [docs/media_catalog.md](media_catalog.md) を参照。capsicum 側 gate は [pooza/capsicum#606](https://github.com/pooza/capsicum/issues/606)
- **#4338 feat: features API に `annict_linked` を追加** — ユーザー単位の Annict 連携状態を `/about` の features に動的合流（capsicum 連携）
- **#4336 feat: 番組表エディタの各エントリにコピーボタン**（作品名・話数+サブタイトル、毎朝の挨拶投稿運用の手数削減、#4286 の代替最小実装）
- **#4331 feat: Addrinfo.getaddrinfo にタイムアウト** — Puma スレッド枯渇防止
- **#4330 feat: POST /annict/record に冪等性** — 重複 record 投稿を抑止
- **#4329 feat: AnnictService の GraphQL エラーをカテゴリ別 status code で返す**
- **#4318 feat: ProgramEntryContract のエラーメッセージにフィールド名を含める**
- **#4316 fix: Program#update_cache の rescue 整理と失敗文脈付与**
- **#4334 perf: RateLimitStorage を EVALSHA + NOSCRIPT フォールバックに移行**
- **#4328 perf: HTTP fetch のサイズ検証を Content-Length 事前判定に切替え**
- **#4335 refactor: MediaCatalogUpdateWorker の `cursor_pagination?` を Attachment 側に移譲**（#4343 の前提整理）
- **#4333 refactor: RemoteHost.public? の bare rescue を具体例外に絞る**
- **#4319 refactor: tagging_handler.rb / program.rb の暗黙 return を明示**
- **#4313 refactor: ProgramEntryUpdateContract の params 抽出順序整理**
- **#4314 docs: docs/api.md に ProgramEntryContract の上限値・null セマンティクスを補記**
- **#4280 docs: docs/api.md の表記揺れ修正**（インスタンス→サーバー）
- **#4332 wontfix クローズ** — SwSubscriptionContract allowed_hosts は allow-all デフォルトが妥当（endpoint がベンダー管理で allowlist 列挙不能、内部宛 SSRF は #4271 で対応済み、NOTE コメントに理由明記）
- **リリース前 5観点レビュー赤対応** — MediaCatalogUpdateWorker の scheduler 直叩き経路で `disable?` が効かない穴（sidekiq-scheduler が `Sidekiq::Client.push` を直接呼ぶため `Worker.perform_async` 側 gate を通らない）を `perform` 先頭ガード追加で封じ込め。docs 表記揺れ追加修正、`/feed/media` の disabled 時挙動を `docs/api.md` で明確化
- **リリース前 5観点レビュー黄インライン** — ConflictError 経路に info ログ、RateLimitStorage NoScriptError フォールバックに warn ログ、`/media`・`/feed/media` の disabled 応答にも構造化 info ログ、AnnictRecordLockStorage#ttl の memoize
- **5観点レビュー次リリース送り** — #4345（fix: AnnictRecordLockStorage release の compare-and-delete、5.24.0）、#4346（feat: alert しきい値）、#4347（refactor: Program 分割）、#4348（refactor: /about 動的合流フック化）、#4349（refactor: MediaCatalogDisabledRenderer 切り出し）。後者 4 件は未設定
- **Ruby 4.0.4 に更新**
- **bundle update**
- 本番デプロイ: 4 台（zugoga / lbock / shallu / sweep）

### 振り返り

**期間**: 5.22.1 リリース 2026-05-15 → 5.23.0 リリース 2026-05-23（8 日間）。本リリース 7 コミット（#4343 関連 + 5観点対応 + version bump）。

**消化**: 17 Issue（5.22 レビュー送り 8 件 + 番組表エディタ補助 1 件 + media_catalog #4343 + 諸 docs/refactor 7 件）。

**主軸**: #4343 が事実上の主軸として急遽組み込まれた。当初計画は「滞留した小粒の整理回」で主軸なしだったが、2026-05-19 障害（zugoga 等の DB プール枯渇で全サーバー投稿不可）と zugoga 本番ベースライン EXPLAIN で確証した 175 秒級病理を受け、当該機能の実験的扱い化に切替。本来の最適化 #4323（partial index `idx_mlkhy_statuses_local_catalog` 追加）は on-hold へ移動（ベースラインと candidate A は再開時の起点として残す）。

**5観点レビュー仕分け**: 真の赤 1 件（scheduler 経路）を hotfix インライン、黄 2 件と自明赤 7 件（docs 表記等）をまとめて対応、緑容易分 2 件もインライン。残り構造改善 5 件は #4345〜#4349 で次リリース送り。誤検知 2 件（AAAA 取得・`e.alert(**hash)` kwargs）は実証で覆して対応外とした。

**運用観察**:

- sidekiq-scheduler は `Sidekiq::Client.push` を直叩きするため、`Worker.perform_async` 側 gate は scheduler 経由では効かない（本リリースで判明）。今後 `disable?` を持つ worker は `perform` 先頭でも評価する必要がある
- 本番病理（重 SQL の DB プール枯渇）は本番規模特有で、ステージング dev04 等では再現不能（n_live_tup の桁が違う）。性能検証は本番で `EXPLAIN ANALYZE` を取る必要がある（#4323 で実証）

**反省**:

- #4343 で本番停止に駆け込んだが、scheduler 直叩き経路の穴を 5観点レビューが拾わなかったら本番で「local.yaml で false にしたつもりが止まっていない」が継続するところだった。並列レビューを規定どおり実施する価値を再確認

## 次期マイルストーン: 5.25.0

テーマ: APIController 段階的リファクタの締め + 5.23/5.24 レビュー送りの構造改善 + メディアカタログ段階的再有効化 + 5.24 繰越（番組表 iCalendar / Annict review API）+ 運用ログ整備（9 件 / 24 重み、budget 内）。

### APIController 段階的リファクタ

- #4285 refactor: PUT /scheduled_status/:id/tags を Service に移設（#4233 段階的リファクタの 3 件目、最大、size:L）

### 番組表エディタ拡張（5.24 繰越）

- #4366 feat: 番組表エディタに開始時刻 (start_time) 欄を追加（#4286 で見送った分の再起票、#4287 iCal の前提、size:S）
- #4287 feat: 番組表を iCalendar (.ics) 形式で出力（tomato-shrieker 連携、#4366 依存、size:M）

### capsicum 連携（5.24 繰越）

- #4342 feat: Annict review (作品全体感想) 投稿 API（capsicum #592 / v1.34 連携、size:M）。capsicum 側余裕あり

### メディアカタログ再有効化

- #4351 perf: media_catalog を zugoga で段階的に再有効化（#4323 ロードマップ A、partial index 適用 + 効果計測 + overlay 切替、size:M）

### 構造改善（5.23/5.24 レビュー送り）

- #4348 refactor: /about の features 動的合流を Config#about 側にフック化（5.23 レビュー送り、annict_linked / media_catalog / announcement_push 等の集約、size:S）
- #4364 5.24.0 リリース前 5観点レビュー 5.25 送り（黄 3 件 + 緑 3 件まとめ: episode_id alert payload, 暗黙 return, shortcode 単一文字コメント, EMPTY_PAYLOAD freeze, lock&. ノイズ, EVALSHA キャッシュ、size:S）
- #4360 test: ProgramTest auto_update 一律 false 設定の順序依存修正（PR #4356 Codex P2 follow-up、size:S）

### 運用観察起点

- #4362 ops: Sidekiq ログが no-reader pipe へ書き込まれ消失している（FreeBSD 3 台、#4264 副次発見、Mulukhiya::Logger 経由への切替検討、size:M）

## 次々期マイルストーン: 5.26.0

主軸候補: Spotify 連携（capsicum #465 ペア）+ メディアカタログ再有効化の横展開 + 構造改善（3 件 / 14 重み）。

- #4337 feat: Spotify user-level OAuth + currently-playing API（capsicum #465 連携、size:L）— 主軸候補
- #4352 perf: media_catalog を shallu / lbock に横展開（#4323 ロードマップ B、#4351 完了後着手、size:M）
- #4347 refactor: Program クラスを ProgramFetcher へ分割（rubocop Metrics/ClassLength の disable 解除、5.25 から送り、size:M）

## ロードマップ仮置き

Issue #4233 の APIController 段階的リファクタは「1〜2 マイルストーンに 1 件」の方針でサブ Issue 化済み。残ペースで進める想定:

- 5.22.0: #4283 GET /media（最小 24 行）— **完了**
- 5.24.0: #4284 POST /status/tags（中規模 26 行）— **完了**
- 5.25.0: #4285 PUT /scheduled_status/:id/tags（最大 64 行、ロールバック含む、size:L）— **アサイン済み**

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
- #4323 perf: media_attachments 関連 index 見直し（サブ #4351 zugoga 再有効化 / #4352 shallu/lbock 横展開 / #4353 本家 migration、1 マイルストーンに 1 件のペースで進行中）

### マイルストーン未設定

（現在なし。本リリース計画で未設定 Issue はすべて 5.24.0 / 5.26.0 に吸収。）

## リリース済み: 5.22.1（2026-05-15）

ホットフィックス。5.22.0 #4227 で追加した `POST /mulukhiya/api/annict/record` が、capsicum エピソードブラウザの送る数値 annictId をそのまま Annict GraphQL `createRecord(episodeId: ID!)` に渡しており、Annict が要求する Relay グローバルノード ID と不一致で `Invalid input` 失敗していた回帰を修正（dev04 ステージングで観測）。capsicum 側からの直接コミット（#4339）をリリース体裁に整えて出荷。

- **#4339 fix: Annict createRecord に数値 annictId を渡して Invalid input で失敗** — `AnnictService#create_record` が `episodeId: episode_id.to_s`（数値 annictId 文字列化）を渡していたのを、`searchEpisodes(annictIds:)`（新 `app/query/annict/resolve_episode.graphql`）で Relay ノード ID に解決してから mutation を呼ぶよう修正。capsicum 側の API 契約（`episode_id` は正の整数）は据え置き、解決はモロヘイヤ内部の責務に閉じる。#4227 実装時の取りこぼし。関連: pooza/capsicum#298
- **#4339 fix: Annict の auth/scope 失敗を AuthError(403) に正規化** — write スコープ不足トークンを Annict が HTTP 401/403 で返す経路・200+GraphQL `errors` で返す経路の双方を `Ginseng::AuthError`（403）に吸収し、capsicum へ「要（再）連携」を 403 一本で見せる。エピソード未解決時は `Ginseng::NotFoundError`（404）。`docs/api.md` の `POST /annict/record` エラー記述（403/404/422/502）を新セマンティクスに更新
- **リリース体裁整備** — capsicum 直コミットでは更新漏れだった `create_record` 系ユニットテストを新 2 段フロー（resolve_episode → createRecord）に追従させ、AuthError(403)・NotFoundError(404) 正規化のカバレッジを追加。rubocop 確認済み
- **bundle update** — ginseng-fediverse 1.8.24 / sidekiq 8.1.5 / jwt 3.2.0 / redis-client 0.29.0 / faraday 2.14.2 / dry-configurable 1.4.0 / rubocop 1.86.2
- 本番デプロイ: 4 台（zugoga / lbock / shallu / sweep）

## リリース済み: 5.22.0（2026-05-08）

番組表リニューアル フェーズ4（Annict 視聴記録・感想投稿 API）達成、5.21 リリース前 5観点並列レビュー黄送りの掃き出し、番組表エディタ品質強化、5.21.x ホットフィックス Codex 指摘対応、本リリース前 5観点並列レビュー赤・黄インライン対応。

- **#4227 feat: Annict 視聴記録・感想投稿 API の追加** — `POST /mulukhiya/api/annict/record` 新設、`createRecord` mutation 中継。capsicum エピソードブラウザ（pooza/capsicum#298 v1.26 ペア）からの感想投稿を可能にする。番組表リニューアル #4234 のフェーズ4 達成。OAuth scope を `[read, write]` に拡張、5.21.x までの既存ユーザーは再認可必須
- **#4322 perf: media_catalog 専用 Sidekiq Capsule に分離** — `default` キュー詰まり防止、concurrency 1。#4306 中期項目の 2 件目（5.21.2 の cursor 化に続く根治策）
- **#4271 feat: /sw/register SSRF allowlist に DNS 解決検証 / IDN 対策を追加** — `allowed_hosts` 空 = allow-all の運用は変わらず、追加でホスト名→IP 解決して private/loopback を弾く
- **#4279 feat: Program#fetch_remote にレスポンスサイズ・スキーマ検証** — 異常な巨大レスポンスや非 JSON で番組表が破壊される経路を塞ぐ
- **#4269 feat: logger.mask_fields に endpoint を追加** — Push 配信先 URL のログ漏れ対策
- **#4312 feat: ProgramEntryContract の source_url にスキーム検証** — `http(s)` 以外を弾く（XSS 緩和）
- **#4283 refactor: GET /media を MediaCatalogQueryService に移設** — #4233 段階的リファクタの 1 件目（24 行、最小）
- **#4325 fix: MediaCatalogUpdateWorker の cursor が Misskey の非ユニーク順序で添付欠落** — Misskey では cursor 無効化し OFFSET ページング維持。SQL の複合キー cursor 化は #4323 と合わせて将来検討
- **#4326 fix: Program#data の extra_tags 正規化を非 Hash entry でも安全にする**（5.21.1 PR #4321 への Codex P1）
- **#4327 fix: Program#fetch_remote 全 URL 失敗時に YAML 上書きを抑止**（本リリース前 5観点 Codex P1）
- **#4309 fix: APIController#token の Bearer 経路で復号後の nil/空チェック**
- **#4310 fix: AnnictService#enrich_episode の dup ガード**
- **#4311 fix: Handler#non_federated_payload? の真偽判定・key 判定正規化** — `localOnly` の string `"true"` や symbol/string キー両対応
- **#4315 fix: AnnictService#episodes 戻り値を nil/[] に統一**
- **#4317 fix: Controller#error の Sentry.capture_exception を rescue で防御**
- **#4277 fix: RateLimitStorage#increment の TTL 取り残しを Lua で防ぐ**
- **#4278 fix: 番組表エディタの重複キー登録を 409 Conflict** — ginseng-core v1.15.25 で ConflictError を追加、`Program#add_entry` を 422→409 に変更
- **#4308 chore: ProgramEntryContract の source_type/source_url を audit メタデータとして整理 / /program/urls 棚卸し**
- **リリース前 5観点レビュー赤 R1 R2 R3 + 昇格 Y9** — SidekiqDaemon.health の capsule 反映、refines.rb の Sentry capture rescue、docs/api.md の 401→403 訂正、AnnictService の非 Hash response 防御
- **黄 6 件インライン** — only_person 正規化を Contract 検証前に戻す / Sidekiq capsule の defensive default / Program#fetch_remote の per-URL rescue / RemoteHost.public? の rescue ログ / test の teardown leak 修正 / `/annict/record` の e.alert 昇格
- **5観点レビュー次リリース送り** — 黄 4 件・緑 4 件は #4328 #4329 #4330 #4331 #4332 #4333 #4334 #4335 で 5.23.0 / 5.24.0 / 未設定へ
- **bundle update**
- 本番デプロイ: 4 台（zugoga / lbock / shallu / sweep）

### 振り返り

**期間**: 5.21.0 リリース 2026-05-02 → 5.22.0 リリース 2026-05-08（6 日間）。期間中ホットフィックス 2 回（5.21.1 当日 / 5.21.2 4 日後）、本リリース 27 コミット。

**消化**: 17 Issue（S=11 / M=6 / L=0、重み 29）。予算 25 を +4 超過。

**主軸 2 件**:

- #4227 Annict 視聴記録・感想投稿 API → 番組表リニューアル #4234 全フェーズ完了。**capsicum v1.26（pooza/capsicum#298）に先行してモロヘイヤ側 API を着地できた** ため、capsicum 側はこちらの仕様を見ながら実装できた（毎晩のルーチンの最終ピース）
- #4322 media_catalog 専用 Sidekiq capsule 分離 → 5.21.2 cursor 化と合わせ、5.20.2 の `every: 30m` 暫定緩和を根治へ寄せた

**5観点レビュー仕分け**: 赤 4 件 / 黄 6 件をインライン、黄・緑 8 件は次リリース送り（#4328〜#4335）。Codex P1 1 件（#4327）もインライン。

**運用観察（chubo2 #36 系）**:

- delmulin_mulukhiya エイリアスは pooza 着地でリポジトリは `/home/mastodon` 配下。デプロイは delmulin_mastodon 経由が必要（SSH エイリアス間で着地ユーザーが食い違う運用）
- FreeBSD で sidekiq daemon が stdio を握って ssh セッションが抜けない → `</dev/null >/dev/null 2>&1` リダイレクトで回避。根治は #4264（5.23.0）

**反省**:

- 5.21.0 当日ホットフィックス #4320（番組表エディタ空フィールドで `extra_tags` 欠落）はステージング手動検証で踏めるはずの回帰だった。番組表エディタ系の手動シナリオを充実させる必要
- 5.22.0 重み 29 で予算 +4 超過。Codex / 5観点レビュー由来の小粒 Issue が積み上がる傾向は構造的で、5.23.0 の計画では主軸を据えず「整理回」として 24 重みに圧縮（#4286 #4287 等の番組表拡張は 5.24.0 へ繰越）、レビュー送り Issue を 1 リリースで吸収する方針に転換。番組表は #4336（最小実装、size:S）で日々運用の手数を先に削る

5.21.x 以前のリリースノートは [release-history.md](archive/release-history.md) を参照。

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

### 8. MEMORY.md の更新

- 上記で検出した差分（Issue 状態、リリース日の誤り、件数のズレ等）を反映

### 9. 同期結果の報告

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
