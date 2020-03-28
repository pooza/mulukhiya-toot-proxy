module Mulukhiya
  class AmazonURI < Ginseng::URI
    def initialize(options = {})
      super(options)
      @config = Config.instance
      @service = AmazonService.new
    end

    def shortenable?
      return false unless amazon?
      return false unless asin.present?
      @config['/amazon/patterns'].each do |entry|
        next unless path.match(entry['pattern'])
        return entry['shortenable']
      end
      return false
    end

    def amazon?
      return absolute? && host.split('.').member?('amazon')
    end

    alias valid? amazon?

    def asin
      @config['/amazon/patterns'].each do |entry|
        if matches = path.match(entry['pattern'])
          return matches[1]
        end
      end
      return nil
    end

    alias id asin

    def asin=(id)
      self.path = "/dp/#{id}"
    end

    def item
      return nil unless amazon?
      return nil unless asin.present?
      return @service.lookup(asin)
    end

    def associate_tag
      return query_values['tag']
    rescue NoMethodError
      return nil
    end

    def associate_tag=(tag)
      values = query_values || {}
      if tag.present?
        values['tag'] = tag
      else
        values.delete('tag')
      end
      self.query_values = values
    end

    def image_uri
      return nil unless amazon?
      return nil unless asin.present?
      @image_uri ||= @service.create_image_uri(asin)
      return @image_uri
    end

    alias image_url image_uri

    def shorten
      return self unless shortenable?
      dest = clone
      dest.asin = asin
      dest.fragment = nil
      dest.query_values = nil
      dest.query_values = {tag: associate_tag} if associate_tag.present?
      return dest
    end
  end
end
