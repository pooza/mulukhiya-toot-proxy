namespace :mulukhiya do
  namespace :announcement do
    desc 'update announcements'
    task :update do
      Mulukhiya::Announcement.new.announce
    end
  end
end
