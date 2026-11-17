module Mulukhiya
  # Akkoma の自分の投稿の一覧で、読めなかった投稿を飛ばすか（5.47.0 のリリース前レビュー）。
  # ⚠ `Pleroma::Account` は Sequel のモデルで DB が要るので、判定の `Status.deleted_error?` を確かめる。
  class PleromaStatusDeletedErrorTest < TestCase
    ResponseDouble = Struct.new(:code, :body)

    # 消された投稿（404・410）は飛ばす。
    def test_deleted
      [404, 410].each do |code|
        assert(Pleroma::Status.deleted_error?(gateway_error(code)))
      end
    end

    # 上流の不調・トークンの失効・接続の失敗は飛ばさない（空の一覧にしない）。
    def test_upstream_failure
      [401, 403, 500, 503].each do |code|
        assert_false(Pleroma::Status.deleted_error?(gateway_error(code)))
      end

      assert_false(Pleroma::Status.deleted_error?(Ginseng::GatewayError.new('Net::ReadTimeout')))
      assert_false(Pleroma::Status.deleted_error?(RuntimeError.new('broken')))
    end

    private

    def gateway_error(code)
      error = Ginseng::GatewayError.new("Bad response #{code}")
      error.response = ResponseDouble.new(code, '{}')
      return error
    end
  end
end
