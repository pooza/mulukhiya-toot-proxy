require 'rack/test'

module Mulukhiya
  # 取り込みを止めた形式を、上流へ投げる前に断ること (#4733 / #4734)。
  #
  # ⚠⚠ **これが無いと、クライアント起因の入力で 500 と「抑止の無い」アラートが出る。**
  # 素通しした HEIC は Mastodon 4.7.2 も弾くが、Paperclip がそれを 500 に変換し、
  # `handle_gateway_error` が `error.alert` を**直接**呼ぶ（`throttled_alert` を通らない）。
  class BlockedUploadTypeTest < TestCase
    include Rack::Test::Methods

    # ISO BMFF の `ftyp` ボックス（major_brand = `heic`）。⚠ **中身は要らない** —
    # 判定は Marcel のマジックバイトだけで決まる。
    HEIC_HEADER = "\x00\x00\x00\x18ftypheic\x00\x00\x00\x00heicmif1".b.freeze

    def setup
      @heic = tempfile('.heic', HEIC_HEADER)
      @png = tempfile('.png', png_bytes)
    end

    def teardown
      [@heic, @png].each {|f| f&.unlink}
      super
    end

    # ⚠ **判定に vips を使っていないこと。**`ImageFile#type` は
    # `Vips::Image.new_from_file` を呼ぶので、止めたい相手をデコードしてしまう。
    # `MediaFile#type` は Marcel ＝ マジックバイトだけで答える。
    def test_detects_heic_without_decoding
      assert_equal('image/heic', MediaFile.new(@heic.path).type)
      assert_equal(MIMEType::DEFAULT, ImageFile.new(@heic.path).type, 'vips 側は止まっている')
    end

    def test_blocks_heic
      error = assert_raises(Ginseng::ValidateError) do
        controller(@heic).verify_upload_type!
      end

      assert_include(error.message, 'HEIF')
      # ⚠ 4xx であること。5xx だと `report_error` が alert 側へ倒れる。
      assert_equal(422, error.status)
      assert_true(HTTPStatus.client_error?(error.status))
    end

    # サムネイル（PUT /api/:version/media/:id）も同じ経路を通る。
    def test_blocks_heic_on_thumbnail_field
      assert_raises(Ginseng::ValidateError) do
        controller(@heic, :thumbnail).verify_upload_type!(:thumbnail)
      end
    end

    # 止めていない形式は通す（絞りすぎていないこと）。
    def test_passes_png
      assert_nothing_raised do
        controller(@png).verify_upload_type!
      end
    end

    # 添付が無いリクエスト（本文だけの更新など）で落ちないこと。
    def test_passes_without_attachment
      assert_nothing_raised do
        MastodonController.new!.tap {|c| c.define_singleton_method(:params) {{}}}.verify_upload_type!
      end
    end

    # ⚠ Misskey 側（POST /api/drive/files/create）も同じガードを通す。
    def test_blocks_heic_on_misskey
      c = MisskeyController.new!
      file = @heic
      c.define_singleton_method(:params) {{file: {tempfile: file}}}

      assert_raises(Ginseng::ValidateError) {c.verify_upload_type!}
    end

    # ⚠⚠ **ルートに繋がっていることを見る。**上のテストは `verify_upload_type!` を
    # 直接呼んでいるだけなので、**ルートから呼び忘れても緑のまま**になる。
    # `POST /api/:version/media` をインプロセスで叩いて 422 を確認する。
    # ⚠ 上流へは届かない（ガードが手前で止めるので `sns.upload` を呼ばない）。
    def test_route_rejects_heic_before_reaching_upstream
      with_error_handler do
        # ⚠ Sinatra 4 の host authorization は既定で `example.org`（rack-test の既定）を
        # 拒む。素で叩くと中身に届く前に 403 になる。
        header('Host', 'localhost')
        post(
          '/api/v1/media',
          {file: Rack::Test::UploadedFile.new(@heic.path, 'image/heic')},
        )

        assert_equal(422, last_response.status)
        assert_include(JSON.parse(last_response.body)['error'].to_s, 'HEIF')
      end
    end

    private

    def app = MastodonController

    # ⚠⚠ **開発モードだと `error do |e|` に届かない。**Sinatra は
    # `show_exceptions` が有効なあいだ例外を HTML のデバッグ画面（500）にするので、
    # 素で叩くと**ガードが効いていても 500 に見える**。本番は無効なので、
    # ここだけ本番と同じ扱いに倒して確かめ、必ず元へ戻す。
    def with_error_handler
      original = [app.settings.show_exceptions, app.settings.raise_errors]
      app.set(:show_exceptions, false)
      app.set(:raise_errors, false)
      yield
    ensure
      app.set(:show_exceptions, original.first)
      app.set(:raise_errors, original.last)
    end

    def controller(file, field = :file)
      c = MastodonController.new!
      c.define_singleton_method(:params) {{field => {tempfile: file}}}
      return c
    end

    def tempfile(extname, bytes)
      file = Tempfile.new(['mulukhiya-4733', extname])
      file.binmode
      file.write(bytes)
      file.close
      return file
    end

    def png_bytes
      dest = Tempfile.new(['mulukhiya-4733', '.png'])
      dest.close
      Vips::Image.black(16, 16).add(128).cast(:uchar)
        .bandjoin([Vips::Image.black(16, 16).add(64).cast(:uchar)] * 2)
        .copy(interpretation: :srgb)
        .write_to_file(dest.path)
      bytes = File.binread(dest.path)
      dest.unlink
      return bytes
    end
  end
end
