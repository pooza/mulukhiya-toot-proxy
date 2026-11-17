module Mulukhiya
  module Pleroma
    # ⚠ 添付は `objects` の `Document`（JSON・v4 と同じ）。メディアカタログは段階 5（#4911）で戻した。
    # SQL は `app/query/pleroma/media_catalog.sql.erb`（投稿の `attachment` を展開して `Document` を引く）。
    class Attachment < Sequel::Model(:objects)
      include Package
      include AttachmentMethods
      include SNSMethods

      # 上げた人。⚠ `Document` は `data->>'actor'` に AP の ID を持つ（`users.ap_id`）。
      def account
        @account ||= Account.first(ap_id: data[:actor])
        return @account
      end

      # ⚠ `inserted_at` は UTC をタイムゾーン無しで持つ（#4864）。
      def date
        return NaiveTime.utc(values[:inserted_at])&.getlocal
      end

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

      # ⚠⚠ **cursor は `<投稿の ID>.<attachment の中の位置>` の 2 つ組**（Misskey と同じ・#4375）。
      # 1 つの投稿に添付が複数あると、投稿の ID だけでは行が一意に並ばない。
      def self.cursor_pagination?
        return true
      end

      # ⚠ SQL は投稿の ID を uuid（`status_uuid`）で返す。API と URL は base62 の FlakeId。
      def self.catalog_cursor_key
        return :status_uuid
      end

      def self.catalog_cursor(row)
        return "#{FlakeId.encode(row[catalog_cursor_key])}.#{row[:file_order]}"
      end

      def self.build_catalog_items(rows)
        attachments = where(id: rows.map {|r| r[:id]}).to_h {|a| [a.id, a]}
        return rows.filter_map do |row|
          next unless attachment = attachments[row[:id]]
          flags = catalog_flags(row)
          status = {id: FlakeId.encode(row[:status_uuid])}
          attachment.to_h.except(:data, :inserted_at, :updated_at).merge(
            sensitive: flags[:sensitive],
            account: row.slice(:username, :display_name),
            status: {
              body: flags[:body],
              spoiler_text: flags[:spoiler_text],
              public_url: Status.create_uri(:public, status).to_s,
              webui_url: Status.create_uri(:webui, status).to_s,
            },
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
