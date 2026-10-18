module Mulukhiya
  module Pleroma
    # ⚠ Akkoma にタグの表は無い（`objects` の JSON の中）。名前だけを持つ（v4 と同じ）。
    class HashTag
      include Package
      include HashTagMethods
      include SNSMethods

      attr_reader :name
      attr_writer :raw_name

      def initialize(name)
        @name = name
      end

      # `HashTagMethods#to_h` が Sequel の `values` に重ねるので、列の無いこのモデルは空を返す（PR #4844 の Codex P1）。
      def values
        return {}
      end

      def self.get(key)
        case key
        in {tag: tag}
          return nil if tag.nil?
          record = new(tag.downcase)
          record.raw_name = tag
          return record
        end
      end
    end
  end
end
