module Mulukhiya
  class TwitterServiceTest < TestCase
    def setup
      @service = Environment.test_account.twitter
    end

    def test_config?
      assert_boolean(TwitterService.config?)
    end

    def test_tweet
      return unless TwitterService.config?
      assert_kind_of(Twitter::Tweet, @service.tweet('宇宙の闇社会を牛耳る、宇宙マフィア。'))
    end
  end
end
