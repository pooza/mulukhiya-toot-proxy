namespace :mulukhiya do
  namespace :announcement do
    desc 'update announcements'
    task :update do
      Mulukhiya::Announce.new.announce
    end
  end
end
