module Mulukhiya
  module AccessTokenMethods
    include SNSMethods

    def webhook_digest
      return Webhook.create_digest(sns_class.new.uri, to_s)
    end

    def scopes_valid?
      return scopes == account.default_scopes
    end

    def self.included(base)
      base.extend(Methods)
    end

    module Methods
      def webhook_entries(&)
        return enum_for(__method__) unless block
        Postgres.instance.exec('webhook_tokens')
          .map {|row| row[:id]}
          .filter_map {|id| Environment.access_token_class[id] rescue nil}
          .select(&:valid?)
          .map(&:to_h)
          .each(&)
      end
    end
  end
end
