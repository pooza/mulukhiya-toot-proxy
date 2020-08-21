module Mulukhiya
  class MeisskeyController < MisskeyController
    def self.name
      return 'めいすきー'
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
      return config['/meisskey/dbms']
    end

    def self.parser_name
      return config['/meisskey/parser']
    end

    def self.status_field
      return config['/parser/note/fields/body']
    end

    def self.status_key
      return config['/meisskey/status/key']
    end

    def self.attachment_field
      return config['/parser/note/fields/attachment']
    end

    def self.poll_options_field
      return config['/parser/note/fields/poll/options']
    end

    def self.spoiler_field
      return config['/parser/note/fields/spoiler']
    end

    def self.visibility_name(name)
      return parser_class.visibility_name(name)
    end

    def self.status_label
      return config['/meisskey/status/label']
    end

    def self.events
      return config['/meisskey/events'].map(&:to_sym)
    end

    def self.webhook_entries
      return enum_for(__method__) unless block_given?
      Meisskey::AccessToken.all.reverse_each do |token|
        yield token.to_h if token.valid?
      end
    end
  end
end
