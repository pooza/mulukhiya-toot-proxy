module Mulukhiya
  class BandaiChannelURITest < TestCase
    def test_bandai_channel?
      uri = BandaiChannelURI.parse('https://apple.com')
      assert_false(uri.bandai_channel?)

      uri = BandaiChannelURI.parse('https://www.b-ch.com/titles/6357/039')
      assert(uri.bandai_channel?)
    end

    def test_title_id
      uri = BandaiChannelURI.parse('https://www.b-ch.com/titles/6357/039')
      assert_equal(uri.title_id, 6357)
    end

    def test_episode_id
      uri = BandaiChannelURI.parse('https://www.b-ch.com/titles/6357/039')
      assert_equal(uri.episode_id, 39)
    end

    def test_image_uri
      uri = BandaiChannelURI.parse('https://www.b-ch.com/titles/6357/039')
      assert_equal(uri.image_uri.to_s, 'https://image2.b-ch.com/ttl2/6357/6357039a.jpg')

      uri = BandaiChannelURI.parse('https://www.b-ch.com/titles/6256/')
      assert_equal(uri.image_uri.to_s, 'https://image2.b-ch.com/ttl2/6256/6256001a.jpg')
    end
  end
end
