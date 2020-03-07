module Mulukhiya
  class DolphinController < MisskeyController
    def self.name
      return 'Dolphin'
    end

    def self.webhook?
      return false
    end

    def self.announcement?
      return false
    end

    def self.status_field
      return Config.instance['/dolphin/status/field']
    end

    def self.status_key
      return Config.instance['/dolphin/status/key']
    end

    def self.attachment_key
      return Config.instance['/dolphin/attachment/key']
    end

    def self.visibility_name(name)
      return Config.instance["/dolphin/status/visibility_names/#{name}"]
    end

    def self.events
      return Config.instance['/dolphin/events'].map(&:to_sym)
    end
  end
end
