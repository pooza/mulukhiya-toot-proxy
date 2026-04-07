module Mulukhiya
  module Mastodon
    class Attachment < Sequel::Model(:media_attachments)
      include Package
      include AttachmentMethods
      include SNSMethods

      many_to_one :status

      alias name file_file_name

      alias filename file_file_name

      alias size file_file_size

      def account
        return status.account
      end

      def date
        return Time.parse(created_at.strftime('%Y/%m/%d %H:%M:%S GMT')).getlocal
      end

      def pixel_size
        return nil if mediatype == 'audio'
        size = meta.dig(:original, :size)
        size ||= "#{meta.dig(:original, :width)}x#{meta.dig(:original, :height)}"
        return size
      end

      def duration
        return meta.dig(:original, :duration)&.round(2)
      end

      alias type file_content_type

      def meta
        @meta ||= JSON.parse(self[:file_meta]).deep_symbolize_keys
        return @meta
      rescue
        return {}
      end

      def path(size = :original)
        return File.join(
          '/media/media_attachments/files',
          id.to_s.gsub(/(\d)(?=(\d{3})+(?!\d))/, '\1/'),
          size.to_s,
          filename,
        )
      end

      def create_uri(size = :original)
        return MastodonService.new.create_uri(path(size))
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
            account: row.slice(:username, :display_name),
            status: {
              body: row[:status_text],
              public_url: Status.create_uri(:public, row.except(:id)).to_s,
              webui_url: Status.create_uri(:webui, row.except(:id)).to_s,
            },
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
