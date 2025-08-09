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

      def size
        @size ||= meta[:size]
        return @size
      rescue => e
        e.log(path:)
        return 0
      end

      def description
        return nil
      end

      def type
        return data[:url].first[:mediaType]
      end

      def create_uri(size = :original)
        return Ginseng::URI.parse(data[:url].first[:href])
      end

      def data
        @data ||= JSON.parse(values[:data]).deep_symbolize_keys
        return @data
      end

      def self.get(key)
        case key
        in {id: id}
          return self[id]
        in {row: row}
          row = row.deep_symbolize_keys
          time = "#{row[:created_at].to_s.split(/\s+/)[0..1].join(' ')} UTC"
          attachment = get(id: row[:id])
          attachment.account = Account.get(acct: Acct.new("@#{row[:username]}@#{row[:host]}"))
          attachment.date = Time.parse(time).getlocal
          return attachment
        end
      end

      def self.catalog(params = {})
        params[:page] ||= 1
        params[:limit] ||= config['/webui/media/catalog/limit']
        rows = Postgres.exec(:media_catalog, params)
        return rows.filter_map do |row|
          get(row:).to_h.merge(
            account: {username: row[:username]},
            status: {body: row[:status_text], public_url: row[:status_uri]},
          )
        end
      end

      def self.feed(&block)
        return enum_for(__method__) unless block
        Postgres.exec(:media_catalog, {page: 1, limit: MediaFeedRenderer.limit})
          .filter_map {|row| get(row:) rescue nil}
          .map(&:feed_entry)
          .each(&block)
      end
    end
  end
end
