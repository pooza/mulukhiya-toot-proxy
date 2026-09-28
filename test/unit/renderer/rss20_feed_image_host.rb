module Mulukhiya
  # フィードの画像取得が、ホストの検証を実際に渡していること (#4749)。
  #
  # 🔴 enclosure の URL はフィードの提供元が決める値。ginseng-web 3.0.3 は `fetch_image` の
  # 既定で内部アドレスを塞いだが、モロヘイヤは `fetch_image` を上書きしているので届かない。
  # ⚠ **呼び出し側のテストを別に持つ**（#4578 の教訓）。ストレージ側だけだと、ここで
  # 渡すのをやめても緑のまま無検証に戻る。
  #
  # ⚠ インスタンスは SNS と Redis を掴むので `allocate` で作り、使うものだけ差し替える。
  class RSS20FeedImageHostTest < TestCase
    def setup
      @renderer = RSS20FeedRenderer.allocate
      @renderer.instance_variable_set(:@http, Struct.new(:base_uri).new(nil))
      @calls = calls = []
      storage = Object.new
      storage.define_singleton_method(:key?) {|_uri| false}
      storage.define_singleton_method(:push) {|uri, **opts| calls.push([uri, opts])}
      storage.define_singleton_method(:[]) {|_uri| {}}
      @renderer.metadata_storage = storage
    end

    def test_fetch_image_passes_host_validator
      @renderer.send(:fetch_image, 'https://example.com/a.jpg')

      assert_equal(1, @calls.size)
      validator = @calls.first.last[:host_validator]

      assert_respond_to(validator, :call, 'フィードの画像を無検証で取りに行っている')
    end
  end
end
