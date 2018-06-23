require 'addressable/uri'
require 'httparty'
require 'mulukhiya-toot-proxy/handler'
require 'mulukhiya-toot-proxy/logger'
require 'mulukhiya-toot-proxy/slack'

module MulukhiyaTootProxy
  class ShortenedUrlHandler < Handler
    def exec(source)
      source.scan(%r{https?://[^\s[:cntrl:]]+}).each do |link|
        uri = Addressable::URI.parse(link)
        next unless domains.member?(uri.host)
        increment!
        headers = HTTParty.get(link, {follow_redirects: false, timeout: timeout}).headers
        source.sub!(link, headers['location']) if headers['location']
      end
    rescue => e
      message = {class: self.class.to_s, message: "#{e.class}: #{e.message}"}
      Logger.new.error(message)
      Slack.all.map{ |h| h.say(message)}
    ensure
      return source
    end

    private

    def timeout
      return (@config['application']['shortened_url']['timeout'] || 5)
    end

    def domains
      return [
        't.co',
        'goo.gl',
        'bit.ly',
        'ow.ly',
      ]
    end
  end
end
