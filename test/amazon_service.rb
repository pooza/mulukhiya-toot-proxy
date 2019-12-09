module MulukhiyaTootProxy
  class AmazonServiceTest < Test::Unit::TestCase
    def setup
      return unless AmazonService.config?
      @service = AmazonService.new
    end

    def test_create_image_uri
      return unless AmazonService.config?
      ['B07VHY7DBH', 'B00TYVQN3O', 'B071DNWLBR'].each do |asin|
        uri = @service.create_image_uri(asin)
        assert_equal(uri.scheme, 'https')
        assert_equal(uri.host, 'images-fe.ssl-images-amazon.com')
      end
    end
  end
end
