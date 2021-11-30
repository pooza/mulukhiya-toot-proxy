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
      def webhook_entries
        return enum_for(__method__) unless block_given?
        Postgres.instance.exec('webhook_tokens')
          .map {|v| Environment.access_token_class[v['id']]}
          .select(&:valid?)
          .each {|t| yield t.to_h}
      end
    end
  end
end
