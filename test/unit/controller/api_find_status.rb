module Mulukhiya
  # `APIController#find_status`（5.43.0 のリリース前レビュー）。
  #
  # ⚠ API で読む系統（Pleroma 系）の `Status.[]` は nil を返さない。取りに行くのを
  # 後回しにすると、上流の 404 が `GET /status/:id` で 502 とアラートに化けていた。
  # 実サーバーに依らず走らせるため、投稿のクラスはダブルを差す。
  class APIFindStatusTest < TestCase
    APIStatusDouble = Struct.new(:error, :service) do
      def data
        raise error if error
        return {}
      end
    end

    DBStatusDouble = Struct.new(:id) do
      def data
        raise 'DB で読む系統では取りに行かない'
      end
    end

    def setup
      @controller = APIController.new!
      sns = Object.new
      @controller.define_singleton_method(:sns) {sns}
    end

    def test_returns_status_when_upstream_has_it
      stub_status(APIStatusDouble.new(nil))
      status = @controller.send(:find_status, '1')

      assert_kind_of(APIStatusDouble, status)
      assert_not_nil(status.service)
    end

    def test_returns_nil_when_upstream_says_not_found
      [401, 403, 404].each do |code|
        stub_status(APIStatusDouble.new(Ginseng::GatewayError.new("Bad response #{code}")))

        assert_nil(@controller.send(:find_status, '1'), code)
      end
    end

    # ⚠ 上流の障害まで「無い」にしない。502 とアラートのままにする。
    def test_raises_when_upstream_fails
      stub_status(APIStatusDouble.new(Ginseng::GatewayError.new('Bad response 500')))

      assert_raises(Ginseng::GatewayError) do
        @controller.send(:find_status, '1')
      end
    end

    def test_db_backed_status_is_not_fetched
      stub_status(DBStatusDouble.new('1'))

      assert_kind_of(DBStatusDouble, @controller.send(:find_status, '1'))
    end

    private

    def stub_status(status)
      klass = Class.new
      klass.define_singleton_method(:[]) {|_id| status}
      @controller.define_singleton_method(:status_class) {klass}
    end
  end
end
