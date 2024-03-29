module Mulukhiya
  module Meisskey
    class AccessToken < MongoCollection
      include AccessTokenMethods

      def to_h
        return super.except(:hash)
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
        return new(id)
      end

      def self.get(key)
        case key
        in {hash: hash}
          return nil unless record = collection.find(hash:).first
          return new(record[:_id])
        in {token: token}
          return nil unless record = collection.find(hash: token).first
          return new(record[:_id])
        else
          return nil
        end
      end

      def self.first(key)
        return get(key)
      end

      def self.all(&block)
        return enum_for(__method__) unless block
        collection.find.filter_map {|v| new(v[:_id])}.each(&block)
      end

      def self.webhook_entries(&block)
        return enum_for(__method__) unless block
        aggregate(:webhook_entries).filter_map {|v| self[v[:_id]]}.map(&:to_h).each(&block)
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
