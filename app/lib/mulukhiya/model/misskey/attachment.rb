module Mulukhiya
  module Misskey
    class Attachment < Sequel::Model(:drive_file)
      include Package
      include AttachmentMethods
      include SNSMethods

      many_to_one :account, key: :userId

      def meta
        unless @meta
          @meta = JSON.parse(values[:properties]).deep_symbolize_keys
          @meta.merge!(super) unless mediatype == 'image'
        end
        return @meta
      rescue
        return {}
      end

      def create_uri(size = :original)
        case size.to_sym
        in :small | :thumbnail
          return MisskeyService.new.create_uri(thumbnailUrl || webpublicUrl || url)
        in :original
          return MisskeyService.new.create_uri(webpublicUrl || url)
        end
      end

      def date
        return MisskeyService.parse_aid(id)
      end

      def description
        return nil
      end

      # Misskey の media_catalog SQL は note_id ベースで unnest を展開するため、
      # 単一ノートに複数添付があると同 note_id の行が連続して並ぶ。non-unique な
      # 並びに対して `note_id < cursor` で次ページを取ると、ページ境界に該当した
      # ノートの残り添付がキャッシュから抜ける (#4325)。短期対処として cursor を
      # 更新せず OFFSET ページングのみを使う。SQL 側で複合キー cursor へ移行する
      # のは将来の改善 (#4323 と合わせて検討)。
      def self.cursor_pagination?
        return false
      end

      # Misskey の media_catalog SQL は note_id ベースで unnest を展開するので、
      # 添付の id ではなく `status_id` を cursor の基準にする。
      def self.catalog_cursor_key
        return :status_id
      end

      def self.build_catalog_items(rows)
        attachments = where(id: rows.map {|r| r[:id]}).to_h {|a| [a.id, a]}
        return rows.filter_map do |row|
          next unless attachment = attachments[row[:id]]
          attachment.to_h.merge(
            status: {
              body: row[:status_text],
              public_url: Status.create_uri(:public, row.except(:id)).to_s,
              webui_url: Status.create_uri(:webui, row.except(:id)).to_s,
            },
            account: row.slice(:username, :display_name),
          )
        end
      end

      def self.feed(&block)
        return enum_for(__method__) unless block
        rows = Postgres.exec(:media_catalog, {page: 1, limit: MediaFeedRenderer.limit})
        ids = rows.map {|row| row[:id]}
        attachments = where(id: ids).to_h {|a| [a.id, a]}
        ids.filter_map {|id| attachments[id]&.feed_entry}.each(&block)
      end
    end
  end
end
