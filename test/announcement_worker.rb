module Mulukhiya
  class AnnouncementWorkerTest < TestCase
    def setup
      @worker = AnnouncementWorker.new
    end

    def test_perform
      @worker.perform
    end
  end
end
