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

## 設計方針: SNS の状態ストアには SELECT しかしない

モロヘイヤは Mastodon / Misskey の Postgres を Sequel で直読みするが、**書き込まない**。SNS の Redis に対しても同様。スキーマの所有者は SNS 側であり、SNS 自身のマイグレーションが与り知らない書き込みを外から入れると、アップグレード時の整合が壊れる。

**唯一の例外: Misskey の `sw_subscription`**（[misskey_service.rb](../app/lib/mulukhiya/service/misskey_service.rb)）。

- 行の `create` / `update` / `delete`（`for_update` + トランザクション）
- あわせて Misskey の Redis キャッシュ `kvcache:userSwSubscriptions:<userId>` を `del`（行を書き換えたら飛ばさないと Misskey が古い値を読むため）

やむを得なかった理由は、Misskey の `/api/sw/register` が重複 subscription を溜め込むうえ、**それを修復する API が無い**こと。#4408 で導入し、#4420 で決定化・トランザクション化した。

### 二つの方針が衝突したら、本体改造を採る

「本体改造の最小化」（上節）と本節は衝突しうる。**本体を触らずに済ませる代償がモロヘイヤ側の非 SELECT なら、本体改造のほうを採る。** モロヘイヤは本体改造を減らすための仕組みだが、そのために SNS の状態ストアを外から書き換えるのでは目的と手段が逆転する。非 SELECT は「他に手が無いとき」の選択肢に留める。

**判断の前例（2026-08-01）**: ダイスキーのリモート `drive_file` 期限切れ（195 万行・うち 97.1% が誰もフォローしていない著者のもの）を、モロヘイヤの Sidekiq ワーカーでやるか Misskey 本体の fork でやるかを検討し、**fork を採った**。行削除と Object Storage の実体削除を伴い、非 SELECT を二重に踏むため。`CleanRemoteNotesProcessorService` の改造版（デフォルトタグ付き投稿を削除対象から除外）という前例が既に daisskey ブランチにあり、`CleanRemoteFilesProcessorService` を同じ形で拡張できる。詳細は pooza/chubo2#35。

## 姉妹サーバーとコミュニティ設計

モロヘイヤは複数の SNS サーバーで稼働しており、一部は「姉妹サーバー」の関係にある。

- **姉妹サーバー**: 同じデフォルトハッシュタグを持ち、同一リレーサーバー（`deas.b-shock.co.jp`）に接続しているサーバー同士
- **仕組み**: `DefaultTagHandler` が投稿にデフォルトハッシュタグを自動付与 → リレー経由で姉妹サーバーに伝播 → タグタイムラインが同期し、同じコミュニティとして機能
- **姉妹関係**: デルムリン丼 ↔ ダイスキー（同一管理者）、キュアスタ！ ↔ 外部管理のダイスキー（異なる管理者）

`DefaultTagHandler` は実装としてはシンプルだが、コミュニティ運用の基盤を支える重要なハンドラー。

### デフォルトハッシュタグは upstream で却下済み（再提案しない）

タグの**付与**はモロヘイヤ（`DefaultTagHandler`）が担うが、**読み取り経路**——ローカルタイムライン・streaming チャンネル・検索がそのタグでコミュニティを構成する部分——はプロキシの射程外で、`pooza/misskey` の `daisskey` ブランチ（および `pooza/mastodon`、[pooza/mastodon#925](https://github.com/pooza/mastodon/issues/925)）の fork が担っている。

**この機能は misskey-dev へ PR 済みで、却下されている。** 理由は 2 点:

1. **既存機能のふるまいを変えてはならず、完全な追加機能でなければならない** — 現行 fork は `local-timeline` の `note.userHost IS NULL` をタグ条件に置き換え、`SearchService` の `host: '.'` を同様に分岐させ、`NoteCreateService` の fanout でリモート投稿を `localTimeline` へ流している。いずれも既存の意味を変えている
2. **設定はファイルではなくコントロールパネルから行えなければならない** — 現行 fork は `.config/default.yml` の `defaultTag` を読む

**config ゲートで未設定時にバニラ挙動へ倒れる書き方になっているが、それはマージ衛生の話であって upstream の受け入れ基準とは別物。** 満たしていない。再提案するなら上記 2 点を満たす設計（既存エンドポイントに触れない新規タイムラインを、`meta` テーブル経由の設定で追加する等）から作り直しになる。**現状の形のまま出し直しても通らない。**

なお `CleanRemoteNotesProcessorService` の fork のうち、statement_timeout 耐性（upstream #17057 の回避策）にあたる部分は挙動も設定も変えないため、この 2 基準に抵触せず upstream 化の余地がある。fork の中で唯一 upstream の既存行を大きく書き換えている箇所（+78/−25）でもあり、マージ痛を減らす効果も大きい。

## カスタムフィードの残置（cure-api との切り分け）

cure-api 独立化（#4144）でカスタム API（`/api/custom`）は完全削除されたが、**カスタムフィード**（`/feed/custom`、`custom_feed.rb` + `command_line.rb`）はモロヘイヤ側に残置されている。利用者は2名。`Open3.capture3` を使うが Bundler 環境切替が無いため EPIPE 系の問題は起きていない。

cure-api 側を触るときに「カスタムフィードも一緒に整理」と思い込まないこと。両者は名前が似ているが完全に別系統。

## media_catalog の既定値（Mastodon は有効・Misskey は無効）

`media_catalog` 機能（`/mulukhiya/api/media`、`/feed/media`、`MediaCatalogUpdateWorker`、Mastodon WebUI のメディアフィード）の既定値は、
**Mastodon が `true`（5.41.0・#4789）、Misskey が `false`（#4375 まで）**。5.23.0〜5.40.x は両方 `false`（実験的扱い・#4343）だった。

**経緯**: 2026-05-19 に、底値 175 秒級の重い SQL が DB の接続プールを専有して全サーバーが投稿不可になり、5.23.0 で既定を無効にした。
決着は #4393 の **B 案（ローカルアカウント駆動の LATERAL merge・PR #4613）**で、🔴 **追加の index は要らない**。
⚠ **partial index（候補 A・`idx_mlkhy_statuses_local_catalog`）は不採用**（170 秒 → 約 10 秒止まり）。zugoga にだけ残っているが、
無い shallu / gomander でも 1 秒未満で成立している（2026-10-12 に本番 3 台で確認）。揃えるかは pooza のインフラだけの話で、受け皿は pooza/chubo2#272。

**現在の状態**:

- `/features` API で `media_catalog: bool` を露出（capsicum / モロヘイヤ WebUI の事前判定用）
- 無効のときの API は 503 + `{ "available": false, "items": [] }`（404 と区別し「機能未提供」ではなく「現在 OFF」を伝える）
- 重さは**ローカルアカウント数にほぼ比例**（温まった 1 クエリで 47 アカウントが数十 ms、384 が 0.5〜0.6 秒）。⚠ 384 超は未検証・冷えた初回は 384 で 12 秒
- 戻し方は overlay に `/mastodon/data/media_catalog: false`。見るものは `/mulukhiya/api/health` の `postgres.pool.waiting`
- ⚠ **他の運用者への責任は注意書きまで**（2026-10-01 の合意）。アカウント数を見て警告する等の自動の安全策は入れない。index の作成も案内しない
- ⚠ Misskey 側（`/misskey/data/media_catalog`）は #4375 が済むまで `false` のまま。きゅあすきー等の他者運用がある

詳細は [media_catalog.md](media_catalog.md)。

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

## 開発中: 5.43.0

[マイルストーン 5.43.0](https://github.com/pooza/mulukhiya-toot-proxy/milestone/643)。`config/application.yaml` は 5.43.0 へバンプ済み。

- open 4 件（`gh issue list --milestone 5.43.0`）。2026-10-18 に #4845 を足し、#4722 / #4375 / #4323 をクローズ（ユーザー判断）。次の [5.44.0](https://github.com/pooza/mulukhiya-toot-proxy/milestone/644) を作った（#4847 Pleroma の webhook・#4848 ginseng-core）。5.42.0 から #4375 / #4323（Misskey のメディアカタログ）を引き継いだ
- 📌 **Misskey のメディアカタログの残り**: ✅ **ダイスキー（vulcan）で有効にした（2026-10-16 06:29・ユーザー承認・#4375 にコメント）**。
  ワーカー 10.5 秒・`/api/media` 200（0.31 秒）・`/feed/media` 200（1.20 秒）・health 全 OK。バックアップは vulcan の `config/local.yaml.bak-4375`。
  ダイスキーの実況は不定期でごく稀なので、日曜の見直しは要らない（2026-10-16 ユーザー指摘）。
  → 24 時間観測（〜10-17 06:30）→ ✅ #4375 / #4323 をクローズ（10-18）→ **次は Misskey の既定値を `true` に戻す（#4838）**
  → **PR #4852（#4838）**: `/misskey/data/media_catalog` の既定を `true` に。lint・test とも 0 failures。**2026-10-23 時点で CI・Codex の結果待ち**。
  ⚠ リリースノートに戻し方と見るもの（`postgres.pool.waiting`）を書く・Wiki（メディアカタログ）はリリース時に反映
- ✅ **PR #4841**（PR #4840 の Codex P2）: pgbouncer の WARN の割合が範囲の外（0 以下・1 超）なら `pgbouncer_warn_config`。**2026-10-16 マージ（`3187aaa2`）**
- **PR #4849（#4845）**: `/mulukhiya/api/*` の書き込みの要求（GET / HEAD / OPTIONS 以外）では、`write` / `write:*` を持たないトークンを外す（403）。
  読み取りの POST 3 本（is_cat・nowplaying/resolve・resolve-url）は除外、Misskey の本人のトークンは通す。harness 両系 0 failures、実トークンで通る側・弾く側とも確認済み。
  **2026-10-18 時点で CI・Codex の結果待ち・マージ待ち**
- **PR #4855（#4853）**: `.ruby-version` を 4.0.9 へ。mulukhiya が動く 9 台（本番 4 台・dev24〜27・dev29）すべてに 4.0.9（YJIT 有効）が入ったのを 2026-10-24 に確認してから出した。
  ローカルの 4.0.9 で lint・test とも 0 failures。⚠ **4.0.9 の同梱 bundler は 4.0.20 だけ＝デプロイ時は `bundle install` の前に `gem install bundler -v 4.0.18`**（4.0.7 のときと同じ罠）。
  lint の途中で出た crass 1.0.7 の advisory（GHSA-pq4g-8rxf-4g29）は 4.0.9 と無関係で、develop へ直接（`1c5a2f48`）
- ⚠ **本番のどの辞書ソースに `interval`（5.41.0・#4690）を入れるかは未決**（ユーザー「後で決める」・2026-10-12）。こちらから急かさない
- ✅ `bundle update` は 2026-10-16 に develop へ直接（`a141799d`・json 3.1.0 / webmock 3.34.0 / domain_name / net-imap 0.6.8・rubocop は ginseng-style の固定で据え置き）。lint・test とも 0 failures
- ✅ **PR #4842（#4677）**: **2026-10-18 マージ（`880f5756`）**。is_cat は取れなかった acct も 600 秒覚え、1 件の取得全体を 4 秒・再送なしで諦める。本体は `IsCatService` へ。
  ダイスキーの 504 は 09-08 が最後（相手が通知一覧から外れたと見られる）だが、美食丼は今も 1 日 1〜3 件の 499。
  Codex の P1（締切が要求ごとに数え直されて 2 倍に延びる）を `5a5af9d5` で直し、`@codex review` 済み
- ✅ **PR #4843（#4722）**: **2026-10-16 マージ（`1cd535ac`）**。メディア変換の締切切れはハンドラごとに 300 秒に 1 回だけ alert（残りは log）・動画は段を残す。
  `AlertThrottle` へ寄せてコントローラと共有。#4722 の 2・3 は 5.39.0 で済んでいた
- ✅ #4685（Idempotency-Key の再送で孤児メディア）は**上流に任せてクローズ**（2026-10-16 ユーザー判断）。Mastodon の Vacuum が未添付のメディアを 1 日で消す。`docs/api.md` に一文
- ✅ #4233 はクローズ（表の 5 件はすべて 5.19.0〜5.25.0 で完了していた・2026-10-16 ユーザー判断）。いま長いのは `POST /annict/review` / `record` で対象外
- **#4566（Akkoma）= この版の「前へ進む」枠**。✅ 2026-10-16 に dev29 へモロヘイヤを設置（pooza/chubo2 `3dd85d9`）し、
  **PR #4844**（controller `pleroma`・最初の段階）で health 200・アカウント解決・pre_toot パイプラインまで dev29 で通った。
  🔴 Akkoma の API のアカウント ID は uuid ではなく FlakeId の base62 → 照合を `api_id` に。残りはゲート（harness で dev29 に対して緑）
  ✅ **PR #4844 は 2026-10-18 マージ（`28d80436`）**。Codex の指摘はすべて返信・リアクション済み。
  ✅ **ゲート（手順 4）: PR #4856**（2026-10-24）。dev29 に向けて 1824 tests・0 failures / 0 errors（最初は 5 / 32）。Mastodon・Misskey の harness も 0 failures。
  dev29 に info ユーザーを作った（pooza/chubo2 `5337c6e`）。⚠ **リリースゲートの「省略不可」に 3 系統目を入れるかはユーザー判断待ち**。
  `~/.claude/settings.json` の `autoMode.allow` に dev29 のステージング操作全般を足した（ユーザー承認）
  先送りの受け皿: **#4845**（スコープを見ずにトークンからアカウントを解決している・全系統・5.43.0）/
  **#4846**（#4566 の非ゴール＝ハンドラ・listener・SQL 7 本・on-hold）。⚠ Pleroma では `post_reaction` を流していない（#4846 に記載）

## リリース済み: 5.42.0（2026-10-14）

**本番デプロイ: 4 台完了**（2026-10-14 07:53〜07:56、shallu → zugoga → gomander → vulcan の順・水曜の朝。
全台 version 5.42.0 / health 200 / Ruby 4.0.7（据え置き）/ `postgres.pool.waiting` 0 / FreeBSD 3 台は monit 復帰 / vulcan は 3 ユニットとも `NRestarts=0`）。
`main` の `41c0d4e0` / [v5.42.0](https://github.com/pooza/mulukhiya-toot-proxy/releases/tag/v5.42.0)（PR #4840）。
[マイルストーン 5.42.0](https://github.com/pooza/mulukhiya-toot-proxy/milestone/642)（7 件・クローズ済み）。

### 本番デプロイで見たこと

- **4 台とも 1 回で通った**（1 台あたり約 45 秒）。`config:lint` は 4 台とも `config: OK`・起動後のエラー行 0。rc.d / systemd unit・Ruby・gem の変更なし
- 事前確認: 4 台とも `main` の `95855040`・作業ツリーに変更なし（vulcan の `vendor/` は未追跡で従来どおり）
- **pgbouncer の実物で WARN の判定を通した**（ステージングは pgbouncer を挟んでいないので、ここが初めて）: shallu 15 / 500・zugoga 9 / 500・gomander 15 / 500 で `postgres` は `OK`・`reason` なし
- **再起動の直後に `rake mulukhiya:media_catalog:update` を打った**（FreeBSD 3 台）。キャッシュの鍵は `media_catalog_v3`（shallu 4 本・zugoga 6 本・gomander 6 本）。
  外から `/mulukhiya/api/media?page=2` は 3 台とも 200（0.07〜0.10 秒）・`/feed/media` は 0.86〜1.10 秒
- vulcan は `/mulukhiya/api/media` が 503（メディアカタログは無効のまま＝ flip は別途）
- ⚠ **リリースノートの「アップグレードの前に」は 3 点**: pgbouncer の WARN と通知／キャッシュの鍵（更新タスク）／Misskey の `next_cursor` の形
- ⚠ **Wiki**: 公開API（health の WARN・`/media` の cursor）と PostgreSQL の設定項目（`clients_ratio`）を更新

### 開発時の記録


- ✅ **2026-10-14 に PR を 3 本マージした（ユーザー承認・CI 両系 SUCCESS・Codex の P2 は対処済み）**: #4835（`52a4e4fd`）/ #4836（`ebc31225`）/ #4837（`d5a07b24`）。**#4695 はクローズ**
  - **ステージング 4 台（dev24〜27）を develop（`d5a07b24`）へ揃えた**（`config: OK`・3 サービスの restart rc=0・health 200）
  - **develop（`d5a07b24`）で harness を実走（系ごとに別シェル）**:
    Mastodon 1798 tests / 3829 assertions / **0 failures / 0 errors** / 158 omissions（`TestHarness: controller=mastodon url=http://localhost:3000`）、
    Misskey 1797 tests / 3877 assertions / **0 failures / 0 errors** / 145 omissions（`TestHarness: controller=misskey url=http://localhost:3001`）。
    ⚠ リリースゲートとして読むなら、この後に develop へコードが入っていないこと
  - **Misskey のメディアカタログの段取り（2026-10-14 ユーザー判断）**: 5.42.0 を出荷 → **ダイスキー（vulcan）で有効にする**（#4375）→ 観測 →
    Misskey の既定値を `true` に戻す（**#4838・5.43.0**）。既定値は一旦据え置き。
    ⚠ vulcan の flip は 5.42.0 の出荷後（5.41.0 のままだと、cursor で辿ったときに添付が抜ける）
- ✅ **リリース前レビュー（5 観点・`v5.41.0..develop`・2026-10-14）: 赤 0 / 黄 6 / 緑 9**（重複は 1 件に数えた）。行き先はユーザーが決めた
  - **本リリースで直した（PR #4839・`b6b1003b`・Codex は指摘なし）**:
    割合の設定が壊れていても health を NG にしない（`pgbouncer_warn_config`。NG だと monit が再起動し続ける）／
    上限に達した後も WARN のまま（`pgbouncer_clients_exhausted`。観測が `no more connections allowed` で断られると OK に戻り、いちばん悪い瞬間に「WARN → OK」が飛ぶ形だった）／
    Annict のキーワードが 1 語でも落とさない／通知の WARN に理由を添える／Misskey の `catalog_cursor` の整理／コメント・`docs/api.md`・スキーマの並び
  - **記録のみ（ユーザー判断・Issue にしない）**:
    - WARN の判定が境目で揺れると、通知が 5 分ごとに届く。本番 3 台の平常は 500 のうち 10〜16（10-14 の公開 health）＝揺れるのは詰まりかけている間だけ
    - キーワードの変更と Annict の不調が重なると、凌ぐ用のキャッシュが空になる（変えた直後だけ）
    - `cursor_pagination?` が両系 `true` になり、分岐の意味が無い（Akkoma で 3 系目が要るかもしれないので残した）
    - 設定名 `warn/clients_ratio` は既存の `threshold` 系と不揃い（意味は通るのでそのまま）
  - **デプロイ手順に織り込む**: キャッシュの鍵が `media_catalog_v3` に変わるので、再起動の直後に `rake mulukhiya:media_catalog:update` を打つ
    （打たないと、最初の巡回まで最長 30 分、2・3 ページ目の要求ごとに SQL が走る）
- ✅ **リリースゲート（`b6b1003b`・2026-10-14・系ごとに別シェル）**:
  Mastodon 1802 tests / 3840 assertions / **0 failures / 0 errors** / 158 omissions（`TestHarness: controller=mastodon url=http://localhost:3000`）、
  Misskey 1801 tests / 3888 assertions / **0 failures / 0 errors** / 145 omissions（`TestHarness: controller=misskey url=http://localhost:3001`）。
  ステージング 4 台も `b6b1003b`（`config: OK`・3 サービスの restart rc=0・health 200・`/api/about` は 5.42.0・`/app/media` 200）。
  ⚠ この後に develop へコードが入ったら回し直す
  - **dev27 でメディアカタログを有効にした（ダイスキーの flip のリハーサル）**: `config/local.yaml` に `misskey.data.media_catalog: true`（バックアップは `config/local.yaml.bak-4375`）。
    再起動 → `rake mulukhiya:media_catalog:update` → `media_catalog_v3:page:1:*` が 2 本。`/api/media` 200（13 件）・`?cursor=asas0399u2.1` は同じノートの 2 枚目から・
    位置の無い cursor は次のノートから・不正な形 4 種は 422・`/feed/media` 200。**dev27 は有効のまま慣らす**
  - **リリース前の `bundle update` は入れていない**: Dependabot 0 件・bundler-audit 指摘なし。動くのは json 3.1.0 / net-imap / rubocop など（セキュリティ上の理由が無いので次の周回で）
- 3 本の中身:
  - **PR #4835**: Annict のエピソード辞書は、キーワード（`/service/annict/works`）を入れ替えた後の空でキャッシュを置き換える（PR #4834 にマージ後に届いた Codex P2）。
    ⚠ 見分けるのは設定のキーワードで、Annict が返した作品の ID ではない（不調のときは作品の検索も欠ける）
  - **PR #4836（#4695 の残り 1 件）**: pgbouncer の `clients_used / clients_max` が `/postgres/pgbouncer/warn/clients_ratio`（既定 0.8）以上で
    `postgres` を `WARN`（`reason: pgbouncer_clients_high`）。HTTP は 200 のまま・管理者へ「ヘルスステータス変更」が飛ぶ。
    ⚠ **ステージング 4 台は pgbouncer を挟んでいない**ので実物では未確認（出荷後に本番 3 台の health で見る）
  - **PR #4837（#4375 の手順 3）**: Misskey の cursor を `<note_id>.<fileIds の中の位置>` の 2 つ組に。`cursor_pagination?` は両系 `true`。キャッシュの鍵は `media_catalog_v3`。
    dev27 で添付 3 枚のノート 2 本を作って全 13 行と突き合わせた（修正前は cursor で 9〜11 行）。
    ⚠ **位置は `generate_subscripts` で取る**（`LATERAL unnest ... WITH ORDINALITY` は副問い合わせが平坦化され、note の主キーを逆順に舐める計画に変わる。
    vulcan で OFFSET 2500 が 583 ms・note 33 万行のうち 31 万行を捨てた）
  - **#4375 の残りは判断だけ**: ダイスキー（vulcan）は追加の index なしで 1 ページ目 69 ms / OFFSET 2500 で 153 ms（#4375 にコメント）。
    有効にするか（本番の設定変更）・Misskey の既定値を戻すかはユーザーが決める。#4323（メタ）は #4375 が閉じれば閉じられる
- ⚠ **本番のどの辞書ソースに `interval`（5.41.0・#4690）を入れるかは未決**（ユーザー「後で決める」・2026-10-12）。こちらから急かさない
- capsicum のメディアカタログのぼかしは pooza/capsicum#1284（依頼済み）
- zugoga にだけある index を揃えるかは pooza/chubo2#272（先送り・pooza のインフラだけの話）

## リリース済み: 5.41.0（2026-10-12）

**本番デプロイ: 4 台完了**（2026-10-12 17:17〜17:22、shallu → zugoga → gomander → vulcan の順。
全台 version 5.41.0 / health 200 / Ruby 4.0.7（据え置き）/ `postgres.pool.waiting` 0 / FreeBSD 3 台は monit 復帰 / vulcan は 3 ユニットとも `NRestarts=0`）。
`main` の `95855040` / [v5.41.0](https://github.com/pooza/mulukhiya-toot-proxy/releases/tag/v5.41.0)（PR #4834）。
[マイルストーン 5.41.0](https://github.com/pooza/mulukhiya-toot-proxy/milestone/641)。

### 本番デプロイで見たこと

- **4 台とも 1 回で通った**（1 台あたり約 1 分）。`config:lint` は 4 台とも `config: OK`・起動後のエラー行 0。rc.d / systemd unit の変更なし
- 事前確認: 4 台とも作業ツリーに変更なし・設定の `disabled:` は 0 行
- **`/mulukhiya/api/media` の 1 ページ目**（Mastodon 3 台）: shallu 100 件中 閲覧注意 4 / zugoga 50 件中 10 / gomander 100 件中 3。CW つきで本文が返るものは 0 件。51 ページ目は 422
- ⚠ 本番 3 台は以前から明示の `media_catalog: true` なので、既定の変更そのものは効いていない。効くのは他の運用者の Mastodon
- ⚠ FreeBSD 3 台の `bundle install` に `Source locally installed gems is ignoring ... missing extensions`（zlib / json / etc / date）が出る。通知だけでインストールは通る
- ⚠ **本番の SSH は `pooza@<host>` で着地する**（`~/.ssh/config` の既定は mastodon）。手順は chubo2 `docs/infra-mastodon.md`「デプロイ手順」
- リリースの手順 3 で `bundle update`: ginseng-youtube 3.0.1 → 3.0.2（⚠ 9 月 26 日のリリースにピンが追従していなかった＝**毎同期のピンの突き合わせは全 gem を見る**）/ icalendar 2.13.0。
  harness（`612b2f8c`）は両系 0 failures / 0 errors
- Wiki: メディアカタログ・タグ付けに関する設定項目（`interval`・キャッシュが切れたときの振る舞い）・設定ファイル（`disabled`）・EmojiSpacingHandler を更新

### 手順 12（小粒の掃除）の持ち越し

- なし（リリース前レビューの「その場で直せる規模」は PR #4833 で本リリースに入れた）。記録のみにした 5 件は下の「リリース前レビュー（5 観点）の結果（2026-10-12）」

### 開発時の記録

### マージ済み（develop）

- ✅ **PR #4819（5.40.0 の手順 12・掃除 8 件）— 2026-10-12（`6010f8e6`）**。⚠ **この PR 単独では harness とステージングを回していない**
  （下の #4823 / #4826 の実走が、この変更を含む HEAD を通っている）
- ✅ **PR #4822（#4821）— 2026-10-12（`1bff88cb`）・ユーザー承認**: 自サーバーの名前が引けないだけなら、health の `streaming` を NG にしない
  （`{status: 'OK', unresolved: true, error: ...}`）。外すのは名前解決の失敗だけ。#4821 はクローズ
  - **きっかけ**: 2026-10-11 23:57〜10-12 01:16 JST に `.ml` の名前解決が落ち、gomander で monit がモロヘイヤを 4 回再起動した（10-12 の同期の記録）
  - ⚠⚠ **dev25（`st2.precure.ml`）にもう 1 つの壊れ方が残っていた**: 再起動された listener が再試行 20 回（約 16 分）で終了し、
    **以後 7 時間 503 のまま**。monit の `exec` は状態が変わったときに 1 回だけなので、503 が続く間は撃ち直さない。手で再起動して復帰
  - 修正後は、名前が引けない間は 200 → listener が終了したら NG → monit が 1 回再起動、の周回になる（止まったまま残らない）
  - dev25（FreeBSD）の実物の HTTP で、解決できない名前は OK（`unresolved`）・接続拒否は NG を確認。⚠ 自ドメインだけ引けない状態そのものは作っていない
  - ⚠ **テストに `omit` を足すと、CI の omission の上限（mastodon 327 / misskey 316）を超えて落ちる。**コントローラの判定を固定して両系で実行する形にした
- ✅ **PR #4823（#4820）— 2026-10-12（`f069b95a`）・ユーザー承認**: ginseng-core v2.4.2 / ginseng-fediverse v6.0.0。#4820 はクローズ
  - 署名付き URL のクエリ（`signature` / `sig` / `x-amz-signature` / `hm` / `jwt` など）がログでマスクされる。
    `/logger/mask_query_params` は gem の既定に**足す**形なので設定は変えなくてよい（`Mulukhiya::Logger` で実測）
  - fediverse 6.0.0 の破壊的変更は届かない（`upload_remote_resource` を上書きしていて、取得は `MediaFile.download`）
  - `TooLargeError` を受け直す 3 か所のコメントを直した（上流の文言が URL を持つのは core 2.4.0 まで）
  - **harness（`8a721b24`）**: Mastodon 1706 tests / 0 failures / 0 errors / 159 omissions（`controller=mastodon`）、
    Misskey 1709 tests / 0 failures / 0 errors / 145 omissions（`controller=misskey`）。
    ⚠ **2 回目。**1 回目は Mastodon 2 failures / Misskey 1 failure（どれも実物の辞書 `mstdn.delmulin.com` → GAS を引くテスト・
    Mastodon のログに `No route to host` 3 行）。新しい gem で同じ辞書を 6 回引いて全部 200 だったので、外部要因として同じ HEAD で回し直した
  - ステージング dev24 / dev26 / dev27 で health 200・エラー行 0
- ✅ **PR #4824 — 2026-10-12（`6116104f`）・ユーザー承認**: ginseng-style v1.1.14（rubocop 1.91.0 / rubocop-minitest 0.41.0）。新しい指摘は 0 件

- ✅ **PR #4825（#4700）— 2026-10-12（`34923a92`）・ユーザー承認**: 設定スキーマの穴 3 件。ハンドラのスキーマ 41 本の `disabled` を `disable` に揃え、
  `disabled` と書いたら検査で落とす（`default.yaml`・`not: {}`）／`dics[].fields`／`program.auto_update`。#4700 はクローズ
  - Codex P2 × 1 に対処: `scheduled_status_save` はスキーマのファイルが無く、検査が素通りだった → ファイルを足し、全ハンドラがスキーマを持つことをテストで見る
  - 本番 4 台・ステージング 4 台の設定に `disabled:` は 0 行
  - ⚠ **リリースノートに書く**: `disabled:` を書いていると警告が出る・`/config/validation/strict: true` なら起動が止まる
- ✅ **PR #4827（#4817）— 2026-10-12（`847f0186`）・ユーザー承認**: デーモンの身元確認を gem の `process_pattern` へ。自前の `alive_state_of` ほかを削除
  （`identity_tag` だけ残る）。#4817 はクローズ。dev27（systemd）・dev26（rc.d）で、pid ファイルへ無関係な `sleep` の番号を書いた状態から
  3 デーモンとも起動し、`sleep` は生きたまま。⚠ ログが変わる: info の `pid file points to another process` → warn の `process identity mismatch`
- ✅ **PR #4826 — 2026-10-12（`8d8e7e02`）・ユーザー承認**: `bundle update`（net-http 0.10.0 / redis-client 0.31.0 / mime-types-data / webmock 3.29.0）。
  harness（`d6bc419e`）は両系 0 failures / 0 errors
- ✅ **6 本をマージした後の develop（`8d8e7e02`）で harness を実走（2026-10-12 07:35〜07:50 JST・系ごとに別シェル）**:
  Mastodon 1719 tests / 3652 assertions / **0 failures / 0 errors** / 159 omissions（`TestHarness: controller=mastodon url=http://localhost:3000`）、
  Misskey 1722 tests / 3705 assertions / **0 failures / 0 errors** / 145 omissions（`TestHarness: controller=misskey url=http://localhost:3001`）。
  ＝ ginseng-core 2.4.2 ＋ net-http 0.10.0 の組み合わせも通っている。⚠ このあと develop にコードが入ったら、リリースゲートは回し直す
- ✅ **ステージング 4 台（dev24〜27）を develop（`8d8e7e02`）へ揃えた**（`config: OK`・3 サービスの restart rc=0・health 200）

### リリース前レビュー（5 観点）の結果（2026-10-12）

対象は `v5.40.0..develop`（`ca56bd56` 時点）。**赤 1 / 黄 10 / 緑 7**（観点をまたぐ重複は 1 件に数えた）。行き先はユーザーが指摘ごとに決めた。

**本リリースで直した（PR #4833・`a6c540a1`）**

- 🔴 **赤 1: 辞書ソースが 0 本のサーバーで、タグ検索 API が 500**（#4628 の回帰）。本体キャッシュが無いと `TaggingDictionary#cache` が nil になり、
  `TagSearchService#search` の `cache.each` が落ちる。ソースが無いと更新ワーカーも動かない（`disable?`）ので、本体を書く者がいない
  ＝**デプロイから最大 1 時間後（5.40.0 が書いた空の payload の TTL 切れ）に出始める**。`fill_cold_cache` が空の Hash を置く。
  ⚠ **「呼び出し元が何も書かなくなる」変更は、書き手が居ない設定（ソース 0 本）を必ず見る**
- **media_catalog の見直し（既定が有効になる #4789 に伴う・Mastodon / Misskey とも）** — 行き先はユーザー判断:
  - **未収載（Misskey はホーム公開）を載せない**（公開だけ）。本番 3 台の直近 1 年では一覧の 2〜5%
  - **閲覧注意・CW は印を付けて載せる**: `items[].sensitive`（CW つきも true）/ `status.spoiler_text` / CW つきは `status.body: null`。
    RSS（`/feed/media`）はぼかせないので載せない（`safe: true`）。WebUI は押すまで表示しない。**capsicum への依頼は pooza/capsicum#1284**
  - **ページの上限** `/webui/media/catalog/max_page`（既定 50・超えると 422・上限のページは `has_next: false`・cursor で辿る限り掛からない）
  - 知らないパラメータを `catalog` へ渡さない（未認証の `skip_cache` / `limit` / `rule`）・`cursor` の形と範囲を検証
  - キャッシュの鍵を `media_catalog_v2` に（古い形の応答が最大 24 時間返るのを避ける）・鍵に `max_page` を含める
- その場で直した黄・緑: `'cold'` のジョブの空振りにログ 1 行／依頼を出せなかった回は本体を読み直さない（`cache discarded` が 2 行ずつ出る）／
  last-good の鍵から `interval` を外し、印の鍵にだけ入れる／使い回した回も last-good の寿命を置き直す／コメントと実装の食い違い 3 件／`docs/api.md` の例

**記録のみ（ユーザー判断・Issue にしない）** — どれも障害時だけの話

- `/feed/media` はキャッシュを通らず、要求ごとに SQL が走る（大きいサーバーで同時要求が重なったときだけ）。リリースノートの注意書きに含める
- 名前解決の失敗（`unresolved`）はどの通知にも乗らない。`StartupNotificationWorker#extract_status` は `:status` しか見ない
- 名前解決の障害が長引くと、約 16〜20 分周期の再起動ループが残る（listener の再接続が `/websocket/retry/max_count: 20` で `exit 1` → health NG → monit）
- 辞書が cold のまま続いても Sentry に出ない（`tagging dictionary cold` は `logger.error` だけ。Sidekiq が生きたまま詰まったとき）
- Annict が「200 で空」を返し続けても、古さのアラート（6 時間）が鳴らない（`keep_cache` は warn だけ）

**リリース時にやること（レビュー由来）**

- リリースノート: 設定の `disabled:` はエラー文に直し方が出ない（`matched the disallowed schema`）ので、「`disable` に書き直す・strict なら起動しない」を明記。Wiki の `EmojiSpacingHandler.md` の「共通の `disabled`」も直す
- リリースノート: メディアカタログは公開だけ・印が付く・ページの上限・未収載は載らなくなる
- Wiki「メディアカタログ」は旧既定（5.23.0 から無効）のまま

**Codex（PR #4833）**: P2 を 6 件。⚠⚠ **`@codex review` を 6 回投げた＝回しすぎ。**ginseng-style の codex-review スキルでは **P2 は直して返信するだけ・再レビューは P1 だけ**。
直すたびに新しいコードへ P2 が 1 件ずつ付き、後ろへ行くほど条件が狭くなった（4・5 回目は「`max_page` を変えた直後の 24 時間」）。
⚠ 途中で CI を 1 回落とした（cursor のテストが Mastodon 前提・Misskey の ID は英数字）。**テストを足したら CI 相当の設定で両系を回してから push する**

**ステージングでの確認**: dev25 / dev27 に info アカウントから検証用の投稿を 4 件ずつ（公開・未収載・閲覧注意・CW）。未収載は載らず、印が付き、CW の本文は返らず、
RSS から外れる。WebUI のぼかしは `https://st2.precure.ml/mulukhiya/app/media` をブラウザで押して確認。
⚠ dev25 の WebUI はサムネイルが 5 件とも表示されなかった（今回の変更の前からかは未確認）

### 2026-10-12 にマージしたもの（4 回目）

- **PR #4831（#4789・`ca56bd56`）**: Mastodon の `media_catalog` の既定を `true` に戻す（Misskey は `false` のまま）。変更は既定値 1 行＋文書＋既定値のテスト。
  CI 両系 SUCCESS・Codex は P2 を 1 件（文書に partial index の適用手順が残っていた）直して指摘なし（HEAD `be65376c`）。
  harness（`1d8fec04`）両系 0 failures / 0 errors（Mastodon 1763 tests・omission 159 → 158 / Misskey 1762 tests）
  - **#4353 は 2026-10-12 にクローズ**（ユーザー判断）。本番 3 台を読み取りだけで確認: index があるのは zugoga だけ（`idx_scan` 累計 1541 万回＝使われている）、
    無い shallu（48 アカウント）/ gomander（384）も `/feed/media` は 1 秒未満。**「あれば役に立つ・なくても成立する・作成の案内は不要」**。
    揃えるかは pooza のインフラだけの話で、**決定は先送り＝受け皿は pooza/chubo2#272**
  - **dev25 で確認**: 明示の `media_catalog: false` があると 503 のまま（＝戻し方が効く）→ 行を外すと `features.media_catalog: true`・`/feed/media` 200（0.05〜0.9 秒）・`pool.waiting` 0。
    ⚠ dev25 は明示の行を外したまま（既定で慣らす。バックアップは `config/local.yaml.bak-4789`）
  - ⚠ dev24 も `config/local.yaml` に明示の `false` がある（＝ 5.41.0 でも無効のまま）。dev26 は明示の `true`
  - 入れなかったもの: 深いページの上限（Issue の「できれば」）・Wiki（リリース時）
  - ⚠ shallu の `/feed/media` は 1 回だけ 6.4 秒だった（続く 3 回は 0.25〜0.31 秒）。原因は未特定＝キャッシュが空のときの型と同じ見え方

### 2026-10-12 にマージしたもの（3 回目）

- **PR #4830（#4628 の残り 2 件・振る舞いは 2026-10-12 にユーザーと決めた・`55fe80b5`）**: 本体キャッシュが無いとき、**投稿の経路（`TaggingDictionary.new`）は上流へ取りにいかない**。
  更新ワーカーへ依頼を 10 分に 1 回だけ出し（印 `tagging_dictionary/refresh_request`・`'cold' => true`）、ソースごとの last-good からメモリの中で組み立てる。
  last-good も無ければ空の辞書で投稿を通す。依頼は、走る時点で本体が埋まっていれば何もしない（Sidekiq 復帰時にまとめて上流を叩かない）。
  据え置いた回は本体の寿命を延ばす（作ってから `source_ttl`＝24 時間まで・延ばす先も残り時間で切る＝ Codex P2）。更新ワーカーは `new(lazy: true)`（二重取得をやめた）。
  - harness（`388ffa64`）両系 0 failures / 0 errors（Mastodon 1756 / Misskey 1759 tests）・CI 両系 SUCCESS・Codex は P2 を 1 件直して指摘なし（HEAD `a478d21d`）
  - **dev25 で実測**: Sidekiq を止めて本体キャッシュを消す → `new` は 3965 語（温かいときと同数）を約 90 ms で返し（温かいとき約 50 ms）、ジョブは 1 本だけ積まれた。
    Sidekiq を戻すと 20 秒ほどで本体が埋まった。syslog に `tagging dictionary cold` が 1 行（`restored_sources: 10`）
  - ⚠ development / test は `Worker.perform_async` が同期なので、依頼を出したその場で本体が埋まる（テストの見え方は以前と同じ）

### 2026-10-12 にマージしたもの（2 回目）

- **PR #4828（#4690・機能が前へ進む枠・`dec45a09`）**: 辞書ソースごとの取得間隔 `dics[].interval`（秒）。間隔の内側は上流を引かず、直前の成功分（last-good）を使う。
  既定は今までどおり毎回。印の寿命は `interval` − 600 秒（ワーカーの周期ぶん）・失敗した回は印を置かない・世代ログに `reused_sources`。
  - **前提の実測（#4690 にコメント）**: GAS は `ETag` も `Last-Modified` も返さず `no-store` ＝ **条件付き GET は使えない**
  - **dev25 で実物の GAS を通した**（`5d1c0b38`）: `singer.json` / `series.json` に `interval: 3600` → 2 回目の更新から `reused_sources: 2`・語数 3965 のまま。
    ⚠ dev25 は設定に `interval: 3600` を 2 か所入れたまま（機能は develop に入ったので、そのまま慣らす。バックアップは `config/local.yaml.bak-4690`）
  - **Codex P2 × 3 に対処**（再レビューは指摘なし・CI 両系 SUCCESS・HEAD は `965569ac`）: ① 手動の更新（`POST /tagging/dic/update`・rake）は
    `force` を渡して間隔を無視する ② 実際に取りにいって失敗した回は「新しい」印を消す（残すと定時の更新が取り直さない）
    ③ `force` は文字列・シンボルどちらのキーでも受ける（development / test は `Worker.perform_async` がシンボルにして同期で呼ぶ）。
    dev25 で、定時と同じ呼び方は `reused_sources: 2`・`rake mulukhiya:tagging:dic:update` は `reused_sources: 0` を確認
  - ⚠ **手動更新が間隔を無視するので、ニチアサの直前に辞書を直したら「更新」を押せば届く**
  - 📌 **本番のどのソースにどの間隔を入れるかは未決**（設定の話・ユーザーと決める）。⚠ ニチアサの直前に直す運用があるソースには長い間隔を付けない

- **PR #4829（#4678・`4b6d1031`）**: 同時アクセス下でトークンが取り違えられないことの回帰テスト（`test/unit/controller/concurrent_token_isolation.rb`・4 本）。実コントローラを継いだプローブを、Rack 直呼びと**テスト内の Puma**（keep-alive 8 本・500 リクエスト）で叩き、上流（WebMock）へ出たトークンを応答ごとに突き合わせる。防御策（`verify_token_integrity!`）の発火が 0 回だったことも別に見る。わざと状態を共有させたプローブで「防御策が発火する」「防御策を外すと突き合わせが検出する」も確かめる。CI 両系 SUCCESS・Codex は P2 を 1 件（`/puma/threads` が 1 だと壊したプローブが直列になる）直して指摘なし。
  - 🔴 **事故の版（rack 3.2.3 + sinatra 4.2.0）へ下げても緑だった**（puma 8.0.2 / Ruby 4.0.7・3 回）。＝このテストは事故を再現しない。`Gemfile` の注記を「上げた版でこのテストを回す・緑は安全の証明ではない・ステージングの通し確認は省かない」に改めた。
  - ⚠ 罠: 本物のサービスは `default_token` を DB から引くので、DB の無い環境では `before` が黙って落ちて `sns` が nil になる（500 の本文は `Internal Server Error` だけ）。プローブは `default_token` だけ外した子を `sns_class` で返す。

### ステージングの現在地（2026-10-12 17:30 JST）

dev24 / dev25 / dev26 / dev27 とも develop（`a6c540a1`）・health 200。`media_catalog` は dev25（既定）・dev26（明示の `true`）が有効、
dev24（明示の `false`）・dev27（Misskey）が無効。dev25 は設定に `interval: 3600` を 2 か所入れたまま。
⚠ dev27 は `misskey@dev27.b-shock.local`（Linux・systemd）。`mastodon@dev27` では入れない。

**develop（`a6c540a1`）で harness 両系 0 failures / 0 errors**（Mastodon 1788 tests / 158 omissions、Misskey 1787 tests / 145 omissions）。
⚠ リリースゲートとして読むなら、この後に develop へコードが入っていないこと。

### 残り

- **open は 0 件**（2026-10-12）。リリース前レビュー（5 観点）も済み、**5.41.0 は 2026-10-12 にリリース済み**。⚠ リリース時にやること: Wiki（メディアカタログ・`interval` の運用注意・`EmojiSpacingHandler.md` の `disabled`）、リリースノート冒頭の注意点（#4789 の 5 項目＋メディアカタログの範囲と印＋`disabled:`）、本番のどのソースに `interval` を入れるかの決定
- **2026-10-12 にクローズ（ユーザー判断・not planned）**: #4465（照合の索引化・削れるのは 1 ms 前後で、実測が前提を否定）/ #4756（辞書のプロセス内キャッシュ・約 9 ms に対して、共有した辞書が壊れるとタグ付けが黙って狂う）。
  ⚠ どちらも「辞書の語数が桁で増えたら起こし直す」。**次の大玉として選択肢に出さない**
- ⚠ **Issue は develop へのマージでは自動で閉じない**（`Closes` が効くのは既定ブランチ main だけ）。マージしたら手で閉じる
- ⚠ **作業ツリーを harness が使っている間は、別の worktree で作業する**（ブランチを切り替えると実走中の HEAD が変わる）。
  worktree には `config/local.yaml` が無いので、harness を回すブランチは主ツリーに置く
  （worktree の `rake test` は `'/crypt/password' not found` で errors 2 が出る・変更と無関係）
- ⚠ **辞書のキャッシュを消すテストは、harness の実走中に回さない**（同じ Redis を使う）
- ⚠ ステージングへブランチを渡すスクリプトで `$B:refs/...` と書くと、zsh が `:r` を修飾子として食う。`${B}:refs/...` と書く

## リリース済み: 5.40.0（2026-10-11）

**本番デプロイ: 4 台完了**（2026-10-11 09:31〜09:35、shallu → zugoga → gomander → vulcan の順。
全台 version 5.40.0 / health 200 / Ruby 4.0.7（据え置き）/ FreeBSD 3 台は monit 復帰 / vulcan は 3 ユニットとも `NRestarts=0`）。
`main` の `236193bc` / [v5.40.0](https://github.com/pooza/mulukhiya-toot-proxy/releases/tag/v5.40.0)（PR #4798）。
[マイルストーン 5.40.0](https://github.com/pooza/mulukhiya-toot-proxy/milestone/639)。

### 本番デプロイで見たこと

- ✅ **4 台とも 1 回で通った**（1 台あたり約 1 分）。rc.d / systemd unit の変更なし・Ruby 据え置きなので、bundler の入れ直しも要らなかった
- ✅ `config:lint` は 4 台とも `config: OK`。ginseng-core 2.4.0 / fediverse 5.0.0 / piefed 0.4.0 を 4 台で確認
- ✅ 起動後のエラー行は FreeBSD 3 台とも 0。zugoga の `Bad response 403`（GAS への HEAD）1 行は 09:31:28 の旧プロセス（pid 17858）のもので、
  新しいプロセス（09:33:37〜）では出ていない（#4793）
- ✅ 外から `https://mstdn.b-shock.org/mulukhiya/app/token` を引くと `mulukhiya_oauth_browser` が `secure; httponly; samesite`・`path=/mulukhiya` で付く（#4726）
- ⚠ **日曜の 09:20 に着手した**（ニチアサ 08:30〜09:00 の窓が明けてから・ユーザー「かぶらないように待機」）
- ⚠ **リリース直前の `bundle update` は 4 本が動いたが入れなかった**（net-http 0.10.0 が公開 3 日目・実行時の全 HTTP 経路）。
  セキュリティ上の理由が無い更新を、ゲートのやり直し 40 分だけで本番に載せない。5.41.0 の周回で上げる
- ⚠ **デプロイのスクリプトで `set -- $pair` を使い、zsh が単語分割しないために接続前に止まった**（本番には何も実行されていない）。ホストごとに変数で渡す
- ✅ `gh pr merge` / `gh release create` は、確認ありで通った（5.39.0 で `.claude/settings.local.json` の ask に足した 2 つ）
- ✅ **#4801 / #4793 をクローズし、マイルストーン 5.40.0 を閉じた**（22 件）。#4793 は本番で数えた: `Bad response 403`（HEAD）のエラー行が
  デプロイ前 90 分で gomander 9 / shallu 18 / zugoga 9 → デプロイ後 17 分で 3 台とも 0（GAS への HEAD 自体は撃っている）
- ✅ **リリース後の更新 4 項目**: この文書（5.37.x をアーカイブへ）／wiki 7 ページ（`c8ef788`）／chubo2 `infra-history.md`（`bf4fdb0`）／メモリ
- ⚠ **リリースノートに「メディアカタログの既定値は `false` のまま」を後から足した**（ユーザーの指摘）。5.39.0 のノートで
  「`true` にするのは次の版の予定」と予告していたのに、5.41.0 へ送った（#4789）ことを書いていなかった。
  **前の版のノートで予告したことは、見送ったときも次のノートに書く**
  （節は「メディアカタログについて」。ユーザーの指示で「まだ `true` にしていない」「Mastodon は `true` にすればおおむね問題なく動くはず」の 2 点を書いた）
- 📌 **掃除 PR #4819 のマージは次回**（ユーザー「掃除 PR は次にしましょう」）

### 開発時の記録


- ✅ **2026-10-10 に 4 本をマージ（ユーザー承認）**: PR #4804（#4784・`793f786e`）/ #4805（#4793・`53611ac5`）/ #4806（#4748・`b2829286`）/ #4807（#4742）。
  **#4784 / #4748 / #4742 はクローズ。⚠ #4793 は open のまま**（本番の行数を出荷後に gomander で数えて閉じる。
  dev26 では error 行が消え、info 行と GET だけになったのを確認済み）。
  - ⚠⚠ **積んだ PR の base を `--delete-branch` で消すと、上の PR は付け替わらずに閉じられる。**#4804 のマージで #4805 / #4806 が
    `CLOSED` になり、`gh pr reopen` も通らなかった。**base のブランチを同じ SHA で push し直す → reopen → `gh api -X PATCH pulls/N -f base=develop` → ブランチを消す**で戻した。
    次からは、積んだ PR の base を先に develop へ付け替えてからマージする
  - ✅ **同日に PR #4808（#4790・`e396d4d6`）/ PR #4809（piefed v0.3.0・`ea3bbb77`）もマージ**。#4790 はクローズ
  - ✅ **同日に PR #4810（#4600・`032b3813`）/ PR #4811（#4794・`2a97e3a5`）もマージ**。#4600 / #4794 はクローズ
  - **PR #4804（#4784）**: ginseng-core v2.2.0。`DaemonIdentityMethods` の `run_stop` の上書きを外した（上流の `stop` が身元を見る）。
    8 台とも `tmp` / `tmp/cache` は実ディレクトリ、hook は zugoga / gomander の `discordapp.com`（リダイレクトなし）。
    dev26 / dev27 で 3 サービスの restart / stop / start・`tmp/cache/*.yaml` が 0600・無関係な `sleep` の番号を書いた
    pid ファイルへの `stop`（TERM を送らず pid ファイルだけ消す）を確認
  - **PR #4805（#4793）**: サイズ確認の HEAD に `quiet_statuses: [403, 405]`（`HTTP::HEAD_UNSUPPORTED_STATUSES`）。
    読み辞書・番組表・メディア取得の 3 か所。⚠ base は #4804 のブランチ。本番の行数は出荷後に gomander で数える
  - **PR #4806（#4748）**: ginseng-fediverse v4.0.0（コード変更なし）。⚠ base は #4804 のブランチ。
    実測: `あ#タグ` / `本文。#タグ` / `(#tag)` を抽出しなくなり、`＃全角タグ` を抽出する。
    ⚠ **本文に既にあるタグを足し直すことは無い**（付与側の重複判定 `create_pattern` は手前の境界を見ない部分一致のまま）。
    `escape_toot` の `@` 側は v2.0.5 と同じ（PR #4770 で保留した Codex P2 は挙動が変わらないので据え置き）、
    `#` 側は `曲)#precure` を区切るようになった。
    **harness（`8b2b2d92`）**: Misskey 1650 tests / 0 failures / 0 errors / 145 omissions（`controller=misskey`）、
    Mastodon 1647 tests / 0 failures / 0 errors / 159 omissions（`controller=mastodon`）。
    ✅ dev26 / dev27 はマージ後に develop（`b2829286`）へ戻した
  - **PR #4807（#4742）**: `Redis#acquire_token` / `#release_token`。`ConnectionError` なら待たずに 1 回だけ撃ち直す
    （タイムアウトは撃ち直さない・撃ち直しで NX に負けたら値が自分の token かを見る）。3 つのロックの Lua も 1 か所へ。
    harness の Redis を `docker restart` して、修正前は fail-open・修正後は取得できることを確認。
    ⚠ `reconnect_attempts: 1` は採らなかった（接続設定は gem が作り、冪等でないコマンドにも効く）。
    Codex P2 × 1 に対処: 接続できなかったとき（`CannotConnectError`・接続時のタイムアウトもこれで上がる）は撃ち直さない
  - **PR #4808（#4790）**: `RemoteHost` の判定の本体を `Ginseng::PublicHost` へ委譲（Issue の道 1）。自前の予約レンジの表は削除。
    残したのは DNS タイムアウトの設定・warn ログ・`validator` の差し替え口・`unpinned_validator`・`validate!`
  - **PR #4809**: ginseng-piefed v0.3.0（PieFed 宛がリダイレクトを追わない）。⚠ 実物の PieFed への送信は未確認
  - **PR #4810（#4600）**: `Controller#before` の `reject_invalid_encoding!`。リクエストログの前に検査して 400。
    ⚠ **Issue の前提と違った**: JSON のパーサ（Yajl）は不正な UTF-8 を弾く。500 にはならず、**本文が丸ごと捨てられて
    「内容が空」の要求として奥へ進んでいた**（こちらも 400 に寄せた）。500 / 401 に化けるのはフォームの場合。
    Codex P2 × 2: JSON はメディアタイプでも判定する／文字列はタグを信用せず UTF-8 として検査する。
    ⚠ 後者は実測すると修正前でも落とせていた（Sinatra が `params` を UTF-8 へ `force_encoding` してから `before` に渡す）。備えとして残した
  - **PR #4811（#4794）**: `Mulukhiya::CommandLine#exec` を上書き。締切でプロセスグループへ TERM → 2 秒 → KILL。
    **FreeBSD（dev26）でも再現**（`sleep 5` に 1 秒の締切で 5.0 秒後）。実物の ffmpeg に 2 秒の締切: 修正前は 300 秒待っても戻らず、修正後は 2.25 秒。
    ⚠⚠ **先頭のプロセスの終了を「止まった」と読まない**（シェル経由だと先頭はシェルで TERM で先に死に、TERM を無視する本体が残る。テストで踏んだ）。
    Codex P1 × 2・P2 × 1: 後始末を `ensure` に（外側の `Thread#kill` でも子を残さない）／出力の読み切りまで締切に含める／`timeout: 0` は締切なしのまま。
    上流へは **pooza/ginseng-core#684**（報告）と **pooza/ginseng-core#685**（たたき台）。⚠ **着地した版へ上げたら、こちらの上書きは外す**
  - **#4734**: ①② は 5.37.1 で実装済みだった（`verify_upload_type!`）。件数は vulcan で 24 日 0 件・FreeBSD 3 台は直近 3 日 0 件
    （syslog の保持が 3 日）。✅ **題を「HEIF の取り込みを戻す」に書き換えて on-hold にし、5.40.0 から外した**（ユーザー判断・周知はしない）
  - ✅ **同日に PR #4812（#4726・`a1985181`）/ PR #4814（#4699・`d139a3f8`）/ PR #4815（#4612・`831d863b`）もマージ**。3 件ともクローズ
  - ✅ **5.40.0 の実装は出し切った。**open は出荷で閉じる #4801 / #4793 だけ。**#4789 は 5.41.0 へ送った**（前提の #4353 が fork への依頼で揃わない・ユーザー判断）
  - ✅ **ステージング 4 台（dev24〜27）を develop（`831d863b`）へ揃えた**（`config: OK`・3 サービスの restart rc=0・health 200）
  - 📌 **次回の入口: リリース手順**（`/release-review` → `/release`）。✅ **#4812 のブラウザでのログインの目視は 2026-10-11 に済んだ**
    （ユーザーが dev26 `https://st3.mstdn.delmulin.com/mulukhiya/app/token` で認証し、`token_complete` に着いた）。
    ⚠ **Mastodon は、同じアカウントが同じアプリを承認済みだと認可画面を出さずに callback へ戻す**（`force_login=true` を付けたときだけ出す）。
    画面が出なくても Mastodon へ行って戻る経路は同じなので、合否は `token_complete` に着くかで見る。
    別のブラウザへ持ち込む確認は、PR #4812 の API 直叩き（Cookie なし・別の Cookie が 403）で足りるので省いた。⚠ リリースゲートの harness は `831d863b` で回し直す
    （#4806 / #4814 で回したのは途中の HEAD）。
    → **2026-10-11: #4816 で develop が進んだので、ゲートの harness は `db6d3bc1` 以降で回す**（`b6ef6a5e` の実走は PR のブランチ）
    → ✅ **2026-10-11 05:28〜05:41 JST にゲートの harness を `23dfded2` で実走（系ごとに別シェル）**:
    Mastodon 1695 tests / 3452 assertions / **0 failures / 0 errors** / 159 omissions（`TestHarness: controller=mastodon url=http://localhost:3000`）、
    Misskey 1698 tests / 3505 assertions / **0 failures / 0 errors** / 145 omissions（`TestHarness: controller=misskey url=http://localhost:3001`）。
    ⚠ このあと develop にコードの変更が入ったら回し直す（docs だけのコミットは対象外）
    → ✅ **PR #4818（レビューの指摘 1・2）を 2026-10-11 にマージ（ユーザー承認・`0a8ebb57`）し、ゲートを回し直した（06:36〜06:48 JST・`0a8ebb57`）**:
    Mastodon 1698 tests / 3465 assertions / **0 failures / 0 errors** / 159 omissions（`TestHarness: controller=mastodon url=http://localhost:3000`）、
    Misskey 1701 tests / 3518 assertions / **0 failures / 0 errors** / 145 omissions（`TestHarness: controller=misskey url=http://localhost:3001`）。
    ✅ **ステージング 4 台（dev24〜27）も `0a8ebb57`**（`config: OK`・3 サービスの restart rc=0・health 200・壊れた Cookie つきの `/mulukhiya/app/token` が 200）。
    CI はマージコミットで success。**リリース前レビューは済み＝次は `/release`**
  - **PR #4812（#4726）**: OAuth の state を発行したブラウザに縛る。`/mulukhiya/app/:page` が Cookie `mulukhiya_oauth_browser`
    （HttpOnly・SameSite=Lax・https では Secure・path `/mulukhiya`）を置き、SHA-256 を state に添えて callback で突き合わせる。
    目印の無い state は通さない。**dev26 の修正前で攻撃の形が通ることを確認**（Cookie なしの callback がトークン交換まで進む）、
    修正後は Cookie なし・別の Cookie が 403、同じ Cookie は交換へ進む。
    ⚠ **実際のブラウザでのログインは目視していない**（5.40.0 のステージング確認で行う）。
    ⚠ デプロイの瞬間にログイン画面を開いていた人は認証し直し（state の寿命 10 分）
  - **PR #4814（#4699）**: json 2.21.2 → 3.0.2。`JSON.parse` / `generate` の実体は Yajl なので、既定値の変更は経路に届かない（重複キーは後勝ちのまま）。
    **harness（`b5ebb1ee`）**: Misskey 1682 tests / 0 failures / 0 errors / 145 omissions（`controller=misskey`）、
    Mastodon 1679 tests / 0 failures / 0 errors / 159 omissions（`controller=mastodon`）。
    ステージング 4 台で health 200・エラー行なし
  - **PR #4815（#4612）**: GET に `max_bytes:` を渡して受信中に打ち切る（メディア・読み辞書・番組表）。
    ⚠⚠ **「gem 側の対応待ち」のまま載っていたが、待ち先の pooza/ginseng-core#526 は 2026-08-20 に着地済みだった**
    （[[feedback_milestone-items-may-be-already-done]] の「待ち」版。**待ち先の Issue の状態を着手前に見る**）
    Codex P1 × 1 に対処（`d7d3d177`）: 読み辞書・番組表でも `TooLargeError` を上へ渡さず、URL は `url:` フィールドで残す。
    上流のメッセージから URL を外すたたき台は **pooza/ginseng-core#686**
  - PR #4814 の Codex P1（dev26 が未確認のまま「4 台」と書いていた）は、dev26 にも載せて確かめて解消（コード変更なし）
  - ⚠⚠ **2026-10-10 10:00 JST ごろ、Codex がコードレビューの利用上限に達した。**PR #4815 の再レビュー（`d7d3d177`）は走っていない。
    上限が戻るまで `@codex review` は空振りする。**リリース前の 5 観点レビューがその代わりになる**
  - 残り: #4789（#4353 待ち）。**出荷で閉じる**: #4801 / #4793
  - ✅ **PR #4816（#4813）を 2026-10-11 にマージ（ユーザー承認・`db6d3bc1`）**: ginseng-core v2.4.0 / fediverse v5.0.0 / piefed v0.4.0。**#4813 は 5.40.0 に載せた**（ユーザー「3 本、更新してください」）。
    - `Mulukhiya::CommandLine#exec` の上書き（#4811）を外した（core 2.4.0 が締切で子を止める）。テスト `command_line_deadline` は回帰として残した
    - `StatusHostValidationMethods`（`TootURI` / `NoteURI` に混ぜる）: `host_validator` は `RemoteHost.validator`。
      **自サーバーの URL だけ外す**（設定の `/<controller>/url` と scheme・ホスト・ポートの 3 つとも同じとき）。
      ⚠⚠ **外さない形（`6bb827e8`）は harness の Misskey 系で `NoteURITest#test_to_md` が `Rejected host 'localhost'` で落ちた**
      ＝ harness は「自サーバーが内部アドレスに解決される構成」そのもの。**取得先ホストの検証を足す変更は、開発機の緑では分からない**
    - ⚠ ファイル名に `uri` を入れると Zeitwerk が `Uri` と読む（`status_uri_host_methods.rb` → `StatusUriHostMethods` を探して `NameError`）
    - **dev26（FreeBSD 15.1・`/bin/sh`）で core 2.4.0 の番人が動くことを実測**（pooza/ginseng-core#688 の依頼）: `sleep 30` に 1 秒の締切で 1.0 秒・`still running` なし・残りなし。
      TERM を無視する子は 3.0 秒、実物の ffmpeg（軽い変換）は 2 秒の締切で 2.2 秒・`received signal 15`。⚠ 重い変換（1080p・veryslow）は猶予を使い切って 4.0 秒
    - **harness（`b6ef6a5e`）**: Mastodon 1695 tests / 0 failures / 0 errors / 159 omissions（`controller=mastodon`）、
      Misskey 1698 tests / 0 failures / 0 errors / 145 omissions（`controller=misskey`）。
      ⚠ Misskey の 1 回目は `DictionaryTagHandlerTest#test_handle_pre_toot` が 1 failure（実物の GAS 辞書が空・#4659 の間欠）。同じ HEAD の回し直しで 0 / 0
    - ✅ **ステージング 4 台（dev24〜27）を develop（`db6d3bc1`）へ揃えた**（`config: OK`・3 サービスの restart rc=0・health 200）。
      Codex は 2 つ目のコミット（`b6ef6a5e`）まで指摘なし。✅ **#4813 はクローズ**。`DaemonIdentityMethods` を gem の `process_pattern` へ移す件は **#4817（5.41.0）** へ送った（ユーザー判断）
    - ⚠ **入れていない**: `DaemonIdentityMethods` を gem の `process_pattern` へ移す件（#4813 の 3）。`exec` の最中の一瞬に本物を他人と答える窓は自前の実装に残る
    - ⚠ リリースノートに書く: 例外の文言が `execution expired (Ns)` に変わる／締切のたびに error が 1 行出る／自サーバー以外の内部アドレス宛の投稿 URL は `Rejected host` になる
    - pooza/ginseng-core#688 へ FreeBSD の実測を返した（食い違いなし）
- ✅ **#4792 は PR #4802 でマージ（2026-10-06・`17a7cc22`）・クローズ。**`DaemonIdentityMethods` を 3 デーモンへ混ぜた:
  ① `alive_state_of` を上書きし、`ps` で見たコマンドが自分のものでなければ `:dead`（pid ファイルを取り直す）
  ② `run_stop` を上書きし、他人のプロセスへは TERM を送らず古い pid ファイルだけ消す。
  - **pid ファイルが残る理由が分かった**: puma / sidekiq は `start` が `exec` するので、TERM の trap が置き換わった時点で消える。
    systemd は TERM を直接送る（`ExecStop=/bin/kill -TERM $MAINPID`）ので毎回残り、rc.d は `bin/*_daemon.rb stop` を通すので消える。
    ＝ **FreeBSD 3 台で起きなかったのは構造上の違い**（ただし kill -9・電源断では同じく残る）
  - ⚠⚠ **① だけの段階で、dev26 の Mastodon の web を止めた**（`PumaDaemon.pid` に Mastodon の puma の番号を入れて
    `service mulukhiya-puma restart` → 上流の `run_stop` が身元を見ずに TERM）。すぐ起動し直した。② はこれを受けて足した。
    FreeBSD の本番 3 台は Mastodon とモロヘイヤが同じユーザーなので、同じことが起きうる
  - ⚠ **検証で `dev26` の pid ファイルへ他人の番号を入れるときは、止まって困らないプロセスを選ぶ**
  - 身元が分からない（`ps` が失敗・空）ときは「生きている」扱いのまま（誤ると sidekiq が二重起動する）
  - Codex P2 × 4: 起動スクリプトの一致を `<script> start|restart` の呼び出しに絞る／タグは proctitle の決まった位置で見る／
    `exec` 直後の姿は設定ファイルのフルパスで見る。⚠ **同じユーザーが同じホストで複数のチェックアウトを動かす構成は見分けられない**
    （注意書きに留めた・2 件）。⚠ CI の作業ツリーは親ディレクトリも同名なので、パスにディレクトリ名を探す形はテストが落ちる
  - dev27（systemd）で修正前の再現（`active (running)` のまま `NRestarts` が増える）→ 修正後の復帰、dev26（rc.d）で同じ確認。
    ✅ dev26 / dev27 はマージ後に develop（`d89c8ee4`）へ戻した。
    ⚠ dev26 / dev27 は `ecf74cfa` のままだったので、切り替えに `bundle install` が要った（fediverse v2.0.5 / web v3.0.4）
  - gem 側へ報告: **pooza/ginseng-core#673**（stop が身元を見ない／既定の `alive_state_of` は生死だけ／`exec` で pid ファイルが残る）と、
    1 点目のたたき台 **pooza/ginseng-core#674**。⚠ **着地した版へ上げたら、こちらの `run_stop` の上書きは外す**
- 🆕 **#4801**（Annict のタイムアウトで `/tagging/dic/annict/episodes` が 502・アラートが 1 日 150 件前後）— 2026-10-06 起票。
  **#4792 の次に着手**。案: 成功した結果をキャッシュして失敗時は前回の結果を返し、アラートは「古い結果も返せなくなったとき」だけ
- ~~最初に #4792~~（再起動後に puma が「already running」で上がらない）。⚠ **運用に直結する修正は優先順位を上げる。**
  2026-10-04 の朝、ダイスキー（vulcan）の再起動で実際に約 6 分止まった。`alive_state_of` を上書きして、
  pid ファイルの PID が自分のデーモンかを確かめる。⚠ 正常停止でも pid ファイルが残る理由は未解明（調査込み）。
  ⚠ FreeBSD 3 台は同じ朝の再起動で起きなかったが、**構造上か偶然かは切り分けていない**（対象から外す根拠にしない）
- **#4794**（ffmpeg / ffprobe の締切が子プロセスの終了まで発火しない）— 5.39.0 のリリース前レビューの黄。
  ⚠ 実測は開発機（Linux）だけ。着手時に FreeBSD の実機で再現を取る
- **#4793**（GAS への HEAD が 403 で落ちるたびにエラー行・1 台 1 日 144 行）— ~~pooza/ginseng-core#672 の着地待ち~~
  ✅ **core v2.2.0 で着地（2026-10-07）**。`quiet_statuses: [403, 405]` を渡す。⚠ core 2.x が要るので **#4784 の後**
- **#4789**（Mastodon の media_catalog の既定を `true` に戻す）— #4352 はニチアサ明けの見直しまで済んだ。残る前提は #4353
- ginseng-\* のメジャー: **#4784**（core ~~v2.0.0~~ → ~~v2.1.0~~ → **v2.2.0**・10-10 の同期）/ **#4748**（fediverse ~~v3.1.0~~ → **v4.0.0**・core 2.x が必須）。
  **#4790**（`RemoteHost` の予約レンジの漏れ）は #4784 の後で扱う（2026-10-05 ユーザー判断）
- ✅ **2026-10-06 にマージ（ユーザー承認）**: **PR #4799（#4743）** `f6e491d5` / **PR #4800（#4737・v4 向け）** `73c5c528`。#4743 / #4737 はクローズ。
  **v4 の CI はマージコミットで success**（2026-02 以来）。⚠⚠ **v4 のワークフローにはテストのステップがもともと無い**
  （最後は `rake lint`）＝緑は依存解決・監査・lint まで。⚠ 引数なしの `bundle update` は json 3.0.2 などを掴んで
  mime-types 2.99.3 の `SyntaxError` で止まるので、CI から `rake bundle:update` を外してある
- ✅ **PR #4803（#4801）をマージ（2026-10-06・`d89c8ee4`）。⚠ #4801 は open のまま**（本番に出てから件数で確かめて閉じる）: `AnnictEpisodeDictionary` / `AnnictDictionaryStorage`。直近の成功結果を Redis に持ち（7 日）、
  10 分より新しければ Annict を引かず、失敗したらそれを 200 で返す。アラートは返している結果が 6 時間より古くなったときだけ。
  上流の失敗（`GatewayError`）以外は凌げていても鳴らす。CI 両系 SUCCESS・Codex 指摘なし（👍）。
  ⚠ **実物の Annict を通した確認はしていない**（ステージングのお知らせボットに Annict のトークンが無く 403）。
  本番に出てから Sentry `-2X` の件数と辞書台帳の `annict/episodes` の失敗数で確かめる
- ✅ **5.39.0 の手順 12（掃除）は PR #4795 でマージ済み**（2026-10-04・`bd5031c9`・7 件）。Codex P2 × 1 に対処: 409 の案内で、
  編集時はサブタイトルと Annict エピソード ID も書き換えるよう促す。⚠ **サーバー側で古い情報を自動で消す案は採らない**
  （ユーザー「余計なことをしない今の動作がいい」）。harness とステージングは 5.40.0 の周回で見る

### リリース前レビュー（5 観点）の結果（2026-10-11）

対象は `v5.39.0..develop`（`23dfded2` 時点・アプリとテストで 49 ファイル）。**赤 0 / 黄 7 / 緑 8**（観点をまたぐ重複は 1 件に数えた）。
lint 3 本は通過、ginseng-\* との interface の食い違いは無し。行き先はユーザーが一覧で決めた（「提案のとおり」）。

**本リリースで直す（PR #4818）** — どちらも 5.40.0 の入口の検査が持ち込んだ退行

- **1（黄・赤寄り）**: UTF-8 でないファイル名のメディアアップロードが 400（#4600 の検査が、アップロードのパートの `filename` と `head` まで見ていた）。
  `tempfile` を持つ Hash には潜らないようにした。dev26 / dev27 で修正前 400 → 修正後は認証つきの実アップロードが 4 通りの文字コードとも 200
- **2（黄）**: 壊れた UTF-8 の Cookie 1 本で `/mulukhiya/app/:page` が 500 ＋アラート（#4726 の `oauth_browser_nonce` が正規表現で `ArgumentError`）。
  壊れた値は捨てて作り直す。dev26 / dev27 で修正前 500 → 修正後 200
- ⚠ **Codex P1 × 1 は再現せず**（「検査を外してもリクエストログの JSON 化で落ちる」）。`JSON.generate` の実体は Yajl で、バイト列をそのまま通す。
  ⚠⚠ **未認証の要求で確かめると、通っても落ちても 401 で区別が付かない**（`before` の rescue がトークンを外すため）。認証つきで通して確かめた

**掃除 PR（手順 12）へ**

- **3（黄）**: Annict が空の結果や「200 ＋ errors」を返すと、空の辞書が直近の良いキャッシュを上書きする（`annict_episode_dictionary.rb` の `fetch`）。
  `works` 側は同じ応答で `NoMethodError` になり、凌げていても毎回アラート。応答の形が合わなければ `GatewayError` に寄せる。⚠ Annict がこの形を返す頻度は未確認
- **4（黄）**: Annict が 6 時間を超えて落ちると、アラートが取得のたび（10 分おき・抑止は 300 秒）に鳴る。鳴らした印を持つ
- **5（黄）**: 拒否されるホストの URL を PieFed へクリップすると 4 回試行・Sentry 4 件・利用者には何も返らない（`piefed_clipping_worker.rb`・`retry: 3`）。
  ⚠ **`status_host_validation_methods.rb` のコメント「拒否の warn ログが付く」は誤り**（PR #4816）。warn が出るのは名前解決が例外で落ちたときだけ
- **6（黄）**: 不正な UTF-8 の 400 が `docs/api.md` の「エラーレスポンス」に無い
- **9（緑）**: OAuth の 3 種類の失敗（state の失効・Cookie の不一致・`code_verifier` 無し）が同じ文言「Invalid OAuth state」
- **10（緑）**: `/daemon/restart/timeout/seconds` が `config/schema/base.yaml` に未宣言
- **11（緑）**: 死んだコードと古いコメント — `RemoteHost.internal_address?`（呼び出し 0）／`NowplayingResolver#artwork_pixel` の届かない `rescue`／
  `.github/dependabot.yml:45` と `test/unit/lib/dependabot_config.rb:5` の json「据え置き中」／`command_line_deadline.rb` の `upstream` 比較と `test_without_timeout_uses_upstream`／
  `daemon_identity_methods.rb` 冒頭の「rc.d と同じ物差し」／`invalid_encoding.rb:6`（JSON 経路を逆に書いている）／`redis_token_lock.rb:8`／`remote_host.rb`（テスト）`:7-8`／
  `spotify_oauth_failure.rb:55`／`media_file_download_methods.rb:26-28` と `:61`／`sns_service_methods.rb:93` の「Web UI」／
  `annict_episode_dictionary.rb`（テスト）の `setup` が設定を戻さない／この文書の「5.32.x 以前のリリースノートは」の案内

**記録のみ**

- **7（緑）**: 外部の Mastodon の投稿 URL の取得がリダイレクトを追わなくなった（fediverse 3.x 以降、トークンが空でも `Authorization: Bearer ` が付き、`RedirectGuard` が追従を止める）。
  `http://` で書かれた投稿 URL のクリップ・引用が `Bad response 301`。https の正規 URL は影響なし。本筋は gem 側。**リリースノートに注意書き**
- **8（緑）**: 形の合う Cookie をそのまま目印に採るので、Cookie を植えられる相手（兄弟サブドメインを握る・平文 HTTP に割り込む）にはログイン CSRF が残る。
  `__Host-` 接頭辞で塞げる。本番 4 台では現実的な経路なし
- **12（緑）**: ログが出ない経路 3 つ（デーモンの身元が分からないとき／`never_silent?` の経路に発生源が載らない／ロックの撃ち直しが無言）
- **13（緑）**: ハンドラの締切を 6 秒未満にすると、内側の締切の後始末（締切 ＋ 最大 3 秒）が外側の余白を超える。既定の 90 秒では起きない
- **14（緑）**: Annict 辞書の取り直しに排他が無い。⚠ `fresh: 600` は取得の周期（10 分）と同じ値なので、Annict への要求を減らす効果は期待しない

**そのほか**

- ⚠ **#4722 は 3 件のうち 2 件（音声変換と ffprobe の締切・出力ファイル名の衝突）が実装済みに見える**という報告あり。未確認。着手前に実体を見る
- wiki に書く項目（レビューが挙げた 10 個）: Annict 辞書のキャッシュ 3 キー／`/tagging/dic/annict/episodes` が障害時も 200／不正な UTF-8 は全ルートで 400／
  ログインに Cookie `mulukhiya_oauth_browser` が必須／アップグレード手順（Ruby 版・ginseng の版）／デーモンの pid ファイルと「1 ユーザー 1 チェックアウト」／
  クリップ・引用の URL は公開ホストだけ（自サーバーは scheme・ホスト・ポート一致で外す）／ffmpeg・再起動の締切が子を実際に止める／
  `max_bytes` 3 つが受信中にも効く／番組表「話数 ＋」の 409 の文言

## セッション同期の記録

### 2026-10-24 セッション同期の記録

**本番には触っていない**（辞書台帳の生成で本番 4 台へ SSH した読み取りのみ）。chubo2 の Issue 棚卸し（10-02・22 日）と harness の upstream 確認（10-23）はスキップ。

- **ブランチ**: `develop` は `origin/develop` と同一（`8e0e0028`）
- **Dependabot**: open アラート **0 件**
- **open PR**: **#4852（#4838）・#4849（#4845）とも CI 緑（mastodon / misskey）・Codex の指摘は返信・👍 済み＝マージ待ち**
- **Codex / 申し送り**: #4840〜#4844・#4849・#4852 とも完了（未返信・リアクション漏れなし・`pooza` の申し送りなし）
- **マイルストーン**: 5.43.0 は open 5 件（#4853 / #4845 / #4838 / #4677 / #4566）、5.44.0 は open 5 件（#4854 を含む）。on-hold 以外でマイルストーン無しは 0 件
- **ginseng-\* のピン**: ginseng-core v2.4.2 → v4.0.0 のずれのみ（#4848・5.44.0 の判断どおり）
- **Annict の API**: 10-23 と同じ（`rails/app/graphql` の最新は 10-17・公式アカウントは 10-06 のまま）
- **辞書台帳**: **🔴 死亡 0**。🔴 直書き（gomander の GAS）・🔴 台帳に無い 2 行は既知のまま。🟡 は #4659 の型の入れ替わり。再生成を chubo2 へ（`d47d678`）
- **chubo2**: open 24 件（前回 23）。新規は #288（Ubuntu の nvm 台の Node を 10 月のセキュリティリリースへ）。#286（Ruby 4.0.9 を rbenv に）は open のまま＝ #4853 はサーバー待ち。
  ⚠ 作業ツリーに別セッションの変更（`config/node/*.yaml` 4 本・`tools/weekly-update.rb`）があるので触っていない

#### Sentry

- unresolved **34 件**（-1X を resolve した後）。**コメント 0 は 0 件**（2026-10-24 時点）
- ✅ **-1X（count=394・2026-10-24 時点）**: 最後は 10-23T00:57Z のまま約 1.5 日再発なし → **resolve**（Sentry にコメント）。再発したら URL の移転・再閉鎖を疑う
- -J（count=168）・-38（count=6）・-2X（count=585）とも 10-23 から増えていない（2026-10-24 時点）

### 2026-10-23 セッション同期の記録

**本番には触っていない**（辞書台帳の生成で本番 4 台へ SSH した読み取りのみ）。chubo2 の Issue 棚卸し（10-02・21 日）はスキップ。

- **ブランチ**: `develop` は `origin/develop` と同一（`a527a0e7`）
- **Dependabot**: open アラート **0 件**
- **open PR**: **#4849（#4845）は CI 緑（mastodon / misskey）・MERGEABLE・Codex 指摘なし＝引き続きマージ待ち**
- **Codex / 申し送り**: #4840〜#4844・#4849 とも完了（未返信・リアクション漏れなし）
- **ginseng-\* のピン**: ginseng-core v2.4.2 → v4.0.0 のずれのみ（#4848・5.44.0 の判断どおり）
- **Annict の API**: 10-18 と同じ（`rails/app/graphql` の最新は 10-17・公式アカウントは 10-06 のまま）
- **辞書台帳**: **🔴 死亡 0**。🔴 直書き（gomander の GAS）は既知の 1 行で、今回 1/144 の間欠。🟡 は #4659 の型の入れ替わり。再生成を chubo2 へ（`7751789`）
- **harness upstream**: 新しい版なし（Mastodon v4.7.3 / Misskey 2026.10.0。Misskey 2026.10.1-alpha.1 は alpha）。`last_checked` を 10-23 に
- **chubo2**: open 22 件（前回 21）。新規は #284（FreeBSD の Node を 10 月のセキュリティリリースへ・pkg 待ち。vulcan は 26.12.1 済み `f7cb78d`）

#### Sentry

- unresolved **35 件**。**コメント 0 は 0 件**（2026-10-23 時点）
- ⚠ **-1X（count=349・前回 10-18 は 110）**: 増分の 238 件は **zugoga で 2026-10-22T01:27Z から 5 分おきに継続中**。
  カスタムフィードが `www.dqdai-official.com:443` へつなげない（Connection refused）。手元からも 443 が拒否される＝**相手のサイトの停止**。
  対応なし・復旧待ち（Sentry にコメント）。復旧後も止まらなければ URL の移転を疑う。残り 1 件は gomander の 502（一過性）。
  停止の理由は **PHP2Shell**（CVE-2026-109618 / 109619・PHP 本体の未認証 RCE・修正版は 10-21 14:00 UTC）への対応で
  ポータル（PHP）を閉じている可能性が高い（ユーザー指摘）。拒否の開始は修正版公開の約 11 時間後で時刻が合う。閉鎖が長引くことはありうる
  → **同日 2 回目の同期（08:45Z）で復旧を確認**: count=394・最後は 00:57Z。サイトは 200。再発しなければ次の同期で resolve を検討（Sentry にコメント）

#### 同日 2 回目の同期（08:45Z）

- **新規 Issue #4853（Ruby 4.0.9・Onigmo の CVE 4 件）**: ginseng-style 側のセッションが 07:21Z に起票（pooza/ginseng-style#131 の配布）。
  マイルストーンが無かったので **5.43.0 に載せた**。⚠ **順番はサーバーが先**（chubo2#286 で rbenv に 4.0.9 を入れてから `.ruby-version` の PR）。
  🔴 当たりは `RemoteDictionary#create_pattern`（遠隔の辞書の語でパターンを組む・語が長いほど繰り返しが増える）
  → ✅ **確認の結果、当たりなし**（#4853 にコメント・ginseng-style#131 へ申し送り）。4.0.9 の修正（ruby/ruby@c3c8863acd）が止めたのは
  range repeat / null check の ID だけで、`.?` と `[あぁ]` はどちらも使わない。メタ文字は全部 `.? ?` になるので辞書の語からは作れない。
  公開の辞書 15 本・8,230 語で記号の最大は 9 個。**語の長さの上限は不要。**残りは `.ruby-version` をサーバーの後で上げることだけ
- **PR #4852**: Codex の P2（チェックリストが Mastodon のテーブルしか案内していない）を `6441983f` で直して返信・👍。CI は両系とも緑
- **辞書台帳**: 前回と同じ（🔴 死亡 0・直書きは既知の 1 行）。chubo2 へ `6f574ec`
- **chubo2**: open 23 件。新規は #285（kues の後始末）・#286（Ruby 4.0.9 を rbenv に）。⚠ 作業ツリーに別セッションの変更（`config/node/*.yaml` 8 本）があるので触っていない
- その他（Dependabot 0・Codex の取りこぼし 0・Sentry のコメント 0 は 0・ピン・Annict）は 1 回目と同じ
- -J（count=168）の増分は他者サーバー（`server_name=mulukhiya`・5.37.1）の Redis 接続拒否（10-19 / 10-21）。族の判断（09-02）は据え置き

### 2026-10-20 セッション同期の記録

**本番には触っていない。**急ぎの件の確認に絞った簡易同期（辞書台帳・Annict・chubo2 の棚卸しは省略。harness の upstream は `last_checked` から 2 日でスキップ）。

- **ブランチ**: `develop` は `origin/develop` と同一（`db026e8b`）
- **Dependabot**: open アラート **0 件**
- **Mastodon 5.0**: 上流はタグなし（main は `5.0.0-alpha.1`、beta は 10-20 以降・stable は「数週間後」）。pooza/mastodon はマイルストーン 5.0.0 で新 UI への移植を始めている。
  モロヘイヤ側は **#4850**（harness で beta → RC → stable を検証）と **#4851**（フォークが呼ぶ面の形を保ち、移植後にステージングで通しで確認・DM がタイムラインから外れる影響）を起票し 5.44.0 へ。
  5.0 にこちらから取りに行く新機能はほぼ無い（ハッシュタグフィードは 5.1〜5.2 予定・中身が見えたら検討）
- **open PR**: **#4849（#4845）は CI 緑・Codex 👍（指摘なし）＝マージ待ち**
- **Codex**: #4840〜#4844 は全件返信・リアクション済み。#4849 は指摘なし
- **Sentry**: unresolved **35 件**。コメント 0 は 1 件 → 判断を書いて 0 件（2026-10-20 時点）。
  **-38（新規・count=6）**: 他者サーバー `instance-20220704-2044`（5.42.0）の Sidekiq で 10-19 15:55Z の 1 秒間だけ Redis 接続拒否。先方の Redis 再起動と見られる一過性
- **ginseng-\* のピン**: ginseng-core v2.4.2 → v4.0.0 のずれのみ（#4848・5.44.0 で取り込み済みの判断どおり）
- **chubo2**: open 21 件（前回 18）。新規 #279〜#283 はいずれもモロヘイヤの急ぎではない
  （#283 は 10-17 の `pkg upgrade` で lmdb0 が消えた件＝PowerDNS / Samba 側）

### 2026-10-18 セッション同期の記録

**本番には触っていない**（辞書台帳の生成で本番 4 台へ SSH した読み取りのみ）。日曜 13:30 JST・ニチアサ明けに実施。
chubo2 の Issue 棚卸し（10-02・16 日）はスキップ。

- **ブランチ**: 作業は `feature/4566-pleroma-controller`（PR #4844）。`develop` は `origin/develop` と同一（`e2873ff5`）・CI `success`
- **Dependabot**: open アラート **0 件**
- **open PR**: #4842（#4677）/ #4844（#4566）
- **Codex / 申し送り**: #4840 / #4841 / #4843 は完了（#4841 / #4843 は指摘なし）。#4842 は 4 件とも返信・リアクション済み
  （10-15 の `@codex review` の後、新しい指摘は来ていない）。
  ⚠ **#4844 に 10-16 00:32Z の指摘 2 件が未返信だった**:
  - P1 `Pleroma::HashTag` に `values` が無く、`HashTagMethods#to_h` が落ちる（`/feed/list`・`Pleroma::Status#to_h` が 500）。
    v4 では `to_h` を上書きしていたのが、戻したときに落ちていた。→ 空の `values` を足して直した（`3c442f23`・テストは修正前に落ちることを確認）。返信・リアクション・`@codex review` 済み
  - P2 README は `pleroma/` に `local.yaml` があると書いているが、`config/.gitignore` の `local.*` で**未追跡**（mastodon / misskey は強制追加されている）。
    手元には在る。⚠ `git add -f` はオートモードに止められたので、ユーザー判断待ち
- **5.43.0**: open 6 件 / closed 2 件（#4685 / #4233）。⚠ **#4722 は PR #4843 で済んだが open のまま**（develop へのマージでは閉じない）。
  #4375 / #4323 は vulcan の 24 時間観測（〜10-17 06:30）が明けた＝クローズ待ち
- **ginseng-\* のピン**: ⚠ **ginseng-core が v2.4.2 → v3.0.0（10-15・major・security 4 件）**。モロヘイヤが触る面（`HTTP` / `Logger`）に当たる:
  `guard_redirects!` で資格情報つきと見なす要求が増える（`follow_redirects:` を明示している呼び出しは従来どおり）、ログのマスク範囲の拡大。
  `CommandLine#secrets=` に Hash を渡す箇所・外された定数の参照はモロヘイヤに無い。同日 v4.0.0 も出た。
  → **② 次の版で取り込む**（緊急性なし・ユーザー判断）。取り込むときの最新 major を入れる（#4848・5.44.0）
- **chubo2**: open 18 件（前回 25）。#269 / #270 / #273 / #274 / #275 / #276 / #277 / #278 が close。
  🔴 **#277: 10-17 朝、gomander の `pkg upgrade` で ports の openssl が 3.0 → 3.5 に上がり、rbenv の Ruby が起動しなくなった**
  （Mastodon / モロヘイヤ / cure-api）。10-18 に FreeBSD 全台の Ruby を base の OpenSSL へ作り直した（gomander は 09:20・ニチアサ明け）
- **Annict の API**: ⚠ `rails/app/graphql` に **2026-10-17「Rails版の表示から非公開・削除済みの人物を除く」**（`beta/annict_schema.rb` +3）。
  キャスト・スタッフから非公開の人物を除くもので、モロヘイヤが使う面（作品・エピソード・記録）には当たらない。#3157 も動かない。公式アカウントは 10-06 のまま
- **辞書台帳**: **🔴 の行に差分なし・🔴 死亡 0**。🟡 は前回の gomander の 4 行が 🟢 に戻り、別の 4 行が 1〜3/144（#4659 の型）。再生成を chubo2 へ（`cab7951`）
- **harness upstream**: 新しい版なし（Mastodon v4.7.3 / Misskey 2026.10.0 のまま）。`last_checked` を 10-18 に

#### Sentry

- unresolved **34 件**（前回 33）。**コメント 0 は 1 件 → 判断を書いて 0 件**（2026-10-18 時点）
- **-37（新規・count=1）**: gomander・`POST /api/:version/statuses/:id/favourite` で本体が 404。消えた投稿へのお気に入りと見られる。一過性・様子見
- **-1X（count=110）**: 増分 7 は zugoga（10-18 07:57〜08:12 JST）と gomander（09:05〜09:15 JST）。#277 の再ビルド中にカスタムフィードが作りかけの Ruby で落ちたもの。再起動後は無し
- **-34 / -2F**: 10-17 09:25〜09:27 JST に zugoga → shallu → gomander の順で Redis 接続拒否。10-17 朝の更新作業で Redis が先に再起動されたと推定。以後なし
- -2X / -2Y の増分は他者サーバー（`instance-20220704-2044`・5.37.1）の Annict タイムアウト。判断は据え置き

### 2026-10-16 セッション同期の記録

**本番には触っていない**（辞書台帳の生成で本番 4 台へ SSH した読み取りのみ）。金曜に実施。
chubo2 の Issue 棚卸し（10-02・14 日）と harness upstream（`last_checked` 10-14・2 日）はスキップ。

- **ブランチ**: `develop` は `origin/develop` と同一（`e2135bce`）・未コミット無し。CI は `e2135bce` で `success`
- **Dependabot**: open アラート **0 件**
- **open PR**: 0 本
- **Codex / 申し送り**: 直近マージ 5 本（#4835 / #4836 / #4837 / #4839 / #4840）。#4836 / #4837 は返信・リアクションとも済み、#4835 / #4839 は指摘なし。
  ⚠ **リリース PR #4840 に、マージ後（10-14 07:54 JST）に届いた P2 が 1 件・未返信**:
  `Pgbouncer#warning`（`app/lib/mulukhiya/dbms/pgbouncer.rb`）は `clients_ratio` を `Numeric` かどうかしか見ていないので、
  `1.1` のような範囲外の値だと割合が超えられず、**上限に達するまで WARN が出ない**（スキーマの検査は既定で非 strict なので起動は通る）。
  指摘は正しい（0 以下は常に WARN になるので見える側に倒れるが、1 超は黙って無効になる）。→ **同日ユーザー判断で直した（PR #4841）・返信とリアクション済み**
- **5.43.0**: open 8 件 / closed 0 件（docs の記載と一致）。マイルストーンの無い open Issue は on-hold の 10 件だけ
- **ginseng-\* のピン**: ずれなし（8 本とも最新タグ）
- **chubo2**: `origin/main` と同一。open 25 件（前回 27）。#270 / #275 / #276 が close
- **Annict の API**: 基準（2026-10-06）と同じ。公式アカウントの最新も 10-06 のまま
- **辞書台帳**: **🔴 の行に差分なし・🔴 死亡 0**。🟡 間欠が増えた（gomander の `precure.ml/api/dic/v1/dic.json` が 2 → 22/144、
  ほか 6 行が 🟢 → 🟡 2〜5/144・探査で `precure.json` が 404 text/html）。#4659 の GAS の間欠 404 の型。再生成を chubo2 へコミット済み（`41def63`）

#### Sentry

- unresolved **33 件**（前回 33・新規なし）。**コメント 0 は 0 件**（2026-10-16 時点）。最終発生は `-34` / `-2F` の 10-12（計画停止・判断済み）が最新

### 2026-10-14 セッション同期の記録

**本番には触っていない**（辞書台帳の生成で本番 4 台へ SSH した読み取りのみ）。水曜の 06:30 JST ごろに実施。
chubo2 の Issue 棚卸し（10-02・12 日）はスキップ。harness upstream は `last_checked` 10-10 から 4 日なので実施。

- **ブランチ**: `develop` は `origin/develop` と同一（`f2c133ca`）・未コミット無し。CI は `f2c133ca` で `success`
- **Dependabot**: open アラート **0 件**
- **open PR**: 0 本
- **Codex / 申し送り**: 直近マージ 5 本（#4829 / #4830 / #4831 / #4833 / #4834）。#4829〜#4833 は返信・リアクションとも済み。
  ⚠ **リリース PR #4834 に、マージ後（10-12 17:04 JST）に届いた P2 が 1 件・未返信**:
  `AnnictEpisodeDictionary#fetch` の「作品はあるのに回が空ならキャッシュを残す」が、**見る作品（`/service/annict/works`）を入れ替えた直後**にも効き、
  新しい作品にまだ題のついた回が無い間（最長でキャッシュの寿命 7 日）、前の作品の回がタグ辞書に残る。
  指摘は正しい（キャッシュに作品の ID を持っていない）。当たるのは作品を入れ替えた直後だけ。**直すかはユーザー判断待ち**
- **5.42.0**: open 3 件（#4323 / #4375 / #4695）/ closed 1 件。5.43.0 は open 5 件。マイルストーンの無い open Issue は on-hold の 10 件だけ
- **ginseng-\* のピン**: ずれなし（8 本とも最新タグ）。こちらが送った pooza/ginseng-core#684 / #685 / #686 / #688 はどれも close 済み・取り込み済み
- **chubo2**: `origin/main` と同一。open 27 件（前回 24）。前回の同期のあとに立った #272（index を揃えるか）/ #273（15.1 化の戻り先の片付け）/
  #274（monit の mastodon-puma の検知がモロヘイヤの puma にも当たる）/ #275（chubo-core の修正は必要とした側が PR を出す）
- **Annict の API**: 基準（2026-10-06）と同じ。公式アカウントの最新も 10-06 のまま
- **辞書台帳**: **🔴 の行に差分なし・🔴 死亡 0**。🟡 間欠は gomander の `precure.ml/api/dic/v1/dic.json`（2/144）だけに戻った
  （前回の 7 本は 10-11 深夜の名前解決の失敗のぶん）。再生成を chubo2 へコミット済み
  - ⚠ ログ上の取得回数で `precure.ml` の `series.json` / `singer.json` だけモロヘイヤ 567 → 400 前後（ほかは 550 前後）。
    dev25 がこの 2 本に `interval: 3600` を入れているのと数が合う（未確認・異常ではない）
- **harness upstream**: 新しい stable / RC は無い（Mastodon v4.7.3・Misskey 2026.10.0 のまま。Misskey 2026.10.1-alpha.0 は対象外）。`last_checked` を 10-14 に

#### Sentry

- unresolved **33 件**（前回 33・新規なし）。**コメント 0 は 0 件**
- `-34`（count 6 → 9）と `-2F`（count=48）に、**10-12T05:15:22Z（14:15 JST）の shallu・5.40.0・3 イベントずつ**が足された。
  shallu の 15.1 化（pooza/chubo2#240）でクローン取得のために止めた 1 回目の停止（14:13:41 → 14:21:09 JST）の中＝計画停止。判断をコメントに書いた
- `-35` / `-36`（名前解決）は 10-11 から増えていない。`-2X` / `-2Y`（Annict のタイムアウト）も 10-10 が最後

### 2026-10-12 セッション同期の記録

**本番には触っていない**（辞書台帳の生成と Sentry `-35` / `-36` の裏取りで本番 4 台へ SSH した読み取りのみ）。月曜の 06:30 JST ごろに実施。
chubo2 の Issue 棚卸し（10-02）と harness upstream（`last_checked` 10-10・2 日）はスキップ。

- **ブランチ**: `develop` は `origin/develop` と同一・未コミット無し。CI は `0dcfd23d` で `success`
- **Dependabot**: open アラート **0 件**
- **open PR**: #4819（掃除 8 件）だけ。CI 両系 SUCCESS・`MERGEABLE` / `CLEAN`。✅ **同日にマージ（ユーザー承認・`6010f8e6`）**。open PR は 0 本
- **Codex / 申し送り**: 直近マージ 5 本（#4812 / #4814 / #4815 / #4816 / #4818）と open 1 本の行コメント・PR 本体コメントとも**未消化ゼロ**
- **5.41.0**: open 9 件（Issue 8 ＋ PR #4819）/ closed 0 件。マイルストーンの無い open Issue は on-hold の 8 件だけ
- **ginseng-\* のピン**: 🆕 **前回の同期のあと（10-11 05:00〜06:00 JST）にタグが 4 本切られた**。こちらの Issue は立っていない
  - **core v2.4.0 → v2.4.2**（v2.4.1 / v2.4.2・security）: 署名付き URL のクエリ（`signature` / `sig` / `x-amz-signature` / `hm` / `jwt` など）を
    既定でマスクする＝**いまはログに平文で残っている**。`TooLargeError` の文言から URL が外れた（こちらのたたき台 pooza/ginseng-core#686 の着地）。
    ⚠ `guard_redirects!` を挿した HTTP は、上の名前をクエリに持つ要求の 3xx を追わなくなる（モロヘイヤの `app/` に `guard_redirects` は 0 件）
  - **fediverse v5.0.0 → v6.0.0**（v5.0.1 / v6.0.0・破壊的）: `Service#upload_remote_resource` が取得先のホストを検証する。
    ⚠ **モロヘイヤは `upload_remote_resource` を上書きしている**（`sns_service_methods.rb`・取得は `MediaFile.download`）ので、この変更は届かない
    （リリースノートにも同じ記載）。gemspec の core の床は変わっていない
  - **判断: ② 5.41.0 で取り込む**（core と fediverse を 1 本で・harness 両系とステージングを通す）。✅ **#4820 として起票し、5.41.0 に載せた**（ユーザー承認）
  - 既知のまま: youtube v3.0.2（③ 見送り）/ style `ed862dcf` → v1.1.14（5.41.0 で単独で）
- **chubo2**: `origin/main` と同一。`infra-note.md` の変更なし。open 24 件（前回 24・新規なし）
- **Annict の API**: 基準（2026-10-06）と同じ。公式アカウントの最新も 10-06 のまま
- **辞書台帳**: **🔴 は前回と同じ 3 件**（直書き 1 / 台帳に無い 2）・**🔴 死亡 0**。🟡 間欠が gomander の `precure.ml/api/dic/v1/*` 7 本に出た
  （1〜9/141）のは、下の名前解決の失敗の時間帯のぶん。再生成を chubo2 へコミット済み（`0290d5f`）

#### Sentry

- unresolved **33 件**（前回 31）。**コメント 0 が 2 件**あったので、裏を取って判断を書いた（コメント 0 は 0 件に戻した）
  - `-35`（count=3・10-11T15:04Z〜15:47Z・gomander・5.40.0・`AnnouncementWorker`）と
    `-36`（count=2・10-11T15:18Z〜15:33Z・同・`StartupNotificationWorker`）: **自ドメイン `precure.ml` の名前解決が
    10-11 23:57〜10-12 01:16 JST に間欠的に失敗した**（`getaddrinfo(3): Name does not resolve`・syslog に 336 行）
  - **失敗した名前は `precure.ml` だけ**（同じ窓で宛先 895 本のうち 311 本が失敗。`api.annict.com` 654 本などは引けている）。
    外形監視 `-1W`（Downtime detected）も 23:56 JST に出ている＝外からも引けていない。
    同じ並びのリゾルバを使う shallu / zugoga は 0 行なので、**リゾルバ（1.1.1.1 など）全体の障害ではない**（ユーザーの問いへの答え）。
    権威 DNS が同じ兄弟ドメインは無事なので `.ml` の TLD 側が疑わしいが、事後で未特定
    （ユーザー: `.ml` の権威サーバーは大昔に不安定だったことがある・最近は無かった）
  - ⚠⚠ **副作用: monit がモロヘイヤを 4 回再起動した**（00:12 / 00:26 / 00:28 / 00:37 JST）。`/mulukhiya/api/health` が
    `https://precure.ml/api/v1/streaming/health` を**公開名で**引くので、名前が引けないと 503 になる。**再起動しても直らない失敗で再起動が走る。**
    `-36` はその再起動のたびに起動通知が同じ失敗で落ちたもの。✅ **#4821 として起票し、5.41.0 に載せた**（ユーザー「起票してください」）
  - 経緯は chubo2 `infra-history.md` に書いた
  - ⚠ 2 件目のコメントを書くとき、一時ファイルの上書きが zsh の noclobber で失敗し、`-36` に `-35` の文面が入った。消して書き直した
- `-2X` は count=581・`-2Y` は count=34 で前回から変化なし。ほかも変化なし

### 2026-10-11 セッション同期の記録

**本番には触っていない**（辞書台帳の生成・Sentry `-34` の裏取り・#4813 の前提確認で本番 4 台へ SSH した読み取りのみ）。
日曜の 04:30 JST ごろに実施（ニチアサの窓の前）。chubo2 の Issue 棚卸し（10-02）と harness upstream（`last_checked` 10-10）はスキップ。

- **ブランチ**: `develop` は `origin/develop` と同一・未コミット無し。CI は `fee13bf6` で `success`
- **Dependabot**: open アラート **0 件**
- **open PR**: #4798（5.40.0 のリリース PR）だけ
- **Codex / 申し送り**: 直近マージ 8 本（#4807〜#4815）と open 1 本の行コメント・PR 本体コメントとも**未消化ゼロ**
  （Codex の指摘 8 件はすべて返信 ＋ 👍 済み）。⚠ #4815 の再レビュー（`d7d3d177`）は利用上限で走っていないまま
- **5.40.0**: open 3 件（#4801 / #4793 ＝出荷で閉じる・#4798 ＝リリース PR）/ closed 16 件
- 🔴 **#4813 がマイルストーン無し・on-hold でもない**（10-10 に `ginseng-*` の当番が起票・10-10 16:11 JST に追記）。
  **ピンのずれ 3 本はこの Issue と同じもの**: core v2.2.0 → **v2.4.0** / fediverse v4.0.0 → **v5.0.0** / piefed v0.3.0 → **v0.4.0**。
  - **fediverse 5.0.0（security）**: クリップのコマンドに `http://127.0.0.1:<port>/@a/1` のような URL を書くと、
    ローカルのサーバーへ要求が届いていた（pooza/ginseng-fediverse#306）。⚠ **piefed 0.4.0 と同時に上げる**
  - **core 2.4.0**: 締切つきの `exec` が締切で子を止める（こちらが報告した pooza/ginseng-core#684）。
    上げたら `Mulukhiya::CommandLine#exec` の上書き（#4811）を外せる。
    ⚠⚠ **当番の指摘: #4811 の上書き（＝たたき台 #685 の写し）には、gem 側のレビューで直した 3 点が残っているはず**
    （止められない子がいると締切後も戻らない／ゾンビを「まだ居る」と数えて最大 2 秒余計に待つ／
    回収済みの番号へ TERM・KILL を送る窓＝番号が再利用されていると無関係なプロセスグループに届く）。
    ⚠ 向こうは実行しておらず、#685 の時点のコードからの推論。**5.40.0 は未出荷なので、この上書きはまだ本番に出ていない**
  - ⚠ core 2.4.0 の番人（`/bin/sh`）は **FreeBSD の `sh` で未実測**（pooza/ginseng-core#688）。上げるなら dev26 で 1 回試す
  - **前提の確認（読み取り）**: 本番 4 台とも `/etc/hosts` に自ドメインの上書きは無く、プロキシの環境変数も無い。
    `precure.ml` / `mstdn.b-shock.org` / `mstdn.delmulin.com` は公開アドレスに解決される（開発機から `dig`）。
    ⚠ ダイスキー（vulcan）のドメインと、各箱のリゾルバから見た答えは未確認
  - 📌 **どのマイルストーンに載せるかはユーザーの判断待ち**（5.40.0 に入れるか、出荷後の版へ送るか）
- **ginseng-\* のピン（ほか）**: style `ed862dcf` → v1.1.14 は 10-10 に「② 5.40.0 のどこかで」とした**まま未着手**。youtube v3.0.2 は ③ 見送りのまま
- **chubo2**: 1 コミット遅れていたので早送りで取り込んだ（`00d34a1`・`docs/infra-servers.md` の capsicum-relay の APNs の鍵の記述・
  `infra-note.md` の変更なし）。open 24 件（前回 24・🆕 #270 Kuma に tomato-shrieker のモニター 3 件 / #271 kues の sdb の読み取りエラー、
  10-09 に #263 が閉じた）。どちらもモロヘイヤには当たらない
- **Annict の API**: 基準（2026-10-06）と同じ。公式アカウントの最新も 10-06 のまま
- **辞書台帳**: **🔴 は前回と同じ 3 件**（直書き 1 / 台帳に無い 2）・**🔴 死亡 0**。🟡 間欠は gomander の `precure.ml/common.json` 1/144 と
  zugoga の `annict/episodes` 1/144 だけ（前回は gomander で 6 本）。再生成を chubo2 へコミット済み

#### Sentry

- unresolved **31 件**（前回 30）。**コメント 0 が 1 件**あったので、裏を取って判断を書いた（コメント 0 は 0 件に戻した）
  - `-34`（count=6・firstSeen = lastSeen = 10-10T03:51:37Z・vulcan・5.39.0）: Sidekiq が Redis に接続拒否。
    **10-10 12:51:35 JST に vulcan で `misskey` ユーザーが手で `apt upgrade` を実行し、`redis-server` が
    `5:8.0.5-1` → `5:8.0.5-1ubuntu0.1` に上がって約 1 秒再起動した**（`/var/log/apt/history.log` と journal で確認）。
    モロヘイヤの 3 サービスは再起動しておらず、以後の発生なし。一過性・対応不要
- `-2X` は count=581（前回 579）・`-2Y` は count=34（前回 33）。10-10 に zugoga（5.39.0）で 3 件だけ＝平常の範囲。ほかは変化なし

### 2026-10-10 セッション同期の記録

**本番には触っていない**（辞書台帳の生成で本番 4 台へ SSH した読み取りのみ）。土曜に実施。
chubo2 の Issue 棚卸しは 10-02 実施なのでスキップ。

- **ブランチ**: `develop` は `origin/develop` と同一・未コミット無し。CI は `7019d715` で `success`（両系）
- **Dependabot**: open アラート **0 件**
- **open PR**: #4798（5.40.0 のリリース PR・draft）だけ
- **Codex / 申し送り**: 直近マージ 5 本（#4797 / #4799 / #4800 / #4802 / #4803）と open 1 本の行コメント・PR 本体コメントとも**未消化ゼロ**
- **5.40.0**: open 14 件 / closed 7 件（10-06 に #4743 / #4737 / #4792 が閉じたぶんだけ動いた）。マイルストーンの無い open Issue は on-hold の 8 件だけ
- **chubo2**: `origin/main` と同一。`infra-note.md` の変更なし。open 24 件（前回 25・10-07 に #267 / #268 / #269 が閉じた・新規なし）
- **ginseng-\* のピン**: 🆕 **新しいタグが 2 本**。
  - **core v2.2.0**（10-07）: こちらが依頼した 2 件が入った。**pooza/ginseng-core#672**（`http.head(uri, quiet_statuses: [403, 405])`
    ＝ #4793 の待ち先）と **pooza/ginseng-core#673 の 1**（`stop` が身元を見る・たたき台 #674 は 10-07 にマージ）。
    **#4784 の宛先は v2.1.0 → v2.2.0 に変わる**（② 5.40.0 で取り込む・#4784 にコメント済み）。
    ⚠ **上げたら `DaemonIdentityMethods` の `run_stop` の上書きを外す**／**#4793 は #4784 の後に着手できる**（`waiting:pr` の待ちは解けた）
  - **style v1.1.14**（rubocop-minitest 0.41.0）。固定中は v1.1.12 の SHA。② 5.40.0 のどこかで上げる（lint の指摘が増えうるので単独で）
  - 既知のまま: fediverse v4.0.0 ＝ #4748 / piefed v0.3.0 ＝ #4784 の後 / youtube v3.0.2（③ 見送り）
- **harness upstream**: `last_checked` 10-06 から 4 日。Mastodon **v4.7.3** / Misskey **2026.10.0** とも verified と同じで、新しい RC も無い。`last_checked` だけ更新した
- **Annict の API**: 基準（2026-10-06）と同じ。`rails/app/graphql` の直近は 2026-01-28、Go 側に API らしきディレクトリなし
- **辞書台帳**: **🔴 は前回と同じ 3 件**（直書き 1 / 台帳に無い 2）・**🔴 死亡 0**。
  🟢 **`annict/episodes` は 3 機とも 0/144 に戻った**（前回 gomander 26 / zugoga 29 / vulcan 39）。
  gomander の `precure.json` が 2 → 8/144（#4659 の既知の間欠の範囲）

#### Sentry

- unresolved **30 件**（前回 28）。**コメント 0 が 2 件**あったので、最新イベントを開いて判断を書いた（コメント 0 は 0 件に戻した）
  - `-32`（count=1・10-06T04:29:41Z・gomander・5.39.0）: 番組表の「話数 ＋」で Annict が ReadTimeout。画面は `failed` の警告で +1 は進む（#4765 の仕様どおり）
  - `-33`（count=1・10-06T04:29:54Z・gomander・5.39.0）: その 13 秒後、`GET /program/works/:id/episodes` で同じ ReadTimeout。
    どちらも `-2X` と同じ Annict の応答遅延で、入口の行が違うので割れただけ
- 🟢 **`-2X` は count=579 / lastSeen 10-09T21:19Z（前回 447 → +132）だが、密度は 10-06 のうちに平常へ戻った。**
  日別は 10-05 180 → 10-06 108 → **10-07 1 → 10-08 0 → 10-09 1**。`-2Y` も count=33（前回 27）で 10-07 以降 0 件
  - ⚠⚠ **本番は 5.39.0 のまま（PR #4803 は未出荷）なので、この減少は Annict 側の回復であって #4801 の修正の効果ではない。**
    #4801 を閉じる条件に置いた「本番に出てから件数が下がることを確かめる」は、**下がった状態から始まるので判定に使えない。**
    次に Annict が遅くなったときに鳴らないことで確かめる（閉じ方はユーザーに確認する）。判断は `-2X` / `-2Y` にコメント済み
- `-1X` / `-30` / `-31` は変化なし

- 🆕 **10-04〜06 のタイムアウトの原因は、Annict への海外からの大量リクエストだった**（同日・ユーザーが公式アカウントの投稿で確認）。
  [`@annict@mastodon.social` の 2026-10-06 19:21 JST の投稿](https://mastodon.social/@annict/117393463446972710):
  「海外からのリクエストが大量に来ていた影響で、しばらく Annict に繋がりにくい状態になっていました。妙なリクエストを拒否するなどの対応をした」。
  `-2X` の密度が 10-06 のうちに戻ったのと時刻が合う
  - **#4801 は再発を待たない**（ユーザー「中断でも良いかも」）。修正（PR #4803）は入っているので、5.40.0 の出荷で閉じる
  - **同期手順 §6-4 に公式アカウントの確認を足した**（ユーザー提案）。`annict_api_watch.rb` が直近 5 件を出す

### 2026-10-06 セッション同期の記録

**本番には触っていない**（辞書台帳の生成で本番 4 台へ SSH した読み取りと、公開エンドポイントへの GET のみ）。火曜 05 時台 JST に実施。
chubo2 の Issue 棚卸しは 10-02 実施なのでスキップ。

- **ブランチ**: `develop` は `origin/develop` と同一・未コミット無し。CI は `194af6d1` で `success`
- **Dependabot**: open アラート **0 件**
- **open PR**: 3 本。**#4799（#4743）/ #4800（#4737・v4 向け）はマージ待ちのまま**（どちらも `MERGEABLE` / `CLEAN`・CI SUCCESS・Codex 👍）。
  #4798 は 5.40.0 のリリース PR（draft）
- **Codex / 申し送り**: 直近マージ 15 本（#4776〜#4797）と open 3 本の行コメント・PR 本体コメントとも**未消化ゼロ**
- **5.40.0**: open 15 件（前回から増減なし）。マイルストーンの無い open Issue は on-hold の 8 件だけ
- **chubo2**: `origin/main` と同一。`infra-note.md` の変更なし。open 25 件（前回と同じ・新規なし）
- **ginseng-\* のピン**: **前回から新しいタグは無い。**ずれは既知の 5 本のまま
  （core v2.1.0 ＝ #4784 / fediverse v4.0.0 ＝ #4748 / piefed v0.3.0 ＝ #4784 の後 / youtube v3.0.2 / style v1.1.13）
- **pooza/ginseng-core#672**（#4793 の待ち先）: open のまま・PR なし（最終更新 10-04）
- **harness upstream**: `last_checked` 10-02 から 4 日。Mastodon **v4.7.3** / Misskey **2026.10.0** とも verified と同じで、新しい RC も無い。`last_checked` だけ更新した
- **辞書台帳**（chubo2 `5738935`）: **🔴 は前回と同じ 3 件**（直書き 1 / 台帳に無い 2）・**🔴 死亡 0**。
  🟡 **`annict/episodes` がさらに増えた**（gomander 18 → 26/144・zugoga 25 → 29/144・vulcan 30 → 39/144）＝下の Sentry `-2X`

#### Sentry

- unresolved **28 件**（前回と同じ・新種なし）。コメント 0 は **0 件**
- 🟡 **`-2X` が count=447 / lastSeen 10-05T20:45Z（前回 339 → +108）。密度は戻っていない。**
  日別は 10-03 17 → 10-04 112 → 10-05 158（20 時 UTC まで）。1 時間 4〜15 件が約 44 時間続いている
  （zugoga 252 / gomander 167 / 他者サーバー 28）。入口は変わらず `GET /tagging/dic/annict/episodes` → `AnnictService#works`（5 秒でタイムアウト）
  - ⚠ **05:48 JST に本番 2 台の同エンドポイントを 3 回ずつ叩くと、6 回中 4 回が 5 秒で 502。**成功した 2 回も 2.4 / 3.2 秒
    （前回 10-05 17:20 JST は 3 回とも 1.4〜2.2 秒で 200）
  - `-2Y` は count=27（前回 20 → +7・他者サーバー 18 / zugoga 7 / gomander 2）
  - ⚠ 退行とは見ていない（5.37.1 のままの他者サーバーでも増えている）が、**Annict 側の応答時間そのものは未計測のまま。**
    前回の「数日たっても密度が戻らなければ見直す」に近づいたので、扱いをユーザーに確認する。判断は `-2X` / `-2Y` にコメント済み
  - ✅ **同日に #4801 として起票した（5.40.0）。**アラートは Sentry とメール / Slack / LINE を同じ 1 回で出すので、
    ユーザーに届いている「HTTP タイムアウトのメール」は、モロヘイヤ発のものに限ればこの件
- `-1X` は count=103 / lastSeen 10-02T05:18Z で変化なし。`-30` / `-31` も count=1 のまま

- 🆕 **同期手順に §6-4「Annict の API の動きを見る」を足した**（同日・ユーザー承認）。Annict は Rails → Go の書き直し中
  （annict/annict・2026 年は 9 月末までに 963 コミット）で、GraphQL は後回し。基準は `rails/app/graphql` の直近が
  2026-01-28、Go 側に API らしきディレクトリなし。#3157 に 2018 年の記録テーブルの作り替えの経緯を追記した（保留のまま）。
  ⚠ **向こうへ要望・報告を出すことは提案しない**（ユーザー判断）

### 2026-10-05 セッション同期の記録

**本番には触っていない**（辞書台帳の生成で本番 4 台へ SSH した読み取りと、公開エンドポイントへの GET のみ）。月曜 17 時台 JST に実施。
harness upstream は `last_checked` 10-02 から 3 日、chubo2 の Issue 棚卸しは 10-02 実施なので、どちらもスキップ。

- **ブランチ**: `develop` は `origin/develop` と同一・未コミット無し。CI は `a4973926` で `success`
- **Dependabot**: open アラート **0 件**
- **open PR**: なし
- **Codex / 申し送り**: 直近マージ 5 本（#4785〜#4788 / #4795）の行コメント・PR 本体コメントとも**未消化ゼロ**
- **5.40.0**: open 14 件。🆕 **マイルストーンの無い Issue が 2 件**（どちらも 10-03 に `ginseng-*` の当番が起票・on-hold ではない）:
  **#4791**（ginseng-fediverse v2.0.5・security: 他サーバーの連合なしの投稿が「公開」として本文つきでクリップされる）/
  **#4790**（`RemoteHost` の予約レンジの漏れ: 文書用レンジ・6to4 / Teredo・site-local）。版はユーザーに確認する
- **chubo2**: `origin/main` から 1 本取り込んだ（`09d32e5`・capsicum-relay の手順書から行頭 `cd` を外す）。`infra-note.md` の変更なし。
  open 25 件（前回 26）。🆕 **#267**（手順書の行頭 `cd` が capsicum 側のフックで貼れない）。モロヘイヤの実装には非関係
- **ginseng-\* のピン**: 🆕 **新しいタグが 4 本**。
  - **fediverse v2.0.5**（2.0.x の security・差分は `public?` の 1 件だけ・core 1.25.1 のままで動く）＝ #4791。最新は **v4.0.0**（core 2.x が必須）なので、**#4748 の宛先は v3.1.0 → v4.0.0 に変わる**
  - **web v3.0.4**（security: `PublicHost` を core 2.1.0 と同じ規則に・`resolv >= 0.7.2` の床。core 1.25.1 のままで動く）＝ #4790 のコメント
  - **core v2.1.0**（`Ginseng::PublicHost` の新設・`resolv` の床）。**#4784 の宛先は v2.0.0 → v2.1.0 に変わる**
  - **piefed v0.3.0**（security: PieFed 宛の要求がリダイレクトを追わない）。⚠ **core >= 2.0.0 が必須**なので #4784 の後
  - 既知のまま: youtube v3.0.2 / style v1.1.13
  - ⚠ `ginseng_pin_drift.rb` は最新タグしか出さないので、**2.0.x のバックポート（v2.0.5）はスクリプトの出力からは読めない**（Issue で知った）
  - 判断はユーザーに確認する（案: core を上げずに済む fediverse v2.0.5 と web v3.0.4 を先に取り込み、残りは #4784 の後）
  - ✅ **同日に 2 本を取り込んだ**（ユーザー承認）: **PR #4796**（fediverse v2.0.5・`db27f3a6`・#4791 をクローズ）/ **PR #4797**（web v3.0.4・`ad053703`）。
    どちらも gem 単位で上げ、`rake lint` 無指摘・`rake test` 1548 tests / 0 failures / 0 errors。CI 両系 SUCCESS・Codex 指摘なし（👍）
  - ⚠ **web v3.0.4 の予約レンジの修正はモロヘイヤに届かない。**`RSS20FeedRenderer#fetch_image` は gem の実装を上書きして
    `RemoteHost.unpinned_validator` を渡す（#4749）ので、gem の `PublicHost` を通る経路が無い。**#4790 は open のまま**
    （5.40.0・#4784 の後で扱う＝ユーザー判断）
  - #4790 / #4791 は 5.40.0 に割り当てた
- **pooza/ginseng-core#672**（#4793 の待ち先）: open のまま・PR なし
- **辞書台帳**（chubo2 `08005c0`）: **🔴 は前回と同じ 3 件**（直書き 1 / 台帳に無い 2）・**🔴 死亡 0**。
  🟡 **`annict/episodes` が 3 機とも増えた**（gomander 18/144・zugoga 25/144・vulcan 30/144。前回は 0〜1/144）＝下の Sentry `-2X` と同じ事象。
  gomander の `dic.json` は 33/144 → 3/144 に下がった。
  ⚠ 1 回目の生成では `mstdn.b-shock.org/api/dic/v1/common.json` の探査が 404（text/html）だった。直後に 3 回叩いて 3 回とも 200 / JSON だったので生成し直した（GAS の一過性）

#### Sentry

- unresolved **28 件**（前回 25）。**コメント 0 が 3 件**あったので、最新イベントを開いて判断を書いた（コメント 0 は 0 件に戻した）
  - `-2Z`（count=1・10-03T22:15Z・shallu・5.38.1）: 10-04 朝の OS 再起動の最中に Redis へ繋げなかった 1 件。同じ分に `-2F` / `-2Q` も 1 件ずつ。一過性
  - `-30`（count=1・10-04T11:02Z・gomander・5.39.0）: Annict のタイムアウト。入口の行が違うので `-2X` から割れただけ
  - `-31`（count=1・10-04T22:48Z・shallu・5.39.0）: webhook の POST で上流（Mastodon）が 422。`GatewayError` になるので `throttled_alert` で Sentry へ出る。
    5.38.0 のレビューで記録のみとした既知の形（#4764）。単発のあいだは対応しない
- 🟡 **`-2X` が count=339 / lastSeen 10-05T08:15Z（前回 162 → +177）。**10-03 までは 1 時間 0〜2 件、**10-04 01 時台 UTC から 1 時間 2〜11 件が 31 時間続いている**
  （zugoga 108 / gomander 68 / 他者サーバー 3）。入口は全件 `GET /tagging/dic/annict/episodes` → `AnnictService#works`（5 秒でタイムアウト）。
  `-2Y` も count=20（前回 7 → +13・他者サーバー 8 / zugoga 5）
  - ⚠ **5.39.0 の本番デプロイ（10-04 01:07〜01:16 UTC）と時期が重なるが、退行とは見ていない。**① 5.37.1 のままの他者サーバーも同じ期間に 11 件出ている
    （それ以前は `-2Y` 全体で 7 件）② 件数が段差でなく波（10〜11 時台に 11 件・13 時台に 1 件）③ 5.38.1 → 5.39.0 でこの経路のコードとタイムアウト設定は変わっていない
    （ginseng-core v1.23.7 → v1.25.1 の HTTP の変更は 429 の待ち時間だけ）
  - 17:20 JST ごろに本番 2 台の同エンドポイントを 3 回ずつ叩くと 1.4〜2.2 秒で 200
  - ⚠ **Annict 側の応答時間そのものは測っていないので「外部要因」は推定。**数日たっても密度が戻らなければ見直す。判断は `-2X` / `-2Y` にコメント済み
- `-1X` は count=103 / lastSeen 10-02T05:18Z で変化なし

### 2026-10-03 セッション同期の記録

**本番には触っていない**（辞書台帳の生成で本番 4 台へ SSH した読み取りのみ）。土曜 18:54 JST に実施。harness upstream は `last_checked` 10-02 から 1 日なのでスキップ。

- **ブランチ**: `develop` は `origin/develop` と同一・未コミット無し。**CI は直近とも `success`**
- **Dependabot**: open アラート **0 件**
- **open PR**: リリース PR #4788（draft・`MERGEABLE` / `CLEAN`・CI 両系 SUCCESS）のみ
- **Codex / 申し送り**: 前回以降のマージは **0 本**。直近マージ 13 本＋ #4788 の行コメント・PR 本体コメントとも**未消化ゼロ**
- **5.39.0**: open は前回と同じ 7 件（モンキーテスト待ち 6 件＝ #4725 / #4747 / #4749 / #4769 / #4771 / #4775 ＋ #4352）。新しい Issue なし。
  📌 **#4352 の残りは 10-04（日）のニチアサ明けの見直し**。5.40.0 は 3 件（#4748 / #4784 / #4789）
- **chubo2**: `origin/main` と差分なし。open **26 件**（前回 27）。🆕 **#265**（kues を Ubuntu 26.04 へ上げるか・前回の棚卸しで #211 から切り出した分）。
  モロヘイヤの実装には非関係。Issue 棚卸しは 10-02 実施済み
- **ginseng-\* のピン**: 新しいタグなし。ずれは既知の 4 本のみ（core v2.0.0 ＝ #4784 / fediverse v3.1.4 ＝ #4748 / youtube v3.0.2 / style v1.1.13）
- **辞書台帳**（chubo2 `d3492b4`）: **🔴 は前回と同じ 3 件**（直書き 1 / 台帳に無い 2）・**🔴 死亡 0**。
  🟡 `annict/episodes` は 3 機とも 18〜19/144 → **0〜1/144 に下がった**。一方 gomander の `precure.ml/api/dic/v1/dic.json` が **8/144 → 33/144**
  （09-28 の 30/144 と同水準・#4659 の間欠の範囲と読む）。
  ⚠ 1 回目の実行は `timeout 240` で書き込み前に切れた（出力が `resolve` の行だけ・差分なし）。**`wrote …` の行が出たかを見る**

#### on-hold 以外の Issue をすべてマイルストーンへ割り当てた（同日・ユーザー指示）

「残っている issue で on-hold 外は、ぜんぶマイルストーンを設定したい」。未設定は 25 件・重み 82（L×5 / M×12 / S×6）で、
**テーマ別に 4 回へ分けた**（ユーザー選択）。5.41.0〜5.43.0 は新設。★ は機能が前へ進む枠。

| マイルストーン | 足した Issue | 重み |
| --- | --- | ---: |
| **5.40.0**（既存: #4748 / #4784 / ★ #4789） | S: #4612 / #4742 / #4699 / #4737 / #4734 / #4743、M: #4600 / #4726 | 既存と合わせて約 19 |
| **5.41.0** タグ辞書 | L: ★ #4465、M: #4756 / #4690 / #4628 / #4678 / #4700 | 23 |
| **5.42.0** media_catalog の残り | L: ★ #4375 / #4323、M: #4353 / #4695 | 22 |
| **5.43.0** Akkoma と大物 | L: ★ #4566 / #4233、M: #4685 / #4722 / #4677 | 25 |

- 未設定で残るのは on-hold の 8 件だけ（#3157 / #3877 / #4195 / #4196 / #4197 / #4229 / #4298 / #4301）
- 🎯 **狙いは「大玉がいつまでも残る構造」の対策**（ユーザー）。未設定の棚から古い順・size:L を避けて選ぶ回が続くと、L は毎回残る。
  行き先の版が決まっていれば順番が来る
- ⚠ **今後、新しく起票する Issue にも起票の時点で版を付ける**（同日ユーザー承認）。どの版かは案を添えて確認する。on-hold で起票するものは対象外。
  同期（§7）で on-hold でないのに版が無い Issue を見つけたら報告する
- ⚠ 5.40.0 の既存 3 件のうち #4748 / #4784 / #4789 はサイズラベルが無い（重みは概算）
- ⚠ #4353 は B 案が index 非依存で決着したので前提が変わっている。#4323（メタ）とあわせて 5.42.0 の着手時に実体を確かめる

#### Sentry

- unresolved **25 件**（前回と同じ）・**コメント 0 は 0 件**
- `-2X` は **count=162 / lastSeen 10-03T07:42Z**（前回 146 → +16）。zugoga / gomander のみ。10-02 の 09〜17 時台 UTC に 13 件が寄り、
  10-03 は 2 件＝再び平常の密度。判断は据え置き＝ Annict 側の遅延による外部ノイズ。コメント済み。`-2Y` は count=7 で変化なし（足して 169）
- `-1X` は **count=103 / lastSeen 10-02T05:18Z**（前回 102 → +1）。増えた 1 件は `server_name=mulukhiya` ＝他者サーバー（5.37.1）。
  本番側の最新は 09-19 の zugoga（#4728・5.38.0 で修正済み）のまま。コメント済み

### 2026-10-02 セッション同期の記録

**本番には触っていない**（辞書台帳の生成で本番 4 台へ SSH した読み取りのみ）。

- **ブランチ**: `develop` は `origin/develop` と同一・未コミット無し
- **Dependabot**: open アラート **0 件**
- **open PR**: リリース PR #4788（draft）のみ
- **Codex / 申し送り**: 前回以降のマージは **0 本**。直近マージ分の Codex 指摘は全件「返信＋ +1」済み。PR 本体への申し送りも無し
- **5.39.0**: open は前回の振り分けどおり 6 件＋ #4352。**#4352 の 24 時間観測は両台とも問題なし**（上の #4352 の項）。
  🆕 **#4789（media_catalog の既定を true に戻す）を 5.40.0 に起票済み**（10-01・前回同期の後）
- **chubo2**: `origin/main` と差分なし。🆕 **#262**（ボットアカウント作成〜 webhook URL 発行の引き受け）・**#263**（UTM が RustDesk を遮断している疑い）。
  どちらもモロヘイヤの実装には非関係。open 27 件。
  ⚠ **Issue 棚卸しは最終 08-31 から 32 日＝期限切れ**（§6-2）
- **ginseng-\* のピン**: 新しいタグなし。ずれは既知の 4 本のみ（core v2.0.0 ＝ #4784 / fediverse v3.1.4 ＝ #4748 / youtube v3.0.2 / style v1.1.13）
- **辞書台帳**（chubo2 `ade4a21`）: **🔴 は前回と同じ 3 件**（直書き 1 / 台帳に無い 2）・**🔴 死亡 0**。
  🟡 `annict/episodes` が 3 機とも 18〜19/144 にやや増えた（下の Annict 遅延と同時期）。gomander `precure.json` の 23/144 は消えた
- **harness upstream**（`last_checked` 09-28 から 4 日）: 🔴 **新しい版が 2 つ**。
  **Mastodon v4.7.3**（10-01・Security: 依存更新・アセット再コンパイル要・verified は v4.7.2）と
  **Misskey 2026.10.0**（10-01・「セキュリティに関する修正」・HTTP Signatures の `(request-target)` にクエリ文字列を含める修正・verified は 2026.9.1）。
  どちらもセキュリティを含むリリースなので harness 検証を促した
  - ✅ **Mastodon v4.7.3 を同日中に実走して `verified` へ昇格した**（develop `6fb5092a`・1613 tests・0 failures / 0 errors・159 omissions ＝ v4.7.2 と同数。
    chubo2 `2f6b45a`・実走後に teardown 済み）
  - ✅ **Misskey 2026.10.0 も実走して `verified` へ昇格した**（pooza/misskey #457 でマージ済み・本番デプロイ前。develop `f490b091`・1616 tests・0 failures / 0 errors・145 omissions ＝ 2026.9.1 と同数。
    chubo2 `2bdbc8a`）。⚠ harness は upstream イメージなので fork 固有の差分は検証範囲外

#### chubo2 の Issue 棚卸し（§6-2・同日に実施・chubo2 `200e217`）

- open 27 件を本文・コメント・chubo2 / chubo-core の main・実機（読み取りのみ）と突き合わせた。**完全に終わっている／対象が消滅しているものは 0 件**
- 判断をユーザーに残したもの 2 件:
  **#211**（kues の構成記述）は本題が済み、残りは「26.04 への in-place upgrade の検討」だけ（kues は 24.04.5・サポートは 2029-04 まで）→ 残りを切り出して閉じる候補。
  **#121**（全ノードのドリフト棚卸し）は完了条件をほぼ満たすが、未分類 133 件の受け皿を兼ねる → 閉じるか残すか
- 残り 25 件は生きている（#261 のリモート投稿削除は進行中・shallu 10/2・gomander 10/5 の予定 など）

#### Sentry

- unresolved **25 件**（前回と同じ）・**コメント 0 は 0 件**
- `-2X` は **count=146 / lastSeen 10-01T19:32Z**（前回 126 → +20）。うち 14 件は 10-01 00 時台 UTC（前回記録の集中の続き）、
  03 時台以降は 1 時間に 0〜1 件で**平常の密度へ戻った**。判断は据え置き＝ Annict 側の遅延による外部ノイズ。コメント済み。`-2Y` は count=7 で変化なし

### 2026-10-01 セッション同期の記録

**本番には触っていない**（辞書台帳の生成で本番 4 台へ SSH した読み取りのみ）。harness upstream は `last_checked` 09-28 から 3 日なのでスキップ。

- **ブランチ**: `develop` は `origin/develop` と同一・未コミット無し。**CI は直近とも `success`**
- **Dependabot**: open アラート **0 件**
- **open PR**: 前回の記録どおり＋ 🆕 **#4787（dependabot・icalendar 2.12.4 → 2.12.5・MERGEABLE）**
- **Codex / 申し送り**: 前回以降のマージは **0 本**。PR #4782 の P2 は返信＋ +1 で完了。
  🆕 **PR #4786 に Codex の P2 が 1 件、未返信**（09-29T10:59Z）: `/release` が必須の `/release-review` を呼べない
  （`disable-model-invocation: true` なので Skill ツールから起動できず、手順が止まるかレビューを飛ばす）。
  → **「明示的に止める」で対処（ユーザー判断・`9145f121`）**。`/release` の手順 2 で必ず止まり、ユーザーに `/release-review` を頼む。返信＋ +1 済み
- **chubo2**: `origin/main` と差分なし。🆕 **#261（Mastodon 3 台で古いリモート投稿を削除し、ハッシュタグリレーを戻す）**。
  モロヘイヤの実装には非関係（`tootctl` の改修は pooza/mastodon#977）
- **ginseng-\* のピン**: 前回から**新しいタグなし**（core v2.0.0 / fediverse v3.1.4 / piefed v0.2.0 / redis v2.0.8 / web v3.0.3 /
  youtube v3.0.2 / style v1.1.13）。各 PR・Issue の宛先は前回の判断どおり
- **辞書台帳**（chubo2 `ee61bd7`）: **🔴 は前回と同じ 3 件**（直書き 1 / 台帳に無い 2）・**🔴 死亡 0**。
  🟡 が広がった（gomander `precure.json` 23/144・`annict/episodes` 16/144、vulcan `annict/episodes` 14/144・`service.json` 11/144）。
  `annict/episodes` は下の Annict 遅延と同時期
- **#4352 の 24 時間観測は 10-01 11:45（shallu）/ 11:53（gomander）まで**。同期時点（09:11）では未了。日曜（10-04）明けに見直す予定は据え置き

#### ✅ 同日中に着地: open PR 13 本をマージ（`87eaa900`）

- #4768 / #4776 / #4782 / #4785 / #4783 / #4774 / #4778 / #4779 / #4781 / #4787 / #4786 / #4777 / #4780。**open PR は 0**
- **#4777 は #4768 と衝突**（#4768 が `handle_gateway_error` を `ControllerErrorMethods` へ移していた）→ `relay_upstream_headers` の呼び出しを移動先へ、
  `upstream_error_code` は `UpstreamErrorMethods` の 1 本に寄せた（`16f31bb6`）。**#4780 は Gemfile が衝突** → redis v2.0.8 を採り web だけ v3.0.3 で lock を作り直した（`6dca27ec`）
- develop: `rake lint` 無指摘・`rake test` **1541 tests・0 failures・0 errors**・CI `success`
- **ステージング 4 台を develop（`87eaa900`）へ戻した**: Ruby 4.0.7 で `bundle install` → sidekiq → puma → listener。4 台とも version 5.39.0 / health 200
- **Issue の振り分け（モンキーテスト可否）**: クローズ 10 件＝ #4750 / #4746 / #4745 / #4731 / #4724 / #4723 / #4721 / #4698 / #4697 / #4635（理由はクローズコメント）。📌 **open に残してテスト観点メモを付けた 6 件**＝ #4775（dev26 で 429）/ #4771（dev25 の「話数 ＋」）/ #4769（dev24 の artwork_url）/ #4749（dev26 のフィード）/ #4747（サービスの stop / start / restart）/ #4725（404 の Content-Type）。5.39.0 の残りはこの 6 件＋ #4352（観測中）

#### Sentry

- unresolved **25 件**（前回 26）・**コメント 0 は 0 件**
- 🔴 **`-2X` が count=126 / lastSeen 10-01T00:10:29Z**（前回 61 → +65）。**JST 10-01 06:00〜09:00 の 3 時間で 44 件**に集中。
  zugoga / gomander / 他者（instance-20220704-2044・5.37.1）の 3 機で同時に、全件 `AnnictService#query` の ReadTimeout。
  **他者の機体でも同時刻に増えているので Annict 側の応答遅延**と読む。判断は据え置き＝外部ノイズ。`-2Y`（count=7・他者 +2）も同じ。
  両方にコメント済み。📌 **次の同期で密度が平常（1 日数件）へ戻ったかを見る**

### 2026-09-29 セッション同期の記録

**本番には触っていない**（vulcan のログを読んだだけ）。辞書台帳・harness upstream は前回（09-28）から 1 日なので回していない。

- **ブランチ**: `develop` は `origin/develop` と同一・未コミット無し。**CI は直近とも `success`**
- **Dependabot**: open アラート **0 件**
- **open PR**: #4768 / #4774 / #4776〜#4782（前回の記録どおり）＋ 🆕 **#4783（Ruby 4.0.7 へ追従・pooza/ginseng-style#114 の配布分）**。
  `.ruby-version` だけの変更で CI 緑。サーバー側には 4.0.7 を追加済み（pooza/chubo2#259）。デプロイ時に `bundle install` が要る
- **Codex / 申し送り**: 前回以降のマージは **0 本**。⚠ **PR #4782 に Codex の P2 が 1 件、未対処**
  （Spotify の画像で `width` が null のものがフォールバックで落ちる）。09-28 の記録を書いた直後に付いた
- **chubo2**: `origin/main` と差分なし。新 Issue なし
- **vulcan は 09-29 05:45 JST に再起動している**（`uptime` 5:09）。モロヘイヤへの影響はログ上は見ていない

#### ginseng-\* の新しいタグ（2026-09-29 の同期）

⚠ **判断はユーザー待ち。宛先はまだ差し替えていない:**

- **core v2.0.0**（09-28 21:51Z・**破壊的変更**）: Slack / LINE がリダイレクトを追わない・`host_validator` 付きが
  `follow_redirects: false` を尊重・`Daemon#save_config` が `tmp/cache` の symlink / 不在で `ConfigError`。
  #4747（PR #4778）の宛先は v1.25.1 のまま
- **piefed v0.2.0**（09-28 21:33Z）: `Service#clip` が非公開で `RequestError` を上げず `nil` を返す（pooza/ginseng-piefed#18 の着地）。
  **PR #4781 の「後半」の前提がこれ**（`PiefedClippingWorker` は戻り値の `nil` を「弾かれた」と扱う必要がある）

#### Sentry

- unresolved **26 件**。**`-2X` は count=61 / lastSeen 09-29T01:00:29Z**（前回 49 → +12）。内訳は zugoga / gomander / 他者で、
  **vulcan は 0**。判断は据え置き＝外部ノイズ

#### 📣 ダイスキーの「モロヘイヤ重い」（2026-09-28 22:36 JST・misskey.delmulin.com/notes/arouuogqya）

**モロヘイヤ側の処理は全部速かった。**vulcan の mulukhiya-toot-proxy.log と nginx のアクセスログで、この人の IP を追った:

| 時刻（JST） | 操作 | モロヘイヤ内の所要 |
|---|---|---|
| 22:29:52 | `/mulukhiya/app/status/aroul0c8xl`（タグづけ画面）を開く | 約 0.03 秒 |
| 22:30:20 / :30 / :41 | Misskey のクライアントが丸ごと読み直される（`sw.js`・同じ画像群を 3 回） | ―（モロヘイヤを通らない） |
| 22:30:29 | `notes/delete`（元ノート）＝**削除して編集** | ―（モロヘイヤを通らない） |
| 22:30:51 | `notes/drafts/create`（`scheduledAt` = 22:31:00・`isActuallyScheduled`） | 約 0.23 秒（Misskey 0.023 秒） |
| 22:31:00 | リプ元 `arounzp3wq` を **Misskey のキュー（`PostScheduledNoteProcessorService`）が投稿** | ―（HTTP を経ない） |
| 22:33:12 / 22:36:11 | 返信 2 本の `notes/create` | 約 0.27 秒ずつ |

- リプ元の本文は **22:30:51 の `drafts/create` でモロヘイヤを通っている**（pre_toot はここで掛かる）。
  22:31:00 の実投稿は Misskey 内部の予約投稿ジョブなので、**モロヘイヤのログに `notes/create` が無いのは正常**
- 同時間帯の 1 秒超はタグ辞書・読み辞書の更新（sidekiq・10 分おき）だけで、投稿の経路ではない。puma の遅延・エラーなし
- **体感の重さの候補**: タグづけ画面（`/mulukhiya/app/...`）は Misskey の SPA の外なので、**行って戻ると Misskey のクライアントが
  丸ごと読み直される**（22:30 台に 3 回）。サーバー側の遅さではない
- **Misskey 側も追ったが原因なし → 一時的なものとして打ち切り**（ユーザー判断）。misskey.log の 22:29〜22:31 に遅延・タイムアウトなし、
  ERR は定常のもの（削除済みアクターの Delete・削除直後の `aroul0c8xl` への Announce）だけ
- 📌 **手がかりとして残す（因果は不明）**: 22:30:52〜57 に `/proxy/preview.webp` が 4 回 403。
  `Refusing to proxy a request from another proxy` で、**プロキシ済みのアバター URL（`/proxy/avatar.webp?url=...`）を
  さらにプレビュー用プロキシへ渡していた**＝Misskey の仕様どおりの拒否。下書き保存の直後に出ている。
  `files/null/` はオブジェクトストレージの既定のパスで、直接の取得は当日 13 件とも 200

### 2026-09-28 セッション同期の記録

**本番には触っていない**（辞書台帳の生成と、shallu の Redis の uptime・ログを読んだだけ）。

- **ブランチ**: `develop` は `origin/develop` と同一・未コミット無し。**CI は直近 6 本とも `success`**
- **Dependabot**: open アラート **0 件**
- **open PR**: #4774（main → develop の戻し・5.38.1 の `resolv`）と #4768（レビュー残件）。**どちらも MERGEABLE でマージ待ち**
- **Codex / 申し送り**: 前回以降のマージは PR #4759 / #4767 / #4770 / #4773。
  修正コミットを確かめて **+1 を 3 件付けた**（#4768 の P2 ×2＝`20683748` / `22b44fda`、#4770 の P1＝`289609a6`）。
  ⚠ **#4770 の P2「MFM のメンション境界を Misskey だけに絞る」は返信で「後退ではない・別途判断」とした未修正のまま**
  （Mastodon のナウプレで `ラブ@pooza` が `ラブ@ pooza` になる。5.37.1 以前はもっと広く区切っていた）。→ **単独では直さず、#4748（v3.1.4 の取り込み）で実測して判断する**（09-28 ユーザー合意・#4748 にコメント済み）
- **chubo2**: `origin/main` と差分なし。§6-2 は 08-31（28 日）でスキップ。新 Issue は #258 / #259 / #260（いずれもモロヘイヤの実装に非関係）
- **harness upstream**: Mastodon v4.7.2 / Misskey 2026.9.1 とも verified と同版。`last_checked` を 09-28 に更新
- **辞書台帳**（chubo2 `4dfae45`）: **🔴 は前回と同じ 3 件**（直書き 1 / 台帳に無い 2）・**🔴 死亡 0**。
  🟡 の最大は gomander の `precure.ml/api/dic/v1/dic.json` **30/144**（前回 16/144）。#4659 の間欠の範囲と読む

#### 📥 pooza/makoto2 からの依頼 2 件（#4775 / #4747）

- **#4747**: 宛先を **v1.25.0 → v1.25.1** に差し替え、タイトルも直した。差は pooza/ginseng-core#657 の 1 commit・3 ファイル
  （タグで確認）。**読んだ効き方**: 429 に `Retry-After` が無ければ `X-RateLimit-Reset` を使うが、
  **`/http/retry/max_seconds`（60 秒）を超える待ちは叩き直さず即座に上げる**。→ 投稿の 3 時間窓では 1 回で諦めて 429 を透過する。
  ⚠ 窓が 60 秒以内なら puma のスレッドを持ったまま最大 60 秒眠るので、#4775 と合わせて 429 を実際に起こして確かめる
- **#4775**: `handle_gateway_error`（`controller.rb`）が上流の 429 のステータスと本文は透過するが、
  `Retry-After` / `X-RateLimit-*` を中継していない。**コードで確認した**（ヘッダを付けているのは `ConflictError` の `Retry-After` だけ）。
  size:S・マイルストーン未割り当て

#### ginseng-\* のピン判断（2026-09-28 の同期）

09-26 に各 gem で新しいタグが出ていた。**判断は宛先の差し替えだけで、マイルストーンは動かさない**:

- **core v1.25.1** → #4747（上）
- **redis v2.0.7 → v2.0.8**（`key?` を EXISTS で引き、キーをパターンとして読まない）→ #4746 の宛先を v2.0.8 に。
  ⚠ モロヘイヤは `metadata_storage.key?(uri)` 等で **`?` を含みうる URI をキーにしている**ので、効く側の修正
- **web v3.0.1 → v3.0.3**（`fetch_image` を既定で公開アドレスだけに・SlimRenderer）→ #4749 の宛先を v3.0.3 に。
  `Rss20FeedRenderer#fetch_image` は上書きしているので、既定の変更がそのまま効くかは取り込み時に確かめる
- **fediverse v3.1.0 → v3.1.4**（`escape_sigils` の境界 3 本・`TagContainer#member?`）→ #4748（5.40.0）の宛先を v3.1.4 に。
  固定中は v2.0.4（PR #4770）
- **youtube v3.0.1 → v3.0.2**（`search_channels` の失敗を GatewayError に）→ ③ 見送り。モロヘイヤは `search_channels` を使っていない

#### Sentry

- unresolved **26 件**・**コメント 0 は 0 件**
- 🆕 **`-2F`（Redis 接続拒否）count=29 と `-C`（`LOADING`）count=38 に、shallu で 09-26T03:02:50Z（JST 12:02）の新イベント。**
  Redis の uptime から再起動は同時刻。**同じ時間帯に pooza/chubo2#251（`4400d01`・12:10）で shallu に `redis` レシピを当てている**ので、
  その適用による再起動と読む。**判断は計画作業の一過性**。両方にコメントを残した
- **`-2X` は count=49 / lastSeen 09-26T06:40:07Z**（前回 48 → +1）。判断は据え置き＝外部ノイズ

### 2026-09-26 セッション同期の記録

**本番には触っていない**（辞書台帳の生成で本番 4 台へ SSH した読み取りのみ）。

- **ブランチ**: `develop` は `origin/develop` と同一・未コミット無し。**CI は直近 6 本とも `success`**
- **Dependabot**: open アラート **0 件**
- **Codex / 申し送り**: 前回以降のマージは **PR #4753 / #4754 / #4757 / #4758 の 4 本**。行コメント・PR 本体コメントとも
  **Codex の指摘なし**。open PR は #4739（draft・`CONFLICTING` ＝上の赤 1 の version 1 行）だけで、新しいコメントなし
- **PR #4752（dependabot の ginseng グループ）は 09-24 にクローズ済み**（宛先ずれの理由をコメント済み）。#4702 もクローズ
- **マイルストーン**: 5.38.0 は **open 2**（#4352 / #4728）＋ draft PR #4739。**#4463 / #4579 は 09-25 に消化済み**で上の表どおり。
  🔴 **次の入口は変わらず「赤 2 件」**（develop へ main を merge ／ fediverse v2.0.1 の無毒化後退はユーザー判断待ち）
- **chubo2**: `origin/main` と差分なし・作業ツリーもクリーン。§6-2 は 08-31（26 日経過）でスキップ、§6-3 は 09-08 実施済み。
  新しい Issue は **chubo2#254**（writersbase-tools v1.7.1 反映）の 1 件でモロヘイヤ非関係。
  ✅ **前回の宿題「`fedi-test-harness/misskey` の着地確認」は `2acc483` で着地済み**（実走・昇格は 09-24 に消化済み）
- **harness upstream**: `last_checked` 09-24（2 日）でスキップ。Mastodon v4.7.2 / Misskey 2026.9.1 とも verified と同版
- **ginseng-\* のピン**: 09-23 の判断から変化なし（新しいタグなし。core v1.25.0 / fediverse v3.1.0 / piefed v0.1.2 /
  redis v2.0.7 / web v3.0.1 / style v1.1.13 がずれとして既知）

#### Sentry

- unresolved **26 件**・**コメント 0 は 0 件**
- **`-2X` は count=48 / lastSeen 09-25T15:10:07Z**（前回 41 → +7）。全件 `AnnictService#query` の ReadTimeout・5.37.1、
  内訳は zugoga / gomander / 他者（`instance-20220704-2044`）。**判断は据え置き＝外部ノイズ**。count の時点つきでコメントを残した
- **`-2Y` は count=5 のまま**（新規なし）、**`-1X` も新規なし**（最新は 09-22T22:38Z）

#### 辞書台帳

- **🔴 は前回と同じ 3 件**（直書き 1 / 台帳に無い 2）。**🔴 死亡は 0**（chubo2 `a9db002`）
- 🟡 の最大は **gomander の `precure.ml/api/dic/v1/dic.json` 16/144** と **zugoga の `mstdn.delmulin.com/api/dic/v1/common.json` 12/144**。
  ⚠ 前回 5/145 まで下がった vulcan の同ソースは 🟢 になったが、**同じ URL が zugoga で上がっている**＝ #4659 の間欠が機を変えて出ているだけと読む
- 実探査で 404 text/html が 4 件・応答なし 1 件（`pronruby.json`）。⚠ **判定はログ主・探査は注記**（#249 以降のツールの設計）で、
  該当ソースのログ上の判定は 🟢 / 🟡 のまま。#4659 の間欠 404 をたまたま踏んだものとして異常と読まない

#### 🔧 ローカル環境: システムの redis-server が 09-23 から落ちている

`Can't open the log file: Permission denied` で起動に失敗し、`disabled`。**`rake test` が 77 errors になる**（Redis 接続拒否）。
このセッションでは scratchpad にユーザー権限の `redis-server` を上げてテストした。⚠ **恒久対処（ログファイルの権限）は sudo が要る**

#### 赤 1 の対処: PR で main を develop へ戻した

ブランチ `fix/merge-main-5.37.1` で `git merge origin/main`。衝突は予告どおり `config/application.yaml` の version 1 行だけで 5.38.0 を採った。
`rake lint` 無指摘 / `rake test` **1441 tests・0 failures・0 errors**。`vips_block` / `blocked_upload_type` の 2 本は
**読み込まれて実行されている**（omit 一覧に出ない）ことを確認した。あわせてホットフィックス手順に 9「develop へ戻す」を足した

### 2026-09-24 セッション同期の記録

**本番には触っていない**（辞書台帳の生成で本番 4 台へ SSH した読み取りのみ）。

- **ブランチ**: `develop` は `origin/develop` と同一・未コミット無し。**CI は直近 6 本とも `success`**
- **Dependabot**: open アラート **0 件**
- **Codex / 申し送り**: 前回以降のマージは **PR #4751 の 1 本**。Codex は「指摘なし」。open PR #4739 / #4752 にも
  新しいコメントは無く、**未消化ゼロ**
- **chubo2**: `origin/main` と差分なし。§6-2 は 08-31（24 日経過）でスキップ、§6-3 は 09-08 実施済み。
  新しいコミットは `3f543e7`（**ダイスキーを Misskey 2026.9.1 へ上げた**）。
  ⚠ 作業ツリーに `fedi-test-harness/misskey` の版を 2026.9.1 へ上げる**未コミット変更**がある＝**別セッションの作業**なので触っていない
- **マイルストーン**: 5.38.0 は **open 4**（#4352 / #4463 / #4579 / #4728）＋ draft PR #4739、5.39.0 に 6 件、5.40.0 に 1 件。前回から変化なし

#### 🆕 Dependabot の ginseng グループ PR #4752 — ⚠ そのままマージしない

`ginseng-core` v1.23.7 → **v1.24.0** / `ginseng-fediverse` v2.0.1 → **v3.0.0** / `ginseng-redis` v2.0.6 → v2.0.7 を
**1 本に束ねた** PR（CI は緑）。推移依存で `net-protocol` 0.3.0 → 0.4.0 / `bigdecimal` 4.1.2 → 4.1.3 も動く。

- ⚠⚠ **09-21 / 09-23 に決めた宛先と食い違う。**core は **v1.25.0（#4747）**、fediverse は **v3.1.0 を 5.40.0（#4748）**、
  redis は #4746（5.39.0）。**版も宛先もずれている**
- ⚠ **§6-1 の「`bundle update <gem>` と gem 単位で」に反する**（3 本まとめると赤が出たときに切り分けられない）
- ⚠ core は**pid ファイルの書き込み方が変わる**ので、ステージングで起動・停止・再起動を通してから出す判断が付いている
  （[[project_latent-landmine-fires-on-next-restart]]）。CI 緑は根拠にならない
- → **閉じるかどうかはユーザー判断**。取り込みは 5.39.0 で gem ごとに行う

#### 辞書台帳: 🔴 は 3 件で変化なし（chubo2 `f461102`）

- **🔴 は前回と同じ 3 件**（直書き 1 / 台帳に無い 2）。**🔴 死亡は 0**
- **vulcan の `mstdn.delmulin.com/api/dic/v1/common.json` は 🟡 33/144 → 5/145 に下がった。**
  ⚠ 前回「次の同期でも率を見る」とした件。**下がったことを「直った」とは読まない**（#4659 の既知の範囲で振れているだけ）
- 他の 🟡 もいずれも 1〜6/144 の範囲で入れ替わっているだけ

#### Sentry

- unresolved **26 件**・**コメント 0 は 0 件**（§5 のスクリプトで確認）
- **`-2X` は count=41 / lastSeen 09-24T10:46:16Z**（前回 37 → +4）、**`-2Y` は count=5 / lastSeen 09-23T17:16:18Z**（前回 4 → +1）。
  **足して 46**。1 日 2 件程度で 09-21〜23 と同じ密度。内訳は zugoga / gomander / 他者（`instance-20220704-2044`）。
  **判断は据え置き＝外部ノイズ**。両方に count の時点つきでコメントを残した
- **`-1X` は新規なし**（最新は 09-22T22:38Z の他者サーバー分のまま）

#### harness upstream

- 🔴 **Misskey 2026.9.1（09-23・stable）が出た。**セキュリティリリースで、**ダイスキーへは 09-24 00:45 に適用済み**
  （harness 未実走）。⚠ **検証は後追い**になる。台帳の `last_checked` を 09-24 に更新した
- 📌 **宿題（2026-09-24 ユーザー指示「終わったらこちらでもテストをしたい。次セッションでも構わない」）**:
  chubo2 側で harness の Misskey 版を 2026.9.1 へ上げる作業が進行中（同期時点で未コミット）。
  ⚠⚠ **次の同期では `cd ~/repos/chubo2 && git log origin/main -- fedi-test-harness/misskey` で着地を確かめ、
  着地していれば harness を 2026.9.1 で建てて `rake test` を実走し、`misskey.verified` を昇格する。**
  未着地なら持ち越し。使い終わったら基本は `stop.sh`（[[project_fedi-test-harness-usage]]）
  - ✅ **同日中に消化。**chubo2 側が 2026.9.1 の harness を建てた時点で実走し、**1488 tests・0 failures・0 errors・
    145 omissions**。`misskey.verified` を 2026.9.1 へ昇格した（詳細は台帳）
- Mastodon は v4.7.2 のまま・新しい RC なし

#### ginseng-* のピン: 09-23 の判断から変化なし

core v1.25.0（#4747・5.39.0）/ fediverse v3.1.0（#4748・5.40.0）/ piefed v0.1.2（#4750・5.39.0）/
redis v2.0.7（#4746・5.39.0）/ web v3.0.1（#4749・5.39.0）/ style v1.1.13（③ 見送り）。**新しいタグは出ていない**

### 2026-09-23 セッション同期の記録

**本番には触っていない**（辞書台帳の生成で本番 4 台へ SSH した読み取りのみ）。

- **ブランチ**: `develop` は `origin/develop` と同一・未コミット無し。**CI は直近 6 本とも `success`**
- **Dependabot**: open アラート **0 件**
- **Codex / 申し送り**: **前回の同期（09-21）以降、マージされた PR は 0 本。**直近マージ 8 本
  （#4744〜#4729）＋ open PR #4739 を再走査したが**新しいコメントは無く、未消化ゼロ**
- **chubo2**: `origin/main` と差分なし。§6-2 の Issue 棚卸しは **08-31（23 日経過・30 日未満）でスキップ**、
  §6-3 のドキュメント棚卸しは 09-08 実施済み
- **harness upstream**: `last_checked` が **09-20（3 日経過・4 日未満）なのでスキップ**
- **マイルストーン**: 5.38.0 は **open 4（Issue ベース）＋ draft PR #4739**（#4543 / #4570 を同日クローズ）、5.39.0 に **6 件**（#4749 / #4750 を同日に追加）、5.40.0 に 1 件

#### 辞書台帳: 🔴 は 3 件で変化なし（chubo2 `9e82981`）

09-21 に直した「直近 24 時間で判定する」形（pooza/chubo2#249）で 2 回目の生成。**母数は 4 台とも
144-145 にそろっており、回ごとに比べられる。**

- **🔴 は前回と同じ 3 件**（直書き 1 ＝ gomander の `script.google.com` 直引き / 台帳に無い 2）。**🔴 死亡は 0**
- ⚠ **前回まで全行に付いていた「(探査 404 text/html)」が今回は 1 つも出なかった。**
  生成時点の GAS がたまたま健常だっただけの**瞬間値**なので、**改善と読まない**（🟡 間欠は継続している）
- ⚠ **vulcan の `mstdn.delmulin.com/api/dic/v1/common.json` だけ 🟡 間欠 33/144（約 23%）。**
  前回 11/144 から上がっている。**同じソースを引く zugoga は 1/144** なので vulcan 側の事情。
  #4659 の既知の範囲だが、次の同期でも率を見る

#### Sentry

- 🔴 **`-2Y` を初回トリアージした。`-2X` と同一現象が別イシューに割れていたもの。**
  title（`Ginseng::GatewayError: Net::ReadTimeout`）も culprit（`Mulukhiya::AnnictService in query`）も同じで、
  count=4 / lastSeen 09-22T20:16:00Z。内訳は `instance-20220704-2044` 1（**他者サーバー**・GCP 既定のホスト名）/
  `zugoga` 1 / `gomander` 2。**判断は `-2X` と同じ＝ Annict 側の応答遅延によるノイズ。**
  ⚠⚠ **件数を見るときは `2X` と `2Y` を足して読む**（[[project_sentry-1x-zugoga-recurrence]] の逆パターン）
- **`-2X` は count=37 / lastSeen 09-22T15:10:01Z。⚠ 09-20 の密度上昇は続かなかった**
  （09-09: 2 → 09-20: 23 → 09-21: 34 → **09-23: 37 ＝ 2 日で 3 件**）。**判断は据え置き**（外部ノイズ・#4543）。
  ⚠ **「増えている」で起票しなかったのが正しかった**が、**減ったことも「解決」と書かない**
- **`-1X` の新規 2 件（09-22T22:30 / 22:38Z）は `server_name=mulukhiya` ＝ 他者サーバー。**
  ⚠ **その機体の release が 5.35.0 → 5.37.1 に上がっている。**本番側の最新は 09-19 の zugoga ＝ #4728 のまま
- **#4543 は群 2 が 8 件 → 7 件**（`2Y` を上の判断で片付けた）。残り 7 件は 07-29 以降の発生が無く、この 2 日も動いていない
- 3 件とも「いつの時点の count か」をコメントに残した（[[feedback_sentry-triage-needs-count-snapshot]]）

#### ginseng-* のピン判断（2026-09-23 の同期）

**09-21 に宛先を決めた 3 本のうち `ginseng-core` は版が進み、新たに 2 本がずれた。**

- 🔴 **`ginseng-core` は v1.24.0 → **v1.25.0** が出た。#4747 の宛先を差し替えた**（タイトルも変更）。
  差分は `pid ファイルを「同じ inode を書き換える」形から「作って rename」へ`（pooza/ginseng-core#643 / #650）と
  style 追随のみ。**同じ面（pid ファイル）の続きなので v1.24.0 で止める理由が無い。**
  ⚠ **注意点はむしろ強まる**（書き込み方そのものが変わる）。**ステージングで起動・停止・再起動を
  実際に通してから**出す（[[project_latent-landmine-fires-on-next-restart]]）
- 🆕 **`ginseng-web` v3.0.0 → v3.0.1 — ② #4749 として起票・5.39.0**（2026-09-23 ユーザー判断）。
  `fix: Package に http_class を足し、RSS20FeedRenderer の直書きをやめる`（pooza/ginseng-web#135 / #136）
- 🆕 **`ginseng-piefed` v0.1.1 → v0.1.2 — ② #4750 として起票・5.39.0**（同）。
  `fix: Service が http_class を無視して Ginseng::HTTP を直に作る`（pooza/ginseng-piefed#15 / #16）
- ⚠⚠ **上の 2 本は同じ型＝ [[feedback_fix-may-not-reach-through-ginseng]] の「gem がこちらの値を捨てる」。**
  モロヘイヤは `Package#http_class` で自前の `Mulukhiya::HTTP` を返しているのに、
  **gem 側が `Ginseng::HTTP` / `Ginseng::Web::HTTP` を直に作っていたので届いていなかった。**
  🔴 **「UA とロガーの差」で済む話ではない。**向こうがモロヘイヤで取った実測では、
  `Ginseng::HTTP#initialize` が `config_class` から設定を読むので、**フィード描画の HTTP だけ
  再送上限が 3 ではなく gem の既定 5 で回り、syslog の identity が `ginseng-core` になり、
  `Mulukhiya::Config` ではなく `Ginseng::Config` を見ていた**。
  ⚠⚠ **ログのマスク設定（`/logger/mask_fields` と #4511 の `mask_query_params`）も
  この経路には効いていなかった**ことになるので、**取り込み時に
  [[project_log-credential-exposure]] の走査対象にこの経路が入っていたかを確かめる**
- ⚠ **取り込むと再送上限が 5 → 3 に下がる**＝外部ソースの取得が今より早く諦める。
  辞書ソースの 🟡 間欠（#4659）と同じ面なので、**取り込み後に台帳の率を 1 回見る**
- **`ginseng-fediverse` v3.1.0（#4748 / 5.40.0）・`ginseng-redis` v2.0.7（#4746 / 5.39.0）は 09-21 の判断のまま。**
  `ginseng-style` v1.1.13 は ③ 見送りのまま（docs・rubocop 追随のみ）

#### ✅ 同日中に着地: #4543（Sentry の未トリアージ棚卸し）をクローズ

同期のあと「進めてください」で 5.38.0 の #4543 に着手し、**群 2 の 6 件を判定して閉じた。**

| Short ID | 判断 | 根拠 |
| --- | --- | --- |
| 9 | ✅ resolve | `AnnouncementWorker` が上流の 502 を受けたもの。07-29 を最後に 2 か月発生なし |
| E / S / W | ✅ resolve | Misskey のドラフト API が 400。**保持イベントが全部 `sweep`** |
| 29 | ✅ resolve | `MastodonController` の 404。`lbock` の単発 |
| 17 | ✅ resolve | **利用者起因**（下記） |

- ⚠⚠ **「機体が退役した」だけを根拠にしていない。**`E` / `S` / `W` の**コードは vulcan でも同じように
  動いている**。**08-22 のカットオーバーから 1 か月、同じシグネチャが 1 件も出ていない**ことを
  併せた上での判断で、**再発したら reopen してコードを疑う**旨を各コメントに残した
- 🔴 **`17` は #4543 本文の推測（SSRF allowlist が弾いた結果）が外れていた。**
  `ginseng-piefed` の `service.rb:92` の `uri.public?` は**ネットワーク的な到達性ではなく
  トゥートの公開範囲**（`TootURI#public?` ＝ `visibility == 'public'`）で、実体は
  **「公開でないトゥートを Piefed にクリップした」**。⚠ **動作は正しいのに例外にしているので、
  Sidekiq の再試行で 1 操作が 4 件に膨らむ**（count=20 ＝ 実際は 5 回程度の操作）。
  **gem 側で静かに諦める形にするのが本筋**なので、#4750 で piefed を触るときに上流へ提案する
- ⚠ **`28`（`7571753939`）は Sentry から消えていた**（`The requested resource does not exist`）。
  起票時の 16 件のうち 1 件は**追跡不能**
- ✅ **完了条件の最後の 1 項目（§5 の手順に「コメント 0 の滞留も見る」を足すか判断する）も片付けた。**
  **足した**うえで、**実行して 0 件であることを確かめる**形でスクリプトごと手順に置いた
  （実際に動かして確認済み。2026-09-23 時点は unresolved 26 件・コメント 0 は 0 件）

⚠ **監視を続けるものが 2 件残る**（どちらも障害ではなく外部依存のノイズ）:
**`2X` + `2Y`（Annict・足して読む）**と **`2Q`（辞書全滅・新規は他者サーバー分）**。

#### ✅ 同日中に着地: #4570（`Program` の編集系を `ProgramEditor` へ）

**PR #4751・`42507124`。**CI 緑・Codex 指摘なし。

- ⚠ **起票時から状況が進んでいた。**Issue は「**上限 200 行ちょうど**」と書いているが、
  **既に超えて抑止されていた**（2026-08-11 の `e4084d9e` で `rubocop:disable Metrics/ClassLength`）。
  [[feedback_milestone-items-may-be-already-done]] の逆で、**「まだ大丈夫」と書いてある側が陳腐化していた**
- 編集 5 メソッド＋`generate_key`、ロック・正規化・Annict 解決を移した。
  **`Program#save` は残してエディタへ委譲**（auto_update の pull と編集が**同じロックで
  直列化される** #4534 の性質を壊さないため）
- ⚠ **分けても壊れない根拠を先に取った**: `ProgramFetcher` はプロセス内に状態を持たず
  （キャッシュの実体は Redis・`cached_data` は毎回引く）、ロックの実体も Redis 側で key は 1 つ。
  **別インスタンスでも読み書きが食い違わないし、直列化も効く**
- ⚠ **ロックの正テストは移動先を追いかけた。**`Program#save` 越しのケースは残したので、
  **委譲がロックを素通りしたら赤になる**
- **disable を外した。`Program` 85 行 / `ProgramEditor` 182 行（上限 200）**。
  ⚠⚠ **エディタは上限まで 18 行しかない。**次は Annict の 6 メソッドが自然な切り口。
  **また行数合わせで無関係なメソッドを潰さないこと**（#4534 の `persist` がそれ）

⚠ **ローカルの赤 2 件は develop でも落ちる環境由来**（`'/program/auto_update' not found` と
Time の Redis 往復）。**stash して develop の内容で回し、同じ内訳であることを確かめてから出した**。
⚠ `ProgramTest` は `livecure?` が false だと丸ごと omit されるので、**検証の間だけ
`var/program.yaml` を置いて実走**させた（48 tests・後で削除）。

#### chubo2 側で動いたこと（こちらの作業ではない）

- **pooza/chubo2#184（シークレットを sops + age で暗号化して git に置く）が着地した**（`3a93278`）
- ⚠ **pooza/chubo2#253「既に露出した資格情報を再発行する」に、モロヘイヤの告知 webhook が入っている。**
  **ユーザー判断で低優先**（元々 private リポジトリに平文で置いていた経緯があり、深刻に扱わない）。
  差し替え後に `misskey_emoji_sync` を 1 回手で走らせる手順まで向こうに書いてある。**こちらから先回りしない**

### 2026-09-21 セッション同期の記録

**本番には触っていない。**

- **ブランチ**: `develop` は `origin/develop` と同一・未コミット無し。**CI は直近 5 本とも `success`**
- **Dependabot**: open アラート **0 件**
- **Codex / 申し送り**: 直近マージ 8 本（#4744〜#4729）＋ open PR #4739 を横断走査。**未消化ゼロ。**
  指摘は #4744 の P2 1 件のみで、`87fd7111` で消化・返信＋リアクション済み
- **chubo2**: `origin/main` と差分なし。§6-2 の Issue 棚卸しは 08-31（21 日経過）でスキップ、
  §6-3 は 09-08 実施済み
- ⚠ **辞書台帳: 再生成できず。**本番 4 台すべて SSH が `Connection timed out`（VPN 未起動と見る）。
  中身が空の台帳になったので**コミットせず破棄**した。次の同期で回し直す
  → ✅ **09-22 00:25 JST に回し直してコミット**（chubo2 `4f1bcac`）。🔴 は前回の 3 件に
  gomander の `precure.ml/api/dic/v1/dic.json`「死亡」が 1 件増えたが、**偽陽性**。
  0 時のログローテート直後で gomander / zugoga の母数が 2 回しかなく、その 2 回が両方 404 だった。
  前日分（.0.gz）は 144 回中 9 回が空（約 6%）＝ #4659 の 🟡 間欠と同水準。
  → ✅ **生成スクリプトを直近 24 時間で判定するよう直した**（pooza/chubo2#249 / #250、
  台帳は chubo2 `5fcfa97`）。母数は 4 台とも 144 前後にそろい、dic.json は 🟡 間欠 12/144 に戻った。
  **何時に回しても母数が揺れない**ので、🟡 の n/m は回ごとに比べられる。
  ローテート設定の不揃い（shallu は cookbook と実機がずれて zstd）は pooza/chubo2#251 で依頼済み
- **harness upstream**: `last_checked` が 09-20（1 日）なのでスキップ
- **マイルストーン**: 5.38.0 は **open 7**（前日と同じ）。5.39.0 に 1 件

#### Sentry

- ⚠ **`-2X`（Annict `Net::ReadTimeout`）の密度が上がっている。**count=34 / lastSeen 09-20T23:30:07Z。
  **前日 23 → 1 日で 11 件増**（前回は 10 日で 21 件）。zugoga と gomander が**ほぼ同時刻に揃って落ちる**ので
  Annict 側の応答遅延と読み、判断は前日どおり外部ノイズ（#4543）。**次の同期でも count を取り直す**
- **`-7`（Redis `ReadTimeoutError`）に vulcan / 5.37.1 の単発 1 件**（09-18T22:59Z・count=34）。
  07-22 以来の新イベント。単発なので 04-25 の判断を維持
- **`-2Q` の新規は全部 `server_name=mulukhiya`（他者）**。本番の発火ではない。
  ✅ **先方の管理人から相談を受け、原因は GAS のタイムアウトと確定した**（先方の syslog）。
  **既知の間欠（#4659 系）と同じ件**として扱い、受け皿は #4690 にコメントで寄せた
  - ⚠ **9/16 に出始めたのは先方の 5.35.0 → 5.37.x アップグレードと同時刻。**5.36.0 の #4659 ②
    （全滅は last-good で埋めても鳴らす）で**黙っていた回が見えるようになった**だけ。新しい故障と読まない
  - ソース数が少ないサーバーでは、1 本の間欠がそのまま「全ソースが空」になる。
    `Net::ReadTimeout` は #4689 で再送済み（30 秒 × 2 回）なので、**再送しても取れなかった回だけが鳴る**
  - ⚠ **先方の発火はこのまま続く（設計どおり）。**利用者影響は無い（ソース単位の last-good で埋まる）
- ⚠ **観測の穴: `StandardError#alert` は付帯情報を Sentry に渡していない**
  （[refines.rb](../app/lib/mulukhiya/refines.rb) の `Sentry.capture_exception(self)` に `values` が無い）。
  syslog には出るが Sentry では空で、**-2Q の `sources` / `cached_entries` が見えず、他者サーバーの相談に
  Sentry だけでは答えられなかった**。全 alert 共通。**#4745 として起票した**（extra は `scrub_sentry_event` を素通りするので `LogScrubber` を通してから渡す）
- 3 件とも「いつの時点の count か」をコメントに残した

#### ginseng-\* のピン判断（2026-09-21 の同期）

**4 本が 09-20 に一斉に新版を出した。**どれも急ぎではないので、**宛先だけ決めた**（ユーザーと合意）:
**ginseng-redis → #4746 / ginseng-core → #4747（ともに 5.39.0）、ginseng-fediverse → #4748（5.40.0 を新設）**。
fediverse を分けたのは、タグの抽出結果が変わる変更をデーモン周りの変更と同じリリースに混ぜないため。

- **`ginseng-redis` v2.0.6 → v2.0.7 — ② 5.38.0 で取り込む候補（小さく、利が直接ある）。**
  `INCR` を曖昧な失敗（`ReadTimeoutError` 等）で撃ち直さなくした。コメントで
  **モロヘイヤのヒステリシスのカウンタが二重に進む＝早すぎる通知**を名指ししている。
  ⚠ **#4742（ロックの acquire/release がリトライに乗っていない）は直らない**（別経路・`redis.call` 直叩き）
- **`ginseng-core` v1.23.7 → v1.24.0 — ② ただしステージング実測が要る。**`Daemon` / `PidFile` の
  hardlink・symlink 対策、`restart` の終了コード、`CommandLine` ログの資格情報マスク。
  ⚠ **起動時だけ走る経路なので CI 緑を根拠にできない**（[[project_latent-landmine-fires-on-next-restart]]）。
  sidekiq の pid 問題（pooza/chubo-core#37）と同じ面に触る
- **`ginseng-fediverse` v2.0.1 → v3.1.0 — ② 破壊的・急がない。**v3.0.0 は**ハッシュタグ判定を
  Mastodon v4.7.2 へ写し直し**（`＃全角` が抽出される / `あ#タグ` `(#tag)` は抽出されなくなる）と、
  **資格情報付き要求でリダイレクトを追わない**（3xx を例外化）。タグの抽出結果が変わる＝
  **デフォルトタグ・辞書タグの出力が変わる**ので harness 実走が要る。v3.1.0 は `to_utf8` の外出し
  （pooza/ginseng-fediverse#276 / #277）
- **`ginseng-style` → v1.1.13 — ③ 見送り。**docs・プラグイン雛形・rubocop 1.91.0 追随のみ

### 2026-09-20 セッション同期の記録

⚠ **ニチアサ（08:30-09:00）通過後の 09:50 に実施**（[[project_nichiasa-window-is-the-product]]）。
**本番には触っていない。**

- **ブランチ**: `develop` は `origin/develop` と同一・未コミット無し。**CI は直近 4 本とも `success`**
- **Dependabot**: open アラート **0 件**
- **Codex / 申し送り**: 直近マージ 12 本＋ open PR を横断走査（レビューコメントと PR 本体コメントの両方）。
  **未消化ゼロ。**指摘のある 2 件（#4716 の P1 / #4715 の P2）はいずれも**返信＋リアクションが揃っている**
- **chubo2**: `origin/main` と差分なし。§6-2 の Issue 棚卸しは **08-31（20 日経過・30 日未満）でスキップ**、
  §6-3 のドキュメント棚卸しは 09-08 実施済み
- **辞書台帳**: 再生成してコミット。🔴 は**前回と同じ 3 件で変化なし**（直書き 1 / 台帳に無い 2）。
  ⚠ 🟡 間欠は**母数の窓が 69-71 → 57-59 に縮んだ**ので件数も減っているが、**率はほぼ同じ**。
  改善と読まない（#4659 の既知）
- **harness upstream**: `last_checked` が 09-16 で 4 日経過したので実施。**Mastodon v4.7.2 /
  Misskey 2026.9.0 とも verified と同一で、新しい stable も RC も無い。**⚠ 09-15 の 4.6.8 / 4.5.18 /
  4.4.25 は**古い系列のバックポート**なので対象外。`last_checked` のみ 09-20 に更新
- **マイルストーン**: 5.38.0 は **open 7 / closed 3**（Issue ベース）。5.39.0 に 1 件

#### ✅ 同日中に着地: `ginseng-fediverse` v2.0.1（#4740 / PR #4741）

保留を解く提案をユーザーが受けたので、**同じセッションで 5.38.0 へ取り込んだ**。
根拠と実測は上の「取り込み済み」節に書いた。⚠ **本番に届くのは 5.38.0 のリリース時。**

#### Sentry: 過去のトリアージを 1 件取り下げた

- 🔴 **`-2X`（`Net::ReadTimeout` / culprit `Mulukhiya::AnnictService in query`）を再トリアージした。**
  2026-09-09 に **count=2 のまま「一過性・対応不要」**と書いていたが、**今日 count=23 /
  lastSeen 09-18T15:00:07Z**。10 日で 21 件増えている。内訳は `zugoga` 13 / `gomander` 10 で、
  release は 5.36.0 → 5.37.0 → 5.37.1 をまたぐ＝**版に紐づかない**。
  ⚠ ユーザー影響は観測されていない（エピソード辞書は last-known-good が残る）ので
  **障害ではなく外部依存のノイズ**。受け皿は #4543 にコメントで寄せた
  - ⚠⚠ **教訓: `count` が小さいうちに「一過性」と書くと、増えても誰も見直さない。**
    今回気づけたのは**コメントに「いつの時点の count か」が書いてあった**から。この作法を続ける
  - ⚠ **#4577 の「Annict staleness が無音」とは別物。**あちらは `e.log` 止まりで Sentry に出ない経路、
    これは alert に出ている側
- **`-2Q`（辞書全滅）の最新は 09-19T19:35:11Z / `server_name=mulukhiya` ＝ 他者サーバー。**
  **本番 4 台の発火ではない**（`shallu` 本体は 09-05T19:09Z が最後のまま）。09-16 の見分け方がそのまま効いた
- **`-1X` の最新は 09-19T00:02:13Z / `zugoga`** ＝ #4728。**5.38.0 が出るまで鳴り続ける**（既知・方針どおり）

### 2026-09-16 セッション同期の記録（2 回目）

**午前の同期（`9f81add1`・05:47）の続き。**差分だけ書く。

- **ブランチ**: `develop` は `origin/develop` と同一・未コミット無し。**CI は直近 6 本とも緑**
- **Dependabot**: open アラート 0 件
- **Codex**: 直近 9 マージ PR（#4736〜#4717）＋ open PR #4732 を横断走査。**未消化なし**
  （指摘のあるコメントは 1 件も無く、`Didn't find any major issues` のみ）。
  ⚠ PR #4736 の `pooza` コメント（v4 の CI が死んでいる申し送り）は **#4737 で受け皿を起票済み**
- **harness upstream チェック**: `last_checked` が当日（09-16）なのでスキップ
- **chubo2**: `origin/main` と差分なし。§6-2 の Issue 棚卸しは 08-31、§6-3 のドキュメント棚卸しは
  09-08 実施済みなのでどちらもスキップ
- **辞書台帳**: 再生成してコミット（chubo2 `09796cd`）。🔴 は**前回と同じ 3 件で変化なし**。
  🟡 間欠は母数の窓が 22-23 → 69-71 に広がった分だけ件数が増えただけ（率は同程度・#4659 の既知）
- **ginseng-\* のピン**: **ずれは 2 本のみで、午前の判定から変化なし。**
  `ginseng-fediverse` v2.0.0 は **pooza/ginseng-fediverse#276 が open のまま**なので保留継続（v2.0.1 待ち）。
  `ginseng-web` v3.0.0 は **PR #4732 が open・CI 両系 SUCCESS で、マージ可能な状態**
- **マイルストーン**: 🧹 **5.37.0（#635）を close した**（open 0 / closed 14・09-10 に出荷済みなのに開いたままだった）

#### 🔴 Sentry: 今日の新規イベントは**全部他者サーバー**から出ている（→ #4543）

⚠⚠ **`server_name=mulukhiya` の機体の特定を、2026-08-28 から 3 週間「次の同期へ持ち越し」にしていた。**
**この持ち越しが間違いだった。**追って特定する話ではなく、**切り分けて除外する**話だった。

| Sentry | JST | server | release | 中身 |
| --- | --- | --- | --- | --- |
| `-1X` | 09-16 07:03 / 07:13 | **`mulukhiya`** | 5.35.0 | `FeedUpdateWorker`・シェルの null byte |
| `-J` | 09-16 09:43 ×3 | **`mulukhiya`** | 5.35.0 | Redis 接続拒否 6379/3（起動順の族） |
| `-2Q` | 09-16 09:54 / 10:04 | **`mulukhiya`** | **5.37.1** | 辞書が全滅 |
| `-2Q` | 09-16 10:24 / 10:34 / 10:44 | **`mulukhiya`** | **5.37.0** | 同上 |

⚠⚠ **本番 4 台からの新規は 1 件も無い。**

##### 🔴 見分け方が確定した: **FQDN を名乗らない `server_name` が他者**

`server_name` タグの内訳を取り直して確定した。⚠ **この DSN には他者のモロヘイヤが少なくとも 2 台流れ込んでいる。**

| `server_name` | 初出 | 最終 | |
| --- | --- | --- | --- |
| `mulukhiya` | 2026-06-23 | **2026-09-16** | ⚠ 他者 |
| `instance-20220704-2044` | 2026-06-23 | 2026-08-22 | ⚠ 他者（GCP 既定のホスト名） |
| `lbock.b-shock.co.jp` / `sweep.b-shock.co.jp` | | | ✅ 自分（**退役済みでも FQDN を名乗る**） |

- 🔴 **初出が 2 台とも 2026-06-23** で、**2026-05-31 に合意した姉妹サーバー管理人の DSN 合流**
  （[[project_cureskey-sister-server]] の案 A）と一致する
- ⚠ **`mulukhiya` の指紋**: kernel `PMX 7.0.14-14`（2026-08-22 ビルド）/ ruby 4.0.6 /
  `environment=production` / sidekiq。**今の pve（`7.0.2-6-pve`・CT 10 台とも同一）より新しい**ので
  この pve の上には無い。⚠ **これは「フリート表に無い自分の機体」ではなく
  「向こうが自分の Proxmox で動かしている」と読む。**版が 1 時間で 5.35.0 → 5.37.1 → 5.37.0 と
  動いていたのも、**向こうの管理人が今朝アップグレードしていた**と読める
- ⚠⚠ **一度 pooza/chubo2#241 として「未特定の機体」を起票したが、前提が違ったのでクローズした。**
  **インフラの課題ではない**（こちらから直せない）。受け皿は **#4543**（Sentry 棚卸し・5.38.0 在籍）にコメントで寄せた

##### 本番側の読み直し

- ⚠ **`-2Q` を「shallu の辞書がまた全滅した」と読まないこと** ——
  **shallu 本体での発火は 2026-09-05T19:09Z が最後で、以後 11 日間出ていない**
- ⚠ **`-1X` の本番側の最新は 09-14T00:24Z の zugoga**（`config validation` ＝ #4728）。
  **修正は develop にしか無いので 5.38.0 が出るまで鳴り続ける**（午前に記録した方針のとおり）
- 判定と訂正は Sentry の `-2Q` / `-1X` にコメントとして残した

## 投稿レイテンシ調査の記録（#4464・2026-08-02 完了）

5.30.0 の主軸だった調査の全記録。**ゴール（数秒の内訳をハンドラ単位で説明できる状態）は達成済み**なので、以下は今後の性能判断のための参照用。⚠ **同じ推測を繰り返さないために、否定された仮説もそのまま残してある。**

### 主軸: #4464 pre_toot ハンドラの所要時間を計装する

**是正したい対象は、キュアスタ！のメインコンテンツであるニチアサ実況（日曜朝）で投稿に数秒かかること。** relay ~1.5s 部分は Mastodon 本体の status 生成と確定済み（proxy 無罪）で、残る超過分が `pre_toot` 26 ハンドラの直列処理側にあるという仮説。

**5.30.0 のゴールは「数秒の内訳をハンドラ単位で説明できる状態にすること」だけ。** 対策の実装は内訳が出てから別 Issue で行う。以下の実測により、当初主軸に据えかけた辞書まわりの最適化が的外れと判明したため。

### 2026-07-20 実測: lbock / gomander の単スレッド性能

同一 Ruby 3.4.9、`TaggingDictionary#matches` 相当の合成ベンチ（語数 3000、実況相当の短文）。

| ベンチ | lbock | gomander | 比 |
| --- | --- | --- | --- |
| `raw_cpu`（素の整数演算） | 1408 ms | 2411 ms | **1.71x 遅い** |
| `regexp_compile_3000`（`short?` の再コンパイル） | 8.2 ms | 9.8 ms | 1.20x |
| `sweep_3000_x1`（辞書スイープ本体） | 0.7 ms | 0.8 ms | 1.14x |
| `sweep_x3_current`（`addition_tags` 3回呼び） | 2.1 ms | 2.4 ms | 1.14x |
| `marshal_load`（辞書読み直し） | 3.7 ms | 4.0 ms | 1.08x |

| ホスト | CPU | コア | RAM | FreeBSD |
| --- | --- | --- | --- | --- |
| lbock（現行・さくら VPS） | Intel Xeon Sapphire Rapids（2023） | **4** | 4GB | 14.4 |
| gomander（移行先・Linode） | AMD EPYC 7713（Milan, 2021） | **2** | 4GB | 15.1 |

**判明した二つのこと:**

1. **「数秒」の原因は辞書スキャンではない。** `DictionaryTagHandler` の総コストは lbock 約 12ms / gomander 約 15ms で、数秒に対して三桁足りない。#4463 / #4465 をやり切っても体感は変わらないため、両者はマイルストーンから外し判断保留とした
2. **gomander へそのまま移すと悪化する公算が高い。** per-core 1.7 倍遅く、コアも 4→2。実況バーストの同時処理能力は半減する

### 真犯人の候補: pre_toot の直列 HTTP（**2026-07-26 の実測で否定された**）

**後述の実測により、直列 HTTP 仮説は棄却された。** 実況ウィンドウの HTTP 待ちは総所要の 0.1% しかなく、対策の方向はメモ化・キャッシュではない。以下は当時の仮説として残す。

`pre_toot` 26 ハンドラのうち **11 個が外部 HTTP を打ちうる**（itunes/spotify/you_tube の image と nowplaying、shortened_url、amazon_url、peer_tube_url_nowplaying）。特に `ShortenedURLHandler#resolve_redirects` は **1 URL あたり最大 8 回の HTTP リクエストを直列**で投げる（`app/lib/mulukhiya/handler/shortened_url_handler.rb:37-48`、`MAX_REDIRECTS = 8`）。数秒はここに居る公算が大きく、**CPU ではなく I/O**。

これが正しければ対策はメモ化・キャッシュ・タイムアウト見直しであり、移行先に関わらず効く。順序性の制約（`pre_toot` パイプライン順、`matches` の「長い語から先に消し込む」順序）は仕様なので、**並列化を安易な特効薬として扱わない**（MEMORY `feedback_handler-order-no-casual-parallel`）。

### 計装の要件

- **ハンドラ別の壁時計時間**（CPU 時間ではなく HTTP 待ちを含む実時間）
- 発行した**外部 HTTP の回数と各所要**
- **ニチアサ実況の実負荷で採る**（アイドル時の合成負荷で判断しない）
- **トゥートの種類別**に内訳が見られること（URL 有無・ナウプレ・短文で通るハンドラが変わる）

### 2026-07-26 実測: lbock 最後のニチアサ実況（#4464 のゴール達成）

計装は 07-23 05:40 の再起動から稼働（計画の 07-24 より 1 日早い）。**生データは lbock 解約前に `docs/bench/data/` へ退避済み**で、集計は `docs/bench/analyze_handler_profile.rb`。

実況ウィンドウ（08〜09時台）で閾値 1.0 秒を超えたのは **168 件**（`pre_toot` 129 / `pre_webhook` 39）。総所要は min 4.3 / **p50 4.9** / p90 7.5 / max 9.7 秒で、**1〜4 秒帯が 1 件も無い**。

| handler | 件数 | 合計s | 平均s | 最大s | HTTP回 | HTTP秒 |
| --- | --- | --- | --- | --- | --- | --- |
| dictionary_tag | 168 | 240.2 | 1.429 | 3.874 | 0 | 0.0 |
| remote_tag | 168 | 230.8 | 1.374 | 3.547 | 0 | 0.0 |
| spoiler | 168 | 109.5 | 0.652 | 1.245 | 0 | 0.0 |
| user_tag | 129 | 88.8 | 0.688 | 0.849 | 0 | 0.0 |
| user_config_command | 129 | 81.6 | 0.632 | 0.958 | 0 | 0.0 |
| group_tag | 168 | 53.6 | 0.319 | 0.508 | 6 | 0.7 |
| shortened_url | 124 | 26.6 | 0.214 | 0.940 | 0 | 0.0 |

**判明したこと:**

1. **直列 HTTP は無罪。** 合計イベント秒 923.0 に対し HTTP 待ちは **0.7 秒（0.1%）**。最大の調査対象だった `shortened_url` すら**この日は一度も HTTP を打っていない**（0.214 秒はリダイレクト解決ではない何かで待っている）
2. **ハンドラ固有の仕事でもない。** 07-20 のベンチで 12ms だった `dictionary_tag` が壁時計 1.43 秒。**HTTP を打たないハンドラが軒並み 0.6〜1.4 秒で横並び**になっており、各ハンドラが「自分の仕事」で遅いのではなく**全員が同じ何かを待っている**形
3. その「同じ何か」は同日中に特定できた（次節）。当初疑ったスレッド競合（GVL・swap の page-in）ではない

### 真犯人: `localhost` への TCP 接続 1 回につき 305ms（#4481 / #4482 / pooza/chubo2#87）

lbock 実機（Ruby 4.0.5・YJIT 有効・実辞書 3950 語 / 725KB）で `TaggingDictionary.new` を割ると、辞書処理ではなく **Redis への接続**が支配項だった。

| 対象 | 所要 |
| --- | --- |
| `Redis.new`（接続は遅延） | 0.7 ms |
| `Redis.new` + 小さい GET | 309.8 ms |
| 接続を使い回した GET | 0.95 ms |
| `Marshal.load`（辞書 725KB） | 23.8 ms |
| `TaggingDictionary#matches` | 116.4 ms |

さらに割ると `TCPSocket.new('localhost', 6379)` そのものが **305ms**。

```text
localhost:6379  既定=305.4ms  HEv2無効=0.2ms  addrs=127.0.0.1
precure.ml:443  既定= 20.2ms  HEv2無効=118.3ms
127.0.0.1:6379  既定=  0.0ms
```

**原因は Ruby 3.4 以降の Happy Eyeballs v2 と、lbock の `/etc/hosts` に `::1 localhost` が無いことの組み合わせ。** A は files から即引けるのに AAAA は files に無いため DNS（1.1.1.1）へ出て行き、HEv2 がその決着を待つあいだ固定ディレイを払う。`fast_fallback: false` で 0.2ms、IP アドレス直指定で 0.0ms になることで確定。**AAAA を正しく持つ実在ホスト（precure.ml 等）では HEv2 はむしろ速い**ので、地雷は「`::1` を持たない `localhost`」に限られる。

| ホスト | `/etc/hosts` の `::1` | localhost:6379 connect |
| --- | --- | --- |
| **lbock** | **無し** | **305 ms** |
| zugoga / shallu / gomander | あり | 0.3〜0.7 ms |

**これでログの形がすべて説明できる。** `Event#dispatch` の `run_handler` はハンドラごとに Thread を立てるが `join` で待つ＝**実質直列**なので、投稿の総所要 ≒ ハンドラ時間の総和（実測 4.9 秒と一致）。そして各ハンドラの平均が 305ms の整数倍に並ぶ。

- `group_tag` 0.319s ≒ 接続 1 回
- `spoiler` 0.652 / `user_config_command` 0.632 / `user_tag` 0.688 ≒ 接続 2 回
- `dictionary_tag` 1.429 / `remote_tag` 1.374 ≒ 接続 2 回 + 辞書処理 140ms

**1〜4 秒帯が空白だったのも同じ理由**（投稿ごとに固定回数の 305ms を必ず払うため値が量子化される）。検出は `docs/bench/probe_localhost_connect.rb` で 1 コマンド。

**効いてくること:**

- **カットオーバー（07-28）だけで大半が消える。** gomander には `::1` があるため、コードを 1 行も変えずに投稿が数秒速くなる見込み
- 逆に **08-02 の再測で出る劇的な改善を「RAM 2.15 倍のおかげ」と誤帰属しないこと。** 主因はこれで、RAM ではない
- `config/application.yaml` の既定 DSN が 3 箇所とも `redis://localhost:...`＝**`::1` を持たないホストを新設すれば誰でも踏む**。lbock 固有の事故ではなく出荷設定側の地雷（#4481）

**lbock は直さない。** 07-28 に退役し、それまでに実況も無いため利用者の得が無く、08-02 比較のベースラインが変わるだけ。

**次にやること:** #4481（既定 DSN の IP アドレス化）・#4482（`TaggingDictionary` の二重構築解消）・pooza/chubo2#87（`/etc/hosts` の `::1` をレシピで保証）。ただし**コード側の着手はカットオーバー後**（移行前後を同じコードで比較する必要があるため）。

### 2026-07-29 実測: gomander 移行翌日（暫定・予測どおり）

**少人数の実況（19〜21時台・ローカル投稿 32 件）なのでニチアサとは比較にならない**が、予測の方向は出た。生データは `docs/bench/data/handler_profile-gomander-20260729.jsonl.gz`。

| | lbock 07-26 ニチアサ | gomander 07-29 夜 |
| --- | --- | --- |
| 1 秒超えイベント | 176 件 | 16 件（32 投稿中） |
| 総所要 min / p50 / max | 4.3 / 4.9 / 9.7 秒 | **1.0 / 1.1 / 1.6 秒** |

**分布が重ならない**（gomander の最遅 1.6s が lbock の最速 4.3s に届かない）。決め手は**処理内容が変わっていない `spoiler` と `user_config_command`** で、平均が 0.651s → **0.020s** / 0.632s → **0.016s**。lbock でのこの値は ≒ 305ms × 2 の接続遅延そのものだったので、**305ms 説の実データ裏取りになっている**（RAM でもプランでもない）。

残る 1.0〜1.6 秒は `dictionary_tag` + `remote_tag` で 87%、HTTP 待ちは 0.3% しかない＝**辞書スキャンの CPU 時間**（#4463 / #4465）。

⚠ 日全体では `p90=3.6s / max=6.5s` になるが、上位は 00:14:07 に同時発火した `pre_webhook` 5 件で、**並行実行時に `dictionary_tag` / `remote_tag` が 3 秒級へ膨らむ**という別の現象。実況の投稿レイテンシと混ぜて読まないこと。

**本命は 08-02（日）のニチアサ**で、同じ手順で採取して 07-26 と突き合わせる。

### 2026-08-02 実測: gomander で初のニチアサ（#4464 の突き合わせ完了）

生データは `docs/bench/data/handler_profile-gomander-20260802.jsonl.gz`（99 行、うち実況の 08 時台が 80 行）。

**投稿量がほぼ同じ 08 時台どうしで比較できた**（ローカル投稿 07-26 133 件 / 08-02 130 件。件数は移行後の gomander の `statuses` から両日とも取得）。

| | lbock 07-26 08時台 | gomander 08-02 08時台 |
| --- | --- | --- |
| ローカル投稿 | 133 件 | 130 件 |
| 1 秒超の `pre_toot` | 119 件（**89%**） | 79 件（**61%**） |
| 総所要 min / p50 / p90 / max | 4.3 / **4.8** / 5.5 / 6.3 秒 | 1.0 / **1.1** / 1.5 / 1.9 秒 |

ハンドラ別（08〜09 時台、平均秒）:

| handler | lbock 07-26 | gomander 08-02 | 効いたもの |
| --- | --- | --- | --- |
| dictionary_tag | 1.429 | **0.457** | 接続 2 回分が消え、辞書処理だけが残った |
| remote_tag | 1.374 | **0.454** | 同上 |
| user_tag | 0.688 | **0.073** | 接続 2 回 → ほぼゼロ |
| spoiler | 0.652 | **0.026** | 同上（処理内容は不変） |
| user_config_command | 0.632 | **0.023** | 同上（処理内容は不変） |
| group_tag | 0.319 | **0.006** | 接続 1 回 → ほぼゼロ |
| shortened_url | 0.214 | **0.002** | 同上 |

**確定したこと:**

1. **305ms 説は実況の実負荷でも裏づけられた。** 処理内容が変わっていない `spoiler` / `user_config_command` が 0.65s / 0.63s → 0.026s / 0.023s。lbock での値が接続回数 × 305ms そのものだったことが、07-29 の少人数実況に続いて本番相当の流量でも再現した
2. **残る 1.1 秒の 76% は `dictionary_tag` + `remote_tag`**（0.457 + 0.454 = 0.911 秒）。HTTP 待ちは 0.1% で、これは**辞書スキャンの CPU 時間**。次に削るならここ（#4463 / #4465 / #4482）
3. **交絡因子 2 件は今回の比較には効いていない。** ボット流入は実況窓に再来せず（当日の 504 は **808 件すべて 06 時台**、08 時台は 12,687 req・ピーク 518 req/分・load 0.54 で平常）。`tags` のインデックス是正は Mastodon 本体の status 生成側に乗るためハンドラ計装には現れない（切り分けの指針どおり）

⚠ **`p50 1.1s` は「1 秒超だけの p50」であって全投稿の p50 ではない。** lbock は最速でも 4.3 秒＝全件が閾値の上にいたので母集団と実質同じだったが、gomander は分布が閾値をまたぐ（08 時台の 61% だけが記録対象）。**閾値 1.0 秒が分布を切っている**ので、両日の p50 を「同じ母集団の代表値」として並べない。改善幅の主張には 1 秒超の**割合**（89% → 61%）を併記する。

**実況そのものは負荷イベントではない。** 08 時台のピークは 518 req/分・load 0.54 で、同日早朝のボット流入（約 5,000 req/分・load 24.6）とは二桁違う。投稿が遅かったのは負荷ではなく、投稿 1 件あたりに固定で払っていた接続遅延だった。

`docs/bench/cpu_sample.rb` のサンプラは gomander / zugoga とも cron・TSV とも既に無く、撤収済み（実機確認）。

### 同梱: Ruby ランタイムの能力欠落を検知する（#4466 / chubo2#69）

**本番 4 台は YJIT 有効**（lbock / zugoga / shallu / sweep、いずれも `built=true enabled=true`、Ruby 4.0.5。2026-07-20 実機確認）。

有効化は `app/lib/mulukhiya.rb:113` の `RubyVM::YJIT.enable if defined?(RubyVM::YJIT)` による。これは module 本体の**末尾**にある実行文で、`require 'mulukhiya'` 時点で必ず走る。**初期化を終えてから YJIT を有効にするのがプラクティス**で、プロセス起動時（`RUBYOPT` に `--yjit`）から有効にすると一度しか通らない初期化コードのコンパイルに YJIT の予算を費やしてしまうため。`RUBYOPT` に `--yjit` が無いのは手落ちではなく設計意図。

**問題は、このガードがサイレントであること。** `if defined?(RubyVM::YJIT)` は YJIT なしビルドでも起動できるようにするために必要で実装として正しいが、裏返すと **Rust 不在でビルドされた Ruby では黙って false 側に倒れ、誰にも気づかれないまま 24〜25% 遅い状態で動き続ける**。YJIT は Rust がないとビルド時に黙って外れ、エラーにならない。

| ホスト | Rust | Ruby 4.0.5 の YJIT |
| --- | --- | --- |
| lbock / zugoga / shallu | あり（1.94〜1.96） | ✅ ビルド済み・有効 |
| gomander | あり（1.96.1、2026-07-20 導入） | ✅ ビルド済み（2026-07-20、chubo2#72） |

※ 07-20 に gomander へ Rust 1.96.1 と rbenv + Ruby 4.0.5 を導入し、`ruby --yjit -e 'RubyVM::YJIT.enabled?'` → true を実機確認。**4 台すべてで YJIT が乗る状態になった**ため「移行で 24〜25% を失う」リスクは解消。

**YJIT の効果は `raw_cpu` で 24〜25% 短縮**（lbock 1558→1184ms、zugoga 1603→1202ms）。ただし `regexp_compile` / `sweep` / `marshal_load` はほぼ不変で、正規表現エンジンも Marshal も C 実装のため YJIT の対象外。

つまり 24〜25% は「これから取れる利得」ではなく **既に全台で得ている利得**。当初は「Rust なしの gomander へ移ればこれを失う」ことが最大のリスクだったが、**2026-07-20 に gomander へ Rust + Ruby 4.0.5 (YJIT) を導入して解消済み**（chubo2#72）。残るリスクはホスト個体の遅さのみ（上記「ハズレ個体」節）。

- **#4466 obs: health に Ruby ランタイム情報（version / YJIT）を含める（size:M）** — 既定では NG 判定に含めず情報として出す（能力欠落は障害ではないため 503 にしない）。`runtime.require_yjit` による opt-in アサーションを併設。config 参照を fail-open にしないこと（MEMORY `feedback_fail-open-guard-footgun`）
- **chubo2#69** — rbenv レシピで Rust を前提化し、ビルド直後に `ruby --yjit -e 'exit RubyVM::YJIT.enabled?'` でアサートして失敗させる
- ~~#4467 perf: 本番で YJIT を有効化する~~ — **前提が誤りだったためクローズ**（既に有効だった）

### 本番 Ruby での per-core 再測定（重要な訂正）

上表のベンチは `ruby34`（3.4.9・YJIT なし）で全台統一して測ったもので、ホスト間比較としては有効。ただし**本番の実行環境は Ruby 4.0.5** であり、そちらで測り直すと結論が変わる。

| ホスト | 3.4.9 | 4.0.5 YJIT なし | **4.0.5 YJIT あり＝本番の実行条件** |
| --- | --- | --- | --- |
| lbock（さくら） | 1408 ms | 1558 ms | **1181 ms** |
| zugoga（Linode） | 1624 ms | 1603 ms | **1157〜1194 ms** |
| gomander（Linode） | 2412〜2450 ms | — | **1764〜1841 ms** |

**本番 Ruby では lbock と zugoga の差は 1.03 倍＝実質同等。** 3.4.9 で見えた 1.15 倍の Linode ペナルティは本番条件ではほぼ消える。「さくらは価格性能比で優れる」は、少なくとも per-core CPU については本番条件で裏付けられない。

### gomander は物理ホストのハズレ（2026-07-20 確定）

gomander に rbenv + Ruby 4.0.5（YJIT built=true）を導入し（chubo2#72）、本番条件で測り直すと **gomander だけ 1.52 倍遅い**。ここから交絡を順に潰して、原因を**着地した物理ホスト**に特定した。

| 疑い | 検証 | 結果 |
| --- | --- | --- |
| Ruby / ビルドの差 | 素の C（同一ソース・clang 19.1.7・`-O2`、[chunk_bench.c](bench/chunk_bench.c)） | **差は残る**（1.35〜1.41 倍） |
| FreeBSD 15 vs 14 の緩和策 | ループはシステムコールを呼ばない＝緩和策が効く境界を通らない | 除外 |
| シリコン世代 | dmesg | **完全一致**（Family 0x19 / Model 0x1 / Stepping 1、TSC 2.000GHz） |
| 隣人輻輳 (steal) | チャンク 400 分割の分布 | **除外**（下記） |
| プラン種別 | Linode metadata service | **同一** `g6-standard-2` / `jp-tyo-3` |

**分布（3M 回 × 400 チャンク、ms）:**

| ホスト | min | p50 | max | max/min |
| --- | --- | --- | --- | --- |
| gomander | **20.05** | 20.10 | 20.82 | **1.04** |
| zugoga | **14.22** | 14.31 | 148.89 | 10.5 |
| lbock | 15.11 | 15.16 | 15.73 | 1.04 |

**gomander は最小値そのものが 1.41 倍遅い。** 最小値は誰にも邪魔されない最良ケースなので、これは競合ではなく素の速度。かつ max/min 1.04 で**テールが皆無＝まったく競合していない**。実際に steal を食らっているのは zugoga のほう（max 148ms）で、それでも baseline は gomander より速い。

Linode metadata service で **プラン・リージョン・vCPU・RAM がすべて同一、違うのは `host_uuid` だけ**と確認できた（gomander `a6f7baf2…` / zugoga `550683b0…`）。

**対処はプランアップではなく作り直し**（破棄・再作成して別ホストへ着地させる）。受け皿は chubo2#68。**gomander は 2026-07-20 に作り直し済みで、この病状は解消した**（`raw_cpu` 2412 → 1646.9ms、zugoga 1632ms と同等。2026-07-23 再確認）。

なお **`raw_cpu` の分散が小さいこと（gomander 約 1.6%）は「隣人輻輳ではない」の根拠にならない**。OS や設定由来の一定の差でも分散は小さく出るため。切り分けたのは上記の C ベンチと分布のほう。

#### ⚠ 当時の受け入れ基準は両方とも無効（#4471 / #4476）

作り直しの合否に使っていた ①`host_uuid` が変わること ②チャンクベンチの min < 15ms は、**どちらも後に反証された**。

- **`host_uuid`** — Cold Resize で uuid が変わっても数字が動かず反証。そもそも既知の 1 台と UUID を比べる方式では「別の遅い個体」を検出できない
- **チャンクベンチの min** — **C の速度は Ruby の速度を予測しない**。作り直した gomander は C では lbock より 6% 速いのに Ruby では 10% 遅い。生スループットで門番をすると誤った結論に導く

現行の判定は `stlf_probe` の ratio を**参照ホストとの相対比較**で見る（[docs/bench/README.md](bench/README.md)）。ratio に不変な絶対閾値は置けない（コンパイラを変えるだけで健全な機体が 3〜5 倍動く）ため、`verify_host.sh` は参照が測れないとき・両者の `cc` が違うときは**合否を出さない**。インスタンスの引き直しは stlf_probe が異常を示したときだけで、per-core 数％〜十数％の差では引き直さない。

### per-core 分散サンプリング（2026-07-20 仕込み済み・観測中）

上記の単発ベンチは「その瞬間の per-core 性能」しか見ていない。Shared プランは隣人輻輳で揺れるため、**07-26（日）のニチアサ実況ウィンドウを含む定期サンプリング**を lbock / zugoga / gomander の 3 台に仕込んだ（`docs/bench/cpu_sample.rb`、cron `*/10`、`~/cpu_sample.tsv` に追記）。Ruby は条件統一のため全台 `ruby34`（3.4.9）で、絶対性能の結論には使わない。

初回サンプル（2026-07-20 10:10、`raw_cpu` ms）: lbock 1404〜1408 / zugoga 1625〜1630 / gomander 2418〜2450。いずれも 07-20 の単発ベンチ基準値と整合。

**2026-07-23 時点**: lbock 1416.8 / zugoga 1632.1 / gomander **1646.9**（作り直し後）。gomander のサンプラは作り直しで消えていたため再設置した。lbock / zugoga は継続稼働中。

判定したいこと: ~~①gomander は安定して遅いのか揺れているのか~~（作り直しで解消）②zugoga / lbock が実況時間帯に劣化するか（Shared 契約が実況ウィンドウで牙を剥くか）。**カットオーバー（chubo2#68）の判断材料**であり、07-26 の観測後に読む。

**2026-07-26 の観測結果（②の答えは No）:**

| ホスト | 実況 08-09時台 平均 | 同 最悪 | 同日 02-04時台 平均 |
| --- | --- | --- | --- |
| lbock | 1502ms | 1763ms | 1488ms |
| zugoga | 1776ms | 2243ms | 1751ms |
| gomander | 1637ms | 1674ms | 1639ms |

**3 台とも実況時間帯の劣化は無い**（lbock で +1%）。Shared 契約の隣人輻輳はカットオーバーの阻害要因にならない。**投稿が数秒かかる原因も per-core CPU ではない**（実況中も平常値）ことが裏づけられ、上記「2026-07-26 実測」のスレッド競合説と整合する。生データは `docs/bench/data/` に退避済み。サンプラの撤収は lbock 解約（07-31）と gomander での再測（08-02）の後でよい。

### 保留中（マイルストーン外）

- **#4463 perf: DictionaryTagHandler の投稿同期スキャン最適化（size:M）** — 実測で 12ms と判明し主軸から外れた。無駄が無駄であることは変わらないので安い改善として後日消化の余地はある（`regexp_compile` の 8〜10ms が単独では最大項）。**推測で実装を進めない**
- **#4465 perf: `TaggingDictionary#matches` のアルゴリズム刷新（size:L）** — 索引化で削れる上限がミリ秒未満と判明。辞書の語数が桁で増えた場合に再検討

### キュアスタ！ (lbock) → gomander 移行との関係

受け皿は chubo2#68。**2026-07-28 にカットオーバー完了**（ダウンタイム約 2 時間）。移行の記録は chubo2 `docs/infra-history.md` の同日の節、移行後の構成は `docs/infra-note.md`「キュアスタ！本番 (gomander)」節。

移行判断の前提だったのは「**移行して現状より悪化させないことが絶対条件**」で、コストはそのために受け入れてきた要素（二重ランニングコストが数ヶ月発生したが、期限で急かす材料にはしない）。作り直した gomander は per-core で lbock の約 1.1 倍遅い程度に収まり、**コアは 4 で同数・RAM は 8.5GB（2.15 倍）**。lbock は swap を 1.3GB 使い page-in が続く状態だったので、律速は CPU ではなく RAM と判断し、プランアップせず現行プランのまま切り替えた。

**残っている段取り**: ~~07-31 lbock 解約~~（07-29 夜に前倒しで停止・DNS 削除済み）→ ~~**08-02（日）gomander で初の実況・計装の再採取**~~ → **2026-08-02 に採取・突き合わせ完了**（上記「2026-08-02 実測」節）。**#4464 のゴール（数秒の内訳をハンドラ単位で説明できる状態）は達成**。**2026-08-02 に 5.30.0 をリリースし、gomander を `main` 運用へ戻して移行トラックは完了**。

⚠ **`localhost` 接続の 305ms（下記）は lbock 固有の `/etc/hosts` 起因で、gomander は `::1 localhost` を持つ（2026-07-29 実機確認）＝移行しただけで消える。** 08-02 に投稿レイテンシが改善しても gomander の RAM やプランの手柄と読み違えないこと。

⚠ **08-02 の実況は特殊条件下だった。比較に交絡因子が 2 つ乗る**（採取後の評価は上記「2026-08-02 実測」節。**どちらもハンドラ計装の比較には効いていなかった**）。

1. **早朝の分散ボット流入**（05:00〜06:20）。単一 UA・2,922 IP アドレス / 319 ネットに分散したスクレイパーがピーク約 5,000 req/分で gomander を叩き、load 24.6・当日 504 が 808 件（前日 18 件）。受け皿は chubo2#118。→ **実況時間帯に再来せず**（504 は 808 件すべて 06 時台、08 時台は 12,687 req・ピーク 518 req/分・load 0.54）
2. **`tags` のインデックス是正**（06:1x〜06:3x）。上記の調査中に `index_tags_on_name_lower_btree` の欠損が発覚し、本番 3 台へ非 UNIQUE で投入 + `ANALYZE`。タグ検索が **3,086ms → 0.078ms**。受け皿は chubo2#117

**この欠損は 07-26 の lbock 時点でも存在していた**（gomander の DB は lbock 由来で、移行後も欠けていた）。実況はハッシュタグを大量に使い、モロヘイヤの自動タグ付与がそれを増幅するため、**07-26 の p50 4.9 秒にはこのフルスキャン分が乗っていた可能性がある**。08-02 との単純比較で「移行で速くなった」と結論しないこと。

切り分けの指針: タグ検索は Mastodon 本体の status 生成（relay ~1.5s と確定済みの部分）の中で起き、モロヘイヤのハンドラ側には乗らない。したがって **relay 部分の低下＝インデックス是正の効果、ハンドラ部分の変化＝移行・HEv2 の効果**として読む。

**優先度ダウン（後ろ倒し）: #4393 media_catalog sub-second 化**。2026-07-18 に優先度を下げ 5.29.0 から除外（「落ち着いた頃に」）。media_catalog 再有効化トラック（#4323/#4351/#4352/#4375/#4393、runbook=docs/media_catalog.md「性能トラックの記録」）は生きているが着手時期を後ろ倒し。#4393（query 再構成/非正規化、size:L）が #4351 Gate 2 の前提ブロッカーである構図は不変。

**ステージング再建（解消済み）**: Proxmox ステージング dev24-27（美食丼/キュアスタ！/デルムリン丼=Mastodon、ダイスキー=Misskey）が稼働し、「ステージング検証省略不可」を実運用で満たせる状態に復帰（旧 dev04/15/22/23 は退役、現行構成は chubo2 `docs/infra-note.md`「ステージング」節が正）。5.28.0 の省略障害（MEMORY `project_5280-staging-skip-postmortem`）は解消。構成乖離#36/Linode 移行#35 等の長期構想は MEMORY `project_proxmox-staging-rebuild` 継続。

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
- #4734 HEIF の取り込みを戻す（解除条件は `libheif >= 1.23.4` が pkg / ports に来ること。2026-10-10 に題を書き換えて受け皿にした。周知はしない）
- #4298 Misskey ドライブの一覧でファイル不可視（Misskey 本体／Object Storage 側の問題、状況変化があれば再開）
- #4301 capsicum #344 向け Misskey avatarDecorations API（capsicum 側の進捗待ち）

### メタ Issue（生きている）

- #4233 APIController: 残る長大エンドポイントの段階的リファクタ（サブ #4283/#4284/#4285、上記ロードマップで進行中）
- #4323 perf: media_attachments 関連 index 見直し（サブ #4393 sub-second 化 query 再構成 / #4351 zugoga 再有効化 / #4352 shallu/lbock 横展開 / #4353 本家 migration / #4375 Misskey track）。**zugoga 本番 EXPLAIN で partial index 単独では sub-second に届かないと判明し、#4393（query 再構成/非正規化、size:L）を #4351 の前提に格上げ**。実行 runbook は docs/media_catalog.md「性能トラックの記録」（決定ゲート Gate 0〜2 + rollback）。Mastodon は statuses partial index、Misskey は別ルート（drive_file、daisskey で実証済み）

### マイルストーン未設定

⚠ **2026-10-03 に、on-hold 以外の open Issue はすべてマイルストーンへ割り当てた**（5.40.0〜5.43.0・「2026-10-03 セッション同期の記録」参照）。
**未設定のまま残るのは on-hold 群の 8 件だけ。**以下は 2026-08-03 時点の記録。

2026-08-03 の 5.31.0 スコープ確定時点で、以下は意図的にマイルストーン未設定のまま置いている。
着手条件が揃うか、次のスコープ確定で拾う。

- **media_catalog track** — #4323（メタ）とサブ #4351 / #4352 / #4353 / #4375 / #4393。#4393（sub-second 化の query 再構成）が #4351 の前提。優先度ダウン中
- **辞書スキャンの最適化** — #4463（メモ化・辞書キャッシュ・regex 事前コンパイル）/ #4465（`TaggingDictionary#matches` の索引化）。5.30.0 で「次に削るなら辞書スキャンの CPU」と結論したが、**推測で着手しない**（計装で裏を取ってから）
- **stlf_probe まわり** — #4471 / #4476。インフラ寄りで chubo2 側の判定と対
- **#4478** FreeBSD の rc スクリプトが SSH 越しの restart で戻ってこない
- **Pleroma 系（Akkoma）対応の復活** — #4566（+ 検証環境 pooza/chubo2#164）。下記の専用節を参照
- **on-hold 群** — #3157 / #3877 / #4195 / #4196 / #4197 / #4229 / #4298 / #4301

### Pleroma 系（Akkoma）対応の復活トラック（2026-08-10 起票）

⚠ **2026-10-18 から設計と進み具合は [pleroma.md](pleroma.md) が正本。**総まとめは #4846（on-hold）、段階ごとのサブ Issue を 1 マイルストーンに 1 つずつ載せる（ユーザー判断）。以下は経緯。

5.0 で「削除ではなく未対応」として保留した Pleroma 系を、**Akkoma を対象に**戻す趣味枠。正本は #4566。
**動機は実用ではなく「少しずつ元の形に戻す」こと**なので、リリース作業・番組表・実況まわりより常に後回しでよい。

- ⚠ **対象は Akkoma で確定。Pleroma ではない。**2026-08-10 実測で Akkoma は v3.20.0（08-08）と 2〜3 か月ごと、Pleroma 本体は 2.10.2（2026-05-03）止まり。API・DB スキーマとも互換なので**実装は Pleroma 互換 1 系統・検証は Akkoma**
- ⚠ **めいすきーは見送り（再提案しない）。**10.102.x は Misskey v10 ベース＝**MongoDB** で、復活は `ginseng-mongo` と Mongo スタックを Gemfile へ戻すことを意味する
- **足りないのは DB 直読み層だけ。**v5-plan は Akkoma を「Mastodon 系（`MastodonController` 担当）」に分類しており API はほぼ互換。一方 DB は `users` / `objects` / `activities` / `oauth_tokens` で Mastodon の `accounts` / `statuses` とは別物
- 抽象化の縫い目は生きている（`controller_name.camelize` → constantize、`sns_type` 分岐は app 全体で 20 箇所）。除去コミット #4031 / #4033 / #4034 から `git show 46c4f4e2^:<path>` で復元できる
- ⚠ **`Ginseng::Fediverse::PleromaService` は gem 側に残っているが最終更新 2024-09-16。**この 2 年ぶんの `MastodonService` の変化に追随できているかは未検証
- ✅ **検証環境は 2026-10-10 に建った＝着手のブロッカーは解消**（2026-10-11 ユーザー確認）。dev29 `https://st.akkoma.b-shock.org`
  （Akkoma 3.20.1・OTP リリース・Ubuntu 26.04 の LXC・2 vCPU / 2GB・新規登録は閉じてある・管理者 `pooza`）。構成と踏んだ点は chubo2
  `docs/infra-servers.md`「dev29（Akkoma ステージング）」、経緯は `docs/infra-history.md` の 2026-10-10 の節。
  ⚠ **マイルストーンは 5.43.0 のまま動かさない**（ユーザー「変えなくていい」）。作業を始められる状態になった、というだけで、急ぐ理由は増えていない。
  **最初の一歩は dev29 へのモロヘイヤの設置**（pooza/chubo2#164 の残り）
- ~~**CT が先。**~~ 検証環境が無いまま足すと、3 系統目が「走っていないのに緑」になり #4503 で潰した状態が復活する（→ 上のとおり解消）

ここに無い版（5.37.x 以前）のリリースノートは [release-history.md](archive/release-history.md) を参照。

## セッション開始時の同期手順

⚠ **手順は `sync` スキル（[.claude/skills/sync/SKILL.md](../.claude/skills/sync/SKILL.md)）へ移した**（#4731・2026-09-29）。
「進捗を同期してください」で起動する。ginseng-\* のピンのずれと Sentry のコメント 0 件の確認は、スキルに同梱したスクリプトで回す。
⚠ 履歴の中の「同期手順 §6-1」などの節番号は、スキルの番号のまま通る。

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
- [pleroma.md](pleroma.md) — Pleroma 系（Akkoma）対応の設計と進み具合（**進捗はこの表で管理**・2026-10-18）

### 手順（Claude Code のスキル・`.claude/skills/`）

名前のついた手順書は #4731 でスキルへ移した。**正本はスキル**で、docs の同名の節はポインタ。

- [sync](../.claude/skills/sync/SKILL.md) — セッション開始時の同期（「進捗を同期してください」で起動）。スクリプト 2 本を同梱
- [release](../.claude/skills/release/SKILL.md) — 通常リリース・ホットフィックス（`/release` でのみ起動）
- [release-review](../.claude/skills/release-review/SKILL.md) — リリース前の 5 観点並列レビュー（`/release-review` でのみ起動）
- [harness-gate](../.claude/skills/harness-gate/SKILL.md) — harness 実走（リリースゲート）と upstream 版の検証
- ⚠ **`media-catalog-index-plan.md` は 2026-09-08 に [media_catalog.md](media_catalog.md) の「性能トラックの記録」へ統合した**（正本を 1 本にするため）。内容は削らず全量を移してある

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

⚠⚠ **`Gemfile.lock` は CI の lint を縛らない。**bundle install ステップが
`bundle exec rake bundle:update` を回すので、**毎回その時点の最新へ解決し直す**。
🔴 **rubocop の新版が新しい cop を持ってくると、こちらが 1 行も変えていない日に CI が赤くなる**
（2026-08-25 前後に 1.90.0 が `Style/DirectiveScope` を追加し、develop が 4 日間赤のまま滞留した）。

⚠ **docs だけのコミットでも push 後に run を見ること。**コードを触っていない日は
「自分の変更のせい」の疑いが立たないので、**赤が誰にも見られずに積み上がる。**

### CI の緑が意味しないこと（#4503）

CI には SNS の実サーバーも Mastodon の Postgres も無い。`Ginseng::TestCase#run_test` は
`disable?` のケースを **omission** として報告する（pooza/ginseng-core#488）ので実行されていない
ことは出力に現れるが、**test-unit はそれでも `100% passed` と表示する**。実測で
**929 tests 中 313 件が omission**（= 一度も実行されていない。2026-08-09 の CI 実測は
mastodon 313 件 / misskey 302 件）。

- **CI の緑をリリース判断の根拠にしない。**実サーバーを要する範囲（`user_config` /
  `compose_template` / handler 系など）は、chubo2 fedi-test-harness の実走でしか検証できない。
  リリース手順に必須ゲートとして組み込んである
- CI は毎回ジョブサマリに集計行と omission 件数を出す。**omission が
  `.github/workflows/test.yml` の `omission_baseline` を超えると CI が落ちる**。
  実行されないテストが黙って増えるのを止めるためのラチェットなので、意図して増やしたときは
  baseline を実測に合わせて更新する

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

⚠ **手順は `release` スキル（[.claude/skills/release/SKILL.md](../.claude/skills/release/SKILL.md)）へ移した**（#4731）。
モデルからは起動しない（`disable-model-invocation`）。`/release` で呼ぶ。
⚠ harness 実走（`harness-gate` スキル）とステージング 4 台の検証は**省略不可**。「リリース後の更新」4 項目も全部踏む。

### リリース前レビュー

⚠ **手順は `release-review` スキル（[.claude/skills/release-review/SKILL.md](../.claude/skills/release-review/SKILL.md)）へ移した**（#4731）。
5 観点の並列レビュー、指摘の行き先（深刻度 × 工数、⚠⚠ 黄・緑を単独で起票しない）、棚を減らす弁はスキルにある。

### ホットフィックス手順

⚠ **手順は `release` スキル（[.claude/skills/release/SKILL.md](../.claude/skills/release/SKILL.md)）へ移した**（#4731）。
⚠⚠ main から切ったら **develop へ戻す**のを飛ばさない（5.37.1 で踏んだ。詳細はスキル）。
バージョンの正本は `config/application.yaml` の `/mulukhiya/version`。

### マイルストーン管理

5観点並列レビュー導入（5.19.0〜）以降、レビュー由来の小粒 Issue（仕様補足・docs 修正・単発バリデーション）が大量に発生するようになり、件数では実態を反映しなくなった。**サイズラベル + 重み予算**で管理する。

#### サイズラベルと重み予算

⚠ **正本は [pooza/ginseng-style](https://github.com/pooza/ginseng-style) の `docs/workflow.md`**（`size:S` = 1 / `size:M` = 3 / `size:L` = 8、1 マイルストーンの目安 20〜25 重み）。

モロヘイヤ固有の補足:

- 目安の 20〜25 は、従来「10 件前後」と接続する感覚値（M を基準に S が混在する想定）
- 上限を超えそうな Issue は次のマイナーバージョンへ送る（緑送り扱い）

#### 主軸宣言（任意）

テーマ性の強いリリース（番組表フェーズ系・大規模リファクタ等）では、`size:L` を 1〜2 件「主軸」として「次期マイルストーン」節の冒頭に置く。テーマ性が薄い回（複数系統の集積）は宣言なしで重み合計だけ守る。

モロヘイヤはバックエンド・プロキシの性質上、複数クライアント（capsicum / 純正 WebUI / 外部連携）の要求が並列で来るため、テーマレス回が多い前提で運用する。

### リリースノート

- 定型フォーマットは [release-notes-template.md](release-notes-template.md) を使う（5.18.0 / 5.19.0 形式）。ホットフィックスでも同フォーマット
- セキュリティアップデート（gem のパッチ更新等）は、実質的に影響がなくてもリリースノートに記載する
- 「アップグレード手順」には[更新手順](https://github.com/pooza/mulukhiya-toot-proxy/wiki/%E6%9B%B4%E6%96%B0%E6%89%8B%E9%A0%86)Wikiへのリンクを毎回含める。加えて4.x系ユーザー向け[アップグレードガイド](https://github.com/pooza/mulukhiya-toot-proxy/wiki/4.x-%E2%86%92-5.0-%E3%82%A2%E3%83%83%E3%83%97%E3%82%B0%E3%83%AC%E3%83%BC%E3%83%89%E3%82%AC%E3%82%A4%E3%83%89)へのリンクも当分含める

### Dependabot運用

⚠⚠ **5.37.0 (#4702 / PR #4716) で develop 側の方針が変わった。**
⚠⚠ **5.39.0（#4702 の決着・2026-09-24）で `ginseng-*` を version update の対象から外した。**

| target-branch | version update | 備考 |
| --- | --- | --- |
| `v4` | ⚠ **無効**（`open-pull-requests-limit: 0`） | 保守はバックポート方針なので据え置き |
| `develop` | ✅ **有効**（上限 1 本） | `others` 1 本に束ねる。⚠ **`ginseng-*` は `ignore` で対象外** |

- ⚠⚠ **`ginseng-*` の版上げは同期手順 §6-1 だけが受け皿。**dependabot の PR は「どの版を・どの回で」を
  持てないので、**判断と一致すれば Issue と二重、一致しなければ閉じる**だけだった
  （PR #4752 は core v1.24.0（宛先は v1.25.0）/ fediverse v3.0.0（v3.1.0 を 5.40.0）/ redis を 1 本に束ねていた）。
  ginseng は自走でタグが頻繁に切られるので、**寝かせている間に作り直しと close が繰り返される**。
  ⚠ **凍結はしない**（#4702 が心配した点）— §6-1 が毎回ずれを拾っている
- ⚠ 止め方は **`ignore`（`update-types` 無し＝全種別）**。`allow` で絞ると security update まで止まる。
  どちらも `test/unit/lib/dependabot_config.rb` が見ている

- ⚠ **`.github/dependabot.yml` は既定ブランチ（`main`）のものが読まれる。**`target-branch` は
  PR の宛先で、設定の読み先ではない。**develop で変えても `main` に入るまで効かない**
- ⚠ **`versioning-strategy: increase-if-necessary`**。ginseng の `tag:` を上げるために入れた設定だが、
  ginseng を外した後も実害が無いので据え置き
- ⚠⚠ **`Gemfile` で `~>` の上限を置いた gem は `ignore` で据え置く**（json / rack / sinatra ほか 7 本）。
  **上限を足した・外したら `ignore` も直す**——ずれは `test/unit/lib/dependabot_config.rb` が捕まえる
- ⚠ `ignore` も `open-pull-requests-limit` も **security update には効かない**（脆弱性の PR は常に出る）
- 上限の内側の版上げ・ginseng 以外の定例更新は、従来どおり手動 `bundle update` でもよい
- セキュリティPRへの対応:
  - `bundle update` で既に対応済み → PRをCloseし「Already included via bundle update in commit xxxxx」とコメント
  - 未対応 → PRをマージ
- セキュリティアラートはリリース時の Gemfile.lock 更新で自動クローズされる
- `target-branch`: v4（4.x向け）と develop（5.x向け）の2エントリ
- **bundler-audit**: `rake lint` に統合済み。RubyGems ソースの gem の既知脆弱性を自動スキャンする。`ginseng-*` 系 gem は git ソースのため対象外。`ginseng-*` の依存 gem に脆弱性がある場合は、該当 gem のリポジトリで `bundle update` して対応する

### Codexレビュー確認

⚠ **手順は `sync` スキル（[.claude/skills/sync/SKILL.md](../.claude/skills/sync/SKILL.md)）の §4 へ移した**（#4731）。
要点: Codex のコメントには**返信と `+1` リアクションの両方**を付けて「完了」。

## 既知の注意事項

### rack 3.2問題

rack 3.2 + Sinatra 4.2 で「異なるアカウントの投稿として送信される」致命的問題が発生した（2025-10-12〜10-26）。
防御策（トークン整合性チェック・アカウントID検証）実装済み。rack 3.2.5 + Sinatra 4.1.1 に更新済み（#4053, #4054）。
ステージングでの同時アクセス再現テスト（#4055）完了済み（成功率100%）。
診断スクリプト: `bin/diag/concurrent_token_test.rb`。
詳細は [postmortem-2025-10-rack32.md](archive/postmortem-2025-10-rack32.md) を参照。

⚠⚠ **上限固定（`sinatra ~>4.1.0` / `rack ~>3.1.14`）は 2026-08-09 の #4508 で外れている。**
🔴 **外れた原因は、上限の由来が `ginseng-web` の gemspec に書かれていなかったこと**（コメントは
一貫して下限の理由である `# CVE-2024-21510` だった）。⚠ **advisory はこの事故を知らない**
（原因未特定で CVE になっていない）。**advisory だけで床を決めない。**

- **本番 4 台は `sinatra 4.2.1` / `rack 3.2.7`。**⚠ **`token_mismatch` は 2026-08-28 の実測で 0 件**
  （ログ保持 9 日ぶん・08-23 のニチアサ実況を含む）。**「再発していない」であって「起きない」ではない**
- **版の制約を `ginseng-web` からこちらへ移す作業が #4663。**⚠ `ginseng-web` の `lib/` は
  `sinatra` / `rack` / `rack-session` / `tilt` を一行も使っていないのに、gemspec だけが宣言を持っている
- ⚠⚠ **この 4 つと `puma` を触るときは、系列をまたぐなら「下限を上げるだけ」でも同時アクセステストを通す。**
  🔴 **事故のときの指定がまさに `sinatra >=4.2.0` だった**
- ⚠ `verify_token_integrity!` は `app/` にしかなく `test/` に無い。**あれは本番の防御策であって回帰テストではない**（#4663 の ③）

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

### Webhook digest は資格情報（#4655）

`POST /mulukhiya/webhook/<digest>` は **digest だけで投稿権限が通る**（`verify_webhook!` 以外に認証が無い）。
⚠⚠ **したがってパスをログへ出すと、webhook を 1 回使うたびに完全な鍵が syslog に残る。**

- 既存の掃討はどれも当たらない — `Ginseng::Logger#mask_url` は `\A<scheme>://` に一致する**値**にしか
  効かず、`SCRUBBED_LOG_PARAMS` は**パラメータのキー**しか見ず、nginx 側のパターン（#4511 の
  `access_token=` / `"i":"` / `[?&]i=`）にも当たらない
- 対策は `LogScrubber#scrub_log_path`。⚠ **マウント位置ではなく digest の形（64 桁の 16 進）で判定する。**
  webhook のパスは `config/route.yaml` で変えられるので、**接頭辞で切ると設定変更で黙って秘匿が外れる**
- ⚠ **`not_found` のボディだけは丸めない。**あれはログではなく**要求した本人へ返す値**で、
  丸めても秘匿にならず 404 のボディ（api.md の契約）が変わるだけ
- ⚠⚠ **パーセントエンコードを解いてから判定する**（PR #4664 の Codex P1）。
  🔴 **`request.path` は生のまま（`PATH_INFO` そのもの）で、Sinatra の `params[:digest]` だけが
  デコード済み。**`%61` を 1 文字混ぜるだけで**引き当ては成功するのにログには丸ごと残る**
  という抜け道が開いていた（実測で確認）。**「パスから来る値」を扱うときは常にこの非対称を疑う**
- ⚠⚠ **不正なバイト列で例外を上げない**（PR #4666 の Codex P2）。`String#match?` も
  `String#split` も不正な UTF-8 で `ArgumentError` を上げる。🔴 **`Controller#before` の
  ログ行を組む途中なので、上げると request ログが丸ごと消え、`before` の rescue に落ちて
  `@sns` 未設定のまま経路が進む**（malformed な URL 1 本で 500 にできた）。
  ⚠ **[[project_log-credential-exposure]] と同型**（gem 側でも `mask_urls_in` が同じ理由で
  マスクごと外れていた。pooza/ginseng-core#587）。区切りは `path.b.split('/')` と
  **バイト単位で見る**（`/` は ASCII なので壊れない）

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

- `Ginseng::Web::Sinatra` ラッパークラスは廃止済み（v1.3.45。**削除の出荷は 2.0.0**）
- Controller は `Sinatra::Base` を直接継承
- **現行は 2.0.0**（2026-08-28 取り込み）。⚠ major の理由は公開クラスの削除と、
  **事故構成 `rack >=3.2.3` + `sinatra >=4.2.0` を要求する打ち捨てられたタグ（`v1.4.0`〜`v1.4.4`）の追い越し**
- gemspec の宣言は `rack >=3.1.14` / `rack-session >=2.1.1` / `sinatra >=4.1.0` / `tilt >=2.1.0` / `puma >=6.4.3`
  （**すべて下限のみ・上限なし**）。⚠ **これらは `lib/` で一行も使われていない。**引き取りは #4663
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

⚠ **Ruby の書き方・テストの基本方針・表記規約の正本は [pooza/ginseng-style](https://github.com/pooza/ginseng-style) の `docs/`。** RuboCop 設定も同リポジトリの `config/rubocop.yml` を `inherit_gem` している（モロヘイヤの `.rubocop.yml` には固有の差分だけがある）。以下はモロヘイヤ固有の項目だけを置く。

- `docs/ruby.md` — 暗黙の return を使わない／論理的 2 スペース／`return` に多行チェインを繋がない理由／`disable?` パターン／文字列のエンコーディング
- `docs/writing.md` — 用語・パスとキーの書き方・⚠ マーカーの使い方
- `docs/workflow.md` — Issue 駆動・ブランチ・サイズラベルと重み予算・`ginseng-*` の変更手順

### モロヘイヤ固有

- slim_lint, erb_lint にも準拠する（`rake lint` に含まれる）
- テストの基底クラスは `Mulukhiya::TestCase`
- ハンドラー設定: `handler_config(:key)`（5.0でシンボル記法に統一完了、ネストはYAML構造で表現）

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

⚠ **正本は [pooza/ginseng-style](https://github.com/pooza/ginseng-style) の `docs/ruby.md`。** 新しい指示が出たらそちらへ追記する（モロヘイヤだけの話ではないため）。

### ドキュメント表記規約

⚠ **正本は [pooza/ginseng-style](https://github.com/pooza/ginseng-style) の `docs/writing.md`**（用語・パスとキーの書き方・⚠ マーカーの使い方・クロスリポジトリの Issue 参照）。以下はモロヘイヤ固有の呼称だけを置く。

- **ボットの呼称**: 英名（`info_bot` 等）ではなく日本語の役割名（「お知らせボット」等）を使う
