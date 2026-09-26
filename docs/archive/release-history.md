# リリース履歴

CLAUDE.md から分離した過去のリリースノート。直近リリースは [CLAUDE.md](../CLAUDE.md) を参照。

## リリース済み: 5.34.0（2026-08-22）

**本番デプロイ: 4 台完了**（2026-08-22、shallu → zugoga → gomander → **vulcan** の順。
全台 version 5.34.0 / health 200（全サブシステム OK）/ `yjit_enabled: true` / Ruby 4.0.6 据え置き /
WebUI 200 / 再起動後の生存 pid が吐いたログに新規エラー署名なし）。

⚠⚠ **ダイスキーの本番が sweep から vulcan へ変わった**（2026-08-22 14:06 カットオーバー・
pooza/chubo2#35）。**本番 4 台は shallu / zugoga / gomander / vulcan。**
vulcan は **dev27 と同じ形**（Ubuntu 26.04 / `misskey` ユーザー / `/home/misskey/repos` /
systemd / monit なし）で、**FreeBSD 3 台とは手順が違う**。⚠ **`sweep` はまだ生きていて
mulukhiya も残っている**（8 月末まで残置・pooza/chubo2#192）ので、**うっかり sweep へ
デプロイしないこと。**

デプロイで踏んだこと:

- ⚠ **`git fetch --tags` が既存タグ衝突で非ゼロを返し、`set -e` のスクリプトが黙って止まる。**
  本番には `v5.3.0` のようなローカルタグが残っていて `would clobber existing tag` になる。
  **デプロイに `--tags` は要らない**ので付けない（付けるなら `|| true`）
- monit は **2 つ**登録されている（`mulukhiya` = Remote Host と `mulukhiya-sidekiq` = Process）。
  **両方 unmonitor / monitor する**
- 再起動順は **sidekiq → puma → listener**。⚠ ssh 越しの `service ... restart` は
  `</dev/null >/dev/null 2>&1` を付けないとセッションが返ってこない

**テーマは「黙って壊れるのをやめる」。**#4573 / #4558 とも、**上流の正規化・検証がキャッシュ層や rescue で静かに外れ、機能が死んでも誰も気付かない**という同じ型（#4549 / #4560 と同族）。
GitHub マイルストーン作成済み（#632）。バージョンバンプは 2026-08-12（5.33.0 リリース直後）に実施済み（[[feedback_bump-version-first]]）。

- **#4573 obs/bug: リモート辞書が 200-with-HTML を掴むと黙って空になる（主軸・size:S）** — 2026-08-12 の 5.33.0 ステージング検証中に、ステージングのログから気付いて本番で確認したもの。GAS の `/exec` が失効すると **HTTP 200 のまま `text/html`** を返し、`RemoteDictionary#fetch` は `present?` しか見ていないので String が通る。`RelatedRemoteDictionary#parse` の `fetch.to_h` が `String#to_h` で倒れ、外側の rescue が `{}` を返して**辞書が空になる**
  - ⚠ **美食丼（shallu）は `related` 辞書 3 本とも死んでおり、関連語タグ付けが機能していない**（GAS 2 本が 200+HTML、`service.json` が 302→404。10 分周期で毎回全滅）。zugoga / gomander / sweep は 0 件
  - ⚠ **`e.log` 止まりなので Sentry に出ない**（`Sentry.capture_exception` を呼ぶのは `alert` の側）。#4549 / #4560 と同じ「機能が黙って死ぬ」系
  - 直し方の前例は同リポ内の `PronunciationDictionary#valid_schema?`（`parsed.is_a?(Array)` を確かめ、外れたら型名つきで `logger.error`）。**読み辞書だけ検証していてタグ辞書が素通し**という非対称になっている
  - ⚠ **fail-open 自体は残す**。GAS の一過性障害で辞書が消し飛ぶのを防ぐ意図は正しい。問題は倒れたことが**見えない**ほう
  - 付随して 3 サブクラスで異常時の挙動が割れている（`Related` / `Mecab` は fail-open で `{}`、`MultiField` だけ外側 rescue が無く例外が抜ける）
  - **5.33.0 には積まなかった**。ユーザー可視の機能不全＝リリース前レビューの基準では「赤」だが、**5.33.0 の退行ではない既存事象**で、積むとステージング検証をやり直すことになるため（2026-08-12 ユーザー判断）。⚠ **GAS デプロイ URL の失効そのものは運用側の是正**で Issue のスコープ外

- **#4558 番組表の `next_on` に `Time` を手書きすると Redis キャッシュ往復で無効値になる（size:S）** — 5.33.0 で保留にしていたものを 2026-08-12 に繰り入れ。`load_from_yaml` が **coerce 前の生ハッシュ**を `update_cache` に渡すため、Redis には `"2026-08-08 18:00:00 +0900"` が入り、**1 回目（キャッシュミス）だけ正しく 2 回目以降は無効値**になって VEVENT が黙って消える
  - **発火経路を潰して確認した（2026-08-12）。トリガーは `var/program.yaml` の手書きだけ。**エディタの `next_on` は `input type='date'` なので常に `YYYY-MM-DD` の String（項目 3 の不正日付も作れない）、リモート取得は JSON 経由なので時刻型が存在しない
  - ⚠ **それでも積む理由は「#4537 を半分着地のまま残さない」。**`Time` を許可クラスへ入れたのは #4537（5.32.0）が「手書きでも読める」ようにするためで、**こちらが明示的にサポートすると決めた書き方**が 2 回目の読み出しから壊れている
  - ⚠ **一度入ると save をまたいで残る。**`write_yaml` は `to_yaml` をそのまま書き、`Time` は**クォートされず Time のまま書き戻る**。`save` はハッシュ全体を書くので、**エディタで別の行を編集しても Time の行は Time のまま**再永続化される
  - ⚠ **`PERMITTED_YAML_CLASSES` から `Time` を外す方向は採らない。**外すと #4537 が潰した「クォート忘れで番組表全体が読めなくなる」footgun が戻る
  - ⚠ **ゾーンレスの手書きは Psych が UTC で読む**（`18:00:00` と書くと `+0900` では翌日 03:00）。`format_date` の `getutc` はこれを戻すための処理なので、**項目 2「明示オフセットには効かせない」是正はこの UTC 前提を壊さない形で入れる**
  - 直し方は `load_from_yaml` で coerce 済みを `update_cache` に渡す側を推す（**項目 2 も同時に閉じる**）

- **#4576 security: SSRF 掃討の取り残し 2 件（size:M）** — `is_cat` の webfinger が無検証（リダイレクト未検証 + pinning 無し）と、webhook の `image_url` が **full-read SSRF**。5.33.0 のリリース前レビューで赤に分類したが、**修正が全画像ハンドラと webfinger 経路に及ぶ**ため独立サイクルに分けた（2026-08-12 ユーザー判断）
  - ⚠ **CDN への pinning は「複数 A レコードのフォールバックが効かない」既知のトレードオフ**（#4524）を、いまより広い面へ適用することになる。harness 実走込みで見る

- **#4585 番組表: 「次回」ボタンを「話数 +1」と「日付 +1」に分離する（size:M・2026-08-15 着地）** — 2026-08-13 ユーザー要望。現行の ＋ は `episode` の +1 と `next_on` の +7 日を同時に行うため、①2 週以上放置したエントリは 1 回押しても過去日のまま ②話数だけ直したいときに日付が巻き込まれる ③**Annict が載らずに 200 が返ったとき、押し直すと話数が飛んだうえ日付が 7 日ずれる**（[[project_5330-release]] の footgun）
  - ⚠ **日付側は +7 日ではなく +1 日**（2026-08-13 ユーザー判断）。**翌日放送であることがある**のと、**+1 日なら 7 回押して翌週も兼ねられる**ため。`NEXT_ON_INTERVAL_DAYS = 7` は用済みになるので消す。⚠ **7 のまま別名で残さない**（週次前提が別の場所へ生き延びる）
  - ⚠ **連打が常用操作になる。**一覧のボタンは `:disabled='isBusy(key)'` なので素朴に作ると 7 往復待たされ、**ロック取得も 7 回**になる（#4534 の 409 が増える）。楽観更新か日数パラメータで往復を減らす方向で決める
  - ⚠ **曜日ルールや RRULE は #4373 で却下済みなので持ち出さない**（[[project_program-ics-shelved]]）
  - 契約変更だが **`.../episode/increment` を叩いているのは番組表エディタだけ**（capsicum は参照していない）。影響は WebUI と `docs/api.md` に閉じる

- **#4351 perf: media_catalog を zugoga で段階的に再有効化（size:M）** — 2026-08-13 にユーザー要望で繰り入れ。**「メディアカタログの作業を何かしら含めたい」**が起点で、partial index 適用 → 効果計測 → overlay の順に進める一歩目。後続は #4352（shallu / gomander へ横展開）・#4393（sub-second 化）

- **#4583 test/ci: harness ゲートの結果が「前に一度回したか」で変わる（size:M・2026-08-15 着地）** — `tagging_dictionary` が TTL 無しで Redis に居座る。**受け皿 5 件のうちこれだけ繰り入れた**のは、放置するとゲートの緑そのものが信用できなくなり、**次の回の判断材料が腐る**ため（2026-08-13 ユーザー確定）。詳細は下の「着地済み」節

- **#4589 bug: ALT 編集の PUT が `media_ids` / `spoiler_text` / `sensitive` を送らない（size:M・2026-08-15 着地・PR #4590）** — capsicum#121 の着手前に経路を通しで読んで見つけたもの。⚠ **Mastodon の `UpdateStatusService` は「送らなかったパラメータ」を現状維持ではなく「空で更新」として扱う**（コントローラの `update_options` がハッシュリテラルなので `options.key?` が常に true）。そのため ALT を 1 つ直すだけで**投稿から添付が全部外れ、CW と閲覧注意フラグが消える**
  - ⚠ **モロヘイヤ側だけ直しても届かない。**`ginseng-fediverse` の `flatten_media_attributes` が `status` と `media_attributes` しか通さないので、復元した 3 フィールドはリクエスト直前に捨てられる。pooza/ginseng-fediverse#245（1.8.27）と対で入れる（PR #4590 の Codex P1。**指摘が無ければ「直したのに直っていない」まま出ていた**）
  - ⚠ **必須パラメータは purpose ごとに違う。**`tag` は本文だけを送り直す経路で添付を持たない投稿にも来るので、`media_attributes` を一律必須にすると本文だけのタグ書き換えが 422 になる（同 Codex P2）
  - ⚠ **実害はまだ出ていない。**この経路を叩くクライアントが無く、capsicum#121 が着手前だったため。**先に塞ぐのが本件の趣旨**

- **#4594 bug: 画像アップロードの 401 がアラート抑止をすり抜ける（size:S・2026-08-20 着地・PR #4595）** — 2026-08-17 に
  キュアスタ！本番（gomander）で `POST /api/v1/media` の 401 が 25 分に 13 回、**すべて管理者へのアラートメール
  （＋ Discord ＋ Sentry）として飛んだ**。発生源は Tencent Cloud の分散 IP からのボットで、無効トークンのまま連打していた
  - ⚠ **モロヘイヤ側だけ読んでも辿り着けない**（#4589 と同型）。`ginseng-fediverse` の `MastodonService#upload` が上流の
    `GatewayError` を `ValidateError` に詰め替えていたため、`rescue Ginseng::GatewayError` に引っかからず
    `silent_statuses: [401]` に**一度も到達していなかった**。pooza/ginseng-fediverse#246 → #247（1.8.28）と対で入れる
  - ⚠ **同じ理由で 413 の分岐も死んでいた。**「アップロードしたファイルがサーバーの上限サイズを超過しています。」は
    **導入以来一度も出ていない**。クライアントに返るのも上流の 401 / 413 ではなく `ValidateError#status` の 422 だった
  - ⚠ **Issue は open のまま残している。**効いていることの確認は**本番へ出た後**にしか取れない
    （同じボットの 401 連打でアラートメールが飛ばず、syslog には残っていること）。5.34.0 デプロイ後に確認してクローズする
  - 回帰テストは 2 段。`gateway_error_transparency.rb` に 4 本（401 抑止 / 413 文言 / **5xx は鳴らす** /
    上流ステータス透過）と、**gem 境界の契約テスト** `test/unit/service/mastodon_upload_error_boundary.rb`。
    ⚠ **後者が無いと `bundle update` で黙って戻る**（前者は gem を通らない）
  - ボット自体の遮断はインフラ層（pooza/chubo2#118）。モロヘイヤ側は alert 条件だけを扱う

- **#4598 bug: `Idempotency-Key` が上流へ転送されず、再送が二重投稿になる（size:M）** — 2026-08-19 に
  `pooza/makoto2` の通しリハーサル（dev25）の相談から発見。`POST /api/:version/statuses`（プロキシ経路）と
  `POST /mulukhiya/webhook/:digest`（Slack 互換）の両方でヘッダが落ちる。⚠ **クライアントが正しくキーを付けていても
  モロヘイヤ経由では無効化される**ので、応答だけ失われたときの再送が投稿をもう 1 つ作る
  - ⚠ **転送は `Idempotency-Key` だけの許可リストで行う。**`@headers` の丸投げは `Host` / `Content-Length` /
    `Cookie` / `X-Mulukhiya` まで混ざる

- **#4599 feat: Slack 互換 webhook でリクエストごとの公開範囲を受け付ける（size:S）** — `Webhook#post` は既に
  「来れば尊重する」形なのに、`SlackWebhookPayload#values` が `visibility` を落としている。
  ⚠ **`Webhook#command` が出す curl サンプルには `visibility` が入っている**＝**効くように見えて効かない**状態

- **#4601 chore: RuboCop 設定と規約の正本を ginseng-style へ寄せる（size:S・2026-08-20 着地・PR #4602・Issue クローズ済み）** —
  新設した [pooza/ginseng-style](https://github.com/pooza/ginseng-style) を `inherit_gem` し、`.rubocop.yml` に残るのは
  `bin/diag` の除外・`TargetRubyVersion`・Sequel 系（正本が持たないプラグイン）だけになった。
  docs 側もコーディング規約・表記規約・重み定義を ginseng-style の `docs/` へ委譲
  - ⚠ **`Minitest/RefutePathExists` の固有緩和も落とした**（`b77dd308`）。これは**モロヘイヤ固有ではなく
    test-unit を使う全プロジェクト共通**の問題で（minitest は `assert_path_exists`、test-unit は `assert_path_exist` の単数形）、
    `rubocop-minitest` が**存在しないメソッドへ自動修正する 4 cop**（`AssertPathExists` / `RefutePathExists` /
    `AssertOutput` / `AssertSilent`）を正本側でまとめて無効化した（pooza/ginseng-style#11 / #12）
  - ⚠ **この申し送りは PR 本体のコメントに置かれていた**（投稿者は Codex ではなく `pooza`＝別セッション）。
    同期の初回で落としたので §4 に手順として足してある

- **#4616 chore/security: ginseng-core を更新し、ログのマスクが外れる穴を塞ぐ（size:S・2026-08-21 繰り入れ）** —
  ⚠⚠ **🔴 依頼（ginseng-core#518）より重かった。**「不正なバイト列でログ 1 行が消える」ではなく、
  `Logger#mask_url` の `ArgumentError` が `create_message` の rescue まで飛んで**素の src が返る＝
  `mask_fields` も `mask_query_params` も効かない**状態だった。⚠ **`Controller#before` は受信 params を
  そのまま `logger.info` に載せる**ので、**外から壊れたバイト列を 1 つ混ぜるだけでその行のマスクを外せる**
  ＝ #4511（[[project_log-credential-exposure]]）で塞いだものがこの経路で戻っていた
  - ⚠ **本番で開いている実害なので繰り入れた**（2026-08-21 ユーザー判断）。⚠ **cert タスク（#4617）と
    `max_bytes`（#4612）は同じ `bundle update` に乗るが、5.34.0 には含めない**
  - `bundle update ginseng-core` ＋ `Gemfile.lock` のコミット。⚠ **取り込み後に `Controller#before` 側の
    回避策を畳めるか見る**（gem 側で塞いだため）

⚠ **#4621 は 5.34.0 から外し、5.35.0 へ送った**（2026-08-22 ユーザー判断）。下の「5.35.0」節を参照。
5.34.0 に載るのは `bundle update ginseng-fediverse` 1.8.29 と Purpose ヘッダの件までで、
**ALT 編集は通らないまま**。⚠ **リリースノートで「ALT 編集が直った」と書かないこと。**

**確定スコープの重み合計は 24**（M 3 × 6 + S 1 × 6）。目安の 20〜25 の上寄りで、**これ以上の追加は次リリースへ送る**。
⚠ **メンテナンスリリースを連続させない**というユーザーの意向（2026-08-13）を受けて、**主軸をメディアカタログと番組表に置き、
検査由来の受け皿は #4583 の 1 本に絞った**。残り 4 件は次リリース以降へ送る。
なお #4589 / #4594 は**バグとして後から繰り入れた**（受け皿の枠ではない）。#4598 / #4599 / #4601 は 2026-08-18〜19 の追加。

### Codex レビューの棚卸し（2026-08-16）

**PR #4587 / #4588 の P2 を PR #4591 で消化した。**どちらも「直した機能が黙って効かなくなる」型で、5.34.0 のテーマそのもの。

- **#4583 (PR #4587) 署名が「畳む前」と「畳んだ後」で割れていた** — `RemoteDictionary.create` が `type` の既定値
  (`multi_field`) と旧称 (`relative` → `related`) を**プロセス共有の設定ハッシュへ直接埋めて**いた。
  `handler_config(:dics)` が返すのは設定の実体そのものなので、`refresh` する側（`fetch` 後＝畳んだ後）と
  起動直後の `load_cache`（畳む前）で指紋が食い違う。⚠ **`type` を省略した dic が 1 本でもあると、
  新しい Puma プロセスが毎回キャッシュを捨てて全辞書を同期取得する**＝ #4583 で TTL と署名を入れた意味が
  その分だけ失われていた。`type` の解決を非破壊の `RemoteDictionary.type` へ出し、署名は `canonical_sources`
  から取る。⚠ **dics の並び順は保つ**（取り込み順でもあるため、並べ替えは別物として扱う）
- **#4585 (PR #4588) 600ms の debounce 窓が書き込みの穴だった** — 窓の間は `busy[key]` がまだ立たないので、
  その隙に**編集フォームが開けて古い `next_on` を写し取り、保存で押したはずの ＋ を黙って書き戻す**。
  `isLocked`（実リクエスト中）と `isBusy`（＋ 保留分も含む書き込みバリア）に分け、日付 ＋ だけ `isLocked` を見る
  （ここまでバリアに含めると 1 クリック 1 往復へ戻る）。`openEdit` は保留分を先に送り切って再読込みを待つ

⚠ **`views/program.slim` は #4578 のため `rake lint` の対象外。**develop 版と slim-lint の結果を突き合わせて
新規指摘ゼロを確認した（既存の LineLength のみ）。

### 着地済み: #4583 タグ辞書キャッシュに署名と TTL を入れる（2026-08-15・PR #4587）

芯は 2 つあり、**実害が大きいのは 2 のほう**だった。

1. `tagging_dictionary` が **TTL 無しの素の SET** で、実行と実行のあいだで消えない
2. キャッシュが **「どの `dics` 設定から作られたか」を持たない**ので、別の設定で温めたキャッシュを次のプロセスがそのまま読む

`DictionaryTagHandlerTest#setup` は `dics` を 5 件（うち 1 件は `strict: true`）へ差し替えて `refresh` する。
その回のキャッシュが `RemoteTagHandler#search_remote_tags` の reject 3 条件
（`short?` / `local_tags.member?` / `strict_key?`）に効く。**3 条件とも同じ辞書を読んでいる。**

入れたもの:

- キャッシュ本体を `version` / `signature` / `generated_at` / `entries` の envelope に包む。署名は `dics` 設定の指紋で、署名違い・バージョン違い・旧形式は「無いもの」として作り直す
- `setex` で TTL（既定 3600 秒・`/handler/dictionary_tag/cache/ttl`）
- **全ソースが空を返した回は、生きているキャッシュを空へ潰さない。**⚠ `RemoteDictionary` のサブクラスは失敗を握って `{}` を返すので、**例外の有無では検出できない**（結果が空かどうかで判定する）。⚠ fail-open 自体は残す（#4573 と同じ理由）
- キャッシュ未充填で `alert` しない。TTL を入れた以上、失効は日常的に起きる
- `refresh` のたびに世代（`signature` / `generated_at` / `entries` / `ttl`）をログへ出す
- **スイートのロード時にキャッシュを捨てる**（`TestCase.invalidate_shared_caches`）。⚠ **「実走の前に手で `UNLINK` する」を手順書に書くだけでは弱い**（#4503 の教訓）

⚠ **回帰テストは `TaggingDictionaryCacheTest` として別クラスに置いた。**`Handler.create(:dictionary_tag)` が
Sequel のモデルを触るため、既存の `TaggingDictionaryTest` は **DB の無い環境でクラスごと omission** になり、
ゲートを守れない。キャッシュの世代・署名・TTL は辞書ソースの設定だけで決まるので、辞書ソースを返すだけの
ダブルを差し込んで常に実走させている。

⚠ **`RemoteTagHandlerTest` の `キュアスタ!` が 3 条件のどれで落ちているかは未特定のまま**（#4584 の担当）。
本件の着地で A/B の再現性が担保されたので、着手できる状態になった。

検証: `rake test` 978 → **988 tests / 0 failures / 0 errors / 313 omissions**（omissions は前後で不変・新規 10 件はすべて実走）。
`rake lint` 通過。CI は mastodon / misskey とも緑。

### 着地済み: #4585 「次回」を「話数 +1」と「日付 +1」に分離（2026-08-15・PR #4588）

| ボタン | 動き | エンドポイント |
| --- | --- | --- |
| 話数 ＋ | `episode` のみ +1（Annict のサブタイトル解決は従来どおり） | `POST .../episode/increment`（**日付を触らなくなった**） |
| 日付 ＋ | `next_on` のみ **+1 日** | `POST .../next_on/advance`（新設） |

`NEXT_ON_INTERVAL_DAYS = 7` は削除した（⚠ **7 を別名で残していない**）。
`increment_episode` から日付の前進が外れたので、**Annict が載らずに 200 が返ったときの巻き戻し量が半分**になる。

⚠ **`days` は 1〜366 の整数のみ・範囲外と非整数は 422。**素の `to_i` に倒すと `'abc'` が 0 日になり、
「押したのに進まない」理由が分からなくなる。**クライアント起因なので alert しない**（#4542 と同型）。

⚠ **WebUI は連打を 600ms で畳んで 1 リクエストにする**（`days` に日数を載せる）。1 クリック 1 リクエストだと
7 往復待たされたうえ #4534 のロックも 7 回取る。⚠ **`entry.next_on` の実体は触らない** ——
一覧の並びが `next_on` 昇順（#4540）なので、実体を進めると**連打の途中で行が動き、2 回目のクリックが別の行に当たる**。

⚠ **CI の omission baseline を 313→318 / 302→307 へ上げた。**ゲートを緩めたのではなく、
**CI で実行しようがないテストが 5 件増えた分**（`ProgramTest` は `livecure?` が false だとクラスごと omission になり、
CI には `var/program.yaml` も `/program/urls` も無いので常に false）。

⚠ **ローカルで `ProgramTest` を実走させるには `var/program.yaml` を一時的に置く**（無いと 40 件超がまるごと omission）。
これで見つかった**既存の赤 2 件**（本 PR 由来ではない）:

- `test_data_coerces_unquoted_yaml_timestamp` — `Time` が Redis キャッシュ往復で `"2026-08-08T23:30:00.000Z"` になる。**#4558 そのもの**（5.34.0 スコープ内・未着手）
- `test_auto_update_default_true` — `/program/auto_update` 未設定だと `auto_update?` が `ConfigError` を上げる（「既定 true」が実装されていない）。⚠ **既定値は `config/application.yaml` にあるので通常は踏まない**

`test_increment_episode_does_not_create_next_on` も develop で落ちていた（`coerce_scalars` が `next_on` を必ず
materialize するのでキーは常に存在する）。**値を見るアサーションへ直した**。

⚠ **`views/program.slim` は #4578 のため `rake lint` の対象外。**個別に `slim-lint` を掛けて確認すること。

### 着地済み（マイルストーン外）: デーモンの `/health` が「触れなかった」を「死んでいる」と断定しない（2026-08-15・PR #4592）

ginseng-core 1.17.0（pooza/ginseng-core#509 / #510 / #511）への追随。**3 件とも「例外を安全側でない値・順序に
読み替える」同型**で、Issue は立てずに gem 追随として直接入れた。

- `Process.alive?` は `Errno::EPERM`（プロセスは存在するが**シグナルを送る権限が無い**）でも false を返す。
  `listener_daemon.rb` / `sidekiq_daemon.rb` の `/health` はこれを `PID '...' was dead` と報告していた
  ＝ **原因を誤って伝えていた**。1.17.0 の `Process.alive_state`（`:alive` / `:dead` / `:unknown`）で分岐する
- ⚠ **`:unknown` も NG のままにする。**デーモンは `/health` を返すプロセスと同じユーザーで動くので、
  触れない＝ pid が再利用されて他人のプロセスになっている＝うちのデーモンは動いていない。
  **変えるのは「なぜ NG なのか」の説明だけ**（[[project_5310-release]] の `pgrep -f mulukhiya` の取りこぼしと同じ筋）
- gem を上げるだけで効く分に `Daemon#run_stop` の順序バグ（`remove_pid` → `Process.kill` だったため、`EPERM` で
  **プロセスは生きたまま pid ファイルだけ消え**、次の start が 2 本目を立てていた）が含まれる

### 5.34.0 の実装状況（2026-08-21 時点）

**スコープの実装は #4351（Gate 2 の flip）を除いて全て develop へマージ済み。**
**次にやるのはリリース前レビュー → ステージング検証。**

| PR | Issue | 主眼 |
| --- | --- | --- |
| #4620 | #4616 (S) | ginseng-core 1.19.0。壊れたバイト列でログのマスクが外れる穴を塞ぐ |
| #4605 | #4599 (S) | Slack 互換 webhook の公開範囲をリクエストごとに受ける |
| #4607 | #4558 (S) | `next_on` を「書いたとおりの日付」で読む |
| #4609 | #4573 (S) | リモート辞書の 200-with-HTML を黙って飲まない |
| #4610 | #4598 (M) | `Idempotency-Key` を上流へ中継する |
| #4611 | #4576 (M) | SSRF 掃討の取り残し 2 件 |
| #4613 | #4393 | media_catalog を LATERAL merge へ（#4351 Gate 2 の前提） |
| #4614 | #4351 | `/health` に接続プールの使用状況を出す |
| #4608 | #4606 | `inherit_mode` を足して継承した `Exclude` を取り戻す |

⚠ **Issue はどれも open のまま。**`Fixes #NNNN` を書いても **base が `develop` なので GitHub は閉じない**
（デフォルトブランチへのマージでしか閉じない）。リリース後に、モンキーテスト可否で分類して畳む。

判断が要った点（詳細は各 PR 本文）:

- **#4558 は Issue の推奨案では直らない。**⚠ **`Time` に materialize した後ではゾーンレスと明示
  オフセットを区別できない**（実測でどちらも `utc? == false` / `utc_offset == 32400` の同じ
  オブジェクト）。**AST 上で `next_on` を `YYYY-MM-DD` の String へ差し替える**方式にしたところ、
  項目 1（Redis 往復で無効値）も同時に消えた。⚠ 直すのは `format_date` ではなく `parse_yaml`
- **#4573 は Sentry へ escalation しない。**10 分周期なので `alert` に載せると 1 ソースあたり
  日 144 件のメール・Discord になる（#4594 と同型）。`logger.error` ＋ 世代ログの `empty_sources`
  で「何本中何本が死んでいるか」を 1 行で読めるようにし、判断は #4577 へコメントで残した
- **#4576 は pinning の段階適用を採らなかった。**Issue は「ナウプレのサムネイル取得にも効くので
  CDN が壊れうる」としていたが、⚠ **`Handler#upload` の呼び出し元は `WebhookImageHandler`
  1 本だけ**で、ナウプレ系は `upload_remote_resource` を通らないことを全呼び出し元の確認で裏取り
  した。**fedi-test-harness（Mastodon）実走で 1104 tests / 0 failures / 0 errors / 157 omissions**
- テストはすべて**両マトリクスで実走する場所**に置いた。⚠ `SlackWebhookPayloadTest`（Slack 未設定で
  omission）・`ProgramTest`（`livecure?` が false で omission）に相乗りしない
- **#4616 は gem 更新なので、判断が要ったのは「何を持ち込まないか」。**`bundle update` には
  timeout（#4593）・`max_bytes`（#4612）・cert タスク（#4617）・`format: uri` 厳格化も乗ってくるが、
  **こちら側の載せ替え作業は 5.34.0 でやらない**（2026-08-21 ユーザー判断）。⚠ **gem の挙動が変わることと、
  こちらが載せ替えることは別**として扱う
  - ⚠ **`ListenerTest#test_root_cert_file` の是正は退行対応ではなく、地雷が外れた分。**
    `Faye::WebSocket::SslVerifier` は値があると `cert_store.add_file` を呼ぶので**存在しないパスで落ちる**。
    旧 gem が `ENV['SSL_CERT_FILE']` に無い `cert/cacert.pem` を立てており、**Listener がそれを掴む
    唯一の経路**だった（#4586）。1.19.0 は立てないので nil ＝ システムの CA ストアに倒れる
- ⚠ **CI の omission baseline は 318 / 307 → 321 / 310 になった**（#4613）。ゲートを緩めたのではなく、
  **DB を持たない CI では `AttachmentTest` がクラスごと omission になる**ため、そこへ足した 3 件が
  そのまま乗る分。**それ以外の PR では baseline を動かしていない**

### #4351 / #4393 の決着（2026-08-20・zugoga 本番実測）

**sub-second 化は B 案（ローカルアカウント駆動の LATERAL merge）で決着し、PR #4613 で着地した。**
計測の全文は [#4323 のコメント](https://github.com/pooza/mulukhiya-toot-proxy/issues/4323#issuecomment-5349297730)。

| パターン | 現行 | 本実装 |
| --- | --- | --- |
| page1 | 26,415ms | **56.7ms** |
| only_person | 25,998ms | **6.5ms** |
| cursor | 23,234ms | **5.7ms** |
| rule つき | 8,900ms | **837ms** |
| rule ヒット無し | 2,244ms | **14.0ms** |

- ⚠ **現行のベースラインは劣化していた**（Gate 1 当時の「約 10s」→ 23〜26s）。「10s だから Gate 2 保留」の
  前提はさらに厳しい側に振れていた
- ⚠ **A 案は棄却。**速さ（1,593ms）ではなく、照合で **44 行の取りこぼし**が出たのが決め手
- ⚠ **フィルタは LATERAL の内側・内側 LIMIT は `limit + offset`。**本番でわざと誤り版を作って照合したところ
  **page2 で 14 行取りこぼした**。正しい版は page1 / only_person / rule / page2 とも差分 0 行
- **追加 index は不要**（Mastodon 本体の `index_media_attachments_on_account_id_and_status_id` で成立）。
  ローカルアカウントは **19 件**
- worker の DB 占有が **30 分ごと 150 秒 → 0.2 秒**。⚠ ここが 2026-05-19 の枯渇の温床だった

**Gate 2 の進め方（2026-08-20 ユーザー確定）**:

1. **順序は「5.34.0 リリース → zugoga デプロイ → flip」。**⚠ 新クエリはコードなので先行 flip はできない
2. **ステージング（dev26）を挟む。**⚠ ただし**性能検証ではなく機構の確認**
   （flip が効く・`/feed/media` が 200・worker がキャッシュを載せる・新規エラーが出ない）。
   ⚠ **dev26 で有意な性能計測はできない**（本番と桁違いでプランが変わる。[[feedback_staging-data-scarcity]]）
3. **rollback は `/health` の `postgres.pool.waiting` が 0 を超えた状態が数分続いたら**（overlay を false へ戻すだけ）。
   ⚠ `allocated` が `max` に張り付くのは正常なので、それを理由に戻さない
   - ⚠ **この指標は「Puma 1 プロセスの Sequel プール」しか見ていない**（2026-08-21 の Codex 指摘 ＝ #4618）。
     2026-05-19 に枯れたのは **pgbouncer（全プロセス・Mastodon 本体と共有）**で、重い SQL を流すのは
     別プロセスの Sidekiq。**flip 中は pgbouncer の `SHOW POOLS`（`cl_waiting`）も人が直接見る**
   - ⚠ **`/health` は `SELECT 1` の後にプールを読むので、有限のスパイクは取りこぼす。**
     「waiting が 0 だった」を「詰まらなかった」の証拠にしない

### 2026-08-20 セッション同期の記録

- **Sentry**: 未コメントの新規 3 件を精査した。
  - **MULUKHIYA-TOOT-PROXY-2K（UploadError 401・28 件）** — #4594 そのもの。PR #4595 が CI 緑で着地待ち
  - **MULUKHIYA-TOOT-PROXY-2J（Webhook not found・3 件・shallu）** — **#4603 として起票**。
    存在しない digest への `POST /webhook/:digest` が `e.alert` 固定で Sentry に上がる。
    ⚠ **同じ例外が `get '/:digest'` では `e.log` で静か**という非対称。#4542 / #4594 と同型
  - **MULUKHIYA-TOOT-PROXY-1X（CustomFeed command failed）** — 最新イベント（2026-08-18）も
    `server_name=mulukhiya` / `release=5.26.0` ＝ **姉妹サーバー管理人のモロヘイヤ**の系統で pooza 側の作業は無い。
    chubo2#41 系統（zugoga のデプロイで bundle install 未走）は 2026-07-17 を最後に静穏
- **Dependabot** 0 件。**Codex** は open / 直近マージ 25 本を横断してリアクション 0 の指摘ゼロ（[[feedback_codex-review-window-too-narrow]] の広めの窓で確認）
- ⚠ **同期の初回で PR #4602 の申し送りコメントを落とした。**`pulls/{number}/comments` は行コメントしか返さず、
  PR 本体のコメント（`issues/{number}/comments`）を見ていなかったため。**投稿者は Codex ではなく `pooza`**
  （ginseng-style 側を触っていた別セッションの申し送り）。§4 に手順として追記した。
  内容は「正本側 pooza/ginseng-style#11 / #12 で **test-unit に無いアサーションへ自動修正する 4 cop**
  （`AssertPathExists` / `RefutePathExists` / `AssertOutput` / `AssertSilent`）をまとめて無効化したので、
  モロヘイヤ側の `Minitest/RefutePathExists` の固有緩和は落とせる」。b77dd308 で消化（rubocop 471 files / no offenses）
- **chubo2** は差分なし。**Issue 棚卸し（§6-2）は最終 2026-07-31 で 30 日未経過**なのでスキップ（次回は 2026-08-30 以降）
- **harness の upstream チェック（§8）** — 下の「fedi-test-harness の検証状況」に反映

### 2026-08-21 セッション同期の記録

- **Mastodon 4.7.0 が stable リリース（2026-08-20）＝ 本番 3 台・ステージング 3 台へ適用済み（2026-08-21）。**
  インフラ側の記録は pooza/chubo2 の `docs/infra-history.md` / `docs/infra-note.md` が正本（[[project_mastodon-upgrade-runbook]]）。
  **モロヘイヤ側は同日に harness を stable で実走し、`verified` を v4.7.0 へ昇格した**（全緑）。
  下の「fedi-test-harness の検証状況」参照
- **Codex**: 前回同期の後に付いた **3 件**を消化（PR #4614 の P1 / P2、PR #4613 の P2）。いずれも妥当と判断し、
  返信 ＋ 👍 のうえ **#4618 / #4619 で受けた**。⚠ **どちらも「ゲートや rollback 信号が、見たいはずのものを
  取りこぼす」型**で 5.34.0 のテーマ（黙って壊れるのをやめる）そのもの
- **Sentry** 新規なし（最終確認 2026-08-18 の 3 件はいずれも 08-20 にトリアージ済み）。**Dependabot** 0 件
- **ginseng-core が動いた。**依頼していた 4 件（#518 / #514 / #526 / #528）と #512 が `main` へ着地し、
  **向こうから取り込み依頼が 2 本来ている（#4616 / #4617）**。⚠ `Gemfile.lock` の revision は
  `ab02f5e`（旧）のままで **`bundle update ginseng-core` は未実施**
- **chubo2** は差分なし（`git fetch` 済み・infra 側の 4.7.0 記録は取り込み済み）。
  **Issue 棚卸し（§6-2）は最終 2026-07-31 で 30 日未経過**なのでスキップ（次回は 2026-08-30 以降）
- **#4616 を 5.34.0 へ繰り入れた**（本番で開いている実害のため。#4617 / #4612 は次リリース以降）。
  重み合計 23 → 24
- **harness を v4.7.0 stable で実走し `verified` を昇格**（下の節）。⚠ **踏んだ罠は無し**
  （`update-version.sh` → `reset.sh` がそのまま通った。08-16 に踏んだポート 3000 衝突は
  pooza/chubo2#178 の修正が効いていて再発しなかった）

### 2026-08-22 セッション同期の記録

- **#4621（ALT 編集の PUT が 500）の原因を特定した。**⚠ **ステージング実機は要らない**（Rack の
  パース挙動で手元で再現できる）。`ginseng-fediverse` の `flatten_media_attributes` が
  `media_attributes[0][id]=...` と**数字の添字**で form-urlencode していたのが原因で、
  この形は Rack / Rails 側で **`fields_for` 形式の Hash `{"0" => {...}}`** に解釈され**配列にならない**。
  Mastodon の `UpdateStatusService` は `(@options[:media_attributes] || []).each` と回すので、
  Hash を each した `["0", {...}]`（Array）が渡り `attributes[:id]` で
  `TypeError: no implicit conversion of Symbol into Integer` ＝ 500
  - ⚠ **#245 は入っているのに崩れていた**＝ **#245 の平坦化そのものが誤り**。
    「gem 側の修正が着地した」は「正しく直っている」ではない
  - **pooza/ginseng-fediverse#253** を出した（form-urlencoded をやめて **JSON で送る**）。
    ⚠ **空添字 `media_attributes[][id]` でも配列にはなるが採らなかった**。「同じキーが再出現したら
    次の要素」という Rack の暗黙のグルーピングに依存し、要素ごとのキーの並びで壊れうるため
  - ⚠ **Content-Type の明示が要る。**ginseng-core の `create_body` は Content-Type が
    `application/json` のときだけ `to_json` する。無指定だと HTTParty が Hash を form-urlencode し、
    そこでも数字の添字（`HashConversions#to_params`）になって**同じ 500 に戻る**
  - **#253 は同日 03:26Z に着地し v1.8.29 としてリリース済み。PR #4622 で完結した**
    （`bundle update ginseng-fediverse` ＋ 内部 fetch と上流への PUT に `X-Mulukhiya-Purpose` を
    出さない ＋ **gem 境界の契約テスト**）
  - ⚠ **境界テストを別に置いた**（`test/unit/service/mastodon_status_update_boundary.rb`）。
    `alt_edit_body` は**モロヘイヤが組んだ Hash** しか見ないので gem 側が形を崩しても捕まえられない。
    #4589 / #4594 と同じ「`bundle update` で黙って戻る」類。**旧 revision へ戻すと 4 件とも落ちる**
    ことを確認済み
  - ⚠ **ステージング（dev24）での実地確認が未了。**capsicum と同じ PUT を投げて 200 と ALT 反映を
    見るところまでがクローズ条件
- **Codex** は open #4604 ＋直近マージ 8 本を横断して未消化ゼロ。**PR 本体コメントの申し送りも無し**。
  **Dependabot** 0 件
- **Sentry** 新規 1 件 **MULUKHIYA-TOOT-PROXY-2M**（`AnnictPollingWorker` の
  `RedisClient::CannotConnectError`・単発）をトリアージ。⚠ `server_name=instance-20220704-2044` /
  `release=5.31.0` ＝ **姉妹サーバー管理人（Oracle 無料枠）のモロヘイヤ**で pooza 本番 4 台ではない。
  Redis 再起動時の既知パターンで、#4543 の Redis 接続系の群に合流させた（コメント記録済み）
- **chubo2** は差分なし。**Issue 棚卸し（§6-2）は最終 2026-07-31 で 30 日未経過**なのでスキップ
  （次回は 2026-08-30 以降）。**harness の upstream チェック（§8）は `last_checked` 2026-08-21 で
  1 日**なのでスキップ（次回は 2026-08-25 以降）

#### ginseng-\* のピンのずれ（2026-08-22 判定）

⚠ **8 本すべてずれていたが、7 本は取り込まない（③ 見送り）。**次の同期で同じ調査をしないために残す。

- **ginseng-fediverse / piefed / postgres / redis / web / youtube** — 差分は **CI・RuboCop 設定・
  テスト土台のみ**で、モロヘイヤが触る面（`HTTP` / `Logger` / `Controller` / `TagContainer` /
  `Environment`）に当たらない → **③ 見送り**と判定した
- **ginseng-style** — docs 中心（`inherit_gem` の Include / Exclude が置換になる件・Codex 走査の
  ワンライナー是正・ブランチ規約）。lint の挙動しか変わらない → **② 次のマイルストーンで**
- ⚠ **③ / ② と判定した 6 本は、同日の「通常リリース手順」3.（`Gemfile.lock` のルーチン最新化・
  `57631310`）で結局すべて乗った。**差分は上のとおり読んだうえで無害と確認済みなので問題は無いが、
  **「見送り」判定はリリース前のルーチン更新までしか保たない**。判定するときはそのつもりで
  （`bundle update` 引数なしを避ける必要があるのは、**赤が出たときの切り分け**が要る取り込みだけ）
- **ginseng-fediverse は #253 の着地で 1.8.29（`0129fa5e`）へ、ginseng-core は v1.19.0（`4a029e9c`）へ**
  個別に取り込み済み
- **ginseng-core** — 当初は「`cert:*` の CA ストア検証・`run_stop` の pid・`cacert.pem` の週次 PR 化＝
  **#4617 の範囲**なので ② 次リリース以降」と判定した。⚠ **その後 v1.19.0（同日 03:49Z）が出て
  🔴 #527 が乗ったので ① へ切り替えた**（2026-08-22 ユーザー判断・PR #4622 に `57b73dc8` で取り込み済み）
  - 🔴 **#527 リダイレクト追従で別オリジンへ資格情報を渡していた** — `Authorization` / `Cookie` が
    リダイレクト先へそのまま送られ、初段の query / body も撃ち直されていた。
    ⚠ **`host_validator` では塞げない**（「公開ホストか」しか見ないので、**リダイレクト先が公開ホスト
    でありさえすれば通る**）。#4576 / #4524 で固めた SSRF 面と同じ層
  - ⚠ **モロヘイヤでの実害は小さい**（資格情報を付けて叩く先は自前の Mastodon / Misskey で、
    辞書・番組表・メディアの外部取得は `Authorization` を持たない）。**急ぐ理由としては使わない**
    （[[feedback_no-false-urgency]]）。取り込んだのは「`bundle update` 一発で、同じブランチで
    テストを回している最中だった」から
  - ⚠ **cert タスクの受け取り（#4617）は含めていない。**`Ginseng.load_tasks` と
    `cert/cacert.pem` をコミットするかの判断が要るため、次リリース以降のまま
  - ⚠ **v1.15.26 以降タグが打たれていなかった**ので v1.19.0 は 20 件まとめての回。
    **「リリースが出た」＝「差分が小さい」ではない**


### ステージング検証（2026-08-22・**4 台とも緑**）

`develop` の HEAD（`03efc95d`）を dev24 美食丼 / dev25 キュアスタ！ / dev26 デルムリン丼（Mastodon）/
dev27 ダイスキー（Misskey）へ適用。**4 台とも version 5.34.0・`/mulukhiya/api/health` 200
（redis / sidekiq / postgres / streaming / ruby すべて OK）・`yjit_enabled: true`・
WebUI 200（`/mulukhiya/` / `app/media` / `app/config` / `app/program`）**。

**再起動後の生存 pid が吐いたログに新規のエラー署名は無い**（dev24 / dev25 は 0 件）。
⚠ **dev26 / dev27 の 1 件は `/program.ics` を叩いた私の足跡**で、非 livecure サーバーの
期待動作（`raise NotFoundError unless livecure?` の log のみ）。**退行ではない。**

- **#4351 Gate 2 の前提が 4 台で見えた** — `/health` の `postgres.pool`
  （dev24 / 25 / 27 は `max: 10`、dev26 は `max: 16`）
- ⚠ **dev27 の `yjit_enabled` は `true`**（pooza/chubo2#123 の欠落は解消済み）

#### 実機で中身を 1 つ確認した（手順を通っただけで満足しない）

**#4616 の本丸＝「壊れたバイト列でマスクが外れない」を dev25 で確認し、Issue をクローズした。**

```json
{"request":{"method":"POST","path":"/mulukhiya/webhook/0000...","params":{
  "access_token":"[FILTERED]","i":"[FILTERED]","text":"[FILTERED]",
  "url":"https://example.com/?access_token=[FILTERED]&s=%3Fho"},
  "remote":"127.0.0.1"},"_encoding_error":true}
```

⚠ **`access_token` / `i` / クエリ内の token とも `[FILTERED]`**、壊れたバイト列だけが `%3Fho` へ、
`_encoding_error: true` つき、行全体が妥当な UTF-8。

- ⚠ **JSON ボディでは検証できない。**不正なバイト列を含むと `JSON.parse` が倒れ、
  `Controller#before` は Sinatra の `params`（JSON では空）へ倒れるので**ログに何も出ない**。
  **form-urlencoded で送ること**
- ⚠ **marker 文字列を grep で探す設計にしない。**`text` は `SCRUBBED_LOG_PARAMS` に入っており
  `[FILTERED]` になるので、**marker が出てこないのが正しい**（最初これで「ログが出ていない」と誤読した）

#### 検証できなかったもの

- ⚠ **#4623 / #4625（ALT 編集・`tag` purpose）は実地で確認できない。**上流 PUT が #4621 の 405 で
  届かないため。**5.35.0 で #4621 が直ってから、この 2 件も併せて実機確認する**
- ⚠ **dev26 は nginx が #4474 修正前のまま**（pooza/chubo2#188）。外部からの PUT が常に 405 で、
  vhost に `if ($http_x_mulukhiya_purpose != '')` も残っている。**dev26 で ALT 編集経路の
  実機確認を取らないこと**

### harness 実走ゲート（2026-08-22・**「新規の失敗ゼロ」で通過**）

両系を**別シェル**で実走（#4559 の取り違え対策。`controller=` と `url=` の両方で確認）。

| 系 | harness | 結果 |
| --- | --- | --- |
| Mastodon（v4.7.0） | `controller=mastodon url=http://localhost:3000` | **1184 tests / 2299 assertions / 1 failures / 0 errors / 159 omissions** |
| Misskey（2026.7.0） | `controller=misskey url=http://localhost:3001` | **1187 tests / 2289 assertions / 1 failures / 0 errors / 146 omissions** |

**失敗は両系とも `RemoteTagHandlerTest#test_handle_pre_toot` の 1 件だけ**＝ **#4584**。
⚠ **新規の失敗はゼロ**で、リリース前レビューの赤 4 件の是正による退行も無い。
**「新規の失敗ゼロ」で非ブロック化して通した**（2026-08-22 ユーザー判断。5.33.0 と同じ扱い）。

⚠ **ただし今回は放置で終わらせず、#4584 を 5.35.0 へ割り当てた**（同ユーザー判断）。
[[project_harness-zero-error-goal]] の「両系エラー 0」へ戻すため。

- omissions は参考値（2026-08-09 の 152 / 141）から 159 / 146 へ微増。**テスト総数が
  1001 → 1184 に増えている**ぶんの範囲で、前提が壊れて実行されなくなった類ではない
- ⚠ **実走中に出る `DB 接続に失敗したためスキップ: ... user "u"` は意図したテストの出力。**
  `test_apply_wires_info_token_and_postgres_dsn` が `postgres://u:p@...` という偽 DSN で
  失敗経路を検証している。ENV は `setup` / `teardown` で退避・復元されるので後続へ漏れない。
  **退行と読み違えないこと**
- ⚠ **判定基準の「既知例外は無い」は、この時点で実態と食い違っている**（docs/test-harness.md）。
  #4584 が着地したら記述を戻す

### リリース前 5 観点レビュー（2026-08-22 実施・赤 4 件を是正）

対象は `v5.33.0..develop`（64 コミット / 60 ファイル / +3648 -558）。**赤 4 件・黄 11 件・緑 6 件。**

⚠ **赤のうち 2 件は本リリースで入った退行だった。**レビューを回さなければ、
**#4589 と #4599 という「今回直したもの」自身が新しい穴を開けたまま出ていた**。

**赤 4 件は PR #4627 で是正**（Issue は #4623 / #4624 / #4625 / #4626）:

- **#4623 ALT 編集が「本文なし + CW あり」の投稿の本文を CW 文言で上書きする（🔴 退行）** —
  Mastodon の `update_immediate_attributes!` は本文が blank のとき
  `@options.delete(:spoiler_text)` を**本文へ昇格**させる。⚠ **そのとき `delete` されるので
  次の行の `key?(:spoiler_text)` が false になり CW も残る**（本文と CW に同じ文言が並ぶ）。
  本文が空なら `spoiler_text` を**キーごと送らない**ことで両立させた
- **#4624 webhook の未知 `visibility` が既定でなく `public` へ倒れる（🔴 退行）** —
  gem の `visibility_name` は未知の名前を **`public` へ丸める**ので、#4599 で足した素通しにより
  ⚠ **`private` 設定の webhook が綴り誤りや Misskey 語彙（`home`）ひとつで公開投稿**になった。
  ⚠ **判断を `visibility_for` へ寄せた**（`post` に式を残すと、配線を戻されても
  `requested_visibility` 単体のテストが緑のまま＝ #4583 / #4619 と同型）
- **#4625 `tag` purpose の PUT が添付・CW・閲覧注意・アンケートを消す** — **既存**。
  #4589 は ALT 編集側しか直していなかった。復元を `restored_body` へ括り出して両経路で共有。
  ⚠ **`status` だけは呼び出し側のものを使い、省略時は復元した本文へ倒す**（素朴に `.compact` すると
  本文まで空になる）。⚠ **`poll` も復元する**（`expires_in` は**残り秒数**。期限切れには触らない）
- **#4626 `MediaFile.download` が固定パスへ非アトミックに書く** — **既存**。URL の sha256 由来の
  固定名 ＋ `File.write` の O_TRUNC で、同一 URL の同時取得が**読み出し中のファイルを切り詰める**。
  一時ファイル ＋ `rename` へ（形は `ProgramFetcher#write_yaml` と同じ）

⚠ **既存の赤 2 件（#4625 / #4626）も 5.34.0 で直した**（2026-08-22 ユーザー判断）。
5.33.0 で #4576 を次リリースへ送ったのとは逆の判断で、**どちらも小さく、ステージング検証は
どうせ 1 回回すから**というのが理由。

**黄・緑は受け皿 8 件へ**（下の「マイルストーン未割当」）。

#### レビューの効き方について

⚠ **5 観点のうち赤を出したのは 3 観点で、観点ごとに別のものを捕まえた。**
セキュリティが #4624 / #4625、API 契約が #4623、並行性が #4626。
**スタイルと観測性は赤 0 件**（ただし黄・緑は両方から出た）。単一のレビューでは
**4 件のうち 1 件しか出なかった**ことになる。

⚠ **サブエージェントが作業ツリーの HEAD を detach させた。**観測性の担当が
`git checkout origin/develop` で過去版を読みに行き、その窓でこちらが積んだ 2 コミットが
detached HEAD 上に乗った。⚠ **`git push` は成功扱いになる**（動いていないブランチ ref を
押すだけ）ので「push 済み」と誤報告した。**レビュー指示には「git の状態も変えるな」を明記し、
過去版は `git show <rev>:<path>` で読ませること。**

### マイルストーン未割当

**5.33.0 のリリース前レビュー・harness ゲート由来の受け皿**（2026-08-12 起票）。
**#4583 だけ 5.34.0 へ繰り入れ、残り 4 件は次リリース以降へ送ることで確定**（2026-08-13 ユーザー判断）:

- **#4577 obs: 5.33.0 レビュー由来の観測性の穴 4 件（size:M）** — 番組表全滅が無音・ロック fail-open が不可視・Annict staleness が無音・Spotify の誤分類
- **#4578 test/ci: `rake lint` の slim-lint が `views/` 直下 16 本を一度も検査していない（size:S）** — dash に globstar が無いため。#4503 と同型の「守れているつもりの緑」
- **#4579 API 契約: 409 の「恒久／一過性」がクライアントから判別できない（size:M）** — 機械可読コード・`Retry-After`・increment の 3 通り
- **#4584 test: harness で `RemoteTagHandlerTest` の `キュアスタ!` タグが reject される（size:M）** — 両系で発生。**5.33.0 の退行ではない**（同一コミット連続実行で A/B 済み）。⚠ **3 つある reject 条件のどれが効いているかは未特定**。⚠ **#4583 を先に片付けないと A/B の再現性が担保できない**ので、5.34.0 で #4583 が着地してから着手する → **2026-08-15 に #4583 が着地したので着手可能**

その他:

- **#4543 obs: Sentry の未トリアージ unresolved 16 件を棚卸しする（size:M）** — `is:unresolved` 27 件のうち **16 件がコメント 0 のまま滞留**していた。§5 の手順は**新規イシューだけを見る**構造なので、手順が入る前の分がそのまま残っている。Redis 接続系 174 件 / 上流 4xx・5xx 100 件 / 単発 2 件の 3 群に分けて群ごとに判断する。上流 4xx 群には #4542 と同型（クライアント起因なのに alert）が混ざっている可能性が高い
- **#4603 obs: 存在しない digest への webhook POST が 404 なのに Sentry へ alert される（size:S）** — 2026-08-20 の
  セッション同期で Sentry から拾ったもの（MULUKHIYA-TOOT-PROXY-2J）。`post '/:digest'` の rescue が `e.alert` 固定。
  ⚠ **同じ `verify_webhook!` を通す `get '/:digest'` は `e.log`** で、GET と POST で扱いが割れている。
  #4543 の「上流 4xx 群に #4542 と同型が混ざっている」という見立てが、**上流由来ではなく自前の 404 で**当たった形
- **syslog 側のノイズ棚卸し（未起票）** — zugoga の `base_uri undefined` のように `e.log` 止まりで Sentry に出ない大量ログがある。#4543 の対象外なので別建てが要る
**5.34.0 のリリース前 5 観点レビュー由来の受け皿（2026-08-22 起票・黄 11 / 緑 6 を 8 本に集約）**:

- **#4628 obs: タグ辞書の観測性とキャッシュ運用の穴 5 件（size:M）** — ⚠ **全滅 alert が TTL 失効後は
  永久に沈黙する**（`discardable?` が `cache.present?` を見るため）／⚠ **Sidekiq が 1 時間落ちると
  失効し、投稿経路のサンダリングハードに化ける**（単一フライト無し）／`setex` 直後の読み戻し／
  世代ログの分母と分子が別勘定／`Marshal.load` が署名検証より先
- **#4629 obs: 番組表編集 4 本のクライアント起因 403/404 が `e.alert` に落ちる（size:S）** —
  ⚠ **#4594 / #4603 と同型が 3 系統目**。同じファイルの `handle_annict_write_error` が逆の方針を
  明記しているのに漏れている。共通ヘルパへ寄せるほうが再発しない
- **#4630 security: ログの秘匿の穴 2 件（size:S）** — ⚠ **`mask_url` は `\A` アンカー**なので
  **例外メッセージに埋めた URL は素通し**（5.34.0 で新設した 3 箇所）／`scrub_log_params` が
  **`blocks` / `attachments` の入れ子を素通し**＝ ⚠ **送り方で秘匿の効き方が変わる**
- **#4631 obs: ALT 編集の内部 fetch 失敗がクライアントの 404 に潰れる（size:S）** —
  ⚠ **ALT 編集が全ユーザーで壊れていても syslog 1 行しか出ない**。#4621 で切り分けを遅らせた構造
- **#4632 bug: `/media` のページ送りが境界で 1 件飛ばす（size:S）** — `limit + 1` を offset の
  基準にも使っている。⚠ **WebUI の無限スクロールでそのまま欠落する**
- **#4633 bug: webhook の添付が黙って落ちる 2 件（size:S）** — 上限超過が **200 のまま画像だけ無い
  投稿**になる／添付上限の check-then-act で **6 枚積んで 422**
- **#4634 docs: api.md の追随漏れと廃止語の残存 5 件（size:S）** — `/health` の `pool`／
  `Idempotency-Key` 節が PUT 経路と食い違う／`direct` の宛先／⚠ 廃止語「インスタンス」が
  ユーザー可視の 2 箇所
- **#4635 refactor/test: 構造改善 8 件（size:M）** — ⚠ **`forwarded_headers` のテストが自己充足**
  （ゲートを書き換えても緑）／`handler_config` を通さない唯一の箇所／`mastodon_type?` でなく
  文字列比較（#4566 で効く）／⚠ **`/health` が pid ファイル破損を OK と報告する**
  （`to_i` が 0 → `kill(0, 0)` が成功）ほか

**5.34.0 の Codex レビュー由来の受け皿（2026-08-21 起票）**:

- **#4618 obs: `/health` のプール指標が Puma プロセスローカルで、pgbouncer と Sidekiq 側の逼迫を取りこぼす（size:M）** —
  PR #4614 の Codex P1 / P2。⚠ **2026-05-19 に実際に枯れたのは pgbouncer（全プロセス・Mastodon 本体と共有）**で、
  重い SQL を流すのは別プロセスの `MediaCatalogUpdateWorker`。`/health` が読むのは**そのリクエストを処理した
  Puma プロセスの Sequel プール 1 つ**なので、どちらも直接は見えない
  - ⚠ **完全に盲目ではない**（pgbouncer が詰まれば滞留が延びて同プロセスの他スレッドが待つので `waiting` は
    遅れて上がる）。**症状の代理としては効くが、flip の影響を最初に検知するには遅い・粗い**
  - ⚠ **P2（`SELECT 1` の前にスナップショットを取る）は P1 と独立に入れられる。**現行は health 自身が
    待ち行列に並び、**前の待ちが捌けてから `num_waiting` を読む**ので有限のスパイクを取りこぼす
  - **Gate 2 は「`/health` の `waiting` ＋ flip 中は pgbouncer の `SHOW POOLS` を人が直接見る」で回す**
- **#4619 test: catalog の `only_person` subset 検証が truncate したベースラインと比較していて偽陽性になりうる（size:S）** —
  PR #4613 の Codex P2。`all_ids` は「絞り込み無しの最新 10 件」で母集合ではないため、⚠ **最新 10 件に Person 以外が
  1 件でも混ざると `only_person` 側はより古い Person で 10 件を埋め、SQL が正しいのに落ちる**。
  いま緑なのはデータの並びがたまたま Person で埋まっているからにすぎない（#4583 と同型）。
  ⚠ **DB を持たない CI ではクラスごと omission** なので、赤は harness 実走でしか出ない

**ginseng-core からの取り込み依頼（2026-08-20〜21・向こうが着地させた分）**。⚠ **`Gemfile.lock` は
まだ旧 revision（`ab02f5e`）で、`bundle update ginseng-core` は未実施**:

- **#4616 は 5.34.0 へ繰り入れた**（2026-08-21 ユーザー判断・上のスコープ節）。**本番で開いている実害**のため。
  ⚠ 併せて #514（`/http/timeout/seconds` が効いていなかった＝ #4593）・#526 / #534（`max_bytes` ＝ #4612）・
  #528 / #533（`host_validator` の使い回し）も `main` に入っており、**同じ `bundle update` に乗ってくる**。
  ⚠ **乗ってくることと、こちら側の載せ替え作業を 5.34.0 でやることは別**
- **#4617 chore: ginseng-core の cert タスクを受け取る（size:S）** — `cert:update` / `cert:check` を gem が配るようになった
  （`Ginseng.load_tasks` の 1 行）。#4586 の受け皿。⚠ **急がない**（上流側で「存在しないパスは `SSL_CERT_FILE` に
  立てない」が入ったので**現状は無害**）。⚠ **`cert/cacert.pem` をコミットするかは判断が要る**
  （向こうの推奨は「コミットせずデプロイ時に `rake cert:update`」＝更新の当番を増やさない）
- **#4612 security: `MediaFile.download` の受信バイト上限が「読み切ってから」しか効かない（size:S）** —
  #4576（PR #4611）の Codex P1 の受け皿。⚠ **gem 側の `max_bytes` が着地したので着手可能になった**
  （起票時は「gem 側の対応待ち」だった）。`bundle update` と同じサイクルで載せ替える

**設定検証・入口の堅牢化まわり（2026-08-15〜19 起票・いずれも未スコープ）**。⚠ **`ginseng-*` 側と対になっているものが多い**
（[[feedback_fix-may-not-reach-through-ginseng]]）。まとめて 1 サイクルにするか個別に散らすかは次期マイルストーン確定時に決める:

- **#4596 bug: config 検証の strict が構造的に発火しない（size:S）** — `Mulukhiya.validate_config` の `raise` を
  **同じメソッドの `rescue => e` が必ず受ける**（`ConfigError < Ginseng::Error < StandardError`）。
  ⚠ **`strict` を有効にしても起動は止まらない**＝守っているつもりの検証。[[feedback_fail-open-guard-footgun]] の実例
- **#4597 bug: schema の `format` が 1 つも検証していない（size:M）** — `uri` 以外（regex 6 / hostname 2 / email 1）は
  **json-schema 6 に検証実装が無く素通し**。⚠ **`validate_formats: true` を渡しても変わらない**（フラグの問題ではない）。
  ⚠ `config/schema/base.yaml` の `format: ^/` は **format 名ですらない**
- **#4600 bug: 不正な UTF-8 バイト列を含むリクエストが 500 + Sentry になる（size:M）** — 入口で 400 に落とす。
  ⚠ **`JSON.parse` は不正 UTF-8 を弾かない。**リクエストログが通り抜けているのは `SCRUBBED_LOG_PARAMS` で
  `[FILTERED]` に置換されるからで、**偶然の防波堤**。対は pooza/ginseng-core#518 / pooza/ginseng-fediverse#248
- **#4593 perf/bug: HTTP タイムアウトが未設定（size:S）** — `/http/timeout/seconds` が無く、`Ginseng::HTTP` 側も
  `get` / `post` / `put` / `delete` に `timeout:` を渡していない（pooza/ginseng-core#514）＝**両側とも未設定で実効 60 秒**。
  `retry.limit: 3` と合わせて最悪 180 秒級が**同期の投稿経路にぶら下がる**。⚠ **実測はまだ無い**（設定が効いていない事実の記録）。
  #4573 が「黙って空になる」なら、こちらは「黙って遅くなる」
- **#4586 bug: Listener の `root_cert_file` が `SSL_CERT_FILE` にフォールバックし、存在しないパスを渡しうる（security）** —
  対は pooza/ginseng-core#512（利用アプリに cert タスクが無い）・#515（cacert.pem に更新の当番が無い）

**ginseng-style（2026-08-19 新設）**。Ruby の書き方・テスト方針・表記規約・RuboCop 設定の正本を切り出した gem リポジトリ。
モロヘイヤ側の取り込みが #4601 / PR #4602。⚠ **今後「書き方」の指示が出たら正本は ginseng-style の `docs/`**。
⚠ **ginseng-\* 自体の残件はこのリポジトリの管轄外**（§6 のとおり専任セッションがある）。こちらは
`inherit_gem` の追随と、送った Issue / PR の結果待ちだけを持つ。

- **pooza/chubo2#166 ops: sweep の unattended-upgrades が itamae 管理外** — 2026-08-12 06:40 に systemd 更新の巻き添えで `redis-server` が再起動し、Sidekiq が Sentry へ 8 イベント（一過性・復旧済み・triage コメント済み）。⚠ **sweep は「再起動で PG が上がらない地雷」を抱えているのに `postgresql-16` が自動更新の射程内**なのが本題。モロヘイヤ側の作業は無い

### fedi-test-harness の検証状況

**Mastodon v4.7.1 stable を 2026-09-02 に実走・`verified` 昇格**（⚠⚠ **GHSA 3 件のセキュリティリリース**。
本番・ステージング 6 台への適用はユーザーが同日に完了済みで、harness 検証は 07-28 の 4.6.4 と同じく後追い）。
**1291 tests / 2490 assertions / 0 failures / 0 errors / 159 omissions（100% passed、391 秒）**。

- **DB 直読み層は個別にも実走**: account 34 / status 27 / postgres 11 は **omission 0 で全緑**、
  attachment は 21 tests / **2 omissions**（既知・pooza/chubo2#64）
- ⚠ **omission 159 件は v4.7.0 と同数。**tests が 1156 → 1291 に増えたのは 5.36.0 開発中だからで、
  **Mastodon 版の影響と読まない**
- **4.7.0 → 4.7.1 はモロヘイヤの面に当たらない**（59 files / 10 commits）。admin 系 15 コントローラ＋
  新設 `Admin::PermissionsConcern`（⚠ **モロヘイヤは Mastodon の admin API を 1 本も叩かない**）／
  `json_ld_helper` と `ProcessActivityService` ＝ AP 受信側／認証まわり。
  ⚠⚠ **マイグレーションの追加は無く、変更された 2 本は冪等化＝適用済み DB では no-op。
  スキーマもシリアライザも 4.7.0 から不変**

以下は 1 つ前の昇格（v4.7.0）の記録。
**Mastodon v4.7.0 stable を 2026-08-21 に実走・`verified` 昇格**（本番 3 台・ステージング 3 台への適用と同日。
**本番と検証済み版が揃った**）。**1156 tests / 2250 assertions / 0 failures / 0 errors / 159 omissions
（100% passed、332 秒）**。

- **DB 直読み層は個別にも実走**: account 34 / status 27 / postgres 10 は **omission 0 で全緑**、
  attachment は 20 tests / 0 failures / **2 omissions**
- ⚠ **attachment の omission 2 件を 4.7 の影響と読まない。**#4613 で足したページ送りのテストが
  **ページ 2 を作れるだけの media を harness が seed していない**ため（pooza/chubo2#64）。
  08-16 の「attachment 17 tests / omission 0」との差は**モロヘイヤ側でテストが増えた分**
- ⚠ **rc.1 → stable の差分は harness の観点では空だった**（49 files / 24 commits・**マイグレーションなし・
  DB スキーマ変更なし・シリアライザ変更なし**。Ruby 側は `ActivityPub::ProcessAccountService` +3-1 と
  admin 系の文言のみ）。**見込みで昇格させず回し直した結果、08-16 の rc.1 全緑がそのまま再現した**
- Misskey は stable 2026.7.0 据え置き。2026.8.0-alpha.0 は prerelease なので**方針どおり動かない**。
  ⚠ **今回は Mastodon 側だけの実走**なので、[[project_harness-zero-error-goal]]（両系エラー 0）の
  未達（#4584）は解消していない

**Mastodon v4.7.0-rc.1 を 2026-08-16 に実走済み**（RC なので `verified` は昇格させない）。
**1086 tests / 2157 assertions / 0 failures / 0 errors / 157 omissions（100% passed）**、
DB 直読み層（account / status / attachment / postgres）も **omission 0 で全緑**。
4.6.6 → 4.7.0-rc.1 でモロヘイヤに当たりうる 3 点（`accounts.uri` の nullable 化 + UNIQUE 張り替え、
`account_summaries` の実テーブル化、`AccountSerializer` の `pretty_username`）は**実コードでもすべて空振り**。
⚠ **`statuses` テーブルは 4.6.6 から無変更**（nullable になるのは `keypairs.uri`）。
⚠ **tests / omissions の増減を Mastodon 版の影響と読まない**（母数はモロヘイヤ側の開発で動く）。詳細は台帳の 2026-08-16 節。
⚠ **ポート 3000 の衝突と、失敗した proxy コンテナが `exited` で残って `up -d` を繰り返しても復旧しない罠**を踏んだ
（`docker compose rm -sf proxy` で解決）。pooza/chubo2#178 で修正済み＝**両ハーネスの同時起動が可能になった**（[test-harness.md](test-harness.md)）。

以下は現 `verified` の記録。**Mastodon v4.6.6 を 2026-08-14 に検証・verified 昇格**（pooza/chubo2#169 でピンも bump）。
**本番 3 台・ステージング 3 台へは 2026-08-14 にユーザーが適用済み**で、harness 検証は後追い。
実走は **1050 tests / 2101 assertions / 0 failures / 0 errors / 152 omissions（100% passed）**＝退行ゼロ
（omission は v4.6.5 と同数）。⚠ **実走前に `redis-cli -n 1 UNLINK tagging_dictionary` を踏んでいる**（#4583。**2026-08-15 着地済みなので次回以降は不要**）。
4.6.5 → 4.6.6 は **マイグレーション無し・依存無変更・シリアライザ無変更**で、モロヘイヤが叩く REST にも
直読みするスキーマにも掛からない。⚠ **harness の `update-version.sh` がシークレット無しの `.env` を作る不具合**
（後続の `setup.sh` が `db:prepare` で落ちる）を踏んだ。pooza/chubo2#168 として修正済み。

以下は 1 つ前の昇格（v4.6.5）の記録。**Mastodon v4.6.5 を 2026-08-09 に検証・verified 昇格**（pooza/chubo2#153 クローズ）。同一の mulukhiya HEAD を v4.6.5 / v4.6.4 でクリーン再構築して実走・比較し、**失敗集合の一致＝退行ゼロ**を確認した（1001 tests / 0 errors、両版で omission 完全一致）。詳細は [harness-verified-versions.yaml](harness-verified-versions.yaml) の 2026-08-09 節。

⚠ **07-30 の 879 tests / 0 failures とは比較にならない。** #4503 の可視化と harness のトークン供給で実行本数が増え、これまで走っていなかったテストが初めてアサートしている。**「前回 0 failures だったのに増えた」を退行と読まないこと。**上記 5 件の解消で Mastodon 側は再び 0 failures / 0 errors になり、**#4492 の解消で Misskey 側も 0 failures / 0 errors**（1004 tests / 141 omissions）。両系エラー 0 の目標を一度達成した。

⚠ **2026-08-12 の再実走で Misskey 側が 1 failures に戻っている**（`RemoteTagHandlerTest`・#4584）。**5.33.0 の退行ではない**ことは同一コミットの連続実行で確かめてあり、「新規の失敗ゼロ」でリリースを通した。`project_harness-zero-error-goal` は**未達に戻った状態**なので、#4584 / #4583 を消化するまで「両系エラー 0」と書かないこと。

### マイルストーン外の繰越（着手条件待ち）

- **#4414 security: Spotify OAuth ハードニング（size:M）** — capsicum#570 復活と歩調を合わせる（全台 OFF のため単独では着手しない）
- **#4428 test: fedi-test-harness で webhook 投稿経路をインプロセス検証する（size:M）** — chubo2#63 と対。chubo2 側の着地待ち

## リリース済み: 5.33.0（2026-08-12）

**土台テーマは「テストが実際に走っていない」の解消**で、#4503 → #4508 → #4492 の順に消化して完了した（5.32.0 から丸ごと繰り越し）。
そこへ #4524（SSRF の DNS リバインディング）・#4534（番組表の書き込みロック）・#4549 / #4559 / #4560 / #4567 が乗った回。
依存する ginseng-core は 1.15.34 → **1.16.2**（pooza/ginseng-core#499 / #503）。GitHub マイルストーンは #631。

**本番デプロイ: 4 台完了**（2026-08-12、shallu → zugoga → gomander → sweep の順。
全台 version 5.33.0 / health 200（全サブシステム OK）/ `yjit_enabled: true` / Ruby 4.0.6 据え置き）。
**5.32.1 が zugoga 限定だったことによるバージョンの不揃いは、これで解消した。**
⚠ **ただしこの不揃いを「だからリリースを急ぐべき」の根拠に使わないこと**（2026-08-12 ユーザー明示: 「不揃いは特に気にしていません」）。
揃っていない状態そのものに実害は無い。**急ぐ理由が要るときは実害のあるものを挙げる。**

デプロイで踏んだこと 3 件:

- ⚠ **`BUNDLED WITH` が 4.0.17 → 4.0.18 に上がっていた。**4 台とも `bundle install` の前に `gem install bundler -v 4.0.18` を明示した。
  ステージングで踏んだ罠（[[project_staging-app-deploy-runbook]]）が本番でもそのまま出る。**`bundle update` を含む回は毎回この確認が要る**
- ⚠ **`pgrep -f mulukhiya` では listener が漏れる。**プロセス名は `ruby: bin/listener_daemon.rb start` で `mulukhiya` を含まない。
  「生存 pid が吐いたログだけを見る」検証をこれでやると、**listener を素通ししたまま「エラー 0」と言える**。`pgrep -f "mulukhiya|listener_daemon"` で取ること
- sweep で `rbenv: cannot rehash: ~/.rbenv/shims/.rbenv-shim exists` が出た。**2026-07-09 に中断した rehash の置き土産**で他 3 台には無い。
  退避して `rbenv rehash` で解消（shim 46 本のまま）。⚠ **その直後の `bundle --version` が 2.6.9 に見えるのは正常**
  （sweep は `rbenv global = system`。リポジトリ内では `.ruby-version` により 4.0.6 + bundler 4.0.18 が選ばれる）

**本番でも実機確認を取った**（デプロイ手順を通っただけで満足しない）:

```text
--- #4574 ゼロアドレス（shallu） ---
  0.0.0.0              internal=true
  ::                   internal=true
  64:ff9b:1::7f00:1    internal=true
  255.255.255.255      internal=true
  100.64.0.1           internal=true
  公開 8.8.8.8               internal=false
  公開 2001:4860:4860::8888  internal=false
--- #4575 setnx（shallu・テスト用キー。実キー program には触れない） ---
  1st=true 2nd=false value="v1"
```

⚠ **新設した予約レンジが正当な宛先を巻き込んでいないことも確かめた**（4 台とも `Rejected host` が 0 件）。
再起動後の生存 3 プロセスが吐いたログにエラーは 4 台とも 0 行（shallu 255 行 / zugoga 213 行 / gomander 244 行 / sweep 138 行 中）。
`/mulukhiya/`・`/mulukhiya/app/program`・`/mulukhiya/api/program.ics` も 4 台とも 200。

**リリース時点の実測**: `rake test` **975 tests / 1335 assertions / 0 failures / 0 errors / 313 omissions**。
5.33.0 でテストは 954 → 975 に増えたが **omission は 313 のまま**（新規 21 件はすべて実際に走っている）なので、
CI の `omission_baseline`（mastodon 313 / misskey 302）は据え置きでよい。

### リリース前 5 観点レビュー（2026-08-12 実施・赤 2 件を是正）

5 観点を独立したサブエージェントで並列に走らせ、指摘を合流させた。**重複を畳んで実質の赤は 4 件。**
⚠ **セキュリティ観点と観測性観点が独立に同じ 2 件へ到達**した（ゼロアドレス・キャッシュ温めの競合）。裏付けとしては強い部類。

| 観点 | 赤 | 黄 | 緑 |
| --- | --- | --- | --- |
| セキュリティ | 3 | 1 | 3 |
| 並行性・ライフサイクル | 1 | 2 | 4 |
| エラー処理・観測性 | 1 | 5 | 2 |
| API 契約 | 1 | 2 | 3 |
| スタイル・規約 | 0 | 3 | 3 |

**本リリースで対応した赤 2 件**（どちらも今回の新規コード自身の穴）:

- **#4574 内部アドレス判定がゼロアドレスを素通り**（PR #4580）— `private? / loopback? / link_local?` は `0.0.0.0` と `::` にすべて false を返す。**実測で `Net::HTTP#ipaddr = "0.0.0.0"` がループバックの待受へ 200 で到達**。⚠ **ブラインドではない**（各ホップの失敗が `errors` に積まれ `reportable?` が必ず true を返すので、`Connection refused` と `Bad response NNN` の差が投稿者へ戻る＝結果の見える内部ポートスキャン）。⚠ **#4524 が作った穴ではない**（v5.32.1 の `public?` も同じ 3 述語）。#4524 が変えたのは pinning で決定的な経路になった点で、**述語を書き直したのが 5.33.0 だから塞ぐならこのリリース**
  - Codex P1（マージ前）で **RFC 8215 の local-use NAT64 prefix `64:ff9b:1::/48`** の漏れを指摘され取り込んだ。RFC 6146 の well-known prefix `64:ff9b::/96` とは**別レンジ**。⚠ この Issue 自体が「NAT64 のある環境で顕在化しうる」を理由にレンジを足しているので、片方だけ塞ぐのは筋が通らない
- **#4575 読み経路のキャッシュ温めがロックの外**（PR #4581）— `load_from_yaml` が**読み経路のまま無条件 SET** を撃つ。**#4534 は書き手同士を直列化したが、書き手 × 読み手が残っていた**（「塞いだつもりで開いていた」の 4 度目）。`program` キャッシュに TTL が無く `load` はキャッシュを優先するので、以降すべての面が旧データを返し、次の編集が YAML まで巻き戻す。⚠ **窓はミリ秒ではない**（Redis 再起動直後は死んだソケットを掴んだ最初の 1 コマンドが必ず例外になり、リトライで 1 秒以上眠る＝**デプロイ直後の編集がいちばん危ない**）。読み経路だけ `SET NX` に分けた。⚠ **読み経路をロックに載せる方向は採らない**（読みは書きより桁違いに多く 409 が跳ね上がる）

**既存の赤 2 件は別建て（#4576・5.34.0）**。`is_cat` の webfinger が無検証（リダイレクト未検証 + pinning 無し）と、webhook の `image_url` が **full-read SSRF**。⚠ **5.33.0 に積まなかった**のは、修正が全画像ハンドラと webfinger 経路に及び、**CDN への pinning は「複数 A レコードのフォールバックが効かない」既知のトレードオフを広い面へ適用する**ことになるため（harness 実走込みの独立サイクルが要る＝2026-08-12 ユーザー判断）。

**黄・緑の受け皿は用途別に 3 本**: #4577（観測性 4 件）／ #4578（`views/*.slim` 16 本が未 lint）／ #4579（409 の恒久・一過性が判別できない）。

#### ⚠ サブエージェントの報告をコードで検証せずに写して、危険な docs を書いた

api.md に「Annict の staleness で載らなかったときは**再実行すれば解決する**」と書いたが、**従うとデータがずれる**（PR #4582 の Codex P1 で発覚、`20c872de` で是正）。

`increment_episode` のロック内は **①話数 +1 → ②`annict_episode_id` を nil → ③`next_on` を 7 日前進 → ④`annict_applicable?` の判定 → ⑤`save`（無条件）** の順で、**ガードが閉じるのは ④ の「Annict メタデータを載せるか」だけ**。増分そのものは成功して保存済みなので、再実行すると**話数を飛ばして日付が 7 日ずれる**。正しくは `PUT /admin/program/entry/:key` で補う。

**赤 4 件は実コードと実測で裏を取ったのに、黄 1 件を素通しした。**サブエージェントの結論は額面どおり受け取らない、が観点ごとに緩まないようにする。同じ誤りを写していた #4579 / #4577 にも訂正コメントを入れてある。

### ステージング検証・2 回目（2026-08-12・レビュー是正後・**4 台とも緑**）

赤 2 件の是正を含む `dd85ee7b` を dev24-27 へ再適用。**4 台とも version 5.33.0・health 200（全サブシステム OK）・
WebUI 200・番組表エディタ 200**。⚠ **再起動後のプロセスが吐いたログに新しいエラー署名は無い**
（生存 pid で絞って確認。残るのは GAS の HEAD 403 と #4573 の辞書エラーで、いずれも既存事象）。

**是正 2 件が実機で効いていることを dev25 で直接確認した**（手順を通っただけで満足しない）:

```text
--- #4574 ゼロアドレス ---
  0.0.0.0              internal=true
  ::                   internal=true
  64:ff9b:1::7f00:1    internal=true
  公開: 8.8.8.8 internal=false
--- #4575 setnx ---
  1st=true 2nd=false value="v1"
```

### ⚠ 旧: ステージング検証・1 回目（2026-08-12・4 台とも緑・**レビュー是正前の記録**）

`develop` の HEAD（`640ee959`）を dev24 美食丼 / dev25 キュアスタ！ / dev26 デルムリン丼（Mastodon）/ dev27 ダイスキー（Misskey）へ適用。
**4 台とも version 5.33.0・`/mulukhiya/api/health` 200（redis / sidekiq / postgres / streaming すべて OK）・WebUI 200**、
番組表エディタ（`/mulukhiya/app/program`）と `.ics`（`/mulukhiya/api/program.ics`）も 200。
**再起動後のプロセスが吐いたログにエラーは 1 行も無い**（生存 pid で grep して確認。再起動前の pid が吐いた辞書取得エラーは 5.32.0 時点からの既存事象）。

- ⚠ **`Gemfile.lock` の `BUNDLED WITH` が 4.0.18 に上がっている**（`640ee959`）のに 4 台の bundler は 4.0.17 だった。
  **FreeBSD では bundler の自己インストール → 再 exec が `/bin/sh` へフォールバックして落ちる**（[[project_staging-app-deploy-runbook]] の既知の罠）ので、
  `bundle install` の前に `gem install bundler -v 4.0.18` を明示した。**`bundle update` を含む回のデプロイでは毎回この確認が要る**
- ⚠ **ssh 越しに `service mulukhiya-listener restart` を素で叩くとセッションが返ってこない**。
  デーモンが ssh の stdout を握ったままになるため。`</dev/null >/dev/null 2>&1` を付けること（health は別セッションから叩けば確認できる）
- dev24-26 は monit が `/mulukhiya/api/health` を 3 サイクル監視して 3 サービスを再起動する構成なので、
  デプロイ中は `monit unmonitor mulukhiya` → 完了後 `monit monitor mulukhiya` で挟んだ。⚠ **`monit monitor` の反映は次サイクル**（直後の summary は `monitor pending` と出る）
- dev27 の `yjit_enabled: false` は既知の欠落（pooza/chubo2#123）で退行ではない。dev24-26 は `yjit_enabled: true`

**モンキーテスト待ち**: #4534（番組表の書き込みロック）と #4560（`warn` の JSON 化・マスキング）は
ステージングで目視できるためクローズせず開けてある。確認項目は各 Issue のコメントが正本。

### harness 実走ゲート（2026-08-12 再実走・**「新規の失敗ゼロ」で非ブロック化**）

レビュー是正後の HEAD（`2c69bb31`）で両系を再実走。**両系 0 failures は満たせていない**が、
**#4508 の前例（「既知集合と完全一致 = 新規の失敗ゼロ」で通す）に倣って非ブロック化した**（2026-08-12 ユーザー判断）。

| 系 | 結果 |
| --- | --- |
| Mastodon（`tagging_dictionary` 空） | **1050 tests / 0 failures / 0 errors** / 152 omissions |
| Mastodon（キャッシュ温） | 1050 tests / 1 failures（`RemoteTagHandlerTest`） |
| Misskey（キャッシュ空・3 回） | 1053 tests / **1 failures**（`RemoteTagHandlerTest`）/ 0 errors / 141 omissions |

**非ブロック化の根拠は A/B。**`tagging_dictionary` をクリアしたうえで**同一コミットを連続実行**して比較し、
是正前 HEAD（`640ee959`）でも Misskey 2/2 で同じく落ちることを確認した（現行は 3/3）。**新規の失敗ではない。**
受け皿は **#4584**（`キュアスタ!` が reject される・原因未特定）。

#### ⚠ この日踏んだ落とし穴 2 つ（#4583 / #4584 として起票）

- **`tagging_dictionary` が TTL 無し（実測 `TTL` = -1）で Redis に居座り、実行をまたいでもコミットを切り替えても残る。**
  **ゲートの結果が「前に一度回したか」で変わる**（同一コミット・同一 harness で 0 failures → 1 failures）。
  当面は **実走の前に `redis-cli -n 1 UNLINK tagging_dictionary`** を踏む。#4503 / #4559 と同じ「守れているつもりの緑」型 → **#4583**
  （⚠ **2026-08-15 着地。以降この手作業は不要**でスイートのロード時に自動で捨てる）
- ⚠ **A/B はコミットを交互に変えるだけでは足りない。**`DictionaryTagHandlerTest` を「5.33.0 の退行」と判断しかけた。
  交互に 4 回回すと 2→1→2→1 ときれいに再現したが、**同一コミットを 2 回続けて**回すと 2→1 と揺れた。
  **run 単位の状態依存とコミット差は、同一コミットの連続実行を入れないと区別できない。**

### ⚠ 旧: harness 実走ゲート（2026-08-11・両系緑で通過・**レビュー是正前の記録**）

同一 HEAD（`develop` = #4572 マージ後）で両系を実走。**判定基準（両系 0 failures / 0 errors、`TestHarness: controller=` が狙った系と一致）をいずれも満たす。**

| 系 | 結果 | announce |
| --- | --- | --- |
| Mastodon（harness v4.6.5） | **1042 tests / 2079 assertions / 0 failures / 0 errors / 152 omissions** | `controller=mastodon url=http://localhost:3000` |
| Misskey（harness 2026.7.0） | **1045 tests / 2112 assertions / 0 failures / 0 errors / 141 omissions** | `controller=misskey url=http://localhost:3000` |

omission は両系とも 2026-08-09 の参考値（152 / 141）と**完全一致**。tests が参考値（1001 / 1004）より増えているのは #4534 系列で 16 件足したぶんとシード差。上流バージョンの昇格は伴わないので台帳（harness-verified-versions.yaml）は据え置き。

#### ⚠ この日踏んだ落とし穴 3 つ（次回も踏む）

- **両ハーネスは同時に起動できない。**Misskey ハーネスも `MISSKEY_PORT=3000` で Mastodon と衝突する。**片方を `teardown.sh` してからもう片方を `setup.sh`**（`setup.sh` は 1 系あたり 8〜9 分）。⚠ **`url=` は両系とも `localhost:3000` なので取り違えの判別に使えない。`controller=` の側を見ること**（#4559 のドキュメント例にある `:3001` は実態と違う）
- ⚠ **系の分離に `env -i` を使うなら `LANG` を残す。**落とすと Ruby の外部エンコーディングが US-ASCII になり、**製品と無関係な `invalid byte sequence in US-ASCII` が 6 件（1 failures / 5 errors）出る**。退行と読み違えかけた。`env -i HOME PATH TERM LANG LC_ALL` で足りる（`MASTODON_count=0` を実走前に出して分離も確かめた）
- ⚠ **Mastodon 実走中に出る `TestHarness: DB 接続に失敗したためスキップ: ... password authentication failed for user "u"` は正常。**`TestHarnessTest` が配線を検証するために**わざと偽 DSN（`postgres://u:p@…`）を差している**もので、環境の不備ではない。DB 依存テストは実際に走っている（omission が 313 → 152 に減っているのが証拠）

### 着地済み: #4534 番組表の書き込みが無ロックの read-modify-write（2026-08-11）

**5.32.0 で意図的に見送っていた最後の実装項目。**「実況が使う書き込み経路そのものにロックを入れる変更」なので、ニチアサ（次は 08-16）まで runway のあるタイミングで入れた。

- `ProgramLockStorage` を新設。`ComposeTemplateLockStorage`（#4457 / #4460）と同型（`SET NX EX` + compare-and-delete + fail-open、TTL は**定数** 30 秒）。番組表はインスタンスに 1 つなので key も 1 つ
- 編集 4 メソッドは `lock.synchronize` の内側で `fetcher.save` を直接呼ぶ。⚠ **公開 `save` 経由にすると自分のロックと衝突する**
- **`save` もロックに載せた。**auto_update の pull（`ProgramUpdateWorker`）とエディタの編集は同じ YAML / Redis を触るので、別ロックにすると交差する
- `ProgramUpdateWorker` は競合を **alert に上げず**次の周回へ送る（every 1m で追いつく。直列化が意図どおり働いた結果を毎分 Sentry に流すのは #4542 と同型）
- ⚠ **ロックの正テストを `ProgramTest` に置かなかった。**あちらの `disable?` は `livecure?`（`var/program.yaml` が在るか `/program/urls` が設定されているか）で丸ごと倒れるので、番組表を持たない環境では**一度も走らない**（#4549 で `absolute_uri` をクラスメソッドへ出したのと同じ理由）。`ProgramWriteLockTest` として独立させた
  - ⚠ **例外クラスだけでなくメッセージまで見る。**`auto_update` の 409 も `ConflictError` なので、クラスだけだと**ロックが無くても緑になる**
  - ⚠ このテストは書き込みを 1 つも成功させない（全ケースがロック獲得の時点で倒れる）ので、`var/program.yaml` も Redis も触らない

#### ⚠ 初版は Annict をロックの内側に置いていた（同日中に是正・PR #4571）

**「話数の +1 とサブタイトルの解決は不可分だから」という理由で内側に置いたのは誤り**だった（PR #4569 の Codex P2）。

- `/service/annict/timeout: 5` は **open と read の双方**に効くので、3 回で素直に **TTL(30 秒) に届く**。ロックが先に失効すると別の編集が獲得でき、そこへ元のリクエストが書き戻して**塞いだはずの lost update がそのまま戻る**
- ⚠ **TTL を伸ばす手は採らない。**プロセスが死んだときに編集が止まる時間もそのまま伸びる
- ⚠ **ロックを持っている区間にネットワーク I/O を入れない**、が一般則。Annict はロックの外で先に引き、**「引いた時点の話数と作品 ID」を持ち回ってロックの中で一致を確かめる**。判定は純関数 `annict_applicable?` に出し、`ProgramAnnictStalenessTest` で検証する
  - ⚠ **話数だけでは足りない**（PR #4571 の Codex P2 → PR #4572）。`ProgramEntryUpdateContract` は `annict_work_id` の変更を許しているので、待っている間に作品を差し替えられると**話数は同じだが別作品**になり、旧作品のサブタイトルが載る。**照合は話数と作品 ID の両方**
- ⚠ **存在チェックの正本はロックの中に残す。**外で `NotFoundError` を上げると、**ロック競合より先に 404 を返す**ようになり `ProgramWriteLockTest` が実際に落ちた
- 付随: `persist` を潰して `fetcher.save` 直呼びにした。⚠ **`Metrics/ClassLength` の上限 200 行に合わせるための削りであって設計判断ではない。**この学びを踏まえ、PR #4572 で 201 行になった際は**同じ捻出をせず inline disable で明示**した。正しい直し方（参照系と編集系の分離）は **#4570**

⚠ **この #4534 の系列は「塞いだつもりで開いていた」が 3 連続で出た**（TTL 超過 → 作品 ID 未照合）。**ロックや排他を入れる変更は、入れた直後の Codex 追撃まで込みで 1 セットと見る。**

### 着地済み: #4567 route-not-found 以外の 404 を omit していた（2026-08-11）

PR #4557 の Codex P2。**2026-08-10 の棚卸し（直近 8 PR 横断）でも取り残されていた**もので、同期のリアクション 0 走査で拾った。`endpoint_missing?` が `statusCode == 404` だけを見ていたため、ルートには届いたうえで参照先が無い 404 まで「エンドポイント未提供」として omit し、webhook のルーティング退行を飲みうる状態だった。

⚠ **初版（PR #4568）の `message` 部分一致でも足りず、同日中に是正した**（PR #4568 の Codex P2 → PR #4571）。ハンドラが同じ Fastify 包絡で `Webhook <path> not found` を返すと path を含むので一致し、**ルートは在るのに omit する**。route-miss の文面ごと（`Route POST:<path> not found`）突き合わせる。`Webhook#command` は必ず POST なのでメソッド名も固定でよい。

⚠ 文言が将来ずれた場合は omit されず **assert で赤くなる**方向に倒れる。実退行を飲むより検証条件のズレに気づけるほうを採った。

### Codex レビューの棚卸し（2026-08-11）

**⚠ 前日「直近 8 PR を横断で走査し全件処理した」と記録したのに、PR #4557 の P2 が 1 件リアクション 0 で残っていた。**同じセッション中に PR をマージし続けると、走査の後に着いたコメントがそのまま落ちる。さらに本日マージした PR #4568 / #4569 の**両方**にマージ直後 P2 が届いた（どちらも実質的な穴で、同セッション中に PR #4571 で消化）。

**PR を出したセッションは、締める直前にもう一度リアクション 0 走査を回すこと。**「棚卸し済み」は次セッションへの免罪符にならない。

### 着地済み: #4524 SSRF allowlist の DNS リバインディング（2026-08-10）

**「名前で検証して名前で接続する」構造そのものを畳んだ。**`RemoteHost.public?` は解決結果を真偽値に潰していたので、権威 DNS を握った相手が検証時だけ公開 IP アドレスを返し、接続時に 127.0.0.1 を返せた（TOCTOU）。**#4410 のホップ検証も #4523 のプリフライト検証も、この構造がある限り素通りできる。**

- `RemoteHost.allowed_address` を新設し、`validator` は**真偽値でなく接続先の IP アドレス** を返す。ginseng-core 1.16.0 が文字列を受けると `Net::HTTP#ipaddr=` で接続先を固定する（pooza/ginseng-core#503 / PR #504、`Ginseng::PinnedAddressAdapter`）
- ⚠ **`ipaddr=` は接続先だけを差し替える。**`Host:` ヘッダと TLS の SNI・証明書検証はホスト名のままなので HTTPS の検証は壊れない
- ⚠ **pinning はホップごとに付け替える**（リダイレクト先は別ホスト）
- ⚠ **IPv4 があれば IPv4 を採る。**`getaddresses` は A と AAAA を混ぜて返すので素直に先頭を採ると IPv6 を掴む（#4464 で踏んだ `::1` の 305ms と同型）
- **トレードオフ**: アドレスを 1 本に固定するので、**複数 A レコードのフォールバックは効かなくなる**。対象は管理者が設定した少数の URL なので許容した
- ⚠ 拒否の戻りが **`false` → `nil`** に変わった。呼び出し元はいずれも真偽で判定しているので falsy であればよい

**マージ後に Codex の P1 が 2 件届き、同日中に是正した（PR #4565 / pooza/ginseng-core#505、1.16.1）。どちらも「塞いだつもりで開いていた」型。**

- **短縮 URL の展開だけ pinning を素通りしていた** — `ShortenedURLHandler#permitted_host?` が validator の戻り（IP アドレス）を捨て、`fetch_redirect` は名前で GET し直していた。⚠ **ここは `host_validator` に任せられない**（あちらは追従まで肩代わりして最終レスポンスだけ返すので展開先が取れない）。**追うのがこちらである以上、pinning もこちらの責務**
- **プロキシ経由では pinning が効かない** — `Net::HTTP#connect` は `proxy?` のとき `@ipaddr` を見ずプロキシへ繋ぎ、平文なら絶対 URI・HTTPS なら CONNECT でホスト名を渡す。**名前を解決するのはプロキシ**なのでリバインディングは成立する。fail-closed にした。⚠ `Net::HTTP.new` の proxy 引数は既定が `:ENV` なので、`http_proxy` を置いた環境では**明示していなくても**該当する
  - さらに P2 で「その拒否を `repeat` が 5 回叩き直す」（上流レスポンスの無い `GatewayError` は `source_status` が 502 = 一時障害と読まれる）ことが判明し、`Ginseng::PinningError` を新設して非再送に（pooza/ginseng-core#506、**1.16.2**）。⚠ **設定起因の失敗を再送で解決しようとしない**

### 5.31.0 レビュー由来の受け皿 Issue

5.32.0 で **#4535 / #4536 と #4537 の 1・4**、2026-08-10 に **#4537 の 2・3・5・6**（PR #4563）を消化した。残りは 1 本。

- **#4534** 番組表書き込みの無ロック RMW（サーバー側ロック・size:M）。**5.32.0 では意図的に見送った**（実況が使う書き込み経路そのものにロックを入れる変更で、二度押しは #4533 でクライアント側が塞いである）
- **#4537 の 2・3・5・6（着地）** — Spotify の `invalid_request` を運用側不備に分類（⚠ `Ginseng::AuthError` は **403**、401 ではない）／`webhook.url` を `available?` で nullable 化／効かない `silent_statuses: [413]` の撤去・透過を Hash 限定に・`source_body` のメモ化（ginseng-core 1.15.37）／`Mulukhiya::ForeignGatewayError` を新設し、**引用元（他人のサーバー）由来は #4480 の透過に乗せない**
  - ⚠ **ForeignGatewayError は現状どの経路からもリクエスト層へ届かない**（呼び出し元がすべて degrade する）。「届いたときに透過されない」不変条件を型で担保するためのもの

### Codex レビューの棚卸し（2026-08-10）

直近マージ 8 PR を横断でリアクション 0 走査（[[feedback_codex-review-window-too-narrow]]）。**取り残し 8 件（5 PR ぶん）**があり、全件に返信 + リアクションを付けて処理した。受け皿は 3 本で、**うち 2 本は同日中に着地**。

- **#4558 番組表の `next_on` に `Time` を手書きすると Redis キャッシュ往復で無効値になる（保留中）** — PR #4546 P1 / #4548 P2。**素の Ruby で再現済み。**`load_from_yaml` が coerce 前の生ハッシュを `update_cache` に渡すため、Redis には `"2026-08-08 18:00:00 +0900"` が入る。**1 回目（キャッシュミス）だけ正しく、2 回目以降は無効値**になって VEVENT が黙って消える。⚠ **キャッシュ層を挟むと上流の正規化が静かに外れる**のは #4549（`base_uri` の相対解決）と同型。あわせて `format_date` の無条件 `getutc` が明示オフセット付きの値を 1 日ずらす件（PR #4546 P2、`2026-08-08 00:30:00 +09:00` → 08-07）と、まとめコピーの見出しが `2026-02-31 (火)` と存在しない日付に曜日を付ける件（PR #4548 P2）も同 Issue へ
  - ⚠ **本番が実際に踏んでいるかは未確認**（VPN が繋がらず `var/program.yaml` を見られなかった）。ユーザー判断で**着手を保留**している。修正自体は単体テストで閉じるので、本番確認を待たずに書ける
- **#4559 リリースゲートの穴 2 件（着地・PR #4561）** — PR #4555 P1 / P2。①同じシェルで両系を source すると `MASTODON_*` が残り、**Misskey のつもりで Mastodon を 2 回走らせたまま「両系緑」と記録できる**（選択ルールは「手順（Misskey）」節にあるがゲートの節には無い）②omission 集計をパースできないと warning のまま success で、#4503 のラチェットが黙って無効化される
  - **選択ルール自体は変えていない。**`TestHarness#announce` が run の頭で `TestHarness: controller=... url=...` を stderr に出すようにし、**取り違えに気づける手段を足す**方向で直した。ゲートの判定基準にも「この行が狙った系と一致していること」を追加
  - 集計不能は `steps.test.outcome` で切り分けて fail closed。⚠ **テスト自体が落ちている run では追撃しない**（前段のステップが既に赤い）
- **#4560 `logger.warn` がマスキング層を通らない + `unresolved_enclosures` が伸び続ける（着地・PR #4562）** — PR #4551 P1 は**却下（👎）**。`Ginseng::Logger < Syslog::Logger` なので `warn` は存在し `NoMethodError` にはならない。ただし `Ginseng::Logger` が上書きしているのは **`info` と `error` だけ**で、`warn` は `create_message` を通らず **JSON 化もマスキング（#4511 / #4533）もされない**（4 箇所、うち 1 つは URL を載せる）
  - 直したのは ginseng-core 側（pooza/ginseng-core#499 → PR #500 / #501、**1.15.36**）。⚠ **呼び出し側を `info` に書き換えて回るのは対症療法**。severity は syslog の重要度として正当な使い分け
  - ⚠ **初版（#500）は `message` を必須引数にしていて、ブロック形式 `logger.warn {expensive}` を `ArgumentError` で殺していた**（Codex P2）。#501 で省略可能引数 + ブロックへ戻し、severity 無効時はブロックを評価しない形に是正。**マージ直後に Codex が指摘 → 同セッションで是正**の流れが機能した例
  - PR #4550 P2 側は `RSS20FeedRenderer#render` を新設して 1 レンダーぶんにスコープ。⚠ **テストは `RSS20FeedRendererTest` に置かない**（DBMS 無しでケースごと omit され一度も走らない。#4549 で `absolute_uri` をクラスメソッドにしたのと同じ理由）。親の `initialize` を呼ばないスタブで別クラスに置いた

### 着地済み（2026-08-09）

- **#4503 test: アカウント依存のテストが CI・手元で 1 件も走っていない** — **CI で走らせる方向は採らず、harness 実走をリリースゲートとして正式化する形で決着**した。CI には SNS の実サーバーも Mastodon の Postgres も無く、`config['/mastodon/url']` は `https://ci.example.com` のダミーなので、アカウント依存テストは**構造的に**走らない。3 点で着地:
  - **報告の是正（済）**: pooza/ginseng-core#488 / #489 で `disable?` を omission 報告に。実測 **929 tests 中 313 件が omission**（それまでは pass に混ざっていた）
  - **可視化とラチェット**: CI がジョブサマリに集計行と omission 件数を出し、`.github/workflows/test.yml` の `omission_baseline` を超えたら落ちる。⚠ **test-unit は 313 件 omission でも `100% passed` と出す**ので、集計行を読まないと気づけない
  - **ゲートの明文化**: 通常リリース手順に「harness 実走（省略不可・両系 0 failures / 0 errors）」を追加。判定基準と切り分けは [test-harness.md](test-harness.md)「リリースゲートとしての実走」
- **#4508 chore: sinatra 4.2.1 / rack-protection 4.2.1 / tilt 2.8.0 へ更新** — PR #4556。pin はモロヘイヤ側でなく **`pooza/ginseng-web` の gemspec** にあったので、そちらを `~>` から `>=` へ緩めるのが前提作業だった（pooza/ginseng-web#116 / 1.3.46。CVE-2024-21510 の下限 4.1.0 は保つ）
  - ⚠ **起票時の前提が 1 つ違っていた。`mustermann 4.0.0` はこの更新では入らない**（sinatra 4.2.1 が `~>3.0` を要求する）。**メジャー跨ぎを含まない更新**だった
  - **#4503 のゲートの初適用。**Mastodon（v4.6.5）1001 tests / 0 failures / 0 errors / 152 omissions ＝基準値と完全一致、Misskey（2026.7.0）1004 tests / 3 failures（当時の #4492 の既知集合と完全一致）/ 0 errors / 139 omissions。新規の失敗ゼロ
  - 副産物: **ゲート文言「両系 0 failures」が #4492 のせいで満たせない**ことが露見した。直後に #4492 を解消したので例外は残っていない
- **#4492 test: Misskey harness で恒常的に落ちる 3 件を解消** — PR #4557。**3 件のうち 1 件は harness 側の実バグ**で pooza/chubo2#161 / #162 で直した。これで **`project_harness-zero-error-goal`（両系エラー 0）を達成**
  - ⚠ **`WebhookImageHandlerTest#test_handle_pre_webhook` は製品もテストも変更していない。**Misskey harness の `files` ボリュームが root 所有で、uid 991 の misskey が書けず drive アップロードが `EACCES` → 500 で全滅していた。**起票時の「Amazon の外部依存が原因」は誤り**（当該 URL は 200 を返していた）。harness が drive を一度も通していなかったので露見しなかった
  - `SNSServiceTest#test_access_token` — Misskey の `access_token` 行は MiAuth / OAuth の認可時にしか作られず、harness が発行するのは**ユーザー固有トークン**なのでテーブルは 0 行。honest omit に。⚠ **Mastodon は Doorkeeper のトークン行を持つので対象外**にし、素通しさせている
  - `WebhookTest#test_command` — omit ガードが HTML エラーページ前提だった。⚠ **Misskey harness は nginx を挟まない**ので Fastify が 404 の JSON 包絡を返し、ガードが素通りしていた
- **#4516 / #4552 test/bug: harness 実走で常態化していた失敗 5 件をテスト側から解消** — PR #4553。5 件とも product の退行ではなく**検証側の前提ズレ**だったので、テスト側に寄せて **1001 tests / 0 failures / 0 errors / 152 omissions（100% passed）** にした
  - `SNSServiceTest#test_info` — ⚠ **`metadata.maintainer` を出すのは Misskey だけ**。Mastodon はフォークの `pooza/mastodon` も `nodeName` / `nodeDescription` しか返さないので、**本番 3 台でも `maintainer_name` は nil**。harness 固有の欠落ではない（起票時の「harness に contact account を設定すれば直る」は誤り）。副次的に `MediaFeedRenderer` の RSS author は Mastodon で常に nil
  - `MediaFeedRendererTest#test_to_s` — omit ガードを `#fetch` の描画条件と同じ順に並べ直した。`media_catalog?` が false なら entries は空のまま返る（既定 OFF・#4343）。**harness では依然 `<item>` の描画が検証されない**ので、通したければ harness 側で `media_catalog` を有効にする必要がある（chubo2#64 の続き）
  - `ComposeTemplateContainerTest#test_write_reloads_user_config_inside_lock` — ⚠ **`Account#user_config` はメモ化される**。`TestCase#account` が返す同じインスタンスを渡すと、書き込みが成功していても最初に掴んだ空スナップショットを読む。読み直しは新しい account から行う
  - `AttachmentTest#test_catalog` — ⚠ **製品側は直さない**。`:page` の既定値補完は API 境界の `MediaCatalogQueryService#normalize` が持っており（`cursor` 指定時は付けない、も含む）、モデル側にも足すと補完が 2 箇所に分かれる。起票時の「製品側で揃える」推奨は撤回
  - `MediaMetadataStorageTest#test_push` — Amazon の実画像取得をやめ、`test/fixture/sample.jpg` を WebMock で返す。取得失敗時のネガティブキャッシュ（`{}`）が期待値と食い違って毎回ランダムに落ちていた

### 振り返り

**「塞いだつもりで開いていた」がこのリリースだけで 4 回出た。**#4534 の系列で 3 回（ロック TTL 超過 → 作品 ID 未照合 → 読み経路がロックの外）、#4524 で 2 回（短縮 URL の pinning 素通り・プロキシ経由の fail-open）。
いずれも**排他や検証を「入れた」直後**に見つかっている。**ロックや SSRF ガードを入れる変更は、入れた直後の追撃レビューまで込みで 1 セットと見る**、が実測で裏付いた。

**レビュー・harness・ステージングの 3 段が、それぞれ別のものを捕まえた。**5 観点レビューが赤 2 件（#4574 / #4575）、ステージング検証が #4573（本番で `related` 辞書 3 本が死んでいた既存事象）、harness が #4583 / #4584。**どれも他の段では出てこなかった。**

**⚠ この回でいちばん危なかったのは、コードでなく docs だった。**サブエージェントの黄 1 件を検証せずに api.md へ写し、**従うとデータがずれる手順**を書いた（Codex P1 で発覚・`20c872de` で是正）。赤 4 件は実コードと実測で裏を取ったのに、黄だから素通しした。**観点や深刻度で検証の手を緩めない。**

## リリース済み: 5.32.1（2026-08-08、ホットフィックス）

⚠ **適用したのはデルムリン丼（zugoga）だけ**（ユーザー判断・実害が出ているのがこのサーバーのみのため）。
shallu / gomander / sweep は 5.32.0 のままで、**本番のバージョンは意図的に不揃い**だった。**2026-08-12 の 5.33.0 で 4 台とも揃えて解消済み。**

- **#4549 カスタムフィードの相対 enclosure URL が解決されない** — 5.32.0 の直後に、zugoga の syslog へ
  `base_uri undefined` が**日 2 万行**積まれているのを見つけたのが端緒。追うと**ログノイズではなく機能不全**で、
  `dqdai-anime`（80 エントリ）の `<enclosure>` が **1 件しか出ていなかった**
  - 原因は、モロヘイヤ側の `RSS20FeedRenderer#fetch_image` が `MediaMetadataStorage`（base_uri を
    持たない別の `HTTP`）へ委譲したことで、基底クラスが `@http.base_uri = channel[:link]` で担っていた
    **相対 URL の解決だけが落ちていた**こと。⚠ **キャッシュ層を挟むと基底クラスの前提が静かに外れる**
  - `RSS20FeedRenderer.absolute_uri(value, base)` を新設。⚠ **クラスメソッドにしたのは意図的**で、
    インスタンスは SNS（DB）と Redis を掴むため、DBMS 未設定の環境ではテストがケースごと omit され
    **この判定が一度も走らない**（既存の `RSS20FeedRendererTest` がその状態）
  - 絶対化できなかった値は**エントリごとに出さず 1 サイクル 1 行**にまとめる（`feed enclosure url unresolved`）。
    愚直に出すと #4549 の再来になる
  - `MediaMetadataStorage#push` のネガティブキャッシュを `GatewayError` 限定から広げた。
    呼び出し元が 5 分おきに全エントリを舐め直すので、**空を置かない失敗は永久に再試行される**
- **本番適用（zugoga のみ）**: version 5.32.1 / health 200 / monit OK。適用後のサイクルで
  `base_uri undefined` が **79 → 0**、`<enclosure>` が **1 → 80**（全エントリ）になったことを実機で確認
- **残（この修正の外・スクリプトは git 管理外）**: `bin/dqdai-vjump.rb` が**エントリ 0 件**を返している
  （⚠ **スクレイパの故障と決めつけない**。「V ジャンプがダイ大を取り上げなくなっただけ」の可能性がユーザーの見立て。
  放送していた頃は動いていた）／`bin/dqdai-anime.rb` の記事リンクが `https://dq-dai.com/../news/...` と `/../` を含む

## リリース済み: 5.32.0（2026-08-08）

番組表の実用改善 2 件を主軸に、5.31.0 リリース前レビュー由来の受け皿 Issue から SSRF ハードニング・観測性・テスト信頼性の 4 件を足した回。
当初の土台テーマ（「テストが実際に走っていない」の解消 = #4503 → #4508）は**着手せず 5.33.0 へ送った**。

### 着地済み（2026-08-07）

番組表まわりの実用改善 2 件。**この実況の予定管理はこれまで Google カレンダーで行っていた**もので、`next_on` + `.ics` + tomato-shrieker が揃ってモロヘイヤ側へ寄せられる過程で見えてきた不足。

- **#4540 番組表の並び順を `next_on` → `start_time` に統一** — エディタ一覧・JSON API・まとめコピー・iCalendar の 4 面が別々の（または無指定の）順序だった。`Program.sort_key` を共通の比較規則として新設。⚠ **`Program#data` 自体は並べ替えない**（編集の read-modify-write が `var/program.yaml` の行順を書き換えるため、並べ替えは API のレスポンス経路にだけ入れる）。エディタ一覧の列順も `次回放送日` / `開始時刻` 先頭へ。まとめコピーは日付が変わる位置に `2026-08-08 (土)` の見出しを挟む（全件コピーして手で削る運用なので、削る境界が見えるほうが速い）
- **#4541 番組表エントリに説明欄を追加し `.ics` の `DESCRIPTION` として出力** — 実況の準備のための注意書きを書く欄。`DESCRIPTION` は RFC 5545 の標準プロパティで Google 独自ではなく、**tomato-shrieker の `IcalendarSource` が既に `event.description` を読んでいるため購読側は変更不要**。上限 1,000 文字（他の文字列フィールドの 200 文字とは別枠）。未設定なら `extra_tags` のハッシュタグ行、それも無ければ `DESCRIPTION` を出さない。⚠ **`.ics` は無認証で公開され投稿にも載る**ので内輪メモを置く欄ではない

### 着地済み（2026-08-08 の追加スコープ）

**「番組表だけでリリースするのはさすがに拙速」**（ユーザー、2026-08-08）を受けて、5.31.0 レビュー由来の受け皿 Issue から今日中に収まる 4 件を足した。

- **#4535 security: 短縮 URL 展開の各ホップが SSRF allowlist を通っていない** — `ShortenedURLHandler#resolve_redirects` は Location だけ見て自前で最大 8 ホップ追うが、各ホップのホストを検証していなかった。`rewritable?` が `t.co` を無条件で許すため、短縮 URL 1 本で内部エンドポイントへ GET を撃たせられる（ブラインド）。⚠ **`Ginseng::HTTP` の `host_validator` には寄せられない**（あちらはホップ追従まで肩代わりして最終レスポンスだけ返すので、展開先 URL が取れず機能自体が壊れる）。弾いた URL は **GET しないだけでなく展開結果にも採らない**（採ると投稿本文が内部 URL へ書き換わったまま連合に流れる）。あわせて番組表・読み辞書の HEAD プリフライトが allowlist 拒否まで「判定不能」として飲み `true` に倒れていたのを `RemoteHost.validate!` で是正
- **#4542 obs: ALT 編集 PUT の 404 を Sentry alert から外す** — `STATUS_UPDATE_SILENT_STATUSES = [401, 404]`。他エンドポイントも棚卸しした結果、`favourite` の 404 は 6 週で 1 件しかなく据え置き、**投稿本体（`POST /api/:version/statuses`）の 404 は抑止しない**（投稿が 404 で落ちるのは alert すべき異常）
- **#4537 の 1 と 4** — `PERMITTED_YAML_CLASSES` に `Time` を追加（`next_on: 2026-08-08 09:00:00` で番組表全体が読めなくなる footgun。⚠ **秒なしの `09:00` は Psych が String で返すので元から無害**だった）。`next_on` が過去へ落ちたエントリを `.ics` 生成時に `logger.warn`。残り（2/3/5/6）は Issue に残置
- **#4536 test: `disable_gate` の盲点** — `log` の呼び出し有無で判定していたため、`log` を呼ばず自分の例外も飲む `DecorationApplyWorker` はゲートを外しても緑だった。`ScriptError` 派生の tripwire（`rescue => e` に飲まれない）＋**`perform` の最初の実行文をソースで見る静的テスト**＋検査器自身の空振り検査を追加。ついでに `Worker.descendants` が読み込み済みクラスしか返さず**単独実行では 1 本しか列挙していなかった**のも是正

**今日は入れないと決めたもの**（再提案しない）: **#4534**（番組表の無ロック RMW・size:M。翌日の実況が使う書き込み経路そのものにロックを入れる変更で、二度押しは #4533 でクライアント側が塞いである）／**#4520**（`APIController` の 404 body・capsicum 可視の変更）／**#4524**（DNS リバインディング・`Ginseng::HTTP` 側）

### 5.31.0 からの持ち越し（決着済み）

- **Codex #4527 P2: `ClippingWorker#create_body` が上流の `GatewayError` を握り潰す** — **却下（👎、2026-08-07）**。事実関係は正しい（`uri.to_md` 由来の `GatewayError` はガードを通らず生 URL へ倒れる）が、**非対称なのは意図的**。戻り値は投稿本文なので、上流が落ちたら「リンクだけの投稿」を残すほうがよく、再 raise すると `retry: 3` を使い切って dead 送り＝投稿そのものが消える。#4480 の透過は返す相手（API クライアント）がいるリクエスト層の要求で、ワーカーには及ぼさない。ガード自体は死んでおらず、`create_status_uri` 由来（`uri` が nil）の経路で `GatewayError` の二重包絡を防いでいる。同じ指摘が再発しないよう[コード側にも理由を明記](../app/lib/mulukhiya/clipping_worker.rb)

### メンテナンス

- **bundle update** — sentry-ruby / sentry-sidekiq 6.7.0、temple 0.10.6。bundler-audit クリーン、Dependabot アラート 0

### ステージング検証・本番デプロイ

- **ステージング検証（省略不可）**: dev24 美食丼 / dev25 キュアスタ！ / dev26 デルムリン丼（Mastodon）/ dev27 ダイスキー（Misskey）全 4 台で version 5.32.0・health 200・WebUI 200・番組表エディタ 200 を確認。加えて **dev25 の実機で新経路を 2 つ実行確認**した — 短縮 URL の展開が正常系（t.co → YouTube）で通り `http://127.0.0.1:6379/` は `Rejected host` で弾かれること、`next_on` を過ぎたエントリが `.ics` から落ちて syslog に `program next_on expired` が出ること
- **本番デプロイ: 4 台完了**（2026-08-08、shallu / zugoga / gomander / sweep、全台 version 5.32.0 / health 200、FreeBSD 3 台は `yjit_enabled: true` と monit OK）。Ruby は 4 台とも 4.0.6 据え置きで `rbenv install` 不要。デプロイ後の syslog に**新しいエラー署名は出ていない**（既存の `base_uri undefined`〈zugoga・多発〉と GAS の HEAD 403 のみ）

### 振り返り

- **「番組表だけでは拙速」の判断が正しかった**。追加した 4 件のうち #4535 は pre-existing の SSRF で、#4523 の掃討で取り残していた最後の 1 本だった。レビュー由来の受け皿 Issue は溜めると腐るので、主軸が軽い回の埋め草として消化するのが噛み合う
- **⚠ zugoga の syslog に `base_uri undefined` が 13 時間で 12,720 行出ている**（本リリースとは無関係の既存事象）。Sentry には上がっていない（`e.log` 止まり）ので、Sentry の棚卸し（#4543）だけでは拾えない。syslog 側のノイズ棚卸しは別途必要

## リリース済み: 5.31.0（2026-08-07）

重篤な不具合の解消を主軸に、capsicum の後続タスクと番組表機能を束ねた回。
優先順は「**重篤な不具合 → capsicum の後続タスクがあるもの → 番組表関連**」で消化した。
依存する ginseng-core も 1.15.31 → 1.15.34 へ（pooza/ginseng-core#495 / #498）。

### 1. 重篤な不具合（主軸）

- **#4474 nginx が `X-Mulukhiya-Purpose` 付きの PUT を 405 で弾く** — 本番 3 台で capsicum からの ALT 編集が不通だった。2026-08-05 に本番 3 台 + ステージングで復旧。サンプル vhost（#4475）・docs（#4517）も着地
- **#4511 security/obs: listener が streaming URL をアクセストークン付きで平文ログに書く（size:M）** — ginseng-core 1.15.32 + `config/application.yaml` の `/logger/mask_query_params`（#4518）。**リリース前レビューで「Misskey はボディのキー `i` で渡す＝主たる載り場所が空いていた」ことが判明**し、`Controller::SCRUBBED_LOG_PARAMS` を追加（#4533）
- **#4506 並行性: `disable?` を持つ定期 worker 7 本が perform で短絡していない** — #4519。sidekiq-scheduler は `perform_async` を介さず `Sidekiq::Client.push` を直接叩くため gate を通らない
- **#4487 bug: トークン未設定のアカウントでも webhook URL が生成される（size:S）** — #4522、Codex P2（壊れた行で走査が止まる）を #4525 で追加是正
- **#4523 security: リモート取得の HEAD プリフライトが SSRF allowlist を通っていない** — #4528 + pooza/ginseng-core#495（1.15.33）。#4410 で GET は塞いだが、**その 1 行上の HEAD が素通り**していた。Codex レビューの取り残しから発見（[[feedback_codex-review-window-too-narrow]]）

インフラ側の対の課題として **pooza/chubo2#131**（pgbouncer の `max_client_conn` / `default_pool_size` が未管理・既定 100 のまま）がある。
2026-08-02 06:09 JST に `FeedUpdateWorker` が `no more connections allowed (max_client_conn)` で全滅した実績があり、**ニチアサ窓の約 2.5 時間前**だった。
モロヘイヤ側からはサブプロセス（`bin/*.rb` 19 本）の接続バーストが疑わしいので、chubo2 の調査と突き合わせる。

### 2. capsicum の後続タスク

- **#4491 docs/api.md に `POST /mulukhiya/api/status/tags` のレスポンス仕様を明記する** — #4521（capsicum#909 のブロック解除）。Codex P2（**他人の投稿は 404 ではなく 403**）を #4525 で追加是正
- **#4480 refactor: 上流エラー包絡を捨てず透過する（size:M）** — 第 1 層 pooza/ginseng-core#498（`GatewayError#response` / `#source_body`）+ 第 2・3 層 #4527。棚卸し 5 件すべて回収。**⚠ `APIController`（モロヘイヤ独自 API）の rescue は scope 外で未着手**なので Issue は open のまま
  - 🔴 **本リリース最大の破壊的変更**: ゲートウェイエラーの `error` の型が **Misskey ではオブジェクト、Mastodon では文字列**になる

### 3. 番組表関連

- **#4373 番組表エントリに「次回放送日」を持たせ iCalendar を正しい日に出す** — #4529。**仕様を起票時の `frequency` + `weekday` から `next_on`（次回放送日）1 フィールドへ変更した。**
  - ⚠ **曜日ルールは却下済み・再提案しない。** fail-open で、更新を忘れると**古い話数のまま毎週誤発火する**。価値が話数である以上それは鳴らないより悪い。`next_on` は fail-closed で黙り、エディタの警告バッジで気づける
  - デルムリン丼の公式再放送が終了し、durable な対象はキュアスタ！のウィークリー 1 枠。**この機能は実質キュアスタ！のためのもの**
  - `var/program.yaml` の YAML footgun 2 件（無クォート日付の `Psych::DisallowedClass`、`20:30` の 60 進数解釈）も同時に塗りつぶした
  - 詳細は MEMORY `project_program-ics-shelved`
- **#4484 番組表エディタの一覧表に「有効」トグルボタンを付ける（size:S）** — #4526

### リリース前 5 観点レビュー（2026-08-06 実施・是正済み）

**赤 4 件・是正は #4533。** `rake lint` 全緑、`rake test` 873 件 0 failures / 0 errors。

- **🔴 Misskey のアクセストークンが request ログに平文で残る** — `i` は Misskey が**ボディのキー**で渡すが、`/logger/mask_query_params` は URL のクエリにしか効かない。#4511 はクエリ側しか塞いでおらず、トークンの主たる載り場所が空いていた。**dev27 のログで実在を確認**。`Controller::SCRUBBED_LOG_PARAMS` に `i` / `access_token` を追加。⚠ **これを止めない限り、デプロイ後のログ掃除は掃除した端から再汚染される**
- **🔴 `docs/api.md` が #4480 / #4491 に追随していない 3 件** — ①ゲートウェイエラーの `error` が **Misskey ではオブジェクト、Mastodon では文字列**になる（5.31.0 最大の破壊的変更なのに未記載）②`favorites/create` の冪等丸めが `ALREADY_FAVORITED` 限定に変わった ③`/status/tags` は docs が「上流のステータス」なのに実装は常に 502 だった（実装を `source_status` へ揃えた）
- **不正な `next_on` の fail-closed 化** — `Date::Error` を握って**毎日扱い**へ倒れていた。曜日ルールを却下した理由がそのまま当たり、しかも毎日鳴る。エディタの stale 判定も素の文字列比較で、`2026-02-31` を「過去日（通知は止まっています）」と表示しながら実際は毎日発火していた（表示と挙動が真逆）。過去日と不正値を別バッジに分離
- **番組表エディタの二度押し防止** — 「次回」の二度押しは話数 +2・`next_on` +14 日で**その週の VEVENT が消える**。送信中は ＋ / トグル / 削除を `disabled` に

黄・緑の送り先: **#4534**（番組表書き込みの無ロック RMW・サーバー側ロック）/ **#4535**（`ShortenedURLHandler` の SSRF、pre-existing・#4523 と同型）/ **#4536**（`disable_gate` テストの盲点）/ **#4537**（緑まとめ）。

### Codex レビューの棚卸し（2026-08-07）

直近 15 PR を横断でリアクション 0 走査（[[feedback_codex-review-window-too-narrow]]）。取り残し 4 件のうち 3 件を処理済み。

- **#4527 P1 / #4528 P1（`Gemfile.lock` が ginseng-core 1.15.32 のまま）** — lock は既に **1.15.34** なので解消済み。👍 を付けて処理済みに
- **#4538 P2（`toLocaleDateString('en-CA')` が ISO を保証しない）** — #4539 で是正。`M/D/YYYY` へ落ちると `isStaleNextOn` の字句比較が逆転し、未来日を「過去日」と誤表示する（`2027-01-01` < `8/6/2026`）。`Intl.DateTimeFormat#formatToParts` で明示的に組む
- **#4527 P2（`ClippingWorker#create_body` が上流の `GatewayError` を握り潰す）** — **2026-08-07 に却下（👎）**。詳細は 5.32.0 節

### ステージング検証（省略不可・2 回実施）

**1 回目（2026-08-06）**: dev24-27 全 4 台で develop=5.31.0・health 200・外部 HTTPS 200。実機で機械的に潰した項目:

- **#4373** — dev25 で `RACK_ENV=production` 実行し、`next_on` 未設定＝当日 20:00 / 未来日＝その日 / **過去日＝出力されない**を確認
- **#4480** — dev27 で `favorites/create` に不正 noteId → **`{"error":{"code":"NO_SUCH_NOTE",...}}` が 400 で透過**。同じ経路で **#4381 の過剰な丸めが直っている**ことも確認（以前は 200 + `{}` で成功と偽っていた）
- **#4511** — dev24-27 のログに生トークン 0 件
- **#4487** — dev25 で `Webhook.all` が全て `available?`、nil / 空白トークンを `ConfigError` で拒否

**2 回目（2026-08-07・レビュー修正 #4533 / #4539 込み）**: 1 回目はレビュー前の develop に対するものなので代わりにならない。4 台を `51d96f47` へ更新し、sidekiq → puma → listener の順に再起動（`Gemfile` 無差分のため再 bundle 不要）。

- 4 台とも health 200・version 5.31.0・外部 HTTPS 200
- **#4511 の再確認** — 4 台とも生トークン 0 件。listener は `?access_token=[FILTERED]`、request ログは `params: {"access_token":"[FILTERED]"}`。**dev27 で `/api/notes/create` を実投稿し、ボディの `i` が `"i":"[FILTERED]"` になることを確認**（レビューで見つけた赤の実機実証）
- **#4539** — dev25 の `/mulukhiya/app/program` が 200 で、`formatToParts` を含む新 JS が配信されている
- ⚠ dev27 は `yjit_available: false` のまま（既知・pooza/chubo2#123）

### 本番デプロイ（2026-08-07・4 台完了）

shallu / zugoga / sweep / gomander、全台 version 5.31.0 / health 200 / `yjit_enabled: true` / 外部 HTTPS で version 確認済み。monit も 3 台とも OK に復帰。Ruby は 4 台とも 4.0.6 で据え置き（`rbenv install` 不要）。

**#4511 のログ掃除も同日に完了。**デプロイで書き足しが止まったことを確認したうえで、残っていた生トークンを `[FILTERED]` へ置換した。

| ホスト | 掃除前 | 掃除後 |
| --- | --- | --- |
| shallu | 5 箇所（live） | 0 |
| zugoga | 2 箇所（live） | 0 |
| gomander | 3 箇所（live + `.0.gz`） | 0 |
| **sweep** | **386 箇所（live + `.1`〜`.7.gz`）** | 0 |

### 振り返り

**sweep の 386 箇所は「掃除済み」と思っていたものが残っていた**。2026-08-05 の #4511 掃除は listener の `access_token=` を対象にしており、**Misskey が使う `"i":"` は 3 台の Mastodon には存在しないパターン**だったので、ダイスキーだけ桁違いに残っていた。しかもその中身は**利用者本人のトークン**（`/api/notes/reactions/create` の body）で、エージェントのボットトークンより深刻だった。MEMORY `project_log-credential-exposure` が「`access_token=` だけで grep しない」と警告していた通りのことが、警告を書いた本人の掃除でもう一度起きている。

**リリース前レビューがこれを捕まえた**。`i` がボディで来るという指摘（🔴）が無ければ、デプロイ後の掃除は「掃除した端から再汚染される」状態で回っていた。ステージング検証が本番停止級を捕まえた 5.30.0 の #4509 と合わせて、**レビュー → ステージング → 本番の 3 段が 2 リリース続けて実際に仕事をしている**。

## リリース済み: 5.30.0（2026-08-02）

性能・観測性・セキュリティのハードニング回。新機能の追加はない。**主軸 #4464 のゴール（ニチアサ実況の数秒をハンドラ単位で説明できる状態）を達成し、その実測から出た修正をまとめて出荷した**回でもある。

- **#4464 perf: pre_toot ハンドラの所要時間を計装する** — 閾値超のイベントだけ 1 行 JSON。既定 OFF（`/profile/handler/enable`）。08-02 の実況で lbock 07-26 と突き合わせ、1 秒超 119 件(89%)→79 件(61%)・p50 4.8s→1.1s を確認（詳細は下記「投稿レイテンシ調査の記録」節）
- **#4481 / #4490 perf: 出荷設定からホスト名 `localhost` を排除** — Ruby 3.4+ の HEv2 により `/etc/hosts` に `::1 localhost` を持たないホストでは 1 接続 305ms。Redis DSN 3 箇所と nginx サンプルの `proxy_pass` 13 箇所を `127.0.0.1` 化。nginx 側は「暗黙 upstream 2 ピア → 負荷時に無条件 502」も同時に塞ぐ
- **#4494 / #4482 perf: タグハンドラの重複評価と辞書の重複構築を削る** — `result.push(addition_tags:)` の短縮記法がメソッド呼び出しになる副作用で 1 投稿 3 回評価。`TaggingDictionary`（Redis GET + Marshal・725KB）は 1 投稿で 6 回構築されていた
- **#4466 obs: `/health` に Ruby ランタイム情報（version / YJIT）** — YJIT は Rust の無い環境でビルド時に黙って外れる。既定では NG にせず `/runtime/require_yjit` で opt-in
- **#4461 obs/並行性: 5.29.0 レビュー黄まとめ 4 件** — 保存の二重 alert 解消（`UserConfig#update!` 新設）、StartupNotificationWorker の rescue デッドマン化、compose RMW の fresh read 強制、ロック TTL 10s→30s
- **#4410 security: リダイレクト経由 SSRF を per-hop ホスト検証で塞ぐ** — 初段だけ検証しても HTTParty がリダイレクトを追うため無意味だった。追従を切ると GAS（番組表・読み辞書の実体）が壊れるので、ginseng-core 1.15.29 に `host_validator` を入れて各ホップを検証。検証は再送処理の外
- **#4483 fix: 番組表エディタの ✔ が表示されない** — 素の U+2714 が Linux の絵文字フォント環境で描画されない。Font Awesome へ置換。⚠ **Issue に書かれていた flex-shrink 説を検証せずに実装して外した**（MEMORY `feedback_verify-before-claiming-fixed`）
- **#4509 fix: `RACK_ENV=production` で起動不能** — `json-schema` を Gemfile に書いておらず `Bundler.require` の対象外。ginseng-core 1.15.31 で `Environment.type` が ENV を先に見るようになり、`Ginseng::Config` の autoload 副作用が消えて顕在化。**ステージング検証で捕捉**
- **ginseng-\* の open Issue 6 件を全消化** — core 1.15.31（`Logger#mask` の破壊的変更・`Environment.type` の ENV 無視・`RBENV_VERSION` の引き継ぎ）/ fediverse 1.8.26（nodeinfo の contact_account nil・numeric_ap_id の publicize）/ redis 2.0.5（`create_key` の破壊的変更）。Ruby 4 の frozen string で落ちる `String#nokogiri`・`URI.normalize_component` も是正
- **テスト実行状況の可視化** — ginseng-core #488 で `disable?` のケースを pass ではなく omission として集計。**822 件中 304 件（37%）が実際には実行されていない**ことが判明（#4503）
- **リリース前 5観点レビュー** — 真の赤 0。赤近い黄 2 件（StartupNotificationWorker の `disable?` 未短絡・保存失敗メッセージへの例外クラス名混入）をインライン是正。残りは #4506 / #4508 / #4511 として 5.31.0 へ
- **ステージング検証（省略不可）**: dev24-27 全 4 台で 5.30.0・health 200・WebUI 200 を確認。さらに **#4461 の RMW / ロックを dev24 の実 DB + Redis で 9 項目検証**（この範囲は単体テストが実行されていないため実機で担保）
- **本番デプロイ: 4 台完了**（2026-08-02、zugoga / shallu / sweep / gomander、全台 version 5.30.0 / health 200 / `yjit_enabled: true`）。あわせて **Postgres DSN の `localhost` を `127.0.0.1` 化**、**`/runtime/require_yjit: true` を全台に投入**、**gomander を `develop` 運用から `main` へ戻した**（lbock→gomander 移行の残件を解消）

### 振り返り

**ステージング検証が本番停止級のバグを捕まえた 2 例目**。#4509 は `rake test` 822 件も CI も緑のまま通過していた（どちらも `RACK_ENV` を立てないため）。1 例目は 5.28.0 の省略障害（MEMORY `project_5280-staging-skip-postmortem`）で、あちらは「省略したから起きた」、今回は「実施したから防げた」。

**「守れているつもりの緑」を 2 つ潰した**。ひとつは #4503（822 件中 304 件が未実行なのに 100% passed と出ていた）。もうひとつは #4410 の作業中に既存テストが 1 件落ちた件で、これは **SSRF ガードが正しく効いた結果**だった（`https://dic.test/` は解決できず fail-closed）。差し替えを恒久化すると以後のテストでガードが効かなくなるため、当該テストだけ `ensure` で復元する形にした。

**⚠ `require_yjit: true` は monit と組み合わさると再起動ループになる**。monit は `/mulukhiya/api/health` の 200 を 3 サイクル監視し、失敗すると 3 サービスを再起動する。YJIT 欠落は再起動で直らないため、Rust 無しで Ruby を作り直した瞬間にループへ入る。全台 YJIT 有効を確認したうえで投入している。

## リリース済み: 5.29.0（2026-07-18）

投稿テンプレート（定形投稿）per-user CRUD API を主軸に、fedi-test-harness のテスト信頼性向上と本番で沈黙していた実バグ1件の修正を束ねた回。**5.28.0 で省略したステージング検証を Proxmox ステージング dev24-27 で全台実施できた最初のリリース**（前回の教訓 `project_5280-staging-skip-postmortem` を実運用で解消）。

- **#4457 feat: 投稿テンプレート（定形投稿）per-user CRUD API** — capsicum の投稿テンプレート（pooza/capsicum#767）の端末またぎ共有のため `GET/POST/PUT/DELETE /mulukhiya/api/compose/templates[/:id]` を新設。保存先は user_config（per-user Redis）、id サーバー採番 UUID・件数上限50・書き込み後 read-back で永続化検証（「保存したのに消えた」検知＝専用エンドポイントの主目的）。多端末同時書き込みの lost update は `ComposeTemplateLockStorage` の per-account ロックで直列化（保持中 409、Codex P2 / #4460）。フィールドは id/name/body/cw の 4 つ（scope/position は持たない）。`features.compose_templates` 露出。
- **#4448 fix: StartupNotificationWorker のヒステリシス通知が本番沈黙** — `bump_ng_count` の `redis.incr` が `Mulukhiya::Redis` 未実装で NoMethodError、ヘルス NG 時の再通知が沈黙していたのを ginseng-redis 2.0.4（`Service#incr` 追加）で復旧。harness が炙り出した実バグで 5.29.0 唯一の運用影響修正
- **#4447 test: fedi-test-harness で Mastodon/Misskey 両系エラー0** — stale/DB依存の是正、構造的未提供の honest omit、`harness?` シグナルで omit をゲート（非 harness では実退行を検出）、GroupTag community-map キャッシュのテスト間汚染解消。0 failures/0 errors baseline、残 omission は chubo2#63/#64 で追跡
- **リリース前 5観点レビュー** — 真の赤は CI lint（rubocop 5件）のみで是正。docs/api.md への compose エンドポイント追従・`GET /compose/templates` の alert 対称化・bundler-audit（loofah 2.25.2 / rails-html-sanitizer 1.7.1）をインライン同梱。残る黄（save 二重 alert・worker deadman・compose RMW の user_config メモ化 fresh-read・lock TTL）は #4461 へ送り
- **bundle update** — json 2.21.1 / oauth2 2.0.25 / parser 3.3.12.0 / fugit 1.13.0 等のルーチン更新（bundler-audit クリーン、Dependabot 0）
- **ステージング検証（省略不可・復活）**: dev24 美食丼 / dev25 キュアスタ！ / dev26 デルムリン丼（Mastodon）/ dev27 ダイスキー（Misskey）全4台で develop=5.29.0・health 200・`compose_templates:true` を確認。旧 dev04/15/22/23 は退役済み（現行構成は chubo2 `docs/infra-note.md`「ステージング」節が正）
- **本番デプロイ: 4 台完了**（2026-07-18、shallu / zugoga / lbock / sweep、全台 version 5.29.0 / health 200 / `compose_templates:true`）

## リリース済み: 5.28.1（2026-07-09、ホットフィックス）

5.28.0 本番適用後に判明した設立日まわりの是正ホットフィックス。**5.28.0 でステージング検証を省略（再構築中で使えず）したため本番で顕在化した**教訓つき（詳細は MEMORY `project_5280-staging-skip-postmortem`）。

- **fix: founded_at fallback の 1 日ズレ** — 5.28.0 の #4437（Codex P2）で入れた `created_at.strftime('...GMT')→getlocal` が、Sequel が既に zone 付き（実測 +0900）で返す created_at を二重シフトし設立日が翌日化していた（美食丼 2017-04-20 ← 実際 2017-04-19）。`account.created_at.getlocal` へ是正
- **fix: 未クォート日付での起動クラッシュ（footgun）** — ginseng-core 1.15.27 で Config の YAML ロードに `permitted_classes: [Date, Time, DateTime]` を許可。`founded_on: 2021-03-14` をクォート無しで書いても `Psych::DisallowedClass` で落ちない（従来はクォート必須）。delmulin/daisskey/lbock で実害が出ていた
- **ops: 誤設定 GitHub webhook 4 件削除** — GitHub 生イベントを mulukhiya の Slack 形式 webhook 受け口へ送っていた hook（ginseng-core/ginseng-fediverse/ginseng-web/cure-api）が全て 422 を返し美食丼で「webhook エラー連発」に見えていた。mulukhiya 無関係のため hook 削除で解消
- **本番デプロイ: 4 台完了**（2026-07-09、shallu / zugoga / lbock / sweep、全台 version 5.28.1 / health 200。美食丼 founded_at が 2017-04-19 に是正、各台 founded_at/preopened_at 確認済み）

## リリース済み: 5.28.0（2026-07-08）

capsicum 開発を実ブロックしていた `/about`・API 表層の急ぎ小物を束ねた快速リリース。#4393 media_catalog sub-second 化（size:L）は 5.29.0 の単独テーマへ分離。

- **#4430 feat: 読み付き単語辞書一括取得 `GET /word/all`** — capsicum 投稿サジェスト最適化（pooza/capsicum#687）。ETag/If-None-Match + digest フォールバック
- **#4433 feat: /about features に `annict_review` capability 露出** — #4342 未デプロイ台での review 投稿 404 を capsicum が feature-gate 可能に（pooza/capsicum#677）
- **#4434 feat: /about に `founded_at`（正式オープン日）+ `preopened_at`（プレ公開日）追加** — config `/founded_on`・`/preopened_on` 優先、founded_at は未設定時に最古ローカルアカウント作成日で近似（pooza/capsicum#818）
- **#4420 concurrency: sw_subscription 集約の race を決定化＋トランザクション化** — `order(:id)` 決定化＋`SELECT ... FOR UPDATE` 先取りロック。register↔unregister ABBA デッドロック・無変更 canonical ロック漏れも解消
- **#4423 test: AnnictReviewLockStorageTest フレーキー解消** — record_conflict 計上テストの minute_bucket 境界を Timecop.freeze で決定化
- **#4429 chore: nokogiri 1.19.4** — Dependabot 8 alert 解消
- **リリース前 5 観点レビュー / Codex 対応** — 真の赤 0。並行性 🟡（ABBA デッドロック #4441）、観測性 🟢（config 日付 typo 可視化）、Codex P2 3 件（TZ・FOR UPDATE・api.md #4443）を同梱。既存 `invalidate_sw_subscription_cache` の alert→log は #4442 へ繰越
- **本番デプロイ: 4 台**（2026-07-08、staging 検証省略のまま出したため上記 5.28.1 の是正が必要になった）

## リリース済み: 5.27.0（2026-06-19）

capsicum ナウプレ連携の「URL を自前で返せる経路」を拡張した回。Spotify user-level OAuth + currently-playing API (#4337) と URL→メタ逆引き `/nowplaying/resolve-url` (#4415) を新設。あわせて Misskey プッシュ購読の重複蓄積修正 (#4408)、5.26.0 リリース前レビュー繰越 (#4405)、本リリース前 5観点レビュー由来のログ scrub (#4418)。

- **#4337 feat: Spotify user-level OAuth + currently-playing API** — `GET /spotify/oauth_uri`・`POST /spotify/auth`・`DELETE /spotify/auth`・`GET /spotify/currently_playing` 新設。Authorization Code Flow で per-user トークンを UserConfig（Redis・暗号化）保管し失効/401 時に自動 refresh。client_secret は capsicum に置かずサーバー保持。`features.spotify_enabled`（サーバーゲート）/`spotify_linked`（ユーザー単位）露出。3 エンドポイント（#4382 resolve / currently_playing / #4415 resolve-url）を統一レスポンス形で設計。**ただし Spotify クォータ規約により capsicum #570 が塩漬けのため `user_oauth_enabled` は既定 OFF・全台 OFF で出荷**（連携導線は自動非表示、コード/config 構造は将来復活用に残置）。capsicum #465/#570 連携
- **#4415 feat: ナウプレ resolve-by-URL `POST /mulukhiya/api/nowplaying/resolve-url`** — 共有 URL→メタ（#4382 の title→URL の逆方向）。host 振り分け（Spotify/Apple Music）で `{url, provider, normalized:{title,artist,album}}` or `{url:nil}`。`features.nowplaying_url_resolver` 露出。ユーザー URL を直接 fetch せず ID 抽出のみで固定 API を叩く SSRF-safe 設計。capsicum #729 連携
- **#4408 fix: sw/register の重複 subscription 蓄積を修正** — dedup を `(userId, endpoint)` 単位にし、鍵ローテで残った既存重複行を 1 行へ集約
- **#4405 5.26.0 リリース前 5観点レビュー繰越（黄・緑まとめ）** — 公開 `/word/suggest` の cold-cache 同期 fetch を非同期化、`PronunciationDictionaryUpdateWorker` の size ログを `update` 戻り値から取り無限 enqueue を防止（Codex P1）、体裁修正
- **本リリース前 5観点レビュー赤近い黄インライン (#4418)** — OAuth 認可コード（`code`）が info ログに平文記録されていたのを scrub 対象に追加（`POST /spotify/auth`・既存 `POST /annict/auth` 共通改善）
- **bundle update** — bundler-audit クリーン、Dependabot 0
- ステージング: dev04（FreeBSD・美食丼）/ dev23（Misskey・ダイスキー）で develop=5.27.0 を確認（dev15/dev22 はメンテ外につき対象外）
- **本番デプロイ: 4 台完了**（2026-06-19、shallu / zugoga / lbock / sweep、全台 version 5.27.0 / health 200 全コンポーネント OK）

### 振り返り

**期間**: 5.26.0 リリース 2026-06-09 → 5.27.0 リリース・本番デプロイ 2026-06-19（10 日間）。

**消化**: 5.27.0 マイルストーン Issue 全消化（#4337/#4415/#4408/#4405/#4418 + #4417 ステージング config 戻し）。

**5観点レビュー仕分け**: 真の赤 1 件（Spotify token refresh の同時実行ロストアップデート）だが、**本機能が `user_oauth_enabled:false` で全台 OFF＝ライブ露出ゼロ**のため非ブロックと判断。同 `refresh!` 上の黄群（auth/oauth_uri/delete の alert→log 対称化、Spotify HTTP timeout 明示）と Codex P2（失効トークンクリア）をまとめて #4414（Spotify ハードニング、capsicum #570 復活と同時着手）へ繰越。赤近い黄 1 件（OAuth code ログ scrub）のみ #4418 でインライン同梱。別系統の黄（sw_subscription 集約の非トランザクション race）は #4420 へ。

**Codex 仕分け**: release PR #4412 に P2 1 件（refresh 失効時の stale トークンクリア）。機能 OFF のため #4414 へ集約し、返信 + リアクション付与済み。

## リリース済み: 5.26.0（2026-06-09）

ナウプレ enrich プロキシ (#4382) と読み付き単語サジェスト API (#4397) の新設を主軸に、capsicum 連携（投稿サジェスト・ナウプレ共有 URL 解決）の土台を整えた回。あわせて Program の ProgramFetcher 分割 (#4347)、5.25.0 レビュー送り (#4394) の構造改善、本リリース前 5観点レビュー由来のログ/アラート整備を含む。

- **#4382 feat: ナウプレ enrich プロキシ `POST /mulukhiya/api/nowplaying/resolve`** — Bearer 必須。構造化メタ（title/artist/album）→ Spotify/iTunes 検索 → 共有可能 URL 解決の読み取り専用 enrich。プロバイダ優先 `prefer`（capsicum トグル）> `source_app_name` ヒント > サーバー既定 `/nowplaying/resolve/default_provider`（既定 apple_music、フォールバック許可）。`features.nowplaying_resolver` 露出、整形は capsicum 側でモロヘイヤはステートレス。未使用の旧系統①（`itunes_nowplaying`/`spotify_nowplaying`）を削除し検索ロジックを resolver へ集約（capsicum #466/#484/#668/#570 連携）
- **#4397 feat: 読み付き単語サジェスト API `GET /mulukhiya/api/word/suggest`** — capsicum #614 投稿サジェスト連携。`PronunciationDictionary` が GAS の pron.json を Redis キャッシュし、読み（ひらがな→カタカナ正規化はモロヘイヤ側で吸収）前方一致 → 表層前方一致 → 部分一致でランク付け、同ランクは五十音順タイブレーク（#4403）。`features.word_suggest` を `/word_suggest/urls` 設定有無で `DynamicFeatures::REGISTRY` から動的導出。本体 API #4398、HEAD 非対応ホスト（GAS）の content-length 事前チェック 403 ログ抑止 #4400
- **#4347 refactor: Program クラスを ProgramFetcher へ分割** — fetch/キャッシュ責務を切り出し、rubocop Metrics/ClassLength disable 解除（5.25.0 から送り）
- **#4394 5.25.0 リリース前 5観点レビュー 5.26.0 送り（黄・緑まとめ）** — favorites 400 ログ、program.ics alert 昇格、harness の `test?` ガード、冪等ロック storage/rescue 重複の共通化（`AnnictIdempotencyLockStorage` 抽出）、request ログ本文 scrub、start_time 二段検証、slim 記法ゆれ、api.md 補記
- **本リリース前 5観点レビュー赤近い黄インライン (#4404/#4406)** — 公開 `/word/suggest` 由来の Sentry スパム抑止: `PronunciationDictionary` の Redis 読み/書き失敗（接続障害）を alert→log に倒し、破損（不正 JSON/非配列）のみ alert+invalidate に限定（read #4404 / write は Codex P2 を受け #4406 で対称化）。`nowplaying/resolve`・`word/suggest` のユーザー入力（曲名・検索語）ログ scrub 追加。残り黄・緑は #4405 で 5.27.0 送り
- **bundle update** — Gemfile.lock 変更なし（既に最新、bundler-audit クリーン、Dependabot 0）
- **運用向け設定変更**: word/suggest を有効化するサーバーは `config/local.yaml` に `/word_suggest/urls`（GAS pron.json）設定が必要。未設定なら `features.word_suggest=false` で無効（既定で無害）。`PronunciationDictionaryUpdateWorker` が 10 分毎更新
- ステージング: dev04（FreeBSD・美食丼）/ dev23（Misskey・ダイスキー）で develop=5.26.0 を確認（dev15/dev22 はメンテ外につき対象外）
- **本番デプロイ: 4 台完了**（2026-06-09、shallu / zugoga / lbock / sweep。辞書設定 `/word_suggest/urls`（GAS pron.json）を各サーバー `config/local.yaml` へ投入、全台 `features.word_suggest=true` / version 5.26.0 / health 200）

### 振り返り

**期間**: 5.25.0 リリース・本番デプロイ 2026-06-07 → 5.26.0 リリース 2026-06-09（2 日間）。

**消化**: 5.26.0 マイルストーン Issue 全消化（#4382/#4347/#4394/#4397）。

**5観点レビュー仕分け**: 真の赤 0 件。赤近い黄 2 系統（word/suggest の Redis 障害 Sentry スパム / 入力ログ scrub）をインライン (#4404)、Codex P2（save 側 write の alert スパム）を追い fix (#4406)、残り黄・緑（リダイレクト SSRF 非対称、cold-cache 同期 fetch、docs 表記揺れ・タイポ等）は #4405 にまとめて 5.27.0 送り。

**Codex 仕分け**: ドラフト解除した release PR #4396 に届く Codex レビューは 5観点と重複見込み。#4404 上の P2（Redis 全断時の write 側 alert スパム）は #4406 でインライン対応しリリースに同梱。

## リリース済み: 5.25.0（2026-06-07）

APIController 段階的リファクタの締め (#4285) + 5.23/5.24 レビュー送りの構造改善 + 番組表の iCalendar 出力・開始時刻欄 + Annict review API + 運用ログ整備 + 報告ベース修正を組み合わせた着地回。

- **#4287 feat: 番組表を iCalendar (.ics) 形式で出力** — `GET /mulukhiya/api/program.ics` 新設。tomato-shrieker IcalendarSource 購読想定で認証不要・livecure? ゲート。有効かつ妥当な start_time のエントリを単発イベント化。icalendar gem が SUMMARY 等を自動エスケープ
- **#4366 / #4372 feat: 番組表エディタに開始時刻 (start_time) 欄** — 24 時間制テキスト入力、保存時 `HH:MM` ゼロ埋め正規化。#4286 で見送った分の再実装、#4287 iCalendar の前提
- **#4342 feat: Annict review (作品全体感想) 投稿 API** — `POST /mulukhiya/api/annict/review`、createReview mutation 中継（searchWorks で数値 annictId → Relay node ID 解決、#4339 の前科を review 側で再発させない）。capsicum #592 連携。冪等ロック（Lua CAS、異常頻度の Sentry alert 昇格）を record API と同型実装
- **#4348 refactor: /about の features 動的合流を DynamicFeatures に集約**（5.23 レビュー送り、annict_linked / media_catalog / program_editable の集約）
- **#4285 refactor: PUT /scheduled_status/:id/tags を ScheduledStatusTagUpdater に移設** — #4233 段階的リファクタの 3 件目（最大、ロールバック含む）。ロードマップ完了
- **#4362 ops: Sidekiq 内部ログを syslog へ出し no-reader pipe 消失を防ぐ** — FreeBSD 3 台のログ消失を `Syslog::Logger` 切替 + stdio `/dev/null` reopen で解消（#4264 副次発見）
- **#4377 fix: CustomFeed が null/非配列を返すと FeedUpdateWorker クラッシュ** — RSS20FeedRenderer で防御し空配列フォールバック（Sentry MULUKHIYA-TOOT-PROXY-26 根治）
- **#4383 fix: Misskey favorites/create 冪等 400 パスの副作用非発火を明記・整合**（post_bookmark の PieFed ミラー等を冪等成功時に発火させない）
- **#4389 fix: TestHarness が DSN 上書き後に Postgres singleton を張り直す**（#4379 後続、stale 接続除去）
- **#4379 test: fedi-test-harness 接続情報の test config 注入導線**（DSN/info トークン自動配線、`config.reload` 跨ぎ保持）
- **#4360 test: ProgramTest の auto_update 順序依存修正**
- **リリース前 5観点レビュー赤近い黄インライン (#4395)** — annict record/review の rescue でユーザー入力起因の AuthError(403)/NotFoundError(404) まで Sentry alert していたのを log のみに抑止（反 alert-spam 方針）。廃止語「インスタンス」→「サーバー」整理。残り黄・緑は #4394 で 5.26.0 送り
- **bundle update** — Gemfile.lock 変更なし（既に最新、bundler-audit クリーン、Dependabot 0）
- ステージング: dev04（FreeBSD・美食丼）/ dev23（Misskey・ダイスキー）デプロイ済み（5.25.0 / health 全 OK / WebUI 200 / 新規 program.ics 200 text/calendar）
- **本番デプロイ: 4 台完了**（2026-06-07、zugoga / shallu / lbock / sweep、全台 version 5.25.0 / health 200 / 公開エンドポイント 200）。実況終了後に実施。本デプロイで Sentry MULUKHIYA-TOOT-PROXY-26 が解消
- **デプロイ時の教訓**（[chubo2 infra-history](https://github.com/pooza/chubo2) 参照）: 5.25.0 で `.ruby-version` が 4.0.5 に上がっており、未導入サーバー（今回 shallu）は `rbenv install 4.0.5` が前提。フレッシュ gemset での `bundle install` は rb_sysopen 一過性エラーが出ることがあり再実行で解消。SSH 越しは `bash -lc`（rbenv 読込）必須・サービス再起動は `</dev/null >/dev/null 2>&1` 必須・`bundle install` は省略不可

### 振り返り

**期間**: 5.24.0 リリース 2026-05-28 → 5.25.0 リリース・本番デプロイ 2026-06-07（10 日間）。

**消化**: 5.25.0 マイルストーン Issue 全消化（#4285/#4287/#4342/#4348/#4360/#4362/#4366/#4372/#4377/#4383/#4389 + #4379 関連サブ群）。当初計画の #4351 media_catalog 再有効化は 5.26.0 へ移動 — Gate 検証で partial index だけでは sub-second に届かず、前提として #4393（query 再構成/非正規化、size:L）が必要と判明しブロック。

**5観点レビュー仕分け**: 真の赤 0 件。赤近い黄 2 件（alert spam 抑止 / 廃止語）をインライン (#4395)、残り黄 4 + 緑 4（favorites 400 ログ、program.ics alert 昇格、harness の test? ガード、lock storage/rescue 重複の共通化、request ログ本文 scrub、start_time 二段検証、slim 記法ゆれ、api.md 補記）は #4394 にまとめて 5.26.0 送り。

**運用観察**: media_catalog 再有効化 (#4351) は zugoga 本番 EXPLAIN で partial index 単独では底値レイテンシが sub-second に届かず、query 再構成/非正規化 (#4393) を前提化。5.26.0 主軸候補に昇格。

## リリース済み: 5.24.0（2026-05-28）

5.23 レビュー送り消化 + 番組表エディタ拡張 + 報告ベース新規対応 + capsicum お知らせ通知連携を中心とする整理・小粒着地回。テーマ性は薄いが capsicum 側の機能解放に必要な API 改善（#4354 / #4355）と毎晩ルーチン補助（#4286 番組表まとめコピー）を組み合わせた。

- **#4272 feat: auto_update 有効時は番組表エディタを参照専用にする** — 書き込み 4 ルートが 409 Conflict を返し、WebUI 側は `features.program_editable` で編集 UI を出し分け
- **#4286 feat: 番組表エディタの有効エントリをまとめてクリップボードへコピー** — 毎朝の挨拶投稿運用支援。最小スコープ実装（`start_time` 欄追加は見送り、貼り付け後に手編集する運用）。Issue 本来スコープの開始時刻フィールド + iCalendar 出力 (#4287) は 5.25.0 送り
- **#4284 refactor: POST /status/tags を StatusTagAddService に移設** — #4233 段階的リファクタの 2 件目（26 行）
- **#4344 feat: status post の custom emoji shortcode 前後に ZWSP 自動挿入ハンドラを追加** — fedibird ユーザー報告起点。Mastodon target のみ介入。Codex P2 指摘で時刻形式 `12:34:56` 等の誤マッチを回避するため SHORTCODE_PATTERN を英字/`_` 始まりに限定
- **#4265 fix: メディアアップロードの 413 を Sentry alert 対象から外しユーザー向けメッセージへ変換** — `Ginseng::HTTP#upload` 経由の本家 413 (MAX_ATTACHMENT_FILE_SIZE 超過) をユーザー入力起因として扱い、Sentry MULUKHIYA-TOOT-PROXY-1T を抑止。本家 mastodon/misskey 両 controller に `handle_upload_gateway_error` ヘルパを追加
- **#4264 daemon 調査** — 本番 4 台に SSH 確認し production モード起動・stdio 状態・Environment.type すべて対応不要と判定してクローズ。副次発見の Sidekiq ログ消失 (FreeBSD 3 台で no-reader pipe へ書き込み) は #4362 として 5.25.0 送り
- **#4354 feat: features.announcement_push を /api/about で公開** — capsicum お知らせ通知連携。フラグ参照で push 配信 UI を出し分け
- **#4355 feat: GET /announcement/list を追加** — capsicum-relay (capsicum-relay#14) からの公開キャッシュ参照用、認証不要
- **#4345 fix: AnnictRecordLockStorage#release を compare-and-delete に変更** — TTL 跨ぎで他人ロックを誤削除しない、Lua CAS
- **#4346 feat: AnnictRecordLockStorage 冪等性ロックの異常頻度を Sentry alert に昇格** — 1 分 bucket / account_id 単位で `alert_threshold` (既定 10) 到達時に alert
- **#4349 refactor: /media disabled 応答を MediaCatalogDisabledRenderer に切り出し** — #4343 整理の継続
- **リリース前 5観点レビュー赤近い黄インライン対応** — EmojiSpacingHandler の `result.push(rewritten:)` が投稿本文 (DM 含む) を info ログへ流出させていたのを `inserted: count` メタ情報のみに圧縮。Program editor 4 ルートで `Ginseng::ConflictError` (409) が `e.alert` で Sentry alert spam を生んでいたのを ConflictError 限定で info ログ + alert 抑止する分岐に変更
- **リリース前 5観点レビュー docs 追記** — docs/api.md に `features.announcement_push` と `GET /announcement/list` を追記
- **5観点レビュー次リリース送り** — #4364 で黄 (episode_id alert payload, 暗黙 return 3 箇所, shortcode 単一文字コメント) + 緑 (EMPTY_PAYLOAD freeze, `lock&.` ノイズ, EVALSHA キャッシュ) をまとめて 5.25.0 へ
- **bundle update** — json 2.19.7
- 本番デプロイ: 4 台（zugoga / lbock / shallu / sweep）

### 振り返り

**期間**: 5.23.0 リリース 2026-05-23 → 5.24.0 リリース 2026-05-28（5 日間）。本リリース 8 PR + 5観点赤・黄インライン 1 コミット + bundle update + version bump。

**消化**: 11 Issue（番組表系 2 + capsicum 連携 2 + 5.23 レビュー送り 3 + 段階的リファクタ 1 + 調査 1 + 報告ベース 1 + 413 適正化 1）。#4287 / #4342 は 5.25.0 送り。

**主軸**: 当初「テーマレス回」と宣言、結果としては (1) 番組表エディタ系 (#4272/#4286)、(2) capsicum お知らせ通知連携 (#4354/#4355)、(3) ZWSP ハンドラ (#4344)、(4) 413 適正化 (#4265) の 4 系統が並列で着地。`pooza` 側の deploy 要求 (4354/4355) を起点に 5/28 中の短期リリースに向けて 1 セッション完結で残作業をすべて捌いた。

**5観点レビュー仕分け**: 真の赤なし。赤近い黄 2 件 (emoji_spacing 本文ログ流出 / Program editor ConflictError Sentry spam) を hotfix インライン、docs 追記 (announcement_push / announcement_list) もインライン、残り黄 3 件 + 緑 3 件は #4364 にまとめて 5.25.0 送り。

**Codex 仕分け**: PR #4356 (#4272) 上の P2 は #4360 として 5.25.0 送り。PR #4361 (#4344) 上の P2 (時刻形式誤マッチ) はインライン即修正してリアクション付与。

**運用観察**:

- `#4264` 調査で本番 FreeBSD 3 台の Sidekiq ログが no-reader pipe へ書き込まれ完全消失していることが判明。これまで Sentry の致命エラーしか観測できていなかった。#4362 で Mulukhiya::Logger (syslog) 経由へ切替検討
- PR ベース指定漏れ事故 — `gh pr create` が repo default (main) をベースに採用する仕様で、3 PR が main 起点でマージされ main / develop が diverge。merge commit で修復したが、次回以降 `gh pr create --base develop` の指定を徹底する必要

**反省**:

- `gh pr create --base develop` の指定漏れで意図しない main 起点マージが 3 件発生。CI が通っただけでマージしてしまったため気づくのが遅れた。PR 作成直後に `gh pr view <num> --json baseRefName` を確認するワークフローを徹底
- EmojiSpacingHandler の本文ログ流出は新ハンドラ開発時のテンプレ判断 (`result.push(text:)` で text の中身をどこまで残すか) の問題。今後新ハンドラを書く際は「Reporter に乗る値が info ログへ流れる」点を意識する

## リリース済み: 5.23.0（2026-05-23）

5.22 リリース前 5観点並列レビューの黄送り掃き出しと、本リリース前 5観点並列レビュー対応を主とする「整理回」。あわせて本番で観測された重 SQL 病理（2026-05-19 障害、底値レイテンシ 175 秒級）を受け、メディアカタログ機能を実験的扱いとしデフォルト無効化する運用判断を反映（#4343）。

- **#4343 feat: media_catalog をデフォルト無効化し disabled シグナルを返す** — `data.media_catalog` のデフォルトを `false` に反転（実験的機能扱い）。disabled 時の `/mulukhiya/api/media`・`/mulukhiya/feed/media` は **404 ではなく 503** + body `{"available": false, ...}` を返し、`/about` の `features.media_catalog` で discovery 可能にした。経緯と再開判断は [docs/media_catalog.md](media_catalog.md) を参照。capsicum 側 gate は [pooza/capsicum#606](https://github.com/pooza/capsicum/issues/606)
- **#4338 feat: features API に `annict_linked` を追加** — ユーザー単位の Annict 連携状態を `/about` の features に動的合流（capsicum 連携）
- **#4336 feat: 番組表エディタの各エントリにコピーボタン**（作品名・話数+サブタイトル、毎朝の挨拶投稿運用の手数削減、#4286 の代替最小実装）
- **#4331 feat: Addrinfo.getaddrinfo にタイムアウト** — Puma スレッド枯渇防止
- **#4330 feat: POST /annict/record に冪等性** — 重複 record 投稿を抑止
- **#4329 feat: AnnictService の GraphQL エラーをカテゴリ別 status code で返す**
- **#4318 feat: ProgramEntryContract のエラーメッセージにフィールド名を含める**
- **#4316 fix: Program#update_cache の rescue 整理と失敗文脈付与**
- **#4334 perf: RateLimitStorage を EVALSHA + NOSCRIPT フォールバックに移行**
- **#4328 perf: HTTP fetch のサイズ検証を Content-Length 事前判定に切替え**
- **#4335 refactor: MediaCatalogUpdateWorker の `cursor_pagination?` を Attachment 側に移譲**（#4343 の前提整理）
- **#4333 refactor: RemoteHost.public? の bare rescue を具体例外に絞る**
- **#4319 refactor: tagging_handler.rb / program.rb の暗黙 return を明示**
- **#4313 refactor: ProgramEntryUpdateContract の params 抽出順序整理**
- **#4314 docs: docs/api.md に ProgramEntryContract の上限値・null セマンティクスを補記**
- **#4280 docs: docs/api.md の表記揺れ修正**（インスタンス→サーバー）
- **#4332 wontfix クローズ** — SwSubscriptionContract allowed_hosts は allow-all デフォルトが妥当（endpoint がベンダー管理で allowlist 列挙不能、内部宛 SSRF は #4271 で対応済み、NOTE コメントに理由明記）
- **リリース前 5観点レビュー赤対応** — MediaCatalogUpdateWorker の scheduler 直叩き経路で `disable?` が効かない穴（sidekiq-scheduler が `Sidekiq::Client.push` を直接呼ぶため `Worker.perform_async` 側 gate を通らない）を `perform` 先頭ガード追加で封じ込め。docs 表記揺れ追加修正、`/feed/media` の disabled 時挙動を `docs/api.md` で明確化
- **リリース前 5観点レビュー黄インライン** — ConflictError 経路に info ログ、RateLimitStorage NoScriptError フォールバックに warn ログ、`/media`・`/feed/media` の disabled 応答にも構造化 info ログ、AnnictRecordLockStorage#ttl の memoize
- **5観点レビュー次リリース送り** — #4345（fix: AnnictRecordLockStorage release の compare-and-delete、5.24.0）、#4346（feat: alert しきい値）、#4347（refactor: Program 分割）、#4348（refactor: /about 動的合流フック化）、#4349（refactor: MediaCatalogDisabledRenderer 切り出し）。後者 4 件は未設定
- **Ruby 4.0.4 に更新**
- **bundle update**
- 本番デプロイ: 4 台（zugoga / lbock / shallu / sweep）

### 振り返り

**期間**: 5.22.1 リリース 2026-05-15 → 5.23.0 リリース 2026-05-23（8 日間）。本リリース 7 コミット（#4343 関連 + 5観点対応 + version bump）。

**消化**: 17 Issue（5.22 レビュー送り 8 件 + 番組表エディタ補助 1 件 + media_catalog #4343 + 諸 docs/refactor 7 件）。

**主軸**: #4343 が事実上の主軸として急遽組み込まれた。当初計画は「滞留した小粒の整理回」で主軸なしだったが、2026-05-19 障害（zugoga 等の DB プール枯渇で全サーバー投稿不可）と zugoga 本番ベースライン EXPLAIN で確証した 175 秒級病理を受け、当該機能の実験的扱い化に切替。本来の最適化 #4323（partial index `idx_mlkhy_statuses_local_catalog` 追加）は on-hold へ移動（ベースラインと candidate A は再開時の起点として残す）。

**5観点レビュー仕分け**: 真の赤 1 件（scheduler 経路）を hotfix インライン、黄 2 件と自明赤 7 件（docs 表記等）をまとめて対応、緑容易分 2 件もインライン。残り構造改善 5 件は #4345〜#4349 で次リリース送り。誤検知 2 件（AAAA 取得・`e.alert(**hash)` kwargs）は実証で覆して対応外とした。

**運用観察**:

- sidekiq-scheduler は `Sidekiq::Client.push` を直叩きするため、`Worker.perform_async` 側 gate は scheduler 経由では効かない（本リリースで判明）。今後 `disable?` を持つ worker は `perform` 先頭でも評価する必要がある
- 本番病理（重 SQL の DB プール枯渇）は本番規模特有で、ステージング dev04 等では再現不能（n_live_tup の桁が違う）。性能検証は本番で `EXPLAIN ANALYZE` を取る必要がある（#4323 で実証）

**反省**:

- #4343 で本番停止に駆け込んだが、scheduler 直叩き経路の穴を 5観点レビューが拾わなかったら本番で「local.yaml で false にしたつもりが止まっていない」が継続するところだった。並列レビューを規定どおり実施する価値を再確認

## リリース済み: 5.22.1（2026-05-15）

ホットフィックス。5.22.0 #4227 で追加した `POST /mulukhiya/api/annict/record` が、capsicum エピソードブラウザの送る数値 annictId をそのまま Annict GraphQL `createRecord(episodeId: ID!)` に渡しており、Annict が要求する Relay グローバルノード ID と不一致で `Invalid input` 失敗していた回帰を修正（dev04 ステージングで観測）。capsicum 側からの直接コミット（#4339）をリリース体裁に整えて出荷。

- **#4339 fix: Annict createRecord に数値 annictId を渡して Invalid input で失敗** — `AnnictService#create_record` が `episodeId: episode_id.to_s`（数値 annictId 文字列化）を渡していたのを、`searchEpisodes(annictIds:)`（新 `app/query/annict/resolve_episode.graphql`）で Relay ノード ID に解決してから mutation を呼ぶよう修正。capsicum 側の API 契約（`episode_id` は正の整数）は据え置き、解決はモロヘイヤ内部の責務に閉じる。#4227 実装時の取りこぼし。関連: pooza/capsicum#298
- **#4339 fix: Annict の auth/scope 失敗を AuthError(403) に正規化** — write スコープ不足トークンを Annict が HTTP 401/403 で返す経路・200+GraphQL `errors` で返す経路の双方を `Ginseng::AuthError`（403）に吸収し、capsicum へ「要（再）連携」を 403 一本で見せる。エピソード未解決時は `Ginseng::NotFoundError`（404）。`docs/api.md` の `POST /annict/record` エラー記述（403/404/422/502）を新セマンティクスに更新
- **リリース体裁整備** — capsicum 直コミットでは更新漏れだった `create_record` 系ユニットテストを新 2 段フロー（resolve_episode → createRecord）に追従させ、AuthError(403)・NotFoundError(404) 正規化のカバレッジを追加。rubocop 確認済み
- **bundle update** — ginseng-fediverse 1.8.24 / sidekiq 8.1.5 / jwt 3.2.0 / redis-client 0.29.0 / faraday 2.14.2 / dry-configurable 1.4.0 / rubocop 1.86.2
- 本番デプロイ: 4 台（zugoga / lbock / shallu / sweep）

## リリース済み: 5.22.0（2026-05-08）

番組表リニューアル フェーズ4（Annict 視聴記録・感想投稿 API）達成、5.21 リリース前 5観点並列レビュー黄送りの掃き出し、番組表エディタ品質強化、5.21.x ホットフィックス Codex 指摘対応、本リリース前 5観点並列レビュー赤・黄インライン対応。

- **#4227 feat: Annict 視聴記録・感想投稿 API の追加** — `POST /mulukhiya/api/annict/record` 新設、`createRecord` mutation 中継。capsicum エピソードブラウザ（pooza/capsicum#298 v1.26 ペア）からの感想投稿を可能にする。番組表リニューアル #4234 のフェーズ4 達成。OAuth scope を `[read, write]` に拡張、5.21.x までの既存ユーザーは再認可必須
- **#4322 perf: media_catalog 専用 Sidekiq Capsule に分離** — `default` キュー詰まり防止、concurrency 1。#4306 中期項目の 2 件目（5.21.2 の cursor 化に続く根治策）
- **#4271 feat: /sw/register SSRF allowlist に DNS 解決検証 / IDN 対策を追加** — `allowed_hosts` 空 = allow-all の運用は変わらず、追加でホスト名→IP 解決して private/loopback を弾く
- **#4279 feat: Program#fetch_remote にレスポンスサイズ・スキーマ検証** — 異常な巨大レスポンスや非 JSON で番組表が破壊される経路を塞ぐ
- **#4269 feat: logger.mask_fields に endpoint を追加** — Push 配信先 URL のログ漏れ対策
- **#4312 feat: ProgramEntryContract の source_url にスキーム検証** — `http(s)` 以外を弾く（XSS 緩和）
- **#4283 refactor: GET /media を MediaCatalogQueryService に移設** — #4233 段階的リファクタの 1 件目（24 行、最小）
- **#4325 fix: MediaCatalogUpdateWorker の cursor が Misskey の非ユニーク順序で添付欠落** — Misskey では cursor 無効化し OFFSET ページング維持。SQL の複合キー cursor 化は #4323 と合わせて将来検討
- **#4326 fix: Program#data の extra_tags 正規化を非 Hash entry でも安全にする**（5.21.1 PR #4321 への Codex P1）
- **#4327 fix: Program#fetch_remote 全 URL 失敗時に YAML 上書きを抑止**（本リリース前 5観点 Codex P1）
- **#4309 fix: APIController#token の Bearer 経路で復号後の nil/空チェック**
- **#4310 fix: AnnictService#enrich_episode の dup ガード**
- **#4311 fix: Handler#non_federated_payload? の真偽判定・key 判定正規化** — `localOnly` の string `"true"` や symbol/string キー両対応
- **#4315 fix: AnnictService#episodes 戻り値を nil/[] に統一**
- **#4317 fix: Controller#error の Sentry.capture_exception を rescue で防御**
- **#4277 fix: RateLimitStorage#increment の TTL 取り残しを Lua で防ぐ**
- **#4278 fix: 番組表エディタの重複キー登録を 409 Conflict** — ginseng-core v1.15.25 で ConflictError を追加、`Program#add_entry` を 422→409 に変更
- **#4308 chore: ProgramEntryContract の source_type/source_url を audit メタデータとして整理 / /program/urls 棚卸し**
- **リリース前 5観点レビュー赤 R1 R2 R3 + 昇格 Y9** — SidekiqDaemon.health の capsule 反映、refines.rb の Sentry capture rescue、docs/api.md の 401→403 訂正、AnnictService の非 Hash response 防御
- **黄 6 件インライン** — only_person 正規化を Contract 検証前に戻す / Sidekiq capsule の defensive default / Program#fetch_remote の per-URL rescue / RemoteHost.public? の rescue ログ / test の teardown leak 修正 / `/annict/record` の e.alert 昇格
- **5観点レビュー次リリース送り** — 黄 4 件・緑 4 件は #4328 #4329 #4330 #4331 #4332 #4333 #4334 #4335 で 5.23.0 / 5.24.0 / 未設定へ
- **bundle update**
- 本番デプロイ: 4 台（zugoga / lbock / shallu / sweep）

### 振り返り

**期間**: 5.21.0 リリース 2026-05-02 → 5.22.0 リリース 2026-05-08（6 日間）。期間中ホットフィックス 2 回（5.21.1 当日 / 5.21.2 4 日後）、本リリース 27 コミット。

**消化**: 17 Issue（S=11 / M=6 / L=0、重み 29）。予算 25 を +4 超過。

**主軸 2 件**:

- #4227 Annict 視聴記録・感想投稿 API → 番組表リニューアル #4234 全フェーズ完了。**capsicum v1.26（pooza/capsicum#298）に先行してモロヘイヤ側 API を着地できた** ため、capsicum 側はこちらの仕様を見ながら実装できた（毎晩のルーチンの最終ピース）
- #4322 media_catalog 専用 Sidekiq capsule 分離 → 5.21.2 cursor 化と合わせ、5.20.2 の `every: 30m` 暫定緩和を根治へ寄せた

**5観点レビュー仕分け**: 赤 4 件 / 黄 6 件をインライン、黄・緑 8 件は次リリース送り（#4328〜#4335）。Codex P1 1 件（#4327）もインライン。

**運用観察（chubo2 #36 系）**:

- delmulin_mulukhiya エイリアスは pooza 着地でリポジトリは `/home/mastodon` 配下。デプロイは delmulin_mastodon 経由が必要（SSH エイリアス間で着地ユーザーが食い違う運用）
- FreeBSD で sidekiq daemon が stdio を握って ssh セッションが抜けない → `</dev/null >/dev/null 2>&1` リダイレクトで回避。根治は #4264（5.23.0）

**反省**:

- 5.21.0 当日ホットフィックス #4320（番組表エディタ空フィールドで `extra_tags` 欠落）はステージング手動検証で踏めるはずの回帰だった。番組表エディタ系の手動シナリオを充実させる必要
- 5.22.0 重み 29 で予算 +4 超過。Codex / 5観点レビュー由来の小粒 Issue が積み上がる傾向は構造的で、5.23.0 の計画では主軸を据えず「整理回」として 24 重みに圧縮（#4286 #4287 等の番組表拡張は 5.24.0 へ繰越）、レビュー送り Issue を 1 リリースで吸収する方針に転換。番組表は #4336（最小実装、size:S）で日々運用の手数を先に削る

## リリース済み: 5.21.2（2026-05-04）

ホットフィックス。`MediaCatalogUpdateWorker` の DB クエリ劣化が 2026-05-01 zugoga (デルムリン丼) に続き 2026-05-04 shallu (美食丼) でも再発し、本番でユーザーログイン・連合受信が止まる事象が観測された問題への対処。

- **#4306 fix: MediaCatalogUpdateWorker を OFFSET → cursor ページングに切替** — `app/lib/mulukhiya/worker/media_catalog_update_worker.rb` の `pages.times` ループを cursor ベースに置換。SQL テンプレート (`app/query/mastodon/media_catalog.sql.erb`) は #4220 で既に cursor 分岐実装済みだったため、worker 側で `cursor:` を渡すだけの最小変更。OFFSET ページングの典型劣化（成功 10 秒 ⇄ 劣化 数百秒の二極化）が解消され、PostgreSQL を長時間専有して Mastodon Web (port 3000) の `POST /inbox` 等を 60 秒タイムアウトに追い込む経路が断たれる。中期項目（専用キュー分離 / index 見直し）は #4322 / #4323 として 5.22.0 / 5.23.0 へ分離

## リリース済み: 5.21.1（2026-05-02）

ホットフィックス。5.21.0 で番組表エディタの「追加タグ」を空にして保存すると `GET /api/program` のレスポンスから `extra_tags` フィールド自体が欠落し、Mastodon WebUI 側で番組表全体が表示されなくなる回帰を修正。

- **#4320 fix: GET /api/program のレスポンスで extra_tags を常に配列に正規化** — 5.21.0 #4282 で番組表エディタが空欄を `null` で送信するようになり、`Program#update_entry` が `nil` を「キー削除」として処理した結果、`extra_tags` が空のエントリで API レスポンスからフィールド自体が欠落していた。`Program#data` で読み出し時に `extra_tags` を必ず配列に正規化することで、ストレージ層の `null=削除` セマンティクスを維持しつつ API レスポンスを安定させる。既存エントリ（5.21.0 で `extra_tags` が消えたもの）にも遡及効果

## リリース済み: 5.21.0（2026-05-02）

番組表エディタ品質確保とリリース前 5観点並列レビュー赤対応。番組表リニューアル（#4234）のフェーズ3 #4237 はフェーズ2 #4236 のエディタ実装で実質達成済みと整理してクローズ、フェーズ4 #4227 を 5.22.0 主軸に組み込み。

- **#4270 feat: ProgramEntryContract に長さ・パターン制約を追加（DoS 緩和）** — `MAX_KEY_SIZE=64` / `MAX_TEXT_SIZE=200` / `MAX_TAGS=32` / `MAX_TAG_SIZE=64` / `KEY_FORMAT=/\A[A-Za-z0-9_-]+\z/`
- **#4274 feat: PUT /admin/program/entry/:key を真の部分更新できるようにする** — `ProgramEntryUpdateContract` を新設、`null` でキー削除セマンティクス
- **#4258 chore: APIController#token の params[:token] フォールバック完全廃止** — capsicum プリセットサーバー全台 5.18+ 確認済み（2026-04-22）。以降の認証は `Authorization: Bearer` のみ
- **#4267 fix: Sinatra error ハンドラが Ginseng::Error 以外で落ちて 500 が無ログになる問題の改善**
- **#4268 fix: 連合しない投稿（チャンネル / localOnly）でタグ付与系ハンドラがスキップされない** — `Handler#non_federated_payload?` を導入し `tagging_handler` / `default_tag_handler` で投稿前にスキップ
- **#4273 fix: Program#update_cache 失敗時に invalidate_cache でフェイルセーフ** — Redis 書き込み失敗時の YAML/Redis 乖離を防ぐ
- **#4275 fix: /program/works/:id/episodes の `url` を正しく返す** — `AnnictService#episodes` が空文字を返していた
- **#4282 fix: 番組表エディタで optional フィールドを空にしてもクリアできない** — フォーム保存時に空フィールドを `null` で送るよう修正、`ProgramEntryUpdateContract` の null セマンティクスと組み合わせて削除可能に
- **#4276 chore: ProgramEntryContract をホワイトリスト経由で抽出する** — `PARAMS_KEYS` 定数で許可キーを定義
- **リリース前レビュー赤対応** — Controller#error の非 Ginseng エラー経路（#4267 で導入）でクライアントレスポンスに `e.message` 生値を返していた問題を修正。レスポンス body を `'Internal Server Error'` 固定に、ログは `e.log(path: ...)` 経由で `/logger/mask_fields` 適用に統一
- **#4237 chore: フェーズ3 を B 案でクローズ** — フェーズ2 のエディタ実装が旧フローを上流から置き換える設計だったため、フェーズ3 のスコープは実質達成。残った掃除タスクは #4308 で 5.22.0 へ
- **bundle update** — minitest 6.0.6 / sequel 5.104.0
- **マイルストーン管理を重み予算ベース (size:S/M/L) に移行** — 5観点レビュー由来の小粒 Issue が大量発生して件数目安が機能しなくなったため、重み合計 20〜25 を目安に運用変更。docs/CLAUDE.md の「マイルストーン管理」節を更新
- **積み残し**: 5観点並列レビュー黄送り 11 件は #4309〜#4319 として 5.22.0 / 5.23.0 へ分配。ステージング乖離は [chubo2#36](https://github.com/pooza/chubo2/issues/36)
- 本番デプロイ: 4 台（zugoga / lbock / shallu / sweep）

## リリース済み: 5.20.2（2026-05-01）

ホットフィックス。`MediaCatalogUpdateWorker` の DB クエリ劣化で Sidekiq `default` キューが詰まり、ユーザー操作起点ジョブ（タグセットクリア通知ほか）が数十分遅延する事象に対する応急処置。

- **#4306 fix: media_catalog_update のスケジュール間隔を 3m → 30m に緩和** — OFFSET ベースクエリが 170〜200 秒に劣化、1 ジョブ完走 12〜16 分 × `every: 3m` 投入で concurrency=5 のスロットを使い切り、`default` キュー全体を塞いでいた。デルムリン丼本番（zugoga）で 6,749 件滞留・最古 25 時間前を観測。`UserTagInitializeWorker` の `at:` 経路（タグセットクリア通知）が想定 4 分→実 43 分遅延、`DecorationInitializeWorker` 等も同様に遅延。発生レートを抑える短期対処。cursor ページング切替・専用キュー分離など根治対応は #4306 で別途対応。関連: 真因が同じため #4302（cron 経路の遅延）/ #4303（タグセットクリア通知遅延報告）も解消見込み
- 本番デプロイは zugoga（デルムリン丼）のみ実施。他サーバ（shallu / lbock / sweep）は同症状の確認後に別途対応

## リリース済み: 5.20.1（2026-04-30）

ホットフィックス。Misskey ドライブのアップロード時に `folderId` がドロップされ、画像がユーザーの既定アップロード先フォルダに格納されない回帰を修正。

- **#4297 fix: Misskey ドライブのアップロードで folderId が無視され既定フォルダに入らない** — `MisskeyController#post '/api/drive/files/create'` が `params[:folderId]` を `sns.upload` に渡しておらず、Misskey 純正 WebUI 等が送出する `defaultUploadFolderId` がドロップされていた。本番 syslog で `folderId` 送出を実証。`folderId` を含めて転送するよう修正。ginseng-fediverse 1.8.23 で `MisskeyService#upload` 側でも `folderId` を受け付けるよう拡張済み（ダイスキー本番でりゅうがさん報告）
- **bundle update** — ginseng-fediverse 1.8.22 → 1.8.23
- 本番デプロイは Misskey 系のダイスキー本番のみ実施、ステージングは dev23 のみ実施（Mastodon 系には無関係なため）

ドライブ閲覧側（「ファイルが見えずフォルダのみ表示される」症状）は nginx で `/api/drive/files`、`/api/drive/folders` が本体直結のためモロヘイヤ無関係。Misskey 本体 / Linode Object Storage 側として別途調査。

## リリース済み: 5.20.0（2026-04-28）

番組表エディタ実装（フェーズ2）、/sw/register 強化、リリース前レビュー赤対応。

- **#4236 feat: 番組表エディタ（フェーズ2）の実装** — admin 限定 CRUD UI、Annict 検索連携で `series` / `subtitle` / `episode` / `annict_work_id` / `annict_episode_id` を自動補完。`var/program.yaml` を Single Source of Truth とする
- **#4256 feat: POST /mulukhiya/api/sw/register にレート制限を導入** — `RateLimitStorage` 新規追加、アカウント単位で window 内回数制限（5.19.0 リリース前レビュー R4 の送り）
- **#4259 feat: /sw/register に endpoint ホスト allowlist を追加** — `config['/sw/register/allowed_hosts']` で許可ホストを設定可能（空 = 無制限）（5.19.0 R3 の送り）
- **#4262 fix: register_sw_subscription の存在チェックから sendReadMessage を除外** — 5.19.0 Codex P2 の送り、冪等性
- **リリース前レビュー赤対応** — `/admin/program/entry` 4 ルートの `e.log` → `e.alert` 昇格、`Program#next_annict_episode` の独自 logger を `e.alert` に統一、`views/program.slim` 有効列の命名修正
- **bundle update** — nokogiri 1.19.3
- **積み残し**: 5 観点並列レビューの赤・黄を Issue 化（#4269〜#4280、12 件）→ 5.21.0 で対応

## リリース済み: 5.19.1（2026-04-23）

ホットフィックス。モロヘイヤ WebUI / capsicum で認証 Bearer トークンが通らず更新系 API が 401 で失敗する回帰を修正。

- **#4260 fix: APIController#token の Bearer 分岐で暗号化トークンを復号** — `/oauth/callback` が発行する `access_token_crypt` を `Authorization: Bearer` で受けた際に生値のまま `@sns.token` に入り、SNS 本家への API コール (`sns.repost` / `sns.toot` / Misskey の `body[:i]` / Mastodon の `Authorization: Bearer`) で 401 になっていた。影響していた機能: WebUI「削除してタグづけ」、capsicum 予約投稿タグ付け、`/sw/register` / `/unregister`（5.19.0 Codex P1 指摘と同根）。`MastodonController` / `MisskeyController` のプロキシ経路（純正クライアントの平文 Bearer 前提）は無変更

## リリース済み: 5.19.0（2026-04-22）

Misskey Web Push 登録プロキシ API の追加 (capsicum プッシュ通知対応)、WebUI の Bearer ヘッダー化、Poipiku 対応廃止、スキーマバリデーション見直し、段階的リファクタ、リリース前レビュー手順の導入。

- **#4254 feat: Misskey Web Push 登録プロキシ API (POST /mulukhiya/api/sw/register / /unregister)** — Misskey 本家の GHSA-7pxq-6xx9-xpgm 対応を踏まえた境界張り直し。`write:account` スコープ要求 + `sw_subscription` テーブルへ直接 INSERT + Misskey Redis キャッシュ無効化
- **#4230 feat: WebUI の GET トークン送信を Authorization ヘッダーに移行** — GET クエリ経由のトークン送出を廃止。後方互換として `params[:token]` フォールバックは 5.21.0 で完全廃止予定
- **#4255 fix: リリース前レビューで検出した赤 7 件を修正** — SSRF ガード / 冪等性仕様整合 / Redis プール漏れ / /tagging/tag/search rescue 復活 / e.alert 昇格 / /health に misskey_redis 追加 / Sentry PII scrub 拡張
- **#4251 fix: スキーマバリデーションで未設定の任意項目が required エラーになる** — 5.18.0 #4245 の取り残し
- **#4253 refactor: POST /tagging/tag/search を TagSearchService に移設** — 親 #4233 段階的リファクタ
- **#4250 chore: ポイピク (Poipiku) 対応機能の全廃止**
- **is_cat キャッシュ TTL デフォルトを 6h → 1h に変更** — 運用観察のため
- **リリース前レビュー手順をプロジェクトガイドに導入** — 5 観点並列サブエージェント + Codex リアクション運用 (capsicum 側から移植)
- **bundle update**

## リリース済み: 5.18.0（2026-04-17）

番組表永続化・Postgres ヘルスチェック改善・is_cat キャッシュ制御・puma/parallel メジャー更新。

- **#4235 feat: 番組表の永続 YAML ストア導入・Program クラス差し替え** — `var/program.yaml` を Single Source of Truth とし Redis は読みキャッシュに。外部 URL pull 機構は維持、既存 API 契約は変更なし
- **#4244 feat: Postgres.health に WARN 分類、通知にヒステリシス導入** — プール枯渇を WARN として区別し、スポット誤報を抑制
- **#4248 feat: is_cat キャッシュの TTL を設定可能にし、デフォルトを 6 時間に短縮**
- **#4249 feat: is_cat キャッシュ管理の rake タスクを追加**
- **#4245 fix: base.yaml の top-level required を merged 検証前提に見直し** — ginseng-core #477 追随
- **#4243 fix: postgres.pool.size の既定値を 4 → 10 に引き上げ** — Sequel::PoolTimeout を回避
- **#4247 fix: fetch_actor が ActivityPub レスポンスをパースできていなかった**
- **fix: Misskey メディアカタログの next_cursor を note_id ベースに修正**（Codex レビュー指摘）
- **fix: Ginseng::ApplicationError を Ginseng::Error に修正**（Sentry MULUKHIYA-TOOT-PROXY-10）
- **#4241 chore: parallel 2.0 へ更新**
- **#4240 chore: puma 8.0 へ更新** — 明示的に `tcp://0.0.0.0` を bind

## リリース済み: 5.17.0（2026-04-14）

Postgres ヘルスチェック・接続プール・API 認証の改善。

- **#4228 fix: Postgres.health が Mastodon API 応答に依存していた問題を修正** — `SELECT 1` を直接実行。goatdeam の PostgreSQL 停止誤報を解消
- **#4232 feat: Postgres 接続プールサイズ・タイムアウトを設定可能にする** — `/postgres/pool/{size,timeout}` を local.yaml で上書き可能に。zugoga の Sequel::PoolTimeout 対策
- **#4223 fix: APIController で Authorization: Bearer ヘッダー認証に対応（security）** — GET クエリにトークンが漏れる問題を修正
- **#4238 fix: Authorization ヘッダが Bearer 形式の場合のみトークンとして採用**
- **#4207 refactor: /emoji/palettes の実装を MisskeyService に移設** — APIController を 42行 → 9行に縮小
- **#4222 feat: メディアカタログキャッシュの管理 rake タスクを追加**
- **#4226 docs: メディアカタログ API のレスポンス形式をドキュメントに反映**
- **#4240/#4241 chore: puma/parallel をピン留めし bundle update 巻き込みを回避**

## リリース済み: 5.16.1（2026-04-09）

ホットフィックス。絵文字ショートコードのタグ化退行修正と gem 互換性修正。

- **#4224 RemoteTagHandler: 絵文字ショートコードがタグとして復活する退行を修正** — `strict_key?` で strict 辞書由来キーのみ除外し、#4089 と #4217 を両立
- **rspotify fork 参照に切替（Ruby 4.0 互換）** — mime-types 2.99.3 の SyntaxError を解消

## リリース済み: 5.16.0（2026-04-07）

メディアカタログ集中改善。

- **#4219 メディアカタログ: ステータスURLが不正になる環境がある** — S3_ALIAS_HOST環境でドメイン・パスが不正。`/mastodon/attachment/base_url` 設定を追加
- **#4220 メディアカタログ: 大規模インスタンスでのクエリパフォーマンス改善** — Redisキャッシュ+Sidekiq定期ジョブ+カーソルページング
- **#4221 emoji/palettes API: scopeカラムのARRAYリテラル型不一致** — capsicumから修正済み・動作確認完了
- **ginseng-postgres#96 SQLインジェクション対策** — QueryTemplate#escape追加、全テンプレート適用

## リリース済み: 5.15.0（2026-04-06）

メディアカタログ API パフォーマンス改善、リモート isCat 判定 API、各種バグ修正。

- **#4211 メディアカタログAPI: N+1クエリの解消** — catalog/feedのself[row[:id]]をwhere(id: ids)の一括取得に変更
- **#4212 メディアカタログAPI: Misskey版SQLパフォーマンス改善** — 冗長なGROUP BY削除、LIMIT/OFFSETをキーワードフィルタ後の外側クエリに移動
- **#4210 メディアカタログAPI: ページネーションメタデータ** — レスポンスを `{items, page, has_next}` 形式に変更。LIMIT+1件取得で次ページ判定。WebUI対応済み。capsicum側も要対応（pooza/capsicum#71）
- **#4206 設定監査: 配列内オブジェクトの不明キー検出** — `detect_unknown_keys` で配列ノードの場合にスキーマの `items` を参照して各要素に再帰
- **#4198 リモートアカウントのisCat判定API** — `POST /mulukhiya/api/account/is_cat` でWebFinger→ActivityPub Actor取得、Redisキャッシュ付き
- **#4217 RemoteTagHandler: リモートタグ欠落修正** — `dic.key?` フィルタを削除し `local_tags.member?` のみに
- **#4215 RSS20FeedRenderer#cache: 例外型を明示**
- **#4214 NowplayingHandler.trim: Artist/Title行が削除されない** — trimロジックのバグを修正
- **#4209 NowplayingHandler.trim: uri.hostがnilの場合のNoMethodError** — nilガード追加
- fix: removal_rule_tagスキーマの重複パス(tags.rules)を削除
- fix: isCat APIでactor取得失敗時にnilをキャッシュしない
- fix: isCat APIのセキュリティ改善（SSRF防止・スレッド安全性・配列上限）
- test: IsCatContract・IsCatStorageのテスト追加、Storage系テストにRedis接続チェック追加

## リリース済み: 5.14.1（2026-04-04）

- fix: about APIで`/status_url`未設定時に500エラーになる問題を修正

## リリース済み: 5.14.0（2026-04-04）

設定監査機能の本格化、ハンドラー画面 UI 刷新、不要設定の廃止。

- **#4118 設定監査API・不要キー検出UI** — `GET /admin/config/audit` でバリデーションエラーと不明キーを検出。本番4台の local.yaml で網羅テスト実施
- **#4117 WebUI: 複雑なハンドラーパラメータ編集（CRUD一覧管理）** — 辞書タグ等の配列・オブジェクト型パラメータを管理画面から編集可能に
- **#4203 about API に `/status_url` を追加**
- **#4202 Misskey 絵文字パレット取得 API** (`GET /mulukhiya/api/emoji/palettes`)
- **#4205 `/ruby/jit`・`/ruby/bundler` 設定を廃止** — YJIT はランタイム判定に変更、bundler 自動実行はカスタム API 分離で不要に
- fix: 設定監査スキーマの偽陽性を解消（`/sentry`, `/service`, `/diag`, `/agent/info/webhook` 等）
- fix: ハンドラー画面の label / description 表示、コンテナ幅拡大、ボタンデザイン統一
- fix: 設定監査レイアウト崩れ修正（バリデーションエラーと不明キーの縦積み）

## リリース済み: 5.13.0（2026-04-03）

rack セキュリティ修正（CVE 13件）とハンドラーメタデータ・TagContainer修正。

- **セキュリティ: rack 3.2.6** — CVE-2026-34829 (High: 無制限チャンクアップロード)、CVE-2026-34827 (High: multipart DoS)、CVE-2026-34785 (High: Static ファイル露出) 他 Medium 9件、Low 1件を修正
- **#4194 ハンドラーに label / description メタデータを追加** — 全44スキーマYAML + Handler#label, #description アクセサ
- **#4199 文章の末尾に `#` が加えられる** — TagContainer で空タグ・nil値をフィルタ。ginseng-fediverse v1.8.22 で gem 側も修正
- **#4191 rc.d スクリプトに redis 依存を追加**
- fix: json-schema gem の MultiJSON 非推奨警告を抑制

## リリース済み: 5.12.1（2026-03-28）

ホットフィックス。Sentry で検出された本番障害 2 件を修正。全4台デプロイ済み。

- **#4193 ImageResizeHandler が type メソッド未実装で ImplementError** — #4184 で `update_metadata` 追加時に `ImageResizeHandler` への `type` 実装を漏らしたリグレッション。`nil` を返すことで早期リターン
- **#4192 Program#update で HTTParty::Response に .to_h を呼んで NoMethodError** — `.parsed_response` に修正

## リリース済み: 5.12.0（2026-03-27）

全5 Issue クローズ。動画アップロード改善、予約投稿タグ編集API、デコレーション復元、短縮URL改善。全4台デプロイ済み。

- **#4188 エピソードブラウザのコマンドトゥートにデコレーション解除を含める**
- **#4187 デコレーション復元APIの追加とタグセット解除時の連動**
- **#4186 予約投稿のタグ編集API** — ScheduledStatusStorage（Redis TTL付き）、ScheduledStatusSaveHandler（post_tootパイプライン先頭に登録）、PUT /scheduled_status/:id/tags
- **#4185 ShortenedURLHandler: youtu.be削除とt.co特別扱い** — youtu.beをホワイトリストから除外、t.coはホワイトリストに依存せずハードコードで常に展開対象
- **#4184 VideoFormatConvertHandlerテスト基盤整備とエッジケース対応** — pix_fmtチェック、video_codec nilガード、音声なし動画へのサイレント音声トラック自動付加、変換後のContent-Type/ファイル名更新
- fix: daemon環境でのOpen3 Broken pipe対策（EPIPE検出時のみ/dev/nullにリオープン）
- 本番Mastodon 3台に`S3_FORCE_SINGLE_REQUEST=true`適用（S3マルチパートダウンロードの動画破損対策）
- Ruby 4.0.2に更新

## リリース済み: 5.10.1（2026-03-22）

Codexレビュー指摘3件の修正。

- **fix: Config#admin_role_ids が空配列を返す** — `positive?`（Ruby Numeric）はSequel DSLではなく正しいSQLに変換されなかった。`> 0` に修正（#4172）
- **fix: StartupNotificationWorker の通知前ステータス保存** — `notify_if_changed` で通知前に `save_status` していたため、通知失敗時にステータスが更新済みになる不整合を修正（#4170 P1）
- **fix: GroupTagHandler#db_display_name のアクセサ経由参照** — Sequelモデルの生カラム値 `account[:display_name]` を直接参照するよう修正（#4169 P2）

## リリース済み: 5.10.0（2026-03-22）

全3 Issue クローズ。HEVC動画対応、about API拡張、ヘルスステータス変更通知。

- **#4168 ヘルスステータス変更時に再通知** — 前回のヘルスステータスをRedisに保存し、5分ごとのチェックで変更（OK→NG、NG→OK）を検出した場合にinfo_botから管理者へ再通知
- **#4172 about APIで管理者ロールIDを返す** — `GET /mulukhiya/api/about` の `config` に `admin_role_ids` フィールドを追加。capsicumの管理者バッジ表示に利用（pooza/capsicum#159）
- **#4171 HEVC動画のアップロード422修正** — VideoFormatConvertHandlerにコーデック互換性チェックを追加。H.265 mp4をlibx264でトランスコードしてからMastodonに送信
- GroupTagHandler#db_display_nameをアクセサ経由に戻す
- bundle update (nokogiri 1.19.2, mcp 0.9.0)

## リリース済み: 5.9.1（2026-03-21）

- **#4167 GroupTagHandler: 空タグ修正** — `db_display_name` が空文字列を返す場合に `#` のみが付加される不具合を修正

## リリース済み: 5.9.0（2026-03-20）

全4 Issue クローズ。カスタムAPI独立デーモン化、PieFed gem切り出し、GroupTagHandler、セキュリティ対応。全4台デプロイ済み。

- **#4144 カスタムAPIを独立デーモンに分離** — Bundler二重管理・Open3.capture3の不安定さを解消。cure-api v3.0.0として独立HTTPサーバーに移行。設計意図は [custom-api-redesign.md](custom-api-redesign.md) を参照
- **#4146 PieFed対応をginseng-piefedに切り出し** — ginseng-piefed gem を新規作成
- **#4164 GroupTagHandler** — PieFed community-hashtag-map 連携によるグループタグ自動付与
- **CVE-2026-33210** json gem format string injection 対応済み
- ginseng-piefed 0.1.1: Service#logger/config未定義バグを修正
- CIでGroupTagHandlerの外部HTTPリクエストを抑制

## リリース済み: 5.8.0（2026-03-16）

全7 Issue/PR クローズ。セキュリティレビュー対応、reblog_labelカスタマイズ、投稿編集APIパススルー（実験的）。

- **#4161 about APIでブースト/リノートのカスタムラベルを返す** — config/local.yamlで `mastodon:/misskey: > status: > reblog_label:` を設定し、capsicumから参照可能に
- **#4162 PUT /api/v1/statuses/:id パススルーの追加（実験的）** — capsicumからの投稿済みメディアALT編集に向けた基盤。capsicum側は継続検討中
- **#4157 Sentry: before_sendフィルタによる秘匿情報スクラビング**
- **#4158 bundler-auditの導入とCI統合** — sinatra CVE-2025-61921 は rack 3.2問題のため ignore 設定
- #4159 フロントJSテストのアサーション修正
- #4155 Wiki: Sentry.ioの設定項目をドキュメントに追加
- #4156 セキュリティレビュー実施済み

## リリース済み: 5.7.0（2026-03-14）

全5 Issue クローズ。Sentry エラートラッキング導入、Misskey localOnly フラグ、フロントエンド JS モジュール抽出。セキュリティレビュー（#4156）実施済み。

- **#4154 Sentry.ioによるエラートラッキングの導入** — sentry-ruby + sentry-sidekiq。既存のalertメソッドにSentry.capture_exceptionを統合。DSNはconfig/local.yamlの`/sentry/dsn`で設定
- **#4153 Misskey: 内部DMにlocalOnlyフラグを設定する** — コマンドトゥート、お知らせボット通知DM、ボットメンション時のDM強制変更でlocalOnly: trueを設定
- **#4140 config.slimのフォーム処理ロジックを外部JSに抽出** — config_form.jsに10個の純粋関数を抽出、27テストケース追加
- **#4141 テンプレート内JSの段階的なモジュール抽出** — webui_utils.jsに6個の純粋関数を抽出、18テストケース追加
- #4152 Annict連携セクションの認証要件をドキュメントで修正

## リリース済み: 5.6.0（2026-03-11）

全5 Issue クローズ。Lemmy 対応廃止、ストリーミング死活監視の再導入、capsicum エピソードブラウザ向け API 整備。

- **#4143 ヘルスチェックにストリーミングプロセスの死活監視を追加** — `/api/v1/streaming/health` への直接チェックに変更し、小規模サーバーでの誤検知を防止
- **#4145 Lemmy対応を廃止し、PiefedClipperを自立化** — LemmyClipper を削除し、PiefedClipper を独立化
- **#4150 `GET /annict/oauth_uri` エンドポイントを追加** — capsicum のエピソードブラウザから Annict OAuth 認可を開始するためのエンドポイント
- #4137 ナウプレ系ハンドラーの tagging パラメータを廃止
- #4139 アップロード時のペイロード調整をginseng-fediverseに移動
- #4148 capsicum エピソードブラウザ向け API ドキュメントの整備

## リリース済み: 5.5.1（2026-03-08）

ホットフィックス。全8サーバーデプロイ済み。

- **#4142 ヘルスチェックからstreaming死活監視を除外** — 小規模サーバーで10分間イベントがないだけでhealth全体が503になり、monitの不要な再起動を誘発していた

## リリース済み: 5.5.0（2026-03-08）

全8 Issue クローズ。WebUI ハンドラーパラメータ編集の拡張、リスナー死活監視、フロントエンドテスト基盤導入。全8サーバーデプロイ済み。

- **#4116 WebUI: object型・配列型ハンドラーパラメータの編集に対応** — スキーマ定義に基づくネストされたオブジェクトや配列の追加・削除をWebUIから直接編集可能に
- **#4124 リスナーのWebSocket死活監視と安全な停止** — 指数バックオフによる再接続、Redisイベント記録、SIGTERM/SIGINTでの安全な停止
- **#4131 フロントエンドJSのブラウザテスト基盤導入** — Mocha/Chaiによるブラウザテストランナー。handler_form.js を抽出し26テストケースを実装（MulukhiyaLib 30件と合わせ計56件）
- **#4134 Misskey: アップロード時にセンシティブ・説明が保存されない問題を修正**
- **#4136 Mastodon: アップロード時にalt textが保存されない問題を修正**
- #4132 WebUI: ハンドラー設定パネルがイベントセクションを突き抜ける問題を修正
- #4133 WebUI: ハンドラーが含まれないイベントを非表示にする
- #4138 local.yaml未存在時のスキーマバリデーションエラーを修正

## リリース済み: 5.4.0（2026-03-04）

全5 Issue クローズ。WebUI ハンドラーパラメータ編集機能の追加と `/about` API の修正。全8サーバーデプロイ済み。

- **#4115 WebUI: 軽量ハンドラーパラメータの編集機能** — boolean・数値・文字列などの単純なパラメータを WebUI から直接編集可能に
- **#4128 `/about` の capabilities・features が空になる問題を修正**
- **#4129 メディアカタログ: Misskey 環境でステータス URL が不正になる問題を修正**
- #4126 起動時の標準出力メッセージを廃止
- #4127 CI ログの Sequel::Error メッセージを抑制

## リリース済み: 5.3.0（2026-03-02）

全12 Issue クローズ。nodeinfo 循環呼び出し問題を解消した重要リリース。ステージング検証（zugoga）完了後にリリース。

- **#4121 nodeinfo 依存の見直し** — nodeinfo を Redis にキャッシュし、循環呼び出し・429 エラー・WebUI のレスポンス低下を解消。詳細は [postmortem-2026-03-nodeinfo.md](postmortem-2026-03-nodeinfo.md) を参照
- **#4098 daemon-spawn gem 廃止** — プロセス管理を OS の init システムに委任。`rake start/stop/restart` を廃止しサービスマネージャへ誘導
- **#4113 `/mulukhiya/api/about` のレスポンス拡張（capsicum 対応）** — `status.label`、`status.max_length`、`theme.color`、`capabilities`、`features`、`handlers` を追加
- **#4125 起動通知 DM** — お知らせボットから管理者へヘルスチェック結果 + スキーマチェック結果を DM 通知
- **#4123 ListenerDaemon.health の PID ファイル非依存化** — `pgrep` フォールバック追加。rc.d の stop に `pkill -9` フォールバック追加
- #4102 WebUI での設定編集機能の拡充
- #4119 FreeBSD rc.d: listener restart 時にログが流れ続ける問題の修正
- #4075 `with_indifferent_access` を `Sinatra::IndifferentHash` に統一
- #4108 Webhook.create の digest 照合を効率化、#4109 エラーレスポンス改善
- #4114 未使用ハンドラースキーマ・パラメータの削除、#4110 Webhook digest 回帰テスト追加

## リリース済み: 5.2.1（2026-03-01）

緊急パッチリリース。全8サーバーデプロイ済み。

- **#4106 Webhook URL が無効になる不具合の修正** — 5.2.0 で `Webhook.create_digest` の salt 取得を `/crypt/salt` → `Crypt.password` に変更したが、両者が異なる値のサーバーで digest が変化し Webhook が 404 になった。`/crypt/salt` 優先にリバート

## リリース済み: 5.2.0（2026-02-28）

全7 Issue クローズ。全8サーバーデプロイ済み。

- **#4096 実況デコレーションの時限付き自動解除** — 番組終了後にアバターデコレーションを自動で剥がす（Misskey `i/update`）
  - Misskey 側: [pooza/misskey#404](https://github.com/pooza/misskey/issues/404) もクローズ（TagsetWidget で `decoration.minutes` を追加送信）
  - 検証時に発見した問題と対策:
    - トークン競合: `UserConfigCommandHandler` で token 保存を update より前に移動（async worker が古いトークンを読む問題）
    - API body sanitization: `DecorationApplyWorker` で `avatarDecorations` の各要素を valid_keys のみに slice（レスポンス専用フィールドの混入防止）
    - Misskey ロール設定: ベースロールのデコレーション上限を +1 する必要あり（追加で1枠使うため）
- #4094 HTTPクライアント統一、#4101 CommandLine.exec タイムアウト
- #4082 Sidekiqワーカーテスト、#4099 Worker個別コンテキストログ、#4103 テストの外部API依存解消
- #4105 FreeBSD rc.d 起動ブロック原因切り分け（Mastodon streaming が主犯 → [pooza/mastodon#900](https://github.com/pooza/mastodon/issues/900)）
