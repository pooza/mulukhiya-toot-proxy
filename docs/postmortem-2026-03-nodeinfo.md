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

## 関連

- [#4121 nodeinfo 依存の見直し](https://github.com/pooza/mulukhiya-toot-proxy/issues/4121)
- [chubo2#6 ステージング nginx に mulukhiya_backend map を設定](https://github.com/pooza/chubo2/issues/6)
- [chubo2#7 monit HTTP インターフェースの設定](https://github.com/pooza/chubo2/issues/7)
