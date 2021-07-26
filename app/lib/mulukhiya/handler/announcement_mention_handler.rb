module Mulukhiya
  class AnnouncementMentionHandler < Handler
    def disable?
      return true unless Environment.dbms_class.config?
      return true unless controller_class.streaming?
      return true unless controller_class.announcement?
      return false
    end

    def handle_mention(payload, params = {})
      self.payload = payload
      return unless respondable?
      return unless sns = params[:sns]
      return unless id = payload.dig('account', 'id') || payload.dig('body', 'id')
      return unless account = account_class[id]
      return if account.bot?
      sns.notify(account, create_body(sns), payload['status'])
      @prepared = true
    end

    def payload=(payload)
      @payload = payload
      @status = payload.dig('status', 'content')
    end

    def respondable?
      return false unless @status.match?(pattern)
      return true
    end

    def create_body(sns)
      return sns.announcements.map {|v| v[:text]}.join("\n\n")
    end

    def pattern
      return Regexp.new(config['/handler/announcement_mention/pattern'])
    end
  end
end
