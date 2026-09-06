$LOAD_PATH.unshift(File.join(File.expand_path('../..', __dir__), 'app/lib'))

# FreeBSD rc.d の daemon(8) 起動では FD 1/2 が no-reader pipe になり、書き込みが
# カーネル buffer 枯渇後に discard される (#4362)。puma initializer と同じく壊れた
# stdio を /dev/null に張り替えて EPIPE / ログ消失を防ぐ。
[$stdout, $stderr].each do |io|
  next if io.tty?
  begin
    io.flush
  rescue Errno::EPIPE, IOError
    io.reopen(File::NULL, 'w')
  end
end

require 'mulukhiya'
require 'syslog/logger'
module Mulukhiya
  daemon = SidekiqDaemon.new
  config = YAML.load_file(daemon.config_cache_path).deep_symbolize_keys
  # ⚠⚠ **中身は SidekiqDaemon.configure_server に置く (#4687)。**
  # `Sidekiq.configure_server` のブロックは **sidekiq の CLI でしか実行されない**
  # (`Sidekiq.server?` が false の環境では yield されない) ため、ここに直接書くと
  # `rake test` でも fedi-test-harness でも puma からも 1 行も走らない。
  # 🔴 **#4687 はそれで CI 緑・harness 両系緑のまま本番の起動で初めて発火した。**
  Sidekiq.configure_server do |sidekiq|
    SidekiqDaemon.configure_server(sidekiq, config)
  end
  Sidekiq::Scheduler.enabled = true
  Sidekiq::Scheduler.dynamic = true
  Sidekiq.schedule = config[:schedule]
end
