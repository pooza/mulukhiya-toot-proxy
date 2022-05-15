module Mulukhiya
  class MentionHandler < Handler
    attr_reader :sender

    def disableable?
      return false
    end

    def disable?
      return true unless controller_class.streaming?
      return true unless info_agent_service
      return super
    end

    def handle_mention(payload, params = {})
      self.payload = payload
      return unless respondable?
      return unless sns = params[:sns]
      return unless sender
      return if sender.bot?
      sns.notify(sender, create_body(params), payload['status'] || payload['body'])
      @break = true
    end

    def payload=(payload)
      @payload = payload
      @status = payload.dig('status', 'content') || payload.dig('body', 'text')
      @sender = Environment.listener_class.sender(payload)
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
