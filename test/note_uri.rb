module Mulukhiya
  class NoteURITest < TestCase
    def setup
      @uri = NoteURI.parse('https://dev.mis.b-shock.org/notes/86o6o8tm6t')
    end

    def test_id
      assert_equal(@uri.id, '86o6o8tm6t')
    end

    def test_service
      assert_kind_of(Environment.sns_class, @uri.service)
    end

    def test_to_md
      assert_equal(@uri.to_md, "## アカウント\n[ぷーざ@美食スキー](https://dev.mis.b-shock.org/@pooza)\n\n## 本文\n[@pooza](https://dev.mis.b-shock.org/@pooza) [@pooza@mstdn.b-shock.org](https://dev.mis.b-shock.org/@pooza@mstdn.b-shock.org) \nクリップのテストに使うノート。\n[#bshocksskey](https://dev.mis.b-shock.org/tags/bshocksskey)\n\n## URL\nhttps://dev.mis.b-shock.org/notes/86o6o8tm6t\n")
    end
  end
end
