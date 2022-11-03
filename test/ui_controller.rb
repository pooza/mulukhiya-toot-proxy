module Mulukhiya
  class UIControllerTest < TestCase
    include ::Rack::Test::Methods

    def setup
      config['/crypt/encoder'] = 'base64'
    end

    def app
      return UIController
    end

    def test_home
      get '/'

      assert_predicate(last_response, :ok?)
    end

    def test_page
      get '/noexist'

      assert_false(last_response.ok?)
      assert_equal(404, last_response.status)

      get '/app/health'

      assert_predicate(last_response, :ok?)
    end

    def test_script
      get '/script'

      assert_false(last_response.ok?)
      assert_equal(404, last_response.status)

      get '/script/noexist'

      assert_false(last_response.ok?)
      assert_equal(404, last_response.status)

      get '/script/mulukhiya_lib'

      assert_predicate(last_response, :ok?)
      assert_equal('text/javascript;charset=UTF-8', last_response.content_type)

      get '/script/mulukhiya_lib.js'

      assert_predicate(last_response, :ok?)
      assert_equal('text/javascript;charset=UTF-8', last_response.content_type)
    end

    def test_style
      get '/style'

      assert_false(last_response.ok?)
      assert_equal(404, last_response.status)

      get '/style/noexist'

      assert_false(last_response.ok?)
      assert_equal(404, last_response.status)

      get '/style/default'

      assert_predicate(last_response, :ok?)
      assert_equal('text/css; charset=UTF-8', last_response.content_type)
    end

    def test_media
      get '/media'

      assert_false(last_response.ok?)
      assert_equal(404, last_response.status)

      get '/media/noexist'

      assert_false(last_response.ok?)
      assert_equal(404, last_response.status)

      get '/media/icon.png'

      assert_predicate(last_response, :ok?)
      assert_equal('image/png', last_response.content_type)

      get '/media/poyke.mp4'

      assert_predicate(last_response, :ok?)
      assert_equal('video/mp4', last_response.content_type)

      get '/media/hugttocatch.mp3'

      assert_predicate(last_response, :ok?)
      assert_equal('audio/mpeg', last_response.content_type)
    end
  end
end
