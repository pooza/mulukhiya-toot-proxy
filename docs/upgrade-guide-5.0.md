# mulukhiya-toot-proxy 5.0 アップグレードガイド

この文書は、 4.x から 5.0 への移行手順です。

- 変更内容の詳細は[リリースノート](https://github.com/pooza/mulukhiya-toot-proxy/releases)を参照。

## 目次

1. [ブランチの切り替え](#1-ブランチの切り替え)（必須）
2. [Ruby の更新](#2-ruby-の更新)（必須）
3. [local.yaml の修正](#3-localyaml-の修正)（該当する設定がある場合）
4. [起動スクリプトの移行](#4-起動スクリプトの移行)（Ubuntu/RHEL のみ）
5. [テーマカラーの設定](#5-テーマカラーの設定)（推奨）
6. [Sidekiq ダッシュボードのアクセス制限](#6-sidekiq-ダッシュボードのアクセス制限)（推奨）
7. [ウェルカム DM の設定](#7-ウェルカム-dm-の設定)（任意・新機能）

## 1. ブランチの切り替え

5.0 リリースに伴い、ブランチ名が変更された。

| 旧ブランチ | 新ブランチ | 用途 |
| --- | --- | --- |
| `develop` | `main` | 5.x（デフォルト） |
| `master` | `v4` | 4.x メンテナンス |

```bash
cd /path/to/mulukhiya # モロヘイヤのインストール先
git branch -m develop main
git fetch origin
git branch -u origin/main main
git pull
bundle install
```

以降は従来通り、 `git pull && bundle install` で更新できる。

## 2. Ruby の更新

5.0 は Ruby 4.0.1 以上が必要。

```bash
# rbenv の場合
cd /path/to/mulukhiya # モロヘイヤのインストール先
rbenv install
ruby -v  # ruby 4.0.1 以上であること

bundle install
```

## 3. config/local.yaml の修正

以下の外部サービス設定を使っている場合、`/service` 配下に移動する。**使っていない設定は対応不要。**

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

# 5.0（新）— /service の下に移動する
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

移動が必要な設定の一覧:

| 設定 | 4.x パス | 5.0 パス |
| ---- | -------- | -------- |
| Annict | `/annict/...` | `/service/annict/...` |
| Spotify | `/spotify/...` | `/service/spotify/...` |
| Amazon | `/amazon/...` | `/service/amazon/...` |
| iTunes | `/itunes/...` | `/service/itunes/...` |
| LINE | `/line/...` | `/service/line/...` |
| PeerTube | `/peer_tube/...` | `/service/peer_tube/...` |
| PieFed | `/piefed/...` | `/service/piefed/...` |
| Poipiku | `/poipiku/...` | `/service/poipiku/...` |

移動しないもの: `/google`, `/handler`, `/crypt`, `/agent` はトップレベルのまま。

## 4. 起動スクリプトの移行

### Ubuntu / RHEL（systemd）

4.x のサービス（`mulukhiya-toot-proxy.service`）は、3つのサービスに分割された。サンプルを参考に、起動スクリプトを更新する。

| 新サービス | 役割 |
| --- | --- |
| `mulukhiya-puma.service` | Web サーバー（本体） |
| `mulukhiya-sidekiq.service` | Sidekiq ジョブワーカー |
| `mulukhiya-listener.service` | WebSocket/Streaming リスナー |

```bash
# 旧サービスの停止・無効化
sudo systemctl stop mulukhiya-toot-proxy
sudo systemctl disable mulukhiya-toot-proxy
sudo rm /etc/systemd/system/mulukhiya-toot-proxy.service

# 新サービスの配置（Ubuntu の例。RHEL は config/sample/rhel/ を使用）
sudo cp config/sample/ubuntu/mulukhiya-{puma,sidekiq,listener}.service /etc/systemd/system/

# 各ファイル内の __username__ とパスを自分の環境に合わせて編集
sudo vi /etc/systemd/system/mulukhiya-puma.service
sudo vi /etc/systemd/system/mulukhiya-sidekiq.service
sudo vi /etc/systemd/system/mulukhiya-listener.service

# 有効化・起動
sudo systemctl daemon-reload
sudo systemctl enable mulukhiya-puma mulukhiya-sidekiq mulukhiya-listener
sudo systemctl start mulukhiya-puma mulukhiya-sidekiq mulukhiya-listener
```

- rbenv を使っている場合: サンプルの `ExecStart` は `/bin/bash -lc` でシェルを起動する。
  - rbenv の初期化が `.bashrc` または `.bash_profile` に書かれていることを確認する
- jemalloc の `LD_PRELOAD` 設定が Ubuntu / RHEL サンプル両方に含まれている。
  - jemalloc がインストールされていない場合は `apt install libjemalloc2`（Ubuntu）/ `dnf install jemalloc`（RHEL）で導入する

### FreeBSD

サンプルスクリプトに変更なし。4.x から3サービス分割済み。

### daemon-spawn（systemd 不使用時）

Docker などでの便宜を想定した起動スクリプトを提供している。
[config/sample/ubuntu/mulukhiya-daemon.sh](../config/sample/ubuntu/mulukhiya-daemon.sh)（または [config/sample/rhel/mulukhiya-daemon.sh](../config/sample/rhel/mulukhiya-daemon.sh)）を参照。

## 5. テーマカラーの設定

WebUI のヘッダー背景色に、サーバーのテーマカラーが反映されるようになった。

### Mastodon

`config/local.yaml` に手動で設定する:

```yaml
mastodon:
  theme:
    color: '#563ACC'  # 管理画面「サイトの外観」のテーマカラーを転記
```

### Misskey

設定不要。メタ API から自動取得される。

## 6. Sidekiq ダッシュボードのアクセス制限

Sidekiq ダッシュボード（`/mulukhiya/sidekiq`）は認証なしで誰でも閲覧できる。**IP アドレス制限または BASIC 認証（あるいは両方）を必ず設定すること。**

### 方法 A: nginx で IP アドレス制限（固定 IP アドレスがある場合・推奨）

nginx の server context に以下を追加する（既存の `location ^~ /mulukhiya` より前に配置）:

```nginx
location ^~ /mulukhiya/sidekiq {
  allow YOUR_IP_OR_CIDR;
  deny all;
  include /path/to/mulukhiya_proxy.conf;
  proxy_pass http://localhost:3008;
}
```

- `YOUR_IP_OR_CIDR` を管理者の IP アドレス（または CIDR ）に書き換える。`allow` 行は複数記述できる
- サンプル: [config/sample/mastodon/mulukhiya.nginx](config/sample/mastodon/mulukhiya.nginx), [config/sample/misskey/mulukhiya.nginx](config/sample/misskey/mulukhiya.nginx)

### 方法 B: BASIC 認証（固定 IP アドレスがない場合）

`config/local.yaml` に以下を追加する:

```yaml
sidekiq:
  auth:
    password: your_password  # 任意の文字列
```

- ユーザー名のデフォルトは `admin`。変更したい場合は `/sidekiq/auth/user` も設定する
- パスワードは [crypt.rb](https://github.com/pooza/mulukhiya-toot-proxy/wiki/コマンドラインツール#cryptrb) で暗号化された値を推奨。
- 設定後、Puma を再起動する

## 7. ウェルカム DM の設定

新規ユーザー登録時にお知らせボットからウェルカム DM を自動送信する機能。SNS 側の webhook と連携して動作する。

### 前提

- お知らせボットのアカウントが SNS 上に存在すること
  - [お知らせボット]([/pooza/mulukhiya-toot-proxy/wiki/エージェントボット](https://github.com/pooza/mulukhiya-toot-proxy/wiki/エージェントボット)#お知らせボット)
- お知らせボットのトークンがモロヘイヤに登録済みであること（トークン管理画面で OAuth 認証）

### Mastodon の場合

Mastodon は webhook 登録時にサーバーが secret を自動生成する。そのため、先に Mastodon 側で webhook を登録し、生成された secret を `config/local.yaml` に書き込む。

#### 手順 1: Mastodon で webhook を登録

| 項目 | 値 |
| ---- | -- |
| 設定場所 | Preferences > Administration > Webhooks > Add endpoint |
| Endpoint URL | `https://{ホスト}/mulukhiya/webhook/admin` |
| Events | `account.created` にチェック |

登録後、webhook の詳細画面に表示される **Signing secret** の値を控える。

#### 手順 2: config/local.yaml に webhook 設定を追加

```yaml
agent:
  info:
    username: info    # お知らせボットのユーザー名
    webhook:
      secret: （手順 1 で控えた Signing secret の値）
```

設定後、Puma を再起動する。

### Misskey の場合

Misskey は secret を自分で決めて、双方に同じ値を設定する。

#### 手順 1: config/local.yaml に webhook 設定を追加

```yaml
agent:
  info:
    username: info    # お知らせボットのユーザー名
    webhook:
      secret: （任意の文字列。十分な長さの乱数を推奨）
```

設定後、Puma を再起動する。

#### 手順 2: Misskey で webhook を登録

| 項目 | 値 |
| ---- | -- |
| 設定場所 | コントロールパネル > Webhook > 作成 |
| URL | `https://{ホスト}/mulukhiya/webhook/admin` |
| Secret | 手順 1 で設定した値と同じ文字列 |
| On | `userCreated` にチェック |

### ウェルカムメッセージのカスタマイズ

テンプレートは [views/mention/welcome.erb](views/mention/welcome.erb) にある。
これを編集するか、または新しいテンプレートファイルを指定する（以下）ことでメッセージの内容を変更できる。
新規登録したばかりのメンバーに、特に念を押したい注意事項をテンプレートに書き込む。

#### ウェルカムメッセージの更新

```haml
agent:
  info:
    welcome:
      template: welcome_delmulin # views/mention/welcome_delmulin.erb をウェルカムメッセージとして使用する場合。
```

### うまく動かない場合

| 症状 | 対処 |
| ---- | ---- |
| 503 Info agent not configured | トークン管理画面で お知らせボットのアカウントの OAuth 認証を行う |
| 401/403 Invalid signature/secret | SNS 側と `config/local.yaml` の secret が一致しているか確認する |
| 401 Missing webhook signature | SNS 側の webhook 設定で secret が入力されているか確認する |
| 404 Unknown event | Mastodon: `account.created` / Misskey: `userCreated` が選択されているか確認する |
| DM が届かない（エラーなし） | お知らせボットのトークンの権限を確認する |
