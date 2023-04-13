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

    def test_update_status
      text = "1#{@status.text}"
      r = @service.update_status(@status, text, {
        headers: {'X-Mulukhiya-Purpose' => 'test'},
      })

      assert(text.start_with?(TootParser.new(r['content']).body))
    end

    def test_filters
      assert_kind_of(HTTParty::Response, @service.filters)

      @service.register_filter(tag: '実況')
      filters = @service.filters(tag: '実況')

      assert_kind_of(Array, filters)
      assert_predicate(filters.length, :positive?)
      filters.first(5).each do |filter|
        assert_kind_of(String, filter['id'])
      end
    end
  end
end
