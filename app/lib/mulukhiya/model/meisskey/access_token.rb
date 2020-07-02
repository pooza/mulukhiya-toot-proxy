module Mulukhiya
  module Meisskey
    class AccessToken
      attr_reader :id

      def initialize(id)
        @id = id.to_s
        @logger = Logger.new
      end

      def values
        @values ||= AccessToken.collection.find(_id: BSON::ObjectId.from_string(id)).first.to_h
        return @values
      end

      def to_h
        unless @hash
          @hash = values.clone
          @hash.delete('token')
          @hash['scopes'] = scopes
          @hash.compact!
        end
        return @hash
      end

      def account
        return Account.new(values['userId'])
      end

      def application
        return Application.new(values['appId'])
      end

      def scopes
        return application.permission
      end

      def self.get(key)
        return nil if key[:hash].nil?
        token = collection.find(hash: key[:hash]).first
        return AccessToken.new(token['_id'])
      end

      def self.first(key)
        return get(key)
      end

      def self.collection
        return Mongo.instance.db[:accessTokens]
      end
    end
  end
end
