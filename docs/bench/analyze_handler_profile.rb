# docs/bench/data/handler_profile-*.jsonl.gz を集計する (#4464)
#   ruby docs/bench/analyze_handler_profile.rb docs/bench/data/handler_profile-lbock-*.jsonl.gz
#   DATE=2026-07-26 HOURS=8-9 ruby docs/bench/analyze_handler_profile.rb ...   # 実況ウィンドウだけ
require 'json'
require 'zlib'

from, to = (ENV['HOURS'] || '0-23').split('-').map(&:to_i)
date = ENV.fetch('DATE', nil)

rows = ARGV.flat_map do |path|
  body = path.end_with?('.gz') ? Zlib::GzipReader.open(path, &:read) : File.read(path)
  body.each_line.map {|line| JSON.parse(line)}
end
rows.select! do |row|
  (from..to).cover?(row['time'][11, 2].to_i) && (date.nil? || row['time'].start_with?(date))
end

abort "no rows in #{date} #{from}-#{to}時台" if rows.empty?

def cell(value, width, decimals = nil)
  return value.to_s.rjust(width) unless decimals
  return ("%.#{decimals}f" % value).rjust(width)
end

seconds = rows.map {|row| row['seconds']}.sort
kinds = rows.group_by {|row| row['profile']}.map {|k, v| "#{k}=#{v.size}"}.join(' ')
puts "対象 #{rows.size} 件（#{date || '全日'} #{from}〜#{to}時台）"
puts "イベント種別: #{kinds}"
puts [
  "総所要 秒: min=#{cell(seconds.first, 0, 1)}",
  "p50=#{cell(seconds[seconds.size / 2], 0, 1)}",
  "p90=#{cell(seconds[(seconds.size * 0.9).to_i], 0, 1)}",
  "max=#{cell(seconds.last, 0, 1)}",
].join(' ')

agg = Hash.new {|h, k| h[k] = {count: 0, seconds: 0.0, max: 0.0, http: 0, http_seconds: 0.0}}
rows.each do |row|
  row['handlers'].each do |handler|
    entry = agg[handler['handler']]
    entry[:count] += 1
    entry[:seconds] += handler['seconds']
    entry[:max] = [entry[:max], handler['seconds']].max
    entry[:http] += handler['http_count']
    entry[:http_seconds] += handler['http_seconds']
  end
end

puts
puts ['handler'.ljust(24), '件数'.rjust(5), '合計s'.rjust(7), '平均s'.rjust(7),
  '最大s'.rjust(7), 'HTTP回'.rjust(6), 'HTTP秒'.rjust(7)].join(' ')
agg.sort_by {|_, v| -v[:seconds]}.each do |name, v|
  puts [
    name.ljust(24),
    cell(v[:count], 5),
    cell(v[:seconds], 7, 1),
    cell(v[:seconds] / v[:count], 7, 3),
    cell(v[:max], 7, 3),
    cell(v[:http], 6),
    cell(v[:http_seconds], 7, 1),
  ].join(' ')
end

total = rows.sum {|row| row['seconds']}
http = rows.sum {|row| row['handlers'].sum {|handler| handler['http_seconds']}}
puts
puts "合計イベント秒=#{cell(total, 0, 1)} / うち HTTP 待ち=#{cell(http, 0, 1)}" \
  " (#{cell(100.0 * http / total, 0, 1)}%)"
