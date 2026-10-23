-- Misskey の media_catalog の重さを測る (#4838) — 読み取りのみ
--
-- 目的:
--   app/query/misskey/media_catalog.sql.erb の重さを、有効にする前（またはした直後）に
--   本番規模の DB で確かめる。Misskey の重さはローカルのノート数に比例する。
--   ⚠ Mastodon 用の bin/diag/media_catalog_index.sql は statuses / media_attachments を
--   見るので、Misskey では使えない。
--
-- 対象 DB:
--   Misskey 本体の DB。書き込みも index の追加もしない。
--
-- 使い方:
--   psql -d <misskey_db> -f bin/diag/misskey_media_catalog.sql
--
-- 目安（ダイスキー・2026-10-14・追加の index なし）:
--   note 約 33 万行・ローカルの公開で添付つきのノート 1,366 で、
--   §2-1 が 69 ms・§2-2 が 153 ms。数百 ms 級ならリスクは低い。
--   秒単位なら overlay で /misskey/data/media_catalog: false に戻し、
--   §1 の件数と §2 の実行計画を添えて報告する。

\timing on
\pset pager off

-- 代表パラメータ。media_catalog の実 LIMIT は /webui/media/catalog/limit (100) + 1。
\set limit 101
\set deep_offset 2500

-- ===========================================================================
-- §1. データ規模
-- ===========================================================================

\echo '=== §1-1 テーブル統計 (行数の目安) ==='
SELECT relname,
       n_live_tup,
       n_dead_tup,
       last_analyze,
       last_autoanalyze
FROM pg_stat_user_tables
WHERE relname IN ('note', 'drive_file', 'user')
ORDER BY relname;

\echo '=== §1-2 ローカルの公開で添付つきのノート (カタログに載る母数) ==='
SELECT count(*)                                            AS notes_with_files,
       count(*) FILTER (WHERE array_length("fileIds", 1) > 1) AS notes_with_multiple_files
FROM note
WHERE (0 < array_length("fileIds", 1))
  AND ("userHost" IS null)
  AND (visibility = 'public');

-- ===========================================================================
-- §2. 実行計画 (media_catalog.sql.erb を、cursor・キーワードなしで展開したもの)
-- ===========================================================================

\echo '=== §2-1 1 ページ目 ==='
EXPLAIN (ANALYZE, BUFFERS)
SELECT drive_file.id, note_file.note_id, note_file.file_order
FROM drive_file
  INNER JOIN (
    SELECT note.id AS note_id,
           unnest(note."fileIds") AS file_id,
           generate_subscripts(note."fileIds", 1) AS file_order
    FROM note
      INNER JOIN "user" ON note."userId" = "user".id
    WHERE (0 < array_length(note."fileIds", 1))
      AND (note."userHost" IS null)
      AND (note.visibility = 'public')
    ORDER BY note.id DESC
  ) AS note_file ON drive_file.id = note_file.file_id
WHERE (drive_file."userHost" IS null)
ORDER BY note_file.note_id DESC, note_file.file_order ASC
LIMIT :limit OFFSET 0;

\echo '=== §2-2 深いページ (OFFSET 2500) ==='
EXPLAIN (ANALYZE, BUFFERS)
SELECT drive_file.id, note_file.note_id, note_file.file_order
FROM drive_file
  INNER JOIN (
    SELECT note.id AS note_id,
           unnest(note."fileIds") AS file_id,
           generate_subscripts(note."fileIds", 1) AS file_order
    FROM note
      INNER JOIN "user" ON note."userId" = "user".id
    WHERE (0 < array_length(note."fileIds", 1))
      AND (note."userHost" IS null)
      AND (note.visibility = 'public')
    ORDER BY note.id DESC
  ) AS note_file ON drive_file.id = note_file.file_id
WHERE (drive_file."userHost" IS null)
ORDER BY note_file.note_id DESC, note_file.file_order ASC
LIMIT :limit OFFSET :deep_offset;
