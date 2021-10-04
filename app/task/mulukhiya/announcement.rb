module Mulukhiya
  extend Rake::DSL

  namespace :mulukhiya do
    namespace :announcement do
      desc 'update announcements'
      task :update do
        if Environment.development? || Environment.test?
          AnnouncementWorker.new.perform
        else
          AnnouncementWorker.perform_async
        end
      end
    end
  end
end
