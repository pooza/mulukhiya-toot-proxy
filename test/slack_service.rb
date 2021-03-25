module Mulukhiya
  class SlackServiceTest < TestCase
    def test_config?
      assert_boolean(SlackService.config?)
    end

    def test_all
      return unless SlackService.config?
      assert_kind_of(Enumerator, SlackService.all)
      SlackService.all do |slack|
        assert_kind_of(SlackService, slack)
      end
    end

    def test_uris
      return unless SlackService.config?
      assert_kind_of(Enumerator, SlackService.all)
      SlackService.uris do |uri|
        assert_kind_of(Ginseng::URI, uri)
      end
    end
  end
end
