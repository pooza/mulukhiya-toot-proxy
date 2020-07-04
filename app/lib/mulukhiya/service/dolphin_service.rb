module Mulukhiya
  class DolphinService < Ginseng::Fediverse::DolphinService
    include Package
    attr_reader :token

    def initialize(uri = nil, token = nil)
      @config = Config.instance
      token ||= @config['/agent/test/token']
      super
    end

    def token=(token)
      @token = token
      @account = nil
    end

    def filters
      return nil
    end

    def account
      @account ||= Environment.account_class.get(token: token)
      return @account
    rescue
      return nil
    end

    def access_token
      return nil
    end

    def notify(account, message, response = nil)
      note = {
        DolphinController.status_field => message,
        'visibleUserIds' => [account.id],
        'visibility' => DolphinController.visibility_name('direct'),
      }
      note['replyId'] = response['createdNote']['id'] if response
      return post(note)
    end
  end
end
