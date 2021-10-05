module Mulukhiya
  module Meisskey
    class HashTag < MongoCollection
      include HashTagMethods
      attr_writer :raw_name

      def name
        return values['tag']
      end

      def to_h
        unless @hash
          @hash = values.deep_symbolize_keys.merge(
            name: name.to_hashtag_base,
            tag: raw_name.to_hashtag,
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
        return notes(params).map do |row|
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

      def self.favorites
        favorites = {}
        Account.aggregate('tag_owners').map {|v| v.to_h['tags']}.each do |tags|
          tags.each do |tag|
            favorites[tag] ||= 0
            favorites[tag] += 1
          end
        end
        return favorites.sort_by {|_, v| v}.reverse.to_h
      rescue => e
        logger.error(error: e)
        return {}
      end

      def self.[](id)
        return HashTag.new(id)
      end

      def self.get(key)
        return nil if key[:tag].nil?
        return nil unless tag = collection.find(tag: key[:tag].downcase).first
        record = HashTag.new(tag['_id'])
        record.raw_name = key[:tag]
        return record
      end

      def self.first(key)
        return get(key)
      end

      def self.collection
        return Mongo.instance.db[:hashtags]
      end

      private

      def notes(params = {})
        return Status.aggregate('hash_tag_notes', {
          tag: raw_name,
          visibility: controller_class.visibility_name(:public),
          test_account: test_account,
          local: params[:local],
          limit: params[:limit],
        })
      end

      def collection_name
        return :hashtags
      end
    end
  end
end
