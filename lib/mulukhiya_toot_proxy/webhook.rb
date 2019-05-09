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

    def uri
      uri = Addressable::URI.parse(@config['/instance_url'])
      uri.path = "/mulukhiya/webhook/#{digest}"
      return uri
    end

    def exist?
      return db.execute('webhook_tokens', {
        token: @mastodon.token,
        owner: @mastodon.account_id,
      }).present?
    rescue => e
      @logger.error(e)
      return false
    end

    def to_json(opts = nil)
      @json ||= JSON.pretty_generate({
        mastodon: @mastodon.uri.to_s,
        token: @mastodon.token,
        visibility: visibility,
        hook: uri.to_s,
      })
      return @json
    end

    def toot(status)
      status = {text: status} if status.is_a?(String)
      body = {
        'status' => status[:text],
        'visibility' => visibility,
        'attachments' => status[:attachments] || [],
      }
      @results = Handler.exec_all(body, {mastodon: @mastodon})
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
      @results = ResultContainer.new
      @mastodon = Mastodon.new
      @logger = Logger.new
    end

    def db
      return Postgres.instance
    end
  end
end
