namespace :mulukhiya do
  namespace :announcement do
    desc 'update announcements'
    task :update do
      Mulukhiya::Announcer.new.announce
    end
  end
end
