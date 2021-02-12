module Mulukhiya
  class AmazonURI < Ginseng::URI
    include Package

    def initialize(options = {})
      super
      @service = AmazonService.new
    end

    def shortenable?
      return false unless amazon?
      return false unless asin.present?
      config['/amazon/patterns'].each do |entry|
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
      config['/amazon/patterns'].each do |entry|
        next unless matches = path.match(entry['pattern'])
        return matches[1]
      end
      return nil
    end

    alias id asin

    def asin=(id)
      self.path = "/dp/#{id}"
      self.fragment = nil
    end

    def item
      return nil unless amazon?
      return nil unless asin.present?
      @item ||= @service.lookup(asin)
      return @item
    end

    def associate_tag
      return query_values['tag'] rescue nil
    end

    def associate_tag=(tag)
      values = query_values || {}
      values['tag'] = tag
      values = nil unless values.present?
      self.query_values = values
    end

    def album
      return nil
    end

    def album?
      return false
    end

    def album_name
      return nil
    end

    alias track item

    def track?
      return track.present?
    end

    def track_name
      return track.dig('ItemInfo', 'Title', 'DisplayValue') if track
    end

    alias title track_name

    def artists
      contributors = item.dig('ItemInfo', 'ByLineInfo', 'Contributors').map {|v| v['Name']}
      return nil unless contributors
      return ArtistParser.new(contributors.join('、')).parse if track
      return ArtistParser.new(contributors.join('、')).parse if album
      return nil
    end

    def image_uri
      return nil unless amazon?
      return nil unless asin
      @image_uri ||= @service.create_image_uri(asin)
      return @image_uri
    end

    def shorten
      return self unless shortenable?
      dest = clone
      dest.asin = asin
      dest.query_values = nil
      dest.query_values = {tag: associate_tag} if associate_tag
      return dest
    end
  end
end
