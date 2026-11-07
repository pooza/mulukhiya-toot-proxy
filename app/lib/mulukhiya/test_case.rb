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

    # 外部への通信を止め、harness の SNS だけ通す。`allow_localhost` だけだと、
    # localhost でない harness（Akkoma のステージング dev29・#4566）を止めてしまう。
    def disable_net_connect_except_harness!
      allow = []
      if harness? && (url = config["/#{Environment.controller_name}/url"] rescue nil)
        allow.push(Ginseng::URI.parse(url).host)
      end
      WebMock.disable_net_connect!(allow_localhost: true, allow:)
    end

    # ⚠⚠ **ファイルを読む本体は core に任せる（#4876・pooza/ginseng-core#696）。**以前はここに写しを
    # 持っていたので、読めなかったテストファイルが `- case:` の 1 行で黙って消え、終了コードは 0 のままだった。
    # core の `load` は読めなかったファイルを失敗として数える。前処理だけをここに残す。
    def self.load(cases = nil)
      ENV['TEST'] = Package.full_name
      TestHarness.apply!
      invalidate_shared_caches
      Sidekiq::Testing.fake!
      super
    end

    # 読まずに飛ばすテストファイル（core が omission として数える）。
    #
    # ⚠ **前提を満たさないハンドラ・ワーカーのテストは、読まずに飛ばす。**`disable?` の判定には DB や
    # SNS が要るものが多く、手元や CI では作れない（`Handler.create` が nil・`No database` など）。
    # 写しの頃は判定の例外も `- case:` で飛ばしていたので、**判定で例外になったら理由を添えて飛ばす**。
    # ⚠ ここで飛ばすのは判定まで。**ファイルの `require` で落ちたものは飛ばさず、失敗にする**（core の検知）。
    def self.skip_case?(name)
      return false unless target = skip_target(name)
      return 'disabled' if target.disable?
      return false
    rescue => e
      return "#{e.class}: #{e.message}"
    end

    # ⚠ 作れなかった（nil）ときは例外にして、上の `rescue` で理由に変える。
    def self.skip_target(name)
      case name
      when /_handler$/
        return Handler.create(name) || raise(Ginseng::ImplementError, "#{name} を作れない")
      when /_worker$/
        return Worker.create(name) || raise(Ginseng::ImplementError, "#{name} を作れない")
      end
      return nil
    end

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

    # プロセスをまたいで居座る共有キャッシュを、スイート開始時に既知の状態へ戻す。
    #
    # ⚠ **「実走の前に手で UNLINK する」を手順書に書くだけでは弱い (#4583)。**
    # タグ辞書は Redis に残り、テストの結果が「前に一度回したか」で変わっていた。
    # 人間が手順を踏み忘れても効くよう、スイートのロードに織り込む。
    def self.invalidate_shared_caches
      TaggingDictionary.invalidate_cache
    rescue => e
      # Redis 未起動などで落ちても、ここでスイート全体を止めない。実際に辞書を
      # 触るテストがその場で落ちる。
      e.log
    end
  end
end
