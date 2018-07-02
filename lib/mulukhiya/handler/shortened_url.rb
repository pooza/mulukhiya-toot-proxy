require 'addressable/uri'
require 'httparty'
require 'mulukhiya/handler/url_handler'

module MulukhiyaTootProxy
  class ShortenedUrlHandler < UrlHandler
    def rewrite(link)
      headers = HTTParty.get(link, {follow_redirects: false, timeout: timeout}).headers
      @status.sub!(link, headers['location']) if headers['location']
    end

    private

    def rewritable?(link)
      return domains.member?(Addressable::URI.parse(link).host)
    end

    def timeout
      return @config['application']['shortened_url']['timeout']
    end

    def domains
      return @config['application']['shortened_url']['domains']
    end
  end
end
