module Mulukhiya
  # HEIF の取り込みを、libheif の版で開け閉めする (#4734)。
  #
  # ⚠⚠ **版で分けるのは、本番の libheif が揃わないから。**FreeBSD の 3 台は pkg で上がるが、
  # vulcan（Ubuntu の LTS）は 1.21.2 のまま（修正は版の番号を変えずに取り込むので、版では判定できない）。許可リストはコードの全体設定なので、
  # ホストごとに設定を書き分けるのではなく、**読み込んでいる libheif に聞く**。
  # 版が上がれば、コードを変えずに開く。
  #
  # ⚠ **分からないときは閉じる。**libheif が読めない・版が読めない・libvips に heif のローダが
  # 無いときは、5.37.1（#4733）と同じく止めたままにする。
  module LibHeif
    # 公開済みの GHSA が直った版。
    # ⚠⚠ **この値はすぐ古くなる。**#4733 を書いた 2026-09 の時点では 1.23.4 だったが、その後も
    # 1.23.5（09-21）・1.23.6（10-05・high 4 件）・1.23.7（10-26・high 13 件。ヒープの解放後の使用・
    # バッファ溢れを含む）と勧告が続いた（5.47.1）。上げるときは
    # `gh api repos/strukturag/libheif/security-advisories` の `patched_versions` の最大を見る。
    SAFE_VERSION = '1.23.7'.freeze

    def self.version
      return native.heif_get_version
    rescue LoadError, FFI::NotFoundError
      return nil
    end

    # HEIF を取り込んでよいか。⚠ 起動時に 1 回だけ決める（`setup_vips` と
    # `Controller#verify_upload_type!` が同じ答えを見るように）。
    # ⚠ 決めたときに 1 回、版・ローダの有無・答えを info で残す（5.47.0 のリリース前レビュー）。
    # 残さないと、pkg を上げたあと本当に開いたのか、soname が変わって黙って閉じたのかが、
    # 実際にアップロードするまで分からない。
    def self.enabled?
      if @enabled.nil?
        summary = self.summary
        @enabled = summary[:enabled]
        Logger.new.info(libheif: summary)
      end
      return @enabled
    end

    def self.summary(version: self.version, loader: loader?)
      return {version:, loader:, enabled: enable?(version, loader:)}
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
    # ⚠ **soname を先に引く**（5.47.0 のリリース前レビュー）。`libheif.so` を先にすると、/usr/local へ
    # 別の版を入れたホストで、libvips が使うのとは違う libheif の版を見て開いてしまう余地がある。
    # `heif` は soname で引けないホスト（macOS の `libheif.1.dylib` など）のための控え。
    # ⚠ **読み込みは呼ばれたときに行う。**定数として書くと、libheif の無いホストでは
    # このファイルを読んだ時点で `LoadError` になる。
    def self.native
      return @native ||= Module.new do
        extend FFI::Library

        ffi_lib ['libheif.so.1', 'heif']
        attach_function :heif_get_version, [], :string
      end
    end
  end
end
