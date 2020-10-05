module Mulukhiya
  module Mastodon
    class Attachment < Sequel::Model(:media_attachments)
      many_to_one :status

      def to_h
        unless @hasn
          @hash = values.clone
          @hash.merge!(
            acct: status.account.acct.to_s,
            status_url: status.public_uri.to_s,
            file_name: name,
            file_size_str: size_str,
            type: type,
            subtype: type.split('/').first,
            created_at: date,
            created_at_str: date.strftime('%Y/%m/%d %H:%M:%S'),
            meta: meta,
            pixel_size: meta.dig('original', 'size'),
            url: uri('original').to_s,
            thumbnail_url: uri('small').to_s,
          )
          @hash.compact!
        end
        return @hash
      end

      alias name file_file_name

      alias filename file_file_name

      def date
        return created_at.getlocal
      end

      alias size file_file_size

      def size_str
        ['', 'Ki', 'Mi', 'Gi', 'Ti', 'Pi', 'Ei', 'Zi', 'Yi'].freeze.each_with_index do |unit, i|
          unitsize = 1024.pow(i)
          return "#{(size.to_f / unitsize).floor.commaize}#{unit}B" if size < unitsize * 1024 * 2
        end
        raise 'Too large'
      end

      alias type file_content_type

      def meta
        @meta ||= JSON.parse(self[:file_meta])
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
          author: status.account.display_name || status.account.acct.to_s,
          date: date,
        }
      end

      def self.query_params
        config = Config.instance
        return {
          limit: config['/feed/media/limit'],
          test_usernames: config['/feed/test_usernames'],
        }
      end

      def self.catalog
        return enum_for(__method__) unless block_given?
        return Postgres.instance.execute('media_catalog', query_params).each do |row|
          yield Attachment[row[:id]].to_h
        end
      end

      def self.feed
        return enum_for(__method__) unless block_given?
        Postgres.instance.execute('media_catalog', query_params).each do |row|
          yield Attachment[row[:id]].feed_entry
        end
      end
    end
  end
end
