module Mulukhiya
  class AnnouncementWorkerTest < TestCase
    def disable?
      return true unless info_agent_service
      return super
    end

    def setup
      return if disable?
      @worker = Worker.create(:announcement)
    end

    def test_perform
      @worker.perform

      assert_kind_of(Array, Announcement.new.load)
    end
  end
end
