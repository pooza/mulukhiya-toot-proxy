module Mulukhiya
  class ItunesSongURI < ItunesURI
    def valid?
      return false unless itunes?
      return false unless song?
      return true
    end

    def id
      return song_id
    end

    def shorten
      return self unless shortenable?
      dest = clone
      dest.host = config['/itunes/hosts'].first
      dest.song_id = song_id
      return dest
    end

    def track
      return nil unless valid?
      @track ||= @service.lookup(song_id)
      return @track
    end

    def album_name
      return track&.dig('collectionName')
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
