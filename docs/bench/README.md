# 計測スクリプト

投稿レイテンシ（#4464）とサーバー性能比較のための計測スクリプト置き場。

## bench_pre_toot.rb

`TaggingDictionary#matches` 相当の単スレッド CPU ベンチ。lbock / gomander / zugoga / shallu の per-core 性能比較に使った。

```sh
ssh pooza@<host> '/usr/local/bin/ruby34 -' < docs/bench/bench_pre_toot.rb
```

2026-07-20 の結果は `docs/CLAUDE.md` の「5.30.0」節を参照。要点は 2 つ。

- `DictionaryTagHandler` の総コストは **12〜15ms** で、是正対象の「投稿に数秒」に三桁足りない
- 本番 Ruby 4.0.5 では lbock と zugoga の per-core は **1.03 倍で実質同等**。gomander だけが 1.55 倍遅い

## cpu_sample.rb

per-core 性能の**定期サンプラ**。Shared プランの隣人輻輳による**分散**を可視化する。

```sh
# 配置
ssh pooza@<host> 'cat > ~/cpu_sample.rb' < docs/bench/cpu_sample.rb
# cron（10 分毎）
*/10 * * * * /usr/local/bin/ruby34 $HOME/cpu_sample.rb
# 結果
ssh pooza@<host> 'cat ~/cpu_sample.tsv'
```

**Ruby は全台 `ruby34`（3.4.9）で揃える。** 本番の実行環境は 4.0.5 + YJIT だが、目的が「時間帯による揺れの検出」であり、隣人輻輳はホスト側の性質なので版が違っても検出できる。gomander には 4.0.5 が未導入で、条件を揃えるほうを優先する。**絶対性能の結論には使わない**（それは `bench_pre_toot.rb` の 4.0.5 系列で採る）。

対象は lbock（キュアスタ！本番）/ zugoga（Linode 実績機）/ gomander（移行先）。

知りたいことは 2 つ。

1. gomander が「安定して遅いハズレ」なのか「揺れている」のか
2. zugoga と lbock が**ニチアサ実況の時間帯**に劣化するか（＝ Shared 契約が実況ウィンドウで牙を剥くか）

2026-07-20 時点の基準値（`raw_cpu`、3.4.9・単発）: lbock 1408ms / zugoga 1624ms / shallu 2056ms / gomander 2515ms。
