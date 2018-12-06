require 'addressable/uri'
require 'httparty'
require 'nokogiri'

module MulukhiyaTootProxy
  class ItunesURI < Addressable::URI
    def initialize(options = {})
      super(options)
      @config = Config.instance
      @service = ItunesService.new
    end

    def itunes?
      return absolute? && host == 'itunes.apple.com'
    end

    def album_id
      @config['/itunes/patterns'].each do |entry|
        if matches = path.match(Regexp.new(entry['pattern']))
          return matches[1]
        end
      end
      return nil
    end

    def track_id
      return query_values['i']
    rescue NoMethodError
      return nil
    end

    def track
      return nil unless itunes?
      return nil unless track_id.present?
      return @service.lookup(track_id)
    end

    def image_uri
      return nil unless itunes?
      return nil unless track_id.present?
      track = @service.lookup(track_id)
      raise RequestError, "Track '#{track_id}' not found" unless track
      unless @image_uri
        response = HTTParty.get(track['trackViewUrl'], {
          headers: {
            'User-Agent' => Package.user_agent,
          },
        })
        body = Nokogiri::HTML.parse(response.body, nil, 'utf-8')
        elements = body.xpath('//picture/source')
        return nil unless elements.present?
        elements.first.attribute('srcset').text.split(/,/).each do |uri|
          next unless matches = uri.match(/^(.*) +3x$/)
          @image_uri = Addressable::URI.parse(matches[1])
          break if @image_uri&.absolute?
        end
      end
      return @image_uri
    end
  end
end
