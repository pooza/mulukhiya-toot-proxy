module Mulukhiya
  class ItunesAlbumURI < ItunesURI
    def valid?
      return false unless itunes?
      return false unless album?
      return true
    end

    def shorten
      return self unless shortenable?
      dest = clone
      dest.host = config['/itunes/hosts'].first
      dest.album_id = album_id
      return dest
    end

    def id
      return album_id
    end

    def album_id
      return nil unless matches = path.match(ItunesURI.pattern(:album))
      return matches[1].to_i
    end

    def album_id=(id)
      self.path = "/#{config['/itunes/country']}/album/#{id}"
      self.fragment = nil
    end
  end
end
