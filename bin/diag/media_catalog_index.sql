-- media_catalog index 見直し (#4323) — 検証 & 適用スクリプト
--
-- 目的:
--   app/query/mastodon/media_catalog.sql.erb の底値レイテンシ (10 秒級) を
--   index 追加で削れるかを EXPLAIN で検証し、効果のあった候補のみ適用する。
--   設計の背景・候補 index の根拠は docs/media-catalog-index-plan.md を参照。
--
-- 対象 DB:
--   Mastodon 本体の DB (ステージング dev04 等 → 本番 shallu / zugoga / lbock)。
--   モロヘイヤは本体スキーマを管理しないため migration は持たず、index は
--   ops 作業として直接適用する (docs/media-catalog-index-plan.md「ロールアウト方針」)。
--
-- 使い方:
--   psql -d <mastodon_db> -f bin/diag/media_catalog_index.sql
--   ※ --single-transaction は付けないこと。§3 の CREATE INDEX CONCURRENTLY は
--     トランザクション内で実行できない。psql -f は文ごとに自動コミットするため
--     そのまま流せるが、§3/§6 は内容を確認のうえコメントアウトを外して実行する。
--
-- 進め方 (docs/media-catalog-index-plan.md「検証手順」):
--   1. §1 §2 を実行しベースライン (プラン・実時間・shared read) を記録
--   2. §2 で既存 index が既に効いていないか確認 (効いていれば主因の再定義)
--   3. §3 候補 A を適用 → §4 で再計測
--   4. ソートが残り効果不足なら §3 候補 B も適用 → §4 で再計測
--   5. §1 の accounts フィルタが上位コストの場合のみ候補 C
--   6. 効果のなかった候補は §6 で撤去

\timing on
\pset pager off

-- 代表パラメータ。media_catalog の実 LIMIT は /webui/media/catalog/limit (100) + 1。
\set limit 101

-- ===========================================================================
-- §1. 現状棚卸し (index / テーブル統計 / selectivity)
-- ===========================================================================

\echo '=== §1-1 既存 index 一覧 (media_attachments / statuses / accounts) ==='
SELECT tablename, indexname, indexdef
FROM pg_indexes
WHERE tablename IN ('media_attachments', 'statuses', 'accounts')
ORDER BY tablename, indexname;

\echo '=== §1-2 テーブル統計 (行数の目安) ==='
SELECT relname,
       n_live_tup,
       n_dead_tup,
       last_analyze,
       last_autoanalyze
FROM pg_stat_user_tables
WHERE relname IN ('media_attachments', 'statuses', 'accounts')
ORDER BY relname;

\echo '=== §1-3 statuses.local selectivity (病理仮説の前提) ==='
-- local 比率が低いほど「id DESC backward scan で non-local を大量フィルタ」が
-- 起きやすい。zugoga / shallu は低いはず。
SELECT count(*) FILTER (WHERE local) AS local_true,
       count(*)                       AS total,
       round(100.0 * count(*) FILTER (WHERE local)
             / nullif(count(*), 0), 3) AS local_pct
FROM statuses;

\echo '=== §1-4 accounts フィルタ selectivity (候補 C の要否判断) ==='
SELECT count(*) FILTER (WHERE silenced_at IS NOT NULL)  AS silenced,
       count(*) FILTER (WHERE suspended_at IS NOT NULL) AS suspended,
       count(*)                                         AS total
FROM accounts;

-- cursor 変種の検証用に、中間あたりの実 id を 1 件取得して :cursor へ束縛する。
-- 行数が 5000 未満なら NULL になるので、その場合は §2-3 を手動 id で実行する。
SELECT coalesce(
         (SELECT id FROM media_attachments ORDER BY id DESC OFFSET 5000 LIMIT 1),
         (SELECT max(id) FROM media_attachments)
       ) AS cursor
\gset
\echo '=== cursor 検証に使う media_attachments.id ==='
\echo :cursor

-- ===========================================================================
-- §2. ベースライン EXPLAIN (index 追加前)
-- ===========================================================================
-- 代表 3 変種。media_catalog.sql.erb を rule なし / test_account なしで展開したもの。
-- 各プランの「実行時間」「Sort の有無」「shared read (BUFFERS)」を記録すること。

\echo '=== §2-1 baseline: only_person=0, page=1, cursor なし ==='
EXPLAIN (ANALYZE, BUFFERS, VERBOSE)
SELECT attachments.id, attachments.file_file_name, attachments.file_content_type,
       attachments.file_file_size, attachments.file_meta, attachments.description,
       attachments.created_at, statuses.id, statuses.text, statuses.visibility,
       accounts.username, accounts.display_name
FROM media_attachments AS attachments
  INNER JOIN statuses ON attachments.status_id = statuses.id
  INNER JOIN accounts ON statuses.account_id = accounts.id
WHERE (statuses.local = true)
  AND (statuses.reblog_of_id IS NULL)
  AND (statuses.visibility < 2)
  AND (statuses.deleted_at IS NULL)
  AND (accounts.silenced_at IS NULL)
  AND (accounts.suspended_at IS NULL)
ORDER BY attachments.id DESC
LIMIT :limit OFFSET 0;

\echo '=== §2-2 baseline: only_person=1 (actor_type フィルタあり) ==='
EXPLAIN (ANALYZE, BUFFERS, VERBOSE)
SELECT attachments.id, attachments.file_file_name, attachments.file_content_type,
       attachments.file_file_size, attachments.file_meta, attachments.description,
       attachments.created_at, statuses.id, statuses.text, statuses.visibility,
       accounts.username, accounts.display_name
FROM media_attachments AS attachments
  INNER JOIN statuses ON attachments.status_id = statuses.id
  INNER JOIN accounts ON statuses.account_id = accounts.id
WHERE (statuses.local = true)
  AND (statuses.reblog_of_id IS NULL)
  AND (statuses.visibility < 2)
  AND (statuses.deleted_at IS NULL)
  AND ((accounts.actor_type = 'Person') OR (accounts.actor_type IS NULL))
  AND (accounts.silenced_at IS NULL)
  AND (accounts.suspended_at IS NULL)
ORDER BY attachments.id DESC
LIMIT :limit OFFSET 0;

\echo '=== §2-3 baseline: cursor あり (キーセットページング) ==='
EXPLAIN (ANALYZE, BUFFERS, VERBOSE)
SELECT attachments.id, attachments.file_file_name, attachments.file_content_type,
       attachments.file_file_size, attachments.file_meta, attachments.description,
       attachments.created_at, statuses.id, statuses.text, statuses.visibility,
       accounts.username, accounts.display_name
FROM media_attachments AS attachments
  INNER JOIN statuses ON attachments.status_id = statuses.id
  INNER JOIN accounts ON statuses.account_id = accounts.id
WHERE (statuses.local = true)
  AND (statuses.reblog_of_id IS NULL)
  AND (statuses.visibility < 2)
  AND (statuses.deleted_at IS NULL)
  AND (accounts.silenced_at IS NULL)
  AND (accounts.suspended_at IS NULL)
  AND (attachments.id < :cursor)
ORDER BY attachments.id DESC
LIMIT :limit;

-- ===========================================================================
-- §3. 候補 index の適用 (DDL)
-- ===========================================================================
-- 内容を確認のうえ、検証手順に従い 1 候補ずつコメントアウトを外して実行する。
-- すべて CONCURRENTLY + IF NOT EXISTS。Mastodon 本体の auto-naming
-- (index_<table>_on_<cols>) と衝突しないよう独自プレフィックス idx_mlkhy_ を付与。

-- --- 候補 A: statuses 側 partial composite (第一候補) -----------------------
-- local かつ可視・非削除・非リブログの status を id 降順で辿れるようにする。
-- media_attachments へは既存 index_media_attachments_on_status_id で probe。
-- ※ 既存 index_statuses_local 等で §2 が十分速いなら本候補は不要。
-- CREATE INDEX CONCURRENTLY IF NOT EXISTS idx_mlkhy_statuses_local_catalog
-- ON statuses (id DESC, account_id)
-- WHERE local = true
--   AND reblog_of_id IS NULL
--   AND deleted_at IS NULL
--   AND visibility < 2;

-- --- 候補 B: media_attachments 側 covering (A で ORDER BY が解決しない場合) ---
-- CREATE INDEX CONCURRENTLY IF NOT EXISTS idx_mlkhy_media_attachments_status_id_desc
-- ON media_attachments (status_id, id DESC);

-- --- 候補 C: accounts 側 (silenced/suspended が上位コストの場合のみ) ----------
-- CREATE INDEX CONCURRENTLY IF NOT EXISTS idx_mlkhy_accounts_active_person
-- ON accounts (id)
-- WHERE silenced_at IS NULL AND suspended_at IS NULL;

-- 適用直後はプランナーに最新統計を渡しておく。
-- ANALYZE media_attachments;
-- ANALYZE statuses;
-- ANALYZE accounts;

-- ===========================================================================
-- §4. 再計測 EXPLAIN (index 追加後)
-- ===========================================================================
-- §2 と同一クエリを再実行し、底値が下がるか・Sort が消えるかを比較する。
-- §2-1 / §2-2 / §2-3 のブロックをそのまま再掲。

\echo '=== §4-1 after: only_person=0, page=1, cursor なし ==='
EXPLAIN (ANALYZE, BUFFERS, VERBOSE)
SELECT attachments.id, attachments.file_file_name, attachments.file_content_type,
       attachments.file_file_size, attachments.file_meta, attachments.description,
       attachments.created_at, statuses.id, statuses.text, statuses.visibility,
       accounts.username, accounts.display_name
FROM media_attachments AS attachments
  INNER JOIN statuses ON attachments.status_id = statuses.id
  INNER JOIN accounts ON statuses.account_id = accounts.id
WHERE (statuses.local = true)
  AND (statuses.reblog_of_id IS NULL)
  AND (statuses.visibility < 2)
  AND (statuses.deleted_at IS NULL)
  AND (accounts.silenced_at IS NULL)
  AND (accounts.suspended_at IS NULL)
ORDER BY attachments.id DESC
LIMIT :limit OFFSET 0;

\echo '=== §4-2 after: only_person=1 ==='
EXPLAIN (ANALYZE, BUFFERS, VERBOSE)
SELECT attachments.id, attachments.file_file_name, attachments.file_content_type,
       attachments.file_file_size, attachments.file_meta, attachments.description,
       attachments.created_at, statuses.id, statuses.text, statuses.visibility,
       accounts.username, accounts.display_name
FROM media_attachments AS attachments
  INNER JOIN statuses ON attachments.status_id = statuses.id
  INNER JOIN accounts ON statuses.account_id = accounts.id
WHERE (statuses.local = true)
  AND (statuses.reblog_of_id IS NULL)
  AND (statuses.visibility < 2)
  AND (statuses.deleted_at IS NULL)
  AND ((accounts.actor_type = 'Person') OR (accounts.actor_type IS NULL))
  AND (accounts.silenced_at IS NULL)
  AND (accounts.suspended_at IS NULL)
ORDER BY attachments.id DESC
LIMIT :limit OFFSET 0;

\echo '=== §4-3 after: cursor あり ==='
EXPLAIN (ANALYZE, BUFFERS, VERBOSE)
SELECT attachments.id, attachments.file_file_name, attachments.file_content_type,
       attachments.file_file_size, attachments.file_meta, attachments.description,
       attachments.created_at, statuses.id, statuses.text, statuses.visibility,
       accounts.username, accounts.display_name
FROM media_attachments AS attachments
  INNER JOIN statuses ON attachments.status_id = statuses.id
  INNER JOIN accounts ON statuses.account_id = accounts.id
WHERE (statuses.local = true)
  AND (statuses.reblog_of_id IS NULL)
  AND (statuses.visibility < 2)
  AND (statuses.deleted_at IS NULL)
  AND (accounts.silenced_at IS NULL)
  AND (accounts.suspended_at IS NULL)
  AND (attachments.id < :cursor)
ORDER BY attachments.id DESC
LIMIT :limit;

-- ===========================================================================
-- §5. index サイズ確認 (採用判断・記録用)
-- ===========================================================================
\echo '=== §5 idx_mlkhy_ index のサイズ ==='
SELECT indexrelname AS index,
       pg_size_pretty(pg_relation_size(indexrelid)) AS size,
       idx_scan AS scans
FROM pg_stat_user_indexes
WHERE indexrelname LIKE 'idx_mlkhy_%'
ORDER BY indexrelname;

-- ===========================================================================
-- §6. 撤去 (効果のなかった候補のみ)
-- ===========================================================================
-- DROP INDEX CONCURRENTLY IF EXISTS idx_mlkhy_statuses_local_catalog;
-- DROP INDEX CONCURRENTLY IF EXISTS idx_mlkhy_media_attachments_status_id_desc;
-- DROP INDEX CONCURRENTLY IF EXISTS idx_mlkhy_accounts_active_person;
