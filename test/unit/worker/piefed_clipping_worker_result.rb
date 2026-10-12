module Mulukhiya
  # PieFed の clip の戻り値でログを分ける (#4750)。PieFed へは行かない。
  class PiefedClippingWorkerResultTest < TestCase
    def disable?
      return true unless controller_class.piefed?
      return super
    end

    def setup
      return if disable?
      @worker = Worker.create(:piefed_clipping)
      @logs = []
      logs = @logs
      @worker.define_singleton_method(:log) {|message| logs.push(message)}
    end

    def test_perform_not_public
      stub_piefed(nil)
      @worker.perform(account_id: 1, uri: 'https://precure.ml/web/statuses/107640049077500578')

      assert_equal('not public', @logs.last[:message])
    end

    def test_perform_clipped
      stub_piefed({id: 1})
      @worker.perform(account_id: 1, uri: 'https://precure.ml/web/statuses/107640049077500578')

      assert_equal('clipped', @logs.last[:message])
    end

    # 🔴 取得先ホストの検証で拒否された URL は、再試行させない（5.40.0 のリリース前レビュー）。
    # 例外のまま抜けると Sidekiq が 3 回再試行し、Sentry に 4 件出て、利用者には何も返らない。
    def test_perform_rejected_host
      stub_piefed {raise Ginseng::GatewayError, "Rejected host '127.0.0.1'"}
      @worker.perform(account_id: 1, uri: 'http://127.0.0.1:3000/@a/1')

      assert_equal('rejected host', @logs.last[:message])
    end

    # ⚠ それ以外の上流の失敗は、従来どおり例外で抜ける（再試行に乗せる）。
    def test_perform_other_gateway_error_is_raised
      stub_piefed {raise Ginseng::GatewayError, 'Bad response 503'}

      assert_raise(Ginseng::GatewayError) do
        @worker.perform(account_id: 1, uri: 'https://precure.ml/web/statuses/1')
      end
    end

    def test_perform_without_piefed
      @worker.define_singleton_method(:account_class) {{}}

      assert_raise(Ginseng::ConfigError) {@worker.perform(account_id: 1, uri: 'https://precure.ml/')}
    end

    private

    def stub_piefed(result = nil, &block)
      piefed = Object.new
      block ||= proc {result}
      piefed.define_singleton_method(:clip) {|_body| block.call}
      account = Struct.new(:piefed).new(piefed)
      @worker.define_singleton_method(:account_class) {{1 => account}}
    end
  end
end
