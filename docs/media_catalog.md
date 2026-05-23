# メディアカタログ機能

モロヘイヤが提供する **メディアカタログ** （`/mulukhiya/api/media`、`/mulukhiya/feed/media`、`MediaCatalogUpdateWorker`）は、当該インスタンスのローカル投稿に添付されたメディア（画像・動画・音声）をページング可能なカタログとして配信する機能。capsicum などのクライアントがメディア一覧画面を提供するために利用する。

**5.23.0 (#4343) から デフォルト無効** に変更された。実験的機能として扱い、性能影響を理解したサーバー管理者だけが明示的にオプトインする運用に切り替えている。

## 5.23.0 でのデフォルト変更の経緯

本機能の SQL クエリ（`app/query/{mastodon,misskey}/media_catalog.sql.erb`）は、ローカル投稿が連合受信に対して少数派になる本番規模で、PostgreSQL のプランナが `media_attachments` PK の id 降順 backward scan + フィルタアウトを選び、LIMIT を満たす local 行が見つかるまで非 local 行を大量に舐める病理を起こす。

- **本番ベースライン（zugoga、2026-05-23 計測）**: 単一クエリで実行時間 **175,248 ms（約 2 分 55 秒）**。対象テーブル `media_attachments` 1,872,570 行、`statuses` 約 1,500 万行、local 比率 0.27%。
- **2026-05-19 障害**: 全サーバー（zugoga / shallu / lbock）で投稿不可。重 SQL が DB 接続プール（pgbouncer）を専有し、Mastodon Web の `POST /inbox` 等が連鎖タイムアウト。
- **最適化（#4323）の規模**: partial index `idx_mlkhy_statuses_local_catalog` 追加を candidate A として確定（[`docs/media-catalog-index-plan.md`](media-catalog-index-plan.md) 参照）。daisskey の drive_file partial index で 29,500 ms → 0.7 ms に削減した先行事例と同型。ただし本番複数台への段階的展開・観測で 1〜2 週間スケール。
- **判断**: 機能自体が pooza の毎晩ルーチン（Annict + 番組表）と独立しており、最適化を急ぐより停止する選択を取った。partial index と機能再開はセットで判断する。

詳細経緯と最適化計画は [`docs/media-catalog-index-plan.md`](media-catalog-index-plan.md)、検証スクリプトは [`bin/diag/media_catalog_index.sql`](../bin/diag/media_catalog_index.sql) を参照。

## クライアント側の挙動（5.23.0 以降）

サーバーがメディアカタログを **無効** にしている場合:

- `GET /mulukhiya/api/about` の `config.features.media_catalog` が `false`。クライアントは事前にこの値を見て UI を「メンテナンス中」相当に切替可能。
- `GET /mulukhiya/api/media`（旧 404）→ **HTTP 503** + body `{"available": false, "items": [], "has_next": false}`。404 = 「このサーバではエンドポイント自体が提供されていない」と区別し、503 = 「機能はあるが現在 OFF」 を明示する。
- `GET /mulukhiya/feed/media`（旧 404）→ **HTTP 503** + 空 channel の RSS。
- `MediaCatalogUpdateWorker` は schedule（30 分毎）には登録されているが、`disable?` が短絡して何もしない。

サーバーが **有効** にしている場合のレスポンス形状は [`docs/api.md`](api.md) の `/media` セクションを参照。

capsicum 側のクライアント対応は [`pooza/capsicum#606`](https://github.com/pooza/capsicum/issues/606) で進行。

## 機能を有効化する手順（オプトイン）

「本番規模のローカル投稿数 × 連合経由メディア数」が大きいインスタンスでは、有効化前に partial index 適用を推奨する（後述）。

### 設定

サーバーの `config/local.yaml`（または `/usr/local/etc/mulukhiya-toot-proxy/local.yaml`）に追記:

**Mastodon インスタンス**:

```yaml
mastodon:
  data:
    media_catalog: true
```

**Misskey インスタンス**:

```yaml
misskey:
  data:
    media_catalog: true
```

### 反映

設定変更後、以下を再起動する:

- `sidekiq` プロセス（`MediaCatalogUpdateWorker` の有効化を読み直すため）
- `puma` プロセス（API・Feed の 503 → 200 切替を読み直すため）

サービス名は環境依存。例:

- FreeBSD: `sudo service mulukhiya-toot-proxy-sidekiq restart` / `sudo service mulukhiya-toot-proxy-puma restart`
- Linux (systemd): `sudo systemctl restart mulukhiya-toot-proxy-sidekiq mulukhiya-toot-proxy-puma`

### 確認

```sh
curl -s https://your.instance/mulukhiya/api/about | jq '.config.features.media_catalog'
# => true なら有効
```

## 再開判断のチェックリスト

性能影響を踏まえ、本番規模のインスタンスで有効化する場合は以下を段階的に確認することを推奨する:

1. **本番データ規模の把握** — `statuses` 行数、`media_attachments` 行数、local 比率（`SELECT count(*) FILTER (WHERE local) * 1.0 / count(*) FROM statuses`）。
2. **ベースライン EXPLAIN 取得** — [`bin/diag/media_catalog_index.sql`](../bin/diag/media_catalog_index.sql) §1–§2 を本番 DB で実行。底値が数百 ms 級なら有効化リスクは低い。10 秒級以上なら index 適用を先行。
3. **partial index 適用（必要時）** — [`docs/media-catalog-index-plan.md`](media-catalog-index-plan.md) の candidate A を `CREATE INDEX CONCURRENTLY` で適用し、`bin/diag/media_catalog_index.sql` §4 で再計測。
4. **sidekiq 余力の確認** — `MediaCatalogUpdateWorker` は専用キュー（`media_catalog`、concurrency 1、`config/application.yaml` の `sidekiq.capsule.media_catalog`）で隔離されているが、worker 起動中は当該クエリが DB に居座る。pgbouncer の `pool_mode = transaction` 等で他の接続を圧迫しない構成になっているか確認。
5. **段階適用** — 開発・ステージング → 本番の順で `local.yaml` 切替・再起動・観測（pgbouncer の `SHOW POOLS`、sidekiq dashboard、Sentry レイテンシ）。

開発・ステージング環境ではデータ規模が桁違いに小さいため Seq Scan が選ばれ病理が再現しないことが多い。性能評価は本番規模で行う必要がある。

## 関連

- [`docs/media-catalog-index-plan.md`](media-catalog-index-plan.md) — partial index 計画と candidate A/B/C DDL
- [`bin/diag/media_catalog_index.sql`](../bin/diag/media_catalog_index.sql) — 検証スクリプト（棚卸し → ベースライン → 候補 DDL → 再計測 → 撤去）
- [`docs/api.md`](api.md) `/media` セクション — API レスポンス仕様
- [#4343](https://github.com/pooza/mulukhiya-toot-proxy/issues/4343) — デフォルト無効化と disabled シグナル
- [#4323](https://github.com/pooza/mulukhiya-toot-proxy/issues/4323) — partial index 見直し（on-hold）
- [pooza/capsicum#606](https://github.com/pooza/capsicum/issues/606) — クライアント側 gate
