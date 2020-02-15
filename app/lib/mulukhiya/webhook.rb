require 'digest/sha1'

module Mulukhiya
  class Webhook
    attr_reader :sns
    attr_reader :results

    def digest
      return Digest::SHA1.hexdigest({
        sns: @sns.uri.to_s,
        token: @sns.token,
        salt: @config['/webhook/salt'],
      }.to_json)
    end

    def visibility
      return @userconfig['/webhook/visibility'] || 'public'
    end

    def uri
      uri = @sns.uri.clone
      uri.path = "/mulukhiya/webhook/#{digest}"
      return uri
    end

    def exist?
      return @db.execute('webhook_tokens', {
        token: @sns.token,
        owner: @sns.account.id,
      }).present?
    rescue => e
      @logger.error(e)
      return false
    end

    def to_json(opts = nil)
      @json ||= JSON.pretty_generate({
        sns: @sns.uri.to_s,
        token: @sns.token,
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
      Handler.exec_all(:pre_webhook, body, {results: results, sns: @sns})
      results.response = @sns.toot(body)
      Handler.exec_all(:post_webhook, body, {results: results, sns: @sns})
      return results
    end

    def self.create(digest)
      all do |webhook|
        next unless digest == webhook.digest
        next unless webhook.exist?
        return Environment.account_class[webhook.sns.account.id].webhook
      end
      return nil
    end

    def self.all
      return enum_for(__method__) unless block_given?
      Postgres.instance.execute('webhook_tokens').each do |row|
        yield Webhook.new(UserConfig.new('/webhook/token' => row['token']))
      end
    end

    private

    def initialize(userconfig)
      @config = Config.instance
      @userconfig = userconfig
      @results = ResultContainer.new
      @sns = Environment.sns_class.new
      @sns.token = @userconfig.webhook_token
      @logger = Logger.new
      @db = Postgres.instance
    end
  end
end
