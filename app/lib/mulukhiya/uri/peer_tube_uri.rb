module Mulukhiya
  class PeerTubeURI < Ginseng::URI
    include Package

    def id
      return nil unless path.start_with?(config['/peer_tube/urls/video'])
      return path.split('/')[4]
    rescue
      return nil
    end

    def data
      return nil unless config['/peer_tube/hosts'].member?(host)
      return nil unless id
      return service.lookup(id)
    end

    def service
      @service ||= PeerTubeService.new(host)
      return @service
    end

    def album
      return nil
    end

    def album?
      return false
    end

    def album_name
      return nil
    end

    def track_name
      return data&.dig('name')
    end

    def track?
      return data.present?
    end

    alias title track_name

    def artists
      return nil unless data
      return ArtistParser.new(data.dig('account', 'displayName')).parse
    end
  end
end
