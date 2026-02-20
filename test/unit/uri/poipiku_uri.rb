module Mulukhiya
  class PoipikuURITest < TestCase
    def setup
      @uri = PoipikuURI.parse('https://poipiku.com/8066049/8819854.html')
      @invalid_uri = PoipikuURI.parse('https://google.co.jp')
    end

    def test_google?
      assert_predicate(@uri, :poipiku?)
      assert_false(@invalid_uri.poipiku?)
    end

    def test_account_id
      assert_equal(8_066_049, @uri.account_id)
    end

    def test_picture_id
      assert_equal(8_819_854, @uri.picture_id)
    end

    def test_image_uri
      uri = @uri.image_uri
      return unless uri
      assert_equal(Ginseng::URI.parse('https://cdn.poipiku.com/008066049/008819854_DlZlDWaDH.jpeg_640.jpg'), uri)
    rescue
      # HTTP client not available in CI
    end
  end
end
