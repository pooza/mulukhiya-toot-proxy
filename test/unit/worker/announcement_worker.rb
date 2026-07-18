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

      # Announcement#load は save が書く id キーの Hash を読み戻すため Hash を返す
      # （cache.member?(id) がキー照合に使う）。空でも '{}' → {} で Hash。
      assert_kind_of(Hash, Announcement.new.load)
    end
  end
end
