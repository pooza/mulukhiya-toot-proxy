module Mulukhiya
  class FeedControllerTest < TestCase
    include ::Rack::Test::Methods

    def disable?
      return true unless controller_class.feed?
      return super
    end

    def app
      return FeedController
    end

    def test_not_found
      get '/noexistant'

      assert_false(last_response.ok?)
    end

    def test_media
      return unless controller_class.media_catalog?

      get '/media'

      assert_predicate(last_response, :ok?)
      assert_equal('application/rss+xml; charset=UTF-8', last_response.content_type)
    end

    def test_default_tag
      return unless DefaultTagHandler.tags.present?

      service = sns_class.new
      DefaultTagHandler.tags.each do |tag|
        get service.create_uri("/tag/#{tag}").normalize.path

        assert_predicate(last_response, :ok?)
        assert_equal('application/rss+xml; charset=UTF-8', last_response.content_type)
      end
    end

    def test_media_tag
      return if Handler.create(:media_tag).disable?
      get '/tag/image'
      if hash_tag_class.get(tag: config['/handler/media_tag/tags/image'])
        assert_equal('application/rss+xml; charset=UTF-8', last_response.content_type)
        assert_predicate(last_response, :ok?)
      else
        assert_false(last_response.ok?)
        assert_equal(404, last_response.status)
      end

      get '/tag/video'
      if hash_tag_class.get(tag: config['/handler/media_tag/tags/video'])
        assert_equal('application/rss+xml; charset=UTF-8', last_response.content_type)
        assert_predicate(last_response, :ok?)
      else
        assert_false(last_response.ok?)
        assert_equal(404, last_response.status)
      end

      get '/tag/audio'
      if hash_tag_class.get(tag: config['/handler/media_tag/tags/audio'])
        assert_equal('application/rss+xml; charset=UTF-8', last_response.content_type)
        assert_predicate(last_response, :ok?)
      else
        assert_false(last_response.ok?)
        assert_equal(404, last_response.status)
      end
    end

    def test_costom_endpoints
      CustomFeed.all do |feed|
        get feed.path

        assert_predicate(last_response, :ok?)
        assert_equal('application/rss+xml; charset=UTF-8', last_response.content_type)
      end
    end
  end
end
