module MulukhiyaTootProxy
  class AmazonServiceTest < Test::Unit::TestCase
    def setup
      @service = AmazonService.new
    end

    def test_fetch_image_uri
      assert_equal(@service.fetch_image_uri('B07VHY7DBH').to_s, 'https://images-na.ssl-images-amazon.com/images/I/61F80dgYOlL._AC_SX355_.jpg')
      assert_equal(@service.fetch_image_uri('B00TYVQN3O').to_s, 'https://images-na.ssl-images-amazon.com/images/I/91Bo8o5PhlL._SX600_.jpg')
      assert_equal(@service.fetch_image_uri('B071DNWLBR').to_s, 'https://images-na.ssl-images-amazon.com/images/I/91HvB+bV66L._SX600_.jpg')
    end
  end
end
