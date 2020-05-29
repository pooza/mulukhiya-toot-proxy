module Mulukhiya
  class RemoteDictionaryTest < TestCase
    def test_all
      RemoteDictionary.all do |dic|
        assert_kind_of(RemoteDictionary, dic)
      end
    end

    def test_uri
      RemoteDictionary.all do |dic|
        assert_kind_of(Ginseng::URI, dic.uri)
      end
    end

    def test_fetch
      RemoteDictionary.all do |dic|
        assert(dic.fetch.present?)
      end
    end
  end
end
