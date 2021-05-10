namespace :mulukhiya do
  namespace :feed do
    desc 'update custom feeds'
    task :update do
      Mulukhiya::FeedUpdateWorker.new.perform
    end
  end
end
