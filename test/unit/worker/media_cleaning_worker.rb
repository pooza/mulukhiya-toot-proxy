module Mulukhiya
  class MediaCleaningWorkerTest < TestCase
    def setup
      @worker = Worker.create(:media_cleaning)
      @media_dir = File.join(Environment.dir, 'tmp/media')
      FileUtils.mkdir_p(@media_dir)
    end

    def test_worker_config
      assert_kind_of(Integer, @worker.worker_config(:hours))
    end

    def test_perform
      path = File.join(@media_dir, 'test_purge.tmp')
      File.write(path, 'dummy')
      old_time = @worker.worker_config(:hours).hours.ago - 60
      File.utime(old_time, old_time, path)

      @worker.perform

      refute_path_exists(path)
    end
  end
end
