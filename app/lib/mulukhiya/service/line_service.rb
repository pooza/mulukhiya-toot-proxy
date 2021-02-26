module Mulukhiya
  class LineService
    include Package

    def initialize(token = nil)
      @http = HTTP.new
      @http.base_uri = config['/line/urls/api']
    end

    def say(id, body)
      return @http.post('/v2/bot/message/push', {
        headers: {'Authorization' => "Bearer #{token}"},
        body: {
          to: id,
          messages: [{type: 'text', text: body.to_s.strip}],
        },
      })
    end

    def token
      config['/alert/line/token'] rescue nil
    end

    def self.config?
      return config['/alert/line/token'].present? rescue false
    end
  end
end
