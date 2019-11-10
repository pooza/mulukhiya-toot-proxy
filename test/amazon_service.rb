module MulukhiyaTootProxy
  class AmazonServiceTest < Test::Unit::TestCase
    def setup
      @service = AmazonService.new
    end

    def test_fetch_image_uri
      ['B07VHY7DBH', 'B00TYVQN3O', 'B071DNWLBR'].each do |asin|
        uri = @service.fetch_image_uri(asin)
        assert_equal(uri.scheme, 'https')
        assert_equal(uri.host, 'images-na.ssl-images-amazon.com')
      end
    end
  end
end
