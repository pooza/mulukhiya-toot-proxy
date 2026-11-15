module Mulukhiya
  # HEIF の取り込みを、libheif の版で開け閉めする (#4734)。
  #
  # ⚠⚠ **版で分けるのは、本番の libheif が揃わないから。**FreeBSD の 3 台は pkg で 1.23.4 以上に
  # 上がるが、vulcan（Ubuntu）は 1.21.2 のまま。許可リストはコードの全体設定なので、
  # ホストごとに設定を書き分けるのではなく、**読み込んでいる libheif に聞く**。
  # 版が上がれば、コードを変えずに開く。
  #
  # ⚠ **分からないときは閉じる。**libheif が読めない・版が読めない・libvips に heif のローダが
  # 無いときは、5.37.1（#4733）と同じく止めたままにする。
  module LibHeif
    # 未修正の GHSA（GHSA-x8r2-mggj-j6wr ほか 3 件）が直った版 (#4733)。
    SAFE_VERSION = '1.23.4'.freeze

    def self.version
      return native.heif_get_version
    rescue LoadError, FFI::NotFoundError
      return nil
    end

    # HEIF を取り込んでよいか。⚠ 起動時に 1 回だけ決める（`setup_vips` と
    # `Controller#verify_upload_type!` が同じ答えを見るように）。
    def self.enabled?
      @enabled = enable?(version) if @enabled.nil?
      return @enabled
    end

    def self.enable?(version, loader: loader?)
      return false unless loader
      return false unless version.to_s.match?(/\A\d+(\.\d+)*\z/)
      return Gem::Version.new(version) >= Gem::Version.new(SAFE_VERSION)
    end

    # libvips が heif のローダを持っているか。⚠ 無いのに開くと、HEIC が `ImageFile#type` の
    # `rescue` に飲まれて素通しになり、上流で 500 になる（#4733 の経路）。
    def self.loader?
      Vips::Operation.new('heifload')
      return true
    rescue Vips::Error
      return false
    end

    # ⚠ libvips が読み込むのと同じ soname を引く。`heif` だけだと、開発用の `libheif.so` が
    # 無いホストで見つからない。
    # ⚠ **読み込みは呼ばれたときに行う。**定数として書くと、libheif の無いホストでは
    # このファイルを読んだ時点で `LoadError` になる。
    def self.native
      return @native ||= Module.new do
        extend FFI::Library

        ffi_lib ['heif', 'libheif.so.1']
        attach_function :heif_get_version, [], :string
      end
    end
  end
end
