module Mulukhiya
  # Akkoma（Pleroma 系）のタグ (#4566)。⚠ `listable?` のほかは DB に繋がない。
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

    # 表に無いタグのフィードは 404 にする。
    def test_listable
      omit('Akkoma の DB が要る') unless Environment.pleroma?

      assert_false(Pleroma::HashTag.get(tag: 'mulukhiya_no_such_tag').listable?)
      omit('hashtags が空') unless name = Sequel::Model.db[:hashtags].get(:name)

      assert_predicate(Pleroma::HashTag.get(tag: name), :listable?)
    end
  end
end
