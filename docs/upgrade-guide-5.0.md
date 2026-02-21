# mulukhiya-toot-proxy 5.0 アップグレードガイド

## local.yaml の設定パス変更

### `service:` 配下への移動

以下の外部サービス設定が、4.xではトップレベルだったものが5.0では `service:` 配下に移動した。

| 設定 | 4.x パス | 5.0 パス |
| ---- | -------- | -------- |
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

## テーマカラーの設定

5.0ではUIのヘッダー背景色がSNSインスタンスのテーマカラーに連動する。

### Mastodon

`local.yaml` に手動で設定する:

```yaml
mastodon:
  theme:
    color: '#563ACC'  # インスタンスのテーマカラーを指定
```

Mastodon本体にはテーマカラーをAPIで取得する手段がないため、管理画面の「サイトの外観」で設定している色を手動で転記する。

### Misskey

設定不要。MisskeyはメタAPI（`/api/meta`）からテーマカラーを自動取得する。フォールバックとして `local.yaml` に `/misskey/theme/color` を設定することも可能。

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
| --- | --- |
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

## 新機能: Webhook / ウェルカムDM

新規ユーザー登録時にinfo_botからウェルカムDMを自動送信する機能を追加した（#3350）。
SNS側のadmin webhookとモロヘイヤを連携させて動作する。

### 動作フロー

```text
新規ユーザーがSNSに登録
  ↓
SNS → POST /mulukhiya/webhook/admin（署名付き）
  ↓ 署名検証
  ↓ イベント判定（account.created / userCreated → :user_created）
WelcomeMentionHandler
  ↓ ボットアカウント除外
info_bot → 新規ユーザーへDM送信
```

### 前提条件

- info_botアカウントがSNS上に存在すること
- info_botのトークンがモロヘイヤに登録済みであること（トークン管理画面でOAuth認証、または `local.yaml` に直接設定）

### モロヘイヤ側の設定

`local.yaml` に以下を追加:

```yaml
agent:
  info:
    username: info    # info_botのユーザー名
    token: （暗号化済みトークン。OAuth認証で自動設定される）
    webhook:
      secret: （任意の文字列。SNS側と同じ値を設定する）
```

設定後、Pumaを再起動して反映させる。

#### secretについて

- 任意の文字列を決めて設定する（十分な長さの乱数文字列を推奨）
- SNS側のwebhook登録時に同じ値を入力する
- Mastodon/Misskeyで別々の値にしてもよいが、同一サーバーでは1つのsecretを共有する

### Mastodon での webhook 登録

| 項目 | 値 |
| ---- | -- |
| 設定場所 | Preferences > Administration > Webhooks > Add endpoint |
| Endpoint URL | `https://{ホスト}/mulukhiya/webhook/admin` |
| Events | `account.created` にチェック |
| Secret | `local.yaml` の `/agent/info/webhook/secret` と同じ値 |

Mastodonは `X-Hub-Signature` ヘッダーでSHA256 HMACを送信する。モロヘイヤはこのヘッダーを検証して、不正なリクエストを拒否する。

### Misskey での webhook 登録

| 項目 | 値 |
| ---- | -- |
| 設定場所 | コントロールパネル > Webhook > 作成 |
| URL | `https://{ホスト}/mulukhiya/webhook/admin` |
| Secret | `local.yaml` の `/agent/info/webhook/secret` と同じ値 |
| On | `userCreated` にチェック |

Misskeyは `X-Misskey-Hook-Secret` ヘッダーでsecretを平文送信する。モロヘイヤはこのヘッダーを検証して、不正なリクエストを拒否する。

### ウェルカムメッセージのカスタマイズ

テンプレートは `views/mention/welcome.erb` で定義されている。デフォルトは:

```text
{インスタンス名}へようこそ。
```

- 可視性: direct（非公開DM）
- 送信者: info_bot
- ボットアカウントで登録した場合はDMを送信しない

テンプレートを編集することで、メッセージの内容をカスタマイズできる。

### トラブルシューティング

| 症状 | 原因 | 対処 |
| ---- | ---- | ---- |
| 503 Info agent not configured | info_botトークンが未設定 | トークン管理画面でinfo_botアカウントで認証するか、`local.yaml` に手動設定 |
| 401/403 Invalid signature/secret | secret不一致 | SNS側とモロヘイヤの `local.yaml` で同じsecretを設定しているか確認 |
| 401 Missing webhook signature | 署名ヘッダーなし | SNS側のwebhook設定でsecretが入力されているか確認 |
| 404 Unknown event | 誤ったイベント選択 | Mastodon: `account.created` / Misskey: `userCreated` を選択 |
| DMが届かない（エラーなし） | ハンドラが無効 | `streaming` 機能が有効か確認。info_botトークンの権限を確認 |

## フロントエンド・CDN の変更

### CDN ホスト統一（#4069）

4.x では CDN ホストが jsDelivr, cdnjs, esm.sh の3つに分散していた。5.0 では **jsDelivr に一本化** した（Google Fonts のみ据え置き）。

| ライブラリ | 4.x CDN | 5.0 CDN |
| ---------- | ------- | ------- |
| Font Awesome | cdnjs | jsDelivr |
| @popperjs/core | esm.sh | jsDelivr |
| tippy.js | esm.sh | jsDelivr |
| その他 | jsDelivr | jsDelivr（変更なし） |

### CDN バージョン指定ポリシー

jsDelivr のアセットは **minor バージョン** で指定するルールに統一した。

```text
# 良い例（minor指定）
https://cdn.jsdelivr.net/npm/vue@3.5/dist/vue.esm-browser.js
https://cdn.jsdelivr.net/npm/axios@1.13/dist/esm/axios.js

# 避ける例
https://cdn.jsdelivr.net/npm/vue@3/...        # major のみ — 破壊的変更を受ける
https://cdn.jsdelivr.net/npm/vue@3.5.13/...   # patch 固定 — セキュリティ修正が入らない
```

バージョンを更新する際は、ステージング環境でブラウザの DevTools を確認し、コンソールエラーがないことを検証すること。

### SweetAlert2 の importmap 移行

4.x では SweetAlert2 をグローバルスクリプト（`<script>` タグ）で読み込んでいた。5.0 では ESM ビルドを importmap 経由で読み込むように変更した。

各ビューの `<script type="module">` ブロック内で `import Swal from 'sweetalert2'` としてインポートする。

### clipboard.js の廃止

clipboard.js（グローバルスクリプト）を廃止し、ブラウザネイティブの `navigator.clipboard` API に置き換えた。Vue の `methods` 内で `navigator.clipboard.writeText()` を使用する。

### Pico CSS の導入（#4068）

CSS フレームワークとして [Pico CSS](https://picocss.com/) v2 を導入した。class-less フレームワークのため、既存の HTML 構造との互換性が高い。

`default.sass` は Pico CSS の後に読み込まれ、プロジェクト固有のスタイル（テーマカラー、背景画像、独自レイアウト等）のみをオーバーライドとして保持する。Pico CSS の custom properties は `--pico-*` プレフィックスで上書き可能。

### local.yaml への影響

フロントエンドの変更による `local.yaml` の修正は不要。CDN URL やスタイルシートの設定は `config/application.yaml` で管理されており、`local.yaml` でオーバーライドしない限り自動的に新しい設定が使用される。

## 廃止予定

### `/crypt/salt`（5.x で廃止予定）

`/crypt/salt` 設定は現在 webhook 署名検証でのみ参照されている（`Crypt.password` へのフォールバックあり）。5.x で廃止予定のため、新規設定では使用しないこと。既存の設定は当面そのままで問題ない。
