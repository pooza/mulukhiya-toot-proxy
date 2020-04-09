module Mulukhiya
  class GrowiClippingWorker < ClippingWorker
    def perform(params)
      return unless account = Environment.account_class[params['account_id']]
      return unless account.growi
      account.growi.clip(
        body: create_body(params),
        path: create_path(account.username),
      )
    rescue Ginseng::RequestError => e
      @logger.error(worker: self.class.to_s, error: e.message)
    end

    def create_path(username)
      return File.join(
        '/',
        Package.short_name,
        'user',
        username,
        Time.now.strftime('%Y/%m/%d/%H%M%S'),
      )
    end
  end
end
