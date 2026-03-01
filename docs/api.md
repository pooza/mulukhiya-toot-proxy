# API リファレンス

モロヘイヤが提供する API エンドポイントのリファレンス。

capsicum 等のクライアントアプリが、モロヘイヤ固有の機能を利用する際に参照する。

## 目次

- [共通仕様](#共通仕様)
- [モロヘイヤ検出プロトコル](#モロヘイヤ検出プロトコル)
- [プロキシ経由の投稿](#プロキシ経由の投稿)
- [エンドポイント一覧](#エンドポイント一覧)
  - [P1: サーバー情報・診断](#p1-サーバー情報診断)
  - [P2: ユーザー設定・ハンドラー管理](#p2-ユーザー設定ハンドラー管理)
  - [P3: タグ・フィード・投稿・メディア](#p3-タグフィード投稿メディア)
  - [P4: NowPlaying・Webhook・番組情報](#p4-nowplayingwebhook番組情報)
  - [認証（OAuth）](#認証oauth)

## 共通仕様

### ベースパス

モロヘイヤ固有のエンドポイントは全て `/mulukhiya/api` 配下。

診断用エンドポイントのみ SNS の API パス配下に配置:
- Mastodon: `/api/v1/mulukhiya/diag`
- Misskey: `/api/mulukhiya/diag`

### レスポンス形式

全エンドポイント共通で `application/json; charset=UTF-8`。

### 認証方式

| 方式 | 対象コントローラ | 送信方法 |
|------|-----------------|----------|
| Bearer トークン | MastodonController | `Authorization: Bearer {token}` ヘッダ |
| `:i` パラメータ | MisskeyController | リクエストボディの `i` フィールド、または `Authorization` ヘッダ |
| `token` パラメータ | APIController | リクエストパラメータの `token` フィールド（暗号化トークンも可） |

### 認証レベル

| レベル | 説明 |
|--------|------|
| 不要 | 認証なしでアクセス可能 |
| オプショナル | 認証なしでもアクセス可能。認証ありの場合、追加情報が返る |
| 必須 | `sns.account` が取得できない場合 401 |
| 管理者 | `sns.account.admin?` が `true` でない場合 401 |

### エラーレスポンス

#### 認証エラー (401)

```json
{"error": "Unauthorized"}
```

#### Not Found (404)

```json
{"error": "Not Found"}
```

#### バリデーションエラー (422)

```json
{"errors": {"field_name": ["エラーメッセージ"]}}
```

#### ゲートウェイエラー (502等)

SNS 本体への転送が失敗した場合、SNS が返したステータスコードをそのまま返す。

```json
{"error": "エラーメッセージ"}
```

### 機能フラグ

一部のエンドポイントは `config/application.yaml` の capabilities / features / data 設定に依存する。
無効な機能のエンドポイントにアクセスした場合は 404 を返す。

主要なフラグ（Mastodon / Misskey 共通で `true`）:

| 設定パス | 依存するエンドポイント |
|----------|----------------------|
| `/{controller}/capabilities/repost` | `/status/tags`, `/status/nowplaying` |
| `/{controller}/data/account_timeline` | `/status/list` |
| `/{controller}/data/favorite_tags` | `/tagging/favorites` |
| `/{controller}/data/media_catalog` | `/media` |
| `/{controller}/features/feed` | `/feed/list` |
| `/{controller}/features/announcement` | `/announcement/update` |
| `/{controller}/features/annict` | `/annict/auth`, `/tagging/dic/annict/episodes` |

## モロヘイヤ検出プロトコル

capsicum のような汎用クライアントが、接続先サーバーにモロヘイヤが導入されているかを自動検出するための手順。

### 推奨手順

1. `GET https://{domain}/mulukhiya/api/about` にリクエストを送る
2. HTTP 200 + JSON レスポンスが返れば「モロヘイヤあり」と判定
3. 404、接続エラー、タイムアウト等であれば「モロヘイヤなし」と判定

### なぜ `/mulukhiya/api/about` か

- **認証不要**で常にアクセス可能
- **バージョン情報**を含むため、クライアント側で互換性判断が可能
- **コントローラ種別**（`mastodon` / `misskey`）が返るため、SNS タイプの二重検出が不要
- `/api/v1/mulukhiya/diag` はデフォルト無効（`/diag/enable: false`）のため検出には不向き
- `/nodeinfo` は標準プロトコルでありモロヘイヤ非導入サーバーでも応答するため、検出には使えない

### レスポンスの活用

```json
{
  "package": {
    "version": "5.1.0",
    "url": "https://github.com/pooza/mulukhiya-toot-proxy"
  },
  "config": {
    "controller": "mastodon"
  }
}
```

- `package.version`: セマンティックバージョニング。クライアント側で API 互換性を判断する材料
- `config.controller`: `mastodon` または `misskey`。SNS タイプに応じた API パスの切り替えに使用

### 検出後の追加確認（任意）

モロヘイヤの検出後、サービスの稼働状況を確認したい場合:

```
GET /mulukhiya/api/health
```

HTTP ステータス 200 なら全サービス正常、503 なら一部サービスに異常あり。

## プロキシ経由の投稿

### 仕組み

モロヘイヤは nginx のリバースプロキシとして動作する。
クライアントが標準の SNS API（`POST /api/v1/statuses` 等）を呼ぶと、nginx がモロヘイヤにルーティングし、ハンドラーパイプラインを通してから SNS 本体に転送する。

```
クライアント → nginx → モロヘイヤ(:3008) → [パイプライン処理] → SNS本体(:3000)
```

### X-Mulukhiya ヘッダ

ループ防止用の内部ヘッダ。**クライアントが意識する必要はない。**

- nginx は `X-Mulukhiya` ヘッダの有無でルーティング先を切り替える
  - ヘッダなし → モロヘイヤへルーティング
  - ヘッダあり → SNS 本体へ直接ルーティング
- モロヘイヤが SNS に転送する際に自動的に `X-Mulukhiya: {パッケージ名}` を付与する
- クライアントがこのヘッダを送信する必要はない

### パイプライン処理

以下の処理が**透過的に**適用される。クライアントは標準 API を呼ぶだけでよい。

#### 投稿時（pre_toot）

URL 正規化、短縮 URL 展開、NowPlaying 検出（iTunes/Spotify/YouTube）、デフォルトタグ付与、辞書タグ付与、ユーザータグ付与、CW 自動設定など。

#### メディアアップロード時（pre_upload）

画像フォーマット変換、画像リサイズ、音声フォーマット変換、動画フォーマット変換。

#### 投稿後（post_toot）

結果通知、チャンネル通知など。

### プロキシ対象のエンドポイント

#### Mastodon

| エンドポイント | メソッド | 処理内容 |
|---------------|---------|---------|
| `/api/v{version}/statuses` | POST | 投稿作成（pre_toot → SNS → post_toot） |
| `/api/v{version}/media` | POST | メディアアップロード（pre_upload → SNS → post_upload） |
| `/api/v{version}/media/{id}` | PUT | メディア更新（サムネイル変換） |
| `/api/v{version}/statuses/{id}/favourite` | POST | お気に入り（SNS → post_fav） |
| `/api/v{version}/statuses/{id}/reblog` | POST | ブースト（SNS → post_boost） |
| `/api/v{version}/statuses/{id}/bookmark` | POST | ブックマーク（SNS → post_bookmark） |

#### Misskey

| エンドポイント | メソッド | 処理内容 |
|---------------|---------|---------|
| `/api/notes/create` | POST | ノート作成（pre_toot → SNS → post_toot） |
| `/api/notes/drafts/create` | POST | 下書き作成（pre_toot → SNS → post_toot） |
| `/api/notes/drafts/update` | POST | 下書き更新（pre_draft → SNS → post_toot） |
| `/api/drive/files/create` | POST | ファイルアップロード（pre_upload → SNS → post_upload） |
| `/api/notes/favorites/create` | POST | お気に入り（SNS → post_bookmark） |
| `/api/notes/reactions/create` | POST | リアクション（SNS → post_reaction） |

### クライアント側での制御

ハンドラーの有効/無効はアカウント単位で制御可能。

- `POST /mulukhiya/api/config/update` でユーザー設定を変更
- `toggleable: true` に設定されたハンドラーはユーザーが ON/OFF 可能
- 設定パス: `/handler/{handler_name}/disable` を `true` / `false` で切り替え

## エンドポイント一覧

### P1: サーバー情報・診断

#### GET /mulukhiya/api/about

サーバー情報を取得する。モロヘイヤの検出にも使用する。

- **認証**: 不要
- **パラメータ**: なし

**レスポンス例**:

```json
{
  "package": {
    "authors": ["Author Name"],
    "description": "各種ActivityPub対応インスタンスへの投稿に対して、内容の更新等を行うプロキシ。",
    "email": ["author@example.com"],
    "license": "MIT",
    "url": "https://github.com/pooza/mulukhiya-toot-proxy",
    "version": "5.1.0"
  },
  "config": {
    "controller": "mastodon",
    "status": {"max_length": 500}
  }
}
```

#### GET /mulukhiya/api/health

サービスの稼働状況を取得する。

- **認証**: 不要
- **パラメータ**: なし
- **HTTP ステータス**: 全サービス正常なら 200、一部異常なら 503

**レスポンス例**:

```json
{
  "redis": {"status": "OK"},
  "sidekiq": {"status": "OK"},
  "streaming": {"status": "OK"},
  "postgres": {"status": "OK"},
  "status": 200
}
```

#### GET /api/v1/mulukhiya/diag (Mastodon)

#### GET /api/mulukhiya/diag (Misskey)

トークン診断。プロキシ経由でトークンが正しく伝達されているか確認する。

- **認証**: オプショナル（トークンがあれば診断情報に反映）
- **前提条件**: `/diag/enable` が `true` であること（デフォルト `false`、無効時は 404）
- **パラメータ**: なし

**レスポンス例**:

```json
{
  "token_prefix": "abcdefgh",
  "token_length": 43,
  "sns_token_prefix": "abcdefgh",
  "sns_token_length": 43,
  "match": true,
  "thread_id": 12345,
  "timestamp": "2026-01-15T12:34:56.789012+09:00"
}
```

### P2: ユーザー設定・ハンドラー管理

#### GET /mulukhiya/api/config

ユーザー設定を取得する。

- **認証**: 必須（`token` パラメータ）
- **パラメータ**: なし

**レスポンス例**:

```json
{
  "account": {
    "id": "12345",
    "username": "user",
    "display_name": "User Name",
    "acct": "user"
  },
  "config": {
    "handler": {
      "default_tag": {"disable": false},
      "dictionary_tag": {"disable": false}
    }
  },
  "webhook": {"url": "https://..."},
  "token": {"scopes": ["read", "write:statuses"]},
  "visibility_names": ["public", "unlisted", "private", "direct"]
}
```

#### POST /mulukhiya/api/config/update

ユーザー設定を変更する。ハンドラーの有効/無効切り替え等。

- **認証**: 必須（`token` パラメータ）
- **リクエストボディ**: ハンドラーコマンド形式のパラメータ

**レスポンス例**:

```json
{
  "config": {
    "handler": {
      "default_tag": {"disable": true}
    }
  }
}
```

#### GET /mulukhiya/api/admin/handler/list

全ハンドラーの一覧と有効/無効状態を取得する。

- **認証**: 管理者
- **パラメータ**: なし

**レスポンス例**:

```json
[
  {"name": "default_tag", "disable": false},
  {"name": "dictionary_tag", "disable": false},
  {"name": "url_normalize", "disable": false}
]
```

### P3: タグ・フィード・投稿・メディア

#### GET /mulukhiya/api/tagging/favorites

お気に入りタグの一覧を取得する。

- **認証**: オプショナル
- **前提条件**: `/{controller}/data/favorite_tags` が `true`（無効時は 404）
- **パラメータ**: なし

**レスポンス例**:

```json
[
  {"name": "precure", "url": "https://mstdn.example.com/tags/precure"},
  {"name": "delmulin", "url": "https://mstdn.example.com/tags/delmulin"}
]
```

#### POST /mulukhiya/api/tagging/tag/search

タグ辞書を検索する。

- **認証**: 不要
- **パラメータ**:

| 名前 | 型 | 必須 | 説明 |
|------|-----|------|------|
| `q` | string | 必須 | 検索クエリ |

**レスポンス例**:

```json
{
  "プリキュア": {
    "regexp": "...",
    "word": "プリキュア",
    "short": false,
    "words": ["プリキュア", "precure"],
    "tags": ["precure"]
  }
}
```

#### GET /mulukhiya/api/feed/list

フィード一覧（ハッシュタグの一覧）を取得する。認証ありの場合はユーザーのフォロー中タグ等も含む。

- **認証**: オプショナル（認証時はユーザー固有のタグも含む）
- **パラメータ**: なし

**レスポンス例**:

```json
[
  {"name": "precure", "url": "https://mstdn.example.com/tags/precure"},
  {"name": "delmulin", "url": "https://mstdn.example.com/tags/delmulin"}
]
```

#### GET /mulukhiya/api/status/list

投稿一覧を取得する。

- **認証**: 必須
- **前提条件**: `/{controller}/data/account_timeline` が `true`（無効時は 404）
- **パラメータ**:

| 名前 | 型 | 必須 | 説明 |
|------|-----|------|------|
| `page` | integer | 任意 | ページ番号（デフォルト: 1、1以上） |
| `q` | string | 任意 | 検索クエリ |
| `self` | integer | 任意 | 自分の投稿のみ（0: 全て / 1: 自分のみ、デフォルト: 0） |

#### GET /mulukhiya/api/status/{id}

指定した投稿の詳細を取得する。

- **認証**: 必須
- **前提条件**: 自分が編集可能な投稿であること

**レスポンス例**:

```json
{
  "id": "12345",
  "content": "投稿内容",
  "account": {
    "username": "user",
    "display_name": "User Name",
    "acct": "user"
  }
}
```

#### POST /mulukhiya/api/status/tags

投稿のタグを変更して再投稿する。

- **認証**: 必須
- **前提条件**: `/{controller}/capabilities/repost` が `true`（無効時は 404）
- **パラメータ**:

| 名前 | 型 | 必須 | 説明 |
|------|-----|------|------|
| `id` | string | 必須 | 投稿 ID |
| `tags` | string[] | 必須 | タグの配列 |

#### GET /mulukhiya/api/media

メディアカタログを取得する。

- **認証**: オプショナル（認証時は検索クエリ `q` が使用可能）
- **前提条件**: `/{controller}/data/media_catalog` が `true`（無効時は 404）
- **パラメータ**:

| 名前 | 型 | 必須 | 説明 |
|------|-----|------|------|
| `page` | integer | 任意 | ページ番号（デフォルト: 1、1以上） |
| `q` | string | 任意 | 検索クエリ（認証時のみ有効） |
| `only_person` | integer | 任意 | 人物のみ（0: 全て / 1: 人物のみ、デフォルト: 0） |

### P4: NowPlaying・Webhook・番組情報

#### DELETE /mulukhiya/api/status/nowplaying

NowPlaying 情報を除去して再投稿する。

- **認証**: 必須
- **パラメータ**:

| 名前 | 型 | 必須 | 説明 |
|------|-----|------|------|
| `id` | string | 必須 | 投稿 ID |

#### GET /mulukhiya/api/program

番組情報を取得する。

- **認証**: オプショナル
- **前提条件**: `/program/urls` が設定されていること（未設定時は 404）
- **パラメータ**: なし

#### Webhook

Webhook エンドポイントは `/mulukhiya/webhook` 配下で提供される。

| エンドポイント | メソッド | 認証 | 説明 |
|---------------|---------|------|------|
| `/mulukhiya/webhook/{digest}` | GET | Webhook 存在確認 | ヘルスチェック |
| `/mulukhiya/webhook/{digest}` | POST | Webhook 検証 | Slack 互換ペイロードを処理 |
| `/mulukhiya/webhook/admin` | POST | HMAC-SHA256 / Misskey Secret | 管理 Webhook（アカウント承認等） |

### 認証（OAuth）

#### POST /mulukhiya/api/mastodon/auth

Mastodon の OAuth 認可コードをアクセストークンに交換する。

- **認証**: 不要
- **前提条件**: コントローラが Mastodon タイプであること
- **パラメータ**:

| 名前 | 型 | 必須 | 説明 |
|------|-----|------|------|
| `code` | string | 必須 | 認可コード（空欄不可） |
| `type` | string | 任意 | 認証タイプ |

**レスポンス例**:

```json
{
  "access_token": "...",
  "access_token_crypt": "...(暗号化済みトークン)...",
  "token_type": "Bearer",
  "scope": "read write:statuses write:media"
}
```

#### POST /mulukhiya/api/misskey/auth

Misskey の認可コードをアクセストークンに交換する。

- **認証**: 不要
- **前提条件**: コントローラが Misskey タイプであること
- **パラメータ**:

| 名前 | 型 | 必須 | 説明 |
|------|-----|------|------|
| `code` | string | 必須 | 認可コード（空欄不可） |
| `type` | string | 任意 | 認証タイプ |

**レスポンス例**:

```json
{
  "accessToken": "...",
  "access_token_crypt": "...(暗号化済みトークン)...",
  "user": {"id": "...", "username": "..."}
}
```
