module Mulukhiya
  module AccessTokenMethods
    include SNSMethods

    def valid?
      return false if to_s.empty?
      return false unless account
      return true
    end

    def webhook_digest
      return Webhook.create_digest(sns_class.new.uri, to_s)
    end

    def scopes_valid?
      return controller_class.oauth_scopes == scopes
    end

    def to_h
      @hash ||= values.deep_symbolize_keys.merge(
        account:,
        digest: webhook_digest,
        is_scopes_valid: scopes_valid?,
        scopes: scopes.to_a,
        token: to_s,
      ).compact
      return @hash
    end

    def self.included(base)
      base.extend(ClassMethods)
    end

    module ClassMethods
      def webhook_entries(&block)
        return enum_for(__method__) unless block
        Postgres.exec(:webhook_tokens)
          .map {|row| row[:id]}
          .filter_map {|id| Environment.access_token_class[id] rescue nil}
          .select(&:valid?)
          .map(&:to_h)
          .each(&block)
      end
    end
  end
end
