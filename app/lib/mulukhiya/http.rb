module Mulukhiya
  class HTTP < Ginseng::Web::HTTP
    include Package

    # サイズ確認の HEAD に応じない相手（GAS の Web アプリなど）が返す状態コード (#4397)。
    # 呼び出し側は黙って GET へ倒すので、`quiet_statuses` に渡して上流のエラー行も止める (#4793)。
    # ⚠ 止まるのは「上流が実際にこの状態を返した試行」の error 行だけ。タイムアウト・接続断・
    # 5xx は挙げても残る（pooza/ginseng-core#672）。
    HEAD_UNSUPPORTED_STATUSES = [403, 405].freeze
  end
end
