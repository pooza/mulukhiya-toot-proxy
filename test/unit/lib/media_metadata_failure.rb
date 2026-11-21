module Mulukhiya
  # 媒体のメタデータが取れなかったときのふるまい (#4920)。
  #
  # - 空のメタデータ（`{}`）は 1 日だけ置く。以前は成功と同じ 100 日で、一時的な失敗でも
  #   その媒体は 100 日空のままだった
  # - 宛先へ直接書かない。書きかけのファイルを別のスレッドが読むと、空のメタデータが残った
  #
  # ⚠ MediaMetadataStorageTest には置かない。あちらはテスト用トークンが無いと丸ごと omit される。
  class MediaMetadataFailureTest < TestCase
    URL = 'https://media.test/failure.jpg'.freeze

    def disable?
      return true unless Redis.health[:status] == 'OK'
      return super
    end

    def setup
      return if disable?
      WebMock.disable_net_connect!
      @storage = MediaMetadataStorage.new
      @uri = Ginseng::URI.parse(URL)
      @path = File.join(Environment.dir, 'tmp/media', URL.sha256)
      FileUtils.rm_f(@path)
    end

    def teardown
      return if disable?
      FileUtils.rm_f(@path)
      @storage.unlink(@uri)
      WebMock.reset!
      super
    end

    def test_failure_is_cached_for_a_day
      stub_request(:get, URL).to_return(status: 503)
      @storage.push(@uri)

      assert_equal({}, @storage[@uri])
      ttl = @storage.redis.call('TTL', @storage.create_key(@uri))

      assert_operator(ttl, :>, 0)
      assert_operator(ttl, :<=, MediaMetadataStorage::NEGATIVE_TTL)
    end

    # 壊れたファイルは消す。残すと、引き直しても同じファイルを読む。
    def test_unreadable_file_is_removed
      stub_request(:get, URL).to_return(body: 'not an image', headers: {'Content-Type' => 'image/jpeg'})
      @storage.push(@uri)

      assert_equal({}, @storage[@uri])
      assert_false(File.exist?(@path))
    end

    def test_success_leaves_no_temporary_file
      stub_request(:get, URL).to_return(
        body: File.binread(File.join(Environment.dir, 'test/fixture/sample.jpg')),
        headers: {'Content-Type' => 'image/jpeg'},
      )
      @storage.push(@uri)

      assert_equal(96, @storage[@uri][:width])
      assert_empty(Dir.glob("#{@path}.*"))
      assert_operator(@storage.redis.call('TTL', @storage.create_key(@uri)), :>, MediaMetadataStorage::NEGATIVE_TTL)
    end
  end
end
