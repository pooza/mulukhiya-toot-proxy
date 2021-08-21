module Mulukhiya
  module AccessTokenMethods
    include SNSMethods

    def webhook_digest
      return Webhook.create_digest(sns_class.new.uri, to_s)
    end

    def scopes_valid?
      return scopes == controller_class.oauth_scopes
    end

    def self.included(base)
      base.extend(Methods)
    end

    module Methods
      def webhook_entries
        return enum_for(__method__) unless block_given?
        Postgres.instance.exec('webhook_tokens').each do |row|
          token = Environment.access_token_class[row['id']]
          yield token.to_h if token.valid?
        end
      end
    end
  end
end
