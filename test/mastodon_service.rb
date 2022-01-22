require 'securerandom'

module Mulukhiya
  class MastodonServiceTest < TestCase
    def setup
      @sns = MastodonService.new
      @key = SecureRandom.hex(16).adler32
    end

    def test_unregister_filter
      return if Environment.ci?
      return unless Environment.mastodon?
      @sns.register_filter(phrase: @key)
      assert(@sns.filters.find {|v| v['phrase'] == @key}.present?)
      @sns.unregister_filter(@key)
      assert_false(@sns.filters.find {|v| v['phrase'] == @key}.present?)
    end
  end
end
