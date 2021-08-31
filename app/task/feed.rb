namespace :mulukhiya do
  namespace :feed do
    desc 'update custom feeds'
    task :update do
      Mulukhiya::FeedUpdateWorker.perform_async
    end
  end
end
