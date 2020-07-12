module Mulukhiya
  class DolphinService < Ginseng::Fediverse::DolphinService
    include Package

    def account
      @account ||= Environment.account_class.get(token: token)
      return @account
    rescue
      return nil
    end

    def access_token
      return nil
    end

    def notes(params = {})
      headers = params[:headers] || {}
      headers['X-Mulukhiya'] = package_class.full_name unless mulukhiya_enable?
      return @http.post('/api/users/notes', {
        body: {userId: params[:account_id], i: token}.to_json,
        headers: headers,
      })
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
