module Mulukhiya
  class PeerTubeURI < Ginseng::URI
    include Package

    def id
      return nil unless path.start_with?(config['/peer_tube/urls/video'])
      return path.split('/').last
    rescue
      return nil
    end

    def data
      return nil unless config['/peer_tube/hosts'].member?(host)
      return nil unless id
      @data ||= service.lookup(id)
      return @data
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

    alias track data

    def track?
      return data.present?
    end

    def track_name
      return data&.dig('name')
    end

    alias title track_name

    def artists
      return nil unless data
      return ArtistParser.new(data.dig('account', 'displayName')).parse
    end
  end
end
