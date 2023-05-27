module Mulukhiya
  class PoipikuURI < Ginseng::URI
    include Package

    def initialize(options = {})
      super
      return unless SpotifyService.config?
      @http = HTTP.new
    end

    def poipiku?
      return absolute? && host.split('.').member?('poipiku')
    end

    alias valid? poipiku?

    def account_id
      return path.split('/')[1].to_i
    end

    def picture_id
      return File.basename(path, File.extname(path)).to_i
    end

    alias id picture_id

    def image_uri
      return nil unless poipiku?
      response = @http.get(self)
      return false unless element = response.body.nokogiri.css('img.IllustItemThumbImg').first
      return false unless uri = Ginseng::URI.parse(element.attribute('src'))
      uri.scheme = 'https'
      return false unless uri.absolute?
      return uri
    end
  end
end
