module Mulukhiya
  class MediaMetadataStorageTest < TestCase
    def disable?
      return true unless test_token
      return super
    end

    def setup
      return if disable?
      @storage = MediaMetadataStorage.new
      @uri = Ginseng::URI.parse('https://images-na.ssl-images-amazon.com/images/I/519zZO6YAVL.jpg')
    end

    def test_push
      @storage.push(@uri)

      assert_equal({
        height: 353,
        mediatype: 'image',
        size: 53_882,
        length: 53_882,
        subtype: 'jpeg',
        type: 'image/jpeg',
        width: 500,
        url: 'https://images-na.ssl-images-amazon.com/images/I/519zZO6YAVL.jpg',
      }, @storage[@uri])
    end
  end
end
