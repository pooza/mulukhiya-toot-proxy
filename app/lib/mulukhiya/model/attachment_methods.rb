module Mulukhiya
  module AttachmentMethods
    include SNSMethods

    def self.included(base)
      base.extend(ClassMethods)
    end

    # media_catalog のクラスメソッド。⚠ **`AttachmentMethods` にクラスメソッドの
    # 口が無かったのが、2 ファイルへ複写された原因** (#4657)。
    module ClassMethods
      # media_catalog のページング。⚠⚠ **Mastodon / Misskey の 2 ファイルへ
      # 1 バイト違わず複写されていた (#4657)。**#4632 のような境界バグを次に
      # 直すとき、また片方だけ直す形になる。差分は cursor に使う列だけなので、
      # そこを `catalog_cursor_key` に切って本体は 1 本にする。
      def catalog(params = {})
        params[:limit] ||= config['/webui/media/catalog/limit']
        unless params[:rule] || params[:skip_cache]
          cached = catalog_from_cache(params)
          return cached if cached
        end
        rows = Postgres.exec(:media_catalog, params.merge(
          limit: params[:limit] + 1,
          offset: catalog_offset(params),
        ))
        has_next = rows.size > params[:limit]
        page_rows = rows.first(params[:limit])
        items = build_catalog_items(page_rows)
        result = {items:, has_next:}
        result[:next_cursor] = page_rows.last[catalog_cursor_key].to_s if has_next && page_rows.last
        result[:page] = params[:page] if params[:page]
        return result
      end

      # ⚠ **OFFSET は「ページ幅」で計算する (#4632)。**`has_next` を見るために
      # 取得件数へ +1 しているので、その `limit` を OFFSET の基準にも使うと
      # **ページごとに 1 件抜ける**（既定の 100 件なら page=2 が 101 件目から
      # 始まり、100 件目がどのページにも出ない）。取得件数とページ幅は
      # 別のキーで渡す。
      def catalog_offset(params)
        return 0 if params[:cursor]
        return 0 unless params[:page]
        return (params[:page] - 1) * params[:limit]
      end

      def catalog_from_cache(params)
        return nil if params[:cursor]
        page = params[:page] || 1
        only_person = params[:only_person] || 0
        return MediaCatalogStorage.new.get("page:#{page}:person:#{only_person}")
      rescue => e
        e.log
        return nil
      end

      # `next_cursor` に使う列。
      #
      # ⚠ Mastodon は `media_attachments.id`（unique）、Misskey は SQL が
      # note_id ベースで unnest を展開するため `status_id`。**この 1 行が
      # 2 ファイルを分けていた唯一の差分。**
      def catalog_cursor_key
        raise NotImplementedError, "\#{self}.catalog_cursor_key"
      end
    end

    def mediatype
      return type.split('/').first
    end

    def width
      return meta&.fetch(:width, nil)
    end

    def height
      return meta&.fetch(:height, nil)
    end

    def pixel_size
      return nil unless width
      return nil unless height
      return "#{width}x#{height}"
    end

    def duration
      return nil unless meta
      return nil unless meta[:duration]
      return meta[:duration].to_f.round(2)
    end

    def uri
      return create_uri(:original)
    end

    def thumbnail_uri
      return create_uri(:small)
    end

    def meta
      storage = MediaMetadataStorage.new
      storage.push(uri) unless storage.key?(uri)
      return storage[uri]
    rescue => e
      e.log(path:)
      return nil
    end

    def size_str
      return nil unless size
      ['', 'Ki', 'Mi', 'Gi', 'Ti', 'Pi', 'Ei', 'Zi', 'Yi'].freeze.each_with_index do |unit, i|
        unitsize = 1024.pow(i)
        return "#{(size.to_f / unitsize).floor.commaize}#{unit}B" if size < unitsize * 1024 * 2
      end
      raise 'Too large'
    rescue => e
      e.log(size:, attachment: id)
      return size
    end

    def feed_entry
      return {
        link: uri.to_s,
        title: [name, "(#{size_str})", description].compact.join(' '),
        author: account.display_name,
        created_at: date,
        date:,
      }
    end

    def to_h
      return values.deep_symbolize_keys.merge(
        created_at: date&.getlocal&.strftime('%Y/%m/%d %H:%M:%S'),
        duration:,
        file_name: name,
        file_size_str: size_str,
        id:,
        mediatype:,
        pixel_size:,
        thumbnail_url: thumbnail_uri.to_s,
        type:,
        url: uri.to_s,
      ).compact
    end
  end
end
