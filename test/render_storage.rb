module Mulukhiya
  class RenderStorageTest < TestCase
    def setup
      @storage = RenderStorage.new
      @renderer = RSS20FeedRenderer.new
      @command = CommandLine.new([File.join(Environment.dir, 'bin/sample/custom_feed_1.sh')])
      @uri = URI.parse('https://images-na.ssl-images-amazon.com/images/I/519zZO6YAVL.jpg')
      @http = HTTP.new
      @key = SecureRandom.hex(16)
    end

    def test_command
      @command.exec
      @renderer.entries = JSON.parse(@command.stdout)
      @storage[@key] = @renderer.to_s

      assert_kind_of(String, @storage[@key])
      @storage.del(@key)
      assert_nil(@storage[@key])
    end

    def test_uri
      response = @http.get(@uri)
      metadata = {
        url: @uri.to_s,
        type: response.headers['content-type'],
        length: response.headers['content-length'],
      }
      @storage[@key] = metadata
      assert_equal(@storage[@key], {
        'url' => 'https://images-na.ssl-images-amazon.com/images/I/519zZO6YAVL.jpg',
        'type' => 'image/jpeg',
        'length' => '53882',
      })
      @storage.del(@key)
      assert_nil(@storage[@key])
    end
  end
end
