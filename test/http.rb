module Mulukhiya
  class HTTPTest < TestCase
    def setup
      @http = HTTP.new
    end

    def test_base_uri
      @http.base_uri = 'https://service1.example.com'
      assert_equal(@http.base_uri, Ginseng::URI.parse('https://service1.example.com'))

      @http.base_uri = Ginseng::URI.parse('https://service2.example.com')
      assert_equal(@http.base_uri, Ginseng::URI.parse('https://service2.example.com'))

      assert_raise RuntimeError do
        @http.base_uri = '/hoge'
      end

      @http.base_uri = nil
      assert_nil(@http.base_uri)
    end

    def test_create_uri
      @http.base_uri = nil
      assert_raise RuntimeError do
        @http.create_uri('/fuga')
      end

      @http.base_uri = 'https://service1.example.com'
      assert_equal(@http.create_uri('/fuga'), Ginseng::URI.parse('https://service1.example.com/fuga'))
    end
  end
end
