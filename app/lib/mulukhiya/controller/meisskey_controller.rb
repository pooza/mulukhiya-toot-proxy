module Mulukhiya
  class MeisskeyController < MisskeyController
    def self.name
      return 'めいすきー'
    end

    def self.webhook?
      return true
    end

    def self.clipping?
      return false
    end

    def self.announcement?
      return false
    end

    def self.filter?
      return false
    end

    def self.parser_class
      return "Mulukhiya::#{Config.instance['/meisskey/parser'].camelize}Parser".constantize
    end

    def self.storage_class
      return "Mulukhiya::#{Config.instance['/meisskey/storage'].camelize}".constantize
    end

    def self.postgres?
      return Config.instance['/meisskey/storage'] == 'postgres'
    end

    def self.mongodb?
      return Config.instance['/meisskey/storage'] == 'mongodb'
    end

    def self.status_field
      return Config.instance['/meisskey/status/field']
    end

    def self.status_key
      return Config.instance['/meisskey/status/key']
    end

    def self.attachment_key
      return Config.instance['/meisskey/attachment/key']
    end

    def self.poll_options_field
      return Config.instance['/meisskey/poll/options/field']
    end

    def self.visibility_name(name)
      return Config.instance["/meisskey/status/visibility_names/#{name}"]
    end

    def self.status_label
      return Config.instance['/meisskey/status/label']
    end

    def self.events
      return Config.instance['/meisskey/events'].map(&:to_sym)
    end

    def self.webhook_entries
      return enum_for(__method__) unless block_given?
      config = Config.instance
      Meisskey::AccessToken.all do |token|
        values = {
          digest: Webhook.create_digest(config['/meisskey/url'], token.hash),
          sha1_digest: Webhook.create_sha1_digest(config['/meisskey/url'], token.hash),
          token: token.values[:hash],
          account: token.account,
        }
        yield values
      end
    end
  end
end
