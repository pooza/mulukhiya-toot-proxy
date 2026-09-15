module Mulukhiya
  # libvips の許可リスト (#4733) の見張り。
  #
  # ⚠⚠ **`Mulukhiya.setup_vips` は `Bundler.require` の後で走るので、スイートにも
  # 効いている。**`app/initializer/*.rb` へ移すと**起動時にしか走らなくなり、
  # この test は緑のまま実機だけ塞がらなくなる**（#4687 と同型）。
  class VipsBlockTest < TestCase
    # ISO BMFF の `ftyp` ボックス（major_brand = `heic`）。⚠ **中身は要らない** —
    # ローダが選ばれるかどうかだけを見るので、ヘッダだけで足りる。
    HEIC_HEADER = [
      "\x00\x00\x00\x18ftypheic\x00\x00\x00\x00heicmif1",
    ].pack('a*').b.freeze

    def setup
      @heic = Tempfile.new(['mulukhiya-4733', '.heic'])
      @heic.binmode
      @heic.write(HEIC_HEADER)
      @heic.close
    end

    def teardown
      @heic&.unlink
      super
    end

    # 先に「この fixture は確かに HEIC として見える」ことを固定する。これが無いと、
    # 下の test が「ただの壊れたファイル」でも通ってしまう。
    def test_fixture_is_detected_as_heic
      assert_equal('image/heic', MediaFile.new(@heic.path).type)
    end

    # 🔴 **`VipsForeignLoadHeif` だけをブロックしても塞がらない。**libvips は
    # `magickload` へフォールバックし、ImageMagick の HEIC デリゲート＝**同じ
    # libheif** に渡る。そのときの例外は `magickload: ... ReadHEICImage` になるので、
    # **`VipsForeignLoad` で断られたこと**まで見て、フォールバックが閉じているかを固定する。
    def test_heif_is_blocked_without_falling_back_to_imagemagick
      error = assert_raises(Vips::Error) do
        Vips::Image.new_from_file(@heic.path)
      end

      assert_include(error.message, 'VipsForeignLoad')
      assert_not_include(error.message, 'magickload')
    end

    # ⚠ ブロックは `ImageFile#type` の `rescue` に飲まれるので、**ハンドラから見ると
    # 「画像ではない」＝黙って素通し**になる（受け皿は #4734）。ここではその形を固定する。
    # ⚠⚠ **これはブロックの見張りではない。**stub はデータを持たないので
    # `setup_vips` が無くても同じ結果になる。ブロックの回帰は上の
    # `test_heif_is_blocked_without_falling_back_to_imagemagick` が見ている
    # （修正を外すと、そこだけが落ちることを確認済み）。
    def test_blocked_file_is_not_treated_as_image
      file = ImageFile.new(@heic.path)

      assert_equal(MIMEType::DEFAULT, file.type)
      assert_false(file.image?)
    end

    # ⚠⚠ **`VipsForeignSaveCgif` は上流（Mastodon）の許可リストに無いが、こちらには要る。**
    # `ImageResizeHandler#convertable?` は `animated?` を除外しないので、アニメ GIF を
    # リサイズして `.gif` へ書き戻す。落とすと `VipsForeignSave: ... is not a known
    # file format` になる。
    def test_allowed_operations_cover_gif_save
      assert_include(VIPS_ALLOWED_OPERATIONS, 'VipsForeignSaveCgif')
    end

    # 許可リストを絞りすぎていないこと。⚠ 実データでの往復は
    # `test/unit/lib/image_file.rb` が png / jpeg / webp / gif で見ている。
    def test_allowed_loaders_round_trip
      ['png', 'jpg', 'webp', 'gif'].each do |extname|
        dest = Tempfile.new(['mulukhiya-4733', ".#{extname}"])
        dest.close
        image.write_to_file(dest.path)

        assert_nothing_raised("#{extname} が書けない") do
          Vips::Image.new_from_file(dest.path).avg
        end
      ensure
        dest&.unlink
      end
    end

    private

    def image
      return Vips::Image.black(16, 16).add(128).cast(:uchar)
          .bandjoin([Vips::Image.black(16, 16).add(64).cast(:uchar)] * 2)
          .copy(interpretation: :srgb)
    end
  end
end
