module Mulukhiya
  class AnnictServiceTest < TestCase
    def setup
      @service = Environment.test_account.annict
    end

    def test_config?
      assert_boolean(AnnictService.config?)
    end

    def test_oauth_uri
      return unless AnnictService.config?
      assert_kind_of(Ginseng::URI, @service.oauth_uri)
    end
  end
end
