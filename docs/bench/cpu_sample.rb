# per-core CPU 性能の定期サンプラ
# 目的: Shared プランの隣人輻輳による分散を可視化する。
#   - gomander が「安定して遅いハズレ」か「揺れている」かの判定
#   - zugoga / lbock がニチアサ実況の時間帯に劣化するかの観測
# 2026-07-20 の単発ベンチ (docs/bench/bench_pre_toot.rb の raw_cpu) と
# 同じ 30M 回ループなので、当日の基準値と直接比較できる。
#   lbock 1408ms / zugoga 1624ms / shallu 2056ms / gomander 2515ms
require 'benchmark'

LOG = File.expand_path('~/cpu_sample.tsv')

elapsed = Benchmark.realtime do
  x = 0
  30_000_000.times {|i| x = (x + i) % 1_000_003}
end

load1 = begin
  `uptime`[/load averages?: ([\d.]+)/, 1]
rescue StandardError
  nil
end

File.open(LOG, 'a') do |f|
  f.flock(File::LOCK_EX)
  f.puts([
    Time.now.strftime('%Y-%m-%dT%H:%M:%S%z'),
    `hostname`.strip,
    '%.1f' % (elapsed * 1000),
    load1,
  ].join("\t"))
end
