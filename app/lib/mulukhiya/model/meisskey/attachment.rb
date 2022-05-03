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

      def uri
        @uri ||= Ginseng::URI.parse(values['src'] || values.dig('metadata', 'url'))
        return @uri
      end

      def thumbnail_uri
        return Ginseng::URI.parse(values.dig('metadata', 'thumbnailUrl'))
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
          row[:_files].filter_map {|f| self[f[:_id]]}.each do |attachment|
            note = Status[row[:_id]]
            records.push(attachment.to_h.deep_symbolize_keys.merge(
              date: note.date,
              status: note.to_h,
            ))
          end
        end
        return records
      end

      def self.feed(&block)
        return enum_for(__method__) unless block
        Status.aggregate(:media_catalog, {page: 1, limit: MediaFeedRenderer.limit}).each do |status|
          status[:_files].map {|f| f[:_id]}
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
