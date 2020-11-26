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
      return unless Environment.controller_class.livecure?

      get '/program'
      assert(last_response.ok?)
      assert_equal(last_response.content_type, 'application/json; charset=UTF-8')
    end

    def test_media
      return unless Environment.controller_class.media_catalog?

      get '/media'
      assert(last_response.ok?)
      assert_equal(last_response.content_type, 'application/json; charset=UTF-8')
    end

    def test_health
      get '/health'
      assert(last_response.ok?)
      assert_equal(last_response.content_type, 'application/json; charset=UTF-8')
    end

    def test_tag_search
      get '/tagging/tag/search'
      assert_false(last_response.ok?)
      assert_equal(last_response.status, 422)
      assert_equal(last_response.content_type, 'application/json; charset=UTF-8')

      get '/tagging/tag/search?q=API'
      assert(last_response.ok?)
      assert_equal(last_response.content_type, 'application/json; charset=UTF-8')
    end
  end
end
