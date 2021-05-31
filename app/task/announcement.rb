namespace :mulukhiya do
  namespace :announcement do
    desc 'update announcements'
    task :update do
      Mulukhiya::Announcement.instance.announce
    end
  end
end
