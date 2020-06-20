module Mulukhiya
  class DolphinController < MisskeyController
    def self.name
      return 'Dolphin'
    end

    def self.webhook?
      return false
    end

    def self.clipping?
      return true
    end

    def self.announcement?
      return false
    end

    def self.filter?
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

    def self.poll_options_field
      return Config.instance['/dolphin/poll/options/field']
    end

    def self.visibility_name(name)
      return Config.instance["/dolphin/status/visibility_names/#{name}"]
    end

    def self.status_label
      return Config.instance['/dolphin/status/label']
    end

    def self.events
      return Config.instance['/dolphin/events'].map(&:to_sym)
    end

    def self.webhook_entries
      return enum_for(__method__) unless block_given?
    end
  end
end
