module Mulukhiya
  class MastodonServiceTest < TestCase
    def setup
      @service = MastodonService.new('https://mastodon.test', 'test_token_abc123')
    end

    def test_theme_color
      color = @service.theme_color

      assert_equal(config['/mastodon/theme/color'], color)
    end

    def test_create_headers
      headers = @service.create_headers({'Cookie' => 'session=abc123'})

      assert_kind_of(Hash, headers)
      assert_equal('Bearer test_token_abc123', headers['Authorization'])
      refute(headers.any? {|k, _| k.to_s.downcase == 'cookie'})
    end

    def test_recent_status
      return unless Environment.mastodon? && account

      assert_not_nil(account.recent_status)
    end
  end
end
