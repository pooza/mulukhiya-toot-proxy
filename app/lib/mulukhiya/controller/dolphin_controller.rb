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

    def self.parser_class
      return "Mulukhiya::#{parser_name.camelize}Parser".constantize
    end

    def self.dbms_class
      return "Mulukhiya::#{dbms_name.camelize}".constantize
    end

    def self.postgres?
      return dbms_name == 'postgres'
    end

    def self.mongo?
      return dbms_name == 'mongo'
    end

    def self.dbms_name
      return config['/dolphin/dbms']
    end

    def self.parser_name
      return config['/dolphin/parser']
    end

    def self.status_field
      return config['/dolphin/status/field']
    end

    def self.status_key
      return config['/dolphin/status/key']
    end

    def self.attachment_key
      return config['/dolphin/attachment/key']
    end

    def self.poll_options_field
      return config['/dolphin/poll/options/field']
    end

    def self.visibility_name(name)
      return parser_class.visibility_name(name)
    end

    def self.status_label
      return config['/dolphin/status/label']
    end

    def self.events
      return config['/dolphin/events'].map(&:to_sym)
    end
  end
end
