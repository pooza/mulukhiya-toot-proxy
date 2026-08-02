# 計測データ

**lbock は 2026-07-31 に解約されて消えるため**、ホスト上にしか無かった計測結果をここへ退避したもの（#4464 / pooza/chubo2#68）。以後の分析はこのファイルを正本とする。移行後の gomander 側も、syslog が日次ローテーションで流れる前に同じ形で退避する。

## handler_profile-lbock-20260723-20260726.jsonl.gz

`HandlerProfile#flush`（`app/lib/mulukhiya/handler_profile.rb`）が lbock の syslog へ出した 1 イベント 1 行の JSON。syslog 由来の行頭を `time` / `host` フィールドへ畳んだうえで時刻順に並べ替えてある。

- **320 行**（07-23 29 / 07-24 27 / 07-25 46 / **07-26 218**）
- 出力は `profile.handler.threshold: 1.0`（秒）超のイベントだけ。**速かった投稿は入っていない**ので、母集団を「全投稿」と読み違えないこと
- ハンドラは `profile.handler.floor: 0.001`（秒）未満を落としてある
- 本文は記録していない（`payload` は文字数・URL 数・ナウプレ有無・添付数のみ）
- 計装が入ったのは 07-23 05:40 の再起動から（当初計画の 07-24 より 1 日早い）

集計:

```sh
DATE=2026-07-26 HOURS=8-9 ruby docs/bench/analyze_handler_profile.rb \
  docs/bench/data/handler_profile-lbock-20260723-20260726.jsonl.gz
```

## handler_profile-gomander-20260729.jsonl.gz

**カットオーバー翌日（移行後の初データ）。** 形式・注意点は上と同じ。

- **51 行**（00:07〜20:23、`pre_toot` 19 / `pre_webhook` 32）
- **19〜21 時台は少人数の実況**（ローカル投稿 32 件）。この窓だけ見ると `p50=1.1s / max=1.6s / min=1.0s` で、**lbock の最速 4.3s（07-26 ニチアサ）にすら届かない**＝分布が重ならない
- **`localhost` の HEv2 305ms が消えたことの裏取りになっている。** 処理内容が変わっていない `spoiler` と `user_config_command` の平均が lbock の 0.65s / 0.63s（≒ 305ms × 2）から **0.020s / 0.016s** へ落ちた。RAM やプランの効果ではない（`docs/CLAUDE.md`「投稿レイテンシ」節）
- 残る 1.0〜1.6s は `dictionary_tag` + `remote_tag` で 87%。HTTP 待ちは全体の 0.3% しかない＝**辞書スキャンの CPU 時間**（#4463 / #4465）
- ⚠ **日全体で見ると `p90=3.6s / max=6.5s` になるが、これは実況の値ではない。** 上位は 00:14:07 に同時発火した `pre_webhook` 5 件で、並行実行時に `dictionary_tag` / `remote_tag` が 3s 級へ膨らむ。**単発の遅さではなく同時実行時の CPU 競合**なので、実況の投稿レイテンシと混ぜて読まないこと

```sh
DATE=2026-07-29 HOURS=19-21 ruby docs/bench/analyze_handler_profile.rb \
  docs/bench/data/handler_profile-gomander-20260729.jsonl.gz
```

## handler_profile-gomander-20260802.jsonl.gz

**gomander で初のニチアサ実況＝本命の突き合わせ。** 形式・注意点は上と同じ。

- **99 行**（00:07〜09:03）。うち実況の 08 時台が 80 行（`pre_toot` 79 / `pre_webhook` 1）
- 08 時台のローカル投稿は **130 件**で、**07-26（lbock）の 133 件とほぼ同量**＝そのまま比較できる（両日とも移行後の gomander の `statuses` から取得）
- 08 時台: `min=1.0 / p50=1.1 / p90=1.5 / max=1.9s`。lbock 07-26 08 時台は `min=4.3 / p50=4.8 / p90=5.5 / max=6.3s`
- ⚠ **閾値 1.0 秒が分布を切っている。** lbock は最速 4.3 秒＝ほぼ全件が閾値の上（119/133＝89%）だったが、gomander は **61%（79/130）しか記録対象にならない**。**両日の p50 を同じ母集団の代表値として並べないこと**。改善幅を語るときは 1 秒超の割合（89% → 61%）を併記する
- 処理内容の変わっていない `spoiler` / `user_config_command` が 0.652s / 0.632s → **0.026s / 0.023s**。305ms × 接続回数の消滅が実況の実負荷でも再現した
- 残る所要の 76% は `dictionary_tag` 0.457s + `remote_tag` 0.454s。HTTP 待ちは 0.1%＝**辞書スキャンの CPU 時間**（#4463 / #4465 / #4482）
- 交絡因子（早朝のボット流入 / `tags` インデックス是正）はいずれもこの比較に効いていない。詳細は `docs/CLAUDE.md`「2026-08-02 実測」節

```sh
DATE=2026-08-02 HOURS=8-8 ruby docs/bench/analyze_handler_profile.rb \
  docs/bench/data/handler_profile-gomander-20260802.jsonl.gz
```

## cpu_sample-{lbock,zugoga,gomander}-20260726.tsv

`docs/bench/cpu_sample.rb` が `*/10` の cron で追記した per-core サンプル。`時刻 / ホスト名 / raw_cpu ミリ秒 / load1` のタブ区切り。**07-26 21:30 時点のスナップショット**で、zugoga と gomander では以後も実機側で伸び続ける（lbock だけがここで打ち止め）。

- lbock / zugoga … 07-20 10:10 〜 07-26 21:30（934 行）
- gomander … 07-23 05:23 〜 07-26 21:30（530 行、作り直しに伴い再設置）

Ruby は 3 台とも条件統一のため `ruby34`（3.4.9・YJIT なし）で、本番の実行条件（Ruby 4.0.5 + YJIT）とは異なる。**絶対性能の結論には使わない**（`docs/CLAUDE.md`「本番 Ruby での per-core 再測定」参照）。

サンプラは **撤収済み**（2026-08-02 に gomander / zugoga とも cron・TSV の不在を実機確認）。lbock は解約済み。
