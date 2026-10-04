module Mulukhiya
  # HTTP ステータスの分類 (#4657)。
  #
  # ⚠ 3 か所に散っていた「4xx か」の判定をここへ寄せたので、**境目がずれると
  # 3 か所が揃ってずれる**。呼び側のテストはそれぞれの経路を見ているだけで、
  # 境目そのものは押さえていなかった (#4698)。
  class HTTPStatusTest < TestCase
    def test_boundaries
      assert_false(HTTPStatus.client_error?(399))
      assert_true(HTTPStatus.client_error?(400))
      assert_true(HTTPStatus.client_error?(499))
      assert_false(HTTPStatus.client_error?(500))
    end

    # ⚠⚠ **nil は 4xx ではない。**`source_status` は接続失敗で nil になり、
    # それは「クライアント起因」ではなく上流かこちらの問題。
    def test_nil_is_not_a_client_error
      assert_false(HTTPStatus.client_error?(nil))
    end

    # 呼び側が文字列で持っていても同じく判定する（`to_i` を通す）。
    def test_string_status
      assert_true(HTTPStatus.client_error?('404'))
      assert_false(HTTPStatus.client_error?('502'))
    end

    def test_other_classes
      [200, 204, 301, 304, 502, 503].each do |status|
        assert_false(HTTPStatus.client_error?(status), status.to_s)
      end
    end
  end
end
