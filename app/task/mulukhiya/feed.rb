module Mulukhiya
  extend Rake::DSL

  namespace :mulukhiya do
    namespace :feed do
      desc 'update custom feeds'
      task :update do
        FeedUpdateWorker.perform_async
      end
    end
  end
end
