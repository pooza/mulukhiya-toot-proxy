module Mulukhiya
  class DefaultTagHandler < TagHandler
    def disable?
      return true unless self.class.tags.present?
      return super
    end

    def addition_tags
      return self.class.tags
    end

    def self.tags
      return TagContainer.new(new.handler_config(:tags))
    rescue => e
      e.log
      return TagContainer.new
    end
  end
end
