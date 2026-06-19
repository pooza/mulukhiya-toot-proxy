# ナウプレ ユニバーサルリンク（Odesli / song.link）対応計画（Songwhip #3748 後継 / Issue 未起票）

> **ステータス**: 計画（未着手・未起票）。急がない。モロヘイヤ側の他作業の進捗を見て着手する。
> 本ドキュメントは「Songwhip 終了で失われた横断リンク機能を Odesli（song.link）で復活し、
> あわせてナウプレ enrich の対応プロバイダ／host を広げる」計画の正本。実装はモロヘイヤが
> 主体で、capsicum 側は Direction B を採る場合のみ数行の UI 追従が要る。
>
> **着手前の確認課題**（後述「未決事項」）: Odesli API キー申請（pooza のアカウント操作）、
> レート制限の緩和可否、キャッシュ／保存に関する ToS。キー無しでも低レートで動作するため、
> 実装の先行着手 → キー後付けは可能。

## 背景

Songwhip 連携（楽曲 URL → 全プラットフォーム横断のユニバーサルページ URL を取得して投稿に
追記する post-time ハンドラ）は、サービス終了に伴い **#3748（2024-08, commit `993aa781`）で
削除済み**。削除されたのは:

- `app/lib/mulukhiya/service/songwhip_service.rb`
- `app/lib/mulukhiya/handler/songwhip_nowplaying_handler.rb`
- 対応する test と `config/application.yaml` の `/songwhip` 設定

Songwhip ユーザーの間では **Odesli（song.link / album.link）** が後継として定着している。
Odesli は「楽曲 URL → 横断リンク＋正規化メタ」を返す公開 API を持ち、削除済み Songwhip
実装をほぼそのまま置き換えられる。

加えて、現行のナウプレ enrich は **Apple Music（iTunes Search API）と Spotify の 2 プロバイダ
のみ**を扱う（[`NowplayingResolver`](../app/lib/mulukhiya/nowplaying_resolver.rb) /
[`NowplayingUrlResolver`](../app/lib/mulukhiya/nowplaying_url_resolver.rb)）。Odesli を入れると、
逆引き（URL → メタ）の対応 host を YouTube Music / Amazon Music / Tidal / Deezer / SoundCloud
など多数へ一気に広げられる。

> ナウプレ機能そのものは capsicum 側で当初計画を概ね完走済み。本計画はその「後継」にあたる
> 拡張で、急ぎではない。

## ゴールとスコープ

2 方向に分ける。**A は B の土台**で、排他ではない。

- **Direction A（モロヘイヤ完結）** — capsicum 無改修。
  - (a) ユニバーサルリンク追記ハンドラの Odesli 版復活（旧 Songwhip と同等の post-time enrich）。
  - (b) `resolve-url`（URL → メタ）の対応 host を Odesli で拡張。
- **Direction B（プロバイダ切替に「ユニバーサル」を追加）** — capsicum＋モロヘイヤの協調。
  - capsicum の URL プロバイダ切替（現状 Apple Music / Spotify）に第3の選択肢
    「song.link（ユニバーサル）」を追加し、ユーザーが明示的に横断リンクを選べるようにする。

いずれもモロヘイヤが処理の大半を担い、capsicum 側は B のときのみ薄い UI 追従（enum 値・ラベル・
既定値の分岐）に限られる。

## 現行アーキテクチャの整理

ナウプレの URL／メタ解決には 2 つの読み取り専用 enrich エンドポイントと、投稿時に走る
ハンドラ群がある。

| 経路 | 実体 | 方向 | エンドポイント / フック | feature flag |
| --- | --- | --- | --- | --- |
| 取得経路（♪ ボタン） | [`NowplayingResolver`](../app/lib/mulukhiya/nowplaying_resolver.rb)（#4382） | メタ → URL | `POST /mulukhiya/api/nowplaying/resolve` | `nowplaying_resolver` |
| 共有経路（Share） | [`NowplayingUrlResolver`](../app/lib/mulukhiya/nowplaying_url_resolver.rb)（#4415） | URL → メタ | `POST /mulukhiya/api/nowplaying/resolve-url` | `nowplaying_url_resolver` |
| 投稿時 enrich | `*_url_nowplaying_handler`（itunes / spotify / youtube / peertube） | URL → 本文整形 | post-time handler | — |
| （旧）横断リンク | `SongwhipNowplayingHandler`（#3748 で削除） | URL → ユニバーサル URL 追記 | post-time handler | — |

- プロバイダ優先順位（`resolve`）は 3 段連鎖: ① 明示 `prefer` → ② `source_app_name` ヒント →
  ③ サーバー既定 `/nowplaying/resolve/default_provider`（既定 `apple_music`）。
- capsicum 側の切替は端末ローカル設定 enum `NowPlayingUrlProvider { appleMusic, spotify }` で、
  `prefer` として毎回 `resolve` に渡す。**この `prefer` が効くのは取得経路のみ**（共有経路は現状
  `prefer` を参照しない）。

### capsicum 側の入口（無改修で済む根拠 / Direction A）

capsicum は共有テキストが**単一の http(s) URL**かだけを見て（`isSingleNowPlayingUrl`、ホスト
判定なし）、ホストを問わず `resolve-url` に投げる。どの host を解決するかの分岐は完全に
モロヘイヤ側にある。したがって **(b) の host 拡張はモロヘイヤだけで効き、capsicum は無改修**。
返却形（`{url, normalized: {title, artist, album}}`）も変わらないため、capsicum の整形は流用。

## Odesli（song.link）API 概要

- **エンドポイント**: `GET https://api.song.link/v1-alpha.1/links?url=<楽曲URL>`
  （`platform` + `type` + `id` 指定も可）。
- **主なパラメータ**: `url`（入力 URL）, `userCountry`（ISO、既定 US）, `songIfSingle`（bool）,
  `key`（API キー、任意）。
- **レスポンス**（実測・2026-06 確認済み）: `pageUrl`（song.link / album.link のユニバーサル
  ページ）, `linksByPlatform`（各サービスの個別リンク）, `entitiesByUniqueId`（`title` /
  `artistName` / `thumbnailUrl` 等）。
- **入力対応プラットフォーム**: spotify / apple music / itunes / youtube / youtube music /
  amazon music / amazon store / tidal / deezer / soundcloud / pandora / napster / yandex /
  audius / anghami / boomplay など多数。
- **料金**: 有料プランは存在せず、API は全機能無料（"At this time, all of our features are free."）。
- **レート制限**: 匿名で **10 req/分**。引き上げは **無料の API キー申請**（developers@odesli.co
  宛のメール）で対応する。プリセット規模ならキー取得でほぼ足りる見込み。
- **キャッシュ／保存（ToS）**: 未確定。公式 API ドキュメント（Notion）の保存・再配布に関する
  条項を読み切れていない。キャッシュ前提にする前に、キー申請のやり取りで明示確認する。
- **資格情報**: 不要（キー無しでも単発は 200）。iTunes Search 同様、常時有効にできる。

参考: 公式ドキュメント（Notion）/ `odesli.co/pricing`。具体的なレート・キャッシュ条項は
着手時にドキュメントで再確認する。

## Direction A: モロヘイヤ完結

### (a) ユニバーサルリンク追記ハンドラの Odesli 版復活

旧 `SongwhipNowplayingHandler` / `SongwhipService` と 1:1 で対応する。雛形は削除コミット直前
（`993aa781^`）のコードがそのまま使える。

- `OdesliService`（`SongwhipService` 相当）: HTTP GET `/links?url=...` → レスポンスの `pageUrl`
  を `Ginseng::URI` で返す。`config['/odesli/urls/api']` を base に持つ。キーがあれば付与。
- `OdesliNowplayingHandler`（`SongwhipNowplayingHandler` 相当）: 投稿中の `#nowplaying` 行 or
  `track_uris` に URL があれば Odesli に投げ、得た `pageUrl` を `push` で本文に追記。
- `config/application.yaml` に `/odesli` セクション（API URL・キー・タイムアウト等）を追加。
- test（`test/odesli_service.rb` / `test/odesli_nowplaying_handler.rb`）を旧 Songwhip テストの
  形で復活。

song.link ページは OGP を持つため、Mastodon 側でリンクカードとして展開される。

> **注意**: 旧 Songwhip と同様、ハンドラの有効化は `config/autoload.yaml` 等の登録に依存する。
> 旧実装の登録箇所を `993aa781` の diff で確認して合わせる。

### (b) `resolve-url`（URL → メタ）の host 拡張

[`NowplayingUrlResolver#detect_provider`](../app/lib/mulukhiya/nowplaying_url_resolver.rb) は今
`spotify` / `apple_music` のみ。これに **Odesli フォールバック**を足す:

- 既知 host（spotify / apple_music）は従来どおりネイティブ parse（資格情報・精度の面で優先）。
- 未対応 host（YouTube Music / Amazon Music / Tidal / Deezer / SoundCloud 等）は Odesli に
  URL を渡し、`entitiesByUniqueId` の `title` / `artistName` を `normalized` にマップして返す。
  `url` には入力 URL（または `pageUrl`、後述の方針による）を載せる。
- 解決不可は従来どおり `{url: nil}`（200 + null）。

これにより capsicum の共有経路が、実質ほぼすべての主要音楽サービスの URL を整形できるように
なる（capsicum 無改修）。

## Direction B: プロバイダ切替に「ユニバーサル」を追加

capsicum の URL プロバイダ切替（`NowPlayingUrlProvider`）に第3の値を足し、ユーザーが「特定
サービスに寄せず、どこでも開けるリンク（song.link）」を選べるようにする。趣旨（どの配信元の
URL を載せるか）に素直に乗る。

### モロヘイヤ側（処理の本体）

- `NowplayingResolver`（メタ → URL）に `prefer=universal`（値は `odesli` 等、要確定）を追加。
  Odesli は「メタ → URL」を直接できない（入力に URL かエンティティが要る）ため、**2 段**にする:
  1. apple_music / spotify で検索して platform URL を得る（既存ロジック流用）。
  2. その URL を Odesli に渡して `pageUrl`（song.link）にラップし、`url` として返す。
  - どの検索バックエンドを使うかは内部詳細（`default_provider` 準拠 or 両者試行）。`normalized`
    は検索ヒットのメタを使う。
- `NowplayingUrlResolver`（URL → メタ）側は、`prefer=universal` のとき得た URL を `pageUrl` に
  ラップして返す（**1 段**）。(b) と自然に合流する。
- `PROVIDERS` 定数・`provider_order` の連鎖に `universal` を組み込む。`default_provider` で
  `universal` を既定にできるかは要検討（既定はサービス寄せの方が無難か）。

### capsicum 側（薄い追従のみ・新ロジックなし）

- `enum NowPlayingUrlProvider` に `universal` を追加（`apiValue` = `odesli`/`songlink` 等）。
- 設定 UI（`display_settings_screen.dart`）にラベル 1 行追加。
- 既定値ロジックの分岐。
- 一貫性を取るなら**共有経路でも `prefer` を尊重**したい（現状 `resolve-url` は `prefer` 非対応）
  → モロヘイヤ `resolve-url` に `prefer` を受ける口を足し、capsicum 共有経路でも渡す。これは
  追加スコープなので、まず取得経路だけで出すのでも可。

### 実装順序

1. **モロヘイヤが先行**して `prefer=universal` を実装・ステージング検証。
2. capsicum が選択肢を出す。
   - capsicum を先に出してもサーバー未対応の間は fallback に倒れるだけで壊れはしないが、UX 上は
     サーバー先行が素直。

## 運用・非機能

- **レート制限**: 匿名 10 req/分。API キー申請で緩和。必要なら正規化 URL をキー（cache key）に
  した短 TTL キャッシュを検討（ただし ToS 確認後）。
- **エラー方針**: 既存の degrade 方針を踏襲。Odesli 失敗・未ヒット・タイムアウトは enrich を
  諦め、`{url: nil}` / 元メタ据え置きに倒す（投稿自体は常に成立）。
- **ログ衛生**: URL・keyword はユーザー入力なのでログに残さない（#4394 と同方針。`e.log` の
  引数に生 URL を入れない）。
- **資格情報**: Odesli はキー無しでも動くため、iTunes 同様 `enabled?` を常時 `true` にできる
  （キーはレート緩和のための任意設定）。
- **公開リポジトリ**: 本リポジトリは公開。API キーの実値は `config/application.yaml` のサンプル
  等に書かず、秘匿設定（環境変数 / ローカル設定）で渡す。

## 未決事項 / 確認課題

1. **Odesli API キー申請**（pooza のアカウント操作）。申請メール文面は Claude が下書きする。
   レート緩和の実条件と、商用利用・キャッシュ可否を申請のやり取りで確認する。
2. **キャッシュ／保存の ToS**。許可されない場合はキャッシュを入れず、レート制限内に収める設計に
   する（プリセット規模なら現実的）。
3. **`url` に何を載せるか**: (b) host 拡張で、`url` を入力 URL のままにするか `pageUrl`
   （song.link）にラップするか。Direction A 単独なら入力 URL 維持が素直、B と統合するなら
   `pageUrl`。`prefer` で切り替える設計が綺麗。
4. **共有経路で `prefer` を尊重するか**（B の一貫性）。`resolve-url` に `prefer` 口を足すかどうか。
5. **`universal` を `default_provider` に許すか**。サーバー既定をユニバーサルにできると、非プリセット
   ユーザー向けの方針とも絡む。

## 段階・依存関係

- **A を土台に B を載せる**。A だけでも Songwhip 終了で失った価値（横断リンク・広い host 対応）を
  回復できる。B はその上で「ユーザーが明示選択できる」UX を足すもの。
- 急がない。モロヘイヤ側の他作業の進捗を見て着手。capsicum 側（B）はモロヘイヤ実装後の追従で足りる。
- Spotify OAuth（#4337）の有効・無効に依存しない（Odesli は資格情報不要）。`spotify_enabled` が
  OFF の環境でも横断リンク・host 拡張は効く利点がある。

## 関連

- Songwhip 削除: #3748（commit `993aa781`）
- ナウプレ enrich（メタ → URL）: #4382 / capsicum #466
- ナウプレ enrich（URL → メタ）: #4415 / capsicum #729
- Spotify OAuth: #4337 / capsicum #465
- capsicum 側の URL 補完統合: capsicum #669
- Odesli 公式: `https://odesli.co/` / API ドキュメント（Notion）/ developers@odesli.co
- Issue: 未起票（着手時に起票）
