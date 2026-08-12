-- media_catalog sub-second 化 (#4393) — 候補比較スクリプト
--
-- 目的:
--   #4351 Gate 1 で候補 A (idx_mlkhy_statuses_local_catalog) を適用し
--   170s → 約 10s まで落ちたが、Gate 2 (overlay flip) に必要な sub-second には
--   届かなかった。本スクリプトは残る 3 案を **同じ本番データで並べて計測**し、
--   どれを採るかを決めるためのもの。設計の背景は
--   docs/media-catalog-index-plan.md 「#4393 フェーズ」を参照。
--
-- 対象 DB:
--   Mastodon 本体の DB。⚠ **zugoga 本番で取る。**ステージングは本番と桁違いに
--   少データで、プランが変わるため性能判断に使えない。
--
-- 使い方:
--   psql -d <mastodon_db> -f bin/diag/media_catalog_subsecond.sql
--   ※ --single-transaction は付けない (§3 の CREATE INDEX CONCURRENTLY 用)。
--   ※ §3 / §5 の DDL は既定でコメントアウトしてある。内容を確認して外すこと。
--
-- 判定 (docs 側と揃える):
--   go   = 代表 3 パターン (page1 / only_person / cursor) すべてで **1000ms 未満**
--   かつ = §6 の照合で現行クエリと **同じ id 列**が返ること (速いが違う結果、を防ぐ)
--
\timing on
\pset pager off

\set limit 101

-- ===========================================================================
-- §0. 前提の確認
-- ===========================================================================

\echo '=== §0-1 候補 A が生きているか (Gate 1 の適用物) ==='
SELECT indexname, indexdef
FROM pg_indexes
WHERE indexname LIKE 'idx_mlkhy_%'
ORDER BY indexname;

\echo '=== §0-2 ローカルアカウント数 (B 案の駆動表サイズ) ==='
-- B 案は「ローカルアカウントごとに attachments を id DESC で引いて merge」。
-- この件数が数百のうちは LATERAL が現実的。数万に育っていたら B 案は棄却。
SELECT count(*) AS local_accounts
FROM accounts
WHERE domain IS NULL
  AND silenced_at IS NULL
  AND suspended_at IS NULL;

\echo '=== §0-3 attachment.id と status.id の相関 (A 案の前提) ==='
-- A 案は「local status を id DESC で先に絞る」。attachment は **アップロード時**に
-- id が振られるため status より古いことがある。下の乖離が大きいほど A 案の
-- 先読み窓を広く取る必要があり、大きすぎれば A 案は棄却。
SELECT max(statuses.id - attachments.status_id) AS same_by_definition,
       count(*)                                  AS sampled
FROM media_attachments AS attachments
  INNER JOIN statuses ON attachments.status_id = statuses.id
WHERE statuses.local = true
  AND attachments.id > (SELECT max(id) - 100000 FROM media_attachments);

-- cursor 変種用の実 id を束縛する。
SELECT coalesce(
         (SELECT id FROM media_attachments ORDER BY id DESC OFFSET 5000 LIMIT 1),
         (SELECT max(id) FROM media_attachments)
       ) AS cursor
\gset
\echo '=== cursor 検証に使う media_attachments.id ==='
\echo :cursor

-- ===========================================================================
-- §1. 現行クエリ (候補 A 適用済み) の再ベースライン
--     ⚠ #4351 の計測から時間が経っている。**必ず取り直す**。
-- ===========================================================================

\echo '=== §1-1 現行 / page1 (cursor なし) ==='
EXPLAIN (ANALYZE, BUFFERS)
SELECT attachments.id
FROM media_attachments AS attachments
  INNER JOIN statuses ON attachments.status_id = statuses.id
  INNER JOIN accounts ON statuses.account_id = accounts.id
WHERE (statuses.local = true)
  AND (statuses.reblog_of_id IS null)
  AND (statuses.visibility < 2)
  AND (statuses.deleted_at IS null)
  AND (accounts.silenced_at IS null)
  AND (accounts.suspended_at IS null)
ORDER BY attachments.id DESC
LIMIT :limit;

\echo '=== §1-2 現行 / only_person ==='
EXPLAIN (ANALYZE, BUFFERS)
SELECT attachments.id
FROM media_attachments AS attachments
  INNER JOIN statuses ON attachments.status_id = statuses.id
  INNER JOIN accounts ON statuses.account_id = accounts.id
WHERE (statuses.local = true)
  AND (statuses.reblog_of_id IS null)
  AND (statuses.visibility < 2)
  AND (statuses.deleted_at IS null)
  AND ((accounts.actor_type = 'Person') OR (accounts.actor_type IS null))
  AND (accounts.silenced_at IS null)
  AND (accounts.suspended_at IS null)
ORDER BY attachments.id DESC
LIMIT :limit;

\echo '=== §1-3 現行 / cursor ==='
EXPLAIN (ANALYZE, BUFFERS)
SELECT attachments.id
FROM media_attachments AS attachments
  INNER JOIN statuses ON attachments.status_id = statuses.id
  INNER JOIN accounts ON statuses.account_id = accounts.id
WHERE (statuses.local = true)
  AND (statuses.reblog_of_id IS null)
  AND (statuses.visibility < 2)
  AND (statuses.deleted_at IS null)
  AND (accounts.silenced_at IS null)
  AND (accounts.suspended_at IS null)
  AND (attachments.id < :'cursor')
ORDER BY attachments.id DESC
LIMIT :limit;

-- ===========================================================================
-- §2. A 案 — local status を先に確定してから attachments を引く
--     コード変更のみ。index 追加なし (候補 A をそのまま使う)。
--     ⚠ 先読み窓 (probe) が必要なぶん **正確性の検証が要る** (§6)。
-- ===========================================================================

\set probe 3000

\echo '=== §2-1 A 案 / page1 ==='
EXPLAIN (ANALYZE, BUFFERS)
WITH local_statuses AS (
  SELECT statuses.id, statuses.account_id
  FROM statuses
  WHERE (statuses.local = true)
    AND (statuses.reblog_of_id IS null)
    AND (statuses.visibility < 2)
    AND (statuses.deleted_at IS null)
  ORDER BY statuses.id DESC
  LIMIT :probe
)
SELECT attachments.id
FROM local_statuses
  INNER JOIN media_attachments AS attachments ON attachments.status_id = local_statuses.id
  INNER JOIN accounts ON local_statuses.account_id = accounts.id
WHERE (accounts.silenced_at IS null)
  AND (accounts.suspended_at IS null)
ORDER BY attachments.id DESC
LIMIT :limit;

\echo '=== §2-2 A 案 / cursor ==='
-- cursor は attachments.id なので、先読み窓の側にも効かせないと窓が無駄になる。
EXPLAIN (ANALYZE, BUFFERS)
WITH local_statuses AS (
  SELECT statuses.id, statuses.account_id
  FROM statuses
  WHERE (statuses.local = true)
    AND (statuses.reblog_of_id IS null)
    AND (statuses.visibility < 2)
    AND (statuses.deleted_at IS null)
    AND (statuses.id < :'cursor')
  ORDER BY statuses.id DESC
  LIMIT :probe
)
SELECT attachments.id
FROM local_statuses
  INNER JOIN media_attachments AS attachments ON attachments.status_id = local_statuses.id
  INNER JOIN accounts ON local_statuses.account_id = accounts.id
WHERE (accounts.silenced_at IS null)
  AND (accounts.suspended_at IS null)
  AND (attachments.id < :'cursor')
ORDER BY attachments.id DESC
LIMIT :limit;

-- ===========================================================================
-- §3. B 案 — ローカルアカウント駆動の LATERAL merge
--     index を 1 本足すだけ。SELECT しかしない方針を崩さず、恒久化も #4353 と
--     同じ道 (pooza/mastodon の migration) に乗る。**第一候補。**
-- ===========================================================================

\echo '=== §3-1 B 案用 index の有無 ==='
-- Mastodon 標準の index_media_attachments_on_account_id は (account_id) のみで
-- id 順を持たない。id DESC を付けた複合が要るかを EXPLAIN で判定する。
SELECT indexname, indexdef
FROM pg_indexes
WHERE tablename = 'media_attachments'
  AND indexdef LIKE '%account_id%';

-- ⚠ 適用は内容を確認してからコメントを外す。CONCURRENTLY はトランザクション外。
-- CREATE INDEX CONCURRENTLY IF NOT EXISTS idx_mlkhy_media_attachments_account_id_id
-- ON media_attachments (account_id, id DESC);
-- ANALYZE media_attachments;

\echo '=== §3-2 B 案 / page1 ==='
EXPLAIN (ANALYZE, BUFFERS)
SELECT picked.id
FROM (
  SELECT accounts.id AS account_id
  FROM accounts
  WHERE accounts.domain IS null
    AND accounts.silenced_at IS null
    AND accounts.suspended_at IS null
) AS local_accounts
CROSS JOIN LATERAL (
  SELECT attachments.id, attachments.status_id
  FROM media_attachments AS attachments
  WHERE attachments.account_id = local_accounts.account_id
  ORDER BY attachments.id DESC
  LIMIT :limit
) AS picked
  INNER JOIN statuses ON picked.status_id = statuses.id
WHERE (statuses.local = true)
  AND (statuses.reblog_of_id IS null)
  AND (statuses.visibility < 2)
  AND (statuses.deleted_at IS null)
ORDER BY picked.id DESC
LIMIT :limit;

\echo '=== §3-3 B 案 / cursor ==='
EXPLAIN (ANALYZE, BUFFERS)
SELECT picked.id
FROM (
  SELECT accounts.id AS account_id
  FROM accounts
  WHERE accounts.domain IS null
    AND accounts.silenced_at IS null
    AND accounts.suspended_at IS null
) AS local_accounts
CROSS JOIN LATERAL (
  SELECT attachments.id, attachments.status_id
  FROM media_attachments AS attachments
  WHERE attachments.account_id = local_accounts.account_id
    AND attachments.id < :'cursor'
  ORDER BY attachments.id DESC
  LIMIT :limit
) AS picked
  INNER JOIN statuses ON picked.status_id = statuses.id
WHERE (statuses.local = true)
  AND (statuses.reblog_of_id IS null)
  AND (statuses.visibility < 2)
  AND (statuses.deleted_at IS null)
ORDER BY picked.id DESC
LIMIT :limit;

-- ===========================================================================
-- §4. 参考値 — 「理論上の下限」
--     statuses の条件を外し、ローカルアカウントの attachments を id DESC で
--     取るだけ。ここより速くはならない。B 案がこれに近ければ勝ち。
-- ===========================================================================

\echo '=== §4-1 下限の目安 ==='
EXPLAIN (ANALYZE, BUFFERS)
SELECT attachments.id
FROM media_attachments AS attachments
WHERE attachments.account_id IN (
  SELECT id FROM accounts WHERE domain IS null
)
ORDER BY attachments.id DESC
LIMIT :limit;

-- ===========================================================================
-- §5. 撤去 (効果が無かった場合)
-- ===========================================================================

-- DROP INDEX CONCURRENTLY IF EXISTS idx_mlkhy_media_attachments_account_id_id;

-- ===========================================================================
-- §6. 正確性の照合 — ⚠ **これを飛ばさない**
--     速いが違う結果を返す案を採らないため、現行クエリと id 列を突き合わせる。
--     差分が 0 行であること。A 案は先読み窓の設定次第でここが割れる。
-- ===========================================================================

\echo '=== §6-1 A 案 vs 現行 (差分 0 行なら一致) ==='
WITH current_q AS (
  SELECT attachments.id
  FROM media_attachments AS attachments
    INNER JOIN statuses ON attachments.status_id = statuses.id
    INNER JOIN accounts ON statuses.account_id = accounts.id
  WHERE (statuses.local = true)
    AND (statuses.reblog_of_id IS null)
    AND (statuses.visibility < 2)
    AND (statuses.deleted_at IS null)
    AND (accounts.silenced_at IS null)
    AND (accounts.suspended_at IS null)
  ORDER BY attachments.id DESC
  LIMIT :limit
), candidate_a AS (
  WITH local_statuses AS (
    SELECT statuses.id, statuses.account_id
    FROM statuses
    WHERE (statuses.local = true)
      AND (statuses.reblog_of_id IS null)
      AND (statuses.visibility < 2)
      AND (statuses.deleted_at IS null)
    ORDER BY statuses.id DESC
    LIMIT :probe
  )
  SELECT attachments.id
  FROM local_statuses
    INNER JOIN media_attachments AS attachments ON attachments.status_id = local_statuses.id
    INNER JOIN accounts ON local_statuses.account_id = accounts.id
  WHERE (accounts.silenced_at IS null)
    AND (accounts.suspended_at IS null)
  ORDER BY attachments.id DESC
  LIMIT :limit
)
SELECT 'missing_in_a' AS side, id FROM (SELECT id FROM current_q EXCEPT SELECT id FROM candidate_a) AS d
UNION ALL
SELECT 'extra_in_a',  id FROM (SELECT id FROM candidate_a EXCEPT SELECT id FROM current_q) AS d;

\echo '=== §6-2 B 案 vs 現行 (差分 0 行なら一致) ==='
WITH current_q AS (
  SELECT attachments.id
  FROM media_attachments AS attachments
    INNER JOIN statuses ON attachments.status_id = statuses.id
    INNER JOIN accounts ON statuses.account_id = accounts.id
  WHERE (statuses.local = true)
    AND (statuses.reblog_of_id IS null)
    AND (statuses.visibility < 2)
    AND (statuses.deleted_at IS null)
    AND (accounts.silenced_at IS null)
    AND (accounts.suspended_at IS null)
  ORDER BY attachments.id DESC
  LIMIT :limit
), candidate_b AS (
  SELECT picked.id
  FROM (
    SELECT accounts.id AS account_id
    FROM accounts
    WHERE accounts.domain IS null
      AND accounts.silenced_at IS null
      AND accounts.suspended_at IS null
  ) AS local_accounts
  CROSS JOIN LATERAL (
    SELECT attachments.id, attachments.status_id
    FROM media_attachments AS attachments
    WHERE attachments.account_id = local_accounts.account_id
    ORDER BY attachments.id DESC
    LIMIT :limit
  ) AS picked
    INNER JOIN statuses ON picked.status_id = statuses.id
  WHERE (statuses.local = true)
    AND (statuses.reblog_of_id IS null)
    AND (statuses.visibility < 2)
    AND (statuses.deleted_at IS null)
  ORDER BY picked.id DESC
  LIMIT :limit
)
SELECT 'missing_in_b' AS side, id FROM (SELECT id FROM current_q EXCEPT SELECT id FROM candidate_b) AS d
UNION ALL
SELECT 'extra_in_b',  id FROM (SELECT id FROM candidate_b EXCEPT SELECT id FROM current_q) AS d;
