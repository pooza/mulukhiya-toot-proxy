module Mulukhiya
  class LemmyClipperTest < TestCase
    def disable?
      return true unless controller_class.lemmy?
      return true unless (account.lemmy rescue nil)
      return super
    end

    def setup
      @lemmy = account.lemmy
    end

    def test_uri
      assert_kind_of(Ginseng::URI, @lemmy.uri)
      assert_predicate(@lemmy.uri, :absolute?)
    end

    def test_communities
      assert_kind_of(Hash, @lemmy.communities)

      ic @lemmy.communities
    end
  end
end
