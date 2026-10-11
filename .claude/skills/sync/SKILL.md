---
name: sync
description: セッション開始時の進捗同期。「進捗を同期してください」「同期して」などで起動する。リモート・CI・Dependabot・Codex レビュー・Sentry・chubo2・ginseng-* のピン・辞書台帳・マイルストーン・harness の upstream 版を確認して報告する。
---

# セッション開始時の同期手順

⚠ この手順の正本はこのファイル（#4731 で `docs/CLAUDE.md` から移した）。`docs/CLAUDE.md` の同名の節はポインタ。
履歴の中の「同期手順 §6-1」などの節番号は、このファイルの番号のまま通る。
同期の結果は `docs/CLAUDE.md` の開発中の版の下に「YYYY-MM-DD セッション同期の記録」として残す。

会話の最初に「進捗を同期してください」等の指示があった場合、以下の手順を実行する。

## 1. プロジェクトガイドの読み込み

- `docs/CLAUDE.md` を読む（プロジェクトのルール・構造・履歴の正本）
- `MEMORY.md` は自動ロードされるので、両者の整合性を意識する

## 2. リモートとの同期・状態確認

- `git fetch origin` — **最初に必ず実行**。リモートが正本であり、ローカルの状態を信用しない
- `git log HEAD..origin/develop --oneline` — リモートに未取り込みのコミットがないか確認。差分があればpullを検討
- `git log --oneline -10` — 直近のコミット履歴
- `gh issue list --state open` — open Issue一覧
- `gh pr list --state open` — open PR一覧

## 3. Dependabotセキュリティアラート

- `gh api repos/pooza/mulukhiya-toot-proxy/dependabot/alerts` で open アラートを確認
- 0件なら対応不要、あれば提案

## 4. Codexレビューコメントの確認

- 最近マージされたPR（`gh pr list --state merged --limit 5`）を取得
- 各PRに対して `gh api repos/pooza/mulukhiya-toot-proxy/pulls/{number}/comments` でCodex（`chatgpt-codex-connector[bot]`）のコメントを確認
- 各コメントについて以下を判定する:
  1. **未返信** → 指摘内容を確認し、対応が必要か判断。必要なら修正コミットまたは Issue 起票、返信してリアクション付与
  2. **返信済みだがリアクション未付与** → 修正コミットの存在を確認し、+1 リアクションを付与
  3. **返信済み・リアクション済み** → 完了。報告不要
- 判定方法: `gh api repos/pooza/mulukhiya-toot-proxy/pulls/{number}/comments --jq` で全コメントを取得し、Codex コメントの `id` に対する `in_reply_to_id` を持つ返信の有無、および Codex コメントへのリアクション（`reactions`）を確認する

⚠ **`pulls/{number}/comments` は行に紐づくレビューコメントしか返さない。**PR 本体のコメントは
`gh api repos/pooza/mulukhiya-toot-proxy/issues/{number}/comments` で別に取る。**open PR も対象に含めること。**

- 他リポジトリ（`ginseng-*` / chubo2）の作業をしている**別セッションが、こちらの PR へ申し送りを置く**ことがある。
  投稿者は Codex ではなく `pooza` なので、bot だけを見ていると丸ごと落ちる
- 2026-08-20 の同期で実際に落とした: PR #4602 に「正本側（pooza/ginseng-style#11 / #12）で 4 cop を無効化したので
  `Minitest/RefutePathExists` の固有緩和を落とせる」という申し送りが 08-19 から置かれていた（b77dd308 で消化）

### 返信とリアクション（旧「Codexレビュー確認」節）

PRマージ後にCodex（chatgpt-codex-connector[bot]）のレビューコメントが遅れて届くことがある。セッション開始時に最近マージされたPRのレビューコメントを確認し、未対応の有益な指摘があれば対応すること。

対応後はCodexのコメントに**返信とリアクションの両方を付与する**: 返信で対応内容（コミットハッシュやIssue番号等）を明記し、コメントに `+1` リアクションを付ける。**両方揃って「完了」**。片方だけではセッション同期時に未完了と判定される。

```bash
# 最近マージされたPRのCodexレビューコメントを確認
gh api repos/pooza/mulukhiya-toot-proxy/pulls/{number}/comments \
  --jq '.[] | select(.user.login == "chatgpt-codex-connector[bot]") | {id, body: .body[:200], path: .path, reactions: .reactions.total_count}'

# リアクション付与（対応済み確定時）
gh api repos/pooza/mulukhiya-toot-proxy/pulls/comments/{comment_id}/reactions -X POST -f content=+1
```

Codex が一時的に停滞して自動指摘が出ないことがある。その場合は`release-review` スキルの 5 観点並列レビューが代替・補完として機能する。

## 5. Sentry の新規イシュー確認

- `sentry-cli issues list` で未解決イシューを確認する（`~/.sentryclirc` に認証トークンとデフォルトプロジェクトが設定済み）
- 各イシューの過去コメント（対応経緯）を確認する: `curl -sH "Authorization: Bearer $TOKEN" https://sentry.io/api/0/issues/{issue_id}/comments/ | python3 -m json.tool`
- 新規・未解決のイシューがあれば内容を確認し、対応が必要か判断する（対応が必要なら GitHub Issue を起票）
- 判断結果や対応経緯はコメントとして記録する: `curl -sX POST -H "Authorization: Bearer $TOKEN" -H "Content-Type: application/json" -d '{"text":"コメント内容"}' https://sentry.io/api/0/issues/{issue_id}/comments/`
- `$TOKEN` は `~/.sentryclirc` の `[auth]` セクションから取得する
- Sentry 未導入のプロジェクトではこのステップをスキップする

⚠⚠ **「新規」だけでなく「コメント 0 のまま滞留しているもの」も見る（2026-09-23 追加・#4543 の結論）。**
この手順は長く**最終発生の新しい順にしか見ていなかった**ので、**静かに立った新種が
一度も判断されないまま残り続けた**。#4543 の起票時点で **27 件中 16 件がコメント 0** だった。

```sh
python3 .claude/skills/sync/scripts/sentry_uncommented.py
```

⚠ **0 件であることを毎回確かめる**（2026-09-23 時点は unresolved 26 件・コメント 0 は 0 件）。
1 件でも出たら、その場で最新イベントの `server_name` / `release` / culprit を開いて判断を書く。
⚠ **判断には必ず「いつの時点の count か」を書く**（[[feedback_sentry-triage-needs-count-snapshot]]）。

## 6. 外部リポジトリの同期確認（chubo2 / ginseng-*）

対象は `pooza/chubo2`（インフラ）と `pooza/ginseng-*`（モロヘイヤが依存する自作 gem 群）。

⚠ **ginseng-\* には専任のセッションがある**（2026-08-20 ユーザー明示）。**こちらが当番のように「担当」しない。**
向こうの open Issue を棚卸ししたり、こちらのマイルストーンへ引き取ったりしない。

⚠⚠ **ただし「Issue を投げて待つ」だけにしない（2026-08-20 ユーザー指示）。**
**ginseng への修正・提案は、なるべく**たたき台を PR として**出す。**Issue だけ出すと、向こうは
「依頼元が PR を出す」と読んで `waiting:pr` で止まる（pooza/ginseng-core#526 で実際に起きた）。
判断・作り直しは向こうに委ねたうえで、動くコードとテストを添える。

- **やること**: たたき台 PR の作成、送った Issue / PR の状況確認、リリースされた gem の
  `bundle update` 追随、申し送りコメントの消化（§4 の PR 本体コメント）
- **やらないこと**: ginseng-\* の open Issue の生死判定・優先度付け・こちらのマイルストーンへの取り込み
- **たたき台 PR の作法**（pooza/ginseng-core#533 / #534 の形）:
  - ⚠ **他セッションのチェックアウトを奪わない。**`~/repos/ginseng-*` は向こうが別ブランチを
    開いていることがあるので、`git worktree add` で隔離した作業ツリーを使う
  - ⚠ **既存の赤と比較して出す。**ginseng-core は実通信・ローカル環境依存で
    **5 failures / 12 errors が常態**（pooza/ginseng-core#508）。「新規の赤ゼロ」を
    main との対比で示す
  - ⚠ **修正前の main で新テストが落ちることを確認**してから出す（回帰テストとして機能するか）
  - 設計判断は「変えて構わない」と明示する。向こうの gem の設計はあちらのもの
- ⚠ **モロヘイヤ側だけ直しても gem が値を捨てて届かないことがある**（#4589 / #4594 で 2 回踏んだ）。
  その場合は「gem へ Issue/PR → 向こうで着地 → `bundle update` → 本体 PR」の順で、**依頼側として**回す

### 6-1. 毎セッション

- `cd ~/repos/chubo2 && git fetch origin` + `git log HEAD..origin/main --oneline` でリモートとの差分を確認
- `docs/infra-note.md` に変更があれば MEMORY.md のインフラセクションに反映が必要か判断
- chubo2 の `gh issue list --state open` で open Issue の変動を確認
- ginseng-\* は**こちらが送った Issue / PR の進捗**と、**下の「ピンのずれ」**だけ見る（一覧の棚卸しはしない）
- **辞書エンドポイントの台帳を回す**（2026-08-27 追加・pooza/chubo2#205）:

  ```sh
  cd ~/repos/chubo2 && ruby tools/dictionary-registry.rb shallu zugoga gomander vulcan --write
  ```

  差分が出たら読む。⚠ **見るのは 🔴 の 2 つだけでよい** — **🔴 直書き**（設定が
  `script.google.com` を直接引いている＝**台帳から辿れないので腐っても気づけない**）と
  **🔴 死亡**（ログ上ずっと空）。**#4658 はこの 2 つが重なった状態**で 2 週間以上
  気づかれなかった。🟡 間欠は #4659 の既知（毎回出る）、⚪ 取得のみは読み辞書の
  正常な姿なので**異常と読まない**

  ⚠⚠ **台帳そのものの整備（スプレッドシートの是正・GAS の V8 移行と再デプロイ）は
  ユーザーが進める（2026-08-28 明示）。**⚠ **生成と差分の報告まではこちらの仕事**だが、
  **是正の段取りを先回りして提案しない。**#4658 の進め方も同じ扱い

#### ginseng-\* のピンのずれを見る（2026-08-21 追加）

⚠⚠ **ginseng-\* は依頼が無くても自走で更新される**（2026-08-21 ユーザー明示）。
`Gemfile.lock` は git gem の **revision 固定**なので、**向こうが直しても `bundle update` するまで
こちらには 1 バイトも届かない**。「Issue が close された」は**取り込み済みを意味しない**。
⚠⚠ **dependabot は `ginseng-*` の PR を出さない（#4702・2026-09-24）。ずれに気づく経路はこの節だけ**なので、
同期のたびに必ず回す。

```sh
ruby .claude/skills/sync/scripts/ginseng_pin_drift.rb
```

⚠⚠ **5.37.0（#4702 / PR #4716）から `Gemfile` は版（タグ）で固定している**
（`ginseng-style` だけは SHA・pooza/ginseng-style#75）。以前のスクリプトは
**lock の revision と main HEAD** を比べていたので、タグで固定した後は
**main にタグ未満のコミットが 1 本でもあると毎回「ずれ」を出す**（ノイズ）。
⚠ 2026-09-10 時点の既知: **ginseng-web だけ v2.0.0 → v3.0.0 のずれ**（破壊的変更・意図して保留）。
⚠ **タグが切られていない main のコミットはこのスクリプトには出ない。**依頼した修正が
着地したかを見るときは `gh api repos/pooza/ginseng-X/compare/<最新タグ>...main` を読む。

- **ずれていたら「何が変わったか」を読む**: `gh api repos/pooza/ginseng-X/compare/<固定中の版>...<最新タグ> --jq '.commits[].commit.message'`。
  ⚠ **モロヘイヤが触る面**（`HTTP` / `Logger` / `Controller` / `TagContainer` / `Environment`）に
  当たるかで判断する
- **判断は 3 択**: ① すぐ取り込む（実害がある・依頼した修正の着地）② 次のマイルストーンで取り込む
  ③ 見送る。**②③ は理由を台帳に 1 行残す**（次の同期で同じ調査をしないため）
- ⚠ **`bundle update`（引数なし）は 8 本まとめて動く。**依頼した修正の取り込みは
  **`bundle update <gem>` と gem 単位で**行う（赤が出たときの切り分けができなくなる）
- ⚠ **取り込んだら `rake lint` と `rake test` を必ず通す。**「向こうが直した」は
  「こちらで動く」ではない。逆向き（gem がこちらの値を捨てる）で 2 回踏んでいる（#4589 / #4594）
- ⚠ **`Gemfile.lock` のルーチン最新化とは別物として扱う。**ルーチンは PR 不要（[[feedback_gemfile-lock-routine]]）
  だが、**自走更新が混じるようになったので差分を読まずに上げない**

### 6-2. 30 日ごとの棚卸し

chubo2 の [docs/infra-note.md](https://github.com/pooza/chubo2/blob/main/docs/infra-note.md) 冒頭にある
「最終棚卸し」の日付を見る。**当日から 30 日以上経過していれば**以下を実行（経過していなければスキップ）。

- **対象は chubo2（インフラ）のみ。**⚠ **ginseng-\* は専任セッションの持ち物なので棚卸ししない**（上の注記）
- chubo2 の open Issue を 1 件ずつ、**コード・コミット・実機と突き合わせて**生死を判定する
- **一覧を眺めるだけでは不十分。** 2026-07-31 の初回棚卸しでは 30 件中 6 件が「既に終わっている」
  または「対象が消滅している」状態で、最古は 5 か月放置されていた（#4488）。実装が chubo-core 側の
  コミットで着地していると、タイトルからは終わっているか分からない
- 判定の取り方の例:
  - レシピ化系 → 該当 cookbook を開いて実装の有無を確認（`git log -- <path>` でコミットも辿る）
  - 移行・撤退系 → 実機に SSH、または `curl` / DNS 解決で新旧の状態を確認
  - ステージング関連 → `docs/infra-note.md` の現況表と突き合わせる。**旧ステージング
    （`drime` + dev04/15/22/23）は退役済み**なので、これらを対象とする Issue は陳腐化している
- close 候補は**証拠を添えて提示する**。close するかどうかの判断はユーザーに残す
- 棚卸しが済んだら `docs/infra-note.md` の「最終棚卸し」を当日に更新してコミット（close 候補が 0 件でも更新する）
- 専用の cloud/cron ジョブは使わない（§8 と同じ理由。スケジュール実行は途中で止まって手で起こす運用に
  なりがちで、セッションに織り込むほうが確実に回る）

### 6-3. ドキュメント・メモリの棚卸し

**インフラ作業は「Mastodon / Misskey / モロヘイヤに触るか」で本セッションと chubo2 セッションに
分かれて依頼されている。セッションメモリは共有されないので、片方のメモリにだけ事実が残ると
もう片方が同じ調査を繰り返す。**

- **一次対策は棚卸しではない。**インフラの調査・変更を終えたら、**その作業の一部として**
  chubo2 の `docs/infra-note.md`（現在の状態・手順・罠・運用方針）または
  `docs/infra-history.md`（日付のある出来事）に落とす。Issue とメモリだけで済ませない。
  `release` スキルの「リリース後の更新」と同じ扱いにする
- 取りこぼしの回収は chubo2 の [docs/doc-maintenance.md](https://github.com/pooza/chubo2/blob/main/docs/doc-maintenance.md) の手順で行う。
  `docs/infra-note.md` 冒頭の「最終ドキュメント棚卸し」が起点。**§6-2 の Issue 棚卸しとは軸が違う**
  （あちらは open Issue の生死、こちらは知見の置き場所）。大きめの作業トラックが終わったとき、
  またはユーザーの指示で回す
- 昇格の判定は**目視でなく grep**。メモリの中の固有名詞を `infra-note.md` / `infra-history.md` に
  投げ、ヒット 0 のものが対象。2026-08-03 の初回実施では `loop6` / `delmulin-misskey` /
  `index_tags_on_name_lower` がいずれもヒット 0 だった（#4512、pooza/chubo2#129）
- 昇格したメモリは**削除せずポインタに書き換える**（正本のパス＋なぜ非自明か）。
  メモリは git 管理外なので消すと復元できない
- **昇格しないもの**: 進め方の好み、提案の抑制（「〇〇を勧めない」）、私的判断。
  これらはセッションごとの作業ルールなので docs に上げない

### 6-4. Annict の API の動きを見る（2026-10-06 追加）

モロヘイヤは Annict の GraphQL API（beta）に依存している（視聴記録・感想投稿・番組表の「話数 ＋」・タグ辞書）。
**Annict は Rails から Go へ書き直している最中**（annict/annict・2025-11 〜）で、手前に Go 版が立ち、
未移行の画面と GraphQL は Rails へ中継されている。API は後回しになっているが、**書き直しが API に及ぶと
こちらが壊れる側にも、#3157（記録の URL の番号が API から取れない）が直る側にも動きうる。**

```sh
ruby .claude/skills/sync/scripts/annict_api_watch.rb
```

- ⚠ **基準（2026-10-06）**: `rails/app/graphql` の直近は **2026-01-28「Canary GraphQL API の実装ファイルを削除」**、
  Go 側に API らしきディレクトリは**なし**。**これと同じなら報告不要**
- 変わっていたら、コミットの中身を読んで、モロヘイヤが使う面（`app/query/annict/*.graphql` の項目・
  認証・エンドポイント）に当たるかを見る。`Record` 型に Web の URL 用の番号が足されていたら #3157 を動かす
- ⚠ **向こうへ要望や不具合報告を出すことは提案しない**（2026-10-06 ユーザー判断: 基本設計を見直してまとめて直す
  つもりだろうから、いま起きていることへの希望を伝えても意味が薄い）。外部 PR は受け付けておらず、窓口は Discord
- ⚠ **Annict の遅さ・タイムアウトは平常として扱う**（#4801）。辞書台帳の `annict/episodes` の失敗数で様子は分かる
- **公式アカウント（`@annict@mastodon.social`）の直近 5 件も同じスクリプトが出す**（2026-10-10 追加・ユーザー提案）。
  障害・仕様変更・開発者向けドキュメントの告知はここに出る。**前回の同期より新しい投稿があれば読む**
  （基準: 最新は **2026-10-06「海外からのリクエストが大量に来ていた影響で繋がりにくかった」**）。
  ⚠ 2026-10-04〜06 のタイムアウト（Sentry `-2X` が 1 日 100〜180 件）の原因はこの投稿で分かった。
  **Sentry の件数が跳ねたら、内訳を掘る前にまずここを見る**

## 7. マイルストーンの状態確認

- `docs/CLAUDE.md` と MEMORY.md に記載された次期マイルストーンの Issue が、実際の GitHub 上の状態（open/closed）と一致しているか確認
- クローズ済みの Issue があれば MEMORY.md から除外し、`docs/CLAUDE.md` も必要に応じて更新

## 8. fedi-test-harness の upstream バージョンチェック

- [harness-verified-versions.yaml](../../../docs/harness-verified-versions.yaml) の `last_checked` を見る。**当日から 4 日以上経過していれば**以下を実行（経過していなければスキップ）:
  - `gh api 'repos/mastodon/mastodon/releases?per_page=15'` と `gh api 'repos/misskey-dev/misskey/releases?per_page=15'` で最新リリースを取得（ローカル `gh` は認証済み）
  - 台帳の `mastodon.verified` / `misskey.verified` より**厳密に新しい** stable、または Mastodon の新しい RC（`vX.Y.Z-rc.N`、ベース版が verified より新しいもの）があるか判定
  - 新しいものがあれば、検証を促す（Mastodon RC=約1週間の RC 期間中／Mastodon stable=リリース直後／Misskey=リリース後数日でデプロイ前）。検証フローは `harness-gate` スキルの「upstream の新しい版の検証」。実検証・bump はその場で着手するか Issue 化するかを相談する
  - 確認したら台帳の `last_checked` を当日に更新してコミット（新規が無くても更新する）
- 専用の cloud/cron ジョブは使わず、この同期手順に織り込む方式（モロヘイヤは作業頻度が高いため十分）。詳細は MEMORY の `feedback_upstream-release-harness-verification`

## 9. MEMORY.md の更新

- 上記で検出した差分（Issue 状態、リリース日の誤り、件数のズレ等）を反映

## 10. 同期結果の報告

- 現在のブランチ・状態、マイルストーンの状況、各確認項目の結果をまとめて報告する
