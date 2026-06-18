module Mulukhiya
  # ナウプレ URL→メタ解決プロキシ (#4415 / capsicum#729)。共有 (Share) 経路は
  # ShareExtension から URL しか受け取らず title/artist/album を持たないため、
  # capsicum が in-app と同じ formatter で整形できるよう URL からメタを逆引きする。
  #
  # メタデータ → 共有 URL を解決する NowplayingResolver (#4382) と対になる、逆方向
  # (URL → メタデータ) の読み取り専用 enrich。テキスト整形は行わず (整形は capsicum
  # 側)、外部 API が返す正規化済みメタデータと URL のみを返す。
  class NowplayingUrlResolver
    include Package

    # iTunes 経路は資格情報不要で常時利用可能なため resolver は常に有効。
    # /about の features.nowplaying_url_resolver の正本 (capsicum の enrich 試行判定)。
    def self.enabled?
      return true
    end

    def initialize(url:)
      @url = url.to_s.strip
    end

    # host でプロバイダを振り分け、URL からメタを抽出した
    # {url:, provider:, normalized: {title, artist, album}} を返す (resolve と同形)。
    # 解決不可 (未対応 host / track・album とも nil) は {url: nil} (404 ではなく 200 + null)。
    def resolve
      return {url: nil} if @url.empty?
      uri = parse
      return {url: nil} unless uri
      title = uri.track_name
      album = uri.album_name
      return {url: nil} if title.nil? && album.nil?
      return {
        url: uri.to_s,
        provider:,
        normalized: {
          title:,
          artist: Array(uri.artists).join(', ').presence,
          album:,
        }.compact,
      }
    rescue => e
      # url はユーザー入力なのでログに残さない (#4394 と同方針)。
      e.log(provider: provider)
      return {url: nil}
    end

    private

    # host から振り分けた URI クラスでパースする。Spotify は資格情報必須なので
    # 未設定なら nil (apple_music は資格情報不要)。未対応 host も nil。
    def parse
      case provider
      when 'spotify'
        return nil unless SpotifyService.config?
        return SpotifyURI.parse(@url)
      when 'apple_music'
        return ItunesURI.create(@url)
      end
    end

    def provider
      @provider ||= detect_provider
    end

    def detect_provider
      host = base_uri&.host.to_s.downcase
      return 'spotify' if host.split('.').member?('spotify')
      return 'apple_music' if config['/service/itunes/hosts'].member?(host)
      return nil
    end

    def base_uri
      @base_uri ||= Ginseng::URI.parse(@url)
    rescue
      return nil
    end
  end
end
