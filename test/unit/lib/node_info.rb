module Mulukhiya
  class NodeInfoTest < TestCase
    def setup
      @info = NodeInfo.instance
    end

    def test_ginseng_class
      assert_equal(Ginseng::Fediverse::MastodonService, @info.send(:ginseng_class, MastodonService))
      assert_equal(Ginseng::Fediverse::MisskeyService, @info.send(:ginseng_class, MisskeyService))
    end

    # PleromaService の 1 つ上はモロヘイヤの MastodonService（キャッシュを返す側）なので、
    # それを飛ばして gem のクラスまで上がること (#4860)。
    def test_ginseng_class_skips_mulukhiya_superclass
      assert_equal(MastodonService, PleromaService.superclass)
      assert_equal(Ginseng::Fediverse::MastodonService, @info.send(:ginseng_class, PleromaService))
    end

    # 更新は gem のクラスの nodeinfo を呼び、`nodeName` を落とさないこと (#4860)。
    def test_update_keeps_node_name
      written = update_with('metadata' => {'nodeName' => 'test'})

      assert_equal('test', JSON.parse(written).dig('metadata', 'nodeName'))
    end

    # 上流の一時障害で空が返っても、キャッシュを上書きしないこと。
    def test_update_skips_blank
      assert_nil(update_with({}))
    end

    private

    def update_with(raw)
      gem_class = Class.new {define_method(:nodeinfo) {raw}}
      service_class = Class.new(gem_class)
      info = NodeInfo.send(:allocate)
      store = {}
      info.define_singleton_method(:sns_class) {service_class}
      info.define_singleton_method(:ginseng_class) {|_| gem_class}
      info.define_singleton_method(:redis) {store}
      info.define_singleton_method(:config) {Struct.new(:about).new({})}
      info.update
      return store['nodeinfo']
    end
  end
end
