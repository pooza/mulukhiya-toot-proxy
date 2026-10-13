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

      # ⚠⚠ **cursor は `<note_id>.<fileIds の中の位置>` の 2 つ組 (#4375)。**media_catalog の SQL は
      # ノートの `fileIds` を展開するので、1 つのノートに添付が複数あると同じ note_id の行が続く。
      # 以前は note_id だけを cursor にしていて、ページの境目に当たったノートの残りの添付が
      # どのページにも出なかった (#4325)。そのため巡回ワーカーは OFFSET だけで送っていた。
      def self.cursor_pagination?
        return true
      end

      def self.catalog_cursor_key
        return :status_id
      end

      def self.catalog_cursor(row)
        return row[:status_id].to_s unless row[:file_order]
        return "#{row[:status_id]}.#{row[:file_order]}"
      end

      def self.build_catalog_items(rows)
        attachments = where(id: rows.map {|r| r[:id]}).to_h {|a| [a.id, a]}
        return rows.filter_map do |row|
          next unless attachment = attachments[row[:id]]
          flags = catalog_flags(row)
          attachment.to_h.merge(
            sensitive: flags[:sensitive],
            status: {
              body: flags[:body],
              spoiler_text: flags[:spoiler_text],
              public_url: Status.create_uri(:public, row.except(:id)).to_s,
              webui_url: Status.create_uri(:webui, row.except(:id)).to_s,
            },
            account: row.slice(:username, :display_name),
          )
        end
      end

      def self.feed(&block)
        return enum_for(__method__) unless block
        # ⚠ RSS はぼかせないので、閲覧注意・CW つきは載せない（`safe`）。
        rows = Postgres.exec(:media_catalog, {page: 1, limit: MediaFeedRenderer.limit, safe: true})
        ids = rows.map {|row| row[:id]}
        attachments = where(id: ids).to_h {|a| [a.id, a]}
        ids.filter_map {|id| attachments[id]&.feed_entry}.each(&block)
      end
    end
  end
end
