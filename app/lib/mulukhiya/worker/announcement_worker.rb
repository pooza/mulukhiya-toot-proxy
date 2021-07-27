module Mulukhiya
  class AnnouncementWorker
    include Sidekiq::Worker
    sidekiq_options retry: false, unique: :until_executed

    def perform
      Announce.new.announce
    end
  end
end
