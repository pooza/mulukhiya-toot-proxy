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

      def create_uri(size = :original)
        case size.to_sym
        in :small | :thumbnail
          return MisskeyService.new.create_uri(thumbnailUrl || webpublicUrl || url)
        in :original
          return MisskeyService.new.create_uri(webpublicUrl || url)
        end
      end

      def date
        return MisskeyService.parse_aid(id)
      end

      def description
        return nil
      end

      def self.catalog(params = {})
        params[:page] ||= 1
        params[:limit] ||= config['/webui/media/catalog/limit']
        rows = Postgres.exec(:media_catalog, params.merge(limit: params[:limit] + 1))
        has_next = rows.size > params[:limit]
        page_rows = rows.first(params[:limit])
        items = build_catalog_items(page_rows)
        return {items:, page: params[:page], has_next:}
      end

      def self.build_catalog_items(rows)
        attachments = where(id: rows.map {|r| r[:id]}).to_h {|a| [a.id, a]}
        return rows.filter_map do |row|
          next unless attachment = attachments[row[:id]]
          attachment.to_h.merge(
            status: {
              body: row[:status_text],
              public_url: Status.create_uri(:public, row.except(:id)).to_s,
              webui_url: Status.create_uri(:webui, row.except(:id)).to_s,
            },
            account: row.slice(:username, :display_name),
          )
        end
      end

      def self.feed(&block)
        return enum_for(__method__) unless block
        rows = Postgres.exec(:media_catalog, {page: 1, limit: MediaFeedRenderer.limit})
        ids = rows.map {|row| row[:id]}
        attachments = where(id: ids).to_h {|a| [a.id, a]}
        ids.filter_map {|id| attachments[id]&.feed_entry}.each(&block)
      end
    end
  end
end
