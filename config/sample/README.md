# config/sample

設定ファイルとサービス起動スクリプトのサンプル集。

## ディレクトリ構成

### freebsd/

FreeBSD rc.d スクリプト。

| ファイル | 用途 |
|---------|------|
| `mulukhiya-puma` | Puma (Web サーバー) |
| `mulukhiya-sidekiq` | Sidekiq (ジョブワーカー) |
| `mulukhiya-listener` | Listener (WebSocket/Streaming) |

`/usr/local/etc/rc.d/` に配置し、`/etc/rc.conf` に以下を設定する。

```sh
mulukhiya_enable="YES"
mulukhiya_path="/home/mastodon/repos/mulukhiya-toot-proxy"
mulukhiya_user="mastodon"
```

**注意**: Sinatra 4.1 以降、development 環境では `HostAuthorization` により localhost 以外のホストからのアクセスがブロックされる。mulukhiya-puma の起動時に `RACK_ENV=production` を設定すること。

### ubuntu/

Ubuntu 向け systemd ユニットと 直接管理スクリプト。

| ファイル | 用途 |
|---------|------|
| `mulukhiya-puma.service` | systemd: Puma |
| `mulukhiya-sidekiq.service` | systemd: Sidekiq |
| `mulukhiya-listener.service` | systemd: Listener |
| `mulukhiya-daemon.sh` | 直接管理 (systemd 不使用時) |

systemd ユニットは `/etc/systemd/system/` に配置し、`__username__` とパスを編集する。

### rhel/

RHEL/CentOS 向け。Ubuntu 版との違いは jemalloc のパス (`/usr/lib64/libjemalloc.so`) のみ。

| ファイル | 用途 |
|---------|------|
| `mulukhiya-puma.service` | systemd: Puma |
| `mulukhiya-sidekiq.service` | systemd: Sidekiq |
| `mulukhiya-listener.service` | systemd: Listener |
| `mulukhiya-daemon.sh` | 直接管理 (systemd 不使用時) |

**注意**: RHEL 環境でのステージング検証は未実施。

### mastodon/

Mastodon インスタンス向けの設定。

| ファイル | 用途 |
|---------|------|
| `local.yaml` | mulukhiya 設定ファイル |
| `mulukhiya.nginx` | nginx server context に追加する location ブロック |
| `mulukhiya_proxy.conf` | nginx proxy パラメータ (include 用) |

`local.yaml` の配置先は `/usr/local/etc/mulukhiya-toot-proxy/local.yaml` (FreeBSD) または `/etc/mulukhiya-toot-proxy/local.yaml`。

### misskey/

Misskey インスタンス向けの設定。構成は mastodon/ と同一。
