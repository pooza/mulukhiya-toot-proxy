require 'securerandom'

module Mulukhiya
  class MastodonServiceTest < TestCase
    def disable?
      return true unless Environment.mastodon?
      return super
    end

    def setup
      @service = MastodonService.new
      @status = account.recent_status
    end

    test 'テスト用投稿の有無' do
      assert_not_nil(account.recent_status)
    end
  end
end
