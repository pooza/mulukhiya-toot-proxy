module Mulukhiya
  extend Rake::DSL

  namespace :mulukhiya do
    namespace :feed do
      desc 'update custom feeds'
      task :update do
        if Environment.development? || Environment.test?
          FeedUpdateWorker.new.perform
        else
          FeedUpdateWorker.perform_async
        end
      end
    end
  end
end
