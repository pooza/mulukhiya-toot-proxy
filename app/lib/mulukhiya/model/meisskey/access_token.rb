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
        unless @hash
          @hash = values.deep_symbolize_keys.merge(
            digest: webhook_digest,
            token: to_s,
            account: account,
            scopes: scopes,
          )
          @hash.delete(:hash)
          @hash.deep_compact!
        end
        return @hash
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
        return Set.new(application.scopes)
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

      def self.all
        return enum_for(__method__) unless block_given?
        collection.find.each do |token|
          yield AccessToken.new(token['_id'])
        end
      end

      def self.webhook_entries
        return enum_for(__method__) unless block_given?
        AccessToken.collection.aggregate([
          {'$sort' => {'createdAt' => -1}},
          {'$lookup' => {from: 'users', localField: 'userId', foreignField: '_id', as: 'user'}},
          {'$lookup' => {from: 'apps', localField: 'appId', foreignField: '_id', as: 'app'}},
          {'$match' => {
            'user.host' => nil,
            'app.name' => {'$regex' => "^#{Package.short_name}"},
          }},
        ]).each do |row|
          yield AccessToken[row['_id']].to_h
        end
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
