# TaggingDictionary#matches 相当の単スレッド CPU ベンチ
# lbock / gomander の per-core 性能を同一条件で比較する目的。
# 実辞書は使わず、語数・語長の分布だけ模した合成辞書で決定論的に回す。

require 'benchmark'

WORDS = 3000
SAMPLE = <<~TEXT * 3
  今日のニチアサ実況です。プリキュアの変身バンクが最高だった。
  日曜朝はやっぱりこれ。#precure #nichiasa 来週も見ます。
TEXT

# 語長 2〜12 の合成辞書（実辞書の「長い語から先に」順序性を再現するため長さ降順）
words = (0...WORDS).map do |i|
  len = 2 + (i % 11)
  base = %w[プリキュア 変身 バンク 実況 日曜 朝 光 星 空 花 風][i % 11]
  (base * ((len / base.length) + 1))[0, len] + i.to_s(36)
end
words.sort_by! { |w| -w.length }

report = {}

# 1. Regexp コンパイル（short? が照合のたびに ~3000 個再コンパイルしている問題の実コスト）
report['regexp_compile_3000'] = Benchmark.realtime do
  10.times { words.each { |w| Regexp.new("^[^\\p{Han}]{,#{w.length}}$") } }
end / 10

# 2. 事前コンパイル済みパターンでのスイープ（matches の本体: match? + gsub 消し込み）
patterns = words.map { |w| [Regexp.new(Regexp.escape(w)), w] }
report['sweep_3000_x1'] = Benchmark.realtime do
  20.times do
    text = SAMPLE.dup
    patterns.each do |re, _w|
      next unless text.match?(re)
      text = text.gsub(re, '')
    end
  end
end / 20

# 3. addition_tags が 1 投稿で 3 回呼ばれる現状の実コスト
report['sweep_x3_current'] = report['sweep_3000_x1'] * 3

# 4. Marshal load（辞書を投稿ごとに読み直している問題）
blob = Marshal.dump(words.each_with_object({}) { |w, h| h[w] = { words: [w], pattern: w } })
report['marshal_load'] = Benchmark.realtime do
  50.times { Marshal.load(blob) }
end / 50

# 5. 素の整数演算（CPU 世代差の素点）
report['raw_cpu'] = Benchmark.realtime do
  x = 0
  30_000_000.times { |i| x = (x + i) % 1_000_003 }
end

puts "host=#{`hostname`.strip} ruby=#{RUBY_VERSION} ncpu=#{`sysctl -n hw.ncpu`.strip}"
puts "cpu=#{`sysctl -n hw.model`.strip}"
report.each { |k, v| puts format('%-22s %8.1f ms', k, v * 1000) }
