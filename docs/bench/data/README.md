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

**本命は 08-02（日）のニチアサ**。同じ手順でもう一度採取し、`handler_profile-lbock-20260723-20260726.jsonl.gz` の 07-26 8〜10 時台と突き合わせる。

## cpu_sample-{lbock,zugoga,gomander}-20260726.tsv

`docs/bench/cpu_sample.rb` が `*/10` の cron で追記した per-core サンプル。`時刻 / ホスト名 / raw_cpu ミリ秒 / load1` のタブ区切り。**07-26 21:30 時点のスナップショット**で、zugoga と gomander では以後も実機側で伸び続ける（lbock だけがここで打ち止め）。

- lbock / zugoga … 07-20 10:10 〜 07-26 21:30（934 行）
- gomander … 07-23 05:23 〜 07-26 21:30（530 行、作り直しに伴い再設置）

Ruby は 3 台とも条件統一のため `ruby34`（3.4.9・YJIT なし）で、本番の実行条件（Ruby 4.0.5 + YJIT）とは異なる。**絶対性能の結論には使わない**（`docs/CLAUDE.md`「本番 Ruby での per-core 再測定」参照）。
