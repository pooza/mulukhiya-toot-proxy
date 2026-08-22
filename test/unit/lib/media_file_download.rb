require 'webmock/test_unit'

module Mulukhiya
  # リモート添付の取得ガード (#4576)。
  #
  # ⚠ **ここで取ったボディはそのまま SNS の添付になる。**準ブラインドではなく
  # full-read SSRF になりうる経路（webhook に `image_url` を入れるだけで、
  # 内部サービスの応答がタイムライン上の画像として読み出せた）。
  class MediaFileDownloadTest < TestCase
    URL = 'https://media.example.com/image.png'.freeze
    INTERNAL = 'http://127.0.0.1:9200/_cat/indices'.freeze

    def setup
      WebMock.disable_net_connect!
      # ⚠ 差し替えたら teardown で必ず戻すこと。
      @original_validator = RemoteHost.validator
      @paths = []
    end

    def teardown
      super
      RemoteHost.validator = @original_validator
      @paths.each {|path| FileUtils.rm_f(path)}
      WebMock.reset!
      WebMock.allow_net_connect!
    end

    # ⚠ **拒否はプリフライトの rescue に飲ませない (#4535)。**飲むと
    # 「プリフライトが true = GET してよい」が成り立たなくなる。
    def test_rejected_host_raises
      RemoteHost.validator = ->(_host) {}
      get = stub_request(:get, INTERNAL).to_return(status: 200, body: 'secret')

      assert_raise(Ginseng::GatewayError) {download(INTERNAL)}
      assert_not_requested(get)
    end

    # 相手の申告が上限超えなら GET しない。
    def test_oversize_content_length_is_rejected_before_get
      allow_all
      config['/media/download/max_bytes'] = 16
      stub_request(:head, URL).to_return(status: 200, headers: {'Content-Length' => '1024'})
      get = stub_request(:get, URL).to_return(status: 200, body: 'x' * 1024)

      assert_raise(Ginseng::GatewayError) {download(URL)}
      assert_not_requested(get)
    end

    # ⚠ **HEAD が Content-Length を返さない相手（GAS 等）でも最終防衛線が要る。**
    # 受信後の実測で弾き、ディスクへは書かない。
    def test_oversize_body_is_rejected_after_get
      allow_all
      config['/media/download/max_bytes'] = 16
      stub_request(:head, URL).to_return(status: 200)
      stub_request(:get, URL).to_return(status: 200, body: 'x' * 1024)

      assert_raise(Ginseng::GatewayError) {download(URL)}
      assert_path_not_exist(path_for(URL))
    end

    # ⚠⚠ **プリフライトを通したあとの GET も検証されること
    # (pooza/ginseng-core#528)。**`Ginseng::HTTP#request` は
    # `options.delete(:host_validator)` で呼び出し側の hash を壊すので、同じ hash を
    # head と get で使い回すと **GET だけ無検証**になる（＝リダイレクト先が内部でも
    # 追従する）。呼び出しごとに hash を作り直していることを、validator の
    # **呼ばれた回数**で押さえる。
    def test_validator_is_applied_to_both_head_and_get
      hosts = []
      RemoteHost.validator = lambda do |host|
        hosts.push(host)
        return '93.184.216.34'
      end
      stub_request(:head, URL).to_return(status: 200, headers: {'Content-Length' => '5'})
      stub_request(:get, URL).to_return(status: 200, body: 'small')

      download(URL)

      assert_equal(2, hosts.size)
      assert_equal(['media.example.com'], hosts.uniq)
    end

    # HEAD 非対応 (405) は「判定不能」として GET へ倒す。正常系を塞がないこと。
    def test_head_not_supported_falls_back_to_get
      allow_all
      stub_request(:head, URL).to_return(status: 405)
      stub_request(:get, URL).to_return(status: 200, body: 'small')

      download(URL)

      assert_equal('small', File.read(path_for(URL)))
    end

    def test_downloads_within_limit
      allow_all
      stub_request(:head, URL).to_return(status: 200, headers: {'Content-Length' => '5'})
      stub_request(:get, URL).to_return(status: 200, body: 'small')

      download(URL)

      assert_equal('small', File.read(path_for(URL)))
    end

    # ⚠⚠ **宛先を切り詰めないこと (#4626)。**`path` は URL の sha256 由来の
    # **固定名**なので、同じ URL を同時に取りに行くと `File.write` の O_TRUNC が
    # **読み出し中のファイルを 0 バイトへ切り詰める**。上流への送信は gem が
    # `File.open(file, 'rb')` でストリームしながら読むため、その窓は秒オーダー。
    #
    # ⚠ **実装をスタブせず、アトミック性そのものを観測する。**先に開いた読み手が
    # **古い内容を最後まで読み切れる**なら rename であり、O_TRUNC ではない。
    def test_destination_is_never_truncated_under_a_reader
      path = File.join(Environment.dir, 'tmp/media', 'atomic_write_test.txt')
      @paths.push(path)
      File.write(path, 'old' * 100)

      File.open(path, 'rb') do |reader|
        head = reader.read(3)
        MediaFile.write_atomic(path, 'new')
        # ⚠ 直接書いていればここが空になる（切り詰められた inode を読むため）。
        assert_equal('old' * 100, head + reader.read)
      end

      # 開き直せば新しい内容が見える。
      assert_equal('new', File.read(path))
    end

    # ⚠ **一時ファイルを残さない。**残ると `MediaFile.all` の掃除（`*` glob）が
    # 拾うまで tmp/media に溜まる。
    def test_temporary_path_is_removed
      allow_all
      stub_request(:head, URL).to_return(status: 200, headers: {'Content-Length' => '5'})
      stub_request(:get, URL).to_return(status: 200, body: 'small')

      download(URL)

      assert_empty(Dir.glob("#{path_for(URL)}.*"))
    end

    private

    def allow_all
      RemoteHost.validator = ->(_host) {'93.184.216.34'}
    end

    def download(url)
      uri = Ginseng::URI.parse(url)
      @paths.push(path_for(url))
      @paths.concat(Dir.glob("#{path_for(url)}.*"))
      return MediaFile.download(uri, host_validator: RemoteHost.validator)
    end

    def path_for(url)
      uri = Ginseng::URI.parse(url)
      return File.join(Environment.dir, 'tmp/media', "#{uri.to_s.sha256}#{File.extname(uri.path)}")
    end
  end
end
