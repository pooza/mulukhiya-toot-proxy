module Mulukhiya
  # Akkoma（Pleroma 系）のタグ (#4566)。⚠ 表を持たないので DB に繋がない。
  class PleromaHashTagTest < TestCase
    def setup
      @tag = Pleroma::HashTag.get(tag: 'NowPlaying')
      # URI の生成と既定タグの判定はサービス（＝トークンの DB）を引くので、先に詰めておく。
      @tag.define_singleton_method(:default?) {false}
      @tag.instance_variable_set(:@uri, Ginseng::URI.parse('https://akkoma.example.com/tag/nowplaying'))
      @tag.instance_variable_set(:@feed_uri, Ginseng::URI.parse('https://akkoma.example.com/mulukhiya/feed/tag/NowPlaying'))
    end

    # `values` が無いと `/feed/list` と `Pleroma::Status#to_h` が 500 になる（PR #4844 の Codex P1）。
    def test_to_h
      h = @tag.to_h

      assert_equal('nowplaying', h[:name])
      assert_equal('#NowPlaying', h[:tag])
      assert_kind_of(String, h[:url])
      assert_kind_of(String, h[:feed_url])
    end
  end
end
