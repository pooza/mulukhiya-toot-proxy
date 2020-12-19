require 'digest/sha1'

module Mulukhiya
  module Pleroma
    class Attachment < Sequel::Model(:objects)
      include AttachmentMethods
      attr_accessor :account, :date

      def name
        return uri.path.split('/').last
      end

      def size
        unless @size
          File.write(path, HTTP.new.get(uri)) unless File.exist?(path)
          storage = MediaMetadataStorage.new
          storage.push(path) unless storage.get(path)
          @size = storage.get(path)['size']
        end
        return @size
      rescue => e
        logger.error(error: e, path: path)
        return 0
      end

      def description
        return nil
      end

      def type
        return data[:url].first[:mediaType]
      end

      def uri
        @uri ||= Ginseng::URI.parse(data[:url].first[:href])
        return @uri
      end

      def data
        @data ||= JSON.parse(values[:data]).deep_symbolize_keys
        return @data
      end

      def path
        return File.join(Environment.dir, 'tmp/media/', Digest::SHA1.hexdigest(
          [id, config['/crypt/salt']].to_json,
        ))
      end

      def to_h
        unless @hash
          @hash = data.merge(
            type: type,
            subtype: subtype,
            url: uri.to_s,
          )
          @hash.deep_compact!
        end
        return @hash
      end

      def feed_entry
        return {
          link: uri.to_s,
          title: "#{name} (#{size_str}) #{description}",
          author: account.display_name || account.acct.to_s,
          date: date,
        }
      end

      def self.get(key)
        rows = Postgres.instance.execute('attachment', key)
        return nil unless row = rows.first
        return Attachment[row['id']]
      end

      def self.query_params
        config = Config.instance
        return {
          limit: config['/feed/media/limit'],
          test_usernames: config['/feed/test_usernames'],
        }
      end

      def self.feed
        return enum_for(__method__) unless block_given?
        Postgres.instance.execute('media_catalog', query_params).each do |row|
          time = "#{row['created_at'].to_s.split(/\s+/)[0..1].join(' ')} UTC"
          attachment = Attachment.get(uri: row['uri'])
          attachment.account = Account.get(acct: Acct.new("@#{row['username']}@#{row['host']}"))
          attachment.date = Time.parse(time).getlocal
          yield attachment.feed_entry
        end
      end
    end
  end
end
