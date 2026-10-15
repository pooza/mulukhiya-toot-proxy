module Mulukhiya
  module Pleroma
    # ⚠ 添付は `objects` の JSON（v4 と同じ）。メディアカタログ・フィードは最初の段階では
    # 対象外（#4566 の非ゴール）なので、`/pleroma/data/media_catalog` は false にしてある。
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
        e.log(id:)
        return 0
      end

      def description
        return data[:name]
      end

      def type
        return data[:url].first[:mediaType]
      end

      def create_uri(size = :original)
        return Ginseng::URI.parse(data[:url].first[:href])
      end

      def data
        value = values[:data]
        value = JSON.parse(value) if value.is_a?(String)
        @data ||= value.to_h.deep_symbolize_keys
        return @data
      end

      def self.get(key)
        case key
        in {id: id}
          return self[id]
        end
      end

      def self.catalog_cursor_key
        return :id
      end
    end
  end
end
