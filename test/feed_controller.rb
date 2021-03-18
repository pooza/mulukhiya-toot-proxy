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
      return unless TagContainer.default_tag_bases.present?

      service = sns_class.new
      TagContainer.default_tag_bases.each do |tag|
        get service.create_uri("/tag/#{tag}").normalize.path
        assert(last_response.ok?)
        assert_equal(last_response.content_type, 'application/atom+xml; charset=UTF-8')
      end
    end

    def test_media_tag
      return unless controller_class.feed?
      if TagContainer.media_tag?
        get '/tag/image'
        if Environment.hash_tag_class.get(tag: config['/tagging/media/tags/image'])
          assert_equal(last_response.content_type, 'application/atom+xml; charset=UTF-8')
          assert(last_response.ok?)
        else
          assert_false(last_response.ok?)
          assert_equal(last_response.status, 404)
        end

        get '/tag/video'
        if Environment.hash_tag_class.get(tag: config['/tagging/media/tags/video'])
          assert_equal(last_response.content_type, 'application/atom+xml; charset=UTF-8')
          assert(last_response.ok?)
        else
          assert_false(last_response.ok?)
          assert_equal(last_response.status, 404)
        end

        get '/tag/audio'
        if Environment.hash_tag_class.get(tag: config['/tagging/media/tags/audio'])
          assert_equal(last_response.content_type, 'application/atom+xml; charset=UTF-8')
          assert(last_response.ok?)
        else
          assert_false(last_response.ok?)
          assert_equal(last_response.status, 404)
        end
      else
        get '/tag/image'
        assert_false(last_response.ok?)
        assert_equal(last_response.status, 403)
        assert_equal(last_response.content_type, 'application/atom+xml; charset=UTF-8')

        get '/tag/video'
        assert_false(last_response.ok?)
        assert_equal(last_response.status, 403)
        assert_equal(last_response.content_type, 'application/atom+xml; charset=UTF-8')

        get '/tag/audio'
        assert_false(last_response.ok?)
        assert_equal(last_response.status, 403)
        assert_equal(last_response.content_type, 'application/atom+xml; charset=UTF-8')
      end
    end
  end
end
