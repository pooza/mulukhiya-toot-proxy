require 'digest/sha1'

module Mulukhiya
  class Webhook
    attr_reader :sns
    attr_reader :results

    def digest
      return Webhook.create_digest(@sns.uri, @sns.token)
    end

    def visibility
      return @userconfig['/webhook/visibility'] || 'public'
    end

    def uri
      @uri ||= @sns.create_uri("/mulukhiya/webhook/#{digest}")
      return @uri
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
        Environment.controller_class.status_field => status[:text],
        'visibility' => visibility,
        'attachments' => status[:attachments] || [],
      }
      Handler.exec_all(:pre_webhook, body, {results: results, sns: @sns})
      results.response = @sns.toot(body)
      Handler.exec_all(:post_webhook, body, {results: results, sns: @sns})
      return results
    end

    def self.create_digest(uri, token)
      return Digest::SHA1.hexdigest({
        sns: uri.to_s,
        token: token,
        salt: Config.instance['/webhook/salt'],
      }.to_json)
    end

    def self.create(key)
      return Webhook.new(key) if key.is_a?(UserConfig)
      Environment.sns_class.webhooks do |hook|
        return hook[:account].webhook if key == hook[:digest]
      end
      return nil
    end

    def self.all
      return enum_for(__method__) unless block_given?
      Environment.sns_class.webhooks do |hook|
        yield Webhook.create(hook[:digest])
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
