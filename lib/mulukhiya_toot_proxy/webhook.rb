require 'addressable/uri'
require 'digest/sha1'
require 'json'

module MulukhiyaTootProxy
  class Webhook
    attr_reader :mastodon
    attr_reader :results

    def digest
      return Digest::SHA1.hexdigest({
        mastodon: @mastodon.uri.to_s,
        token: @mastodon.token,
        salt: @config['/webhook/salt'],
      }.to_json)
    end

    def visibility
      return @params['/webhook/visibility'] || 'public'
    end

    def tags
      return @params['/webhook/tags'] || []
    end

    alias toot_tags tags

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
      return db.execute('webhook_tokens', {
        token: @mastodon.token,
        owner: @mastodon.account_id,
      }).present?
    rescue
      return false
    end

    def to_json(opts = nil)
      @json ||= JSON.pretty_generate({
        mastodon: @mastodon.uri.to_s,
        token: @mastodon.token,
        visibility: visibility,
        toot_tags: tags,
        hook: uri.to_s,
      })
      return @json
    end

    def toot(status)
      body = {'status' => status, 'visibility' => visibility}
      @results = Handler.exec_all(body, @headers, {mastodon: @mastodon, tags: tags})
      return @mastodon.toot(body)
    end

    def self.create(digest)
      all do |webhook|
        next unless digest == webhook.digest
        next unless webhook.exist?
        return Webhook.new(UserConfigStorage.new[webhook.mastodon.account_id])
      end
      return nil
    end

    def self.all
      return enum_for(__method__) unless block_given?
      Postgres.instance.execute('webhook_tokens').each do |row|
        yield Webhook.new({'/webhook/token' => row['token']})
      end
    end

    def self.owned_all(account)
      return enum_for(__method__) unless block_given?
      all do |webhook|
        next unless webhook.mastodon.account['username'] == account.sub(/^@/, '')
        yield webhook
      end
    end

    private

    def initialize(params)
      @config = Config.instance
      @params = params
      @mastodon = Mastodon.new(@config['/instance_url'], @params['/webhook/token'])
    end

    def db
      return Postgres.instance
    end
  end
end
