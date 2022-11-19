module Mulukhiya
  class AmazonURI < Ginseng::URI
    include Package

    def shortenable?
      return false unless amazon?
      return false unless asin.present?
      return false unless entry = config['/amazon/patterns'].find {|v| path.match(v['pattern'])}
      return entry['shortenable']
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

    def associate_tag
      return query_values['tag'] rescue nil
    end

    def associate_tag=(tag)
      values = query_values || {}
      values['tag'] = tag
      values = nil unless values.present?
      self.query_values = values
    end

    def shorten
      return self unless shortenable?
      dest = clone
      dest.asin = asin
      dest.query_values = nil
      return dest
    end
  end
end
