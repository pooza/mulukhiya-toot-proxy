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

  # libvips に渡してよいローダ／セーバーを許可リストで絞る (#4733)。
  # 5.37.1 からのバックポート。
  #
  # ⚠⚠ **モロヘイヤは利用者が上げたファイルを「最初にデコードする側」である。**
  # nginx は `POST /api/v[0-9]+/media` をモロヘイヤへ回すので、上流（Mastodon 等）は
  # 変換後の WebP を受け取るだけ。**上流側の `Vips.block` は別プロセスの設定なので、
  # こちらには一切効かない。**Mastodon 4.7.2 が Security として HEIF を止めても、
  # この経路は塞がらなかった。
  #
  # ⚠ `POST /api/:version/media` の `verify_token_integrity!` は**認証ではなく
  # 自己整合性検査**なので、**無効トークンでも `pre_upload` まで到達する**。
  #
  # 🔴 **`Vips.block('VipsForeignLoadHeif', true)` だけでは塞がらない。**
  # libvips は heif ローダを止めると **`magickload` にフォールバック**し、
  # ImageMagick の HEIC デリゲート＝**同じ libheif** に渡る。
  # **必ず `VipsForeign` を全部止めてから、使うものだけ開ける。**
  #
  # ⚠⚠ **`VipsForeignSaveCgif` は Mastodon の許可リストに無いが、こちらには要る。**
  # `ImageResizeHandler#convertable?` は `animated?` を除外しないので、
  # **アニメ GIF をリサイズして `.gif` へ書き戻す**。
  #
  # ⚠ **解除条件**: `libheif >= 1.23.4` が pkg / ports に来たら HEIF を戻す。
  # 未修正の GHSA は GHSA-x8r2-mggj-j6wr (critical) ほか 3 件。
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
  loader.setup
  setup_sidekiq
  setup_vips
  setup_debug
  ENV['RACK_ENV'] ||= Environment.type
  Environment.dbms_class&.connect
  RubyVM::YJIT.enable if Environment.jit?
end
