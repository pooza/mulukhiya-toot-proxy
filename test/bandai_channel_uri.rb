module Mulukhiya
  class BandaiChannelURITest < TestCase
    def setup
      @apple_uri = BandaiChannelURI.parse('https://apple.com')
      @title_uri = BandaiChannelURI.parse('https://www.b-ch.com/titles/6256/')
      @episode_uri = BandaiChannelURI.parse('https://www.b-ch.com/titles/6357/039')
    end

    def test_bandai_channel?
      assert_false(@apple_uri.bandai_channel?)
      assert(@title_uri.bandai_channel?)
      assert(@episode_uri.bandai_channel?)
    end

    def test_title_id
      assert_nil(@apple_uri.title_id)
      assert_equal(@title_uri.title_id, 6256)
      assert_equal(@episode_uri.title_id, 6357)
    end

    def test_episode_id
      assert_nil(@apple_uri.episode_id)
      assert_nil(@title_uri.episode_id)
      assert_equal(@episode_uri.episode_id, 39)
    end

    def test_image_uri
      assert_nil(@apple_uri.image_uri)
      assert_equal(@title_uri.image_uri.to_s, 'https://image2.b-ch.com/ttl2/6256/6256001a.jpg')
      assert_equal(@episode_uri.image_uri.to_s, 'https://image2.b-ch.com/ttl2/6357/6357039a.jpg')
    end
  end
end
