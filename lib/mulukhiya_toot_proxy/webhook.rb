require 'digest/sha1'

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
      uri = Ginseng::URI.parse(@config['/mastodon/url'])
      uri.path = "/mulukhiya/webhook/#{digest}"
      return uri
    end

    def exist?
      return @db.execute('webhook_tokens', {
        token: @mastodon.token,
        owner: @mastodon.account.id,
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
      Handler.exec_all(:pre_webhook, body, {
        results: results,
        mastodon: @mastodon,
      })
      results.response = @mastodon.toot(body)
      Handler.exec_all(:post_webhook, body, {
        results: results,
        mastodon: @mastodon,
      })
      return results
    end

    def self.create(digest)
      all do |webhook|
        next unless digest == webhook.digest
        next unless webhook.exist?
        return Account.new({id: webhook.mastodon.account.id}).webhook
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
      return enum_for(__method__, account) unless block_given?
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
      @mastodon.token = @params['/webhook/token']
      @logger = Logger.new
      @db = Postgres.instance
    end
  end
end
