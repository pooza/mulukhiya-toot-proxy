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
  end
end
