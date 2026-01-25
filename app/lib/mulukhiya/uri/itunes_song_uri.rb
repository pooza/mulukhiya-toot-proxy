module Mulukhiya
  class ItunesSongURI < ItunesURI
    def valid?
      return false unless itunes?
      return false unless song?
      return true
    end

    def track
      return nil unless itunes?
      return nil unless song_id
      @track ||= @service.lookup(song_id)
      return @track
    end

    def song_id
      return nil unless matches = path.match(ItunesURI.pattern(:song))
      return matches[1].to_i
    end

    def song_id=(id)
      self.path = "/#{config['/itunes/country']}/song/#{id}"
      self.fragment = nil
    end
  end
end
