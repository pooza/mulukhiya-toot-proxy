# 計測スクリプト

投稿レイテンシ（#4464）とサーバー性能比較のための計測スクリプト置き場。

## verify_host.sh — Linode ホストの当たり外れ判定

gomander は「遅い物理ホストに着地した個体」と特定されている（pooza/chubo2#68）。**作り直した直後にこれを流して着地の成否を判定する。**

```sh
docs/bench/verify_host.sh gomander.b-shock.co.jp
# exit 0 = 合格 / 1 = 不合格（作り直し直し）/ 2 = 実行エラー
```

判定は 2 つ。**① `host_uuid` が既知の遅いホスト（`a6f7baf2…`）と違うこと ② チャンクベンチの `min` が 15ms 未満であること。**

2026-07-20 の実測値は zugoga 14.22 / lbock 15.11 / **gomander 20.05** ms。判定が両方向で効くことは、遅い側（gomander→不合格）と速い側（zugoga→合格）の両方で確認済み。

## chunk_bench.c — 「素で遅い」と「奪われている」の切り分け

3M 回の整数ループを 400 チャンクに分割し、ms の分布を出す。

- **`min`** … 誰にも邪魔されない最良ケース。**ここが遅ければホストの素の速度が遅い**
- **`max/min`** … テール。大きければ隣人輻輳（steal）を食らっている

Ruby を通さない素の C なので、Ruby のビルド差や OS メジャーの差を交絡から外せる。gomander の特定はこれが決め手になった（min が 1.41 倍遅く、かつ max/min 1.04 でテール皆無＝競合ではなく素の速度）。

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

**2026-07-20 に lbock / zugoga / gomander の 3 台へ仕込み済み**（cron `*/10`、初回発火・TSV 追記まで確認）。07-26（日）のニチアサを捕まえる目的。

```sh
# 配置
ssh pooza@<host> 'cat > ~/cpu_sample.rb' < docs/bench/cpu_sample.rb
# cron（10 分毎）
*/10 * * * * /usr/local/bin/ruby34 $HOME/cpu_sample.rb
# 結果
ssh pooza@<host> 'cat ~/cpu_sample.tsv'
# 撤収（観測が済んだら）
ssh pooza@<host> 'crontab -l | grep -v cpu_sample.rb | crontab -'
```

**Ruby は全台 `ruby34`（3.4.9）で揃える。** 本番の実行環境は 4.0.5 + YJIT だが、目的が「時間帯による揺れの検出」であり、隣人輻輳はホスト側の性質なので版が違っても検出できる。gomander には 4.0.5 が未導入で、条件を揃えるほうを優先する。**絶対性能の結論には使わない**（それは `bench_pre_toot.rb` の 4.0.5 系列で採る）。

対象は lbock（キュアスタ！本番）/ zugoga（Linode 実績機）/ gomander（移行先）。

知りたいことは 2 つ。

1. gomander が「安定して遅いハズレ」なのか「揺れている」のか
2. zugoga と lbock が**ニチアサ実況の時間帯**に劣化するか（＝ Shared 契約が実況ウィンドウで牙を剥くか）

2026-07-20 時点の基準値（`raw_cpu`、3.4.9・単発）: lbock 1408ms / zugoga 1624ms / shallu 2056ms / gomander 2515ms。
