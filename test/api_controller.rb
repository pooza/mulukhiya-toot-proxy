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
      assert_predicate(last_response, :ok?)
      assert_equal('application/json; charset=UTF-8', last_response.content_type)
    end

    def test_config
      get '/config'
      assert_false(last_response.ok?)
      assert_equal(403, last_response.status)
      assert_equal('application/json; charset=UTF-8', last_response.content_type)
    end

    def test_program
      return unless controller_class.livecure?

      get '/program'
      assert_predicate(last_response, :ok?)
      assert_equal('application/json; charset=UTF-8', last_response.content_type)

      get '/program/works'
      assert_predicate(last_response, :ok?)
      assert_equal('application/json; charset=UTF-8', last_response.content_type)
    end

    def test_media
      return unless controller_class.media_catalog?

      get '/media'
      assert_predicate(last_response, :ok?)
      assert_equal('application/json; charset=UTF-8', last_response.content_type)

      get '/media?page=0'
      assert_false(last_response.ok?)
      assert_equal(422, last_response.status)

      get '/media?page=1'
      assert_predicate(last_response, :ok?)
      assert_equal('application/json; charset=UTF-8', last_response.content_type)

      get '/media?page=2'
      assert_predicate(last_response, :ok?)
      assert_equal('application/json; charset=UTF-8', last_response.content_type)
    end

    def test_health
      get '/health'
      assert_predicate(last_response, :ok?)
      assert_equal('application/json; charset=UTF-8', last_response.content_type)
    end

    def test_tag_search
      post '/tagging/tag/search'
      assert_false(last_response.ok?)
      assert_equal(422, last_response.status)
      assert_equal('application/json; charset=UTF-8', last_response.content_type)

      header 'Content-Type', 'application/json'
      post '/tagging/tag/search', {q: 'まこぴー'}.to_json
      assert_predicate(last_response, :ok?)
      assert_equal('application/json; charset=UTF-8', last_response.content_type)
      assert_kind_of(Hash, JSON.parse(last_response.body))
    end

    def test_favorite_tags
      return unless controller_class.favorite_tags?
      get '/tagging/favorites'
      assert_predicate(last_response, :ok?)
      assert_equal('application/json; charset=UTF-8', last_response.content_type)
    end

    def test_lemmy_communities
      return unless test_account.lemmy
      get "/lemmy/communities?token=#{test_account.token}"
      assert_predicate(last_response, :ok?)
      assert_equal('application/json; charset=UTF-8', last_response.content_type)
    end

    def test_feed_list
      get '/feed/list'
      assert_predicate(last_response, :ok?)
      assert_equal('application/json; charset=UTF-8', last_response.content_type)

      uri = sns_class.new.create_uri('/feed/list')
      uri.query_values = {token: test_token.encrypt}
      get uri.to_s
      assert_predicate(last_response, :ok?)
      assert_equal('application/json; charset=UTF-8', last_response.content_type)
    end

    def test_status
      return unless controller_class.account_timeline?
      get '/status'
      assert_false(last_response.ok?)

      get "/status/list?token=#{test_account.token}"
      assert_predicate(last_response, :ok?)
      assert_equal('application/json; charset=UTF-8', last_response.content_type)

      JSON.parse(last_response.body).first(10).each do |status|
        assert_kind_of([String, Integer], status['id'])
        assert_kind_of([String, NilClass], status['content'])

        get "/status/#{status['id']}?token=#{test_account.token}"
        assert_predicate(last_response, :ok?)
        assert_equal('application/json; charset=UTF-8', last_response.content_type)
      end
    end

    def test_costom_endpoints
      CustomAPI.all.reject(&:args?).each do |api|
        get api.path
        assert_predicate(last_response, :ok?)
      end
    end
  end
end
