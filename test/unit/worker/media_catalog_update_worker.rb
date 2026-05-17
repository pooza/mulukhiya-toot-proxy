module Mulukhiya
  class MediaCatalogUpdateWorkerTest < TestCase
    def setup
      @worker = Worker.create(:media_catalog_update)
    end

    def test_worker_config
      assert_kind_of(Integer, @worker.worker_config(:pages))
    end

    def test_disable
      result = @worker.disable?

      assert_boolean(result)
    end

    def test_uses_dedicated_queue
      assert_equal('media_catalog', MediaCatalogUpdateWorker.sidekiq_options['queue'])
    end

    def test_cursor_pagination_delegated_to_attachment_class
      # attachment_class は Sequel::Model のため、DB 未接続環境で参照すると
      # クラスロード時に Sequel::Error になる。AttachmentTest と同じ DB
      # 構成ガードで保護する。
      return unless Environment.dbms_class&.config?
      if Environment.misskey_type?
        assert_false(@worker.attachment_class.cursor_pagination?)
      else
        assert_true(@worker.attachment_class.cursor_pagination?)
      end
    end
  end
end
