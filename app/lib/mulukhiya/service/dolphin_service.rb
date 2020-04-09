module Mulukhiya
  class DolphinService < Ginseng::Dolphin
    include Package
    attr_reader :token

    def initialize(uri = nil, token = nil)
      @config = Config.instance
      @logger = Logger.new
      @token = token || @config['/agent/test/token']
      @uri = NoteURI.parse(uri || @config['/dolphin/url'])
      @mulukhiya_enable = false
      @http = http_class.new
      @http.base_uri = @uri
    end

    def token=(token)
      @token = token
      @account = nil
    end

    def account
      @account ||= Environment.account_class.get(token: @token)
      return @account
    rescue
      return nil
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
