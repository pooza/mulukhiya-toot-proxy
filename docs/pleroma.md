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
| タグ | `Pleroma::HashTag`（名前だけ） | 表は `hashtags` / `hashtags_objects`。読むのはフィード（`tag_timeline`）と存否（`listable?`）だけ |

DB の対応は Mastodon の `accounts` / `statuses` / `oauth_access_tokens` に対して、Akkoma は `users` / `objects` / `activities` / `oauth_tokens`。
v4 の実装は `git show 46c4f4e2^:<path>` で取り出せる（SQL は `app/query/pleroma/*.sql.erb` の 7 本）。

## 進み具合

| 機能 | 状態 | 設定 | 段階 / Issue |
| --- | --- | --- | --- |
| health・起動 | ✅ 5.43.0 | — | #4566（PR #4844） |
| トークン → アカウント（DB） | ✅ 5.43.0 | — | #4566（PR #4844） |
| pre_toot パイプライン（投稿） | ✅ 5.43.0 | — | #4566（PR #4844） |
| 絵文字リアクション（中継） | ✅ 5.43.0 | `capabilities/reaction` | #4566。`post_reaction` は 5.46.0 から流す（#4884） |
| ゲート（harness の Akkoma 系） | ✅ 5.43.0・**5.45.0 からリリースゲートの必須** | — | #4566 の手順 4・#4857。dev29 に向けて 0 failures（手順は [test-harness.md](test-harness.md)「手順（Pleroma 系・Akkoma）」） |
| webhook | ✅ 5.45.0 | `features/webhook` | 段階 1（#4847）。⚠ `media_ids` は文字列で送る（`PleromaService#post`） |
| タグのフィード・お気に入りタグ | ✅ 5.45.0 | `features/feed` / `data/favorite_tags` | 段階 2（#4860）。⚠ タグは `hashtags` / `hashtags_objects` の表で引く（v4 は JSON の配列を開いていた） |
| アカウントの直近の投稿・添付の参照 | ✅ | 5.46.0 | 段階 3。`recent_toot` は 5.43.0（API で読む・ゲートが要った）。添付は #4861（ID で引く経路は元から通っていた・`Account#attachments` を actor と `Document` で引く） |
| 自分の投稿の一覧（WebUI） | ✅ 5.47.0 | `data/account_timeline` | #4900。ID は `activities` の `Create` を `actor` で引き（索引 `activities_actor_id_DESC_NULLS_LAST_index`）、中身は API で読む。activity の主キーの FlakeId が API の投稿 ID |
| ハンドラ（post_reaction ほか） | ✅ 5.47.0 | — | 段階 4。`post_reaction` は 5.46.0（#4884）、残りは #4910 で 1 本ずつ見た（下の「ハンドラの判定」）。Pleroma 系で外すものは無かった |
| メディアカタログ | ✅ 5.47.0 | `data/media_catalog` | 段階 5（#4911）。ローカルの利用者ごとに `activities_actor_id_DESC_NULLS_LAST_index` で投稿を引き、`attachment` を展開して `Document` を 1 行ずつ索引で引く。cursor は `<FlakeId>.<位置>` |
| ストリーミング（listener） | ✅ 5.47.0 | `capabilities/streaming` | 段階 6（#4901）。`PleromaListener < MastodonListener`。送り主は API の ID（FlakeId）を uuid に戻して引く |
| 投稿の一括削除（テスト用アカウントの添付） | ✅ 5.49.0 | — | #4938。`deletable_statuses` は戻さず、添付のある投稿を API（`only_media`）で引いて投稿ごと消す（`MediaStatusClearMethods`・Mastodon と共通）。⚠ それまでは Mastodon 系の全部で動いていなかった（下の「段階」の 7） |
| お知らせ | ✅ 5.47.0 | `features/announcement` | #4910。Akkoma の `/api/v1/announcements` は Mastodon と同じ形。⚠ `announcement_push`（capsicum-relay）は false のまま |
| 投稿テンプレート | ✅ | `features.compose_templates`（常に true） | #4938。保存先は利用者の設定で SNS に依らない。dev29（5.48.0）で作成・一覧・更新・削除を確かめた（2026-11-28） |
| Annict | ✅ 5.49.0 | `features/annict` | #4939。Akkoma 向けに足すものは無かった（アカウントの ID・利用者の設定・webhook だけに頼る）。⚠ サーバーに Annict の OAuth アプリ（`/service/annict/oauth/client`）が要る |
| ALT 編集（投稿済みの添付） | ⬜ 次の段階 | `capabilities/media_update` | #4945。Akkoma は編集の `media_attributes` を読まない。`PUT /api/v1/media/:id` のあとに投稿を編集すると変わる |
| 投稿へのタグの追加・ナウプレの整理 | ⬜ 次の段階 | `capabilities/repost` | #4946。消して投稿し直すか、Akkoma の編集で済ませるかを決める |
| 注目のタグ | — | `data/futured_tag` | **対象外。**Akkoma の `/api/v1/featured_tags` は `Not implemented`（404）を返す（dev29・2026-11-28）。`Pleroma::Account#featured_tags` は空を返す |
| お知らせの push | — | `features/announcement_push` | **対象外（capsicum-relay 次第）。**モロヘイヤ側に作るものは無い（`/announcement/list` は 5.47.0 から返る）。relay が Akkoma のお知らせを扱えるようになったら、サーバーごとに true にする |
| decoration（アバターデコレーション） | — | — | **対象外。**Misskey だけの機能で、Akkoma には無い（リアクションとは別物・2026-11-23） |

## 段階

各段階はサブ Issue として切り出し、上の「2 件を切らさない」に沿って順に起票する。順番は小さく閉じるもの・ほかの段階の土台になるものを先にした。

1. ✅ **webhook**（#4847・5.45.0）: `webhook_tokens` を `oauth_tokens` / `apps` / `users` で戻し、`features/webhook` を true にした。
   ローカルは `users.local`、期限は `valid_until`（UTC の naive な時刻）で見る。dev29 の本物の webhook URL で本文・添付とも投稿できた。
   ⚠ **Akkoma は `media_ids` の要素に文字列を求める**（gem の `upload` は `to_i` で返す・Mastodon は整数でも受ける）。
   ⚠ `WebhookTest#test_command` は dev29 の前段のモロヘイヤと `/crypt/salt` が違うので、harness のときは omit になる（手元の digest が通じない）
2. ✅ **タグのフィード**（#4860・5.45.0）: `tag_timeline` / `tagged_accounts`。
   - ⚠ **JSON の中身は、索引の要らない用途にだけ使う。**Akkoma は「JSON のまま、よく引く経路にだけ式の索引を張る。それでも重いものは本物の列・表へ出す」作りで、索引の無い JSON の経路を条件に使うと全件を読む。
     タグは後から `hashtags` / `hashtags_objects` へ出されたので、それで引く。JSON を見るのは、タグで絞った後の `type` と公開範囲（`to` に `#Public`＝公開。`cc` だけなら未収載）、取り出す列だけ
   - ⚠ **日時は `published` を ISO の文字列のまま返す。**タイムゾーン無しの時刻にすると JST として読まれ、9 時間ずれる（#4864 と同じ形）
   - ⚠ 本文はローカルの投稿なら `source.content`（Akkoma 3.x はオブジェクト）、リモートの投稿は `content`（HTML）
   - ついでに直したもの: `NodeInfo#update` が Pleroma 系で自分のキャッシュを読み直し、ノード名を落としていた（フィードのチャンネル名が空になる）
3. **直近の投稿・添付**: `recent_toot`（✅ 5.43.0）/ 添付（✅ 5.46.0・#4861）。nowplaying の置き換えや webhook の添付が使う。
   ⚠ 添付は v4 の `attachment.sql.erb`（URL の JSON の式で引く）を戻していない。v4 でも呼び出し元が無く、索引も効かない。
   投稿の `media_ids` は API のメディア ID ＝ `objects` の主キーなので `attachment_class[id]` で引ける。
   アカウントの添付は `data->>'actor'` と `data->>'type' = 'Document'` で引く（Akkoma の索引 `objects_actor_type` が効く）
4. **ハンドラ**: 判断が要るので 1 本ずつ。最初は `post_reaction` を流すところから（✅ 5.46.0・#4884）。
   判断の中心は `reactionable?`。受け手のサーバーの nodeinfo は `software.name` が `akkoma` なので、設定の `akkoma.capabilities.reaction` を立てた。
   Akkoma の利用者は絵文字リアクションを自分で見られるので、リアクションを伝える返信は投稿しない（Misskey 系から Akkoma の利用者へのリアクションも同じ）
   ✅ 残りは #4910（5.47.0）で、dev29 で投稿して確かめた。結論は下の「ハンドラの判定」。
5. ✅ **メディアカタログ**（#4911・5.47.0）: Mastodon / Misskey でも重かった（[media_catalog.md](media_catalog.md)）ので、Mastodon と同じローカルの利用者ごとの LATERAL merge にした。
   ⚠ 添付は投稿（`Note`）の JSON の `attachment` にしか無く、`Document` から投稿へは辿れない。投稿から展開し、`Document` は AP の ID で引く（`objects_unique_apid_index`）。
   ⚠ 素直に JOIN すると、少データでは `objects` を全件読んで Hash Join する（dev29 で実測）。LATERAL と LIMIT 1 で入れ子のループに固定した。
   ⚠ 並びは（投稿の ID DESC, 添付の位置 ASC）。cursor は `<投稿の FlakeId>.<位置>`（Misskey と同じ型・#4375）。
   **規模の見積もり（2026-11-15・dev29 でトランザクションの中に偽のデータを入れて測り、ROLLBACK した）**: `objects` 31 万・`activities` 36 万、
   ローカルの 1 人に Like 5 万と添付の無い投稿 1 万を新しい側に積んで、1 ページ目 77 ms・OFFSET 900 で 66 ms・cursor 1.1 ms。どれも索引だけで、全件の読み込みは無い（添付の展開を内側へ移した形・Incremental Sort が索引の順を使って途中で止まる）。
   ⚠ キーワードは添付 1 件ごとに当てる（PR #4919 の Codex P2）。投稿単位でまとめると、同じ投稿のほかの添付まで出る
   ⚠ 1 人ぶんの走査は、その利用者の activity の数に比例する（添付の有無は索引に無い）
6. ✅ **ストリーミング**（#4901・5.47.0）: v4 の `PleromaListener` を戻した。Akkoma のストリーミングは Mastodon 互換。
   ⚠ トークンはヘッダでも URL でもなく `Sec-WebSocket-Protocol` で渡す（Akkoma はヘッダを読まない・ginseng-fediverse 9.0.0・pooza/ginseng-fediverse#337）。
   ⚠ 送り主は v4 の `fqn` ではなく `account.id`（FlakeId）を `FlakeId.decode` して引く。
   `mention` / `follow` は基本のパイプライン（`welcome_mention` など）がそのまま流れる
7. ✅ **残りの棚卸し**（#4938・5.49.0）: 投稿テンプレートは dev29 で通った。テスト用アカウントの添付の一括削除
   （`rake mulukhiya:media:record:clean` → `clear_attachments`）は**動いていなかった**ので直した。
   ⚠ gem の `MastodonService` に `delete_attachment` が無く、1 件ごとに `NoMethodError` で落ちていた（dev29 で 136 件が 1 件も消えなかった）。
   Mastodon は `attachments` も無く `ImplementError`。Mastodon 系の API には投稿に付いた添付だけを消す口が無いので、v4 の Pleroma 版と同じく
   添付のある投稿ごと消す（`MediaStatusClearMethods`）。dev29 で上限の 30 件が消えた。
   `false` のままの設定は、作れるもの（ALT 編集 #4945・リピート #4946）と対象外（注目のタグ・お知らせの push）に分けた（上の表）
8. ✅ **Annict**（#4939・5.49.0）: `features/annict` を true にしただけ。認可・視聴記録・感想・番組表の「話数 ＋」・取り込み
   （`AnnictPollingWorker`）は、どれもアカウントの ID（`UserConfigStorage` のキー）・利用者の設定・webhook に頼っていて、SNS の形に依らない。
   dev29 で認可（`annict_linked` が true）と、取り込み（Annict の既存の記録が webhook でテスト用アカウントの投稿になる）を確かめた（2026-11-28）。
   Annict への書き込み（記録・感想の投稿）は、公開で残るので実地では確かめていない。
   ⚠ dev29 の OAuth アプリは dev24 と同じもの（リダイレクトは OOB）。secret は dev29 のソルトで暗号化し直して `config/local.yaml` に入れた

### ハンドラの判定（#4910・2026-11-15・dev29 の Akkoma 3.20.1）

**Pleroma 系だけ外す（`pipeline/pleroma` の `exclude` に足す）ものは無かった。**止まっていたものは、どれも設定か利用者の状態で止まっていた。

| ハンドラ | 判定 | 確かめたこと |
| --- | --- | --- |
| `post_announce`・`announcement_mention` | ✅ 戻した | `features/announcement` を true にした。お知らせを足すと info が未収載で投稿し、info への「お知らせ」のメンションに一覧を返した |
| `user_config_command`・`user_tag` | ✅ | コマンドで `user_tags` が保存され、次の投稿にタグが付いた。⚠ 保存の直後（同じ秒）の投稿にはまだ付かない（Pleroma に限らない） |
| `scheduled_status_save` | ✅ | `scheduled_at` 付きの投稿で `ScheduledStatusStorage` に残った（結果を返さないハンドラなのでログには出ない） |
| `image_format_convert`・`video_format_convert`・`audio_format_convert` | ✅ | PNG → WebP・AVI（mpeg4）→ MP4・WAV → MP3 |
| `mention_visibility` | ✅ | `agent/accts` に入っている相手だけが対象。info は入っていないので変わらないのが正しい |
| `reply_reaction`・`result_notification` | ✅ 5.46.0 | #4884 |
| `welcome_mention` | ✅ 5.47.0 | #4901 |
| `image_copyright`・`spotify_url_nowplaying`・`you_tube_url_nowplaying` | ⚪ 設定が無いだけ | ハンドラの設定（`tag`・`message`・`url`）や API の鍵が dev29 に無い。Pleroma 系の事情ではない |
| `piefed_bookmark`・`piefed_clipping_command`・`webhook_image` | ⚪ 利用者の設定次第 | 利用者が PieFed・webhook を設定していると動く |
| `invalid_command` | ⚪ 投稿次第 | コマンドの投稿のときだけ動く |
| そのほか（`default_tag`・`dictionary_tag`・`tagging`・URL 系ほか 14 本） | ✅ | 本文の文字列を書き換えるだけで、SNS の形に依らない。`default_tag` は公開の投稿で付くことをログで見た |

⚠ HEIF は libheif の版で決まる（#4734）。dev29 は Ubuntu の 1.21.2 なので、HEIC は断る（`ValidateError` の文言を確認した）。

## 残っている穴

- ✅ ~~#4845: トークンからアカウントを引くとき、スコープを見ていない~~ → 5.43.0 で書き込みの口はスコープを見るようになった（PR #4849・全系統）
- 3 系統目のゲートを維持し続けられるかが唯一の争点（使わない系統は腐る。gem の `PleromaService` がその実例）。5.45.0 から必須にした（#4857）ので、dev29 が使えないとリリースが止まる
