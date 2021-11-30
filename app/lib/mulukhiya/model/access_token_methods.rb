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
      def webhook_entries(&block)
        return enum_for(__method__) unless block
        Postgres.instance.exec('webhook_tokens')
          .map {|row| Environment.access_token_class[row['id']]}
          .select(&:valid?)
          .map(&:to_h)
          .each(&block)
      end
    end
  end
end
