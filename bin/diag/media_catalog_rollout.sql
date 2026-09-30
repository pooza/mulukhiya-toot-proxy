-- media_catalog の横展開 (#4352) — flip 前後の EXPLAIN
--
-- 目的:
--   現行の media_catalog クエリ (app/query/mastodon/media_catalog.sql.erb・#4393 の B 案)
--   が、その機体の本番データで sub-second に収まるかを flip の前後で測る。
--
--   ⚠⚠ media_catalog_subsecond.sql は使わない。あちらの「現行」は決着前の旧クエリで、
--   zugoga で 26 秒級だった。**使われていない重いクエリを本番で流すことになる。**
--
--   ⚠ zugoga には partial index (idx_mlkhy_statuses_local_catalog) が ops 直適用されて
--   いるが、shallu / gomander には無い。B 案が index 非依存という結論は zugoga の計測
--   から出したものなので、**index の無い機体で同じプランが選ばれるかをここで確かめる**。
--
-- 安全策:
--   - 読み取り専用のトランザクションで流す (EXPLAIN ANALYZE も実行はする)
--   - statement_timeout 30s。⚠ 超えたらそのクエリは中断され、以降は ROLLBACK まで失敗する。
--     超えた時点で「flip しない」の判断材料として十分
--   - count(*) の全走査はしない (行数は pg_stat_user_tables の推定値で見る)
--
-- 使い方 (作業端末から):
--   scp bin/diag/media_catalog_rollout.sql pooza@<node>:/tmp/
--   ssh pooza@<node> 'sudo -u postgres psql -d mastodon -f /tmp/media_catalog_rollout.sql'
--
-- 代表パラメータは本番の呼び出しと同じ: limit = /webui/media/catalog/limit (100) + 1、offset 0。
-- テスト用アカウントの除外 (test_account) は本番では入らない前提で省いている。

\timing on
\pset pager off
\set limit 101

BEGIN READ ONLY;
SET LOCAL statement_timeout = '30s';

\echo '=== §1-1 index (media_attachments / statuses) ==='
-- ⚠ B 案が頼るのは Mastodon 本体の index_media_attachments_on_account_id_and_status_id。
SELECT tablename, indexname, indexdef
FROM pg_indexes
WHERE tablename IN ('media_attachments', 'statuses')
ORDER BY tablename, indexname;

\echo '=== §1-2 テーブル統計 (推定行数・最終 ANALYZE) ==='
SELECT relname, n_live_tup, n_dead_tup, last_analyze, last_autoanalyze
FROM pg_stat_user_tables
WHERE relname IN ('media_attachments', 'statuses', 'accounts')
ORDER BY relname;

\echo '=== §1-3 ローカルアカウント数 (B 案の駆動表サイズ・zugoga は 19) ==='
SELECT count(*) AS local_accounts,
       count(*) FILTER (WHERE actor_type = 'Person' OR actor_type IS null) AS local_persons
FROM accounts
WHERE domain IS null AND silenced_at IS null AND suspended_at IS null;

\echo '=== §2-1 B 案 / page1 ==='
EXPLAIN (ANALYZE, BUFFERS)
SELECT picked.id, picked.status_id, accounts.username
FROM (
  SELECT accounts.id AS account_id
  FROM accounts
  WHERE (accounts.domain IS null)
    AND (accounts.silenced_at IS null)
    AND (accounts.suspended_at IS null)
) AS local_accounts
CROSS JOIN LATERAL (
  SELECT attachments.id, attachments.file_file_name AS name, attachments.file_content_type AS type,
         attachments.file_file_size AS file_size, attachments.file_meta AS meta,
         attachments.description, attachments.created_at,
         statuses.id AS status_id, statuses.text AS status_text, statuses.visibility,
         statuses.account_id AS status_account_id
  FROM media_attachments AS attachments
    INNER JOIN statuses ON attachments.status_id = statuses.id
  WHERE (attachments.account_id = local_accounts.account_id)
    AND (statuses.local = true)
    AND (statuses.reblog_of_id IS null)
    AND (statuses.visibility < 2)
    AND (statuses.deleted_at IS null)
  ORDER BY attachments.id DESC
  LIMIT :limit
) AS picked
  INNER JOIN accounts ON picked.status_account_id = accounts.id
WHERE (accounts.silenced_at IS null)
  AND (accounts.suspended_at IS null)
ORDER BY picked.id DESC
LIMIT :limit
OFFSET 0;

\echo '=== §2-2 B 案 / only_person ==='
EXPLAIN (ANALYZE, BUFFERS)
SELECT picked.id, picked.status_id, accounts.username
FROM (
  SELECT accounts.id AS account_id
  FROM accounts
  WHERE (accounts.domain IS null)
    AND (accounts.silenced_at IS null)
    AND (accounts.suspended_at IS null)
    AND ((accounts.actor_type = 'Person') OR (accounts.actor_type IS null))
) AS local_accounts
CROSS JOIN LATERAL (
  SELECT attachments.id, attachments.file_file_name AS name, attachments.file_content_type AS type,
         attachments.file_file_size AS file_size, attachments.file_meta AS meta,
         attachments.description, attachments.created_at,
         statuses.id AS status_id, statuses.text AS status_text, statuses.visibility,
         statuses.account_id AS status_account_id
  FROM media_attachments AS attachments
    INNER JOIN statuses ON attachments.status_id = statuses.id
  WHERE (attachments.account_id = local_accounts.account_id)
    AND (statuses.local = true)
    AND (statuses.reblog_of_id IS null)
    AND (statuses.visibility < 2)
    AND (statuses.deleted_at IS null)
  ORDER BY attachments.id DESC
  LIMIT :limit
) AS picked
  INNER JOIN accounts ON picked.status_account_id = accounts.id
WHERE (accounts.silenced_at IS null)
  AND (accounts.suspended_at IS null)
  AND ((accounts.actor_type = 'Person') OR (accounts.actor_type IS null))
ORDER BY picked.id DESC
LIMIT :limit
OFFSET 0;

\echo '=== cursor に使う id (page1 の末尾) ==='
SELECT min(id) AS cursor FROM (
  SELECT picked.id
  FROM (
    SELECT accounts.id AS account_id FROM accounts
    WHERE domain IS null AND silenced_at IS null AND suspended_at IS null
  ) AS local_accounts
  CROSS JOIN LATERAL (
    SELECT attachments.id, statuses.account_id AS status_account_id
    FROM media_attachments AS attachments
      INNER JOIN statuses ON attachments.status_id = statuses.id
    WHERE (attachments.account_id = local_accounts.account_id)
      AND (statuses.local = true) AND (statuses.reblog_of_id IS null)
      AND (statuses.visibility < 2) AND (statuses.deleted_at IS null)
    ORDER BY attachments.id DESC
    LIMIT :limit
  ) AS picked
    INNER JOIN accounts ON picked.status_account_id = accounts.id
  WHERE accounts.silenced_at IS null AND accounts.suspended_at IS null
  ORDER BY picked.id DESC
  LIMIT :limit
) AS page1 \gset
\echo :cursor

\echo '=== §2-3 B 案 / cursor ==='
EXPLAIN (ANALYZE, BUFFERS)
SELECT picked.id, picked.status_id, accounts.username
FROM (
  SELECT accounts.id AS account_id
  FROM accounts
  WHERE (accounts.domain IS null)
    AND (accounts.silenced_at IS null)
    AND (accounts.suspended_at IS null)
) AS local_accounts
CROSS JOIN LATERAL (
  SELECT attachments.id, attachments.file_file_name AS name, attachments.file_content_type AS type,
         attachments.file_file_size AS file_size, attachments.file_meta AS meta,
         attachments.description, attachments.created_at,
         statuses.id AS status_id, statuses.text AS status_text, statuses.visibility,
         statuses.account_id AS status_account_id
  FROM media_attachments AS attachments
    INNER JOIN statuses ON attachments.status_id = statuses.id
  WHERE (attachments.account_id = local_accounts.account_id)
    AND (statuses.local = true)
    AND (statuses.reblog_of_id IS null)
    AND (statuses.visibility < 2)
    AND (statuses.deleted_at IS null)
    AND (attachments.id < :'cursor')
  ORDER BY attachments.id DESC
  LIMIT :limit
) AS picked
  INNER JOIN accounts ON picked.status_account_id = accounts.id
WHERE (accounts.silenced_at IS null)
  AND (accounts.suspended_at IS null)
ORDER BY picked.id DESC
LIMIT :limit;

ROLLBACK;
