module Mulukhiya
  class PleromaController < MastodonController
    def self.name
      return 'Pleroma'
    end

    def self.announcement?
      return false
    end

    def self.filter?
      return false
    end

    def self.livecure?
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
      return Config.instance['/pleroma/dbms']
    end

    def self.parser_name
      return Config.instance['/pleroma/parser']
    end

    def self.status_field
      return Config.instance['/pleroma/status/field']
    end

    def self.status_key
      return Config.instance['/pleroma/status/key']
    end

    def self.poll_options_field
      return Config.instance['/pleroma/poll/options/field']
    end

    def self.attachment_key
      return Config.instance['/pleroma/attachment/key']
    end

    def self.visibility_name(name)
      return parser_class.visibility_name(name)
    end

    def self.status_label
      return Config.instance['/pleroma/status/label']
    end

    def self.events
      return Config.instance['/pleroma/events'].map(&:to_sym)
    end

    def self.webhook_entries
      return enum_for(__method__) unless block_given?
      config = Config.instance
      Pleroma::AccessToken.order(Sequel.desc(:inserted_at)).all do |token|
        next unless token.account
        next unless token.token
        values = {
          digest: Webhook.create_digest(config['/pleroma/url'], token.token),
          token: token.token,
          account: token.account,
        }
        yield values
      end
    end
  end
end
