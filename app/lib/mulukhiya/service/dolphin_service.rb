module Mulukhiya
  class DolphinService < Ginseng::Dolphin
    include Package

    def initialize(uri = nil, token = nil)
      @config = Config.instance
      @logger = Logger.new
      @token = token || @config['/agent/test/token']
      @uri = NoteURI.parse(uri || @config['/dolphin/url'])
      @mulukhiya_enable = false
      @http = http_class.new
      @http.base_uri = @uri
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
