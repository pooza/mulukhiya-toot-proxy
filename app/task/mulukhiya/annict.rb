module Mulukhiya
  extend Rake::DSL

  namespace :mulukhiya do
    namespace :annict do
      desc 'crawl Annict'
      task :crawl do
        if Environment.development? || Environment.test?
          AnnictPollingWorker.new.perform
        else
          AnnictPollingWorker.perform_async
        end
      end
    end
  end
end
