module MulukhiyaTootProxy
  class TaggingDictionaryTest < Test::Unit::TestCase
    def setup
      @dic = TaggingDictionary.new
      @dic.delete
      assert_false(@dic.exist?)
      @dic.create
      assert(@dic.exist?)
    end

    def test_resources
      @dic.resources.each do |resource|
        assert(resource.is_a?(Hash))
        assert(resource['fields'].is_a?(Array))
        assert(resource['fields'].present?)
      end
    end
  end
end
