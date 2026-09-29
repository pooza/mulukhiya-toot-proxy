module Mulukhiya
  # ナウプレ enrich プロキシ (#4382 / capsicum#466)。構造化メタデータ
  # (title / artist / album) を受け取り Spotify / iTunes を検索して共有可能な
  # URL を解決する。テキスト整形は行わず (整形は capsicum 側)、外部 API が返す
  # 正規化済みメタデータと URL のみを返す読み取り専用 enrich。
  #
  # プロバイダ優先順位は 3 段連鎖: ① 明示 prefer → ② source_app_name ヒント →
  # ③ サーバー既定 (/nowplaying/resolve/default_provider, 既定 apple_music)。
  # 優先側でヒットしなければもう一方のプロバイダへフォールバックする。
  class NowplayingResolver
    include Package

    PROVIDERS = ['apple_music', 'spotify'].freeze
    DEFAULT_PROVIDER = 'apple_music'.freeze

    # iTunes Search API は資格情報不要で常時利用可能なため resolver は常に有効。
    # /about の features.nowplaying_resolver の正本 (capsicum の enrich 試行判定)。
    def self.enabled?
      return true
    end

    def initialize(title:, artist: nil, album: nil, source_app_name: nil, prefer: nil)
      @title = title.to_s.strip
      @artist = artist.to_s.strip
      @album = album.to_s.strip
      @source_app_name = source_app_name.to_s.strip
      @prefer = prefer.to_s.strip
    end

    # ジャケット画像の一辺 (px) の既定。`itunes_image` ハンドラの `pixel` が取れないとき (#4769)。
    DEFAULT_ARTWORK_PIXEL = 480

    # 優先連鎖の順にプロバイダを試し、最初にヒットした
    # {url:, provider:, normalized: {title, artist, album}, artwork_url:} を返す。
    # ヒットしなければ {url: nil, artwork_url: nil} (404 ではなく 200 + null)。
    #
    # ⚠ **`artwork_url` のキーは常に返す**（取れなければ null・#4769）。クライアントが
    # 「キーが無い」と「画像が無い」を区別せずに済むように。画像の取得・添付・リサイズは
    # しない（URL を返すだけ。添付は capsicum 側）。
    def resolve
      return {url: nil, artwork_url: nil} if @title.empty?
      provider_order.each do |provider|
        result = search(provider)
        return result if result
      end
      return {url: nil, artwork_url: nil}
    end

    # Spotify のアルバム画像（大きい順に 640 / 300 / 64 など）から、`pixel` 以上で最小のものを
    # 選ぶ。足りるものが無ければ Spotify の並びの先頭（＝最大）(#4769)。
    # ⚠ Spotify は任意サイズを作れないので、Apple Music と同じ一辺には揃わない。
    # ⚠ `width` が null の画像もある。0 扱いで並べ替えると先頭の最大画像を取り逃すので、
    # サイズ不明のものは「足りる候補」から外し、フォールバックは並び順に任せる。
    def self.spotify_artwork_url(images, pixel)
      images = Array(images).map {|v| v.to_h.transform_keys(&:to_s)}.select {|v| v['url'].present?}
      return nil if images.empty?
      sufficient = images.select {|v| v['width'].to_i >= pixel}.min_by {|v| v['width'].to_i}
      return (sufficient || images.first)['url']
    end

    # Apple Music の `artworkUrl100` のサイズ指定を差し替える（`ItunesURI#image_uri` と同じ・#4769）。
    def self.apple_music_artwork_url(url, pixel)
      return nil unless url.present?
      return url.sub('100x100', "#{pixel}x#{pixel}")
    end

    private

    # ① prefer → ② source_app_name ヒント → ③ サーバー既定 の順で最優先プロバイダを
    # 決め、残りをフォールバックとして後段に並べる (既定は常に非 nil)。
    def provider_order
      preferred = [normalize_provider(@prefer), hint_provider, default_provider].find(&:itself)
      return ([preferred] + PROVIDERS).compact.uniq
    end

    def search(provider)
      case provider
      when 'apple_music' then search_apple_music
      when 'spotify' then search_spotify
      end
    end

    def search_apple_music
      return nil unless track = ItunesService.new.search(keyword, 'music')
      url = track['trackViewUrl'].presence || track['collectionViewUrl'].presence
      return nil unless url
      return {
        url:,
        provider: 'apple_music',
        normalized: {
          title: track['trackName'],
          artist: track['artistName'],
          album: track['collectionName'],
        }.compact,
        artwork_url: self.class.apple_music_artwork_url(track['artworkUrl100'], artwork_pixel),
      }
    rescue => e
      # keyword は曲名・アーティスト等のユーザー入力なのでログに残さない (#4394)。
      e.log(provider: 'apple_music')
      return nil
    end

    def search_spotify
      return nil unless SpotifyService.config?
      return nil unless track = SpotifyService.new.search_track(keyword)
      return nil unless url = track.external_urls['spotify'].presence
      return {
        url:,
        provider: 'spotify',
        normalized: {
          title: track.name,
          artist: track.artists.map(&:name).join(', ').presence,
          album: track.album&.name,
        }.compact,
        artwork_url: self.class.spotify_artwork_url(track.album&.images, artwork_pixel),
      }
    rescue => e
      # keyword は曲名・アーティスト等のユーザー入力なのでログに残さない (#4394)。
      e.log(provider: 'spotify')
      return nil
    end

    # クライアントが渡した構造化メタデータをすべて検索語に含める。artist が欠落
    # していても album で曲を絞り込めるようにする (#4382 Codex P2)。
    def keyword
      return [@title, @artist, @album].reject(&:empty?).join(' ')
    end

    # source_app_name から優先プロバイダを推定する。判定できなければ nil。
    def hint_provider
      name = @source_app_name.downcase
      return 'spotify' if name.include?('spotify')
      return 'apple_music' if name.include?('apple music') || name.include?('itunes')
      return 'apple_music' if name == 'music'
      return nil
    end

    def normalize_provider(value)
      normalized = value.to_s.downcase.tr('-', '_')
      return normalized if PROVIDERS.include?(normalized)
      return nil
    end

    # ジャケットの一辺。`itunes_image` ハンドラ（既定で無効）の `pixel` に揃える (#4769)。
    # ⚠ ハンドラの有効・無効は見ない。添付するかどうかではなく、大きさの設定だけを借りる。
    def artwork_pixel
      return config['/handler/itunes_image/pixel'].to_i.nonzero? || DEFAULT_ARTWORK_PIXEL
    rescue Ginseng::ConfigError
      return DEFAULT_ARTWORK_PIXEL
    end

    def default_provider
      return normalize_provider(config['/nowplaying/resolve/default_provider']) || DEFAULT_PROVIDER
    end
  end
end
