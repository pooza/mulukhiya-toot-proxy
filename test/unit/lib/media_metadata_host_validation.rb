module Mulukhiya
  # フィードの enclosure の取得で、内部アドレスを取りに行かないこと (#4749)。
  #
  # 🔴 enclosure の URL はフィードの提供元が決める値。検証を渡したら内部アドレスは
  # 取りに行かず、ネガティブキャッシュ（`{}`）に入れて 5 分おきに引き直さない（#4549）。
  #
  # ⚠ MediaMetadataStorageTest には置かない。あちらはテスト用トークンが無いと丸ごと
  # omit される。ここは Redis だけあれば走る。
  class MediaMetadataHostValidationTest < TestCase
    URL = 'http://127.0.0.1/secret.jpg'.freeze

    def disable?
      return true unless Redis.health[:status] == 'OK'
      return super
    end

    def setup
      return if disable?
      WebMock.disable_net_connect!
      # ⚠ 取りに行けば**本物の画像が返る**ようにしておく。スタブが無いと WebMock の例外で
      # 同じ `{}` になり、「検証を無視して取りに行った」を見分けられない。
      stub_request(:get, URL).to_return(
        body: File.binread(File.join(Environment.dir, 'test/fixture/sample.jpg')),
        headers: {'Content-Type' => 'image/jpeg'},
      )
      @storage = MediaMetadataStorage.new
      @uri = Ginseng::URI.parse(URL)
      @path = File.join(Environment.dir, 'tmp/media', URL.sha256)
      FileUtils.rm_f(@path)
    end

    def teardown
      return if disable?
      FileUtils.rm_f(@path)
      @storage.unlink(@uri)
      super
    end

    def test_rejects_internal_host_with_validator
      @storage.push(@uri, host_validator: RemoteHost.unpinned_validator)

      assert_equal({}, @storage[@uri])
      assert_false(File.exist?(@path))
      assert_not_requested(:get, URL)
    end
  end
end
