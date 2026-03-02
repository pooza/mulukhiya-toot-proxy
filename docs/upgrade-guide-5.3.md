# 5.2.x → 5.3 アップグレードガイド

この文書は、5.2.x から 5.3 への移行手順です。

- 変更内容の詳細は[リリースノート](https://github.com/pooza/mulukhiya-toot-proxy/releases)を参照。

## 目次

1. [コードの更新](#1-コードの更新)（必須）
2. [サービスの再起動](#2-サービスの再起動)（必須）
3. [起動後の確認](#3-起動後の確認)（必須）

## 1. コードの更新

```bash
cd /path/to/mulukhiya  # モロヘイヤのインストール先
git pull
bundle install
```

## 2. サービスの再起動

> **重要: `rake restart` は使用しないこと。**
>
> `rake restart` は内部で `bin/*_daemon.rb restart` を直接呼び出す。systemd（Ubuntu/RHEL）や rc.d（FreeBSD）でサービスを管理している場合、サービスマネージャの `Restart=always` と競合し、プロセスの二重起動やゾンビ化の原因となる。
>
> **必ずサービスマネージャ経由で再起動すること。**

### Ubuntu / RHEL（systemd）

```bash
sudo systemctl restart mulukhiya-puma mulukhiya-sidekiq mulukhiya-listener
```

### FreeBSD（rc.d）

```bash
sudo service mulukhiya-puma restart
sudo service mulukhiya-sidekiq restart
sudo service mulukhiya-listener restart
```

### 起動ログについて

サービスマネージャ経由の起動では、以前 `rake start` でターミナルに表示されていた内容（スキーマチェック結果、motd 等）は表示されない。起動ログは syslog で確認する。

```bash
# FreeBSD
tail -f /var/log/messages | grep mulukhiya

# Ubuntu
journalctl -u mulukhiya-puma -u mulukhiya-sidekiq -u mulukhiya-listener -f
```

また、再起動時に ListenerDaemon の stop メッセージが複数回出力されることがあるが、これはプロセスグループへのシグナル伝播による正常な動作であり、不具合ではない。

## 3. 起動後の確認

### ヘルスチェック

```bash
curl -s http://localhost:3008/mulukhiya/api/health | python3 -m json.tool
```

すべてのステータスが `OK`、HTTP ステータスが `200` であることを確認する。

### プロセスの確認

再起動後、各デーモンが1プロセスずつ動いていることを確認する。

```bash
ps aux | grep -E 'puma_daemon|sidekiq_daemon|listener_daemon' | grep -v grep
```

### nodeinfo キャッシュの確認

5.3 では nodeinfo を Redis にキャッシュする仕組みが導入された。Sidekiq の `NodeinfoUpdateWorker` が 5 分ごとにキャッシュを更新する。追加の設定は不要。

`/mulukhiya/api/about` が正常なレスポンスを返し、`max_length` に値が入っていれば正常に動作している。

```bash
curl -s http://localhost:3008/mulukhiya/api/about | python3 -m json.tool | head -20
```
