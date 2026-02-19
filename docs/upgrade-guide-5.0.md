# mulukhiya-toot-proxy 5.0 アップグレードガイド

**ステータス**: 作成中（#4072）

## local.yaml の設定パス変更

### `service:` 配下への移動

以下の外部サービス設定が、4.xではトップレベルだったものが5.0では `service:` 配下に移動した。

| 設定 | 4.x パス | 5.0 パス |
|------|---------|---------|
| Annict OAuth | `/annict/oauth/client/id` | `/service/annict/oauth/client/id` |
| Annict OAuth | `/annict/oauth/client/secret` | `/service/annict/oauth/client/secret` |
| Annict works | `/annict/works` | `/service/annict/works` |
| Spotify client | `/spotify/client/id` | `/service/spotify/client/id` |
| Spotify client | `/spotify/client/secret` | `/service/spotify/client/secret` |

**変更不要なもの**:
- `google:` — 5.0でも `/google/api/key` のまま（`service:` 配下に移動していない）
- `handler:` — トップレベルのまま
- `crypt:` — トップレベルのまま
- `agent:` — トップレベルのまま

### local.yaml の修正例

```yaml
# 4.x（旧）
annict:
  oauth:
    client:
      id: YOUR_CLIENT_ID
      secret: YOUR_CLIENT_SECRET
spotify:
  client:
    id: YOUR_CLIENT_ID
    secret: YOUR_CLIENT_SECRET

# 5.0（新）
service:
  annict:
    oauth:
      client:
        id: YOUR_CLIENT_ID
        secret: YOUR_CLIENT_SECRET
  spotify:
    client:
      id: YOUR_CLIENT_ID
      secret: YOUR_CLIENT_SECRET
```

### 影響

設定パスが誤っている場合、以下の症状が発生する:

- **Annict**: `AnnictService.config?` が `false` → UI設定画面にAnnict項目が非表示、PollingWorkerが即returnし感想投稿されない
- **Spotify**: Spotifyサービスのclient認証失敗 → NowPlaying等のURL処理が動作しない

### 確認コマンド

```bash
bundle exec ruby -I app/lib -e '
require "mulukhiya"
puts "annict?: #{Mulukhiya::Environment.controller_class.annict?}"
puts "spotify config?: #{!Mulukhiya::SpotifyService.client_id.nil?}"
'
```

## nginx 設定の変更

### Sidekiq ダッシュボードのアクセス制限（5.0 で追加）

Sidekiq ダッシュボードは `/mulukhiya/sidekiq` で公開される。
5.0 では、管理者以外のアクセスを防ぐために nginx 側でのアクセス制限を推奨する。

以下の location ブロックを server context に追加する（既存の `location ^~ /mulukhiya` の後）:

```nginx
location ^~ /mulukhiya/sidekiq {
  allow YOUR_IP_OR_CIDR;
  deny all;
  include /path/to/mulukhiya_proxy.conf;
  proxy_pass http://localhost:3008;
}
```

**注意事項**:

- `YOUR_IP_OR_CIDR` には管理者のIPアドレスまたはCIDRを指定する。複数行の `allow` を並べて複数のネットワークを許可可能
- LAN 内からドメイン経由でアクセスする場合、ヘアピン NAT によりクライアントの `$remote_addr` がグローバル IP になることがある。その場合はグローバル IP も `allow` に追加する
- サンプル設定: `config/sample/mastodon/mulukhiya.nginx`, `config/sample/misskey/mulukhiya.nginx`

### map 変数によるバックエンド振り分け（4.x から変更なし）

`$mulukhiya_backend`, `$media_put_backend`, `$status_put_backend` の map 定義は 4.x と同一。変更不要。

## 起動スクリプトの変更

### systemd（Ubuntu/RHEL）: 3サービス分割

4.x では1つの systemd ユニット（`mulukhiya-toot-proxy.service`）で `rake start`/`stop` を呼び、puma/sidekiq/listener を一括管理していた。

5.0 では puma/sidekiq/listener をそれぞれ独立した systemd ユニットに分割した:

| 4.x | 5.0 |
|-----|-----|
| `mulukhiya-toot-proxy.service` | `mulukhiya-puma.service` |
| （同上） | `mulukhiya-sidekiq.service` |
| （同上） | `mulukhiya-listener.service` |

サンプルは `config/sample/ubuntu/`、`config/sample/rhel/` を参照。

#### 移行手順

```bash
# 旧サービスの停止・無効化
sudo systemctl stop mulukhiya-toot-proxy
sudo systemctl disable mulukhiya-toot-proxy
sudo rm /etc/systemd/system/mulukhiya-toot-proxy.service

# 新サービスの配置（Ubuntu の例）
sudo cp config/sample/ubuntu/mulukhiya-{puma,sidekiq,listener}.service /etc/systemd/system/
# __username__ とパスをサイトに合わせて編集
sudo vi /etc/systemd/system/mulukhiya-puma.service
sudo vi /etc/systemd/system/mulukhiya-sidekiq.service
sudo vi /etc/systemd/system/mulukhiya-listener.service

# 有効化・起動
sudo systemctl daemon-reload
sudo systemctl enable mulukhiya-puma mulukhiya-sidekiq mulukhiya-listener
sudo systemctl start mulukhiya-puma mulukhiya-sidekiq mulukhiya-listener
```

#### 注意事項

- **rbenv/asdf 等を使用している場合**: `ExecStart` のシェルが rbenv の初期化を読み込めることを確認すること。サンプルは `/bin/bash -lc` を使用しているが、rbenv の設定が `.zshenv` 等にある場合は `/bin/zsh -c` に変更する必要がある
- **jemalloc**: RHEL サンプルには `Environment="LD_PRELOAD=/usr/lib64/libjemalloc.so"` が含まれる。Ubuntu サンプルには含まれないため、使用する場合は手動で追加すること

### FreeBSD（rc.d）: 変更なし

FreeBSD の rc.d スクリプトは 4.x から3サービス分割（`mulukhiya-puma`/`mulukhiya-sidekiq`/`mulukhiya-listener`）であり、5.0 での変更はない。

### daemon-spawn 直接管理

systemd を使わずに daemon-spawn で直接管理するための `mulukhiya-daemon.sh` を `config/sample/ubuntu/`、`config/sample/rhel/` に追加した。Docker 環境等で利用できる。
