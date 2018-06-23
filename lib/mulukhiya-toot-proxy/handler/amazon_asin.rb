require 'mulukhiya-toot-proxy/amazon_uri'
require 'mulukhiya-toot-proxy/handler'
require 'mulukhiya-toot-proxy/logger'
require 'mulukhiya-toot-proxy/slack'

module MulukhiyaTootProxy
  class AmazonAsinHandler < Handler
    def exec(source)
      source.scan(%r{https?://[^\s[:cntrl:]]+}).each do |link|
        uri = AmazonURI.parse(link)
        next unless uri.shortenable?
        increment!
        source.sub!(link, uri.shorten.to_s)
      end
      return source
    rescue => e
      message = {class: self.class.to_s, message: "#{e.class}: #{e.message}"}
      Logger.new.error(message)
      Slack.all.map{ |h| h.say(message)}
      return source
    end
  end
end
