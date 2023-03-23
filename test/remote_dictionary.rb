module Mulukhiya
  class RemoteDictionaryTest < TestCase
    def disable?
      return true unless RemoteDictionary.all.present?
      return super
    end

    def test_all
      RemoteDictionary.all do |dic|
        assert_kind_of(RemoteDictionary, dic)
      end
    end

    def test_uri
      RemoteDictionary.all do |dic|
        assert_kind_of(Ginseng::URI, dic.uri)
        assert_predicate(dic.uri, :absolute?)
      end
    end

    def test_fetch
      RemoteDictionary.all do |dic|
        assert_predicate(dic.fetch, :present?)
      end
    end

    def test_strict?
      RemoteDictionary.all do |dic|
        assert_boolean(dic.strict?)
      end
    end
  end
end
