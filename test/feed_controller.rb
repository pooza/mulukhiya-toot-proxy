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
      return unless Environment.controller_class.feed?
      return unless Environment.controller_class.media_catalog?

      get '/media'
      assert(last_response.ok?)
      assert_equal(last_response.content_type, 'application/atom+xml; charset=UTF-8')
    end

    def test_default_tag
      return unless Environment.controller_class.feed?
      return unless TagContainer.default_tag_bases.present?

      service = Environment.sns_class.new
      TagContainer.default_tag_bases.each do |tag|
        get service.create_uri("/tag/#{tag}").normalize.path
        assert(last_response.ok?)
        assert_equal(last_response.content_type, 'application/atom+xml; charset=UTF-8')
      end
    end

    def test_media_tag
      return unless Environment.controller_class.feed?
      return unless TagContainer.media_tag?

      get '/tag/image'
      assert(last_response.ok?)
      assert_equal(last_response.content_type, 'application/atom+xml; charset=UTF-8')

      get '/tag/video'
      assert(last_response.ok?)
      assert_equal(last_response.content_type, 'application/atom+xml; charset=UTF-8')

      get '/tag/audio'
      assert(last_response.ok?)
      assert_equal(last_response.content_type, 'application/atom+xml; charset=UTF-8')
    end
  end
end
