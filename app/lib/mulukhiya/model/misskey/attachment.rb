module Mulukhiya
  module Misskey
    class Attachment < Sequel::Model(:drive_file)
      include Package
      include AttachmentMethods
      include SNSMethods
      many_to_one :account, key: :userId

      def meta
        unless @meta
          @meta = JSON.parse(values[:properties]).deep_symbolize_keys
          @meta.merge!(super) unless mediatype == 'image'
        end
        return @meta
      rescue
        return {}
      end

      def uri(size = 'original')
        case size
        when 'small', 'thumbnail'
          return MisskeyService.new.create_uri(thumbnailUrl || webpublicUrl || url)
        else
          return MisskeyService.new.create_uri(webpublicUrl || url)
        end
      end

      def thumbnail_uri
        return uri('small')
      end

      def date
        return createdAt.getlocal
      end

      def description
        return nil
      end

      def self.catalog(params = {})
        params[:page] ||= 1
        params[:limit] ||= config['/webui/media/catalog/limit']
        service = MisskeyService.new
        return Postgres.exec(:media_catalog, params).map do |row|
          self[row[:id]].to_h.merge(
            status: {
              id: row[:status_id],
              body: row[:status_text],
              public_url: service.create_uri("/notes/#{row[:status_id]}").to_s,
            },
            account: row.slice(:username, :display_name),
          )
        end
      end

      def self.feed(&block)
        return enum_for(__method__) unless block
        Postgres.exec(:media_catalog, {page: 1, limit: MediaFeedRenderer.limit})
          .map {|row| row[:id]}
          .filter_map {|id| self[id] rescue nil}
          .map(&:feed_entry)
          .each(&block)
      end
    end
  end
end
