require 'mulukhiya-toot-proxy/amazon_uri'
require 'mulukhiya-toot-proxy/handler'
require 'mulukhiya-toot-proxy/logger'
require 'mulukhiya-toot-proxy/slack'

module MulukhiyaTootProxy
  class AmazonAsinHandler < Handler
    def exec(body, headers = {})
      body['status'].scan(%r{https?://[^\s[:cntrl:]]+}).each do |link|
        uri = AmazonURI.parse(link)
        uri.associate_id = associate_id
        next unless uri.shortenable?
        increment!
        body['status'].sub!(link, uri.shorten.to_s)
      end
      return body
    rescue => e
      message = {class: self.class.to_s, message: "#{e.class}: #{e.message}"}
      Logger.new.error(message)
      Slack.all.map{ |h| h.say(message)}
      return body
    end

    private

    def associate_id
      return @config['local']['amazon']['associate_id']
    rescue
      return nil
    end
  end
end
