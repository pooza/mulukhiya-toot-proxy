# 計測スクリプト

投稿レイテンシ（#4464）とサーバー性能比較のための計測スクリプト置き場。

## stlf_probe.c — 個体の健全性チェック（必ず参照ホストと比べる）

旧 gomander で観測された病状は **「同一アドレスへの store→load だけ 6 倍遅い」**（pooza/chubo2#68）。store-to-load forwarding が効いていない形で、これを直接測る。

```sh
docs/bench/verify_host.sh <target> [reference]   # 構築後（FreeBSD 機）
docs/bench/probe_host.sh <target> [reference]    # 構築前（素の Linux イメージ）
# exit 0 = 参照と同等 / 1 = 参照より明らかに遅い / 2 = 実行エラー・判定不能
```

### ⚠ 絶対閾値では判定できない（#4476）

**`ratio` は同一ツールチェーンで測ったときだけ比較できる。** 同じソース・同じ `-O2` でも、コンパイラを変えるだけで健全な機体の ratio が 3〜5 倍動く。

| 版 | gcc 14.2 | clang | 備考 |
| --- | --- | --- | --- |
| 現行（分母＝定数除算） | 0.113 | 0.177 | どちらも同じ健全なマシン |
| 分母＝別アドレス・非連鎖 | 1.692 | **5.565** | clang が健全な機体を異常判定 |
| 分母＝距離 16 の連鎖 | 0.737 | **3.629** | 同上 |

**分母を変えても直らない。** 分子（同一アドレスへの store→load）の絶対時間からしてコンパイラ依存だから。

| | gcc | clang |
| --- | --- | --- |
| same address | 13.5 ms | **39.2 ms** |

30M 回で 13.5ms ≒ 1.2 cycle/iter は forwarding の遅延（4〜5 cycle）より速い。つまり測っているのは CPU の特性よりコード生成の差で、不変な絶対閾値は置けない。

Codex も Xeon 8370C で現行版が 0.519（GCC 13）/ 0.552（Clang 17）＝異常判定になったと報告している。

### だから相対比較にする

旧 gomander の切り分け（0.569 対 他 0.1）が有効だったのは、**4 台すべてを FreeBSD の clang・同一ソースで測った相対比較**だったから。スクリプトも同じソースを両方へ送って測り、比だけを見る。

- **2.0x 以下** … 同等（健全な 4 台の実測は 0.098〜0.153 で 1.6 倍に収まる）
- **3.0x 以上** … 異常（旧 gomander は 5.8 倍）
- 参照が測れなければ**合否を出さない**（絶対値で断じない）
- **両者の `cc` が違えば合否を出さない**（`verify_host.sh` は各機体でビルドするため、同一ツールチェーンかどうかを毎回検査する。`probe_host.sh` は手元の 1 バイナリを配るので検査不要）

実測（2026-07-21）: gomander vs zugoga = 1.27x、lbock vs zugoga = 1.65x（Intel Xeon 対 AMD EPYC でも同等に収まる）。

### 捨てた判定基準（#4471）

かつては `host_uuid` とチャンクベンチの `min` で判定していたが、どちらも無効。

- **`host_uuid` が既知の遅いホストと違うこと** — 旧 gomander の遅さを物理ホストのせいと見ていたが、**Cold Resize で `host_uuid` が変わっても数字が動かず反証された**。そもそも既知の 1 台と UUID を比べる方式では「別の遅い個体」を検出できない
- **チャンクベンチの `min` が 15ms 未満であること** — **C の速度は Ruby の速度を予測しない**。新 gomander は C では lbock より 6% 速いのに Ruby では 10% 遅い。生スループットで門番をすると誤った結論に導く

**C ベンチは健全性判定にだけ使い、性能の優劣には使わない。**

インスタンスを引き直す判断は stlf_probe が異常を示したときだけ。per-core 数％〜十数％の差では引き直さない（CPU 世代はプランとリージョンで決まる）。

## chunk_bench.c — 「素で遅い」と「奪われている」の切り分け

3M 回の整数ループを 400 チャンクに分割し、ms の分布を出す。

- **`min`** … 誰にも邪魔されない最良ケース。**ここが遅ければホストの素の速度が遅い**
- **`max/min`** … テール。大きければ隣人輻輳（steal）を食らっている

Ruby を通さない素の C なので、Ruby のビルド差や OS メジャーの差を交絡から外せる。旧 gomander の切り分けで「競合ではなく素の速度が遅い」と言えたのはこれによる（min が 1.41 倍遅く、かつ max/min 1.04 でテール皆無）。

**ただし合否判定には使わない**（上記「捨てた判定基準」参照）。切り分けの道具であって門番ではない。`verify_host.sh` は参考値として出力するだけ。

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
