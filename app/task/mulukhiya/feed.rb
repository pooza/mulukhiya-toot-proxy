module Mulukhiya
  extend Rake::DSL

  namespace :mulukhiya do
    namespace :feed do
      desc 'update custom feeds'
      task :update do
        if Environment.production?
          FeedUpdateWorker.perform_async
        else
          FeedUpdateWorker.new.perform
        end
      end
    end
  end
end
