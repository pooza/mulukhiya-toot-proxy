module Mulukhiya
  class AmazonURI < Ginseng::URI
    include Package

    def shortenable?
      return false unless amazon?
      return false unless asin.present?
      patterns = config['/service/amazon/patterns']
      return false unless entry = patterns.find {|v| path.match(v['pattern'])}
      return entry['shortenable']
    end

    def amazon?
      return absolute? && host.split('.').member?('amazon')
    end

    alias valid? amazon?

    def asin
      config['/service/amazon/patterns'].each do |entry|
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

    def shorten
      return self unless shortenable?
      dest = clone
      dest.asin = asin
      dest.query_values = nil
      return dest
    end
  end
end
