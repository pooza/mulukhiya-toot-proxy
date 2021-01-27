require 'time'

module Mulukhiya
  module Mastodon
    class Attachment < Sequel::Model(:media_attachments)
      include Package
      include AttachmentMethods
      include SNSMethods
      many_to_one :status

      def to_h
        unless @hash
          @hash = values.deep_symbolize_keys.merge(
            acct: status.account.acct.to_s,
            status_url: status.public_uri.to_s,
            file_name: name,
            file_size_str: size_str,
            type: type,
            mediatype: mediatype,
            created_at: date,
            created_at_str: date.strftime('%Y/%m/%d %H:%M:%S'),
            meta: meta,
            pixel_size: pixel_size,
            duration: duration,
            url: uri('original').to_s,
            thumbnail_url: uri('small').to_s,
          )
          @hash.delete(:file_meta)
          @hash.deep_compact!
        end
        return @hash
      end

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

      def feed_entry
        return {
          link: uri.to_s,
          title: "#{name} (#{size_str}) #{description}",
          author: account.display_name,
          date: date,
        }
      end

      def self.catalog(params = {})
        return enum_for(__method__, params) unless block_given?
        return Postgres.instance.execute('media_catalog', query_params.merge(params)).each do |row|
          yield Attachment[row[:id]].to_h
        rescue => e
          logger.error(error: e, row: row)
        end
      end

      def self.feed
        return enum_for(__method__) unless block_given?
        Postgres.instance.execute('media_catalog', query_params).each do |row|
          yield Attachment[row[:id]].feed_entry
        rescue => e
          logger.error(error: e, row: row)
        end
      end
    end
  end
end
