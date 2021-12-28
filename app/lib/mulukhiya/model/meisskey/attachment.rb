module Mulukhiya
  module Meisskey
    class Attachment < MongoCollection
      include AttachmentMethods

      def to_h
        unless @hash
          @hash = values.deep_symbolize_keys.merge(
            id: id,
            acct: account.acct.to_s,
            file_name: name,
            file_size_str: size_str,
            type: type,
            mediatype: mediatype,
            created_at: date,
            created_at_str: date.strftime('%Y/%m/%d %H:%M:%S'),
            meta: meta,
            url: uri.to_s,
            thumbnail_url: values.dig('metadata', 'thumbnailUrl'),
            pixel_size: pixel_size,
            duration: duration,
          )
          @hash.deep_compact!
        end
        return @hash
      end

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
        storage = MediaCatalogRenderStorage.new
        if storage[params].nil? || params[:q]
          records = []
          Status.aggregate('media_catalog', params).each do |row|
            status = Status[row[:_id]]
            row[:_files].filter_map {|f| self[f[:_id]]}.each do |attachment|
              records.push(attachment.to_h.deep_symbolize_keys.merge(
                id: attachment.id,
                date: status.createdAt.getlocal,
                status_url: status.uri.to_s,
              ))
            end
          end
          storage[params] = records unless params[:q]
        end
        return params[:q] ? records : storage[params]
      end

      def self.feed(&block)
        return enum_for(__method__) unless block
        Status.aggregate('media_catalog', {page: 1}).each do |status|
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
