module Mulukhiya
  extend Rake::DSL

  namespace :mulukhiya do
    namespace :annict do
      desc 'crawl Annict'
      task :crawl do
        AnnictPollingWorker.perform_async
      end
    end
  end
end
