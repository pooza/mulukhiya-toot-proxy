module Mulukhiya
  class HashTagTest < TestCase
    def setup
      @tag = Environment.hash_tag_class.get(tag: 'nowplaying')
    end

    def test_name
      assert_equal(@tag.name, 'nowplaying')
    end

    def test_uri
      assert_kind_of(Ginseng::URI, @tag.uri)
      assert_equal(@tag.uri.path, '/tags/nowplaying')
    end

    def test_to_h
      assert_kind_of(Hash, @tag.to_h)
    end
  end
end
