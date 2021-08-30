namespace :mulukhiya do
  namespace :announcement do
    desc 'update announcements'
    task :update do
      Mulukhiya::AnnouncementWorker.new.perform_async
    end
  end
end
