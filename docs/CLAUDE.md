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
2. [media-catalog-index-plan.md](media-catalog-index-plan.md) に従い zugoga / shallu / gomander の本番 DB に candidate A の partial index を `CONCURRENTLY` 適用
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

## リリース済み: 5.33.0（2026-08-12）

**土台テーマは「テストが実際に走っていない」の解消**で、#4503 → #4508 → #4492 の順に消化して完了した（5.32.0 から丸ごと繰り越し）。
そこへ #4524（SSRF の DNS リバインディング）・#4534（番組表の書き込みロック）・#4549 / #4559 / #4560 / #4567 が乗った回。
依存する ginseng-core は 1.15.34 → **1.16.2**（pooza/ginseng-core#499 / #503）。GitHub マイルストーンは #631。

**本番デプロイ: 4 台完了**（2026-08-12、shallu → zugoga → gomander → sweep の順。
全台 version 5.33.0 / health 200（全サブシステム OK）/ `yjit_enabled: true` / Ruby 4.0.6 据え置き）。
**5.32.1 が zugoga 限定だったことによるバージョンの不揃いは、これで解消した。**
⚠ **ただしこの不揃いを「だからリリースを急ぐべき」の根拠に使わないこと**（2026-08-12 ユーザー明示: 「不揃いは特に気にしていません」）。
揃っていない状態そのものに実害は無い。**急ぐ理由が要るときは実害のあるものを挙げる。**

デプロイで踏んだこと 3 件:

- ⚠ **`BUNDLED WITH` が 4.0.17 → 4.0.18 に上がっていた。**4 台とも `bundle install` の前に `gem install bundler -v 4.0.18` を明示した。
  ステージングで踏んだ罠（[[project_staging-app-deploy-runbook]]）が本番でもそのまま出る。**`bundle update` を含む回は毎回この確認が要る**
- ⚠ **`pgrep -f mulukhiya` では listener が漏れる。**プロセス名は `ruby: bin/listener_daemon.rb start` で `mulukhiya` を含まない。
  「生存 pid が吐いたログだけを見る」検証をこれでやると、**listener を素通ししたまま「エラー 0」と言える**。`pgrep -f "mulukhiya|listener_daemon"` で取ること
- sweep で `rbenv: cannot rehash: ~/.rbenv/shims/.rbenv-shim exists` が出た。**2026-07-09 に中断した rehash の置き土産**で他 3 台には無い。
  退避して `rbenv rehash` で解消（shim 46 本のまま）。⚠ **その直後の `bundle --version` が 2.6.9 に見えるのは正常**
  （sweep は `rbenv global = system`。リポジトリ内では `.ruby-version` により 4.0.6 + bundler 4.0.18 が選ばれる）

**本番でも実機確認を取った**（デプロイ手順を通っただけで満足しない）:

```text
--- #4574 ゼロアドレス（shallu） ---
  0.0.0.0              internal=true
  ::                   internal=true
  64:ff9b:1::7f00:1    internal=true
  255.255.255.255      internal=true
  100.64.0.1           internal=true
  公開 8.8.8.8               internal=false
  公開 2001:4860:4860::8888  internal=false
--- #4575 setnx（shallu・テスト用キー。実キー program には触れない） ---
  1st=true 2nd=false value="v1"
```

⚠ **新設した予約レンジが正当な宛先を巻き込んでいないことも確かめた**（4 台とも `Rejected host` が 0 件）。
再起動後の生存 3 プロセスが吐いたログにエラーは 4 台とも 0 行（shallu 255 行 / zugoga 213 行 / gomander 244 行 / sweep 138 行 中）。
`/mulukhiya/`・`/mulukhiya/app/program`・`/mulukhiya/api/program.ics` も 4 台とも 200。

**リリース時点の実測**: `rake test` **975 tests / 1335 assertions / 0 failures / 0 errors / 313 omissions**。
5.33.0 でテストは 954 → 975 に増えたが **omission は 313 のまま**（新規 21 件はすべて実際に走っている）なので、
CI の `omission_baseline`（mastodon 313 / misskey 302）は据え置きでよい。

### リリース前 5 観点レビュー（2026-08-12 実施・赤 2 件を是正）

5 観点を独立したサブエージェントで並列に走らせ、指摘を合流させた。**重複を畳んで実質の赤は 4 件。**
⚠ **セキュリティ観点と観測性観点が独立に同じ 2 件へ到達**した（ゼロアドレス・キャッシュ温めの競合）。裏付けとしては強い部類。

| 観点 | 赤 | 黄 | 緑 |
| --- | --- | --- | --- |
| セキュリティ | 3 | 1 | 3 |
| 並行性・ライフサイクル | 1 | 2 | 4 |
| エラー処理・観測性 | 1 | 5 | 2 |
| API 契約 | 1 | 2 | 3 |
| スタイル・規約 | 0 | 3 | 3 |

**本リリースで対応した赤 2 件**（どちらも今回の新規コード自身の穴）:

- **#4574 内部アドレス判定がゼロアドレスを素通り**（PR #4580）— `private? / loopback? / link_local?` は `0.0.0.0` と `::` にすべて false を返す。**実測で `Net::HTTP#ipaddr = "0.0.0.0"` がループバックの待受へ 200 で到達**。⚠ **ブラインドではない**（各ホップの失敗が `errors` に積まれ `reportable?` が必ず true を返すので、`Connection refused` と `Bad response NNN` の差が投稿者へ戻る＝結果の見える内部ポートスキャン）。⚠ **#4524 が作った穴ではない**（v5.32.1 の `public?` も同じ 3 述語）。#4524 が変えたのは pinning で決定的な経路になった点で、**述語を書き直したのが 5.33.0 だから塞ぐならこのリリース**
  - Codex P1（マージ前）で **RFC 8215 の local-use NAT64 prefix `64:ff9b:1::/48`** の漏れを指摘され取り込んだ。RFC 6146 の well-known prefix `64:ff9b::/96` とは**別レンジ**。⚠ この Issue 自体が「NAT64 のある環境で顕在化しうる」を理由にレンジを足しているので、片方だけ塞ぐのは筋が通らない
- **#4575 読み経路のキャッシュ温めがロックの外**（PR #4581）— `load_from_yaml` が**読み経路のまま無条件 SET** を撃つ。**#4534 は書き手同士を直列化したが、書き手 × 読み手が残っていた**（「塞いだつもりで開いていた」の 4 度目）。`program` キャッシュに TTL が無く `load` はキャッシュを優先するので、以降すべての面が旧データを返し、次の編集が YAML まで巻き戻す。⚠ **窓はミリ秒ではない**（Redis 再起動直後は死んだソケットを掴んだ最初の 1 コマンドが必ず例外になり、リトライで 1 秒以上眠る＝**デプロイ直後の編集がいちばん危ない**）。読み経路だけ `SET NX` に分けた。⚠ **読み経路をロックに載せる方向は採らない**（読みは書きより桁違いに多く 409 が跳ね上がる）

**既存の赤 2 件は別建て（#4576・5.34.0）**。`is_cat` の webfinger が無検証（リダイレクト未検証 + pinning 無し）と、webhook の `image_url` が **full-read SSRF**。⚠ **5.33.0 に積まなかった**のは、修正が全画像ハンドラと webfinger 経路に及び、**CDN への pinning は「複数 A レコードのフォールバックが効かない」既知のトレードオフを広い面へ適用する**ことになるため（harness 実走込みの独立サイクルが要る＝2026-08-12 ユーザー判断）。

**黄・緑の受け皿は用途別に 3 本**: #4577（観測性 4 件）／ #4578（`views/*.slim` 16 本が未 lint）／ #4579（409 の恒久・一過性が判別できない）。

#### ⚠ サブエージェントの報告をコードで検証せずに写して、危険な docs を書いた

api.md に「Annict の staleness で載らなかったときは**再実行すれば解決する**」と書いたが、**従うとデータがずれる**（PR #4582 の Codex P1 で発覚、`20c872de` で是正）。

`increment_episode` のロック内は **①話数 +1 → ②`annict_episode_id` を nil → ③`next_on` を 7 日前進 → ④`annict_applicable?` の判定 → ⑤`save`（無条件）** の順で、**ガードが閉じるのは ④ の「Annict メタデータを載せるか」だけ**。増分そのものは成功して保存済みなので、再実行すると**話数を飛ばして日付が 7 日ずれる**。正しくは `PUT /admin/program/entry/:key` で補う。

**赤 4 件は実コードと実測で裏を取ったのに、黄 1 件を素通しした。**サブエージェントの結論は額面どおり受け取らない、が観点ごとに緩まないようにする。同じ誤りを写していた #4579 / #4577 にも訂正コメントを入れてある。

### ステージング検証・2 回目（2026-08-12・レビュー是正後・**4 台とも緑**）

赤 2 件の是正を含む `dd85ee7b` を dev24-27 へ再適用。**4 台とも version 5.33.0・health 200（全サブシステム OK）・
WebUI 200・番組表エディタ 200**。⚠ **再起動後のプロセスが吐いたログに新しいエラー署名は無い**
（生存 pid で絞って確認。残るのは GAS の HEAD 403 と #4573 の辞書エラーで、いずれも既存事象）。

**是正 2 件が実機で効いていることを dev25 で直接確認した**（手順を通っただけで満足しない）:

```text
--- #4574 ゼロアドレス ---
  0.0.0.0              internal=true
  ::                   internal=true
  64:ff9b:1::7f00:1    internal=true
  公開: 8.8.8.8 internal=false
--- #4575 setnx ---
  1st=true 2nd=false value="v1"
```

### ⚠ 旧: ステージング検証・1 回目（2026-08-12・4 台とも緑・**レビュー是正前の記録**）

`develop` の HEAD（`640ee959`）を dev24 美食丼 / dev25 キュアスタ！ / dev26 デルムリン丼（Mastodon）/ dev27 ダイスキー（Misskey）へ適用。
**4 台とも version 5.33.0・`/mulukhiya/api/health` 200（redis / sidekiq / postgres / streaming すべて OK）・WebUI 200**、
番組表エディタ（`/mulukhiya/app/program`）と `.ics`（`/mulukhiya/api/program.ics`）も 200。
**再起動後のプロセスが吐いたログにエラーは 1 行も無い**（生存 pid で grep して確認。再起動前の pid が吐いた辞書取得エラーは 5.32.0 時点からの既存事象）。

- ⚠ **`Gemfile.lock` の `BUNDLED WITH` が 4.0.18 に上がっている**（`640ee959`）のに 4 台の bundler は 4.0.17 だった。
  **FreeBSD では bundler の自己インストール → 再 exec が `/bin/sh` へフォールバックして落ちる**（[[project_staging-app-deploy-runbook]] の既知の罠）ので、
  `bundle install` の前に `gem install bundler -v 4.0.18` を明示した。**`bundle update` を含む回のデプロイでは毎回この確認が要る**
- ⚠ **ssh 越しに `service mulukhiya-listener restart` を素で叩くとセッションが返ってこない**。
  デーモンが ssh の stdout を握ったままになるため。`</dev/null >/dev/null 2>&1` を付けること（health は別セッションから叩けば確認できる）
- dev24-26 は monit が `/mulukhiya/api/health` を 3 サイクル監視して 3 サービスを再起動する構成なので、
  デプロイ中は `monit unmonitor mulukhiya` → 完了後 `monit monitor mulukhiya` で挟んだ。⚠ **`monit monitor` の反映は次サイクル**（直後の summary は `monitor pending` と出る）
- dev27 の `yjit_enabled: false` は既知の欠落（pooza/chubo2#123）で退行ではない。dev24-26 は `yjit_enabled: true`

**モンキーテスト待ち**: #4534（番組表の書き込みロック）と #4560（`warn` の JSON 化・マスキング）は
ステージングで目視できるためクローズせず開けてある。確認項目は各 Issue のコメントが正本。

### harness 実走ゲート（2026-08-12 再実走・**「新規の失敗ゼロ」で非ブロック化**）

レビュー是正後の HEAD（`2c69bb31`）で両系を再実走。**両系 0 failures は満たせていない**が、
**#4508 の前例（「既知集合と完全一致 = 新規の失敗ゼロ」で通す）に倣って非ブロック化した**（2026-08-12 ユーザー判断）。

| 系 | 結果 |
| --- | --- |
| Mastodon（`tagging_dictionary` 空） | **1050 tests / 0 failures / 0 errors** / 152 omissions |
| Mastodon（キャッシュ温） | 1050 tests / 1 failures（`RemoteTagHandlerTest`） |
| Misskey（キャッシュ空・3 回） | 1053 tests / **1 failures**（`RemoteTagHandlerTest`）/ 0 errors / 141 omissions |

**非ブロック化の根拠は A/B。**`tagging_dictionary` をクリアしたうえで**同一コミットを連続実行**して比較し、
是正前 HEAD（`640ee959`）でも Misskey 2/2 で同じく落ちることを確認した（現行は 3/3）。**新規の失敗ではない。**
受け皿は **#4584**（`キュアスタ!` が reject される・原因未特定）。

#### ⚠ この日踏んだ落とし穴 2 つ（#4583 / #4584 として起票）

- **`tagging_dictionary` が TTL 無し（実測 `TTL` = -1）で Redis に居座り、実行をまたいでもコミットを切り替えても残る。**
  **ゲートの結果が「前に一度回したか」で変わる**（同一コミット・同一 harness で 0 failures → 1 failures）。
  当面は **実走の前に `redis-cli -n 1 UNLINK tagging_dictionary`** を踏む。#4503 / #4559 と同じ「守れているつもりの緑」型 → **#4583**
  （⚠ **2026-08-15 着地。以降この手作業は不要**でスイートのロード時に自動で捨てる）
- ⚠ **A/B はコミットを交互に変えるだけでは足りない。**`DictionaryTagHandlerTest` を「5.33.0 の退行」と判断しかけた。
  交互に 4 回回すと 2→1→2→1 ときれいに再現したが、**同一コミットを 2 回続けて**回すと 2→1 と揺れた。
  **run 単位の状態依存とコミット差は、同一コミットの連続実行を入れないと区別できない。**

### ⚠ 旧: harness 実走ゲート（2026-08-11・両系緑で通過・**レビュー是正前の記録**）

同一 HEAD（`develop` = #4572 マージ後）で両系を実走。**判定基準（両系 0 failures / 0 errors、`TestHarness: controller=` が狙った系と一致）をいずれも満たす。**

| 系 | 結果 | announce |
| --- | --- | --- |
| Mastodon（harness v4.6.5） | **1042 tests / 2079 assertions / 0 failures / 0 errors / 152 omissions** | `controller=mastodon url=http://localhost:3000` |
| Misskey（harness 2026.7.0） | **1045 tests / 2112 assertions / 0 failures / 0 errors / 141 omissions** | `controller=misskey url=http://localhost:3000` |

omission は両系とも 2026-08-09 の参考値（152 / 141）と**完全一致**。tests が参考値（1001 / 1004）より増えているのは #4534 系列で 16 件足したぶんとシード差。上流バージョンの昇格は伴わないので台帳（harness-verified-versions.yaml）は据え置き。

#### ⚠ この日踏んだ落とし穴 3 つ（次回も踏む）

- **両ハーネスは同時に起動できない。**Misskey ハーネスも `MISSKEY_PORT=3000` で Mastodon と衝突する。**片方を `teardown.sh` してからもう片方を `setup.sh`**（`setup.sh` は 1 系あたり 8〜9 分）。⚠ **`url=` は両系とも `localhost:3000` なので取り違えの判別に使えない。`controller=` の側を見ること**（#4559 のドキュメント例にある `:3001` は実態と違う）
- ⚠ **系の分離に `env -i` を使うなら `LANG` を残す。**落とすと Ruby の外部エンコーディングが US-ASCII になり、**製品と無関係な `invalid byte sequence in US-ASCII` が 6 件（1 failures / 5 errors）出る**。退行と読み違えかけた。`env -i HOME PATH TERM LANG LC_ALL` で足りる（`MASTODON_count=0` を実走前に出して分離も確かめた）
- ⚠ **Mastodon 実走中に出る `TestHarness: DB 接続に失敗したためスキップ: ... password authentication failed for user "u"` は正常。**`TestHarnessTest` が配線を検証するために**わざと偽 DSN（`postgres://u:p@…`）を差している**もので、環境の不備ではない。DB 依存テストは実際に走っている（omission が 313 → 152 に減っているのが証拠）

### 着地済み: #4534 番組表の書き込みが無ロックの read-modify-write（2026-08-11）

**5.32.0 で意図的に見送っていた最後の実装項目。**「実況が使う書き込み経路そのものにロックを入れる変更」なので、ニチアサ（次は 08-16）まで runway のあるタイミングで入れた。

- `ProgramLockStorage` を新設。`ComposeTemplateLockStorage`（#4457 / #4460）と同型（`SET NX EX` + compare-and-delete + fail-open、TTL は**定数** 30 秒）。番組表はインスタンスに 1 つなので key も 1 つ
- 編集 4 メソッドは `lock.synchronize` の内側で `fetcher.save` を直接呼ぶ。⚠ **公開 `save` 経由にすると自分のロックと衝突する**
- **`save` もロックに載せた。**auto_update の pull（`ProgramUpdateWorker`）とエディタの編集は同じ YAML / Redis を触るので、別ロックにすると交差する
- `ProgramUpdateWorker` は競合を **alert に上げず**次の周回へ送る（every 1m で追いつく。直列化が意図どおり働いた結果を毎分 Sentry に流すのは #4542 と同型）
- ⚠ **ロックの正テストを `ProgramTest` に置かなかった。**あちらの `disable?` は `livecure?`（`var/program.yaml` が在るか `/program/urls` が設定されているか）で丸ごと倒れるので、番組表を持たない環境では**一度も走らない**（#4549 で `absolute_uri` をクラスメソッドへ出したのと同じ理由）。`ProgramWriteLockTest` として独立させた
  - ⚠ **例外クラスだけでなくメッセージまで見る。**`auto_update` の 409 も `ConflictError` なので、クラスだけだと**ロックが無くても緑になる**
  - ⚠ このテストは書き込みを 1 つも成功させない（全ケースがロック獲得の時点で倒れる）ので、`var/program.yaml` も Redis も触らない

#### ⚠ 初版は Annict をロックの内側に置いていた（同日中に是正・PR #4571）

**「話数の +1 とサブタイトルの解決は不可分だから」という理由で内側に置いたのは誤り**だった（PR #4569 の Codex P2）。

- `/service/annict/timeout: 5` は **open と read の双方**に効くので、3 回で素直に **TTL(30 秒) に届く**。ロックが先に失効すると別の編集が獲得でき、そこへ元のリクエストが書き戻して**塞いだはずの lost update がそのまま戻る**
- ⚠ **TTL を伸ばす手は採らない。**プロセスが死んだときに編集が止まる時間もそのまま伸びる
- ⚠ **ロックを持っている区間にネットワーク I/O を入れない**、が一般則。Annict はロックの外で先に引き、**「引いた時点の話数と作品 ID」を持ち回ってロックの中で一致を確かめる**。判定は純関数 `annict_applicable?` に出し、`ProgramAnnictStalenessTest` で検証する
  - ⚠ **話数だけでは足りない**（PR #4571 の Codex P2 → PR #4572）。`ProgramEntryUpdateContract` は `annict_work_id` の変更を許しているので、待っている間に作品を差し替えられると**話数は同じだが別作品**になり、旧作品のサブタイトルが載る。**照合は話数と作品 ID の両方**
- ⚠ **存在チェックの正本はロックの中に残す。**外で `NotFoundError` を上げると、**ロック競合より先に 404 を返す**ようになり `ProgramWriteLockTest` が実際に落ちた
- 付随: `persist` を潰して `fetcher.save` 直呼びにした。⚠ **`Metrics/ClassLength` の上限 200 行に合わせるための削りであって設計判断ではない。**この学びを踏まえ、PR #4572 で 201 行になった際は**同じ捻出をせず inline disable で明示**した。正しい直し方（参照系と編集系の分離）は **#4570**

⚠ **この #4534 の系列は「塞いだつもりで開いていた」が 3 連続で出た**（TTL 超過 → 作品 ID 未照合）。**ロックや排他を入れる変更は、入れた直後の Codex 追撃まで込みで 1 セットと見る。**

### 着地済み: #4567 route-not-found 以外の 404 を omit していた（2026-08-11）

PR #4557 の Codex P2。**2026-08-10 の棚卸し（直近 8 PR 横断）でも取り残されていた**もので、同期のリアクション 0 走査で拾った。`endpoint_missing?` が `statusCode == 404` だけを見ていたため、ルートには届いたうえで参照先が無い 404 まで「エンドポイント未提供」として omit し、webhook のルーティング退行を飲みうる状態だった。

⚠ **初版（PR #4568）の `message` 部分一致でも足りず、同日中に是正した**（PR #4568 の Codex P2 → PR #4571）。ハンドラが同じ Fastify 包絡で `Webhook <path> not found` を返すと path を含むので一致し、**ルートは在るのに omit する**。route-miss の文面ごと（`Route POST:<path> not found`）突き合わせる。`Webhook#command` は必ず POST なのでメソッド名も固定でよい。

⚠ 文言が将来ずれた場合は omit されず **assert で赤くなる**方向に倒れる。実退行を飲むより検証条件のズレに気づけるほうを採った。

### Codex レビューの棚卸し（2026-08-11）

**⚠ 前日「直近 8 PR を横断で走査し全件処理した」と記録したのに、PR #4557 の P2 が 1 件リアクション 0 で残っていた。**同じセッション中に PR をマージし続けると、走査の後に着いたコメントがそのまま落ちる。さらに本日マージした PR #4568 / #4569 の**両方**にマージ直後 P2 が届いた（どちらも実質的な穴で、同セッション中に PR #4571 で消化）。

**PR を出したセッションは、締める直前にもう一度リアクション 0 走査を回すこと。**「棚卸し済み」は次セッションへの免罪符にならない。

### 着地済み: #4524 SSRF allowlist の DNS リバインディング（2026-08-10）

**「名前で検証して名前で接続する」構造そのものを畳んだ。**`RemoteHost.public?` は解決結果を真偽値に潰していたので、権威 DNS を握った相手が検証時だけ公開 IP アドレスを返し、接続時に 127.0.0.1 を返せた（TOCTOU）。**#4410 のホップ検証も #4523 のプリフライト検証も、この構造がある限り素通りできる。**

- `RemoteHost.allowed_address` を新設し、`validator` は**真偽値でなく接続先の IP アドレス** を返す。ginseng-core 1.16.0 が文字列を受けると `Net::HTTP#ipaddr=` で接続先を固定する（pooza/ginseng-core#503 / PR #504、`Ginseng::PinnedAddressAdapter`）
- ⚠ **`ipaddr=` は接続先だけを差し替える。**`Host:` ヘッダと TLS の SNI・証明書検証はホスト名のままなので HTTPS の検証は壊れない
- ⚠ **pinning はホップごとに付け替える**（リダイレクト先は別ホスト）
- ⚠ **IPv4 があれば IPv4 を採る。**`getaddresses` は A と AAAA を混ぜて返すので素直に先頭を採ると IPv6 を掴む（#4464 で踏んだ `::1` の 305ms と同型）
- **トレードオフ**: アドレスを 1 本に固定するので、**複数 A レコードのフォールバックは効かなくなる**。対象は管理者が設定した少数の URL なので許容した
- ⚠ 拒否の戻りが **`false` → `nil`** に変わった。呼び出し元はいずれも真偽で判定しているので falsy であればよい

**マージ後に Codex の P1 が 2 件届き、同日中に是正した（PR #4565 / pooza/ginseng-core#505、1.16.1）。どちらも「塞いだつもりで開いていた」型。**

- **短縮 URL の展開だけ pinning を素通りしていた** — `ShortenedURLHandler#permitted_host?` が validator の戻り（IP アドレス）を捨て、`fetch_redirect` は名前で GET し直していた。⚠ **ここは `host_validator` に任せられない**（あちらは追従まで肩代わりして最終レスポンスだけ返すので展開先が取れない）。**追うのがこちらである以上、pinning もこちらの責務**
- **プロキシ経由では pinning が効かない** — `Net::HTTP#connect` は `proxy?` のとき `@ipaddr` を見ずプロキシへ繋ぎ、平文なら絶対 URI・HTTPS なら CONNECT でホスト名を渡す。**名前を解決するのはプロキシ**なのでリバインディングは成立する。fail-closed にした。⚠ `Net::HTTP.new` の proxy 引数は既定が `:ENV` なので、`http_proxy` を置いた環境では**明示していなくても**該当する
  - さらに P2 で「その拒否を `repeat` が 5 回叩き直す」（上流レスポンスの無い `GatewayError` は `source_status` が 502 = 一時障害と読まれる）ことが判明し、`Ginseng::PinningError` を新設して非再送に（pooza/ginseng-core#506、**1.16.2**）。⚠ **設定起因の失敗を再送で解決しようとしない**

### 5.31.0 レビュー由来の受け皿 Issue

5.32.0 で **#4535 / #4536 と #4537 の 1・4**、2026-08-10 に **#4537 の 2・3・5・6**（PR #4563）を消化した。残りは 1 本。

- **#4534** 番組表書き込みの無ロック RMW（サーバー側ロック・size:M）。**5.32.0 では意図的に見送った**（実況が使う書き込み経路そのものにロックを入れる変更で、二度押しは #4533 でクライアント側が塞いである）
- **#4537 の 2・3・5・6（着地）** — Spotify の `invalid_request` を運用側不備に分類（⚠ `Ginseng::AuthError` は **403**、401 ではない）／`webhook.url` を `available?` で nullable 化／効かない `silent_statuses: [413]` の撤去・透過を Hash 限定に・`source_body` のメモ化（ginseng-core 1.15.37）／`Mulukhiya::ForeignGatewayError` を新設し、**引用元（他人のサーバー）由来は #4480 の透過に乗せない**
  - ⚠ **ForeignGatewayError は現状どの経路からもリクエスト層へ届かない**（呼び出し元がすべて degrade する）。「届いたときに透過されない」不変条件を型で担保するためのもの

### Codex レビューの棚卸し（2026-08-10）

直近マージ 8 PR を横断でリアクション 0 走査（[[feedback_codex-review-window-too-narrow]]）。**取り残し 8 件（5 PR ぶん）**があり、全件に返信 + リアクションを付けて処理した。受け皿は 3 本で、**うち 2 本は同日中に着地**。

- **#4558 番組表の `next_on` に `Time` を手書きすると Redis キャッシュ往復で無効値になる（保留中）** — PR #4546 P1 / #4548 P2。**素の Ruby で再現済み。**`load_from_yaml` が coerce 前の生ハッシュを `update_cache` に渡すため、Redis には `"2026-08-08 18:00:00 +0900"` が入る。**1 回目（キャッシュミス）だけ正しく、2 回目以降は無効値**になって VEVENT が黙って消える。⚠ **キャッシュ層を挟むと上流の正規化が静かに外れる**のは #4549（`base_uri` の相対解決）と同型。あわせて `format_date` の無条件 `getutc` が明示オフセット付きの値を 1 日ずらす件（PR #4546 P2、`2026-08-08 00:30:00 +09:00` → 08-07）と、まとめコピーの見出しが `2026-02-31 (火)` と存在しない日付に曜日を付ける件（PR #4548 P2）も同 Issue へ
  - ⚠ **本番が実際に踏んでいるかは未確認**（VPN が繋がらず `var/program.yaml` を見られなかった）。ユーザー判断で**着手を保留**している。修正自体は単体テストで閉じるので、本番確認を待たずに書ける
- **#4559 リリースゲートの穴 2 件（着地・PR #4561）** — PR #4555 P1 / P2。①同じシェルで両系を source すると `MASTODON_*` が残り、**Misskey のつもりで Mastodon を 2 回走らせたまま「両系緑」と記録できる**（選択ルールは「手順（Misskey）」節にあるがゲートの節には無い）②omission 集計をパースできないと warning のまま success で、#4503 のラチェットが黙って無効化される
  - **選択ルール自体は変えていない。**`TestHarness#announce` が run の頭で `TestHarness: controller=... url=...` を stderr に出すようにし、**取り違えに気づける手段を足す**方向で直した。ゲートの判定基準にも「この行が狙った系と一致していること」を追加
  - 集計不能は `steps.test.outcome` で切り分けて fail closed。⚠ **テスト自体が落ちている run では追撃しない**（前段のステップが既に赤い）
- **#4560 `logger.warn` がマスキング層を通らない + `unresolved_enclosures` が伸び続ける（着地・PR #4562）** — PR #4551 P1 は**却下（👎）**。`Ginseng::Logger < Syslog::Logger` なので `warn` は存在し `NoMethodError` にはならない。ただし `Ginseng::Logger` が上書きしているのは **`info` と `error` だけ**で、`warn` は `create_message` を通らず **JSON 化もマスキング（#4511 / #4533）もされない**（4 箇所、うち 1 つは URL を載せる）
  - 直したのは ginseng-core 側（pooza/ginseng-core#499 → PR #500 / #501、**1.15.36**）。⚠ **呼び出し側を `info` に書き換えて回るのは対症療法**。severity は syslog の重要度として正当な使い分け
  - ⚠ **初版（#500）は `message` を必須引数にしていて、ブロック形式 `logger.warn {expensive}` を `ArgumentError` で殺していた**（Codex P2）。#501 で省略可能引数 + ブロックへ戻し、severity 無効時はブロックを評価しない形に是正。**マージ直後に Codex が指摘 → 同セッションで是正**の流れが機能した例
  - PR #4550 P2 側は `RSS20FeedRenderer#render` を新設して 1 レンダーぶんにスコープ。⚠ **テストは `RSS20FeedRendererTest` に置かない**（DBMS 無しでケースごと omit され一度も走らない。#4549 で `absolute_uri` をクラスメソッドにしたのと同じ理由）。親の `initialize` を呼ばないスタブで別クラスに置いた

### 着地済み（2026-08-09）

- **#4503 test: アカウント依存のテストが CI・手元で 1 件も走っていない** — **CI で走らせる方向は採らず、harness 実走をリリースゲートとして正式化する形で決着**した。CI には SNS の実サーバーも Mastodon の Postgres も無く、`config['/mastodon/url']` は `https://ci.example.com` のダミーなので、アカウント依存テストは**構造的に**走らない。3 点で着地:
  - **報告の是正（済）**: pooza/ginseng-core#488 / #489 で `disable?` を omission 報告に。実測 **929 tests 中 313 件が omission**（それまでは pass に混ざっていた）
  - **可視化とラチェット**: CI がジョブサマリに集計行と omission 件数を出し、`.github/workflows/test.yml` の `omission_baseline` を超えたら落ちる。⚠ **test-unit は 313 件 omission でも `100% passed` と出す**ので、集計行を読まないと気づけない
  - **ゲートの明文化**: 通常リリース手順に「harness 実走（省略不可・両系 0 failures / 0 errors）」を追加。判定基準と切り分けは [test-harness.md](test-harness.md)「リリースゲートとしての実走」
- **#4508 chore: sinatra 4.2.1 / rack-protection 4.2.1 / tilt 2.8.0 へ更新** — PR #4556。pin はモロヘイヤ側でなく **`pooza/ginseng-web` の gemspec** にあったので、そちらを `~>` から `>=` へ緩めるのが前提作業だった（pooza/ginseng-web#116 / 1.3.46。CVE-2024-21510 の下限 4.1.0 は保つ）
  - ⚠ **起票時の前提が 1 つ違っていた。`mustermann 4.0.0` はこの更新では入らない**（sinatra 4.2.1 が `~>3.0` を要求する）。**メジャー跨ぎを含まない更新**だった
  - **#4503 のゲートの初適用。**Mastodon（v4.6.5）1001 tests / 0 failures / 0 errors / 152 omissions ＝基準値と完全一致、Misskey（2026.7.0）1004 tests / 3 failures（当時の #4492 の既知集合と完全一致）/ 0 errors / 139 omissions。新規の失敗ゼロ
  - 副産物: **ゲート文言「両系 0 failures」が #4492 のせいで満たせない**ことが露見した。直後に #4492 を解消したので例外は残っていない
- **#4492 test: Misskey harness で恒常的に落ちる 3 件を解消** — PR #4557。**3 件のうち 1 件は harness 側の実バグ**で pooza/chubo2#161 / #162 で直した。これで **`project_harness-zero-error-goal`（両系エラー 0）を達成**
  - ⚠ **`WebhookImageHandlerTest#test_handle_pre_webhook` は製品もテストも変更していない。**Misskey harness の `files` ボリュームが root 所有で、uid 991 の misskey が書けず drive アップロードが `EACCES` → 500 で全滅していた。**起票時の「Amazon の外部依存が原因」は誤り**（当該 URL は 200 を返していた）。harness が drive を一度も通していなかったので露見しなかった
  - `SNSServiceTest#test_access_token` — Misskey の `access_token` 行は MiAuth / OAuth の認可時にしか作られず、harness が発行するのは**ユーザー固有トークン**なのでテーブルは 0 行。honest omit に。⚠ **Mastodon は Doorkeeper のトークン行を持つので対象外**にし、素通しさせている
  - `WebhookTest#test_command` — omit ガードが HTML エラーページ前提だった。⚠ **Misskey harness は nginx を挟まない**ので Fastify が 404 の JSON 包絡を返し、ガードが素通りしていた
- **#4516 / #4552 test/bug: harness 実走で常態化していた失敗 5 件をテスト側から解消** — PR #4553。5 件とも product の退行ではなく**検証側の前提ズレ**だったので、テスト側に寄せて **1001 tests / 0 failures / 0 errors / 152 omissions（100% passed）** にした
  - `SNSServiceTest#test_info` — ⚠ **`metadata.maintainer` を出すのは Misskey だけ**。Mastodon はフォークの `pooza/mastodon` も `nodeName` / `nodeDescription` しか返さないので、**本番 3 台でも `maintainer_name` は nil**。harness 固有の欠落ではない（起票時の「harness に contact account を設定すれば直る」は誤り）。副次的に `MediaFeedRenderer` の RSS author は Mastodon で常に nil
  - `MediaFeedRendererTest#test_to_s` — omit ガードを `#fetch` の描画条件と同じ順に並べ直した。`media_catalog?` が false なら entries は空のまま返る（既定 OFF・#4343）。**harness では依然 `<item>` の描画が検証されない**ので、通したければ harness 側で `media_catalog` を有効にする必要がある（chubo2#64 の続き）
  - `ComposeTemplateContainerTest#test_write_reloads_user_config_inside_lock` — ⚠ **`Account#user_config` はメモ化される**。`TestCase#account` が返す同じインスタンスを渡すと、書き込みが成功していても最初に掴んだ空スナップショットを読む。読み直しは新しい account から行う
  - `AttachmentTest#test_catalog` — ⚠ **製品側は直さない**。`:page` の既定値補完は API 境界の `MediaCatalogQueryService#normalize` が持っており（`cursor` 指定時は付けない、も含む）、モデル側にも足すと補完が 2 箇所に分かれる。起票時の「製品側で揃える」推奨は撤回
  - `MediaMetadataStorageTest#test_push` — Amazon の実画像取得をやめ、`test/fixture/sample.jpg` を WebMock で返す。取得失敗時のネガティブキャッシュ（`{}`）が期待値と食い違って毎回ランダムに落ちていた

### 振り返り

**「塞いだつもりで開いていた」がこのリリースだけで 4 回出た。**#4534 の系列で 3 回（ロック TTL 超過 → 作品 ID 未照合 → 読み経路がロックの外）、#4524 で 2 回（短縮 URL の pinning 素通り・プロキシ経由の fail-open）。
いずれも**排他や検証を「入れた」直後**に見つかっている。**ロックや SSRF ガードを入れる変更は、入れた直後の追撃レビューまで込みで 1 セットと見る**、が実測で裏付いた。

**レビュー・harness・ステージングの 3 段が、それぞれ別のものを捕まえた。**5 観点レビューが赤 2 件（#4574 / #4575）、ステージング検証が #4573（本番で `related` 辞書 3 本が死んでいた既存事象）、harness が #4583 / #4584。**どれも他の段では出てこなかった。**

**⚠ この回でいちばん危なかったのは、コードでなく docs だった。**サブエージェントの黄 1 件を検証せずに api.md へ写し、**従うとデータがずれる手順**を書いた（Codex P1 で発覚・`20c872de` で是正）。赤 4 件は実コードと実測で裏を取ったのに、黄だから素通しした。**観点や深刻度で検証の手を緩めない。**

## リリース済み: 5.32.1（2026-08-08、ホットフィックス）

⚠ **適用したのはデルムリン丼（zugoga）だけ**（ユーザー判断・実害が出ているのがこのサーバーのみのため）。
shallu / gomander / sweep は 5.32.0 のままで、**本番のバージョンは意図的に不揃い**だった。**2026-08-12 の 5.33.0 で 4 台とも揃えて解消済み。**

- **#4549 カスタムフィードの相対 enclosure URL が解決されない** — 5.32.0 の直後に、zugoga の syslog へ
  `base_uri undefined` が**日 2 万行**積まれているのを見つけたのが端緒。追うと**ログノイズではなく機能不全**で、
  `dqdai-anime`（80 エントリ）の `<enclosure>` が **1 件しか出ていなかった**
  - 原因は、モロヘイヤ側の `RSS20FeedRenderer#fetch_image` が `MediaMetadataStorage`（base_uri を
    持たない別の `HTTP`）へ委譲したことで、基底クラスが `@http.base_uri = channel[:link]` で担っていた
    **相対 URL の解決だけが落ちていた**こと。⚠ **キャッシュ層を挟むと基底クラスの前提が静かに外れる**
  - `RSS20FeedRenderer.absolute_uri(value, base)` を新設。⚠ **クラスメソッドにしたのは意図的**で、
    インスタンスは SNS（DB）と Redis を掴むため、DBMS 未設定の環境ではテストがケースごと omit され
    **この判定が一度も走らない**（既存の `RSS20FeedRendererTest` がその状態）
  - 絶対化できなかった値は**エントリごとに出さず 1 サイクル 1 行**にまとめる（`feed enclosure url unresolved`）。
    愚直に出すと #4549 の再来になる
  - `MediaMetadataStorage#push` のネガティブキャッシュを `GatewayError` 限定から広げた。
    呼び出し元が 5 分おきに全エントリを舐め直すので、**空を置かない失敗は永久に再試行される**
- **本番適用（zugoga のみ）**: version 5.32.1 / health 200 / monit OK。適用後のサイクルで
  `base_uri undefined` が **79 → 0**、`<enclosure>` が **1 → 80**（全エントリ）になったことを実機で確認
- **残（この修正の外・スクリプトは git 管理外）**: `bin/dqdai-vjump.rb` が**エントリ 0 件**を返している
  （⚠ **スクレイパの故障と決めつけない**。「V ジャンプがダイ大を取り上げなくなっただけ」の可能性がユーザーの見立て。
  放送していた頃は動いていた）／`bin/dqdai-anime.rb` の記事リンクが `https://dq-dai.com/../news/...` と `/../` を含む

## リリース済み: 5.32.0（2026-08-08）

番組表の実用改善 2 件を主軸に、5.31.0 リリース前レビュー由来の受け皿 Issue から SSRF ハードニング・観測性・テスト信頼性の 4 件を足した回。
当初の土台テーマ（「テストが実際に走っていない」の解消 = #4503 → #4508）は**着手せず 5.33.0 へ送った**。

### 着地済み（2026-08-07）

番組表まわりの実用改善 2 件。**この実況の予定管理はこれまで Google カレンダーで行っていた**もので、`next_on` + `.ics` + tomato-shrieker が揃ってモロヘイヤ側へ寄せられる過程で見えてきた不足。

- **#4540 番組表の並び順を `next_on` → `start_time` に統一** — エディタ一覧・JSON API・まとめコピー・iCalendar の 4 面が別々の（または無指定の）順序だった。`Program.sort_key` を共通の比較規則として新設。⚠ **`Program#data` 自体は並べ替えない**（編集の read-modify-write が `var/program.yaml` の行順を書き換えるため、並べ替えは API のレスポンス経路にだけ入れる）。エディタ一覧の列順も `次回放送日` / `開始時刻` 先頭へ。まとめコピーは日付が変わる位置に `2026-08-08 (土)` の見出しを挟む（全件コピーして手で削る運用なので、削る境界が見えるほうが速い）
- **#4541 番組表エントリに説明欄を追加し `.ics` の `DESCRIPTION` として出力** — 実況の準備のための注意書きを書く欄。`DESCRIPTION` は RFC 5545 の標準プロパティで Google 独自ではなく、**tomato-shrieker の `IcalendarSource` が既に `event.description` を読んでいるため購読側は変更不要**。上限 1,000 文字（他の文字列フィールドの 200 文字とは別枠）。未設定なら `extra_tags` のハッシュタグ行、それも無ければ `DESCRIPTION` を出さない。⚠ **`.ics` は無認証で公開され投稿にも載る**ので内輪メモを置く欄ではない

### 着地済み（2026-08-08 の追加スコープ）

**「番組表だけでリリースするのはさすがに拙速」**（ユーザー、2026-08-08）を受けて、5.31.0 レビュー由来の受け皿 Issue から今日中に収まる 4 件を足した。

- **#4535 security: 短縮 URL 展開の各ホップが SSRF allowlist を通っていない** — `ShortenedURLHandler#resolve_redirects` は Location だけ見て自前で最大 8 ホップ追うが、各ホップのホストを検証していなかった。`rewritable?` が `t.co` を無条件で許すため、短縮 URL 1 本で内部エンドポイントへ GET を撃たせられる（ブラインド）。⚠ **`Ginseng::HTTP` の `host_validator` には寄せられない**（あちらはホップ追従まで肩代わりして最終レスポンスだけ返すので、展開先 URL が取れず機能自体が壊れる）。弾いた URL は **GET しないだけでなく展開結果にも採らない**（採ると投稿本文が内部 URL へ書き換わったまま連合に流れる）。あわせて番組表・読み辞書の HEAD プリフライトが allowlist 拒否まで「判定不能」として飲み `true` に倒れていたのを `RemoteHost.validate!` で是正
- **#4542 obs: ALT 編集 PUT の 404 を Sentry alert から外す** — `STATUS_UPDATE_SILENT_STATUSES = [401, 404]`。他エンドポイントも棚卸しした結果、`favourite` の 404 は 6 週で 1 件しかなく据え置き、**投稿本体（`POST /api/:version/statuses`）の 404 は抑止しない**（投稿が 404 で落ちるのは alert すべき異常）
- **#4537 の 1 と 4** — `PERMITTED_YAML_CLASSES` に `Time` を追加（`next_on: 2026-08-08 09:00:00` で番組表全体が読めなくなる footgun。⚠ **秒なしの `09:00` は Psych が String で返すので元から無害**だった）。`next_on` が過去へ落ちたエントリを `.ics` 生成時に `logger.warn`。残り（2/3/5/6）は Issue に残置
- **#4536 test: `disable_gate` の盲点** — `log` の呼び出し有無で判定していたため、`log` を呼ばず自分の例外も飲む `DecorationApplyWorker` はゲートを外しても緑だった。`ScriptError` 派生の tripwire（`rescue => e` に飲まれない）＋**`perform` の最初の実行文をソースで見る静的テスト**＋検査器自身の空振り検査を追加。ついでに `Worker.descendants` が読み込み済みクラスしか返さず**単独実行では 1 本しか列挙していなかった**のも是正

**今日は入れないと決めたもの**（再提案しない）: **#4534**（番組表の無ロック RMW・size:M。翌日の実況が使う書き込み経路そのものにロックを入れる変更で、二度押しは #4533 でクライアント側が塞いである）／**#4520**（`APIController` の 404 body・capsicum 可視の変更）／**#4524**（DNS リバインディング・`Ginseng::HTTP` 側）

### 5.31.0 からの持ち越し（決着済み）

- **Codex #4527 P2: `ClippingWorker#create_body` が上流の `GatewayError` を握り潰す** — **却下（👎、2026-08-07）**。事実関係は正しい（`uri.to_md` 由来の `GatewayError` はガードを通らず生 URL へ倒れる）が、**非対称なのは意図的**。戻り値は投稿本文なので、上流が落ちたら「リンクだけの投稿」を残すほうがよく、再 raise すると `retry: 3` を使い切って dead 送り＝投稿そのものが消える。#4480 の透過は返す相手（API クライアント）がいるリクエスト層の要求で、ワーカーには及ぼさない。ガード自体は死んでおらず、`create_status_uri` 由来（`uri` が nil）の経路で `GatewayError` の二重包絡を防いでいる。同じ指摘が再発しないよう[コード側にも理由を明記](../app/lib/mulukhiya/clipping_worker.rb)

### メンテナンス

- **bundle update** — sentry-ruby / sentry-sidekiq 6.7.0、temple 0.10.6。bundler-audit クリーン、Dependabot アラート 0

### ステージング検証・本番デプロイ

- **ステージング検証（省略不可）**: dev24 美食丼 / dev25 キュアスタ！ / dev26 デルムリン丼（Mastodon）/ dev27 ダイスキー（Misskey）全 4 台で version 5.32.0・health 200・WebUI 200・番組表エディタ 200 を確認。加えて **dev25 の実機で新経路を 2 つ実行確認**した — 短縮 URL の展開が正常系（t.co → YouTube）で通り `http://127.0.0.1:6379/` は `Rejected host` で弾かれること、`next_on` を過ぎたエントリが `.ics` から落ちて syslog に `program next_on expired` が出ること
- **本番デプロイ: 4 台完了**（2026-08-08、shallu / zugoga / gomander / sweep、全台 version 5.32.0 / health 200、FreeBSD 3 台は `yjit_enabled: true` と monit OK）。Ruby は 4 台とも 4.0.6 据え置きで `rbenv install` 不要。デプロイ後の syslog に**新しいエラー署名は出ていない**（既存の `base_uri undefined`〈zugoga・多発〉と GAS の HEAD 403 のみ）

### 振り返り

- **「番組表だけでは拙速」の判断が正しかった**。追加した 4 件のうち #4535 は pre-existing の SSRF で、#4523 の掃討で取り残していた最後の 1 本だった。レビュー由来の受け皿 Issue は溜めると腐るので、主軸が軽い回の埋め草として消化するのが噛み合う
- **⚠ zugoga の syslog に `base_uri undefined` が 13 時間で 12,720 行出ている**（本リリースとは無関係の既存事象）。Sentry には上がっていない（`e.log` 止まり）ので、Sentry の棚卸し（#4543）だけでは拾えない。syslog 側のノイズ棚卸しは別途必要

## リリース済み: 5.31.0（2026-08-07）

重篤な不具合の解消を主軸に、capsicum の後続タスクと番組表機能を束ねた回。
優先順は「**重篤な不具合 → capsicum の後続タスクがあるもの → 番組表関連**」で消化した。
依存する ginseng-core も 1.15.31 → 1.15.34 へ（pooza/ginseng-core#495 / #498）。

### 1. 重篤な不具合（主軸）

- **#4474 nginx が `X-Mulukhiya-Purpose` 付きの PUT を 405 で弾く** — 本番 3 台で capsicum からの ALT 編集が不通だった。2026-08-05 に本番 3 台 + ステージングで復旧。サンプル vhost（#4475）・docs（#4517）も着地
- **#4511 security/obs: listener が streaming URL をアクセストークン付きで平文ログに書く（size:M）** — ginseng-core 1.15.32 + `config/application.yaml` の `/logger/mask_query_params`（#4518）。**リリース前レビューで「Misskey はボディのキー `i` で渡す＝主たる載り場所が空いていた」ことが判明**し、`Controller::SCRUBBED_LOG_PARAMS` を追加（#4533）
- **#4506 並行性: `disable?` を持つ定期 worker 7 本が perform で短絡していない** — #4519。sidekiq-scheduler は `perform_async` を介さず `Sidekiq::Client.push` を直接叩くため gate を通らない
- **#4487 bug: トークン未設定のアカウントでも webhook URL が生成される（size:S）** — #4522、Codex P2（壊れた行で走査が止まる）を #4525 で追加是正
- **#4523 security: リモート取得の HEAD プリフライトが SSRF allowlist を通っていない** — #4528 + pooza/ginseng-core#495（1.15.33）。#4410 で GET は塞いだが、**その 1 行上の HEAD が素通り**していた。Codex レビューの取り残しから発見（[[feedback_codex-review-window-too-narrow]]）

インフラ側の対の課題として **pooza/chubo2#131**（pgbouncer の `max_client_conn` / `default_pool_size` が未管理・既定 100 のまま）がある。
2026-08-02 06:09 JST に `FeedUpdateWorker` が `no more connections allowed (max_client_conn)` で全滅した実績があり、**ニチアサ窓の約 2.5 時間前**だった。
モロヘイヤ側からはサブプロセス（`bin/*.rb` 19 本）の接続バーストが疑わしいので、chubo2 の調査と突き合わせる。

### 2. capsicum の後続タスク

- **#4491 docs/api.md に `POST /mulukhiya/api/status/tags` のレスポンス仕様を明記する** — #4521（capsicum#909 のブロック解除）。Codex P2（**他人の投稿は 404 ではなく 403**）を #4525 で追加是正
- **#4480 refactor: 上流エラー包絡を捨てず透過する（size:M）** — 第 1 層 pooza/ginseng-core#498（`GatewayError#response` / `#source_body`）+ 第 2・3 層 #4527。棚卸し 5 件すべて回収。**⚠ `APIController`（モロヘイヤ独自 API）の rescue は scope 外で未着手**なので Issue は open のまま
  - 🔴 **本リリース最大の破壊的変更**: ゲートウェイエラーの `error` の型が **Misskey ではオブジェクト、Mastodon では文字列**になる

### 3. 番組表関連

- **#4373 番組表エントリに「次回放送日」を持たせ iCalendar を正しい日に出す** — #4529。**仕様を起票時の `frequency` + `weekday` から `next_on`（次回放送日）1 フィールドへ変更した。**
  - ⚠ **曜日ルールは却下済み・再提案しない。** fail-open で、更新を忘れると**古い話数のまま毎週誤発火する**。価値が話数である以上それは鳴らないより悪い。`next_on` は fail-closed で黙り、エディタの警告バッジで気づける
  - デルムリン丼の公式再放送が終了し、durable な対象はキュアスタ！のウィークリー 1 枠。**この機能は実質キュアスタ！のためのもの**
  - `var/program.yaml` の YAML footgun 2 件（無クォート日付の `Psych::DisallowedClass`、`20:30` の 60 進数解釈）も同時に塗りつぶした
  - 詳細は MEMORY `project_program-ics-shelved`
- **#4484 番組表エディタの一覧表に「有効」トグルボタンを付ける（size:S）** — #4526

### リリース前 5 観点レビュー（2026-08-06 実施・是正済み）

**赤 4 件・是正は #4533。** `rake lint` 全緑、`rake test` 873 件 0 failures / 0 errors。

- **🔴 Misskey のアクセストークンが request ログに平文で残る** — `i` は Misskey が**ボディのキー**で渡すが、`/logger/mask_query_params` は URL のクエリにしか効かない。#4511 はクエリ側しか塞いでおらず、トークンの主たる載り場所が空いていた。**dev27 のログで実在を確認**。`Controller::SCRUBBED_LOG_PARAMS` に `i` / `access_token` を追加。⚠ **これを止めない限り、デプロイ後のログ掃除は掃除した端から再汚染される**
- **🔴 `docs/api.md` が #4480 / #4491 に追随していない 3 件** — ①ゲートウェイエラーの `error` が **Misskey ではオブジェクト、Mastodon では文字列**になる（5.31.0 最大の破壊的変更なのに未記載）②`favorites/create` の冪等丸めが `ALREADY_FAVORITED` 限定に変わった ③`/status/tags` は docs が「上流のステータス」なのに実装は常に 502 だった（実装を `source_status` へ揃えた）
- **不正な `next_on` の fail-closed 化** — `Date::Error` を握って**毎日扱い**へ倒れていた。曜日ルールを却下した理由がそのまま当たり、しかも毎日鳴る。エディタの stale 判定も素の文字列比較で、`2026-02-31` を「過去日（通知は止まっています）」と表示しながら実際は毎日発火していた（表示と挙動が真逆）。過去日と不正値を別バッジに分離
- **番組表エディタの二度押し防止** — 「次回」の二度押しは話数 +2・`next_on` +14 日で**その週の VEVENT が消える**。送信中は ＋ / トグル / 削除を `disabled` に

黄・緑の送り先: **#4534**（番組表書き込みの無ロック RMW・サーバー側ロック）/ **#4535**（`ShortenedURLHandler` の SSRF、pre-existing・#4523 と同型）/ **#4536**（`disable_gate` テストの盲点）/ **#4537**（緑まとめ）。

### Codex レビューの棚卸し（2026-08-07）

直近 15 PR を横断でリアクション 0 走査（[[feedback_codex-review-window-too-narrow]]）。取り残し 4 件のうち 3 件を処理済み。

- **#4527 P1 / #4528 P1（`Gemfile.lock` が ginseng-core 1.15.32 のまま）** — lock は既に **1.15.34** なので解消済み。👍 を付けて処理済みに
- **#4538 P2（`toLocaleDateString('en-CA')` が ISO を保証しない）** — #4539 で是正。`M/D/YYYY` へ落ちると `isStaleNextOn` の字句比較が逆転し、未来日を「過去日」と誤表示する（`2027-01-01` < `8/6/2026`）。`Intl.DateTimeFormat#formatToParts` で明示的に組む
- **#4527 P2（`ClippingWorker#create_body` が上流の `GatewayError` を握り潰す）** — **2026-08-07 に却下（👎）**。詳細は 5.32.0 節

### ステージング検証（省略不可・2 回実施）

**1 回目（2026-08-06）**: dev24-27 全 4 台で develop=5.31.0・health 200・外部 HTTPS 200。実機で機械的に潰した項目:

- **#4373** — dev25 で `RACK_ENV=production` 実行し、`next_on` 未設定＝当日 20:00 / 未来日＝その日 / **過去日＝出力されない**を確認
- **#4480** — dev27 で `favorites/create` に不正 noteId → **`{"error":{"code":"NO_SUCH_NOTE",...}}` が 400 で透過**。同じ経路で **#4381 の過剰な丸めが直っている**ことも確認（以前は 200 + `{}` で成功と偽っていた）
- **#4511** — dev24-27 のログに生トークン 0 件
- **#4487** — dev25 で `Webhook.all` が全て `available?`、nil / 空白トークンを `ConfigError` で拒否

**2 回目（2026-08-07・レビュー修正 #4533 / #4539 込み）**: 1 回目はレビュー前の develop に対するものなので代わりにならない。4 台を `51d96f47` へ更新し、sidekiq → puma → listener の順に再起動（`Gemfile` 無差分のため再 bundle 不要）。

- 4 台とも health 200・version 5.31.0・外部 HTTPS 200
- **#4511 の再確認** — 4 台とも生トークン 0 件。listener は `?access_token=[FILTERED]`、request ログは `params: {"access_token":"[FILTERED]"}`。**dev27 で `/api/notes/create` を実投稿し、ボディの `i` が `"i":"[FILTERED]"` になることを確認**（レビューで見つけた赤の実機実証）
- **#4539** — dev25 の `/mulukhiya/app/program` が 200 で、`formatToParts` を含む新 JS が配信されている
- ⚠ dev27 は `yjit_available: false` のまま（既知・pooza/chubo2#123）

### 本番デプロイ（2026-08-07・4 台完了）

shallu / zugoga / sweep / gomander、全台 version 5.31.0 / health 200 / `yjit_enabled: true` / 外部 HTTPS で version 確認済み。monit も 3 台とも OK に復帰。Ruby は 4 台とも 4.0.6 で据え置き（`rbenv install` 不要）。

**#4511 のログ掃除も同日に完了。**デプロイで書き足しが止まったことを確認したうえで、残っていた生トークンを `[FILTERED]` へ置換した。

| ホスト | 掃除前 | 掃除後 |
| --- | --- | --- |
| shallu | 5 箇所（live） | 0 |
| zugoga | 2 箇所（live） | 0 |
| gomander | 3 箇所（live + `.0.gz`） | 0 |
| **sweep** | **386 箇所（live + `.1`〜`.7.gz`）** | 0 |

### 振り返り

**sweep の 386 箇所は「掃除済み」と思っていたものが残っていた**。2026-08-05 の #4511 掃除は listener の `access_token=` を対象にしており、**Misskey が使う `"i":"` は 3 台の Mastodon には存在しないパターン**だったので、ダイスキーだけ桁違いに残っていた。しかもその中身は**利用者本人のトークン**（`/api/notes/reactions/create` の body）で、エージェントのボットトークンより深刻だった。MEMORY `project_log-credential-exposure` が「`access_token=` だけで grep しない」と警告していた通りのことが、警告を書いた本人の掃除でもう一度起きている。

**リリース前レビューがこれを捕まえた**。`i` がボディで来るという指摘（🔴）が無ければ、デプロイ後の掃除は「掃除した端から再汚染される」状態で回っていた。ステージング検証が本番停止級を捕まえた 5.30.0 の #4509 と合わせて、**レビュー → ステージング → 本番の 3 段が 2 リリース続けて実際に仕事をしている**。

## 次期マイルストーン: 5.34.0

**テーマは「黙って壊れるのをやめる」。**#4573 / #4558 とも、**上流の正規化・検証がキャッシュ層や rescue で静かに外れ、機能が死んでも誰も気付かない**という同じ型（#4549 / #4560 と同族）。
GitHub マイルストーン作成済み（#632）。バージョンバンプは 2026-08-12（5.33.0 リリース直後）に実施済み（[[feedback_bump-version-first]]）。

- **#4573 obs/bug: リモート辞書が 200-with-HTML を掴むと黙って空になる（主軸・size:S）** — 2026-08-12 の 5.33.0 ステージング検証中に、ステージングのログから気付いて本番で確認したもの。GAS の `/exec` が失効すると **HTTP 200 のまま `text/html`** を返し、`RemoteDictionary#fetch` は `present?` しか見ていないので String が通る。`RelatedRemoteDictionary#parse` の `fetch.to_h` が `String#to_h` で倒れ、外側の rescue が `{}` を返して**辞書が空になる**
  - ⚠ **美食丼（shallu）は `related` 辞書 3 本とも死んでおり、関連語タグ付けが機能していない**（GAS 2 本が 200+HTML、`service.json` が 302→404。10 分周期で毎回全滅）。zugoga / gomander / sweep は 0 件
  - ⚠ **`e.log` 止まりなので Sentry に出ない**（`Sentry.capture_exception` を呼ぶのは `alert` の側）。#4549 / #4560 と同じ「機能が黙って死ぬ」系
  - 直し方の前例は同リポ内の `PronunciationDictionary#valid_schema?`（`parsed.is_a?(Array)` を確かめ、外れたら型名つきで `logger.error`）。**読み辞書だけ検証していてタグ辞書が素通し**という非対称になっている
  - ⚠ **fail-open 自体は残す**。GAS の一過性障害で辞書が消し飛ぶのを防ぐ意図は正しい。問題は倒れたことが**見えない**ほう
  - 付随して 3 サブクラスで異常時の挙動が割れている（`Related` / `Mecab` は fail-open で `{}`、`MultiField` だけ外側 rescue が無く例外が抜ける）
  - **5.33.0 には積まなかった**。ユーザー可視の機能不全＝リリース前レビューの基準では「赤」だが、**5.33.0 の退行ではない既存事象**で、積むとステージング検証をやり直すことになるため（2026-08-12 ユーザー判断）。⚠ **GAS デプロイ URL の失効そのものは運用側の是正**で Issue のスコープ外

- **#4558 番組表の `next_on` に `Time` を手書きすると Redis キャッシュ往復で無効値になる（size:S）** — 5.33.0 で保留にしていたものを 2026-08-12 に繰り入れ。`load_from_yaml` が **coerce 前の生ハッシュ**を `update_cache` に渡すため、Redis には `"2026-08-08 18:00:00 +0900"` が入り、**1 回目（キャッシュミス）だけ正しく 2 回目以降は無効値**になって VEVENT が黙って消える
  - **発火経路を潰して確認した（2026-08-12）。トリガーは `var/program.yaml` の手書きだけ。**エディタの `next_on` は `input type='date'` なので常に `YYYY-MM-DD` の String（項目 3 の不正日付も作れない）、リモート取得は JSON 経由なので時刻型が存在しない
  - ⚠ **それでも積む理由は「#4537 を半分着地のまま残さない」。**`Time` を許可クラスへ入れたのは #4537（5.32.0）が「手書きでも読める」ようにするためで、**こちらが明示的にサポートすると決めた書き方**が 2 回目の読み出しから壊れている
  - ⚠ **一度入ると save をまたいで残る。**`write_yaml` は `to_yaml` をそのまま書き、`Time` は**クォートされず Time のまま書き戻る**。`save` はハッシュ全体を書くので、**エディタで別の行を編集しても Time の行は Time のまま**再永続化される
  - ⚠ **`PERMITTED_YAML_CLASSES` から `Time` を外す方向は採らない。**外すと #4537 が潰した「クォート忘れで番組表全体が読めなくなる」footgun が戻る
  - ⚠ **ゾーンレスの手書きは Psych が UTC で読む**（`18:00:00` と書くと `+0900` では翌日 03:00）。`format_date` の `getutc` はこれを戻すための処理なので、**項目 2「明示オフセットには効かせない」是正はこの UTC 前提を壊さない形で入れる**
  - 直し方は `load_from_yaml` で coerce 済みを `update_cache` に渡す側を推す（**項目 2 も同時に閉じる**）

- **#4576 security: SSRF 掃討の取り残し 2 件（size:M）** — `is_cat` の webfinger が無検証（リダイレクト未検証 + pinning 無し）と、webhook の `image_url` が **full-read SSRF**。5.33.0 のリリース前レビューで赤に分類したが、**修正が全画像ハンドラと webfinger 経路に及ぶ**ため独立サイクルに分けた（2026-08-12 ユーザー判断）
  - ⚠ **CDN への pinning は「複数 A レコードのフォールバックが効かない」既知のトレードオフ**（#4524）を、いまより広い面へ適用することになる。harness 実走込みで見る

- **#4585 番組表: 「次回」ボタンを「話数 +1」と「日付 +1」に分離する（size:M・2026-08-15 着地）** — 2026-08-13 ユーザー要望。現行の ＋ は `episode` の +1 と `next_on` の +7 日を同時に行うため、①2 週以上放置したエントリは 1 回押しても過去日のまま ②話数だけ直したいときに日付が巻き込まれる ③**Annict が載らずに 200 が返ったとき、押し直すと話数が飛んだうえ日付が 7 日ずれる**（[[project_5330-release]] の footgun）
  - ⚠ **日付側は +7 日ではなく +1 日**（2026-08-13 ユーザー判断）。**翌日放送であることがある**のと、**+1 日なら 7 回押して翌週も兼ねられる**ため。`NEXT_ON_INTERVAL_DAYS = 7` は用済みになるので消す。⚠ **7 のまま別名で残さない**（週次前提が別の場所へ生き延びる）
  - ⚠ **連打が常用操作になる。**一覧のボタンは `:disabled='isBusy(key)'` なので素朴に作ると 7 往復待たされ、**ロック取得も 7 回**になる（#4534 の 409 が増える）。楽観更新か日数パラメータで往復を減らす方向で決める
  - ⚠ **曜日ルールや RRULE は #4373 で却下済みなので持ち出さない**（[[project_program-ics-shelved]]）
  - 契約変更だが **`.../episode/increment` を叩いているのは番組表エディタだけ**（capsicum は参照していない）。影響は WebUI と `docs/api.md` に閉じる

- **#4351 perf: media_catalog を zugoga で段階的に再有効化（size:M）** — 2026-08-13 にユーザー要望で繰り入れ。**「メディアカタログの作業を何かしら含めたい」**が起点で、partial index 適用 → 効果計測 → overlay の順に進める一歩目。後続は #4352（shallu / gomander へ横展開）・#4393（sub-second 化）

- **#4583 test/ci: harness ゲートの結果が「前に一度回したか」で変わる（size:M・2026-08-15 着地）** — `tagging_dictionary` が TTL 無しで Redis に居座る。**受け皿 5 件のうちこれだけ繰り入れた**のは、放置するとゲートの緑そのものが信用できなくなり、**次の回の判断材料が腐る**ため（2026-08-13 ユーザー確定）。詳細は下の「着地済み」節

- **#4589 bug: ALT 編集の PUT が `media_ids` / `spoiler_text` / `sensitive` を送らない（size:M・2026-08-15 着地・PR #4590）** — capsicum#121 の着手前に経路を通しで読んで見つけたもの。⚠ **Mastodon の `UpdateStatusService` は「送らなかったパラメータ」を現状維持ではなく「空で更新」として扱う**（コントローラの `update_options` がハッシュリテラルなので `options.key?` が常に true）。そのため ALT を 1 つ直すだけで**投稿から添付が全部外れ、CW と閲覧注意フラグが消える**
  - ⚠ **モロヘイヤ側だけ直しても届かない。**`ginseng-fediverse` の `flatten_media_attributes` が `status` と `media_attributes` しか通さないので、復元した 3 フィールドはリクエスト直前に捨てられる。pooza/ginseng-fediverse#245（1.8.27）と対で入れる（PR #4590 の Codex P1。**指摘が無ければ「直したのに直っていない」まま出ていた**）
  - ⚠ **必須パラメータは purpose ごとに違う。**`tag` は本文だけを送り直す経路で添付を持たない投稿にも来るので、`media_attributes` を一律必須にすると本文だけのタグ書き換えが 422 になる（同 Codex P2）
  - ⚠ **実害はまだ出ていない。**この経路を叩くクライアントが無く、capsicum#121 が着手前だったため。**先に塞ぐのが本件の趣旨**

- **#4594 bug: 画像アップロードの 401 がアラート抑止をすり抜ける（size:S・2026-08-20 着地・PR #4595）** — 2026-08-17 に
  キュアスタ！本番（gomander）で `POST /api/v1/media` の 401 が 25 分に 13 回、**すべて管理者へのアラートメール
  （＋ Discord ＋ Sentry）として飛んだ**。発生源は Tencent Cloud の分散 IP からのボットで、無効トークンのまま連打していた
  - ⚠ **モロヘイヤ側だけ読んでも辿り着けない**（#4589 と同型）。`ginseng-fediverse` の `MastodonService#upload` が上流の
    `GatewayError` を `ValidateError` に詰め替えていたため、`rescue Ginseng::GatewayError` に引っかからず
    `silent_statuses: [401]` に**一度も到達していなかった**。pooza/ginseng-fediverse#246 → #247（1.8.28）と対で入れる
  - ⚠ **同じ理由で 413 の分岐も死んでいた。**「アップロードしたファイルがサーバーの上限サイズを超過しています。」は
    **導入以来一度も出ていない**。クライアントに返るのも上流の 401 / 413 ではなく `ValidateError#status` の 422 だった
  - ⚠ **Issue は open のまま残している。**効いていることの確認は**本番へ出た後**にしか取れない
    （同じボットの 401 連打でアラートメールが飛ばず、syslog には残っていること）。5.34.0 デプロイ後に確認してクローズする
  - 回帰テストは 2 段。`gateway_error_transparency.rb` に 4 本（401 抑止 / 413 文言 / **5xx は鳴らす** /
    上流ステータス透過）と、**gem 境界の契約テスト** `test/unit/service/mastodon_upload_error_boundary.rb`。
    ⚠ **後者が無いと `bundle update` で黙って戻る**（前者は gem を通らない）
  - ボット自体の遮断はインフラ層（pooza/chubo2#118）。モロヘイヤ側は alert 条件だけを扱う

- **#4598 bug: `Idempotency-Key` が上流へ転送されず、再送が二重投稿になる（size:M）** — 2026-08-19 に
  `pooza/makoto2` の通しリハーサル（dev25）の相談から発見。`POST /api/:version/statuses`（プロキシ経路）と
  `POST /mulukhiya/webhook/:digest`（Slack 互換）の両方でヘッダが落ちる。⚠ **クライアントが正しくキーを付けていても
  モロヘイヤ経由では無効化される**ので、応答だけ失われたときの再送が投稿をもう 1 つ作る
  - ⚠ **転送は `Idempotency-Key` だけの許可リストで行う。**`@headers` の丸投げは `Host` / `Content-Length` /
    `Cookie` / `X-Mulukhiya` まで混ざる

- **#4599 feat: Slack 互換 webhook でリクエストごとの公開範囲を受け付ける（size:S）** — `Webhook#post` は既に
  「来れば尊重する」形なのに、`SlackWebhookPayload#values` が `visibility` を落としている。
  ⚠ **`Webhook#command` が出す curl サンプルには `visibility` が入っている**＝**効くように見えて効かない**状態

- **#4601 chore: RuboCop 設定と規約の正本を ginseng-style へ寄せる（size:S・2026-08-20 着地・PR #4602・Issue クローズ済み）** —
  新設した [pooza/ginseng-style](https://github.com/pooza/ginseng-style) を `inherit_gem` し、`.rubocop.yml` に残るのは
  `bin/diag` の除外・`TargetRubyVersion`・Sequel 系（正本が持たないプラグイン）だけになった。
  docs 側もコーディング規約・表記規約・重み定義を ginseng-style の `docs/` へ委譲
  - ⚠ **`Minitest/RefutePathExists` の固有緩和も落とした**（`b77dd308`）。これは**モロヘイヤ固有ではなく
    test-unit を使う全プロジェクト共通**の問題で（minitest は `assert_path_exists`、test-unit は `assert_path_exist` の単数形）、
    `rubocop-minitest` が**存在しないメソッドへ自動修正する 4 cop**（`AssertPathExists` / `RefutePathExists` /
    `AssertOutput` / `AssertSilent`）を正本側でまとめて無効化した（pooza/ginseng-style#11 / #12）
  - ⚠ **この申し送りは PR 本体のコメントに置かれていた**（投稿者は Codex ではなく `pooza`＝別セッション）。
    同期の初回で落としたので §4 に手順として足してある

- **#4616 chore/security: ginseng-core を更新し、ログのマスクが外れる穴を塞ぐ（size:S・2026-08-21 繰り入れ）** —
  ⚠⚠ **🔴 依頼（ginseng-core#518）より重かった。**「不正なバイト列でログ 1 行が消える」ではなく、
  `Logger#mask_url` の `ArgumentError` が `create_message` の rescue まで飛んで**素の src が返る＝
  `mask_fields` も `mask_query_params` も効かない**状態だった。⚠ **`Controller#before` は受信 params を
  そのまま `logger.info` に載せる**ので、**外から壊れたバイト列を 1 つ混ぜるだけでその行のマスクを外せる**
  ＝ #4511（[[project_log-credential-exposure]]）で塞いだものがこの経路で戻っていた
  - ⚠ **本番で開いている実害なので繰り入れた**（2026-08-21 ユーザー判断）。⚠ **cert タスク（#4617）と
    `max_bytes`（#4612）は同じ `bundle update` に乗るが、5.34.0 には含めない**
  - `bundle update ginseng-core` ＋ `Gemfile.lock` のコミット。⚠ **取り込み後に `Controller#before` 側の
    回避策を畳めるか見る**（gem 側で塞いだため）

**確定スコープの重み合計は 24**（M 3 × 6 + S 1 × 6）。目安の 20〜25 の上寄りで、**これ以上の追加は次リリースへ送る**。
⚠ **メンテナンスリリースを連続させない**というユーザーの意向（2026-08-13）を受けて、**主軸をメディアカタログと番組表に置き、
検査由来の受け皿は #4583 の 1 本に絞った**。残り 4 件は次リリース以降へ送る。
なお #4589 / #4594 は**バグとして後から繰り入れた**（受け皿の枠ではない）。#4598 / #4599 / #4601 は 2026-08-18〜19 の追加。

### Codex レビューの棚卸し（2026-08-16）

**PR #4587 / #4588 の P2 を PR #4591 で消化した。**どちらも「直した機能が黙って効かなくなる」型で、5.34.0 のテーマそのもの。

- **#4583 (PR #4587) 署名が「畳む前」と「畳んだ後」で割れていた** — `RemoteDictionary.create` が `type` の既定値
  (`multi_field`) と旧称 (`relative` → `related`) を**プロセス共有の設定ハッシュへ直接埋めて**いた。
  `handler_config(:dics)` が返すのは設定の実体そのものなので、`refresh` する側（`fetch` 後＝畳んだ後）と
  起動直後の `load_cache`（畳む前）で指紋が食い違う。⚠ **`type` を省略した dic が 1 本でもあると、
  新しい Puma プロセスが毎回キャッシュを捨てて全辞書を同期取得する**＝ #4583 で TTL と署名を入れた意味が
  その分だけ失われていた。`type` の解決を非破壊の `RemoteDictionary.type` へ出し、署名は `canonical_sources`
  から取る。⚠ **dics の並び順は保つ**（取り込み順でもあるため、並べ替えは別物として扱う）
- **#4585 (PR #4588) 600ms の debounce 窓が書き込みの穴だった** — 窓の間は `busy[key]` がまだ立たないので、
  その隙に**編集フォームが開けて古い `next_on` を写し取り、保存で押したはずの ＋ を黙って書き戻す**。
  `isLocked`（実リクエスト中）と `isBusy`（＋ 保留分も含む書き込みバリア）に分け、日付 ＋ だけ `isLocked` を見る
  （ここまでバリアに含めると 1 クリック 1 往復へ戻る）。`openEdit` は保留分を先に送り切って再読込みを待つ

⚠ **`views/program.slim` は #4578 のため `rake lint` の対象外。**develop 版と slim-lint の結果を突き合わせて
新規指摘ゼロを確認した（既存の LineLength のみ）。

### 着地済み: #4583 タグ辞書キャッシュに署名と TTL を入れる（2026-08-15・PR #4587）

芯は 2 つあり、**実害が大きいのは 2 のほう**だった。

1. `tagging_dictionary` が **TTL 無しの素の SET** で、実行と実行のあいだで消えない
2. キャッシュが **「どの `dics` 設定から作られたか」を持たない**ので、別の設定で温めたキャッシュを次のプロセスがそのまま読む

`DictionaryTagHandlerTest#setup` は `dics` を 5 件（うち 1 件は `strict: true`）へ差し替えて `refresh` する。
その回のキャッシュが `RemoteTagHandler#search_remote_tags` の reject 3 条件
（`short?` / `local_tags.member?` / `strict_key?`）に効く。**3 条件とも同じ辞書を読んでいる。**

入れたもの:

- キャッシュ本体を `version` / `signature` / `generated_at` / `entries` の envelope に包む。署名は `dics` 設定の指紋で、署名違い・バージョン違い・旧形式は「無いもの」として作り直す
- `setex` で TTL（既定 3600 秒・`/handler/dictionary_tag/cache/ttl`）
- **全ソースが空を返した回は、生きているキャッシュを空へ潰さない。**⚠ `RemoteDictionary` のサブクラスは失敗を握って `{}` を返すので、**例外の有無では検出できない**（結果が空かどうかで判定する）。⚠ fail-open 自体は残す（#4573 と同じ理由）
- キャッシュ未充填で `alert` しない。TTL を入れた以上、失効は日常的に起きる
- `refresh` のたびに世代（`signature` / `generated_at` / `entries` / `ttl`）をログへ出す
- **スイートのロード時にキャッシュを捨てる**（`TestCase.invalidate_shared_caches`）。⚠ **「実走の前に手で `UNLINK` する」を手順書に書くだけでは弱い**（#4503 の教訓）

⚠ **回帰テストは `TaggingDictionaryCacheTest` として別クラスに置いた。**`Handler.create(:dictionary_tag)` が
Sequel のモデルを触るため、既存の `TaggingDictionaryTest` は **DB の無い環境でクラスごと omission** になり、
ゲートを守れない。キャッシュの世代・署名・TTL は辞書ソースの設定だけで決まるので、辞書ソースを返すだけの
ダブルを差し込んで常に実走させている。

⚠ **`RemoteTagHandlerTest` の `キュアスタ!` が 3 条件のどれで落ちているかは未特定のまま**（#4584 の担当）。
本件の着地で A/B の再現性が担保されたので、着手できる状態になった。

検証: `rake test` 978 → **988 tests / 0 failures / 0 errors / 313 omissions**（omissions は前後で不変・新規 10 件はすべて実走）。
`rake lint` 通過。CI は mastodon / misskey とも緑。

### 着地済み: #4585 「次回」を「話数 +1」と「日付 +1」に分離（2026-08-15・PR #4588）

| ボタン | 動き | エンドポイント |
| --- | --- | --- |
| 話数 ＋ | `episode` のみ +1（Annict のサブタイトル解決は従来どおり） | `POST .../episode/increment`（**日付を触らなくなった**） |
| 日付 ＋ | `next_on` のみ **+1 日** | `POST .../next_on/advance`（新設） |

`NEXT_ON_INTERVAL_DAYS = 7` は削除した（⚠ **7 を別名で残していない**）。
`increment_episode` から日付の前進が外れたので、**Annict が載らずに 200 が返ったときの巻き戻し量が半分**になる。

⚠ **`days` は 1〜366 の整数のみ・範囲外と非整数は 422。**素の `to_i` に倒すと `'abc'` が 0 日になり、
「押したのに進まない」理由が分からなくなる。**クライアント起因なので alert しない**（#4542 と同型）。

⚠ **WebUI は連打を 600ms で畳んで 1 リクエストにする**（`days` に日数を載せる）。1 クリック 1 リクエストだと
7 往復待たされたうえ #4534 のロックも 7 回取る。⚠ **`entry.next_on` の実体は触らない** ——
一覧の並びが `next_on` 昇順（#4540）なので、実体を進めると**連打の途中で行が動き、2 回目のクリックが別の行に当たる**。

⚠ **CI の omission baseline を 313→318 / 302→307 へ上げた。**ゲートを緩めたのではなく、
**CI で実行しようがないテストが 5 件増えた分**（`ProgramTest` は `livecure?` が false だとクラスごと omission になり、
CI には `var/program.yaml` も `/program/urls` も無いので常に false）。

⚠ **ローカルで `ProgramTest` を実走させるには `var/program.yaml` を一時的に置く**（無いと 40 件超がまるごと omission）。
これで見つかった**既存の赤 2 件**（本 PR 由来ではない）:

- `test_data_coerces_unquoted_yaml_timestamp` — `Time` が Redis キャッシュ往復で `"2026-08-08T23:30:00.000Z"` になる。**#4558 そのもの**（5.34.0 スコープ内・未着手）
- `test_auto_update_default_true` — `/program/auto_update` 未設定だと `auto_update?` が `ConfigError` を上げる（「既定 true」が実装されていない）。⚠ **既定値は `config/application.yaml` にあるので通常は踏まない**

`test_increment_episode_does_not_create_next_on` も develop で落ちていた（`coerce_scalars` が `next_on` を必ず
materialize するのでキーは常に存在する）。**値を見るアサーションへ直した**。

⚠ **`views/program.slim` は #4578 のため `rake lint` の対象外。**個別に `slim-lint` を掛けて確認すること。

### 着地済み（マイルストーン外）: デーモンの `/health` が「触れなかった」を「死んでいる」と断定しない（2026-08-15・PR #4592）

ginseng-core 1.17.0（pooza/ginseng-core#509 / #510 / #511）への追随。**3 件とも「例外を安全側でない値・順序に
読み替える」同型**で、Issue は立てずに gem 追随として直接入れた。

- `Process.alive?` は `Errno::EPERM`（プロセスは存在するが**シグナルを送る権限が無い**）でも false を返す。
  `listener_daemon.rb` / `sidekiq_daemon.rb` の `/health` はこれを `PID '...' was dead` と報告していた
  ＝ **原因を誤って伝えていた**。1.17.0 の `Process.alive_state`（`:alive` / `:dead` / `:unknown`）で分岐する
- ⚠ **`:unknown` も NG のままにする。**デーモンは `/health` を返すプロセスと同じユーザーで動くので、
  触れない＝ pid が再利用されて他人のプロセスになっている＝うちのデーモンは動いていない。
  **変えるのは「なぜ NG なのか」の説明だけ**（[[project_5310-release]] の `pgrep -f mulukhiya` の取りこぼしと同じ筋）
- gem を上げるだけで効く分に `Daemon#run_stop` の順序バグ（`remove_pid` → `Process.kill` だったため、`EPERM` で
  **プロセスは生きたまま pid ファイルだけ消え**、次の start が 2 本目を立てていた）が含まれる

### 5.34.0 の実装状況（2026-08-21 時点）

**スコープの実装は #4351（Gate 2 の flip）を除いて全て develop へマージ済み。**
**次にやるのはリリース前レビュー → ステージング検証。**

| PR | Issue | 主眼 |
| --- | --- | --- |
| #4620 | #4616 (S) | ginseng-core 1.19.0。壊れたバイト列でログのマスクが外れる穴を塞ぐ |
| #4605 | #4599 (S) | Slack 互換 webhook の公開範囲をリクエストごとに受ける |
| #4607 | #4558 (S) | `next_on` を「書いたとおりの日付」で読む |
| #4609 | #4573 (S) | リモート辞書の 200-with-HTML を黙って飲まない |
| #4610 | #4598 (M) | `Idempotency-Key` を上流へ中継する |
| #4611 | #4576 (M) | SSRF 掃討の取り残し 2 件 |
| #4613 | #4393 | media_catalog を LATERAL merge へ（#4351 Gate 2 の前提） |
| #4614 | #4351 | `/health` に接続プールの使用状況を出す |
| #4608 | #4606 | `inherit_mode` を足して継承した `Exclude` を取り戻す |

⚠ **Issue はどれも open のまま。**`Fixes #NNNN` を書いても **base が `develop` なので GitHub は閉じない**
（デフォルトブランチへのマージでしか閉じない）。リリース後に、モンキーテスト可否で分類して畳む。

判断が要った点（詳細は各 PR 本文）:

- **#4558 は Issue の推奨案では直らない。**⚠ **`Time` に materialize した後ではゾーンレスと明示
  オフセットを区別できない**（実測でどちらも `utc? == false` / `utc_offset == 32400` の同じ
  オブジェクト）。**AST 上で `next_on` を `YYYY-MM-DD` の String へ差し替える**方式にしたところ、
  項目 1（Redis 往復で無効値）も同時に消えた。⚠ 直すのは `format_date` ではなく `parse_yaml`
- **#4573 は Sentry へ escalation しない。**10 分周期なので `alert` に載せると 1 ソースあたり
  日 144 件のメール・Discord になる（#4594 と同型）。`logger.error` ＋ 世代ログの `empty_sources`
  で「何本中何本が死んでいるか」を 1 行で読めるようにし、判断は #4577 へコメントで残した
- **#4576 は pinning の段階適用を採らなかった。**Issue は「ナウプレのサムネイル取得にも効くので
  CDN が壊れうる」としていたが、⚠ **`Handler#upload` の呼び出し元は `WebhookImageHandler`
  1 本だけ**で、ナウプレ系は `upload_remote_resource` を通らないことを全呼び出し元の確認で裏取り
  した。**fedi-test-harness（Mastodon）実走で 1104 tests / 0 failures / 0 errors / 157 omissions**
- テストはすべて**両マトリクスで実走する場所**に置いた。⚠ `SlackWebhookPayloadTest`（Slack 未設定で
  omission）・`ProgramTest`（`livecure?` が false で omission）に相乗りしない
- **#4616 は gem 更新なので、判断が要ったのは「何を持ち込まないか」。**`bundle update` には
  timeout（#4593）・`max_bytes`（#4612）・cert タスク（#4617）・`format: uri` 厳格化も乗ってくるが、
  **こちら側の載せ替え作業は 5.34.0 でやらない**（2026-08-21 ユーザー判断）。⚠ **gem の挙動が変わることと、
  こちらが載せ替えることは別**として扱う
  - ⚠ **`ListenerTest#test_root_cert_file` の是正は退行対応ではなく、地雷が外れた分。**
    `Faye::WebSocket::SslVerifier` は値があると `cert_store.add_file` を呼ぶので**存在しないパスで落ちる**。
    旧 gem が `ENV['SSL_CERT_FILE']` に無い `cert/cacert.pem` を立てており、**Listener がそれを掴む
    唯一の経路**だった（#4586）。1.19.0 は立てないので nil ＝ システムの CA ストアに倒れる
- ⚠ **CI の omission baseline は 318 / 307 → 321 / 310 になった**（#4613）。ゲートを緩めたのではなく、
  **DB を持たない CI では `AttachmentTest` がクラスごと omission になる**ため、そこへ足した 3 件が
  そのまま乗る分。**それ以外の PR では baseline を動かしていない**

### #4351 / #4393 の決着（2026-08-20・zugoga 本番実測）

**sub-second 化は B 案（ローカルアカウント駆動の LATERAL merge）で決着し、PR #4613 で着地した。**
計測の全文は [#4323 のコメント](https://github.com/pooza/mulukhiya-toot-proxy/issues/4323#issuecomment-5349297730)。

| パターン | 現行 | 本実装 |
| --- | --- | --- |
| page1 | 26,415ms | **56.7ms** |
| only_person | 25,998ms | **6.5ms** |
| cursor | 23,234ms | **5.7ms** |
| rule つき | 8,900ms | **837ms** |
| rule ヒット無し | 2,244ms | **14.0ms** |

- ⚠ **現行のベースラインは劣化していた**（Gate 1 当時の「約 10s」→ 23〜26s）。「10s だから Gate 2 保留」の
  前提はさらに厳しい側に振れていた
- ⚠ **A 案は棄却。**速さ（1,593ms）ではなく、照合で **44 行の取りこぼし**が出たのが決め手
- ⚠ **フィルタは LATERAL の内側・内側 LIMIT は `limit + offset`。**本番でわざと誤り版を作って照合したところ
  **page2 で 14 行取りこぼした**。正しい版は page1 / only_person / rule / page2 とも差分 0 行
- **追加 index は不要**（Mastodon 本体の `index_media_attachments_on_account_id_and_status_id` で成立）。
  ローカルアカウントは **19 件**
- worker の DB 占有が **30 分ごと 150 秒 → 0.2 秒**。⚠ ここが 2026-05-19 の枯渇の温床だった

**Gate 2 の進め方（2026-08-20 ユーザー確定）**:

1. **順序は「5.34.0 リリース → zugoga デプロイ → flip」。**⚠ 新クエリはコードなので先行 flip はできない
2. **ステージング（dev26）を挟む。**⚠ ただし**性能検証ではなく機構の確認**
   （flip が効く・`/feed/media` が 200・worker がキャッシュを載せる・新規エラーが出ない）。
   ⚠ **dev26 で有意な性能計測はできない**（本番と桁違いでプランが変わる。[[feedback_staging-data-scarcity]]）
3. **rollback は `/health` の `postgres.pool.waiting` が 0 を超えた状態が数分続いたら**（overlay を false へ戻すだけ）。
   ⚠ `allocated` が `max` に張り付くのは正常なので、それを理由に戻さない
   - ⚠ **この指標は「Puma 1 プロセスの Sequel プール」しか見ていない**（2026-08-21 の Codex 指摘 ＝ #4618）。
     2026-05-19 に枯れたのは **pgbouncer（全プロセス・Mastodon 本体と共有）**で、重い SQL を流すのは
     別プロセスの Sidekiq。**flip 中は pgbouncer の `SHOW POOLS`（`cl_waiting`）も人が直接見る**
   - ⚠ **`/health` は `SELECT 1` の後にプールを読むので、有限のスパイクは取りこぼす。**
     「waiting が 0 だった」を「詰まらなかった」の証拠にしない

### 2026-08-20 セッション同期の記録

- **Sentry**: 未コメントの新規 3 件を精査した。
  - **MULUKHIYA-TOOT-PROXY-2K（UploadError 401・28 件）** — #4594 そのもの。PR #4595 が CI 緑で着地待ち
  - **MULUKHIYA-TOOT-PROXY-2J（Webhook not found・3 件・shallu）** — **#4603 として起票**。
    存在しない digest への `POST /webhook/:digest` が `e.alert` 固定で Sentry に上がる。
    ⚠ **同じ例外が `get '/:digest'` では `e.log` で静か**という非対称。#4542 / #4594 と同型
  - **MULUKHIYA-TOOT-PROXY-1X（CustomFeed command failed）** — 最新イベント（2026-08-18）も
    `server_name=mulukhiya` / `release=5.26.0` ＝ **姉妹サーバー管理人のモロヘイヤ**の系統で pooza 側の作業は無い。
    chubo2#41 系統（zugoga のデプロイで bundle install 未走）は 2026-07-17 を最後に静穏
- **Dependabot** 0 件。**Codex** は open / 直近マージ 25 本を横断してリアクション 0 の指摘ゼロ（[[feedback_codex-review-window-too-narrow]] の広めの窓で確認）
- ⚠ **同期の初回で PR #4602 の申し送りコメントを落とした。**`pulls/{number}/comments` は行コメントしか返さず、
  PR 本体のコメント（`issues/{number}/comments`）を見ていなかったため。**投稿者は Codex ではなく `pooza`**
  （ginseng-style 側を触っていた別セッションの申し送り）。§4 に手順として追記した。
  内容は「正本側 pooza/ginseng-style#11 / #12 で **test-unit に無いアサーションへ自動修正する 4 cop**
  （`AssertPathExists` / `RefutePathExists` / `AssertOutput` / `AssertSilent`）をまとめて無効化したので、
  モロヘイヤ側の `Minitest/RefutePathExists` の固有緩和は落とせる」。b77dd308 で消化（rubocop 471 files / no offenses）
- **chubo2** は差分なし。**Issue 棚卸し（§6-2）は最終 2026-07-31 で 30 日未経過**なのでスキップ（次回は 2026-08-30 以降）
- **harness の upstream チェック（§8）** — 下の「fedi-test-harness の検証状況」に反映

### 2026-08-21 セッション同期の記録

- **Mastodon 4.7.0 が stable リリース（2026-08-20）＝ 本番 3 台・ステージング 3 台へ適用済み（2026-08-21）。**
  インフラ側の記録は pooza/chubo2 の `docs/infra-history.md` / `docs/infra-note.md` が正本（[[project_mastodon-upgrade-runbook]]）。
  **モロヘイヤ側は同日に harness を stable で実走し、`verified` を v4.7.0 へ昇格した**（全緑）。
  下の「fedi-test-harness の検証状況」参照
- **Codex**: 前回同期の後に付いた **3 件**を消化（PR #4614 の P1 / P2、PR #4613 の P2）。いずれも妥当と判断し、
  返信 ＋ 👍 のうえ **#4618 / #4619 で受けた**。⚠ **どちらも「ゲートや rollback 信号が、見たいはずのものを
  取りこぼす」型**で 5.34.0 のテーマ（黙って壊れるのをやめる）そのもの
- **Sentry** 新規なし（最終確認 2026-08-18 の 3 件はいずれも 08-20 にトリアージ済み）。**Dependabot** 0 件
- **ginseng-core が動いた。**依頼していた 4 件（#518 / #514 / #526 / #528）と #512 が `main` へ着地し、
  **向こうから取り込み依頼が 2 本来ている（#4616 / #4617）**。⚠ `Gemfile.lock` の revision は
  `ab02f5e`（旧）のままで **`bundle update ginseng-core` は未実施**
- **chubo2** は差分なし（`git fetch` 済み・infra 側の 4.7.0 記録は取り込み済み）。
  **Issue 棚卸し（§6-2）は最終 2026-07-31 で 30 日未経過**なのでスキップ（次回は 2026-08-30 以降）
- **#4616 を 5.34.0 へ繰り入れた**（本番で開いている実害のため。#4617 / #4612 は次リリース以降）。
  重み合計 23 → 24
- **harness を v4.7.0 stable で実走し `verified` を昇格**（下の節）。⚠ **踏んだ罠は無し**
  （`update-version.sh` → `reset.sh` がそのまま通った。08-16 に踏んだポート 3000 衝突は
  pooza/chubo2#178 の修正が効いていて再発しなかった）

### マイルストーン未割当

**5.33.0 のリリース前レビュー・harness ゲート由来の受け皿**（2026-08-12 起票）。
**#4583 だけ 5.34.0 へ繰り入れ、残り 4 件は次リリース以降へ送ることで確定**（2026-08-13 ユーザー判断）:

- **#4577 obs: 5.33.0 レビュー由来の観測性の穴 4 件（size:M）** — 番組表全滅が無音・ロック fail-open が不可視・Annict staleness が無音・Spotify の誤分類
- **#4578 test/ci: `rake lint` の slim-lint が `views/` 直下 16 本を一度も検査していない（size:S）** — dash に globstar が無いため。#4503 と同型の「守れているつもりの緑」
- **#4579 API 契約: 409 の「恒久／一過性」がクライアントから判別できない（size:M）** — 機械可読コード・`Retry-After`・increment の 3 通り
- **#4584 test: harness で `RemoteTagHandlerTest` の `キュアスタ!` タグが reject される（size:M）** — 両系で発生。**5.33.0 の退行ではない**（同一コミット連続実行で A/B 済み）。⚠ **3 つある reject 条件のどれが効いているかは未特定**。⚠ **#4583 を先に片付けないと A/B の再現性が担保できない**ので、5.34.0 で #4583 が着地してから着手する → **2026-08-15 に #4583 が着地したので着手可能**

その他:

- **#4543 obs: Sentry の未トリアージ unresolved 16 件を棚卸しする（size:M）** — `is:unresolved` 27 件のうち **16 件がコメント 0 のまま滞留**していた。§5 の手順は**新規イシューだけを見る**構造なので、手順が入る前の分がそのまま残っている。Redis 接続系 174 件 / 上流 4xx・5xx 100 件 / 単発 2 件の 3 群に分けて群ごとに判断する。上流 4xx 群には #4542 と同型（クライアント起因なのに alert）が混ざっている可能性が高い
- **#4603 obs: 存在しない digest への webhook POST が 404 なのに Sentry へ alert される（size:S）** — 2026-08-20 の
  セッション同期で Sentry から拾ったもの（MULUKHIYA-TOOT-PROXY-2J）。`post '/:digest'` の rescue が `e.alert` 固定。
  ⚠ **同じ `verify_webhook!` を通す `get '/:digest'` は `e.log`** で、GET と POST で扱いが割れている。
  #4543 の「上流 4xx 群に #4542 と同型が混ざっている」という見立てが、**上流由来ではなく自前の 404 で**当たった形
- **syslog 側のノイズ棚卸し（未起票）** — zugoga の `base_uri undefined` のように `e.log` 止まりで Sentry に出ない大量ログがある。#4543 の対象外なので別建てが要る
**5.34.0 の Codex レビュー由来の受け皿（2026-08-21 起票）**:

- **#4618 obs: `/health` のプール指標が Puma プロセスローカルで、pgbouncer と Sidekiq 側の逼迫を取りこぼす（size:M）** —
  PR #4614 の Codex P1 / P2。⚠ **2026-05-19 に実際に枯れたのは pgbouncer（全プロセス・Mastodon 本体と共有）**で、
  重い SQL を流すのは別プロセスの `MediaCatalogUpdateWorker`。`/health` が読むのは**そのリクエストを処理した
  Puma プロセスの Sequel プール 1 つ**なので、どちらも直接は見えない
  - ⚠ **完全に盲目ではない**（pgbouncer が詰まれば滞留が延びて同プロセスの他スレッドが待つので `waiting` は
    遅れて上がる）。**症状の代理としては効くが、flip の影響を最初に検知するには遅い・粗い**
  - ⚠ **P2（`SELECT 1` の前にスナップショットを取る）は P1 と独立に入れられる。**現行は health 自身が
    待ち行列に並び、**前の待ちが捌けてから `num_waiting` を読む**ので有限のスパイクを取りこぼす
  - **Gate 2 は「`/health` の `waiting` ＋ flip 中は pgbouncer の `SHOW POOLS` を人が直接見る」で回す**
- **#4619 test: catalog の `only_person` subset 検証が truncate したベースラインと比較していて偽陽性になりうる（size:S）** —
  PR #4613 の Codex P2。`all_ids` は「絞り込み無しの最新 10 件」で母集合ではないため、⚠ **最新 10 件に Person 以外が
  1 件でも混ざると `only_person` 側はより古い Person で 10 件を埋め、SQL が正しいのに落ちる**。
  いま緑なのはデータの並びがたまたま Person で埋まっているからにすぎない（#4583 と同型）。
  ⚠ **DB を持たない CI ではクラスごと omission** なので、赤は harness 実走でしか出ない

**ginseng-core からの取り込み依頼（2026-08-20〜21・向こうが着地させた分）**。⚠ **`Gemfile.lock` は
まだ旧 revision（`ab02f5e`）で、`bundle update ginseng-core` は未実施**:

- **#4616 は 5.34.0 へ繰り入れた**（2026-08-21 ユーザー判断・上のスコープ節）。**本番で開いている実害**のため。
  ⚠ 併せて #514（`/http/timeout/seconds` が効いていなかった＝ #4593）・#526 / #534（`max_bytes` ＝ #4612）・
  #528 / #533（`host_validator` の使い回し）も `main` に入っており、**同じ `bundle update` に乗ってくる**。
  ⚠ **乗ってくることと、こちら側の載せ替え作業を 5.34.0 でやることは別**
- **#4617 chore: ginseng-core の cert タスクを受け取る（size:S）** — `cert:update` / `cert:check` を gem が配るようになった
  （`Ginseng.load_tasks` の 1 行）。#4586 の受け皿。⚠ **急がない**（上流側で「存在しないパスは `SSL_CERT_FILE` に
  立てない」が入ったので**現状は無害**）。⚠ **`cert/cacert.pem` をコミットするかは判断が要る**
  （向こうの推奨は「コミットせずデプロイ時に `rake cert:update`」＝更新の当番を増やさない）
- **#4612 security: `MediaFile.download` の受信バイト上限が「読み切ってから」しか効かない（size:S）** —
  #4576（PR #4611）の Codex P1 の受け皿。⚠ **gem 側の `max_bytes` が着地したので着手可能になった**
  （起票時は「gem 側の対応待ち」だった）。`bundle update` と同じサイクルで載せ替える

**設定検証・入口の堅牢化まわり（2026-08-15〜19 起票・いずれも未スコープ）**。⚠ **`ginseng-*` 側と対になっているものが多い**
（[[feedback_fix-may-not-reach-through-ginseng]]）。まとめて 1 サイクルにするか個別に散らすかは次期マイルストーン確定時に決める:

- **#4596 bug: config 検証の strict が構造的に発火しない（size:S）** — `Mulukhiya.validate_config` の `raise` を
  **同じメソッドの `rescue => e` が必ず受ける**（`ConfigError < Ginseng::Error < StandardError`）。
  ⚠ **`strict` を有効にしても起動は止まらない**＝守っているつもりの検証。[[feedback_fail-open-guard-footgun]] の実例
- **#4597 bug: schema の `format` が 1 つも検証していない（size:M）** — `uri` 以外（regex 6 / hostname 2 / email 1）は
  **json-schema 6 に検証実装が無く素通し**。⚠ **`validate_formats: true` を渡しても変わらない**（フラグの問題ではない）。
  ⚠ `config/schema/base.yaml` の `format: ^/` は **format 名ですらない**
- **#4600 bug: 不正な UTF-8 バイト列を含むリクエストが 500 + Sentry になる（size:M）** — 入口で 400 に落とす。
  ⚠ **`JSON.parse` は不正 UTF-8 を弾かない。**リクエストログが通り抜けているのは `SCRUBBED_LOG_PARAMS` で
  `[FILTERED]` に置換されるからで、**偶然の防波堤**。対は pooza/ginseng-core#518 / pooza/ginseng-fediverse#248
- **#4593 perf/bug: HTTP タイムアウトが未設定（size:S）** — `/http/timeout/seconds` が無く、`Ginseng::HTTP` 側も
  `get` / `post` / `put` / `delete` に `timeout:` を渡していない（pooza/ginseng-core#514）＝**両側とも未設定で実効 60 秒**。
  `retry.limit: 3` と合わせて最悪 180 秒級が**同期の投稿経路にぶら下がる**。⚠ **実測はまだ無い**（設定が効いていない事実の記録）。
  #4573 が「黙って空になる」なら、こちらは「黙って遅くなる」
- **#4586 bug: Listener の `root_cert_file` が `SSL_CERT_FILE` にフォールバックし、存在しないパスを渡しうる（security）** —
  対は pooza/ginseng-core#512（利用アプリに cert タスクが無い）・#515（cacert.pem に更新の当番が無い）

**ginseng-style（2026-08-19 新設）**。Ruby の書き方・テスト方針・表記規約・RuboCop 設定の正本を切り出した gem リポジトリ。
モロヘイヤ側の取り込みが #4601 / PR #4602。⚠ **今後「書き方」の指示が出たら正本は ginseng-style の `docs/`**。
⚠ **ginseng-\* 自体の残件はこのリポジトリの管轄外**（§6 のとおり専任セッションがある）。こちらは
`inherit_gem` の追随と、送った Issue / PR の結果待ちだけを持つ。

- **pooza/chubo2#166 ops: sweep の unattended-upgrades が itamae 管理外** — 2026-08-12 06:40 に systemd 更新の巻き添えで `redis-server` が再起動し、Sidekiq が Sentry へ 8 イベント（一過性・復旧済み・triage コメント済み）。⚠ **sweep は「再起動で PG が上がらない地雷」を抱えているのに `postgresql-16` が自動更新の射程内**なのが本題。モロヘイヤ側の作業は無い

### fedi-test-harness の検証状況

**Mastodon v4.7.0 stable を 2026-08-21 に実走・`verified` 昇格**（本番 3 台・ステージング 3 台への適用と同日。
**本番と検証済み版が揃った**）。**1156 tests / 2250 assertions / 0 failures / 0 errors / 159 omissions
（100% passed、332 秒）**。

- **DB 直読み層は個別にも実走**: account 34 / status 27 / postgres 10 は **omission 0 で全緑**、
  attachment は 20 tests / 0 failures / **2 omissions**
- ⚠ **attachment の omission 2 件を 4.7 の影響と読まない。**#4613 で足したページ送りのテストが
  **ページ 2 を作れるだけの media を harness が seed していない**ため（pooza/chubo2#64）。
  08-16 の「attachment 17 tests / omission 0」との差は**モロヘイヤ側でテストが増えた分**
- ⚠ **rc.1 → stable の差分は harness の観点では空だった**（49 files / 24 commits・**マイグレーションなし・
  DB スキーマ変更なし・シリアライザ変更なし**。Ruby 側は `ActivityPub::ProcessAccountService` +3-1 と
  admin 系の文言のみ）。**見込みで昇格させず回し直した結果、08-16 の rc.1 全緑がそのまま再現した**
- Misskey は stable 2026.7.0 据え置き。2026.8.0-alpha.0 は prerelease なので**方針どおり動かない**。
  ⚠ **今回は Mastodon 側だけの実走**なので、[[project_harness-zero-error-goal]]（両系エラー 0）の
  未達（#4584）は解消していない

**Mastodon v4.7.0-rc.1 を 2026-08-16 に実走済み**（RC なので `verified` は昇格させない）。
**1086 tests / 2157 assertions / 0 failures / 0 errors / 157 omissions（100% passed）**、
DB 直読み層（account / status / attachment / postgres）も **omission 0 で全緑**。
4.6.6 → 4.7.0-rc.1 でモロヘイヤに当たりうる 3 点（`accounts.uri` の nullable 化 + UNIQUE 張り替え、
`account_summaries` の実テーブル化、`AccountSerializer` の `pretty_username`）は**実コードでもすべて空振り**。
⚠ **`statuses` テーブルは 4.6.6 から無変更**（nullable になるのは `keypairs.uri`）。
⚠ **tests / omissions の増減を Mastodon 版の影響と読まない**（母数はモロヘイヤ側の開発で動く）。詳細は台帳の 2026-08-16 節。
⚠ **ポート 3000 の衝突と、失敗した proxy コンテナが `exited` で残って `up -d` を繰り返しても復旧しない罠**を踏んだ
（`docker compose rm -sf proxy` で解決）。pooza/chubo2#178 で修正済み＝**両ハーネスの同時起動が可能になった**（[test-harness.md](test-harness.md)）。

以下は現 `verified` の記録。**Mastodon v4.6.6 を 2026-08-14 に検証・verified 昇格**（pooza/chubo2#169 でピンも bump）。
**本番 3 台・ステージング 3 台へは 2026-08-14 にユーザーが適用済み**で、harness 検証は後追い。
実走は **1050 tests / 2101 assertions / 0 failures / 0 errors / 152 omissions（100% passed）**＝退行ゼロ
（omission は v4.6.5 と同数）。⚠ **実走前に `redis-cli -n 1 UNLINK tagging_dictionary` を踏んでいる**（#4583。**2026-08-15 着地済みなので次回以降は不要**）。
4.6.5 → 4.6.6 は **マイグレーション無し・依存無変更・シリアライザ無変更**で、モロヘイヤが叩く REST にも
直読みするスキーマにも掛からない。⚠ **harness の `update-version.sh` がシークレット無しの `.env` を作る不具合**
（後続の `setup.sh` が `db:prepare` で落ちる）を踏んだ。pooza/chubo2#168 として修正済み。

以下は 1 つ前の昇格（v4.6.5）の記録。**Mastodon v4.6.5 を 2026-08-09 に検証・verified 昇格**（pooza/chubo2#153 クローズ）。同一の mulukhiya HEAD を v4.6.5 / v4.6.4 でクリーン再構築して実走・比較し、**失敗集合の一致＝退行ゼロ**を確認した（1001 tests / 0 errors、両版で omission 完全一致）。詳細は [harness-verified-versions.yaml](harness-verified-versions.yaml) の 2026-08-09 節。

⚠ **07-30 の 879 tests / 0 failures とは比較にならない。** #4503 の可視化と harness のトークン供給で実行本数が増え、これまで走っていなかったテストが初めてアサートしている。**「前回 0 failures だったのに増えた」を退行と読まないこと。**上記 5 件の解消で Mastodon 側は再び 0 failures / 0 errors になり、**#4492 の解消で Misskey 側も 0 failures / 0 errors**（1004 tests / 141 omissions）。両系エラー 0 の目標を一度達成した。

⚠ **2026-08-12 の再実走で Misskey 側が 1 failures に戻っている**（`RemoteTagHandlerTest`・#4584）。**5.33.0 の退行ではない**ことは同一コミットの連続実行で確かめてあり、「新規の失敗ゼロ」でリリースを通した。`project_harness-zero-error-goal` は**未達に戻った状態**なので、#4584 / #4583 を消化するまで「両系エラー 0」と書かないこと。

### マイルストーン外の繰越（着手条件待ち）

- **#4414 security: Spotify OAuth ハードニング（size:M）** — capsicum#570 復活と歩調を合わせる（全台 OFF のため単独では着手しない）
- **#4428 test: fedi-test-harness で webhook 投稿経路をインプロセス検証する（size:M）** — chubo2#63 と対。chubo2 側の着地待ち

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

**優先度ダウン（後ろ倒し）: #4393 media_catalog sub-second 化**。2026-07-18 に優先度を下げ 5.29.0 から除外（「落ち着いた頃に」）。media_catalog 再有効化トラック（#4323/#4351/#4352/#4375/#4393、runbook=docs/media-catalog-index-plan.md）は生きているが着手時期を後ろ倒し。#4393（query 再構成/非正規化、size:L）が #4351 Gate 2 の前提ブロッカーである構図は不変。

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
- #4298 Misskey ドライブの一覧でファイル不可視（Misskey 本体／Object Storage 側の問題、状況変化があれば再開）
- #4301 capsicum #344 向け Misskey avatarDecorations API（capsicum 側の進捗待ち）

### メタ Issue（生きている）

- #4233 APIController: 残る長大エンドポイントの段階的リファクタ（サブ #4283/#4284/#4285、上記ロードマップで進行中）
- #4323 perf: media_attachments 関連 index 見直し（サブ #4393 sub-second 化 query 再構成 / #4351 zugoga 再有効化 / #4352 shallu/lbock 横展開 / #4353 本家 migration / #4375 Misskey track）。**zugoga 本番 EXPLAIN で partial index 単独では sub-second に届かないと判明し、#4393（query 再構成/非正規化、size:L）を #4351 の前提に格上げ**。実行 runbook は docs/media-catalog-index-plan.md（決定ゲート Gate 0〜2 + rollback）。Mastodon は statuses partial index、Misskey は別ルート（drive_file、daisskey で実証済み）

### マイルストーン未設定

2026-08-03 の 5.31.0 スコープ確定時点で、以下は意図的にマイルストーン未設定のまま置いている。
着手条件が揃うか、次のスコープ確定で拾う。

- **media_catalog track** — #4323（メタ）とサブ #4351 / #4352 / #4353 / #4375 / #4393。#4393（sub-second 化の query 再構成）が #4351 の前提。優先度ダウン中
- **辞書スキャンの最適化** — #4463（メモ化・辞書キャッシュ・regex 事前コンパイル）/ #4465（`TaggingDictionary#matches` の索引化）。5.30.0 で「次に削るなら辞書スキャンの CPU」と結論したが、**推測で着手しない**（計装で裏を取ってから）
- **stlf_probe まわり** — #4471 / #4476。インフラ寄りで chubo2 側の判定と対
- **#4478** FreeBSD の rc スクリプトが SSH 越しの restart で戻ってこない
- **Pleroma 系（Akkoma）対応の復活** — #4566（+ 検証環境 pooza/chubo2#164）。下記の専用節を参照
- **on-hold 群** — #3157 / #3877 / #4195 / #4196 / #4197 / #4229 / #4298 / #4301

### Pleroma 系（Akkoma）対応の復活トラック（2026-08-10 起票）

5.0 で「削除ではなく未対応」として保留した Pleroma 系を、**Akkoma を対象に**戻す趣味枠。正本は #4566。
**動機は実用ではなく「少しずつ元の形に戻す」こと**なので、リリース作業・番組表・実況まわりより常に後回しでよい。

- ⚠ **対象は Akkoma で確定。Pleroma ではない。**2026-08-10 実測で Akkoma は v3.20.0（08-08）と 2〜3 か月ごと、Pleroma 本体は 2.10.2（2026-05-03）止まり。API・DB スキーマとも互換なので**実装は Pleroma 互換 1 系統・検証は Akkoma**
- ⚠ **めいすきーは見送り（再提案しない）。**10.102.x は Misskey v10 ベース＝**MongoDB** で、復活は `ginseng-mongo` と Mongo スタックを Gemfile へ戻すことを意味する
- **足りないのは DB 直読み層だけ。**v5-plan は Akkoma を「Mastodon 系（`MastodonController` 担当）」に分類しており API はほぼ互換。一方 DB は `users` / `objects` / `activities` / `oauth_tokens` で Mastodon の `accounts` / `statuses` とは別物
- 抽象化の縫い目は生きている（`controller_name.camelize` → constantize、`sns_type` 分岐は app 全体で 20 箇所）。除去コミット #4031 / #4033 / #4034 から `git show 46c4f4e2^:<path>` で復元できる
- ⚠ **`Ginseng::Fediverse::PleromaService` は gem 側に残っているが最終更新 2024-09-16。**この 2 年ぶんの `MastodonService` の変化に追随できているかは未検証
- **CT が先。**検証環境（pooza/chubo2#164、pve の LXC）が無いまま足すと、3 系統目が「走っていないのに緑」になり #4503 で潰した状態が復活する

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

⚠ **`pulls/{number}/comments` は行に紐づくレビューコメントしか返さない。**PR 本体のコメントは
`gh api repos/pooza/mulukhiya-toot-proxy/issues/{number}/comments` で別に取る。**open PR も対象に含めること。**

- 他リポジトリ（`ginseng-*` / chubo2）の作業をしている**別セッションが、こちらの PR へ申し送りを置く**ことがある。
  投稿者は Codex ではなく `pooza` なので、bot だけを見ていると丸ごと落ちる
- 2026-08-20 の同期で実際に落とした: PR #4602 に「正本側（pooza/ginseng-style#11 / #12）で 4 cop を無効化したので
  `Minitest/RefutePathExists` の固有緩和を落とせる」という申し送りが 08-19 から置かれていた（b77dd308 で消化）

### 5. Sentry の新規イシュー確認

- `sentry-cli issues list` で未解決イシューを確認する（`~/.sentryclirc` に認証トークンとデフォルトプロジェクトが設定済み）
- 各イシューの過去コメント（対応経緯）を確認する: `curl -sH "Authorization: Bearer $TOKEN" https://sentry.io/api/0/issues/{issue_id}/comments/ | python3 -m json.tool`
- 新規・未解決のイシューがあれば内容を確認し、対応が必要か判断する（対応が必要なら GitHub Issue を起票）
- 判断結果や対応経緯はコメントとして記録する: `curl -sX POST -H "Authorization: Bearer $TOKEN" -H "Content-Type: application/json" -d '{"text":"コメント内容"}' https://sentry.io/api/0/issues/{issue_id}/comments/`
- `$TOKEN` は `~/.sentryclirc` の `[auth]` セクションから取得する
- Sentry 未導入のプロジェクトではこのステップをスキップする

### 6. 外部リポジトリの同期確認（chubo2 / ginseng-*）

対象は `pooza/chubo2`（インフラ）と `pooza/ginseng-*`（モロヘイヤが依存する自作 gem 群）。

⚠ **ginseng-\* には専任のセッションがある**（2026-08-20 ユーザー明示）。**こちらが当番のように「担当」しない。**
向こうの open Issue を棚卸ししたり、こちらのマイルストーンへ引き取ったりしない。

⚠⚠ **ただし「Issue を投げて待つ」だけにしない（2026-08-20 ユーザー指示）。**
**ginseng への修正・提案は、なるべく**たたき台を PR として**出す。**Issue だけ出すと、向こうは
「依頼元が PR を出す」と読んで `waiting:pr` で止まる（pooza/ginseng-core#526 で実際に起きた）。
判断・作り直しは向こうに委ねたうえで、動くコードとテストを添える。

- **やること**: たたき台 PR の作成、送った Issue / PR の状況確認、リリースされた gem の
  `bundle update` 追随、申し送りコメントの消化（§4 の PR 本体コメント）
- **やらないこと**: ginseng-\* の open Issue の生死判定・優先度付け・こちらのマイルストーンへの取り込み
- **たたき台 PR の作法**（pooza/ginseng-core#533 / #534 の形）:
  - ⚠ **他セッションのチェックアウトを奪わない。**`~/repos/ginseng-*` は向こうが別ブランチを
    開いていることがあるので、`git worktree add` で隔離した作業ツリーを使う
  - ⚠ **既存の赤と比較して出す。**ginseng-core は実通信・ローカル環境依存で
    **5 failures / 12 errors が常態**（pooza/ginseng-core#508）。「新規の赤ゼロ」を
    main との対比で示す
  - ⚠ **修正前の main で新テストが落ちることを確認**してから出す（回帰テストとして機能するか）
  - 設計判断は「変えて構わない」と明示する。向こうの gem の設計はあちらのもの
- ⚠ **モロヘイヤ側だけ直しても gem が値を捨てて届かないことがある**（#4589 / #4594 で 2 回踏んだ）。
  その場合は「gem へ Issue/PR → 向こうで着地 → `bundle update` → 本体 PR」の順で、**依頼側として**回す

#### 6-1. 毎セッション

- `cd ~/repos/chubo2 && git fetch origin` + `git log HEAD..origin/main --oneline` でリモートとの差分を確認
- `docs/infra-note.md` に変更があれば MEMORY.md のインフラセクションに反映が必要か判断
- chubo2 の `gh issue list --state open` で open Issue の変動を確認
- ginseng-\* は**こちらが送った Issue / PR の進捗**と、**下の「ピンのずれ」**だけ見る（一覧の棚卸しはしない）

##### ginseng-\* のピンのずれを見る（2026-08-21 追加）

⚠⚠ **ginseng-\* は依頼が無くても自走で更新される**（2026-08-21 ユーザー明示）。
`Gemfile.lock` は git gem の **revision 固定**なので、**向こうが直しても `bundle update` するまで
こちらには 1 バイトも届かない**。「Issue が close された」は**取り込み済みを意味しない**。

```sh
# ロック済み revision と各リポジトリの main HEAD を突き合わせる
ruby -e 'File.read("Gemfile.lock").scan(%r{github\.com/pooza/(ginseng-\w+)\.git\s+revision: (\h+)}) {|n,r|
  head = `gh api repos/pooza/#{n}/commits/main --jq .sha`.strip
  puts "#{n}\t#{head.start_with?(r) ? "同一" : "ずれ #{r[0,8]} -> #{head[0,8]}"}" }'
```

- **ずれていたら「何が変わったか」を読む**: `gh api repos/pooza/ginseng-X/compare/<locked>...main --jq '.commits[].commit.message'`。
  ⚠ **モロヘイヤが触る面**（`HTTP` / `Logger` / `Controller` / `TagContainer` / `Environment`）に
  当たるかで判断する
- **判断は 3 択**: ① すぐ取り込む（実害がある・依頼した修正の着地）② 次のマイルストーンで取り込む
  ③ 見送る。**②③ は理由を台帳に 1 行残す**（次の同期で同じ調査をしないため）
- ⚠ **`bundle update`（引数なし）は 8 本まとめて動く。**依頼した修正の取り込みは
  **`bundle update <gem>` と gem 単位で**行う（赤が出たときの切り分けができなくなる）
- ⚠ **取り込んだら `rake lint` と `rake test` を必ず通す。**「向こうが直した」は
  「こちらで動く」ではない。逆向き（gem がこちらの値を捨てる）で 2 回踏んでいる（#4589 / #4594）
- ⚠ **`Gemfile.lock` のルーチン最新化とは別物として扱う。**ルーチンは PR 不要（[[feedback_gemfile-lock-routine]]）
  だが、**自走更新が混じるようになったので差分を読まずに上げない**

#### 6-2. 30 日ごとの棚卸し

chubo2 の [docs/infra-note.md](https://github.com/pooza/chubo2/blob/main/docs/infra-note.md) 冒頭にある
「最終棚卸し」の日付を見る。**当日から 30 日以上経過していれば**以下を実行（経過していなければスキップ）。

- **対象は chubo2（インフラ）のみ。**⚠ **ginseng-\* は専任セッションの持ち物なので棚卸ししない**（上の注記）
- chubo2 の open Issue を 1 件ずつ、**コード・コミット・実機と突き合わせて**生死を判定する
- **一覧を眺めるだけでは不十分。** 2026-07-31 の初回棚卸しでは 30 件中 6 件が「既に終わっている」
  または「対象が消滅している」状態で、最古は 5 か月放置されていた（#4488）。実装が chubo-core 側の
  コミットで着地していると、タイトルからは終わっているか分からない
- 判定の取り方の例:
  - レシピ化系 → 該当 cookbook を開いて実装の有無を確認（`git log -- <path>` でコミットも辿る）
  - 移行・撤退系 → 実機に SSH、または `curl` / DNS 解決で新旧の状態を確認
  - ステージング関連 → `docs/infra-note.md` の現況表と突き合わせる。**旧ステージング
    （`drime` + dev04/15/22/23）は退役済み**なので、これらを対象とする Issue は陳腐化している
- close 候補は**証拠を添えて提示する**。close するかどうかの判断はユーザーに残す
- 棚卸しが済んだら `docs/infra-note.md` の「最終棚卸し」を当日に更新してコミット（close 候補が 0 件でも更新する）
- 専用の cloud/cron ジョブは使わない（§8 と同じ理由。スケジュール実行は途中で止まって手で起こす運用に
  なりがちで、セッションに織り込むほうが確実に回る）

#### 6-3. ドキュメント・メモリの棚卸し

**インフラ作業は「Mastodon / Misskey / モロヘイヤに触るか」で本セッションと chubo2 セッションに
分かれて依頼されている。セッションメモリは共有されないので、片方のメモリにだけ事実が残ると
もう片方が同じ調査を繰り返す。**

- **一次対策は棚卸しではない。**インフラの調査・変更を終えたら、**その作業の一部として**
  chubo2 の `docs/infra-note.md`（現在の状態・手順・罠・運用方針）または
  `docs/infra-history.md`（日付のある出来事）に落とす。Issue とメモリだけで済ませない。
  「リリース運用 → 通常リリース手順」の「リリース後の更新」と同じ扱いにする
- 取りこぼしの回収は chubo2 の [docs/doc-maintenance.md](https://github.com/pooza/chubo2/blob/main/docs/doc-maintenance.md) の手順で行う。
  `docs/infra-note.md` 冒頭の「最終ドキュメント棚卸し」が起点。**§6-2 の Issue 棚卸しとは軸が違う**
  （あちらは open Issue の生死、こちらは知見の置き場所）。大きめの作業トラックが終わったとき、
  またはユーザーの指示で回す
- 昇格の判定は**目視でなく grep**。メモリの中の固有名詞を `infra-note.md` / `infra-history.md` に
  投げ、ヒット 0 のものが対象。2026-08-03 の初回実施では `loop6` / `delmulin-misskey` /
  `index_tags_on_name_lower` がいずれもヒット 0 だった（#4512、pooza/chubo2#129）
- 昇格したメモリは**削除せずポインタに書き換える**（正本のパス＋なぜ非自明か）。
  メモリは git 管理外なので消すと復元できない
- **昇格しないもの**: 進め方の好み、提案の抑制（「〇〇を勧めない」）、私的判断。
  これらはセッションごとの作業ルールなので docs に上げない

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

1. **マイルストーンのIssueをすべて消化**
2. **リリース前レビュー**: 下記「リリース前レビュー」の 5 観点並列レビューを実施。必修（赤）のみ本リリースで対応し、残り（黄・緑）は Issue 起票して次リリース以降へ
3. **セキュリティレビュー**: Dependabotアラート確認、`bundle update`、bundler-audit実行。問題があれば修正コミット
4. **harness 実走（省略不可）**: chubo2 fedi-test-harness で `develop` の HEAD を実走し、**Mastodon 系・Misskey 系の両方で 0 failures / 0 errors** を確認する。手順は [test-harness.md](test-harness.md)「リリースゲートとしての実走」節。**CI の緑はこのゲートの代わりにならない**（CI は実サーバーを持たないため、アカウント依存のテスト 300 件超が omission のまま `100% passed` と出る。#4503）
5. **ステージング検証（省略不可）**: `develop` をステージング全4台（dev24 美食丼 / dev25 キュアスタ！ / dev26 デルムリン丼 = Mastodon、dev27 ダイスキー = Misskey）にデプロイし、ヘルスチェック・`/mulukhiya/api/about`・WebUI を目視確認する。緊急ホットフィックス以外で省略しない（5.7.0 で省略 → #4159 が発生した教訓）。※旧ステージング（dev04/15/22/23 + drime）は退役済み。現行の Proxmox ステージング構成は chubo2 `docs/infra-note.md`「ステージング」節を正とする
6. **バージョンバンプ**: `config/application.yaml` の `/mulukhiya/version` を更新
7. **リリースPR作成**: `develop` → `main` へPRを作成
8. **CI緑を確認してマージ**: `gh run list` でステータス確認、`in_progress` なら `gh run watch` で待つ。コードが同一でも CI 結果を踏んでからマージする
9. **タグ・リリースノート作成**: `gh release create vX.Y.Z --target main --title "X.Y.Z"`。フォーマットは [release-notes-template.md](release-notes-template.md) 参照
10. **本番デプロイ**: 全サーバーにデプロイ（sidekiq → puma → listener の順で再起動。monit停止 → restart → monit開始）
11. **リリース後の更新**:
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
