module Mulukhiya
  class MentionHandler < Handler
    attr_reader :sender

    def disable?
      return true unless Environment.dbms_class.config?
      return true unless controller_class.streaming?
      return false
    end

    def handle_mention(payload, params = {})
      self.payload = payload
      return unless respondable?
      return unless sns = params[:sns]
      return if sender.bot?
      sns.notify(sender, create_body(params), payload['status'] || payload['body'])
      @prepared = true
    end

    def payload=(payload)
      @payload = payload
      @status = payload.dig('status', 'content') || payload.dig('body', 'text')
      id = payload.dig('account', 'id') || payload.dig('body', 'user', 'id')
      @sender = account_class[id]
    end

    def respondable?
      return true
    end

    def template
      unless @template
        prefix = underscore.sub(/_mention$/, '')
        @template = Template.new(
          File.join('mention', (config["/agent/info/#{prefix}/template"] || prefix)),
        )
      end
      return @template
    end

    def create_body(params = {})
      template.params = params
      return template.to_s
    end
  end
end
