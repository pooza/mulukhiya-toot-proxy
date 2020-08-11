module Mulukhiya
  class AnnictServiceTest < TestCase
    def setup
      @service = Environment.test_account.annict if AnnictService.config?
    end

    def test_config?
      assert_boolean(AnnictService.config?)
    end

    def test_account
      return unless @service
      assert_kind_of(Hash, @service.account)
      assert_kind_of(Integer, @service.account['id'])
      assert_kind_of(String, @service.account['name'])
      assert_kind_of(String, @service.account['username'])
    end

    def test_records
      return unless @service
      assert_kind_of(Enumerator, @service.records)
    end

    def test_recent_records
      return unless @service
      assert_kind_of(Enumerator, @service.recent_records)
      @service.recent_records do |record|
        assert_kind_of(Hash, record)
        assert_kind_of(String, record['work']['title'])
        assert_kind_of(Float, record['episode']['number'])
      end
    end

    def test_updated_at
      return unless @service
      assert_kind_of([Date, NilClass], @service.updated_at)
    end

    def test_oauth_uri
      return unless @service
      assert_kind_of(Ginseng::URI, @service.oauth_uri)
    end
  end
end
