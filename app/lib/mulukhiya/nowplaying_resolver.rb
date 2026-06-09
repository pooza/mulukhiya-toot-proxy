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

    # 優先連鎖の順にプロバイダを試し、最初にヒットした
    # {url:, provider:, normalized: {title, artist, album}} を返す。
    # ヒットしなければ {url: nil} (404 ではなく 200 + null)。
    def resolve
      return {url: nil} if @title.empty?
      provider_order.each do |provider|
        result = search(provider)
        return result if result
      end
      return {url: nil}
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
      }
    rescue => e
      e.log(provider: 'apple_music', keyword:)
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
      }
    rescue => e
      e.log(provider: 'spotify', keyword:)
      return nil
    end

    def keyword
      return [@title, @artist].reject(&:empty?).join(' ')
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

    def default_provider
      return normalize_provider(config['/nowplaying/resolve/default_provider']) || DEFAULT_PROVIDER
    end
  end
end
