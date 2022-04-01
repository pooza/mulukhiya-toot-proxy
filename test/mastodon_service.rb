require 'securerandom'

module Mulukhiya
  class MastodonServiceTest < TestCase
    def setup
      @service = MastodonService.new
      @key = SecureRandom.hex.adler32
      @status = account.recent_status
    end

    test 'テスト用投稿の有無' do
      assert_not_nil(account.recent_status)
    end

    def test_statuses
      assert_kind_of(Array, statuses = @service.statuses(type: 'account'))
      statuses.first(10).each do |status|
        assert_kind_of(Hash, status)
        assert_kind_of(String, status[:created_at_str])
        assert_kind_of(Time, Time.parse(status[:created_at_str]))
        assert_kind_of(String, status[:body])
        assert_kind_of(String, status[:footer])
        assert_kind_of(Array, status[:footer_tags])
        assert_boolean(status[:taggable])
      end
    end

    def test_update_status
      text = "1#{@status.text}"
      r = @service.update_status(@status, text)
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
        assert_kind_of(String, filter['phrase'])
      end
    end
  end
end
