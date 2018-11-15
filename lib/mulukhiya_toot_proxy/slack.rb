require 'addressable/uri'
require 'httparty'
require 'json'

module MulukhiyaTootProxy
  class Slack
    def initialize(url)
      @url = Addressable::URI.parse(url)
    end

    def say(message)
      return HTTParty.post(@url, {
        body: {text: JSON.pretty_generate(message)}.to_json,
        headers: {
          'Content-Type' => 'application/json',
          'User-Agent' => Package.user_agent,
        },
        ssl_ca_file: ENV['SSL_CERT_FILE'],
      })
    end

    def self.all
      return enum_for(__method__) unless block_given?
      Config.instance['local']['slack'] ||= {}
      if hook = Config.instance['local']['slack']['hook']
        yield Slack.new(hook['url'])
      else
        (Config.instance['local']['slack']['hooks'] || []).each do |url|
          yield Slack.new(url)
        end
      end
    end

    def self.broadcast(message)
      all do |slack|
        slack.say(message)
      end
    end
  end
end
