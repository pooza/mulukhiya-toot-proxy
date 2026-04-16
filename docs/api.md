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
  - [Annict 連携（エピソードブラウザ）](#annict-連携エピソードブラウザ)
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
| Bearer トークン / `token` パラメータ | APIController | `Authorization: Bearer {token}` ヘッダ（推奨）、またはリクエストパラメータの `token` フィールド（暗号化トークンも可。後方互換） |

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
| `/{controller}/features/annict` | `/annict/oauth_uri`, `/annict/auth`, `/tagging/dic/annict/episodes`, `/program/works`, `/program/works/:id/episodes` |

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

### X-Mulukhiya-Purpose ヘッダ

`PUT /api/v{version}/statuses/{id}` で本文更新の可否を制御するヘッダ。
SNS における「発言の責任」の観点から、本文の自由な編集はデフォルトで禁止している。

| X-Mulukhiya-Purpose | 許可されるパラメータ | 用途 |
| --- | --- | --- |
| （なし / 空） | `media_attributes` のみ | メディア説明（ALT）の編集（直接アクセス時） |
| `media_update` | `media_attributes` のみ | メディア説明（ALT）の編集（クライアントから） |
| `tag` | `status`, `media_attributes` | ハッシュタグの付け替え（モロヘイヤ内部用） |

- Purpose ヘッダなし: 直接アクセス時。`media_attributes` 以外は除去される
- Purpose が `media_update`: クライアント（capsicum 等）からの ALT 編集リクエスト。nginx が Purpose ヘッダの有無でルーティングするため、クライアントはこの値を指定する
- Purpose が `tag`: モロヘイヤ自身がハッシュタグを書き換える際に使用（将来の #3877 対応）
- 不明な Purpose: 422 Unprocessable Entity を返す

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
| `/api/v{version}/statuses/{id}` | PUT | 投稿更新（`X-Mulukhiya-Purpose` ヘッダで許可範囲を制御、下記参照） |
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

**レスポンス例**（Mastodon）:

```json
{
  "package": {
    "authors": ["Author Name"],
    "description": "各種ActivityPub対応インスタンスへの投稿に対して、内容の更新等を行うプロキシ。",
    "email": ["author@example.com"],
    "license": "MIT",
    "url": "https://github.com/pooza/mulukhiya-toot-proxy",
    "version": "5.8.0"
  },
  "config": {
    "controller": "mastodon",
    "status": {
      "label": "投稿",
      "reblog_label": "ブースト",
      "max_length": 2400,
      "spoiler": {"text": null, "emoji": null, "shortcode": null},
      "default_hashtag": "precure_fun"
    },
    "theme": {
      "color": "#6364FF"
    },
    "capabilities": {
      "repost": true,
      "streaming": true
    },
    "features": {
      "annict": true,
      "announcement": true,
      "feed": true,
      "webhook": true
    },
    "handlers": ["amazon_image", "default_tag", "itunes_music_nowplaying", "..."],
    "admin_role_ids": ["3"],
    "info_bot": {
      "username": "info",
      "acct": "info@precure.ml",
      "url": "https://precure.ml/@info",
      "display_name": "モロヘイヤからのお知らせ"
    },
    "status_url": "https://uptime.b-shock.org/status/bshockdon"
  }
}
```

**`admin_role_ids`**: 管理者権限を持つロールの ID 一覧（文字列配列）。Mastodon の `user_roles` テーブルから `permissions` ビット 0（Administrator）が立っているロールを返す。DB 未接続時（Misskey 等）は空配列。capsicum でユーザーのロール ID と照合し、管理者バッジ表示に利用する（`pooza/capsicum#159`）。

**`info_bot`**: お知らせボットのプロフィール情報。`username`、`acct`（@user@domain 形式）、`url`（プロフィールページURL）、`display_name` を含む。お知らせボットのトークンが未設定の環境では `null` を返す。capsicum のお知らせ画面でボットのプロフィールリンク表示に利用する（`pooza/capsicum#189`）。

**`status_url`**: ステータスページの URL。`config/local.yaml` の `/status_url` で設定する。未設定時は `null`。Mastodon は `/api/v2/instance` から取得可能だが、Misskey には該当 API がないため、モロヘイヤ経由で統一的に提供する（`pooza/capsicum#247`）。

#### GET /mulukhiya/api/emoji/palettes

認証済みユーザーの Misskey 絵文字パレットを取得する。

- **認証**: 必要（Bearer トークン）
- **Misskey 専用**: Mastodon 環境では 404 を返す

Misskey の `registry_item` テーブルから Web UI が保存したパレットデータを直接取得する。Misskey API の `i/registry/get` はドメイン分離の制約があるため、DB 経由で提供する。

**レスポンス例:**

```json
{
  "palettes": [
    {
      "id": "xxx",
      "name": "よく使う",
      "emojis": [":emoji1:", ":emoji2:", "👍", "❤️"]
    }
  ],
  "palette_for_reaction": "xxx",
  "palette_for_main": "yyy"
}
```

**`palettes`**: パレット定義の配列。各要素は `id`（パレットID）、`name`（表示名）、`emojis`（絵文字ショートコードまたは Unicode 絵文字の配列）を含む。パレットが未作成の場合は空配列。

**`palette_for_reaction`**: リアクション用に設定されたパレットの ID。未設定時は `null`。

**`palette_for_main`**: メイン用に設定されたパレットの ID。未設定時は `null`。

関連: `pooza/capsicum#253`

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

#### POST /mulukhiya/api/account/is_cat

指定したアカウントが猫（isCat）かどうかを問い合わせる。リモートサーバーの ActivityPub actor を取得し、`isCat` フィールドを返す。

- **認証**: 必須
- **パラメータ**:

| 名前    | 型       | 必須 | 説明 |
|---------|----------|------|------|
| `accts` | string[] | 必須 | `user@host` 形式のアカウント識別子の配列（1〜50件） |

**リクエスト例**:

```json
{
  "token": "...",
  "accts": ["pooza@misskey.delmulin.com", "user@mastodon.example.com"]
}
```

**レスポンス例**:

```json
{
  "pooza@misskey.delmulin.com": true,
  "user@mastodon.example.com": null
}
```

| 値 | 意味 |
|---------|------|
| `true`  | isCat が有効 |
| `false` | isCat が無効（明示的に `false`） |
| `null`  | actor の取得に失敗、または isCat フィールドが存在しない |

**備考**:

- 結果は Redis にキャッシュされる（TTL 24時間）。actor 取得失敗時はキャッシュしない
- リモートサーバーへの WebFinger + actor GET を行うため、初回問い合わせはレスポンスが遅延する場合がある
- 複数 acct は並列に問い合わせる
- 関連: `pooza/capsicum#148`

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

#### GET /mulukhiya/api/admin/config/audit

`config/local.yaml` の設定監査を実行する。JSON Schema バリデーションエラーと、スキーマに定義されていない不明なキーを検出する。

- **認証**: 管理者
- **パラメータ**: なし

**レスポンス例:**

```json
{
  "errors": [],
  "unknown_keys": ["service.legacy_option", "handler.old_handler.param"]
}
```

**`errors`**: JSON Schema バリデーションエラーの配列。正常な設定では空配列。

**`unknown_keys`**: スキーマに定義されていないキーのドット区切りパス。移行済みの旧設定や、廃止されたハンドラーのパラメータが残っている場合に検出される。不要であれば `local.yaml` から削除を検討する。

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
| `page` | integer | 任意 | ページ番号（デフォルト: 1、1以上。`cursor` 指定時は無視される） |
| `cursor` | string | 任意 | カーソル（前回レスポンスの `next_cursor` を指定） |
| `q` | string | 任意 | 検索クエリ（認証時のみ有効） |
| `only_person` | integer | 任意 | 人物のみ（0: 全て / 1: 人物のみ、デフォルト: 0） |

- **レスポンス**:

| フィールド | 型 | 説明 |
|-----------|-----|------|
| `items` | array | メディアオブジェクトの配列 |
| `page` | integer | 現在のページ番号 |
| `has_next` | boolean | 次のページが存在するか |
| `next_cursor` | string | 次ページのカーソル（`has_next` が `true` の場合のみ） |

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

#### GET /mulukhiya/api/program/works

Annict 作品をキーワード検索する。

- **認証**: オプショナル（ユーザーの Annict トークンがあれば使用、なければお知らせボットの Annict トークンにフォールバック。いずれもない場合 401）
- **前提条件**: `/{controller}/features/annict` が `true` かつ Annict OAuth が設定済みであること
- **パラメータ**:

| 名前 | 型 | 必須 | 説明 |
|------|-----|------|------|
| `q` | string | 任意 | 検索キーワード（スペース区切りで複数指定可）。省略時は `config/application.yaml` の `/annict/works` に設定済みのキーワードで検索 |

**レスポンス例**:

```json
[
  {
    "annictId": 9569,
    "title": "わんだふるぷりきゅあ！",
    "seasonYear": 2024,
    "officialSiteUrl": "https://www.toei-anim.co.jp/tv/precure/",
    "hashtag": "わんだふるぷりきゅあ",
    "hashtag_url": "https://mstdn.example.com/tags/わんだふるぷりきゅあ",
    "command_toot": "/np わんだふるぷりきゅあ！"
  }
]
```

| フィールド | 型 | 説明 |
|-----------|-----|------|
| `annictId` | integer | Annict 作品 ID |
| `title` | string | 作品タイトル |
| `seasonYear` | integer | 放送年 |
| `officialSiteUrl` | string \| null | 公式サイト URL |
| `hashtag` | string | 作品タイトルから生成されたハッシュタグ |
| `hashtag_url` | string | SNS 上のハッシュタグ URL |
| `command_toot` | string | NowPlaying 投稿用コマンド文字列 |
| `viewerStatusState` | string | 視聴ステータス（ユーザーの Annict トークン使用時のみ） |

#### GET /mulukhiya/api/program/works/:id/episodes

指定した作品のエピソード一覧を取得する。

- **認証**: 不要（お知らせボットの Annict トークンを使用。未設定の場合 401）
- **前提条件**: `/{controller}/features/annict` が `true` かつ Annict OAuth が設定済みであること
- **注意**: capsicum 等のクライアントからはモロヘイヤの Bearer トークン認証不要。Annict の別トークンも不要（サーバー側のお知らせボットが Annict API にアクセスする）

**パラメータ**:

| 名前 | 型 | 必須 | 説明 |
|------|-----|------|------|
| `:id` | integer | 必須 | Annict 作品 ID（URL パス） |

**レスポンス例**:

```json
[
  {
    "annictId": 291706,
    "numberText": "第1話",
    "title": "こむぎとまゆ",
    "hashtag": "こむぎとまゆ",
    "hashtag_uri": "https://mstdn.example.com/tags/こむぎとまゆ",
    "url": "https://annict.com/works/9569/episodes/291706",
    "hashtag_url": "https://mstdn.example.com/tags/こむぎとまゆ",
    "command_toot": "/np わんだふるぷりきゅあ！ 第1話「こむぎとまゆ」"
  }
]
```

| フィールド | 型 | 説明 |
|-----------|-----|------|
| `annictId` | integer | Annict エピソード ID |
| `numberText` | string | 話数テキスト（「第1話」等） |
| `title` | string | サブタイトル |
| `hashtag` | string | サブタイトルから生成されたハッシュタグ |
| `hashtag_uri` | string | SNS 上のハッシュタグ URI（内部表現） |
| `url` | string | Annict 上のエピソードページ URL |
| `hashtag_url` | string | SNS 上のハッシュタグ URL |
| `command_toot` | string | NowPlaying 投稿用コマンド文字列（タイトル・話数・サブタイトル含む） |

#### Webhook

Webhook エンドポイントは `/mulukhiya/webhook` 配下で提供される。

| エンドポイント | メソッド | 認証 | 説明 |
|---------------|---------|------|------|
| `/mulukhiya/webhook/{digest}` | GET | Webhook 存在確認 | ヘルスチェック |
| `/mulukhiya/webhook/{digest}` | POST | Webhook 検証 | Slack 互換ペイロードを処理 |
| `/mulukhiya/webhook/admin` | POST | HMAC-SHA256 / Misskey Secret | 管理 Webhook（アカウント承認等） |

### Annict 連携（エピソードブラウザ）

Annict（アニメ視聴記録サービス）と連携し、作品・エピソードの検索やタグ付けを行う。

capsicum のエピソードブラウザが利用する。

#### 前提条件

- `/{controller}/features/annict` が `true` であること（`GET /about` の `config.features.annict` で確認可能）
- `AnnictService.config?` が `true`（`/service/annict/oauth/client/id` と `/service/annict/oauth/client/secret` が設定済み）
- 作品検索（`GET /program/works`）はユーザーの Annict トークンがなくてもお知らせボットのトークンで動作する。エピソード取得（`GET /program/works/:id/episodes`、`GET /tagging/dic/annict/episodes`）はお知らせボットのトークンのみ使用する。ユーザーの Annict OAuth が必要なのは `POST /annict/auth`（トークン取得）と、`GET /program/works` で視聴ステータスを取得する場合のみ

#### 認証フロー

1. クライアントが `GET /mulukhiya/api/annict/oauth_uri` で認可 URL を取得する
2. 取得した URL をブラウザで開く
3. ユーザーが Annict 上で認可すると、認可コードが画面に表示される（OOB 方式）
4. クライアントが `POST /mulukhiya/api/annict/auth` に認可コードを送信
4. モロヘイヤがコードをアクセストークンに交換し、ユーザー設定に保存
5. 以降の Annict 関連エンドポイントは保存済みトークンを使用

#### GET /mulukhiya/api/annict/oauth_uri

Annict の OAuth 認可 URL を取得する。クライアントはこの URL をブラウザで開き、ユーザーに認可を求める。

- **認証**: 不要
- **前提条件**: `/{controller}/features/annict` が `true`
- **パラメータ**: なし

**レスポンス例**:

```json
{
  "oauth_uri": "https://annict.com/oauth/authorize?client_id=...&response_type=code&redirect_uri=urn:ietf:wg:oauth:2.0:oob&scope=read"
}
```

#### POST /mulukhiya/api/annict/auth

Annict の OAuth 認可コードをアクセストークンに交換し、ユーザー設定に保存する。

- **認証**: 必須（SNS アカウントのトークン）
- **前提条件**: `/{controller}/features/annict` が `true`
- **パラメータ**:

| 名前 | 型 | 必須 | 説明 |
|------|-----|------|------|
| `token` | string | 必須 | SNS アカウントのアクセストークン |
| `code` | string | 必須 | Annict OAuth 認可コード |

**レスポンス例**:

```json
{
  "status": 200,
  "message": {
    "config": {
      "service": {
        "annict": {
          "token": "..."
        }
      }
    }
  }
}
```

#### GET /mulukhiya/api/program/works

Annict の作品をキーワード検索する。パラメータ・レスポンスの詳細は上記 P4 セクションを参照。

- **認証**: オプショナル（ユーザーの Annict トークンがあれば使用、なければお知らせボットの Annict トークンにフォールバック。いずれもない場合 401）
- **前提条件**: `/{controller}/features/annict` が `true` かつ Annict OAuth が設定済みであること

#### GET /mulukhiya/api/program/works/:id/episodes

指定した作品のエピソード一覧を取得する。パラメータ・レスポンスの詳細は上記 P4 セクションを参照。

- **認証**: 不要（お知らせボットの Annict トークンを使用。未設定の場合 401）
- **前提条件**: `/{controller}/features/annict` が `true` かつ Annict OAuth が設定済みであること

#### GET /mulukhiya/api/tagging/dic/annict/episodes

お知らせボットが視聴中の全作品のエピソードを辞書形式で取得する。タグ付け補完に使用する。

- **認証**: 不要（お知らせボットの Annict トークンを使用。未設定の場合 401）
- **前提条件**: `/{controller}/features/annict` が `true`
- **パラメータ**: なし

**レスポンス例**:

```json
{
  "みんなの絆！わんだふる〜！": ["24話"],
  "ふたりのプリキュア": ["23話"],
  "ひろがるスカイ！プリキュア 最終話": []
}
```

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
