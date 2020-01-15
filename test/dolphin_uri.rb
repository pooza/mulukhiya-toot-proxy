module Mulukhiya
  class DolphinURITest < TestCase
    def setup
      @uri = DolphinURI.parse('https://dev.dol.b-shock.org/notes/8210l8qhnc')
    end

    def test_id
      assert_equal(@uri.id, '8210l8qhnc')
    end

    def test_service
      assert_kind_of(DolphinService, @uri.service)
    end

    def test_to_md
      assert_equal(@uri.to_md, "## アカウント\n[鴉河雛​:pangya_syobo:​:dolphin_ap:](https://dlpn.xn--krsgw--n73t.com/@karasu_sue)\n\n## 本文\nテスト用\n\n## メディア\n![a5dac3c6-94bd-4afd-a80f-8ead2d18f10f](https://dev.dol.b-shock.org/files/a5dac3c6-94bd-4afd-a80f-8ead2d18f10f)\n\n## URL\nhttps://dlpn.xn--krsgw--n73t.com/notes/8210l8qhiq\n")
    end
  end
end
