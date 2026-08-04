module Mulukhiya
  class AnnictPollingWorker < Worker
    sidekiq_options retry: false

    def disable?
      return true unless controller_class.annict?
      return super
    end

    def perform(params = {})
      # every 1m。Annict 非対応サーバーでも AnnictService.accounts (DB) と
      # crawl_all (Annict への外部 HTTP) が毎分走ってしまう (#4506)。
      return if disable?
      log(accounts: AnnictService.accounts.count)
      AnnictService.crawl_all
    end
  end
end
