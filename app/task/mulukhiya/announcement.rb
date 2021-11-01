module Mulukhiya
  extend Rake::DSL

  namespace :mulukhiya do
    namespace :announcement do
      desc 'update announcements'
      task :update do
        AnnouncementWorker.perform_async
      end
    end
  end
end
