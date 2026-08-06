module Mulukhiya
  class Webhook
    include Package
    include SNSMethods

    attr_reader :sns, :reporter

    # ⚠ トークンが無いまま digest を作ってはいけない (#4487)。
    # {sns:, token: nil, salt:} の SHA256 は「URL の形をしているのに誰のものでもない」
    # 幽霊 webhook URL になる。find_token_by_digest は oauth_access_tokens を舐めて
    # token.webhook_digest（＝トークン文字列から作った値）と突き合わせるので、
    # nil から作った値に一致するレコードは存在しない。設定はできたのに何も起きない、
    # という静かな失敗になるため、URL を出す前に落とす。
    def digest
      raise Ginseng::ConfigError, 'token not found' if sns.token.blank?
      return self.class.create_digest(sns.uri, sns.token)
    end

    def visibility
      return parser_class.visibility_name(@user_config['/webhook/visibility'])
    rescue => e
      e.log
      return parser_class.visibility_name(:public)
    end

    # digest / uri を取れる状態か。トークンを持たないアカウントでも
    # Account#webhook は Webhook を返すので、呼び出し側はこれで判定する (#4487)。
    def available?
      return sns.token.present?
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
    #
    # 空トークンの拒否は digest 側と二重に持つ。ここは webhook_digest（AccessToken 側）
    # からも呼ばれる入口なので、値の計算に入る前に止める (#4487)。
    def self.create_digest(uri, token)
      raise Ginseng::ConfigError, 'token not found' if token.blank?
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

    # トークンを持たないアカウントの「幽霊 webhook」は列挙しない (#4487)。
    # 混ざっていると digest / uri を呼んだ時点で落ちるうえ、そもそも照合できないので
    # webhook として意味を持たない。
    def self.all(&block)
      return enum_for(__method__) unless block
      controller_class.webhook_entries
        .filter_map {|v| v[:account]&.webhook}
        .select(&:available?)
        .each(&block)
    end

    # ⚠ 1 行の失敗でループを抜けてはいけない。
    #
    # webhook_digest は空トークンで ConfigError を投げる (#4487)。valid? は
    # `to_s.empty?` しか見ないので、空白だけのトークン行はここまで到達する。
    # 例外がループの外へ出ると Webhook.create の rescue が nil を返し、
    # **その行より後ろにある正しい webhook URL が「見つからない」ことになる**。
    # 壊れた行は次へ送るだけにして、走査自体は最後まで続ける (#4487 / PR #4522)。
    # ⚠ ただし黙ってスキップもしない。DB 断や /crypt/salt の設定崩れは全行を
    # 落とすので、無音だと「全 webhook が 404」だけが症状になる。
    def self.find_token_by_digest(digest)
      Postgres.exec(:webhook_tokens).each do |row|
        token = find_valid_token(row)
        return token if token && token.webhook_digest == digest
      rescue => e
        e.log(id: row[:id])
        next
      end
      return nil
    end

    def self.find_valid_token(row)
      token = Environment.access_token_class[row[:id]]
      return nil unless token&.valid?
      return token
    end

    private

    def initialize(user_config)
      @user_config = user_config
      @sns = sns_class.new
      @sns.token = @user_config.token
    end
  end
end
