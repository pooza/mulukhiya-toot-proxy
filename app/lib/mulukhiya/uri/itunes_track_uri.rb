module Mulukhiya
  class ItunesTrackURI < ItunesURI
    def valid?
      return false unless itunes?
      return false unless album?
      return false unless track?
      return true
    end

    alias shortenable? valid?

    def shorten
      return self unless shortenable?
      dest = clone
      dest.host = config['/itunes/hosts'].first
      dest.album_id = album_id
      dest.track_id = track_id
      return dest
    end

    def id
      return track_id
    end

    def album_id
      return nil unless matches = path.match(ItunesURI.pattern(:track))
      return matches[1].to_i
    end

    def album_id=(id)
      self.path = "/#{config['/itunes/country']}/album/#{id}"
      self.fragment = nil
    end

    def track_id
      return nil unless query_values['i']
      return query_values['i'].to_i
    rescue NoMethodError
      return nil
    end

    def track_id=(id)
      values = query_values || {}
      values['i'] = id.to_i
      values.delete('i') if id.nil?
      values = nil unless values.present?
      self.query_values = values
      self.fragment = nil
    end
  end
end
