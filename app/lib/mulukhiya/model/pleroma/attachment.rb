module Mulukhiya
  module Pleroma
    class Attachment < Sequel::Model(:objects)
      include Package
      include AttachmentMethods
      include SNSMethods
      attr_accessor :account, :date

      def name
        return uri.path.split('/').last
      end

      def to_h
        unless @hash
          @hash = data.deep_symbolize_keys.merge(
            id: id,
            file_name: name,
            file_size_str: size_str,
            pixel_size: pixel_size,
            duration: duration,
            type: type,
            mediatype: mediatype,
            url: uri.to_s,
            thumbnail_url: uri.to_s,
            meta: meta,
            created_at: date,
            created_at_str: date&.strftime('%Y/%m/%d %H:%M:%S'),
            acct: account&.acct&.to_s,
          )
          @hash.deep_compact!
        end
        return @hash
      end

      def size
        @size ||= meta[:size]
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

      def self.get(key)
        if key.key?(:acct)
          rows = Postgres.instance.execute('attachment', key)
          return nil unless row = rows.first
          return Attachment[row['id']]
        elsif key.key?(:id)
          return Attachment[key[:id]]
        end
      end

      def self.feed
        return enum_for(__method__) unless block_given?
        Postgres.instance.execute('media_catalog', query_params).each do |row|
          time = "#{row['created_at'].to_s.split(/\s+/)[0..1].join(' ')} UTC"
          attachment = Attachment.get(id: row['id'])
          attachment.account = Account.get(acct: Acct.new("@#{row['username']}@#{row['host']}"))
          attachment.date = Time.parse(time).getlocal
          yield attachment.feed_entry
        end
      end

      def self.catalog(params = {})
        return enum_for(__method__, params) unless block_given?
        return Postgres.instance.execute('media_catalog', query_params.merge(params)).each do |row|
          next unless attachment = Attachment.get(id: row['id'])
          time = "#{row['created_at'].to_s.split(/\s+/)[0..1].join(' ')} UTC"
          attachment.account = Account.get(acct: Acct.new("@#{row['username']}@#{row['host']}"))
          attachment.date = Time.parse(time).getlocal
          yield attachment.to_h.merge(status_url: row['status_uri'])
        end
      end
    end
  end
end
