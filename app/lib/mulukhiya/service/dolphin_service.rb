module Mulukhiya
  class DolphinService < Ginseng::Fediverse::DolphinService
    include Package

    def upload(path, params = {})
      params[:trim_times].times {ImageFile.new(path).trim!} if params[:trim_times]
      return super
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

    private

    def default_token
      return @config['/agent/test/token']
    end
  end
end
