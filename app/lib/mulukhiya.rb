require 'bundler/setup'
require 'mulukhiya/refines'

module Mulukhiya
  using Refines

  def self.dir
    return File.expand_path('../..', __dir__)
  end

  def self.loader
    config = YAML.load_file(File.join(dir, 'config/autoload.yaml'))
    loader = Zeitwerk::Loader.new
    loader.inflector.inflect(config['inflections'])
    loader.push_dir(File.join(dir, 'app/lib'))
    loader.collapse('app/lib/mulukhiya/*')
    return loader
  end

  def self.setup_sidekiq
    daemon = SidekiqDaemon.new
    daemon.save_config
    config = YAML.load_file(daemon.config_cache_path).deep_symbolize_keys
    Sidekiq.strict_args!(false)
    Sidekiq.configure_client do |sidekiq|
      sidekiq.redis = {url: config.dig(:redis, :dsn)}
      sidekiq.logger = Sidekiq::Logger.new($stdout)
      sidekiq.logger.level = config.dig(:logger, :level)
      sidekiq.logger.formatter = Sidekiq::Logger::Formatters::JSON.new
    end
  end

  def self.setup_sentry
    dsn = Config.instance['/sentry/dsn']
    return unless dsn
    Sentry.init do |config|
      config.dsn = dsn
      config.release = Package.version
      config.environment = Environment.type
      config.traces_sample_rate = Config.instance['/sentry/traces_sample_rate'] || 0
      config.before_send = method(:scrub_sentry_event)
    end
  rescue => e
    warn "Sentry initialization skipped: #{e.message}"
  end

  def self.scrub_sentry_event(event, _hint)
    patterns = (Config.instance['/sentry/scrub_patterns'] || []).map {|p| Regexp.new(p)}
    return event if patterns.empty?
    event.exception&.values&.each do |ex| # rubocop:disable Style/HashEachMethods
      patterns.each do |pattern|
        ex.value = ex.value&.gsub(pattern, '[FILTERED]')
      end
    end
    return event
  end

  # libvips に渡してよいローダ／セーバーを許可リストで絞る (#4733)。
  #
  # ⚠⚠ **モロヘイヤは利用者が上げたファイルを「最初にデコードする側」である。**
  # nginx は `POST /api/v[0-9]+/media` をモロヘイヤへ回すので、上流（Mastodon）は
  # 変換後の WebP を受け取るだけ。**上流の `config/initializers/vips.rb` は
  # 別プロセスの設定なので、こちらには一切効かない。**Mastodon 4.7.2 が
  # Security として HEIF を止めても、この経路は塞がらなかった。
  #
  # 🔴 **`Vips.block('VipsForeignLoadHeif', true)` だけでは塞がらない。**
  # libvips は heif ローダを止めると **`magickload` にフォールバック**し、
  # ImageMagick の HEIC デリゲート＝**同じ libheif** に渡る（実測で
  # `magickload: Magick: ... @ error/heic.c/ReadHEICImage/661` まで到達した）。
  # **必ず `VipsForeign` を全部止めてから、使うものだけ開ける。**
  #
  # ⚠⚠ **`VipsForeignSaveCgif` は上流の許可リストに無いが、こちらには要る。**
  # `ImageResizeHandler#convertable?` は `animated?` を除外しないので、
  # **アニメ GIF をリサイズして `.gif` へ書き戻す**。上流の並びをそのまま写すと
  # `VipsForeignSave: ... is not a known file format` で GIF が壊れる。
  #
  # ⚠ **解除条件**: `libheif >= 1.23.4` が pkg / ports に来たら HEIF を戻す。
  # 本番は `libheif-1.22.2_1`、ports は 2026-08-31 時点で `1.22.2_2` 止まり。
  # 未修正の GHSA は GHSA-x8r2-mggj-j6wr (critical) ほか 3 件。
  #
  # ⚠ **ここは `Bundler.require` の後＝全エントリポイントとテストが通る場所**に
  # 置いてある。`app/initializer/*.rb` へ置くと**起動時にしか走らず、CI 緑が
  # 根拠にならない**（#4687）。
  VIPS_ALLOWED_OPERATIONS = [
    'VipsForeignLoadNsgif',
    'VipsForeignLoadJpeg',
    'VipsForeignLoadPng',
    'VipsForeignLoadWebp',
    'VipsForeignSaveCgif',
    'VipsForeignSaveJpeg',
    'VipsForeignSavePng',
    'VipsForeignSaveSpng',
    'VipsForeignSaveWebp',
  ].freeze

  def self.setup_vips
    Vips.block('VipsForeign', true)
    VIPS_ALLOWED_OPERATIONS.each {|operation| Vips.block(operation, false)}
    Vips.block_untrusted(true)
  end

  # ハンドラ計装 (#4464) の HTTP フックを仕込む。既定では
  # /profile/handler/enable が false のため、集計先が無く実質ノーオペになる。
  def self.setup_profile
    Ginseng::HTTP.prepend(HandlerProfile::HTTPProbe)
    Parallel.singleton_class.prepend(HandlerProfile::ParallelProbe)
  end

  def self.setup_debug
    Ricecream.disable
    return unless Environment.development?
    require 'pp'
    Ricecream.enable
    Ricecream.include_context = true
    Ricecream.colorize = true
    Ricecream.prefix = "#{Package.name} | "
    Ricecream.define_singleton_method(:arg_to_s, proc {|v| PP.pp(v)})
  end

  def self.rack
    require 'sidekiq/web'
    require 'sidekiq-scheduler/web'
    if SidekiqDaemon.basic_auth?
      Sidekiq::Web.use(Rack::Auth::Basic) do |username, password|
        SidekiqDaemon.auth?(username, password)
      end
    end
    Sidekiq::Web.use(Rack::Session::Cookie, {
      same_site: true,
      max_age: Config.instance['/sidekiq/dashboard/session/max_age'],
    })
    return Rack::URLMap.new(Environment.route)
  end

  # ⚠⚠ **`rescue` をメソッド全体に掛けてはいけない (#4596)。**
  # `Ginseng::ConfigError < Ginseng::Error < StandardError` なので、以前の形は
  # **最後の `raise` を自分の `rescue => e` が握り込んでいた**＝ `strict` が
  # 構造的に発火しなかった。`config validation skipped: config validation failed`
  # という「失敗した」と「飛ばした」が 1 行に同居した警告が、その状態の目印。
  # **握るのは「検証そのものが実行できなかった」場合だけ**に絞る。
  def self.validate_config
    errors = config_validation_errors
    return if errors.empty?
    errors.each {|e| warn "config validation: #{e}"}
    return unless config_validation_strict?
    raise Ginseng::ConfigError, "config validation failed (#{errors.length} errors)"
  end

  # 検証そのものが実行できなかった場合だけ握る。⚠ ここでの fail-open は
  # 「schema を読めない環境でも起動はできる」ための意図的なもの。
  # ⚠ `format: regex` の検証は `Config#errors` に寄せてある (#4597)。
  # **`rake config:lint` と `#audit` も同じ結果を見る**必要があるため。
  def self.config_validation_errors
    return Config.instance.errors
  rescue => e
    warn "config validation skipped: #{e.message}"
    return []
  end

  # ⚠⚠ **ガードのパラメータを fail-open な `rescue` の内側で読まない (#4596)。**
  # `Ginseng::Config#[]` はキーが無ければ `ConfigError` を上げるので、素で読むと
  # **設定パスの typo がガードの恒常 no-op に化ける**（pooza/makoto2#77 と同型）。
  # 既定値は `config/application.yaml` の `/config/validation/strict: false` にあるので、
  # ここへ例外で来るのは**設定そのものが壊れている**とき。⚠ **黙って false に倒さず、
  # 必ず警告を残す** — 無音だと「strict を書いたのに止まらない」が観測できない。
  def self.config_validation_strict?
    return Config.instance['/config/validation/strict'] == true
  rescue => e
    warn "config validation: strict flag unreadable (#{e.message})"
    return false
  end

  def self.load_tasks
    finder = Ginseng::FileFinder.new
    finder.dir = File.join(dir, 'app/task')
    finder.patterns.push('*.rb')
    finder.patterns.push('*.rake')
    finder.exec.each {|f| require f}
  end

  Dir.chdir(dir)
  ENV['BUNDLE_GEMFILE'] = File.join(dir, 'Gemfile')
  Bundler.require
  JSON::Validator.use_multi_json = false
  loader.setup
  setup_sidekiq
  setup_sentry
  setup_vips
  setup_profile
  setup_debug
  ENV['RACK_ENV'] ||= Environment.type
  Environment.dbms_class&.connect
  validate_config
  RubyVM::YJIT.enable if defined?(RubyVM::YJIT)
end
