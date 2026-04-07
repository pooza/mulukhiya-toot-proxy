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
  end
end
