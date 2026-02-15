# Webhook設定ガイド（admin webhook / ウェルカムDM）

新規ユーザー登録時にinfo_botからウェルカムDMを自動送信する機能です。
SNS側のadmin webhookとモロヘイヤを連携させて動作します。

## 動作フロー

```
新規ユーザーがSNSに登録
  ↓
SNS → POST /mulukhiya/webhook/admin（署名付き）
  ↓ 署名検証
  ↓ イベント判定（account.created / userCreated → :user_created）
WelcomeMentionHandler
  ↓ ボットアカウント除外
info_bot → 新規ユーザーへDM送信
```

## 前提条件

- info_botアカウントがSNS上に存在すること
- info_botのトークンがモロヘイヤに登録済みであること（トークン管理画面でOAuth認証、または `local.yaml` に直接設定）

## モロヘイヤ側の設定

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

### secretについて

- 任意の文字列を決めて設定する（十分な長さの乱数文字列を推奨）
- SNS側のwebhook登録時に同じ値を入力する
- Mastodon/Misskeyで別々の値にしてもよいが、同一サーバーでは1つのsecretを共有する

## Mastodon

### webhook登録

| 項目 | 値 |
|------|----|
| 設定場所 | Preferences > Administration > Webhooks > Add endpoint |
| Endpoint URL | `https://{ホスト}/mulukhiya/webhook/admin` |
| Events | `account.created` にチェック |
| Secret | `local.yaml` の `/agent/info/webhook/secret` と同じ値 |

### 署名検証

Mastodonは `X-Hub-Signature` ヘッダーでSHA256 HMACを送信する。
モロヘイヤはこのヘッダーを検証して、不正なリクエストを拒否する。

## Misskey

### webhook登録

| 項目 | 値 |
|------|----|
| 設定場所 | コントロールパネル > Webhook > 作成 |
| URL | `https://{ホスト}/mulukhiya/webhook/admin` |
| Secret | `local.yaml` の `/agent/info/webhook/secret` と同じ値 |
| On | `userCreated` にチェック |

### 署名検証

Misskeyは `X-Misskey-Hook-Secret` ヘッダーでsecretを平文送信する。
モロヘイヤはこのヘッダーを検証して、不正なリクエストを拒否する。

## ウェルカムメッセージ

テンプレートは `views/mention/welcome.erb` で定義:

```
{インスタンス名}へようこそ。
```

- 可視性: direct（非公開DM）
- 送信者: info_bot
- ボットアカウントで登録した場合はDMを送信しない

## トラブルシューティング

| 症状 | 原因 | 対処 |
|------|------|------|
| 503 Info agent not configured | info_botトークンが未設定 | トークン管理画面でinfo_botアカウントで認証するか、`local.yaml` に手動設定 |
| 401/403 Invalid signature/secret | secret不一致 | SNS側とモロヘイヤの `local.yaml` で同じsecretを設定しているか確認 |
| 401 Missing webhook signature | 署名ヘッダーなし | SNS側のwebhook設定でsecretが入力されているか確認 |
| 404 Unknown event | 誤ったイベント選択 | Mastodon: `account.created` / Misskey: `userCreated` を選択 |
| DMが届かない（エラーなし） | ハンドラが無効 | `streaming` 機能が有効か確認。info_botトークンの権限を確認 |
