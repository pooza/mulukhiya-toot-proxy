module Mulukhiya
  extend Rake::DSL

  namespace :mulukhiya do
    namespace :annict do
      desc 'crawl Annict'
      task :crawl do
        if Environment.production?
          AnnictPollingWorker.perform_async
        else
          AnnictPollingWorker.new.perform
        end
      end
    end
  end
end
