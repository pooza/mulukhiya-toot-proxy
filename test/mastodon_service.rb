require 'securerandom'

module Mulukhiya
  class MastodonServiceTest < TestCase
    def setup
      @service = MastodonService.new
      @key = SecureRandom.hex.adler32
    end

    def test_filters
      assert_kind_of(HTTParty::Response, @service.filters)

      filters = @service.filters(tag: '実況')
      assert_kind_of(Array, filters)
      assert(filters.length.positive?)
      filters.first(5).each do |filter|
        assert_kind_of(String, filter['id'])
        assert_kind_of(String, filter['phrase'])
      end
    end
  end
end
