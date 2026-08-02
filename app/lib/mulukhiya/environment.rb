module Mulukhiya
  class Environment < Ginseng::Environment
    include Package

    def self.name
      return File.basename(dir)
    end

    def self.rake?
      return ENV['RAKE'].present?
    end

    def self.test?
      return ENV['TEST'].present?
    end

    def self.type
      return config['/environment'] rescue 'development'
    end

    def self.development?
      return type == 'development'
    end

    def self.production?
      return type == 'production'
    end

    def self.dir
      return Mulukhiya.dir
    end

    def self.domain_name
      return Ginseng::URI.parse(config["/#{controller_name}/url"]).host
    end

    def self.sns_class
      return "Mulukhiya::#{controller_name.camelize}Service".constantize
    rescue NameError
      return nil
    end

    def self.controller_name
      return config['/controller']
    end

    def self.controller_class
      return "Mulukhiya::#{controller_name.camelize}Controller".constantize
    rescue NameError
      return nil
    end

    def self.listener_class
      return "Mulukhiya::#{controller_name.camelize}Listener".constantize
    rescue NameError
      return nil
    end

    def self.mastodon?
      return controller_name == 'mastodon'
    end

    def self.misskey?
      return controller_name == 'misskey'
    end

    def self.controller_type
      return config["/#{controller_name}/sns_type"]
    end

    def self.mastodon_type?
      return controller_type == 'mastodon'
    end

    def self.misskey_type?
      return controller_type == 'misskey'
    end

    def self.dbms_name
      return controller_class&.dbms_name
    end

    def self.postgres?
      return dbms_name == 'postgres'
    end

    def self.parser_name
      return controller_class&.parser_name
    end

    def self.toot?
      return parser_name == 'toot'
    end

    def self.note?
      return parser_name == 'note'
    end

    def self.account_class
      return "Mulukhiya::#{controller_name.camelize}::Account".constantize
    rescue NameError
      return nil
    end

    def self.status_class
      return "Mulukhiya::#{controller_name.camelize}::Status".constantize
    rescue NameError
      return nil
    end

    def self.attachment_class
      return "Mulukhiya::#{controller_name.camelize}::Attachment".constantize
    rescue NameError
      return nil
    end

    def self.role_class
      return "Mulukhiya::#{controller_name.camelize}::Role".constantize
    rescue NameError
      return nil
    end

    def self.access_token_class
      return "Mulukhiya::#{controller_name.camelize}::AccessToken".constantize
    rescue NameError
      return nil
    end

    def self.hash_tag_class
      return "Mulukhiya::#{controller_name.camelize}::HashTag".constantize
    rescue NameError
      return nil
    end

    def self.poll_class
      return "Mulukhiya::#{controller_name.camelize}::Poll".constantize
    rescue NameError
      return nil
    end

    def self.channel_class
      return "Mulukhiya::#{controller_name.camelize}::Channel".constantize
    rescue NameError
      return nil
    end

    def self.sns_service_class
      return "Mulukhiya::#{controller_name.camelize}Service".constantize
    rescue NameError
      return nil
    end

    def self.parser_class
      return controller_class&.parser_class
    end

    def self.dbms_class
      return controller_class&.dbms_class
    end

    def self.daemon_classes
      return [PumaDaemon, SidekiqDaemon, ListenerDaemon].reject(&:disable?).to_set
    end

    def self.task_prefixes
      return daemon_classes.to_set do |daemon|
        "mulukhiya:#{daemon.to_s.split('::').last.sub(/Daemon$/, '').underscore}"
      end
    end

    def self.pre_start_tasks
      return ['config:lint']
    end

    def self.route
      return {'/' => controller_class}.merge(
        YAML.load_file(File.join(dir, 'config/route.yaml')).to_h do |entry|
          [entry['path'], entry['class'].constantize]
        end,
      )
    end

    def self.health
      values = {
        redis: Redis.health,
        sidekiq: SidekiqDaemon.health,
      }
      values[dbms_name.to_sym] = "Mulukhiya::#{dbms_name.camelize}".constantize.health
      values[:streaming] = ListenerDaemon.health if daemon_classes.member?(ListenerDaemon)
      values[:misskey_redis] = MisskeyService.sns_redis_health if misskey_type?
      values[:ruby] = ruby_health
      values[:status] = 503 if values.values.any? {|v| v[:status] == 'NG'}
      values[:status] ||= 200
      return values
    end

    # ランタイムの能力欠落を検知する (#4466)。YJIT は Rust の無い環境では
    # ビルド時に黙って外れ、エラーにならないまま 24〜25% 遅いサーバーが
    # 出来上がる。全台の /health を叩く運用が既にあるので、そこへ出す。
    def self.ruby_health
      enabled = yjit_enabled?
      return {
        version: RUBY_VERSION,
        yjit_available: defined?(RubyVM::YJIT) ? true : false,
        yjit_enabled: enabled,
        status: ruby_status(enabled),
      }
    end

    def self.yjit_enabled?
      return false unless defined?(RubyVM::YJIT)
      return RubyVM::YJIT.enabled? == true
    end

    # 既定では情報として出すだけで NG にしない。能力の欠落は障害ではなく、
    # health が 503 になるとサーバーが「停止」扱いになるため。
    # 確実に検知したいサーバーは /runtime/require_yjit で opt-in する。
    #
    # config の参照を rescue で握り潰さないこと。既定値は application.yaml が
    # 必ず持つので、引けない状態は設定の破損であり黙って無効化してはいけない
    # (MEMORY feedback_fail-open-guard-footgun)。
    def self.ruby_status(yjit_enabled)
      return 'NG' if require_yjit? && !yjit_enabled
      return 'OK'
    end

    def self.require_yjit?
      return config['/runtime/require_yjit'] == true
    end
  end
end
