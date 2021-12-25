module Mulukhiya
  module Meisskey
    class AccessToken < MongoCollection
      include AccessTokenMethods

      def valid?
        return false if to_s.empty?
        return false unless account
        return application.name == Package.name
      end

      def to_h
        return values.deep_symbolize_keys.merge(
          digest: webhook_digest,
          token: to_s,
          account: account,
          scopes: scopes,
          scopes_valid: scopes_valid?,
        ).except(
          :hash,
        ).deep_compact
      end

      def token
        return values['hash']
      end

      alias to_s token

      def account
        return Account.new(values['userId'])
      end

      def application
        return Application.new(values['appId'])
      end

      def scopes
        return application.scopes.to_set
      end

      def self.[](id)
        return AccessToken.new(id)
      end

      def self.get(key)
        return nil unless record = collection.find(hash: key[:hash] || key[:token]).first
        return AccessToken.new(record['_id'])
      end

      def self.first(key)
        return get(key)
      end

      def self.all(&block)
        return enum_for(__method__) unless block
        collection.find.filter_map {|v| AccessToken.new(v['_id'])}.each(&block)
      end

      def self.webhook_entries(&block)
        return enum_for(__method__) unless block
        aggregate('webhook_entries').filter_map {|v| AccessToken[v['_id']]}.map(&:to_h).each(&block)
      end

      def self.collection
        return Mongo.instance.db[:accessTokens]
      end

      private

      def collection_name
        return :accessTokens
      end
    end
  end
end
