require 'addressable/uri'
require 'digest/sha1'
require 'json'

module MulukhiyaTootProxy
  class Webhook
    attr_reader :mastodon

    def initialize(params)
      @config = Config.instance
      @params = Config.flatten('', params)
      @logger = Logger.new
      @mastodon = Mastodon.new(@params['/mastodon/url'], @params['/mastodon/token'])
    end

    def digest
      return Digest::SHA1.hexdigest({
        mastodon: @mastodon.uri.to_s,
        token: @mastodon.token,
        visibility: visibility,
        shorten: shorten?,
        salt: @config['/webhook/salt'],
      }.to_json)
    end

    def visibility
      return (@params['/visibility'] || 'public')
    end

    def toot_tags
      return @params['/toot/tags'].map do |tag|
        Mastodon.create_tag(tag)
      end
    rescue
      return []
    end

    def uri
      begin
        uri = Addressable::URI.parse(@config['/root_url'])
      rescue Ginseng::ConfigError
        uri = Addressable::URI.new
        uri.host = Environment.hostname
        uri.port = @config['/thin/port']
        uri.scheme = 'http'
      end
      uri.path = "/mulukhiya/webhook/#{digest}"
      return uri
    end

    def shorten?
      return @config['/bitly/token'] && @params['/shorten']
    rescue Ginseng::ConfigError
      return false
    end

    def to_json
      @json ||= JSON.pretty_generate({
        mastodon: @mastodon.uri.to_s,
        token: @mastodon.token,
        visibility: visibility,
        shorten: shorten?,
        hook: uri.to_s,
      })
      return @json
    end

    def toot(body)
      @mastodon.toot({
        status: [body].concat(toot_tags).join(' '),
        visibility: visibility,
      })
    end

    def self.create(digest)
      all do |webhook|
        return webhook if digest == webhook.digest
      end
      return nil
    end

    def self.all
      return enum_for(__method__) unless block_given?
      Config.instance['/webhook/entries'].each do |entry|
        yield Webhook.new(entry)
      end
    end
  end
end
