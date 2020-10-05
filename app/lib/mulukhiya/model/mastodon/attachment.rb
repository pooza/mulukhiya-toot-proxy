module Mulukhiya
  module Mastodon
    class Attachment < Sequel::Model(:media_attachments)
      many_to_one :status

      def to_h
        @hash ||= values.clone.compact
        return @hash
      end

      alias name file_file_name

      alias filename file_file_name

      def date
        return created_at.getlocal
      end

      alias size file_file_size

      def size_str
        return "#{size.to_i.commaize}b"
      end

      alias type file_content_type

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

      def self.feed_entries
        return enum_for(__method__) unless block_given?
        config = Config.instance
        params = {
          limit: config['/feed/media/limit'],
          test_usernames: config['/feed/test_usernames'],
        }
        Postgres.instance.execute('media_catalog', params).each do |row|
          attachment = Attachment[row[:id]]
          yield ({
            link: attachment.uri.to_s,
            title: "#{attachment.name} (#{attachment.size_str}) #{attachment.description}",
            author: row[:display_name] || "@#{row[:username]}@#{Environment.domain_name}",
            date: attachment.date,
          })
        end
      end
    end
  end
end
