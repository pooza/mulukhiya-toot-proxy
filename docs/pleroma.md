# Pleroma 系（Akkoma）対応の設計と進み具合

5.0 で「削除ではなく未対応」として外した Pleroma 系を、**Akkoma を対象に**少しずつ戻すための設計書。
**進み具合はこのファイルの「進み具合」の表で管理する。**1 段進めたら表と「段階」を書き換える。

- 起点: #4566（最初の段階＝ health・pre_toot・アカウント解決・ゲート）
- 受け皿: #4846（非ゴールとして切ったものの総まとめ・on-hold）。個々の段階はサブ Issue として**マイルストーンに 1 つずつ**載せる
- 検証環境: dev29 `https://st.akkoma.b-shock.org`（Akkoma 3.20.1・pooza/chubo2#164）。構成は chubo2 の `docs/infra-servers.md`「dev29」

## 前提と決めたこと

- **動機は実用ではなく「少しずつ元の形に戻す」こと。**実運用は Mastodon と Misskey だけ。リリース作業・番組表・実況まわりより常に後回しでよい
- **対象は Akkoma。**Pleroma 本体は止まりがち。API・DB とも Pleroma 互換なので、**実装は Pleroma 互換 1 系統・検証は Akkoma**
- **コントローラ名は `pleroma`**（2026-10-16 ユーザー判断）。`/api/v1/pleroma/*` は Akkoma も保っている
- ⚠ **めいすきーは対象外（再提案しない）。**Misskey v10 ベース＝ MongoDB で、`ginseng-mongo` を戻すことになる
- **1 段ごとに dev29 で通してから次へ。**切ってある機能は黙って素通りさせず、`capabilities` / `data` / `features` を false にして明示的に止める

## 作り

| 層 | 中身 | 備考 |
| --- | --- | --- |
| コントローラ | `PleromaController < MastodonController` | 絵文字リアクションの口だけ足す |
| サービス | `PleromaService < MastodonService`（**モロヘイヤ側**） | ⚠ gem の `Ginseng::Fediverse::PleromaService` は 2024-09 から追随していないので使わない |
| アカウント | `Pleroma::Account`（`users`） | ⚠ **API の ID は `users.id`（uuid）ではなく FlakeId の base62**。照合は `api_id` で（`FlakeId`） |
| トークン | `Pleroma::AccessToken`（`oauth_tokens`） | `valid_until` と `users.is_active` を見る。`scopes` は配列型の列 |
| アプリ | `Pleroma::Application`（`apps`） | |
| 投稿 | `Pleroma::Status`（**API で読む**・DB ではない） | 本文は `pleroma.content["text/plain"]` を優先 |
| 添付 | `Pleroma::Attachment`（`objects`） | |
| タグ | `Pleroma::HashTag`（名前だけ・表は無い） | タグは `objects` の JSON の中 |

DB の対応は Mastodon の `accounts` / `statuses` / `oauth_access_tokens` に対して、Akkoma は `users` / `objects` / `activities` / `oauth_tokens`。
v4 の実装は `git show 46c4f4e2^:<path>` で取り出せる（SQL は `app/query/pleroma/*.sql.erb` の 7 本）。

## 進み具合

| 機能 | 状態 | 設定 | 段階 / Issue |
| --- | --- | --- | --- |
| health・起動 | ✅ 5.43.0 | — | #4566（PR #4844） |
| トークン → アカウント（DB） | ✅ 5.43.0 | — | #4566（PR #4844） |
| pre_toot パイプライン（投稿） | ✅ 5.43.0 | — | #4566（PR #4844） |
| 絵文字リアクション（中継） | ✅ 5.43.0 | `capabilities/reaction` | #4566。⚠ **`post_reaction` は流していない**（ハンドラは段階 4） |
| ゲート（harness の Akkoma 系） | ⬜ | — | #4566 の手順 4 |
| webhook | ⬜ | `features/webhook` | 段階 1（#4847） |
| タグのフィード | ⬜ | `features/feed` | 段階 2（`tag_timeline` / `tagged_accounts`） |
| アカウントの直近の投稿・添付の参照 | ⬜ | — | 段階 3（`recent_toot` / `attachment`） |
| ハンドラ（post_reaction ほか） | ⬜ | — | 段階 4（1 本ずつ） |
| メディアカタログ | ⬜ | `data/media_catalog` | 段階 5（`media_catalog`・重い） |
| ストリーミング（listener） | ⬜ | `capabilities/streaming` | 段階 6 |
| 投稿の一括削除 | ⬜ | — | `deletable_statuses` |
| Annict・お知らせ・decoration・compose template | ⬜ | `features/*` | 未定 |

## 段階

各段階は **1 マイルストーンに 1 つ**を目安に、サブ Issue として切り出す。順番は小さく閉じるもの・ほかの段階の土台になるものを先にした。

1. **webhook**（#4847）: `webhook_tokens` を `oauth_tokens` / `apps` / `users` で戻し、`features/webhook` を true に。
   dev29 で webhook から投稿が届くことを確かめる。v4 の SQL は 13 行で、現行の `Webhook.find_token_by_digest` はそのまま使える
2. **タグのフィード**: `tag_timeline` / `tagged_accounts`。`objects.data->'tag'` を開く SQL で、件数が増えると重くなりうる（dev29 では測れないので形だけ）
3. **直近の投稿・添付**: `recent_toot` / `attachment`。nowplaying の置き換えや webhook の添付が使う
4. **ハンドラ**: 判断が要るので 1 本ずつ。最初は `post_reaction` を流すところから
5. **メディアカタログ**: Mastodon / Misskey でも重かった（[media_catalog.md](media_catalog.md)）。最後に回す
6. **ストリーミング**: v4 の `PleromaListener` を戻す。Akkoma のストリーミングは Mastodon 互換

## 残っている穴

- **#4845**: トークンからアカウントを引くとき、スコープを見ていない。Pleroma だけでなく全系統の問題なのでそちらで直す
- 3 系統目のゲートを維持し続けられるかが唯一の争点（使わない系統は腐る。gem の `PleromaService` がその実例）
