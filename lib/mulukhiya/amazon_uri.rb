require 'addressable/uri'
require 'mulukhiya/amazon_service'
require 'mulukhiya/config'

module MulukhiyaTootProxy
  class AmazonURI < Addressable::URI
    def initialize(options = {})
      super(options)
      @config = Config.instance
    end

    def shortenable?
      return false unless amazon?
      return false unless asin.present?
      patterns.each do |entry|
        next unless path.match(Regexp.new(entry['pattern']))
        return entry['shortenable']
      end
      return false
    end

    def amazon?
      return absolute? && host.split('.').member?('amazon')
    end

    def asin=(id)
      self.path = "/dp/#{id}"
    end

    def asin
      patterns.each do |entry|
        if matches = path.match(Regexp.new(entry['pattern']))
          return matches[1]
        end
      end
      return nil
    end

    def associate_tag
      return query_values['tag']
    rescue
      return nil
    end

    def associate_tag=(tag)
      return unless tag.present?
      values = query_values || {}
      values['tag'] = tag
      self.query_values = values
    end

    def image_uri
      unless @image_uri
        return nil unless amazon?
        return nil unless asin.present?
        @image_uri = AmazonService.new.image_uri(asin)
      end
      return @image_uri
    end

    def image_url
      return image_uri
    end

    def shorten
      return self unless shortenable?
      dest = clone
      dest.asin = asin
      dest.fragment = nil
      dest.query_values = nil
      dest.query_values = {tag: associate_tag} if associate_tag.present?
      return dest
    end

    private

    def patterns
      return @config['application']['amazon']['patterns']
    end
  end
end
