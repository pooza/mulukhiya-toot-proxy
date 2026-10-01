---
name: release
description: モロヘイヤの通常リリース（develop → main・タグ・本番デプロイ・リリース後の更新）とホットフィックスの手順。ユーザーが「リリースしましょう」などと明示したときだけ使う。
disable-model-invocation: true
---

# リリース手順

⚠ この手順の正本はこのファイル（#4731 で `docs/CLAUDE.md`「リリース運用」から移した）。
バージョニング方針・マイルストーン管理・リリースノート・Dependabot 運用は手順ではなく文脈なので `docs/CLAUDE.md` に残してある。
⚠ **外向きの操作（マージ・タグ・本番デプロイ）を含む。**各段はユーザーの指示を確かめてから進める。

## 通常リリース手順

1. **マイルストーンのIssueをすべて消化**
2. **リリース前レビュー**: `/release-review` の 5 観点並列レビューを実施。⚠ **指摘の行き先は深刻度と工数の 2 軸で決める**（`release-review` スキルの「指摘の行き先」）。本リリースで直すのは必修（赤）のみ。
   ⚠⚠ **ここで必ず止まる。**`release-review` は `disable-model-invocation: true` なので、この手順からは起動できない。
   ユーザーに `/release-review` の実行を頼み、レビューが終わって赤が片付くまで 3 以降へ進まない。**レビューを飛ばして先へ進むことはしない**
3. **セキュリティレビュー**: Dependabotアラート確認、`bundle update`、bundler-audit実行。問題があれば修正コミット
4. **harness 実走（省略不可）**: chubo2 fedi-test-harness で `develop` の HEAD を実走し、**Mastodon 系・Misskey 系の両方で 0 failures / 0 errors** を確認する。手順は `harness-gate` スキル。**CI の緑はこのゲートの代わりにならない**（CI は実サーバーを持たないため、アカウント依存のテスト 300 件超が omission のまま `100% passed` と出る。#4503）
5. **ステージング検証（省略不可）**: `develop` をステージング全4台（dev24 美食丼 / dev25 キュアスタ！ / dev26 デルムリン丼 = Mastodon、dev27 ダイスキー = Misskey）にデプロイし、ヘルスチェック・`/mulukhiya/api/about`・WebUI を目視確認する。緊急ホットフィックス以外で省略しない（5.7.0 で省略 → #4159 が発生した教訓）。※旧ステージング（dev04/15/22/23 + drime）は退役済み。現行の Proxmox ステージング構成は chubo2 `docs/infra-note.md`「ステージング」節を正とする
6. **バージョンバンプ**: `config/application.yaml` の `/mulukhiya/version` を更新
7. **リリースPR作成**: `develop` → `main` へPRを作成
8. **CI緑を確認してマージ**: `gh run list` でステータス確認、`in_progress` なら `gh run watch` で待つ。コードが同一でも CI 結果を踏んでからマージする
9. **タグ・リリースノート作成**: `gh release create vX.Y.Z --target main --title "X.Y.Z"`。フォーマットは [release-notes-template.md](../../../docs/release-notes-template.md) 参照
10. **本番デプロイ**: 全サーバーにデプロイ（sidekiq → puma → listener の順で再起動。monit停止 → restart → monit開始）
11. **リリース後の更新**:
    - docs/CLAUDE.md: 「開発中」→「リリース済み」に変更、次バージョンのセクション追加。**直近 3 マイナーのみ残し、4 マイナー前以前は [archive/release-history.md](../../../docs/archive/release-history.md) へ移動する**（例: 5.20.0 リリース時に 5.17.x をアーカイブへ）
    - Wiki: リリース内容に応じて [Wiki](https://github.com/pooza/mulukhiya-toot-proxy/wiki) の更新が必要か確認（設定変更、API追加、廃止機能など）。**当該バージョンだけでなく直近 2〜3 バージョン分の反映漏れも合わせてチェックする**
    - インフラノート（`pooza/chubo2` の `docs/infra-note.md`）: 作業履歴セクションにデプロイ記録を追記（デプロイ日・バージョン・主な変更内容・特記事項）
    - MEMORY.md: リリース履歴・インフラセクションを同期
12. **小粒の掃除**: `release-review` スキルの「指摘の行き先」の②（その場で直せる規模・`size:S`）に溜めたものを **1 PR** で落とす。⚠ **リリース準備の最中にやらないこと**——触ればステージング検証と harness をやり直しになる（5.36.0 で赤 1 件を直したときに実際に踏んだ）。⚠ **次のマイルストーンが始まる前**なら、その周回のステージング検証で一緒に見られる

## ホットフィックス手順

緊急パッチリリースの手順。通常リリースと異なり、develop → main マージではなく main に直接コミットする場合がある。

1. **バージョンバンプ**: `config/application.yaml` の `/mulukhiya/version`（410行目付近）を更新
2. **コミット・プッシュ**: develop（またはmain）にコミットしてプッシュ
3. **mainへマージ**: developで作業した場合は main へPRを作成しマージ
4. **タグ・リリースノート作成**: `gh release create vX.Y.Z --target main --title "X.Y.Z"`
5. **本番デプロイ**: 全サーバーにデプロイ（monit停止 → restart → monit開始）
6. **docs/CLAUDE.md 更新**: リリース済みセクションに追記
7. **Wiki 確認**: リリース内容に応じて [Wiki](https://github.com/pooza/mulukhiya-toot-proxy/wiki) の更新が必要か確認する（設定変更、API追加、廃止機能など）
8. **インフラノート更新**: `pooza/chubo2` の `docs/infra-note.md` 作業履歴セクションにデプロイ記録を追記
9. **develop へ戻す**: main から切った場合は `main` を `develop` へマージする PR を出す。
   衝突は `config/application.yaml` の version 行だけになるのが普通で、**develop 側の版を採る**

⚠⚠ **9 を飛ばすと、次のリリースでホットフィックスが消える。**5.37.1（#4733 の HEIF 遮断）は
develop へ戻しておらず、5.38.0 のリリース前レビューで初めて気づいた（2026-09-25）。そのまま進めていれば
**harness もステージングも本番と別物を検証**し、`develop → main` のマージで遮断が外れていた。
5.32.1 は戻っていたので、手順ではなく記憶に頼っていたことになる。

バージョンが記載されている場所:

- **`config/application.yaml`** `/mulukhiya/version` — **唯一の正本**。`/mulukhiya/api/about` 等で参照される
