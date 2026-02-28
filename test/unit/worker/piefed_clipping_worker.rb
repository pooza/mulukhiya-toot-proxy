module Mulukhiya
  class PiefedClippingWorkerTest < TestCase
    def disable?
      return true unless controller_class.piefed?
      return true unless test_token
      return super
    end

    def setup
      return if disable?
      @worker = Worker.create(:piefed_clipping)
    end

    def test_create_body
      body = @worker.create_body(uri: 'https://precure.ml/web/statuses/107640049077500578')

      assert_kind_of(String, body)
      assert_predicate(body, :present?)
    end
  end
end
