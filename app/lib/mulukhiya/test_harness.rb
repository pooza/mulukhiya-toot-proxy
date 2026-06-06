module Mulukhiya
  # chubo2 fedi-test-harness (chubo2#31 Mastodon / chubo2#44 Misskey) の接続情報を
  # テスト用 config に注入する。ハーネスの setup.sh が出力する .env.test
  # (MASTODON_URL / MASTODON_ACCESS_TOKEN, MISSKEY_URL / MISSKEY_ACCESS_TOKEN) を
  # 読み込み、対象コントローラの url と agent.test.token を上書きする。
  # 接続情報が無ければ何もしない（従来どおり実インスタンス依存テストはスキップ）。
  class TestHarness
    include Package

    PREFIXES = {'mastodon' => 'MASTODON', 'misskey' => 'MISSKEY'}.freeze

    def self.apply!
      return new.apply!
    end

    # 接続情報を config に流し込む。適用したコントローラの接続情報を返す（無ければ nil）。
    # TestCase#teardown の `config.reload` を跨いで残るよう、フラットキー代入ではなく
    # raw['local'] 層へ deep-merge してから reload する。reload は raw のキャッシュから
    # 再適用するため、フラットキー代入だけだと毎テスト巻き戻ってしまう。
    def apply!
      info = connections
      return nil unless type = target_controller(info)
      return nil unless conn = info[type]
      agent = {'test' => {'token' => conn[:token]}}
      agent['info'] = {'token' => conn[:info_token]} if conn[:info_token]
      values = {'controller' => type, type => {'url' => conn[:url]}, 'agent' => agent}
      # mulukhiya は Mastodon の DB を直読みするため DSN があれば postgres.dsn も配線。
      values['postgres'] = {'dsn' => conn[:db_dsn]} if conn[:db_dsn]
      merge_local(values)
      # DB 接続はブート時 (apply! より前) に確立されるため、DSN を後から差した場合は
      # Sequel のデフォルト DB を張り直す（モデルがロードされる前に必要）。
      # 到達不可でも apply! 自体は落とさない（DB 依存テストは従来どおりスキップされる）。
      begin
        environment_class.dbms_class&.connect if conn[:db_dsn]
      rescue => e
        warn "TestHarness: DB 接続に失敗したためスキップ: #{e.message}"
      end
      return conn
    end

    # 利用可能な接続情報を {'mastodon' => {url:, token:, info_token:, db_dsn:}, ...} で返す。
    def connections
      env = harness_env
      return PREFIXES.each_with_object({}) do |(type, prefix), dest|
        url = env["#{prefix}_URL"]
        token = env["#{prefix}_ACCESS_TOKEN"]
        next unless url.present? && token.present?
        dest[type] = {
          url:, token:,
          info_token: env["#{prefix}_INFO_ACCESS_TOKEN"].presence,
          db_dsn: env["#{prefix}_DB_DSN"].presence
        }
      end
    end

    private

    # raw['local'] 層に deep-merge して reload する（config.reload を跨いで残す）。
    def merge_local(values)
      raw = config.raw
      raw['local'] = Ginseng::Config.deep_merge(raw['local'] || {}, values)
      config.reload
    end

    # 直接 ENV (README 推奨の `source .env.test`) を優先し、足りない分を
    # MULUKHIYA_HARNESS_DIR 配下の <controller>/.env.test から補う。
    def harness_env
      env = ENV.to_h
      return env unless dir = ENV['MULUKHIYA_HARNESS_DIR'].presence
      PREFIXES.each_key do |type|
        path = File.join(dir, type, '.env.test')
        next unless File.exist?(path)
        parse_env(path).each {|key, value| env[key] ||= value}
      end
      return env
    end

    def parse_env(path)
      return File.foreach(path).each_with_object({}) do |line, dest|
        line = line.strip
        next if line.empty? || line.start_with?('#')
        key, _, value = line.partition('=')
        dest[key.strip] = value.strip
      end
    end

    # 設定済みコントローラを優先。未設定／接続情報が無い場合のみ、
    # 唯一の接続情報があればそれを採用する。
    def target_controller(info)
      current = config['/controller'] rescue nil
      return current if current && info.key?(current)
      return info.keys.first if info.size == 1
      return nil
    end
  end
end
