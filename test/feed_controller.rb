module Mulukhiya
  class FeedControllerTest < TestCase
    include ::Rack::Test::Methods

    def app
      return FeedController
    end

    def test_not_found
      get '/noexistant'
      assert_false(last_response.ok?)
    end

    def test_media
      return unless controller_class.feed?
      return unless controller_class.media_catalog?

      get '/media'
      assert(last_response.ok?)
      assert_equal(last_response.content_type, 'application/atom+xml; charset=UTF-8')
    end

    def test_default_tag
      return unless controller_class.feed?
      return unless TagContainer.default_tags.present?

      service = sns_class.new
      TagContainer.default_tags.each do |tag|
        get service.create_uri("/tag/#{tag}").normalize.path
        assert(last_response.ok?)
        assert_equal(last_response.content_type, 'application/atom+xml; charset=UTF-8')
      end
    end

    def test_media_tag
      return unless controller_class.feed?
      return unless TagContainer.media_tag?
      get '/tag/image'
      if hash_tag_class.get(tag: config['/tagging/media/tags/image'])
        assert_equal(last_response.content_type, 'application/atom+xml; charset=UTF-8')
        assert(last_response.ok?)
      else
        assert_false(last_response.ok?)
        assert_equal(last_response.status, 404)
      end

      get '/tag/video'
      if hash_tag_class.get(tag: config['/tagging/media/tags/video'])
        assert_equal(last_response.content_type, 'application/atom+xml; charset=UTF-8')
        assert(last_response.ok?)
      else
        assert_false(last_response.ok?)
        assert_equal(last_response.status, 404)
      end

      get '/tag/audio'
      if hash_tag_class.get(tag: config['/tagging/media/tags/audio'])
        assert_equal(last_response.content_type, 'application/atom+xml; charset=UTF-8')
        assert(last_response.ok?)
      else
        assert_false(last_response.ok?)
        assert_equal(last_response.status, 404)
      end
    end

    def test_costom_endpoints
      CustomFeed.entries.each do |entry|
        get File.join('/', entry['path'])
        assert(last_response.ok?)
        assert_equal(last_response.content_type, 'application/rss+xml; charset=UTF-8')
      end
    end
  end
end
