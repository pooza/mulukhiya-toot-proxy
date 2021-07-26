module Mulukhiya
  class AnnouncementMentionHandler < MentionHandler
    def disable?
      return true unless controller_class.announcement?
      return super
    end

    def respondable?
      return false unless @status.match?(config['/handler/announcement_mention/pattern'])
      return super
    end
  end
end
