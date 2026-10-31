module Mulukhiya
  module Pleroma
    # 名前だけを持つ（v4 と同じ）。⚠ Akkoma には `hashtags` / `hashtags_objects` の表があり、
    # フィードの SQL（`tag_timeline`）はそれで引く（#4860）。`get` は投稿の表示からも呼ばれるので、
    # 表を読むのはタグのフィードの存否（`listable?`）だけにする。
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

      # 表に無いタグのフィードは 404 にする（Mastodon・Misskey と同じ）。
      def listable?
        return Postgres.exec(:hash_tag, tag: name).present?
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
