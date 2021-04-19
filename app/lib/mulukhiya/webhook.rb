require 'digest/sha2'

module Mulukhiya
  class Webhook
    include Package
    include SNSMethods
    attr_reader :sns, :reporter

    def digest
      return Webhook.create_digest(@sns.uri, @sns.token)
    end

    def visibility
      return parser_class.visibility_name(@user_config['/webhook/visibility'])
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

    def post(payload)
      body = payload.values.merge('visibility' => visibility)
      Event.new(:pre_webhook, {reporter: @reporter, sns: @sns}).dispatch(body)
      reporter.response = @sns.post(body)
      Event.new(:post_webhook, {reporter: @reporter, sns: @sns}).dispatch(body)
      return reporter
    end

    alias toot post

    alias note post

    def command(text = nil)
      return CommandLine.new([
        'curl',
        '-H', 'Content-Type: application/json',
        '-X', 'POST',
        '-d', {text: text || config['/webhook/sample']}.to_json,
        uri.to_s
      ])
    end

    def self.create_digest(uri, token)
      return Digest::SHA256.hexdigest({
        sns: uri.to_s,
        token: token,
        salt: config['/crypt/salt'],
      }.to_json)
    end

    def self.create(key)
      return Webhook.new(key) if key.is_a?(UserConfig)
      controller_class.webhook_entries do |hook|
        return hook[:account].webhook if hook[:digest] == key
      end
      return nil
    rescue => e
      logger.error(error: e)
      return nil
    end

    def self.all
      return enum_for(__method__) unless block_given?
      controller_class.webhook_entries do |hook|
        yield Webhook.create(hook[:digest])
      end
    end

    private

    def initialize(user_config)
      @user_config = user_config
      @reporter = Reporter.new
      @sns = sns_class.new
      @sns.token = @user_config.token
    end
  end
end
