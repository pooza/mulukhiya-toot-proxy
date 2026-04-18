# capsicum プロジェクトからの依頼事項

## 概要

[capsicum](https://github.com/pooza/capsicum) は Flutter ベースの Mastodon / Misskey クライアント。
汎用クライアントとして動作しつつ、モロヘイヤ導入済みサーバーでは拡張機能が利用可能になる設計。
Google Play / App Store で配布予定。

本ドキュメントは、capsicum の開発に必要なモロヘイヤ側の対応事項をまとめたもの。

## 1. API ドキュメントの整備

capsicum がモロヘイヤ固有のエンドポイントを利用するため、以下の情報が必要。

### 1.1 必要な情報

エンドポイントごとに以下を文書化する:

- パス・HTTP メソッド
- 認証要否と認証方式（Bearer トークン / `:i` パラメータ / 管理者権限）
- リクエストパラメータ（型・必須/任意）
- レスポンス形式（JSON スキーマまたは具体例）
- 機能フラグによる有効/無効条件（`/capabilities`、`/features` 等）
- エラーレスポンスの形式

### 1.2 優先度の高いエンドポイント

capsicum が初期段階で必要とするもの:

| 優先度 | エンドポイント | 用途 |
|--------|---------------|------|
| P1 | `GET /api/v1/mulukhiya/diag` | モロヘイヤ検出・トークン診断 |
| P1 | `GET /api/mulukhiya/diag` | 同上（Misskey 側） |
| P1 | `GET /mulukhiya/api/about` | サーバー情報取得 |
| P1 | `GET /mulukhiya/api/health` | ヘルスチェック |
| P2 | `GET /mulukhiya/api/config` | ユーザー設定取得 |
| P2 | `POST /mulukhiya/api/config/update` | ユーザー設定変更 |
| P2 | `GET /mulukhiya/api/admin/handler/list` | ハンドラー一覧取得 |
| P2 | `POST /mulukhiya/api/status/tags` | タグ付け（投稿へのタグ追加） |
| P3 | `GET /mulukhiya/api/tagging/favorites` | お気に入りタグ取得 |
| P3 | `GET /mulukhiya/api/feed/list` | フィード一覧取得 |
| P3 | `GET /mulukhiya/api/status/list` | 投稿一覧取得 |
| P3 | `GET /mulukhiya/api/media` | メディアカタログ取得 |
| P4 | `GET /mulukhiya/api/program` | 番組情報取得 |
| P4 | `POST /mulukhiya/api/status/tags` | タグ付け |
| P4 | `DELETE /mulukhiya/api/status/nowplaying` | NowPlaying 削除 |
| P4 | Webhook 関連 | Slack 互換 Webhook |

### 1.3 形式

当面は `docs/api.md`（マークダウン）で十分。
将来的に OpenAPI (Swagger) への移行も検討可能だが、初期段階では保守コストを避ける。

## 2. モロヘイヤ検出プロトコルの明文化

capsicum は任意の Mastodon / Misskey サーバーに接続するため、モロヘイヤの有無を自動検出する必要がある。

確認したいこと:

- `/api/v1/mulukhiya/diag`（Mastodon）/ `/api/mulukhiya/diag`（Misskey）へのリクエストで検出可能か
- 認証なしでも検出できるエンドポイントはあるか（`/mulukhiya/api/about` or `/mulukhiya/api/health`）
- レスポンスにバージョン情報や対応機能一覧は含まれるか
- 検出に推奨される手順があれば明記してほしい

## 3. プロキシ経由の投稿時の挙動

モロヘイヤはプロキシとして動作するため、capsicum から標準 API（`POST /api/v1/statuses` 等）を叩いた場合:

- nginx の設定によりモロヘイヤを経由するかどうかが決まる
- `X-Mulukhiya` ヘッダーの役割と、クライアントが意識すべき点
- パイプライン処理（URL 展開、自動タグ付け、メディア変換等）は透過的に適用されるか
- クライアント側で制御可能な項目はあるか（特定のハンドラーの無効化等）

上記を文書化してほしい。

## 4. クロスリファレンスの運用

両プロジェクト間で Issue を相互参照する:

- capsicum → モロヘイヤ: `pooza/mulukhiya-toot-proxy#XXXX`
- モロヘイヤ → capsicum: `pooza/capsicum#XXXX`

モロヘイヤ側の `docs/CLAUDE.md` の「関連リポジトリ」セクションに capsicum を追加してほしい。

## 5. 管理者ロール情報の提供 API

### 背景

Mastodon の公開 API では、ユーザーのロールに `permissions` フィールドが含まれない（セキュリティ上の制約）。そのため、クライアントアプリから他ユーザーが管理者かどうかを判定する手段がない。

capsicum では管理者ロールに `:sabacan:` カスタム絵文字を表示する機能を実装したが、現状は `verify_credentials`（ログインユーザー自身のロール）から管理者ロール ID を学習する方式のため、ログインユーザーが管理者でない場合は判定できない。

モロヘイヤは DB に直接アクセスできるため、`user_roles` テーブルの `permissions` を参照して管理者ロール ID を返す API を提供してほしい。

### 実装方針

専用エンドポイントは設けず、既存の `GET /mulukhiya/api/about` レスポンスに `admin_role_ids` フィールドを追加する。capsicum はモロヘイヤ検出時に既にこのエンドポイントを呼んでいるため、追加リクエストが不要。

- 認証: 不要（`/about` は認証なしで利用可能）
- レスポンス例（`config` 内に追加）:

```json
{
  "config": {
    "admin_role_ids": ["3"],
    ...
  }
}
```

- DB 未接続時（Misskey 等）やエラー時は空配列 `[]` を返す
- Misskey は `isAdministrator` フィールドがあるため不要だが、空配列が返るだけなので capsicum 側で分岐不要

### 実装詳細

- `Config#about` の `config:` ハッシュに `admin_role_ids` を追加
- `Config#admin_role_ids`（private）: `Mastodon::Role` の `user_roles` テーブルから `permissions` ビット 0（管理者）が立っているロール ID を文字列配列で返す
- ガード: `Environment.dbms_class&.config?` で DB 未接続を判定、rescue で例外も空配列にフォールバック

### capsicum 側の利用方法

1. モロヘイヤ検出時に管理者ロール ID を取得・キャッシュ
2. ユーザーのロール表示時にロール ID を照合して `isAdmin` を判定
3. モロヘイヤ未導入サーバーでは `verify_credentials` フォールバック（現行方式）

### 関連

- `pooza/capsicum#159`

## 6. ユーザー向けハンドラー設定 API

### 背景

モロヘイヤには「ユーザー判断で利用しないハンドラーを選ぶ」機能が計画されている。管理者向けの `GET /admin/handler/list` と `POST /admin/handler/config` は実装済みだが、一般ユーザーがハンドラーを一覧・切替する API が不足している。

capsicum ではハンドラー設定画面（トグルスイッチのリスト）を実装予定。そのために以下の API が必要。

### 6.1 ユーザー向けハンドラー一覧エンドポイント（新規）

```
GET /mulukhiya/api/handler/list
```

- **認証**: ユーザートークン（Bearer）
- **目的**: ログインユーザーに関連するハンドラーの一覧と、ユーザーレベルの有効/無効状態を返す

**レスポンスに必要なフィールド**:

```json
[
  {
    "name": "default_tag",
    "label": "デフォルトタグ",
    "description": "投稿にデフォルトのハッシュタグを付与します",
    "toggleable": true,
    "disabled": false
  },
  {
    "name": "itunes_music_nowplaying",
    "label": "iTunes NowPlaying",
    "description": "Apple Music / iTunes の楽曲リンクから NowPlaying 情報を生成します",
    "toggleable": true,
    "disabled": true
  },
  {
    "name": "dictionary_tag",
    "label": "辞書タグ",
    "description": "辞書に登録された単語に基づいてタグを付与します",
    "toggleable": false,
    "disabled": false
  }
]
```

| フィールド | 型 | 説明 |
|-----------|------|------|
| `name` | string | ハンドラー識別子（既存の underscore 名） |
| `label` | string | **新規**。UI 表示用の短い名前 |
| `description` | string | **新規**。ハンドラーが何をするかの説明文 |
| `toggleable` | boolean | ユーザーが切替可能か |
| `disabled` | boolean | 現在のユーザー設定での無効状態 |

- グローバルに無効化されたハンドラーは一覧に含めない（ユーザーには見せない）
- `toggleable: false` のハンドラーも一覧に含める（capsicum 側でスイッチを無効化して表示する）

### 6.2 ユーザー向けハンドラートグルエンドポイント（新規）

admin の `POST /admin/handler/config` と対称的な専用エンドポイントを新設する。

```http
POST /mulukhiya/api/handler/config
Content-Type: application/json
Authorization: Bearer <user_token>

{
  "handler": "default_tag",
  "disable": true
}
```

- `UserConfig` に `/handler/{name}/disable` を保存（既存の仕組みを利用）
- `toggleable: false` のハンドラーに対してはエラーを返す

### 6.3 モロヘイヤ側で必要な作業

1. 各ハンドラーに `label`（表示名）と `description`（説明文）のメタデータを追加 → #4194
2. `GET /mulukhiya/api/handler/list`（ユーザー認証）エンドポイントの新設 → #4195
3. `POST /mulukhiya/api/handler/config`（ユーザー認証）エンドポイントの新設 → #4196
4. WebUI: ユーザー向けハンドラートグル画面（config.slim に統合） → #4197

### 6.4 capsicum 側の実装予定

1. `MulukhiyaService` に `getHandlerList()` / `updateHandlerDisable()` メソッドを追加
2. ハンドラー設定画面の UI を実装（トグルスイッチリスト）
3. モロヘイヤ連携セクション（サーバー情報画面等）に導線を配置

### 関連

- capsicum 側: `pooza/capsicum#188`（サーバー情報画面の新設）で導線を確保予定
- モロヘイヤ側: #4194, #4195, #4196, #4197

## 7. リモートユーザーの isCat 判定 API

### 背景

Misskey の `isCat` フラグは ActivityPub actor に含まれるが、Mastodon API には存在しない。capsicum は Mastodon サーバーにログインしている場合でも、リモート Misskey ユーザーの猫耳を表示したい。

モロヘイヤは既に `POST /mulukhiya/api/account/is_cat` を実装済み。本セクションは capsicum が期待する仕様を明文化するもの。

### エンドポイント

```
POST /mulukhiya/api/account/is_cat
```

- **認証**: 必須（Bearer トークンまたは `token` パラメータ）
- **Content-Type**: `application/json`

### リクエスト

```json
{
  "token": "<sns_access_token>",
  "accts": ["pooza@misskey.delmulin.com", "user@example.com"]
}
```

| フィールド | 型 | 必須 | 説明 |
|-----------|------|------|------|
| `token` | string | 任意 | SNS アクセストークン（Bearer ヘッダの代替） |
| `accts` | string[] | 必須 | `user@host` 形式の acct 配列（1〜50件） |

### レスポンス

```json
{
  "pooza@misskey.delmulin.com": true,
  "user@example.com": false
}
```

| 値 | 意味 |
|----|------|
| `true` | ActivityPub actor の `isCat` が `true` |
| `false` | ActivityPub actor の `isCat` が `false` または未設定 |

**注意**: capsicum は `null` を `false` として扱うが、可能な限り `true` / `false` の boolean を返すことが望ましい。actor の取得に失敗した場合は `null` を返してよいが、actor が取得できたにもかかわらず `isCat` フィールドが存在しない場合は `false` を返す。

### 処理フロー（期待）

1. acct から WebFinger で actor URI を解決
2. `Accept: application/activity+json` で actor を GET
3. actor JSON のトップレベル `isCat` フィールドを取得
4. `isCat` が `true` → `true`、`false` / 未設定 / actor 取得失敗 → `false`（取得失敗時のみ `null` 許容）
5. 結果を Redis キャッシュ（TTL 24h）

### capsicum 側の利用方法

1. タイムライン取得後、投稿者の acct をバッチで送信
2. `true` が返った acct のユーザーに猫耳を表示
3. capsicum 側でもメモリキャッシュし、同一セッション内の再問い合わせを抑制

### 現在の問題（2026-04-17 確認）

API は到達・認証成功しているが、`pooza@misskey.delmulin.com`（`isCat: true` を設定済み）に対して `null` が返る。サーバーからの `curl` で ActivityPub actor を直接取得すると `"isCat": true` が確認できるため、`fetch_actor` の結果から `isCat` を抽出する処理に問題がある可能性。

### 関連

- `pooza/capsicum#148`（isCat 対応）

## 8. 今後の API 変更時の連携

モロヘイヤ側でエンドポイントの追加・変更・廃止がある場合:

- API ドキュメント（`docs/api.md`）を更新する
- 破壊的変更がある場合は capsicum リポジトリに Issue を起票する
- 可能であればレスポンスにバージョン情報を含め、後方互換性の判断材料とする
