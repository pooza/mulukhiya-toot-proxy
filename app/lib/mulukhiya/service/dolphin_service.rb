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

    def info(params = {})
      unless @info
        r = http.get('/nodeinfo/2.0')
        raise Ginseng::GatewayError, "Bad response #{r.code}" unless r.code == 200
        @info = r.parsed_response
      end
      return @info
    end

    alias nodeinfo info

    def create_tag_uri(tag)
      return create_uri("/tags/#{tag.sub('^#', '')}")
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
