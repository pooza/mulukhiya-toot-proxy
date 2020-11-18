module Mulukhiya
  class UIControllerTest < TestCase
    include ::Rack::Test::Methods

    def setup
      @config = Config.instance
    end

    def app
      return UIController
    end

    def test_home
      get '/'
      assert(last_response.ok?)
    end

    def test_page
      get '/noexist'
      assert_false(last_response.ok?)
      assert_equal(last_response.status, 404)

      get '/app/health'
      assert(last_response.ok?)
    end

    def test_script
      get '/script'
      assert_false(last_response.ok?)
      assert_equal(last_response.status, 404)

      get '/script/noexist'
      assert_false(last_response.ok?)
      assert_equal(last_response.status, 404)

      get '/script/mulukhiya_lib'
      assert(last_response.ok?)
      assert_equal(last_response.headers['Content-Type'], 'text/javascript;charset=UTF-8')

      get '/script/mulukhiya_lib.js'
      assert(last_response.ok?)
      assert_equal(last_response.headers['Content-Type'], 'text/javascript;charset=UTF-8')
    end

    def test_style
      get '/style'
      assert_false(last_response.ok?)
      assert_equal(last_response.status, 404)

      get '/style/noexist'
      assert_false(last_response.ok?)
      assert_equal(last_response.status, 404)

      get '/style/default'
      assert(last_response.ok?)
      assert_equal(last_response.headers['Content-Type'], 'text/css; charset=UTF-8')
    end

    def test_media
      get '/media'
      assert_false(last_response.ok?)
      assert_equal(last_response.status, 404)

      get '/media/noexist'
      assert_false(last_response.ok?)
      assert_equal(last_response.status, 404)

      get '/media/icon.png'
      assert(last_response.ok?)
      assert_equal(last_response.headers['Content-Type'], 'image/png')

      get '/media/poyke.mp4'
      assert(last_response.ok?)
      assert_equal(last_response.headers['Content-Type'], 'video/mp4')

      get '/media/hugttocatch.mp3'
      assert(last_response.ok?)
      assert_equal(last_response.headers['Content-Type'], 'audio/mpeg')
    end
  end
end
