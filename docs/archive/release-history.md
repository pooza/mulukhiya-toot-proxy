# リリース履歴

CLAUDE.md から分離した過去のリリースノート。直近リリースは [CLAUDE.md](../CLAUDE.md) を参照。

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
