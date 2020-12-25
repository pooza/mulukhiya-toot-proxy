namespace :mulukhiya do
  namespace :annict do
    desc 'crawl Annict'
    task :crawl do
      service.crawl
    end

    desc 'crawl Annict (dryrun)'
    task :crawl_dryrun do
      service.crawl(dryrun: true, all: true)
    end

    def service
      return Mulukhiya::Environment.test_account.annict
    end
  end
end
