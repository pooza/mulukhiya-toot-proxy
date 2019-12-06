module MulukhiyaTootProxy
  class GrowiClippingWorker < ClippingWorker
    def perform(params)
      return unless account = Account[params['account_id']]
      return unless account.growi
      account.growi.clip(
        body: create_body(params),
        path: create_path(account.username),
      )
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
