module Mulukhiya
  module Meisskey
    class HashTag < MongoCollection
      include Package
      include HashTagMethods

      def name
        return values['tag']
      end

      def to_h
        unless @hash
          @hash = values.deep_symbolize_keys.merge(
            name: name.to_hashtag_base,
            tag: name.to_hashtag,
            url: uri.to_s,
            feed_url: feed_uri.to_s,
          )
          @hash.delete(:attachedUserIds)
          @hash.delete(:attachedLocalUserIds)
          @hash.delete(:attachedRemoteUserIds)
          @hash.delete(:mentionedUserIds)
          @hash.delete(:mentionedLocalUserIds)
          @hash.delete(:mentionedRemoteUserIds)
          @hash.deep_compact!
        end
        return @hash
      end

      def create_feed(params)
        return [] unless Mongo.config?
        notes = Status.collection
          .find(tags: name, userId: {'$ne' => Environment.test_account.id})
          .sort(createdAt: -1)
          .limit(params[:limit])
        return notes.map do |row|
          status = Status.new(row['_id'])
          {
            username: status.account.username,
            domain: status.account.acct.host,
            display_name: status.account.name,
            spoiler_text: status.cw,
            text: status.text,
            uri: status.uri.to_s,
            created_at: status.createdAt,
          }
        end
      end

      def self.[](id)
        return HashTag.new(id)
      end

      def self.get(key)
        return nil if key[:tag].nil?
        return nil unless tag = collection.find(tag: key[:tag]).first
        return HashTag.new(tag['_id'])
      end

      def self.first(key)
        return get(key)
      end

      def self.collection
        return Mongo.instance.db[:hashtags]
      end

      def self.field_tag_bases
        tag_bases = []
        accounts = Account.collection.find(host: nil, fields: {'$ne' => nil})
        accounts.each do |account|
          account = Account[account['_id'].to_s]
          tag_bases.concat(account.field_tag_bases)
        end
        return tag_bases.uniq.compact
      end

      def self.featured_tag_bases
        tag_bases = []
        accounts = Account.collection.find(host: nil, clientSettings: {'$ne' => nil})
        accounts.each do |account|
          account = Account[account['_id'].to_s]
          tag_bases.concat(account.featured_tag_bases)
        end
        return tag_bases.uniq.compact
      end

      private

      def collection_name
        return :hashtags
      end
    end
  end
end
