module Mulukhiya
  class MediaMetadataStorageTest < TestCase
    # ⚠ 以前は Amazon の実画像 URL を取りに行っていたため、取得に失敗すると
    # MediaMetadataStorage#push がネガティブキャッシュ（`{}`）を置き、期待値との
    # 差分として毎回ランダムに落ちていた (#4552)。取得の成否は本ケースの検証対象
    # ではない（ここで見たいのは fetch → MediaFile → set → get の往復）ので、
    # ローカルのフィクスチャを WebMock で返して外部依存を切る。
    URL = 'https://media.test/sample.jpg'.freeze
    # フィクスチャの実測値。差し替えたら合わせて直すこと。
    WIDTH = 96
    HEIGHT = 64
    SIZE = 2871

    def disable?
      return true unless test_token
      return true unless Redis.health[:status] == 'OK'
      return super
    end

    def setup
      return if disable?
      WebMock.disable_net_connect!
      stub_request(:get, URL).to_return(
        body: File.binread(File.join(Environment.dir, 'test/fixture/sample.jpg')),
        headers: {'Content-Type' => 'image/jpeg'},
      )
      @storage = MediaMetadataStorage.new
      @uri = Ginseng::URI.parse(URL)
      # push は tmp/media/<sha256> が既にあると取得を省く。前回実行の残骸で
      # スタブが空振りしないよう、毎回消してから始める。
      @path = File.join(Environment.dir, 'tmp/media', URL.sha256)
      FileUtils.rm_f(@path)
    end

    def teardown
      FileUtils.rm_f(@path) if @path
      @storage&.unlink(@uri)
      super
    end

    def test_push
      @storage.push(@uri)

      assert_equal({
        height: HEIGHT,
        mediatype: 'image',
        size: SIZE,
        length: SIZE,
        subtype: 'jpeg',
        type: 'image/jpeg',
        width: WIDTH,
        url: URL,
      }, @storage[@uri])
    end
  end
end
