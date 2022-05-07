module Mulukhiya
  module Meisskey
    class Attachment < MongoCollection
      include AttachmentMethods

      def account
        return Account[values.dig('metadata', 'userId')]
      end

      def type
        return contentType
      end

      def create_uri(size = :original)
        case size.to_sym
        in :small, :thumbnail
          return Ginseng::URI.parse(values.dig('metadata', 'thumbnailUrl'))
        in :original
          return Ginseng::URI.parse(values['src'] || values.dig('metadata', 'url'))
        end
      end

      def meta
        unless @meta
          @meta = values.dig('metadata', 'properties')
          @meta.merge!(super) unless mediatype == 'image'
        end
        return @meta
      rescue
        return {}
      end

      def date
        return values['uploadDate'].getlocal
      end

      def name
        return values['filename']
      end

      def size
        return values['length']
      end

      def self.[](id)
        return new(id)
      end

      def self.catalog(params = {})
        params[:page] ||= 1
        params[:limit] ||= config['/webui/media/catalog/limit']
        records = []
        Status.aggregate(:media_catalog, params).each do |row|
          note = Status[row[:_id]]
          account = Account[row[:user].first[:_id]]
          (row[:_files] || []).filter_map {|f| self[f[:_id]]}.each do |attachment|
            records.push(attachment.to_h.merge(
              account: {username: account.username, display_name: account.display_name},
              date: note.date,
              status: {body: note.body, public_url: note.public_uri.to_s},
            ))
          end
        end
        return records
      end

      def self.feed(&block)
        return enum_for(__method__) unless block
        Status.aggregate(:media_catalog, {page: 1, limit: MediaFeedRenderer.limit}).each do |status|
          (status[:_files] || []).filter_map {|f| f[:_id]}
            .filter_map {|id| self[id] rescue nil}
            .map(&:feed_entry)
            .each(&block)
        end
      end

      def self.collection
        return Mongo.instance.db['driveFiles.files']
      end

      private

      def collection_name
        return 'driveFiles.files'
      end
    end
  end
end
