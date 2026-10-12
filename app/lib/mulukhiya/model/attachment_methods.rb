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
        return catalog_result(rows, params)
      end

      def catalog_result(rows, params)
        has_next = rows.size > params[:limit] && !catalog_last_page?(params)
        page_rows = rows.first(params[:limit])
        result = {items: build_catalog_items(page_rows), has_next:}
        result[:next_cursor] = page_rows.last[catalog_cursor_key].to_s if has_next && page_rows.last
        result[:page] = params[:page] if params[:page]
        return result
      end

      # ⚠ 上限のページでは「続きあり」と言わない（次を引くと 422 になる）。
      # ⚠ **`page` があれば cursor つきでも見る（PR #4833 の Codex P2）。**巡回ワーカーは
      # `page:` と `cursor:` を両方渡してページ単位のキャッシュを作るので、cursor で外すと、
      # 上限のページが `has_next: true` でキャッシュされ、次を引いた利用者が 422 になる。
      # ⚠ API からの cursor つきの要求は `page` を持たない（`MediaCatalogQueryService` が落とす）
      # ので、cursor で送る限り上限には掛からない。
      def catalog_last_page?(params)
        return false if params[:page].nil?
        max = config['/webui/media/catalog/max_page'] rescue nil
        return params[:page] >= (max || MediaListContract::DEFAULT_MAX_PAGE)
      end

      # 閲覧注意・CW の印 (5.41.0 のリリース前レビュー)。
      #
      # ⚠⚠ **未認証で届く一覧なので、ぼかす材料をクライアントへ渡す。**以前は印が無く、
      # CW の内側の本文とサムネイルがそのまま出ていた。
      # - `sensitive`: 閲覧注意。⚠ **CW つきも true に倒す**（CW の付いた投稿のメディアを
      #   印なしで並べない）
      # - `status.spoiler_text`: CW の文言
      # - `status.body`: ⚠ **CW つきは nil**（CW の内側を一覧に出さない）
      def catalog_flags(row)
        spoiler = row[:spoiler_text].to_s.strip
        spoiler = nil if spoiler.empty?
        return {
          sensitive: row[:sensitive] == true || !spoiler.nil?,
          spoiler_text: spoiler,
          body: spoiler ? nil : row[:status_text],
        }
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
        cached = MediaCatalogStorage.new.get("page:#{page}:person:#{only_person}")
        # ⚠ **キャッシュの `has_next` は、いまの上限で見直す（PR #4833 の Codex P2）。**2 ページ目
        # 以降は 24 時間残るので、`max_page` を下げた後も古い `has_next: true` が返り、
        # 次を引いた利用者が 422 になる。
        cached[:has_next] = false if cached && catalog_last_page?(page:)
        return cached
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
        raise NotImplementedError, "#{self}.catalog_cursor_key"
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

    # RSS 2.0 の item に**そのまま渡す**ハッシュ (#4639)。
    #
    # ⚠⚠ **キーはすべて `RSS::Maker` の item のセッターとして送られる。**
    # `Ginseng::Web::RSS20FeedRenderer` は `entry.each {|k, v| item.send(:"#{k}=", v)}`
    # なので、**item に無いキーを 1 つでも混ぜると例外になり、その後ろのキーが全部捨てられる。**
    #
    # 🔴 以前は `created_at:` を持っていた。`created_at=` は item に無いので、
    # **`/feed/media` の全 item から `<pubDate>` が消え、item ごとに error 行が出ていた。**
    # media_catalog は 5.23.0 (#4343) から既定で無効だったので誰も踏まず、
    # **#4639 の Gate 2 の手順 3（dev26 で flip）で初めて表に出た。**
    # ⚠ 放置して本番で flip すると、**リクエストごと × item ごとに syslog が 1 行ずつ**増える
    # （#4549 の「日 2 万行」と同型）。
    # ⚠ 日時は `date:`（→ `<pubDate>`）だけで足りる。
    def feed_entry
      return {
        link: uri.to_s,
        title: [name, "(#{size_str})", description].compact.join(' '),
        author: account.display_name,
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
