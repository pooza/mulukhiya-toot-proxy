namespace :mulukhiya do
  namespace :annict do
    desc 'crawl Annict'
    task :crawl do
      if Mulukhiya::Environment.controller_class.annict?
        crawl_all
      else
        warn "#{Mulukhiya::Environment.controller_class.name} doesn't support Annict."
        exit 1
      end
    end

    desc 'crawl Annict (dryrun)'
    task :crawl_dryrun do
      if Mulukhiya::Environment.controller_class.annict?
        crawl_all(dryrun: true, all: true)
      else
        warn "#{Mulukhiya::Environment.controller_class.name} doesn't support Annict."
        exit 1
      end
    end

    def crawl_all(params = {})
      accounts = Mulukhiya::AnnictAccountStorage.accounts
      bar = ProgressBar.create(total: accounts.count)
      results = {}
      accounts.each do |account|
        bar&.increment
        results[account.acct.to_s] = account.annict.crawl(
          dryrun: params[:dryrun],
          all: params[:all],
          webhook: params[:dryrun] ? nil : account.webhook,
        )
      end
      bar&.finish
      results.each do |key, result|
        puts({acct: key, result: result}.deep_stringify_keys.to_yaml)
      end
    end
  end
end
