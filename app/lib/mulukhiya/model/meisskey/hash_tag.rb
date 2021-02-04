module Mulukhiya
  module Meisskey
    class HashTag < MongoCollection
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
        criteria = {'$and' => [{tags: name}], userId: {'$ne' => test_account.id}}
        criteria['$and'].push(tags: {'$in' => TagContainer.default_tag_bases}) if params[:local]
        notes = Status.collection.find(criteria).sort(createdAt: -1).limit(params[:limit])
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

      private

      def collection_name
        return :hashtags
      end
    end
  end
end
