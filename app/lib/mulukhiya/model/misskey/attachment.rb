module Mulukhiya
  module Misskey
    class Attachment < Sequel::Model(:drive_file)
      many_to_one :account, key: :userId

      def to_h
        unless @hasn
          @hash = values.clone
          @hash.merge!(
            acct: account.acct.to_s,
            file_name: name,
            file_size_str: size_str,
            type: type,
            subtype: type.split('/').first,
            created_at: date,
            created_at_str: date.strftime('%Y/%m/%d %H:%M:%S'),
            meta: meta,
            url: webpublicUrl || values[:url],
            thumbnail_url: thumbnailUrl,
          )
          @hash.compact!
        end
        return @hash
      end

      def meta
        @meta ||= JSON.parse(self[:properties])
        return @meta
      rescue
        return {}
      end

      def uri(size = 'original')
        case size
        when 'small', 'thumbnail'
          return MastodonService.new.create_uri(thumbnailUrl)
        else
          return MastodonService.new.create_uri(webpublicUrl)
        end
      end

      def date
        return createdAt.getlocal
      end

      def size_str
        ['', 'Ki', 'Mi', 'Gi', 'Ti', 'Pi', 'Ei', 'Zi', 'Yi'].freeze.each_with_index do |unit, i|
          unitsize = 1024.pow(i)
          return "#{(size.to_f / unitsize).floor.commaize}#{unit}B" if size < unitsize * 1024 * 2
        end
        raise 'Too large'
      end

      def description
        return nil
      end

      def feed_entry
        return {
          link: uri.to_s,
          title: "#{name} (#{size_str}) #{description}",
          author: account.display_name || account.acct.to_s,
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
          attachment = Attachment[row[:id]]
          note = Status[row[:note_id]]
          yield attachment.to_h.merge(status_url: note.uri.to_s)
        rescue => e
          Logger.new.error(error: e.message, row: row)
        end
      end

      def self.feed
        return enum_for(__method__) unless block_given?
        Postgres.instance.execute('media_catalog', query_params).each do |row|
          yield Attachment[row[:id]].feed_entry
        rescue => e
          Logger.new.error(error: e.message, row: row)
        end
      end
    end
  end
end
