module Mulukhiya
  # Akkoma（Pleroma 系）のサービスの差分 (#4566)。⚠ DB にも Akkoma にも繋がない。
  # 実機の確認は dev29（`st.akkoma.b-shock.org`）で行う。
  class PleromaServiceTest < TestCase
    def setup
      @service = PleromaService.allocate
    end

    # Akkoma の投稿の URL は `/notice/<id>`。
    def test_search_status_id_from_notice_uri
      uri = Ginseng::URI.parse('https://st.akkoma.b-shock.org/notice/AzYdGqJxfHLWq8Fjvs')

      assert_equal('AzYdGqJxfHLWq8Fjvs', @service.search_status_id(uri))
    end

    # ⚠ OAuth のスコープと名前は Pleroma の設定から引く（`MastodonController` を名指ししない）。
    def test_oauth_controller_class
      assert_equal(PleromaController, @service.oauth_controller_class)
      assert_equal(MastodonController, MastodonService.allocate.oauth_controller_class)
    end

    def test_controller_reads_pleroma_config
      assert_equal(['read', 'write'], PleromaController.oauth_scopes.to_a)
      assert_equal('postgres', PleromaController.dbms_name)
      assert_equal('toot', PleromaController.parser_name)
    end

    def test_default_uri
      assert_equal(config['/pleroma/url'], @service.default_uri.to_s)
    end
  end
end
