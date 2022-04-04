require 'digest/sha2'

module Mulukhiya
  class Webhook
    include Package
    include SNSMethods
    attr_reader :sns, :reporter

    def digest
      return self.class.create_digest(sns.uri, sns.token)
    end

    def visibility
      return parser_class.visibility_name(@user_config['/webhook/visibility'])
    rescue => e
      e.log
      return parser_class.visibility_name(:public)
    end

    def uri
      @uri ||= sns.create_uri("/mulukhiya/webhook/#{digest}")
      return @uri
    end

    def to_json(opts = nil)
      @json ||= JSON.pretty_generate(
        sns: sns.uri.to_s,
        token: sns.token,
        visibility:,
        hook: uri.to_s,
      )
      return @json
    end

    def post(payload)
      body = payload.values
      body[visibility_field] = parser_class.visibility_name(body[visibility_field] || visibility)
      reporter = Reporter.new
      Event.new(:pre_webhook, {reporter:, sns:}).dispatch(body)
      reporter.response = sns.post(body)
      Event.new(:post_webhook, {reporter:, sns:}).dispatch(body)
      return reporter
    end

    alias toot post

    alias note post

    def command(text = nil)
      text ||= config['/webhook/sample']
      return CommandLine.new([
        'curl',
        '-H', 'Content-Type: application/json',
        '-X', 'POST',
        '-d', {text:, visibility:}.to_json,
        uri.to_s
      ])
    end

    def self.create_digest(uri, token)
      return Digest::SHA256.hexdigest({
        sns: uri.to_s,
        token:,
        salt: (config['/crypt/salt'] || Crypt.password),
      }.to_json)
    end

    def self.create(key)
      return new(key) if key.is_a?(UserConfig)
      return nil unless entry = controller_class.webhook_entries.find {|v| v[:digest] == key}
      return entry[:account].webhook
    rescue => e
      e.log(key: key.to_s)
      return nil
    end

    def self.all(&block)
      return enum_for(__method__) unless block
      controller_class.webhook_entries.filter_map {|v| create(v[:digest])}.each(&block)
    end

    private

    def initialize(user_config)
      @user_config = user_config
      @sns = sns_class.new
      @sns.token = @user_config.token
    end
  end
end
