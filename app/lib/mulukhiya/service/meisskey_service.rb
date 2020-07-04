module Mulukhiya
  class MeisskeyService < MisskeyService
    def initialize(uri = nil, token = nil)
      @config = Config.instance
      uri ||= @config['/meisskey/url']
      super
    end

    def notify(account, message, response = nil)
      note = {
        MeisskeyController.status_field => message,
        'visibleUserIds' => [account.id],
        'visibility' => MeisskeyController.visibility_name('direct'),
      }
      note['replyId'] = response['createdNote']['id'] if response
      return post(note)
    end
  end
end
