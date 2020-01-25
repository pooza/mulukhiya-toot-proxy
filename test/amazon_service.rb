module Mulukhiya
  class AmazonServiceTest < TestCase
    def setup
      @service = AmazonService.new
    end

    def test_lookup
      ['B07VHY7DBH', 'B00TYVQN3O', 'B071DNWLBR'].each do |asin|
        assert_kind_of(Amazon::Element, @service.lookup(asin))
      end
    end

    def test_create_image_uri
      ['B07VHY7DBH', 'B00TYVQN3O', 'B071DNWLBR'].each do |asin|
        uri = @service.create_image_uri(asin)
        assert_equal(uri.scheme, 'https')
        assert_equal(uri.host, 'images-fe.ssl-images-amazon.com')
      end
    end
  end
end
