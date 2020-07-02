module Mulukhiya
  class MeisskeyService < MisskeyService
    def initialize(uri = nil, token = nil)
      @config = Config.instance
      uri ||= @config['/meisskey/url']
      super
    end

    def notify(account, message)
      return note(
        MeisskeyController.status_field => message,
        'visibleUserIds' => [account.id],
        'visibility' => MeisskeyController.visibility_name('direct'),
      )
    end
  end
end
