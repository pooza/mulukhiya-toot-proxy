# ポストモーテム: nodeinfo 循環呼び出しによる本番全面停止 (2026-03)

**発生日**: 2026-03-02
**記録日**: 2026-03-02
**解決**: v5.2.1 に切り戻し。根本対策は #4121 で対応予定

## 概要

v5.3.0 のデプロイにおいて、本番 Mastodon 全3サーバーの WebUI が停止した。2度デプロイし2度切り戻す結果となった。直接の原因は nodeinfo メソッドへの rescue 追加が循環呼び出しを無限ループ化させたこと。背景には nodeinfo 依存の構造的な問題がある。

## 影響

- 本番 Mastodon 全3サーバー（delmulin, bshockdon, curesta）の WebUI が停止
- 投稿機能も停止（puma がハングし全リクエストがタイムアウト）
- 2度のデプロイ・切り戻しで断続的に約1時間の障害

## 時系列

### 第1回デプロイ（06:00頃）

v5.3.0 の主要変更は `/mulukhiya/api/about` のレスポンス拡張（#4113）。

1. 3台にデプロイ・puma 再起動
2. `/about` API は 200 を返すが、WebUI が 502/500
3. 原因: `/about` の `Handler.all` が `Parallel.each` で全ハンドラを並列生成 → 各ハンドラの初期化で nodeinfo HTTP リクエストが発生 → Mastodon のレート制限（429）を誘発
4. `Handler.all` → `Handler.all_names` に修正（HTTP 呼び出しを排除）
5. 修正をコミット・プッシュ・タグ更新、再デプロイ → WebUI 200 OK を確認
6. しかし WebUI のレスポンスタイムが約2秒（後に異常と判明）

### レート制限対策

1. `breadcrumbs.slim` が毎リクエスト `sns.node_name` → nodeinfo HTTP 呼び出しを発見
2. nodeinfo に rescue を追加（Mastodon/Misskey/SNSServiceMethods の3箇所）し、429 時は空ハッシュを返すよう変更
3. Mastodon 側の `rack_attack.rb` に `MY_NETWORKS` safelist 機能が既に改造済みだったが、環境変数が未設定だった
4. `.env.production` に `MY_NETWORKS` を設定（パブリック IP アドレス含む）

### 第2回デプロイ（07:10頃）

1. rescue 追加 + MY_NETWORKS 設定後、Mastodon と mulukhiya-puma を再起動
2. puma が起動するも応答なし（CPU 90%超でハング）
3. 全サーバーの WebUI・投稿機能が完全停止
4. v5.2.1 に切り戻し → 即座に復旧（レスポンスタイム: ミリ秒単位）

## 原因

### 直接原因: rescue による循環呼び出しの無限ループ化

以下の循環呼び出しが存在する:

```
SNSServiceMethods#nodeinfo
  → super.merge(mulukhiya: config.about)
    → config.about
      → controller.max_length
        → parser.max_length
          → default_max_length
            → service.max_post_text_length
              → info (= nodeinfo)  ← 新しいServiceインスタンスで再帰
```

- **rescue なし（v5.2.1）**: 循環の途中で例外（HTTP エラー等）が発生すると伝播して循環が中断される。結果として正常に動作しているように見えていた
- **rescue あり**: エラーを `{}` で吸収するため循環が止まらず、無限ループに陥る

### 背景原因

1. **`config.about` と `nodeinfo` の相互依存**: `nodeinfo` が `config.about` を呼び、`config.about` が `max_post_text_length` 経由で `nodeinfo` を呼ぶ循環構造
2. **インスタンスレベルのメモ化が効かない**: ginseng の `@nodeinfo ||= ...` はインスタンス変数だが、循環の途中で新しい Service インスタンスが生成されるためメモ化が効かない
3. **毎リクエストの nodeinfo HTTP 呼び出し**: `before` フィルタで毎回 `sns_class.new` するため、リクエスト間でのメモ化も効かない
4. **パブリック IP アドレス経由の通信**: mulukhiya → Mastodon の通信が DNS 解決でパブリック IP アドレスに向かうため、Rack::Attack の localhost safelist（`127.0.0.1`）が無効

## 対策

### 完了済み

- main ブランチを v5.2.1 にリセット
- 本番3台を v5.2.1 に切り戻し
- `MY_NETWORKS` に各サーバーのパブリック IP アドレスを設定（Mastodon `.env.production`）
- #4121 Issue に全問題を記録

### 未完了（#4121 で対応）

- **nodeinfo キャッシュ**: 起動時 + Sidekiq Worker で定期取得し、リクエストごとの HTTP 呼び出しを排除
- **循環呼び出しの解消**: `config.about` と `nodeinfo` の相互依存を断ち切る設計変更
- **MY_NETWORKS の効果検証**: パブリック IP アドレスでの safelist が正しく機能するか確認

## 教訓

1. **例外による中断に依存した正常動作は脆弱**: v5.2.1 の nodeinfo は「例外で循環が止まる」ことで動作していた。この隠れた循環構造は rescue 追加で顕在化した
2. **rescue の追加は副作用を伴いうる**: エラーハンドリングの追加が、例外伝播に依存していた暗黙の制御フローを壊すことがある
3. **レスポンスタイムの異常を見逃さない**: 第1回デプロイ後の「約2秒」を正常範囲と判断したが、v5.2.1 ではミリ秒単位だった。この時点で循環の兆候だった
4. **本番デプロイ後の確認項目にレスポンスタイムの比較を含める**: ステータスコードだけでなく、v5.2.1 との応答速度比較で異常を検出できた
5. **ステージング環境のネットワーク構成を本番に近づける**: ステージングで再現できなかった問題が本番で発生した

## 後続障害: リスナーデーモン停止 + monit リスタートループ (2026-03-02 08:00頃)

### 発端

v5.2.1 切り戻し後、お知らせボットの即時投稿が美食丼・デルムリン丼で動作しないことに気づき調査を開始。キュアスタ！のみ即時投稿が動作していた。

### 発見した問題

1. **リスナーデーモンの WebSocket ゾンビ化**: 3サーバーとも元のリスナープロセス（05:22起動）が CPU 95〜105% でスピンしていた。nodeinfo インシデント時に Mastodon streaming の WebSocket 接続が無通知で切断され、リトライループが空回りしていた
2. **Mastodon streaming 全停止**: 3サーバーとも `mastodon-streaming`（node プロセス）が停止しており、リスナーの WebSocket 接続が 502 で拒否されていた
3. **daemon-spawn の PID 管理不具合**: サーバーの ginseng-core が 1.15.19（daemon-spawn ベース）のまま。rc.d の `daemon(8)` と daemon-spawn の二重デーモン化で PID ファイルが書かれず、monit がリスナーを追跡できなかった
4. **monit リスタートループ**: monit がリスナー停止を検知 → restart → PID 書かれない → 失敗判定 → 再 restart の無限ループ。孤児プロセスが各サーバー6〜9個蓄積
5. **美食丼が develop（5.3.0）のまま**: main リセット後の `git pull` が行われておらず、nodeinfo 循環呼び出し問題が残存。リスナー起動時に `SystemStackError: stack level too deep` で即死

### 対処

1. monit 停止 → 孤児リスナープロセスを全 kill（SIGTERM 無効で SIGKILL 必要）
2. 全サーバーを main（v5.2.1）に統一（`git fetch && git reset --hard origin/main`）
3. ginseng-core を 1.15.19 → 1.15.21 に更新（daemon-spawn 依存除去）
4. Mastodon streaming を手動起動（#4105 の rc.d ブロック問題あり）
5. Puma・Sidekiq・Listener を起動し、PID ファイルの正常書き込みを確認
6. monit 起動、リスタートループが発生しないことを確認
7. 全サーバーの `/mulukhiya/api/health` が 200 OK を確認

### 追加の教訓

1. **切り戻し後の streaming 確認**: v5.2.1 への切り戻し時に Mastodon streaming の再起動が漏れていた。切り戻し手順にストリーミングサービスの確認を含めるべき
2. **ginseng-core の Gemfile.lock 更新**: main/develop ともに Gemfile.lock が古いまま放置されていた。daemon-spawn 廃止（#4098）後に `bundle update ginseng-core` + Gemfile.lock のコミットが必要だった
3. **monit の PID 監視の脆弱性**: PID ファイルの有無だけでなく、プロセスの実質的な死活（WebSocket 接続状態、最終イベント受信時刻等）を検知すべき（#4123）
4. **SIGTERM で死なないプロセスへの備え**: WebSocket リトライループがスピンすると SIGTERM が処理されない。EventMachine ループ内でのシグナル処理改善が必要

### 残課題

- [#4123 rc.d の daemon(8) 経由で ListenerDaemon の PID ファイルが書かれない](https://github.com/pooza/mulukhiya-toot-proxy/issues/4123)

## ステージング検証: zugoga (2026-03-02)

教訓5「ステージング環境のネットワーク構成を本番に近づける」を受け、Linode VPS 上に本番同等のネットワーク構成（パブリック IP アドレス経由の自己参照通信）を持つステージング環境 zugoga.b-shock.co.jp を構築し、develop ブランチの修正を検証した。

### 環境

- Linode VPS (FreeBSD 14.3-RELEASE, 1 vCPU, RAM 2GB)
- 自己署名 SSL 証明書（nginx HTTPS）
- パブリック IP アドレス経由で mulukhiya → Mastodon の通信が発生する構成（本番と同一）

### 検証結果

| 検証項目 | 結果 | 詳細 |
|---------|------|------|
| nodeinfo キャッシュ | OK | 初回 0.17s、キャッシュ後 0.10s（本番での約2秒から大幅改善） |
| 循環呼び出し解消 | OK | `X-Mulukhiya` ヘッダによる map 変数でバックエンド振り分け。mulukhiya → 自身への nodeinfo リクエストが Mastodon に直接ルーティングされ、循環が構造的に解消 |
| rescue の安全性 | OK | nodeinfo キャッシュにより rescue が循環を引き起こす経路が消滅 |
| MY_NETWORKS | OK | 設定後は Rack::Attack の safelist が機能し、429 なし |
| PID ファイル (#4123) | OK | `PumaDaemon.pid`、`SidekiqDaemon.pid` が正常に書き込まれ、monit で追跡可能 |
| WebSocket streaming | OK | `/api/v1/streaming/health` が 200 を返す |

### 構築中に発見した問題

1. **Sinatra 4.1.1 HostAuthorization**: `RACK_ENV` 未指定（development モード）では、Sinatra の `HostAuthorization` ミドルウェアが外部ホスト名を拒否し 403 を返す。rc.d スクリプトに `RACK_ENV=production` の追加が必要 → [config/sample/freebsd/](../config/sample/freebsd/) に反映済み
2. **設定ディレクトリのパス**: `Mulukhiya::Package.name` が `mulukhiya-toot-proxy` を返すため、設定ディレクトリは `/usr/local/etc/mulukhiya-toot-proxy/`（`/usr/local/etc/mulukhiya/` ではない）→ [config/sample/README.md](../config/sample/README.md) に記載済み
3. **FreeBSD rbenv Ruby の SSL CA バンドル**: rbenv でビルドした Ruby は `/usr/local/openssl/cert.pem` を CA ストアとして参照する。自己署名証明書環境では `SSL_CERT_FILE` 環境変数で CA バンドルのパスを指定する必要がある
4. **ginseng-fediverse contact_account nil**: 新規 Mastodon サーバーで `contact_account` が未設定の場合、`mastodon_service.rb:13` で nil エラー → [ginseng-fediverse#238](https://github.com/pooza/ginseng-fediverse/issues/238)

### 残課題（ユーザー対応）

- Mastodon 管理画面でサーバー連絡先アカウントを設定
- GitHub SSH キーの配置（デプロイ自動化のため）
- S3 互換ストレージの設定（メディアファイル）
- Let's Encrypt による正規 SSL 証明書の取得

## 関連

- [#4121 nodeinfo 依存の見直し](https://github.com/pooza/mulukhiya-toot-proxy/issues/4121)
- [#4123 rc.d の daemon(8) 経由で PID ファイルが書かれない](https://github.com/pooza/mulukhiya-toot-proxy/issues/4123)
- [ginseng-fediverse#238 mastodon_service.rb の contact_account nil ガード](https://github.com/pooza/ginseng-fediverse/issues/238)
- [chubo2#6 ステージング nginx に mulukhiya_backend map を設定](https://github.com/pooza/chubo2/issues/6)
- [chubo2#7 monit HTTP インターフェースの設定](https://github.com/pooza/chubo2/issues/7)
