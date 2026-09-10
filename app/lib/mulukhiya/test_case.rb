require 'sidekiq/testing'
require 'rack/test'
require 'timecop'
require 'webmock/test_unit'
WebMock.allow_net_connect!

module Mulukhiya
  class TestCase < Ginseng::TestCase
    include Package
    include SNSMethods

    def teardown
      config.reload
      @handler&.clear
      Timecop.return
      WebMock.allow_net_connect!
    end

    def account
      @account ||= account_class.test_account
      return @account
    rescue => e
      e.log
      return nil
    end

    def test_token
      return account_class.test_token
    rescue => e
      e.log
      return nil
    end

    def http
      @http ||= HTTP.new
      return @http
    end

    # chubo2 fedi-test-harness 駆動の run か。harness の構造的未提供（デーモン層・webhook・
    # streaming・nodeinfo・seed 等）を omit する条件を、本番/フルスタックの実退行と切り分ける
    # ためのゲート。非 harness では症状が出たら omit せず実アサートで落とす (#4447)。
    def harness?
      return TestHarness.active?
    end

    def self.load(cases = nil)
      ENV['TEST'] = Package.full_name
      TestHarness.apply!
      invalidate_shared_caches
      Sidekiq::Testing.fake!
      file_map(cases).each do |name, path|
        raise 'disabled' if name.end_with?('_handler') && Handler.create(name).disable?
        raise 'disabled' if name.end_with?('_worker') && Worker.create(name).disable?
        puts "+ case: #{name}" if Environment.test?
        require path
      rescue => e
        puts "- case: #{name} (#{e.message})" if Environment.test?
      end
    end

    # プロセスをまたいで居座る共有キャッシュを、スイート開始時に既知の状態へ戻す。
    #
    # ⚠ **「実走の前に手で UNLINK する」を手順書に書くだけでは弱い (#4583)。**
    # タグ辞書は Redis に残り、テストの結果が「前に一度回したか」で変わっていた。
    # 人間が手順を踏み忘れても効くよう、スイートのロードに織り込む。
    # `report_error` のデッドマン（#4693）の窓を開け直す。
    #
    # ⚠⚠ **抑止は型ごとに Redis へ残る。**同じ型を扱うテストが 2 本以上あると、
    # **後のテストが「抑止されている」状態から始まって順序依存になる**。
    # 「実際に alert すること」を見るテストは、必ずこれを通してから測る。
    # ⚠ キーは `<prefix>/<型>/<発生源>` (#4693・PR #4712 の Codex P2)。
    # テストからは発生源を特定しにくいので、接頭辞で総なめする。
    # ⚠ **プロセス内の抑止も消す**（Redis に書けないときの受け皿・5.37.0 の赤）。
    # 片方だけ消すと、Redis 側を空にしても前のテストの印がプロセスに残る。
    def clear_alert_throttle(*classes)
      classes.each do |klass|
        LocalAlertThrottle.clear("#{Controller::ALERT_THROTTLE_KEY_PREFIX}/#{klass}")
      end
      redis = Redis.new
      classes.each do |klass|
        prefix = "#{Controller::ALERT_THROTTLE_KEY_PREFIX}/#{klass}"
        redis.keys("#{prefix}*").each {|key| redis.unlink(key)}
      end
    rescue Ginseng::Redis::Error
      nil
    end

    def self.invalidate_shared_caches
      TaggingDictionary.invalidate_cache
    rescue => e
      # Redis 未起動などで落ちても、ここでスイート全体を止めない。実際に辞書を
      # 触るテストがその場で落ちる。
      e.log
    end

    def self.names(cases = nil)
      return file_map(cases).keys.to_set
    end

    def self.file_map(cases = nil)
      finder = Ginseng::FileFinder.new
      finder.dir = dir
      finder.patterns.push('*.rb')
      all = finder.exec.to_h {|path| [File.basename(path, '.rb'), path]}
      return all unless cases
      targets = cases.split(',').map(&:underscore)
        .map {|v| [v, "#{v}_test", v.sub(/_test$/, '')]}.flatten.compact
      return all.slice(*targets)
    end

    def self.dir
      return File.join(Environment.dir, 'test')
    end
  end
end
