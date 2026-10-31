# Pleroma 系（Akkoma）対応の設計と進み具合

5.0 で「削除ではなく未対応」として外した Pleroma 系を、**Akkoma を対象に**少しずつ戻すための設計書。
**進み具合はこのファイルの「進み具合」の表で管理する。**1 段進めたら表と「段階」を書き換える。

- 起点: #4566（最初の段階＝ health・pre_toot・アカウント解決・ゲート）
- 受け皿: #4846（非ゴールとして切ったものの総まとめ・on-hold）。個々の段階はサブ Issue として切り出す
- ⚠ **基本の機能がそろうまで、Akkoma の Issue を切らさない**（2026-10-25 ユーザー判断）。常に「いま進めている段階＋次の段階」の **2 件**を起票してマイルストーンに載せておき、1 件閉じたらその場で次の段階を起票して補充する
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
| ゲート（harness の Akkoma 系） | ✅ 5.43.0・**5.45.0 からリリースゲートの必須** | — | #4566 の手順 4・#4857。dev29 に向けて 0 failures（手順は [test-harness.md](test-harness.md)「手順（Pleroma 系・Akkoma）」） |
| webhook | ✅ 5.44.0 | `features/webhook` | 段階 1（#4847）。⚠ `media_ids` は文字列で送る（`PleromaService#post`） |
| タグのフィード・お気に入りタグ | ✅ 5.45.0 | `features/feed` / `data/favorite_tags` | 段階 2（#4860）。⚠ タグは `hashtags` / `hashtags_objects` の表で引く（v4 は JSON の配列を開いていた） |
| アカウントの直近の投稿・添付の参照 | 🟡 | — | 段階 3。`recent_toot` は ✅ 5.43.0（API で読む・ゲートが要った）。`attachment` は #4861 |
| ハンドラ（post_reaction ほか） | ⬜ | — | 段階 4（1 本ずつ） |
| メディアカタログ | ⬜ | `data/media_catalog` | 段階 5（`media_catalog`・重い） |
| ストリーミング（listener） | ⬜ | `capabilities/streaming` | 段階 6 |
| 投稿の一括削除 | ⬜ | — | `deletable_statuses` |
| Annict・お知らせ・decoration・compose template | ⬜ | `features/*` | 未定 |

## 段階

各段階はサブ Issue として切り出し、上の「2 件を切らさない」に沿って順に起票する。順番は小さく閉じるもの・ほかの段階の土台になるものを先にした。

1. ✅ **webhook**（#4847・5.44.0）: `webhook_tokens` を `oauth_tokens` / `apps` / `users` で戻し、`features/webhook` を true にした。
   ローカルは `users.local`、期限は `valid_until`（UTC の naive な時刻）で見る。dev29 の本物の webhook URL で本文・添付とも投稿できた。
   ⚠ **Akkoma は `media_ids` の要素に文字列を求める**（gem の `upload` は `to_i` で返す・Mastodon は整数でも受ける）。
   ⚠ `WebhookTest#test_command` は dev29 の前段のモロヘイヤと `/crypt/salt` が違うので、harness のときは omit になる（手元の digest が通じない）
2. ✅ **タグのフィード**（#4860・5.45.0）: `tag_timeline` / `tagged_accounts`。
   - ⚠ **JSON の中身は、索引の要らない用途にだけ使う。**Akkoma は「JSON のまま、よく引く経路にだけ式の索引を張る。それでも重いものは本物の列・表へ出す」作りで、索引の無い JSON の経路を条件に使うと全件を読む。
     タグは後から `hashtags` / `hashtags_objects` へ出されたので、それで引く。JSON を見るのは、タグで絞った後の `type` と公開範囲（`to` に `#Public`＝公開。`cc` だけなら未収載）、取り出す列だけ
   - ⚠ **日時は `published` を ISO の文字列のまま返す。**タイムゾーン無しの時刻にすると JST として読まれ、9 時間ずれる（#4864 と同じ形）
   - ⚠ 本文はローカルの投稿なら `source.content`（Akkoma 3.x はオブジェクト）、リモートの投稿は `content`（HTML）
   - ついでに直したもの: `NodeInfo#update` が Pleroma 系で自分のキャッシュを読み直し、ノード名を落としていた（フィードのチャンネル名が空になる）
3. **直近の投稿・添付**: `recent_toot`（✅ 5.43.0）/ `attachment`（#4861）。nowplaying の置き換えや webhook の添付が使う
4. **ハンドラ**: 判断が要るので 1 本ずつ。最初は `post_reaction` を流すところから
5. **メディアカタログ**: Mastodon / Misskey でも重かった（[media_catalog.md](media_catalog.md)）。最後に回す
6. **ストリーミング**: v4 の `PleromaListener` を戻す。Akkoma のストリーミングは Mastodon 互換

## 残っている穴

- ✅ ~~#4845: トークンからアカウントを引くとき、スコープを見ていない~~ → 5.43.0 で書き込みの口はスコープを見るようになった（PR #4849・全系統）
- 3 系統目のゲートを維持し続けられるかが唯一の争点（使わない系統は腐る。gem の `PleromaService` がその実例）。5.45.0 から必須にした（#4857）ので、dev29 が使えないとリリースが止まる
