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
      body = payload.to_h
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

    # digestはWebhook URLの一部となるため、入力値や生成ロジックの変更は
    # 外部連携（tomato-shrieker等）を破壊する。
    # /crypt/salt は #4083 で廃止済みだが、本番サーバーの過半数で
    # /crypt/salt と /crypt/password が異なる値を持っており、
    # Crypt.password に統一すると digest が変化する。(#4106)
    def self.create_digest(uri, token)
      return {
        sns: uri.to_s,
        token:,
        salt: (config['/crypt/salt'] rescue Crypt.password),
      }.to_json.sha256
    end

    def self.create(key)
      return new(key) if key.is_a?(UserConfig)
      token = find_token_by_digest(key)
      return token&.account&.webhook
    rescue => e
      e.log(key: key.to_s)
      return nil
    end

    def self.all(&block)
      return enum_for(__method__) unless block
      controller_class.webhook_entries.filter_map {|v| v[:account]&.webhook}.each(&block)
    end

    def self.find_token_by_digest(digest)
      Postgres.exec(:webhook_tokens).each do |row|
        token = Environment.access_token_class[row[:id]] rescue next
        next unless token.valid?
        return token if token.webhook_digest == digest
      end
      return nil
    end

    private

    def initialize(user_config)
      @user_config = user_config
      @sns = sns_class.new
      @sns.token = @user_config.token
    end
  end
end
