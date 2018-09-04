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
      return amazon? && asin.present?
    end

    def amazon?
      return absolute? && host.split('.').member?('amazon')
    end

    def asin
      asin_patterns do |pattern|
        if matches = path.match(pattern)
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
      dest.path = "/dp/#{asin}"
      dest.fragment = nil
      dest.query_values = nil
      dest.query_values = {tag: associate_tag} if associate_tag.present?
      return dest
    end

    private

    def asin_patterns
      return enum_for(__method__) unless block_given?
      @config['application']['amazon_uri']['patterns'].each do |pattern|
        yield Regexp.new(pattern)
      end
    end
  end
end
