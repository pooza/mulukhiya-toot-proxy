require 'addressable/uri'
require 'httparty'
require 'mulukhiya-toot-proxy/handler'
require 'mulukhiya-toot-proxy/logger'
require 'mulukhiya-toot-proxy/slack'

module MulukhiyaTootProxy
  class UrlNormalizeHandler < Handler
    def exec(source)
      source.scan(%r{https?://[^\s[:cntrl:]]+}).each do |link|
        increment!
        source.sub!(link, Addressable::URI.parse(link).normalize.to_s)
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
