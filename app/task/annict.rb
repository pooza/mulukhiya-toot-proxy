namespace :mulukhiya do
  namespace :annict do
    desc 'crawl Annict'
    task :crawl do
      unless Mulukhiya::Environment.controller_class.annict?
        warn "#{Mulukhiya::Environment.controller_class.name} doesn't support Annict."
        exit 1
      end
      Mulukhiya::AnnictService.crawl_all
    end

    desc 'crawl Annict (dryrun)'
    task :crawl_dryrun do
      unless Mulukhiya::Environment.controller_class.annict?
        warn "#{Mulukhiya::Environment.controller_class.name} doesn't support Annict."
        exit 1
      end
      Mulukhiya::AnnictService.crawl_all(dryrun: true, all: true)
    end
  end
end
