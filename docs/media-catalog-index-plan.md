# media_catalog index 見直し計画 & 実行 runbook（#4323 / #4351）

> **ステータス**: 実行 runbook。候補 index の設計（背景・病理仮説・候補 A/B/C）は
> 確定済みだが、**実機 EXPLAIN は未検証**。本ドキュメントの DDL は SQL 構造から
> 設計した候補であり、適用前に**本番相当データでの `EXPLAIN (ANALYZE, BUFFERS)`
> 検証が必須**（ステージング dev04 等は本番と桁違いに少データで性能・index 検証に
> 使えないため、最初から zugoga 本番で EXPLAIN を取る）。検証・適用は chubo2 側の
> オプス作業（[chubo2#37](https://github.com/pooza/chubo2/issues/37) 隣接）。
>
> 検証手順は [`bin/diag/media_catalog_index.sql`](../bin/diag/media_catalog_index.sql)
> にスクリプト化済み（棚卸し → ベースライン EXPLAIN → 候補 DDL → 再計測 → 撤去）。
> 実行は下記「実行 runbook（#4351）」の決定ゲートに従う。Misskey 側は別ルート
> （`drive_file`/`note`、#4375）で扱う。

## 背景

`#4306`（OFFSET → cursor ページング切替、5.21.2 ホットフィックス）で OFFSET 由来の
劣化（成功 10 秒 ⇄ 劣化 数百秒の二極化）は解消した。しかし**スパイクの底値
（10 秒程度）**は index 不在に由来する根本のもので、cursor 化では下がらない。
本 issue（#4323、#4306 中期項目 3）でこの底値を index で削る。

先行事例: chubo2 `docs/infra-note.md`「daisskey drive_file partial index 追加
(2026-05-01)」。PK の id 降順 backward scan で大量行を舐める同型の病理を
partial index で 29,500ms → 0.7ms に短縮した実績がある。

## 対象クエリ

`app/query/mastodon/media_catalog.sql.erb`。要点を抽出すると:

```sql
SELECT attachments.id, ...
FROM media_attachments AS attachments
  INNER JOIN statuses ON attachments.status_id = statuses.id
  INNER JOIN accounts ON statuses.account_id = accounts.id
WHERE statuses.local = true
  AND statuses.reblog_of_id IS NULL
  AND statuses.visibility < 2
  AND statuses.deleted_at IS NULL
  AND accounts.silenced_at IS NULL
  AND accounts.suspended_at IS NULL
  -- only_person 時: AND (accounts.actor_type = 'Person' OR accounts.actor_type IS NULL)
  -- cursor 時:      AND attachments.id < :cursor
ORDER BY attachments.id DESC
LIMIT :limit
```

WHERE には他に 2 つの条件分岐がある:

- **`rule` 時**: `concat_ws(statuses.text, statuses.spoiler_text, attachments.description)
  LIKE '%keyword%'`。カスタムフィード（rule 付き、利用者 2 名）専用の経路。
  前方ワイルドカード LIKE は btree index で加速できず、加速するなら pg_trgm GIN が
  必要になるが、底値 10 秒問題は **rule なしのカタログ表示**で起きているため
  本 issue のスコープ外。候補 index は rule なしクエリの改善に閉じる。
- **`test_account` 時**: `accounts.id <> :test_account_id`。常時付与の等値否定で
  selectivity への寄与は無視できる。

候補 index（特に候補 A の partial 述語）には**常時付与される 4 条件
（local / reblog_of_id / visibility / deleted_at）のみ**を含める。
only_person / cursor / rule / test_account はクエリにより有無が変わるため
partial 述語に入れると一部の変種で index が使えなくなる。4 条件はどの変種でも
必ず付くため、partial index の述語として全変種から共用できる。

## 推定される病理（要 EXPLAIN 検証）

ローカル投稿が連合受信に対して少数派のサーバー（zugoga / shallu）では
`statuses.local = true` の selectivity が（media_attachments 全体に対しては）
極めて低い。プランナーは `ORDER BY attachments.id DESC LIMIT n` を満たすために
`media_attachments` の PK を id 降順 backward scan し、各行を statuses へ
nested-loop probe して `local = true` 等でフィルタアウトする経路を選びやすい。
LIMIT を満たす local 行が見つかるまで大量の non-local media_attachments を
舐めるため、底値 10 秒級のレイテンシになる、というのが daisskey と同型の仮説。

**未確定事項（EXPLAIN で要確認）**:

- Mastodon 本体が出荷する `index_statuses_local`（`statuses (id DESC, account_id)
  WHERE local OR uri IS NULL` 系のローカルタイムライン用 partial index）が
  この経路で採用されているか。採用されていれば底値の主因は別にある。
- 実際に backward PK scan が選ばれているか、Bitmap か、どの結合順か。
- only_person / cursor の有無でプラン分岐があるか。
- `accounts.silenced_at / suspended_at IS NULL` の選択率（ほぼ全件 true で
  寄与小か、相関で効くか）。

## 候補 index（いずれも要検証・排他ではない）

すべて `CONCURRENTLY` + `IF NOT EXISTS`、かつ **Mastodon 本体の auto-naming
（`index_<table>_on_<cols>`）と衝突しない独自プレフィックス `idx_mlkhy_`** を
付け、upstream migration / `db/schema.rb` と名前衝突しないようにする。

### 候補 A: statuses 側 partial composite（第一候補）

local かつ可視・非削除・非リブログの status を id 降順で辿れるようにし、
media_attachments へは `index_media_attachments_on_status_id`（Mastodon 既存）で
probe させる狙い。

```sql
CREATE INDEX CONCURRENTLY IF NOT EXISTS idx_mlkhy_statuses_local_catalog
ON statuses (id DESC, account_id)
WHERE local = true
  AND reblog_of_id IS NULL
  AND deleted_at IS NULL
  AND visibility < 2;
```

- 既存 `index_statuses_local` と述語が異なる（reblog/deleted/visibility を畳む）
  ため重複にならない想定。ただし**既存 index で十分なら本候補は不要** —
  EXPLAIN で既存 index 採用可否を先に確認すること。
- 懸念: 最終的な `ORDER BY attachments.id DESC` は statuses.id 順とは一致しない
  ため、ソートが残る可能性。media_attachments.id と statuses.id の相関が
  高ければ実害が小さいが、要 ANALYZE。

### 候補 B: media_attachments 側 covering（候補 A で order by が解決しない場合）

```sql
CREATE INDEX CONCURRENTLY IF NOT EXISTS idx_mlkhy_media_attachments_status_id_desc
ON media_attachments (status_id, id DESC);
```

- local status 集合に対する nested-loop で attachments を status 単位に
  id 降順で取り出せる。最終ソート削減を狙うが、複数 status をまたぐ
  グローバル `id DESC` には merge/sort が要るため、候補 A と組合せ前提。

### 候補 C: accounts 側（silenced/suspended が効く場合のみ）

```sql
CREATE INDEX CONCURRENTLY IF NOT EXISTS idx_mlkhy_accounts_active_person
ON accounts (id)
WHERE silenced_at IS NULL AND suspended_at IS NULL;
```

- EXPLAIN で accounts フィルタが上位コストでない限り**不要**。優先度低。

## 検証手順（実機 / ステージング）

検証・適用は [`bin/diag/media_catalog_index.sql`](../bin/diag/media_catalog_index.sql)
にスクリプト化済み（§1 棚卸し → §2 ベースライン EXPLAIN → §3 候補 DDL →
§4 再計測 → §5 サイズ → §6 撤去）。`psql -d <mastodon_db> -f` で流す。
以下はその実行手順の要約:

1. ベースライン取得: 代表的なパラメータ（page=1, only_person=0 / 1, cursor あり/なし）で
   `EXPLAIN (ANALYZE, BUFFERS, FORMAT TEXT)` を採取し、プラン・実時間・
   shared read を記録（スクリプト §1–§2）。
2. **まず既存 index の効きを確認**（候補追加前）。`index_statuses_local` 等が
   採用されていれば、本 issue の主因の再定義が必要。
3. 候補 A を `CONCURRENTLY` で追加 → 同一クエリ群を再計測。底値（10 秒級）が
   下がるか、ソートが消えるかを確認。
4. 候補 A で `ORDER BY` のソートが残り効果不足なら候補 B を追加し再計測。
5. 候補 C は accounts フィルタが EXPLAIN 上で有意な場合のみ。
6. 効果のなかった候補は `DROP INDEX CONCURRENTLY` で撤去（index 肥大回避）。
7. インデックスサイズ（`pg_relation_size`）と書き込み影響を記録。

## 実行 runbook（#4351 zugoga 再有効化）

「自信を持って送り出す」ため、各段に go/no-go を置き、仮説が外れたら止まる。
再有効化に **mulukhiya 側のコード変更は不要**（経路は 5.23.0 #4343 で完成・ゲート
済み。`media_catalog?` フラグ＝`config["/{name}/data/media_catalog"]` を overlay で
`true` にするだけ）。唯一の不可逆要素はなく、flip は即時 revert 可能。

### Gate 0 — 仮説の検証（read-only、安全）

`bin/diag/media_catalog_index.sql` の §1〜§2 を **zugoga 本番で直接**実行する。

- 確認: ① `statuses.local` selectivity が低いか（§1-3） ② §2 のプランが実際に
  `media_attachments` の PK backward scan ＋大量フィルタアウトか ③ **Mastodon 本体
  既存の `index_statuses_local` が既に効いていないか**（§1-1 / §2 のプラン）
- ⚠️ **no-go**: 既存 index で底値が出ている／別ノードが主因なら、候補 A は冗長。
  **追加せず病理の再定義に戻る**（これが最重要ゲート）。
- §2 の代表クエリは `rule` なし・`test_account` なしで展開してある。実運用では
  `accounts.id <> :test_account_id` が常時付くが selectivity 寄与は無視できる前提
  （[計画書「対象クエリ」参照]）。気になる場合は test_account 条件を足して再取得。

### Gate 1 — 候補 A 適用と効果判定

§3 候補 A を `CREATE INDEX CONCURRENTLY` で適用 → §4 で §2 と同一クエリを再計測。

- **go 基準**: 底値 175 秒級が明確に低下（daisskey は ms 級、最低でも秒以下を目標）。
  あわせて Sort ノードの有無を確認。
- A で `ORDER BY attachments.id DESC` の Sort が残り効果不足 → **候補 B を追加**して
  再計測（A+B 前提）。
- `accounts` フィルタが §2 で上位コスト → **候補 C**（通常は不要）。
- 効果のなかった候補は §6 で `DROP INDEX CONCURRENTLY`（index 肥大・書き込み負荷回避）。
- ⚠️ **CONCURRENTLY の失敗時**: 中断・失敗すると INVALID な index が残る。
  `\d statuses`（または `pg_index.indisvalid = false` を検索）で確認し、INVALID なら
  `DROP INDEX CONCURRENTLY idx_mlkhy_...` してから再実行する。CONCURRENTLY は
  オンライン（テーブルロックなし）だが、適用直後に `ANALYZE`（§3 末尾）で統計を更新。

### Gate 2 — overlay flip と観測（最低 24 時間）

EXPLAIN 改善を確認してから、chubo2 配下の zugoga overlay で
`/mastodon/data/media_catalog: true` に切替・デプロイ。

- 観測指標: `/feed/media` レイテンシ / `MediaCatalogUpdateWorker` 実行時間 /
  **DB 接続プール使用率**。
- ⚠️ **プール監視が「自信」の核心**: 2026-05-19 の全サーバー投稿不可障害は
  この SQL による **DB 接続プール枯渇**が最有力（#4323 隣接 / chubo2#37）。index で
  底値を削っても、遅いクエリが 1 本でも滑り込めばプールを食う。観測にプール飽和を
  必ず含め、閾値を超えたら Gate 2 の rollback を即実行する。

### Rollback

- 劣化検知 → overlay を `/mastodon/data/media_catalog: false` に戻すだけで即時収束
  （データ損失なし。`/feed/media` は 503 + `available:false` に戻る）。
- index は残しても無害だが、不要と判断したら `DROP INDEX CONCURRENTLY`。

### 記録（完了条件）

- §2 / §4 の EXPLAIN 比較と再有効化後の観測値を **#4323 にコメント**。
- 適用記録を chubo2 `docs/infra-note.md` に daisskey と同フォーマットで残す。

## ロールアウト方針

daisskey 先行事例に準拠:

- 検証は dev 系（ステージング）で先行。効果確認後に本番 Mastodon 3 台
  （shallu / zugoga / lbock）へ `CREATE INDEX CONCURRENTLY` を SQL 直適用。
- 恒久反映が必要なら `pooza/mastodon` の feature ブランチに
  `IF NOT EXISTS` 化した migration を起票（直適用済みインデックスと冪等共存）。
  **upstream Mastodon の migration / `db/schema.rb` と名前衝突しないこと**を
  PR 時に再確認（独自プレフィックス `idx_mlkhy_` で回避）。
- 適用記録は chubo2 `docs/infra-note.md` に daisskey 同様のフォーマットで残す。

## 関連

- 親 issue: #4306（cursor ページング切替、5.21.2 で完了）
- 連動: #4335（`cursor_pagination?` の Attachment 移譲、closed）。
- サブ Issue: #4351（A: zugoga 再有効化）/ #4352（B: shallu/lbock 横展開）/
  #4353（C: pooza/mastodon migration 恒久化）/ **#4375（D: Misskey track
  — `drive_file` index + 複合キー cursor 化で `Misskey::Attachment.cursor_pagination?`
  を true 反転）**。
- 先行事例: chubo2 `docs/infra-note.md`「daisskey drive_file partial index
  追加 (2026-05-01)」、`pooza/misskey` PR #418（Misskey 側が partial index 手法の
  先行実証。本 Mastodon 計画はこれを `statuses` スキーマへ移植したもの）
