module Mulukhiya
  class Webhook
    include Package
    include SNSMethods
    # ⚠ クラスメソッド (`self.create`) から digest を丸めるので `extend` (#4655)。
    extend LogScrubber

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

    # 実際に上流へ送る公開範囲。⚠ **`post` から式を持ち出してここに置いてある。**
    # 呼び出し側に式を残すと、テストが `requested_visibility` 単体しか見られず
    # **配線を戻されても緑のまま**になる（#4583 / #4619 と同型）。
    def visibility_for(requested)
      return parser_class.visibility_name(requested_visibility(requested) || visibility)
    end

    # リクエストごとに指定された公開範囲 (#4599)。未知の語なら nil を返し、
    # `visibility_for` がアカウント設定の既定へ倒す (#4624)。
    #
    # ⚠ **素通ししてはいけない。**`parser_class.visibility_name` は未知の名前を
    # **`public` へ丸める**ので、`private`（フォロワー限定）に設定した webhook が
    # **綴り誤りや Misskey 語彙（`home` 等）ひとつで公開投稿になる**。
    # fail-open の向きが最も公開側なので、既知の語かどうかをここで見る。
    #
    # ⚠ **契約 (`slack_webhook_contract.rb`) では絞らない。**Mastodon と Misskey で
    # 語彙が違うため、パーサの `visibility_names` を正本にして二重管理を避ける。
    # ⚠ このハッシュは**キー（`:public` 等）と値（プラットフォーム名）の両方**を持つ。
    #
    # ⚠ **黙って倒さない。**送信側は綴り誤りに気付けないので、必ずログに残す。
    def requested_visibility(name)
      return nil if name.blank?
      names = parser_class.visibility_names
      return name if names.key?(name.to_sym)
      return name if names.values.member?(name.to_s)
      logger.error(error: 'unknown visibility', visibility: name.to_s)
      return nil
    rescue => e
      e.log
      return nil
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

    # ⚠ **params は上流への中継用 (#4598)。**webhook の口は Slack 互換なので
    # ボディに idempotency の概念が無く、`Idempotency-Key` は HTTP ヘッダで
    # 受けて素通しする。許可リストは Controller::FORWARDED_HEADERS が正本で、
    # ここでは受け取ったものをそのまま gem へ渡すだけ。
    def post(payload, params = {})
      body = payload.to_h
      body[visibility_field] = visibility_for(body[visibility_field])
      reporter = Reporter.new
      Event.new(:pre_webhook, {reporter:, sns:}).dispatch(body)
      reporter.response = sns.post(body, params)
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

    # ⚠⚠ **引き当ての失敗を握り潰す。**呼び側が「そんな digest は無い」と
    # 区別できないので、**404 に化かしてはいけない経路は `create!` を使う**
    # (#4603 の Codex P1)。DB 障害で全 webhook が落ちている状態を 4xx として
    # 扱うと、クライアント起因の alert 抑止に乗って**無音**になる。
    def self.create(key)
      return create!(key)
    rescue => e
      # ⚠ **key は digest（＝資格情報）で来うる (#4655)。**そのまま出すと
      # 引き当てが失敗するたびに完全な鍵が syslog に残る。
      e.log(key: scrub_log_digest(key.to_s))
      return nil
    end

    # 引き当てに失敗したら例外をそのまま上げる。**戻り値の nil は
    # 「そんな digest は無い」だけを意味する。**
    def self.create!(key)
      return new(key) if key.is_a?(UserConfig)
      return find_token_by_digest(key)&.account&.webhook
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
