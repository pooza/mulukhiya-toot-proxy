module Mulukhiya
  class DefaultTagHandler < TagHandler
    def disable?
      return true unless self.class.tags.present?
      return true unless @event.to_sym == :pre_toot
      return super
    end

    def addition_tags
      return self.class.tags
    end

    def self.tags
      return TagContainer.new(config['/handler/default_tag/tags'])
    end
  end
end
