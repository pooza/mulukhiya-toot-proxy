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

      def path(size = 'original')
        return File.join(
          '/media/media_attachments/files',
          id.to_s.gsub(/(\d)(?=(\d{3})+(?!\d))/, '\1/'),
          size,
          filename,
        )
      end

      def uri(size = 'original')
        return MastodonService.new.create_uri(path(size))
      end

      def thumbnail_uri
        return uri('small')
      end

      def self.catalog(params = {})
        params[:page] ||= 1
        params[:limit] ||= config['/webui/media/catalog/limit']
        rows = Postgres.exec(:media_catalog, params)
        return rows.map {|v| v[:id]}.filter_map {|v| self[v] rescue nil}.map do |record|
          record.to_h.merge(status: rcord.status.to_h)
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
