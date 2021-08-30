namespace :mulukhiya do
  namespace :annict do
    desc 'crawl Annict'
    task :crawl do
      Mulukhiya::AnnictPollingWorker.new.perform_async
    end

    desc 'crawl Annict (dryrun)'
    task :crawl_dryrun do
      Mulukhiya::AnnictService.crawl_all(dryrun: true, all: true)
    end
  end
end
