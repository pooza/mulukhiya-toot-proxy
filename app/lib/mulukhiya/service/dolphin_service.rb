module Mulukhiya
  class DolphinService < MisskeyService
    include Package

    def initialize(uri = nil, token = nil)
      @config = Config.instance
      @logger = Logger.new
      @token = token || @config['/agent/test/token']
      @uri = NoteURI.parse(uri || @config['/dolphin/url'])
      @mulukhiya_enable = false
      @http = http_class.new
    end

    def announcements(params = {})
      raise Ginseng::GatewayError, 'Dolphin does not respond to announcements.'
    end

    def notify(account, message)
      return note(
        DolphinController.status_field => message,
        'visibleUserIds' => [account.id],
        'visibility' => DolphinController.visibility_name('direct'),
      )
    end
  end
end
