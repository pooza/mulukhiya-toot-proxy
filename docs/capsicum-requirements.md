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

## 8. ナウプレ enrich プロキシ（メタデータ → 共有可能 URL）

> **#4382 の再定義（2026-06-05）**: 当初 #4382 は「文字情報 → 整形済みナウプレテキストを返す**整形器**」として要件を出していたが、**整形はクライアント（capsicum）側で行う方針に確定**した。本節がその新しい要件であり、#4382 の「テキスト整形器」案は破棄する。設計の全体像は capsicum [docs/nowplaying-design.md](https://github.com/pooza/capsicum/blob/develop/docs/nowplaying-design.md) §責務分担 を参照。

### 背景・責務分担

capsicum が OS から構造化メタデータ（title / artist / album）を pull できるようになった（Linux MPRIS / Windows SMTC / Apple Music）。これにより:

- **整形（`#nowplaying` タグ・Title/Album/Artist のレイアウト・行構成）はクライアント側**で行う。構造化データを持つ側が組むのが筋で、サーバー側整形はクライアントと干渉する（サーバーの `#nowplaying` 行正規化がクライアント整形を壊し、capsicum 側でタグを末尾へ逃がす回避が必要になった = [capsicum#466](https://github.com/pooza/capsicum/issues/466)）。
- **モロヘイヤに残すべきは「外部 API の秘密情報・fetch が要る部分」= メタデータ → 共有可能 URL の解決**。Spotify / iTunes の API キーはサーバー保持なので、capsicum が title/artist を渡し、サーバーが検索して共有 URL を返す（フロントの処理を軽くする本来のプロキシ設計）。

### 要件: enrich エンドポイント（新規・仕様確定 2026-06-07）

`POST /mulukhiya/api/nowplaying/resolve` — **Bearer（SNS token）必須**（外部 API 濫用防止）

**入力**:

| フィールド | 型 | 必須 | 説明 |
| --- | --- | --- | --- |
| `title` | string | 必須 | 曲名 |
| `artist` | string | 任意 | アーティスト名 |
| `album` | string | 任意 | アルバム名 |
| `source_app_name` | string | 任意 | 再生中アプリ名（`Spotify` / `VLC` / `Apple Music` 等）。プロバイダ優先のヒント |
| `prefer` | string | 任意 | `apple_music` \| `spotify`。capsicum のユーザートグル値（下記 §8.1） |

**プロバイダ優先順位（3段連鎖）**: ① 明示 `prefer` → ② `source_app_name` ヒント → ③ サーバー既定（`/nowplaying/resolve/default_provider`、**既定値 = `apple_music`**）。優先側でヒットなしなら他方へフォールバックして URL を返す。

**出力**: ヒット時 `{ url, provider, normalized:{title,artist,album} }`、ヒットなしは `{ url: null }`（200）。外部 API の癖（文字化け・余分な括弧情報）の正規化はモロヘイヤ側で吸収。capsicum はレスポンスの URL を**クライアント整形のテキストに足すだけ**。読み取り専用。

### 既存ハンドラの扱い（確定）

旧 nowplaying ハンドラを2系統に分類して扱いを確定（モロヘイヤ #4382）:

- **系統①（キーワード → 検索 → URL）`itunes_nowplaying` / `spotify_nowplaying`** → **モロヘイヤ 5.26.0 で削除**。現場で未使用。検索ロジックは enrich エンドポイントの resolver へ集約（暗黙横取りは廃止、能力は明示 API へ昇格）。
- **系統②（URL → Title/Album/Artist 展開）`*_url_nowplaying` 4本** → **据え置き**。現役で、capsicum に対応物のない明示 URL 貼付け展開。`NowplayingHandler.trim` / `DELETE /status/nowplaying` も②と連動して維持。

### features フラグ

`GET /mulukhiya/api/about` の `features` に `nowplaying_resolver` を載せる（capsicum がボタンの「URL 補完を試みるか」の判定に使う）。enrich なしでもクライアント整形で投稿は成立するため capsicum 側では必須ではない。

## 8.1 capsicum 側: ナウプレ プロバイダ優先トグル（要実装）

enrich の `prefer` パラメータの供給元として、capsicum 側に **「ナウプレ URL の優先プロバイダ」設定トグル**が必要。

- **設定 UI**: 設定画面（Spotify 連携セクション近辺）に `Apple Music` / `Spotify` のラジオ or トグル
- **保持**: capsicum **ローカル設定**（端末ローカル嗜好。mulukhiya はステートレスに保つ＝ per-user storage を持たない）
- **送出**: `nowplaying/resolve` 呼び出し時に `prefer` パラメータとして毎回送る
- **既定**: 未設定時はパラメータ省略 → サーバー既定（`apple_music`）が効く。capsicum 側で既定値を `apple_music` に寄せてもよい
- **背景**: Spotify 派 / Apple Music 派がコミュニティで明確に分かれる想定のためユーザー選択にする。運営者（pooza）の価値観（アーティスト還元）からサーバー既定は Apple Music
- capsicum 側 Issue: [pooza/capsicum#681](https://github.com/pooza/capsicum/issues/681)

### 関連

- [capsicum#466](https://github.com/pooza/capsicum/issues/466) Linux MPRIS / [capsicum#484](https://github.com/pooza/capsicum/issues/484) Windows SMTC（本要件の利用元、整形はクライアント確定）
- [capsicum#668](https://github.com/pooza/capsicum/issues/668) Apple Music / [capsicum#570](https://github.com/pooza/capsicum/issues/570) Spotify（URL を返せる源 / enrich の利用先）
- [#4337](https://github.com/pooza/mulukhiya-toot-proxy/issues/4337) Spotify user OAuth（currently-playing。URL を返せる別経路）
- 本節は #4382 を置き換える。capsicum 設計 doc: <https://github.com/pooza/capsicum/blob/develop/docs/nowplaying-design.md>

## 9. 読み付き単語サジェスト API（劇中ワード補完）

### 実装方針（5.26.0 確定・#4397）

設計相談の結果、以下で確定し実装した。詳細仕様は [api.md](api.md) の `GET /mulukhiya/api/word/suggest` を正本とする。

- **エンドポイント**: 新設 `GET /mulukhiya/api/word/suggest`（`tagging/tag/search` 拡張ではなく、読み専用・read-only で別系統）。
- **v1 出力**: `surface` + `reading`（カタカナ）。`category` は**ソースにあれば付く任意フィールド**。`tags`（挿入時タグ自動付与）は別レイヤとして見送り。
- **読み正規化**: **モロヘイヤ側**で吸収（NFKC + ひらがな→カタカナ）。capsicum は素の読みを送ればよい。
- **データソース**: dic.json（MeCab 形式）を再パースせず、**サーバー固有の専用エンドポイント**（precure.ml `/api/dic/v1/pron.json` / mstdn.delmulin.com `/api/dic/v1/pronunciations.json`）の `[{word, pronunciation, category?}]` を取り込む。各サーバーの正本は**1 枚のスプレッドシート**で、GAS が dic.json と pron.json を同一シートから投影（**二重管理を作らない**ことを設計の不変条件とする）。モロヘイヤは Redis の揮発キャッシュのみ保持（`PronunciationDictionaryUpdateWorker` が 10 分毎更新、全 URL 失敗時は last-known-good 保持）。
- **features フラグ**: `features.word_suggest` を `word_suggest/urls` 設定の有無から動的導出（`DynamicFeatures`）。フラグの正本を URL 設定に一本化し二重管理を回避。
- **category の語彙**: スプレッドシートに**プルダウン列を 1 本追加**する運用（寄稿者がメンバーに広がるため複雑なルールを避ける）。値は `人名 / 技名 / 作品名 / 一般`、**空欄=一般**。MeCab の品詞列からは `技名`/`作品名` を判別できない（MeCab 体系に無い）ため、category は**シートに直接入力**し MeCab からの自動導出はしない。
- **辞書整備状況**: デルムリン丼 `pronunciations.json` は 997 語整備済み（当初「~1,000 語が必要」だった前提作業は完了）。
- **MeCab 形式辞書は存続**: タグ付けパイプライン（`MecabRemoteDictionary`）と dic.json（MeCab 形式）は他システムでも利用されており廃止しない。pron.json／category は MeCab dic と**同一スプレッドシートから投影される別ビュー**として並存させ、suggest 専用に使う。category がタグ付けの採用判定に影響することはない（タグ付けは従来通り MeCab の品詞列で判定）。

### 背景

capsicum v1.35（[capsicum#614](https://github.com/pooza/capsicum/issues/614)）で、投稿フォームに**劇中ワード・キャラ名・必殺技名のサジェスト**を実装する。実況用途で、辞書登録のない環境だと専門ワード（例: `閃華裂光拳`）が IME の変換候補に出ず入力できないため、capsicum 側のアプリ独立サジェスト UI で補う。

ユーザーが打鍵できるのは**ひらがな読み**だけなので、**読みから表層形を引ける**ことが必須。

### 現状と課題

- 既存 `tagging/tag/search` は**タグ検索が目的で「読み」を返さない**ため、IME 問題（字面を打てない）を解けない。
- 劇中ワード辞書の大元は MeCab IPADic 形式の単語辞書（例: precure.ml `/api/dic/v1/dic.json`、表層形 + 読みカタカナ付き）で、モロヘイヤはこれを含む複数ソースから辞書を組んでいる＝**読みは内部に存在するが API に露出していない**だけ。

→ capsicum は dic.json を直叩きせず（proxy 哲学・サーバー検出を `/about` に乗せ全プリセット一律カバー）、**モロヘイヤに読みで引けるサジェストを露出してもらう**。

### エンドポイント（案）

既存 `tagging/tag/search` に `reading` を足すか、`GET /mulukhiya/api/word/suggest`（仮称）を新設するかはモロヘイヤ側判断。

- **入力**: `q`（ユーザー入力。**ひらがな/カタカナの読み**を主に想定。表層の前方一致も拾えると望ましい）、`limit`
- **出力（案）**:
  ```json
  { "candidates": [
    { "surface": "愛崎えみる", "reading": "アイサキメグミ",
      "category": "人名", "tags": ["#プリキュア"] }
  ] }
  ```
  - `surface`: 挿入する表層形
  - `reading`: 並べ替え・ハイライト用（カタカナ）
  - `category`: 品詞細分類（人名 / 地域 / 一般 等）。capsicum 側のカテゴリ別ブラウズに使う
  - `tags`: 任意。挿入時のタグ自動付与に繋げられる（別レイヤ）
- **読み正規化**: capsicum 入力ひらがなをカタカナ化して送る／モロヘイヤが両対応するか、どちらが吸収するかを確定したい（proxy 哲学的にはモロヘイヤ寄せが自然）
- 読み取り専用（DB 書き込みなし）

### features フラグ

`GET /mulukhiya/api/about` の `features` に `word_suggest`（仮称）を載せる。capsicum はこれで UI 出し分け（annict / tagging と同じ検出パターン）。

### 前提・補足

- **読みのデータは大元の辞書（dic.json, MeCab 形式）に存在し、モロヘイヤは取り込み済み**。タグ検索 API が読みを落としているだけで、API に surface させるだけの話。内部でどう surface するか（既存 store に読みを持たせる / dic を引き直す等）はモロヘイヤ側判断。
- **前提となるコンテンツ作業**: デルムリン丼・ダイスキーには読み付き辞書が未整備で、~1,000 語の辞書を用意する必要がある（pooza 作業、本 API 実装とは独立）。キュアスタ！・きゅあすきーは dic.json あり。
- 視聴中作品の話数サジェストは既存 `tagging/dic/annict/episodes` を利用予定（本節とは別系統）。
- 本節の実装 Issue: #4397
- capsicum 側 Issue: [capsicum#614](https://github.com/pooza/capsicum/issues/614) / 設計 doc: <https://github.com/pooza/capsicum/blob/develop/docs/compose-suggest-design.md>

## 10. 今後の API 変更時の連携

モロヘイヤ側でエンドポイントの追加・変更・廃止がある場合:

- API ドキュメント（`docs/api.md`）を更新する
- 破壊的変更がある場合は capsicum リポジトリに Issue を起票する
- 可能であればレスポンスにバージョン情報を含め、後方互換性の判断材料とする
