module Mulukhiya
  module Meisskey
    class HashTag < MongoCollection
      include HashTagMethods
      attr_writer :raw_name

      def name
        return values['tag']
      end

      def to_h
        return values.deep_symbolize_keys.merge(
          name: name.to_hashtag_base,
          tag: raw_name.to_hashtag,
          url: uri.to_s,
          feed_url: feed_uri.to_s,
        ).except(
          :attachedUserIds,
          :attachedLocalUserIds,
          :attachedRemoteUserIds,
          :mentionedUserIds,
          :mentionedLocalUserIds,
          :mentionedRemoteUserIds,
        ).deep_compact
      end

      def create_feed(params)
        return [] unless Mongo.config?
        return notes(params).map {|v| Status.new(v[:_id])}.map do |status|
          {
            username: status.account.username,
            domain: status.account.acct.host,
            display_name: status.account.name || "@#{status.account.username}",
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
        e.log
        return {}
      end

      def self.[](id)
        return new(id)
      end

      def self.get(key)
        case key
        in {tag: tag}
          tag = collection.find(tag:).first
          tag ||= collection.find(tag: tag.downcase).first
          return nil unless tag
          record = new(tag[:_id])
          record.raw_name = key[:tag]
          return record
        else
          return nil
        end
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
