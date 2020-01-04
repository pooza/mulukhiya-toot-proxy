module MulukhiyaTootProxy
  class TaggingDictionaryTest < TestCase
    def setup
      @config = Config.instance
      @config['/tagging/dictionaries'] = [
        {
          'url' => 'https://script.google.com/macros/s/AKfycbwn4nqKhBwH3aDYd7bJ698-GWRJqpktpAdH11ramlBK87ym3ME/exec',
          'type' => 'relative',
        },
        {
          'url' => 'https://script.google.com/macros/s/AKfycbzAUsRUuFLO72EgKta020v9OMtxvUtqUcPZNJ3_IMlOo8dRO7tW/exec',
          'type' => 'relative',
        },
        {
          'url' => 'https://script.google.com/macros/s/AKfycbyy5EQHvhKfm1Lg6Ae4W7knG4BCSkvepJyB6MrzQ8UIxmFfZMJj/exec',
          'type' => 'relative',
        },
      ]
      @dic = TaggingDictionary.new
    end

    def test_exist?
      @dic.delete
      assert_false(@dic.exist?)
      @dic.refresh
      assert(@dic.exist?)
    end
  end
end
