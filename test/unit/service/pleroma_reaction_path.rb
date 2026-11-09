module Mulukhiya
  # 絵文字をパスへ符号化して入れる（5.46.0 のリリース前レビュー）。⚠ 通信しない。
  class PleromaReactionPathTest < TestCase
    def setup
      @paths = []
      paths = @paths
      http = Object.new
      http.define_singleton_method(:put) {|path, _opts = {}| paths.push(path)}
      http.define_singleton_method(:delete) {|path, _opts = {}| paths.push(path)}
      @service = PleromaService.allocate
      @service.define_singleton_method(:http) {http}
      @service.define_singleton_method(:create_headers) {|_headers = nil| {}}
    end

    def test_reaction
      @service.reaction('abc', '👍')
      @service.reaction('abc', ':borahorn:')
      @service.reaction('abc', '../x?y')

      assert_equal('/api/v1/pleroma/statuses/abc/reactions/%F0%9F%91%8D', @paths[0])
      assert_equal('/api/v1/pleroma/statuses/abc/reactions/%3Aborahorn%3A', @paths[1])
      assert_equal('/api/v1/pleroma/statuses/abc/reactions/..%2Fx%3Fy', @paths[2])
    end

    def test_delete_reaction
      @service.delete_reaction('abc', '../x?y')

      assert_equal('/api/v1/pleroma/statuses/abc/reactions/..%2Fx%3Fy', @paths[0])
    end
  end
end
