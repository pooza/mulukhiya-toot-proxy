# media_catalog index 見直し計画（#4323 ドラフト）

> **ステータス**: 調査ドラフト。**実機 EXPLAIN 未検証**。本ドキュメントの DDL は
> ローカルに DB がない環境で SQL 構造のみから設計した候補であり、適用前に
> ステージング（dev04 等）または本番相当データでの `EXPLAIN (ANALYZE, BUFFERS)`
> 検証が必須。検証・適用は chubo2 側のオプス作業（[chubo2#37](https://github.com/pooza/chubo2/issues/37) 隣接）として扱う。
>
> 検証手順は [`bin/diag/media_catalog_index.sql`](../bin/diag/media_catalog_index.sql)
> にスクリプト化済み（棚卸し → ベースライン EXPLAIN → 候補 DDL → 再計測 → 撤去）。
> 残るのは実機での実行と結果に基づく候補の取捨選択のみ。

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

ローカル投稿が連合受信に対して少数派のインスタンス（zugoga / shallu）では
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
- 連動: #4335（`cursor_pagination?` の Attachment 移譲、5.23.0 で完了）。
  本 issue で Misskey 側 SQL を複合キー cursor に移行できれば
  `Misskey::Attachment.cursor_pagination?` を true へ反転可能。
- 先行事例: chubo2 `docs/infra-note.md`「daisskey drive_file partial index
  追加 (2026-05-01)」、`pooza/misskey` PR #418
