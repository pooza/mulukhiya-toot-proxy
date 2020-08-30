module Mulukhiya
  class MeisskeyController < MisskeyController
    include ControllerMethods

    post '/api/messaging/messages/create' do
      Handler.dispatch(:pre_chat, params, {reporter: @reporter, sns: @sns})
      @reporter.response = @sns.say(params)
      notify(@reporter.response.parsed_response) if response_error?
      Handler.dispatch(:post_chat, params, {reporter: @reporter, sns: @sns})
      @renderer.message = @reporter.response.parsed_response
      @renderer.status = @reporter.response.code
      return @renderer.to_s
    rescue Ginseng::ValidateError => e
      @renderer.message = {'error' => e.message}
      notify('error' => e.raw_message)
      @renderer.status = e.status
      return @renderer.to_s
    end

    def self.name
      return 'Meisskey'
    end

    def self.webhook_entries
      return enum_for(__method__) unless block_given?
      Meisskey::AccessToken.all.reverse_each do |token|
        yield token.to_h if token.valid?
      end
    end
  end
end
