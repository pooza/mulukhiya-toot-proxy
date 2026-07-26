# `localhost` への TCP 接続が Happy Eyeballs v2 で遅延していないか検出する (#4481)
#
# Ruby 3.4 以降の TCPSocket.new は HEv2 で A / AAAA を並行解決する。/etc/hosts に
# `::1 localhost` が無いホストでは AAAA だけ DNS へ出て行き、その決着を待つあいだ
# 固定ディレイ（実測 305ms）を払う。lbock ではこれが投稿レイテンシの主因だった。
#
#   ssh pooza@<host> '/usr/local/bin/ruby34 -' < docs/bench/probe_localhost_connect.rb
#
# 判定: localhost が 127.0.0.1 より 50ms 以上遅ければ地雷を踏んでいる。
# 対策は /etc/hosts へ `::1 localhost` を足すか、DSN をホスト名でなく IP で書くか。
require 'socket'

TARGETS = [6379, 6432, 5432].freeze # redis / pgbouncer / postgres
THRESHOLD = 0.05

def realtime(count, &)
  started = Process.clock_gettime(Process::CLOCK_MONOTONIC)
  count.times(&)
  return (Process.clock_gettime(Process::CLOCK_MONOTONIC) - started) / count
end

def connect(host, port, count = 5)
  return realtime(count) {TCPSocket.new(host, port).close}
rescue SystemCallError
  return nil
end

def render(seconds)
  return '     -' unless seconds
  return "#{'%.1f' % (seconds * 1000)} ms".rjust(9)
end

mapped = File.read('/etc/hosts').match?(/^::1\s.*localhost/)
puts "host=#{`hostname`.strip} ruby=#{RUBY_VERSION}"
puts "/etc/hosts の ::1 localhost: #{mapped ? 'あり' : 'なし'}"
puts
puts ['port'.ljust(6), 'localhost'.rjust(9), '127.0.0.1'.rjust(9), '判定'].join(' ')

failed = false
TARGETS.each do |port|
  by_name = connect('localhost', port)
  by_addr = connect('127.0.0.1', port)
  slow = by_name && by_addr && (by_name - by_addr) > THRESHOLD
  failed ||= slow
  verdict = if by_name.nil? || by_addr.nil?
    '未使用'
  else
    slow ? 'HEv2 の遅延あり' : 'OK'
  end
  puts "#{port.to_s.ljust(6)} #{render(by_name)} #{render(by_addr)} #{verdict}"
end

exit(failed ? 1 : 0)
