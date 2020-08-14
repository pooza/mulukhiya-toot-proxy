module Mulukhiya
  class AnnictServiceTest < TestCase
    def setup
      @service = Environment.test_account.annict if AnnictService.config?
    end

    def test_config?
      assert_boolean(AnnictService.config?)
    end

    def test_account
      assert_kind_of(Hash, @service.account)
      assert_kind_of(Integer, @service.account['id'])
      assert_kind_of(String, @service.account['name'])
      assert_kind_of(String, @service.account['username'])
    end

    def test_records
      assert_kind_of(Enumerator, @service.records)
      @service.records do |record|
        assert_kind_of(Hash, record)
        assert_kind_of(String, record['work']['title'])
        assert_kind_of([Float, NilClass], record['episode']['number'])
        uri = Ginseng::URI.parse(record.dig('work', 'images', 'recomended_url'))
        assert(uri.absolute?) if uri
      end
    end

    def test_recent_records
      assert_kind_of(Enumerator, @service.recent_records)
    end

    def test_reviewed_works
      assert_kind_of(Enumerator, @service.reviewed_works)
      @service.reviewed_works do |work|
        assert_kind_of(Hash, work)
        assert_kind_of(Integer, work['work']['id'])
      end
    end

    def test_reviews
      assert_kind_of(Enumerator, @service.reviews)
      @service.reviews do |review|
        assert_kind_of(Hash, review)
        assert_kind_of(String, review['work']['title'])
        uri = Ginseng::URI.parse(review.dig('work', 'images', 'recomended_url'))
        assert(uri.absolute?) if uri
      end
    end

    def test_recent_reviews
      assert_kind_of(Enumerator, @service.recent_reviews)
    end

    def test_updated_at
      assert_kind_of([Time, NilClass], @service.updated_at)
    end

    def test_oauth_uri
      assert_kind_of(Ginseng::URI, @service.oauth_uri)
    end
  end
end
