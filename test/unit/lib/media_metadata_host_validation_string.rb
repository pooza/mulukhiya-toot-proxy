module Mulukhiya
  # フィードの enclosure は String の URL で来る (RSS20FeedRenderer#absolute_uri)。
  # ホストの検証には URL 全体ではなくホスト名が渡ること。
  #
  # 🔴 5.39.0 のリリース前レビューで見つけた。`RemoteHost.validate!` は `host` を持たない値を
  # ホスト名として扱うので、String のまま渡すと公開ホストまで全件拒否していた。
  # ⚠ 既存の MediaMetadataHostValidationTest は Ginseng::URI を渡して「内部アドレスを拒否する」
  # ことだけを見ていたので、この形を拾えなかった。
  #
  # ⚠ Redis も DNS も要らないように、検証と保存を差し替えて「何が渡ったか」だけを見る。
  class MediaMetadataHostValidationStringTest < TestCase
    URL = 'https://feed.example/images/a.jpg'.freeze

    def setup
      @path = File.join(Environment.dir, 'tmp/media', URL.sha256)
      FileUtils.rm_f(@path)
      @hosts = hosts = []
      @original = RemoteHost.method(:validate!)
      RemoteHost.define_singleton_method(:validate!) do |uri|
        hosts.push(uri.respond_to?(:host) ? uri.host.to_s : uri.to_s)
        true
      end
      @saved = saved = {}
      body = File.binread(File.join(Environment.dir, 'test/fixture/sample.jpg'))
      http = Object.new
      http.define_singleton_method(:get) {|_uri, _options = {}| body}
      @storage = MediaMetadataStorage.allocate
      @storage.define_singleton_method(:http) {http}
      @storage.define_singleton_method(:set) {|key, values| saved[key.to_s] = values}
      @storage.define_singleton_method(:log) {|*| nil}
    end

    def teardown
      RemoteHost.define_singleton_method(:validate!, @original) if @original
      FileUtils.rm_f(@path)
      super
    end

    def test_string_url_is_validated_by_host
      @storage.push(URL, host_validator: RemoteHost.unpinned_validator)

      assert_equal(['feed.example'], @hosts)
      assert_equal(URL, @saved[URL][:url])
    end

    def test_uri_object_is_validated_by_host
      @storage.push(Ginseng::URI.parse(URL), host_validator: RemoteHost.unpinned_validator)

      assert_equal(['feed.example'], @hosts)
    end

    def test_without_validator_skips_validation
      @storage.push(URL)

      assert_empty(@hosts)
    end
  end
end
