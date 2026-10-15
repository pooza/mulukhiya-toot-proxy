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

    # 上限は `/api/v1/instance` から読む（PR #4844 の Codex P2）。
    def test_limits_from_instance
      @service.instance_variable_set(:@instance, {
        'max_toot_chars' => 8000,
        'configuration' => {'statuses' => {'max_media_attachments' => 6}},
      })

      assert_equal(8000, @service.max_post_text_length)
      assert_equal(6, @service.max_media_attachments)
    end

    def test_limits_fall_back_to_config
      @service.instance_variable_set(:@instance, {})

      assert_equal(config['/pleroma/status/default_max_length'], @service.max_post_text_length)
      assert_equal(config['/pleroma/attachment/limit'], @service.max_media_attachments)
    end

    def test_default_uri
      assert_equal(config['/pleroma/url'], @service.default_uri.to_s)
    end
  end
end
