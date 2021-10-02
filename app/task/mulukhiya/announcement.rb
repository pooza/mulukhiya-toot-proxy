module Mulukhiya
  extend Rake::DSL

  namespace :mulukhiya do
    namespace :announcement do
      desc 'update announcements'
      task :update do
        if Environment.production?
          AnnouncementWorker.perform_async
        else
          AnnouncementWorker.new.perform
        end
      end
    end
  end
end
