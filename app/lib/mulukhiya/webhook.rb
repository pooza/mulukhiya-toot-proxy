require 'digest/sha2'

module Mulukhiya
  class Webhook
    attr_reader :sns, :reporter

    def digest
      return Webhook.create_digest(@sns.uri, @sns.token)
    end

    def visibility
      return Environment.parser_class.visibility_name(@userconfig['/webhook/visibility'])
    end

    def uri
      @uri ||= @sns.create_uri("/mulukhiya/webhook/#{digest}")
      return @uri
    end

    def to_json(opts = nil)
      @json ||= JSON.pretty_generate(
        sns: @sns.uri.to_s,
        token: @sns.token,
        visibility: visibility,
        hook: uri.to_s,
      )
      return @json
    end

    def post(status)
      status = {text: status} unless status.is_a?(Hash)
      body = {
        Environment.controller_class.status_field => status[:text],
        'visibility' => visibility,
        'attachments' => status[:attachments] || [],
      }
      Handler.dispatch(:pre_webhook, body, {reporter: reporter, sns: @sns})
      reporter.response = @sns.post(body)
      Handler.dispatch(:post_webhook, body, {reporter: reporter, sns: @sns})
      return reporter
    end

    alias toot post

    alias note post

    def command(text = nil)
      return CommandLine.new([
        'curl',
        '-H', 'Content-Type: application/json',
        '-X', 'POST',
        '-d', {text: text || @config['/webhook/sample']}.to_json,
        uri.to_s
      ])
    end

    def self.create_digest(uri, token)
      return Digest::SHA256.hexdigest({
        sns: uri.to_s,
        token: token,
        salt: Config.instance['/crypt/salt'],
      }.to_json)
    end

    def self.create(key)
      return Webhook.new(key) if key.is_a?(UserConfig)
      Environment.controller_class.webhook_entries do |hook|
        return hook[:account].webhook if hook[:digest] == key
      end
      return nil
    end

    def self.all
      return enum_for(__method__) unless block_given?
      Environment.controller_class.webhook_entries do |hook|
        yield Webhook.create(hook[:digest])
      end
    end

    private

    def initialize(userconfig)
      @config = Config.instance
      @userconfig = userconfig
      @reporter = Reporter.new
      @sns = Environment.sns_class.new
      @sns.token = @userconfig.webhook_token
    end
  end
end
