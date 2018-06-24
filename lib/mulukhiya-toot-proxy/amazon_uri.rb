require 'addressable/uri'

module MulukhiyaTootProxy
  class AmazonURI < Addressable::URI
    def shortenable?
      return amazon? && asin.present?
    end

    def amazon?
      return host.split('.').member?('amazon')
    end

    def asin
      asin_patterns.each do |pattern|
        if matches = path.match(pattern)
          return matches[1]
        end
      end
      return nil
    end

    def associate_id
      return query_values['tag']
    end

    def associate_id=(tag)
      values = query_values || {}
      values['tag'] = tag
      self.query_values = values
    end

    def shorten
      return self unless shortenable?
      dest = clone
      old_values = query_values || {}
      dest.path = "/dp/#{asin}"
      dest.path += "/#{old_values['tag']}" if old_values['tag']
      dest.query = nil
      dest.fragment = nil
      return dest
    end

    private

    def asin_patterns
      return [
        %r{/dp/([A-Za-z0-9]+)},
        %r{/gp/product/([A-Za-z0-9]+)},
        %r{/exec/obidos/ASIN/([A-Za-z0-9]+)},
        %r{/o/ASIN/([A-Za-z0-9]+)},
      ]
    end
  end
end
