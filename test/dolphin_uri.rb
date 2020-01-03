module MulukhiyaTootProxy
  class DolphinURITest < TestCase
    def setup
      @uri = DolphinURI.parse('https://dev.dol.b-shock.org/notes/8211d0fbnx')
    end

    def test_id
      assert_equal(@uri.id, '8211d0fbnx')
    end

    def test_service
      assert(@uri.service.is_a?(DolphinService))
    end

    def test_to_md
      assert_equal(@uri.to_md, "## アカウント\n[test](https://dev.dol.b-shock.org/@test)\n\n## 本文\n[#nowplaying](https://dev.dol.b-shock.org/tags/nowplaying) https://music.apple.com/jp/album/1447931442?i=1447931444&amp;uo=4 [#日本語のタグ](https://dev.dol.b-shock.org/tags/日本語のタグ)\nDANZEN!ふたりはプリキュア ~唯一無二の光たち~\n五條真由美(コーラス:うちやえゆか・宮本佳那子)\n[#五條真由美](https://dev.dol.b-shock.org/tags/五條真由美) [#うちやえゆか_宮本佳那子](https://dev.dol.b-shock.org/tags/うちやえゆか_宮本佳那子) [#ふたりはプリキュア](https://dev.dol.b-shock.org/tags/ふたりはプリキュア) [#うちやえゆか](https://dev.dol.b-shock.org/tags/うちやえゆか) [#宮本佳那子](https://dev.dol.b-shock.org/tags/宮本佳那子) [#mulukhiya](https://dev.dol.b-shock.org/tags/mulukhiya)\n\n## URL\nhttps://dev.dol.b-shock.org/notes/8211d0fbnx\n")
    end
  end
end
