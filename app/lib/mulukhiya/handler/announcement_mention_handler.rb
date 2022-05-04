module Mulukhiya
  class AnnouncementMentionHandler < MentionHandler
    def handle_mention(payload, params = {})
      params[:announcement] = Announcement.new
      super(payload, params)
    end

    def respondable?
      return false unless @status.match?(handler_config(:pattern))
      return super
    end
  end
end
