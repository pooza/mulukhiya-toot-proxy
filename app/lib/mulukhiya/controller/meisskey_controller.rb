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
      return config['/meisskey/status/field']
    end

    def self.status_key
      return config['/meisskey/status/key']
    end

    def self.attachment_key
      return config['/meisskey/attachment/key']
    end

    def self.poll_options_field
      return config['/meisskey/poll/options/field']
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
      Meisskey::AccessToken.all do |token|
        values = {
          digest: Webhook.create_digest(config['/meisskey/url'], token.hash),
          token: token.hash,
          account: token.account,
        }
        yield values
      end
    end
  end
end
