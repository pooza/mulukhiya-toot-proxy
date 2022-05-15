module Mulukhiya
  class AmazonServiceTest < TestCase
    def disable?
      return true unless AmazonService.config?
      return super
    end

    def setup
      @service = AmazonService.new
      @asins = ['B07VHY7DBH', 'B00TYVQN3O', 'B071DNWLBR']
    end

    def test_lookup
      @asins.each do |asin|
        assert_kind_of(Hash, @service.lookup(asin))
      end
    end

    def test_search
      assert_kind_of(String, @service.search('プリキュア', ['DigitalMusic']))
    end

    def test_create_image_uri
      @asins.map {|v| @service.create_image_uri(v)}.each do |uri|
        assert_predicate(uri, :absolute?)
        assert_equal('https', uri.scheme)
        assert_equal('m.media-amazon.com', uri.host)
      end
    end
  end
end
