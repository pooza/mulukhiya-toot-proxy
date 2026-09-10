module Mulukhiya
  # NeverSilent の印が、**raise する場所で実際に付くこと** (#4693)。
  #
  # ⚠⚠ `report_error_gaps` は印を自分で組み立てて渡しているので、
  # `verify_token_integrity!` / `encrypt_token!` の `NeverSilent.mark` を消しても
  # 全テストが緑のままだった（5.37.0 リリース前レビュー）。2025-10 のトークン汚染と
  # 同じ型の事故が、Sentry に出なくなる。ここでは配線そのものを通す。
  class NeverSilentWiringTest < TestCase
    def setup
      @controller = APIController.new!
    end

    # 🔴 **トークンの混線は印付きの `AuthError` になる。**
    def test_token_mismatch_is_marked
      stub_tokens(expected: 'expected-token-0001', actual: 'another-token-0002')

      error = assert_raises(Ginseng::AuthError) {@controller.send(:verify_token_integrity!)}
      assert_predicate(error, :never_silent?)
    end

    # 一致していれば何も上げない。
    def test_matching_token_passes
      stub_tokens(expected: 'expected-token-0001', actual: 'expected-token-0001')

      assert_nothing_raised {@controller.send(:verify_token_integrity!)}
    end

    # 🔴 **暗号化の失敗は印付きで上がる。**`Ginseng::CryptError` は 403 なので、
    # 印が無いと log 止めになる（設定が壊れていても無音）。
    def test_encrypt_failure_is_marked
      value = Object.new
      value.define_singleton_method(:encrypt) {raise Ginseng::CryptError, 'crypt broken'}

      error = assert_raises(Ginseng::CryptError) {@controller.send(:encrypt_token!, value)}
      assert_predicate(error, :never_silent?)
    end

    private

    def stub_tokens(expected:, actual:)
      sns = Object.new
      sns.define_singleton_method(:token) {actual}
      request = Object.new
      request.define_singleton_method(:path) {'/mulukhiya/api/status/list'}
      @controller.define_singleton_method(:token) {expected}
      @controller.define_singleton_method(:sns) {sns}
      @controller.define_singleton_method(:request) {request}
    end
  end
end
