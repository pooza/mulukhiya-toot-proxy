module Mulukhiya
  class BandaiChannelURI < Ginseng::URI
    def initialize(options = {})
      super
      @config = Config.instance
      @logger = Logger.new
    end

    def bandai_channel?
      return absolute? && @config['/bandai_channel/hosts'].member?(host)
    end

    alias valid? bandai_channel?

    def title_id
      unless @title_id
        @config['/bandai_channel/patterns'].each do |entry|
          next unless matches = Regexp.new(entry['pattern']).match(path)
          next unless id = matches[1]
          return @title_id = id.to_i
        end
      end
      return @title_id
    end

    def episode_id
      unless @episode_id
        @config['/bandai_channel/patterns'].each do |entry|
          next unless matches = Regexp.new(entry['pattern']).match(path)
          next unless id = matches[2]
          return @episode_id = id.to_i
        end
      end
      return @episode_id
    end

    def image_uri
      return nil unless bandai_channel?
      unless @image_uri
        response = service.get(to_s)
        body = Nokogiri::HTML.parse(response.body, nil, 'utf-8')
        uri = Ginseng::URI.parse(body.css('.bch-p-hero img').first.attribute('src').to_s)
        return nil unless uri&.absolute?
        uri.query = nil
        @image_uri = uri
      end
      return @image_uri
    rescue => e
      @logger.error(error: e, uri: to_s)
      return nil
    end

    private

    def service
      unless @service
        @service = HTTP.new
        @service.base_uri = "https://#{@config['/bandai_channel/hosts'].first}"
      end
      return @service
    end
  end
end
