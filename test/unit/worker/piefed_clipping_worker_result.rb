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

    def test_perform_without_piefed
      @worker.define_singleton_method(:account_class) {{}}

      assert_raise(Ginseng::ConfigError) {@worker.perform(account_id: 1, uri: 'https://precure.ml/')}
    end

    private

    def stub_piefed(result)
      piefed = Object.new
      piefed.define_singleton_method(:clip) {|_body| result}
      account = Struct.new(:piefed).new(piefed)
      @worker.define_singleton_method(:account_class) {{1 => account}}
    end
  end
end
