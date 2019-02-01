require 'addressable/uri'
require 'digest/sha1'
require 'json'

module MulukhiyaTootProxy
  class Webhook
    attr_reader :mastodon

    def initialize(params)
      @config = Config.instance
      @params = params
      @mastodon = Mastodon.new(@config['/instance_url'], @params['/webhook/token'])
    end

    def digest
      return Digest::SHA1.hexdigest({
        mastodon: @mastodon.uri.to_s,
        token: @mastodon.token,
        visibility: visibility,
        toot_tags: toot_tags,
        salt: @config['/webhook/salt'],
      }.to_json)
    end

    def visibility
      return (@params['/webhook/visibility'] || 'public')
    end

    def toot_tags
      return @params['/webhook/tags'].map do |tag|
        Mastodon.create_tag(tag)
      end
    rescue
      return []
    end

    def uri
      begin
        uri = Addressable::URI.parse(@config['/instance_url'])
      rescue Ginseng::ConfigError
        uri = Addressable::URI.new
        uri.host = Environment.hostname
        uri.port = @config['/thin/port']
        uri.scheme = 'http'
      end
      uri.path = "/mulukhiya/webhook/#{digest}"
      return uri
    end

    def exist?
      return Postgres.instance.execute('token_owner', {token: @mastodon.token}).present?
    rescue
      return false
    end

    def to_json
      @json ||= JSON.pretty_generate({
        mastodon: @mastodon.uri.to_s,
        token: @mastodon.token,
        visibility: visibility,
        toot_tags: toot_tags,
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
    end
  end
end
