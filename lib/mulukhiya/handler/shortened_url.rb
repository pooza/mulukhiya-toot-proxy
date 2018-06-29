require 'addressable/uri'
require 'httparty'
require 'mulukhiya/handler/url_handler'

module MulukhiyaTootProxy
  class ShortenedUrlHandler < UrlHandler
    def rewrite(link)
      uri = Addressable::URI.parse(link)
      return unless domains.member?(uri.host)
      increment!
      headers = HTTParty.get(link, {follow_redirects: false, timeout: timeout}).headers
      @status.sub!(link, headers['location']) if headers['location']
    end

    private

    def timeout
      return @config['application']['shortened_url']['timeout']
    end

    def domains
      return @config['application']['shortened_url']['domains']
    end
  end
end
