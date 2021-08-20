module Mulukhiya
  class APIControllerTest < TestCase
    include ::Rack::Test::Methods

    def app
      return APIController
    end

    def test_not_found
      get '/noexistant'
      assert_false(last_response.ok?)
    end

    def test_about
      get '/about'
      assert(last_response.ok?)
      assert_equal(last_response.content_type, 'application/json; charset=UTF-8')
    end

    def test_config
      get '/config'
      assert_false(last_response.ok?)
      assert_equal(last_response.status, 403)
      assert_equal(last_response.content_type, 'application/json; charset=UTF-8')
    end

    def test_program
      return unless controller_class.livecure?

      get '/program'
      assert(last_response.ok?)
      assert_equal(last_response.content_type, 'application/json; charset=UTF-8')
    end

    def test_media
      return unless controller_class.media_catalog?

      get '/media'
      assert(last_response.ok?)
      assert_equal(last_response.content_type, 'application/json; charset=UTF-8')

      get '/media?page=0'
      assert_false(last_response.ok?)
      assert_equal(last_response.status, 422)

      get '/media?page=1'
      assert(last_response.ok?)
      assert_equal(last_response.content_type, 'application/json; charset=UTF-8')

      get '/media?page=2'
      assert(last_response.ok?)
      assert_equal(last_response.content_type, 'application/json; charset=UTF-8')
    end

    def test_health
      get '/health'
      assert(last_response.ok?)
      assert_equal(last_response.content_type, 'application/json; charset=UTF-8')
    end

    def test_tag_search
      post '/tagging/tag/search'
      assert_false(last_response.ok?)
      assert_equal(last_response.status, 422)
      assert_equal(last_response.content_type, 'application/json; charset=UTF-8')

      header 'Content-Type', 'application/json'
      post '/tagging/tag/search', {q: 'まこぴー'}.to_json
      assert(last_response.ok?)
      assert_equal(last_response.content_type, 'application/json; charset=UTF-8')
      assert_kind_of(Hash, JSON.parse(last_response.body))
    end

    def test_favorite_tags
      return unless controller_class.favorite_tags?
      get '/tagging/favorites'
      assert(last_response.ok?)
      assert_equal(last_response.content_type, 'application/json; charset=UTF-8')
    end

    def test_annict_crawl
      return unless test_account.annict

      header 'Content-Type', 'application/json'
      post '/annict/crawl'
      assert_false(last_response.ok?)
      assert_equal(last_response.status, 403)

      header 'Content-Type', 'application/json'
      post '/annict/crawl', {token: test_token.encrypt}.to_json
      assert_equal(last_response.content_type, 'application/json; charset=UTF-8')
      if test_account.annict
        assert(last_response.ok?)
      else
        assert_false(last_response.ok?)
        assert_equal(last_response.status, 403)
      end
    end

    def test_feed_list
      get '/feed/list'
      assert(last_response.ok?)
      assert_equal(last_response.content_type, 'application/json; charset=UTF-8')

      uri = sns_class.new.create_uri('/feed/list')
      uri.query_values = {token: test_token.encrypt}
      get uri.to_s
      assert(last_response.ok?)
      assert_equal(last_response.content_type, 'application/json; charset=UTF-8')
    end

    def test_costom_endpoints
      CustomAPI.entries.each do |entry|
        next if entry['command'].last.is_a?(Symbol)
        get File.join('/', entry['path'])
        assert(last_response.ok?)
      end
    end
  end
end
