module Mulukhiya
  # Spotify の token endpoint が返した 4xx を、どちらへ倒すかの判定 (#4577 の 4)。
  #
  # - `:operator_fault` → `GatewayError`(502) のまま上げて Sentry に出す
  # - `:reauth` → `AuthError`(403)。capsicum が再連携フローを出す
  #
  # ⚠⚠ **倒す先を 1 段間違えると、直せる人のところへ話が行かなくなる。**
  # ユーザー起因を運用側不備に倒すと**再連携導線が消えて当人のナウプレが黙って
  # 死ぬ**（#4577）。逆に倒すと**何度再連携しても直らない**（#4537 / #4480）。
  #
  # ⚠ I/O を持たない純関数だけを見るので、どの環境でも必ず走る。
  class SpotifyOAuthFailureTest < TestCase
    def service
      return @service ||= SpotifyUserService.new
    end

    def classify(body)
      return service.send(:classify_oauth_failure, body)
    end

    def undecidable?(body)
      return service.send(:undecidable_oauth_failure?, body)
    end

    # 🔴 **回帰。`body` が Hash でない回（HTML のエラーページ等）は再連携へ倒す。**
    # ここを「Hash でなければ運用側不備」と書くと **502 に変わり、
    # capsicum の再連携導線が消える**。
    def test_non_hash_body_falls_back_to_reauth
      assert_equal(:reauth, classify('<html>oops</html>'))
      assert_equal(:reauth, classify(nil))
      assert_equal(:reauth, classify([]))
    end

    # refresh_token の失効・revoke。再連携すれば直るのでユーザーへ返す。
    def test_invalid_grant_is_reauth
      assert_equal(:reauth, classify('error' => 'invalid_grant'))
    end

    # ⚠ 運用側不備はユーザーのせいにしない (#4480)。client_id/secret の設定ミスは
    # 何度再連携しても直らない。
    def test_operator_faults_stay_operator_faults
      ['invalid_client', 'unauthorized_client', 'unsupported_grant_type', 'invalid_scope'].each do |error|
        assert_equal(:operator_fault, classify('error' => error), error)
      end
    end

    # ⚠⚠ **`invalid_request` は判定不能だが、倒す先は据え置く。**
    # `error_description` の文面は Spotify の契約ではないので、文字列一致で
    # 振り分けると #4537 で塞いだ側の誤誘導が戻る。実データが貯まるまで動かさない。
    def test_invalid_request_stays_operator_fault
      assert_equal(:operator_fault, classify('error' => 'invalid_request'))
    end

    # ⚠⚠ **ただし「判定できなかった」ことは必ず残す。**これが倒す先を決める
    # ための唯一の実データになる（受け皿は #4743）。
    def test_only_invalid_request_is_undecidable
      assert(undecidable?('error' => 'invalid_request'))
      assert_false(undecidable?('error' => 'invalid_client'))
      assert_false(undecidable?('error' => 'invalid_grant'))
      assert_false(undecidable?('<html>oops</html>'))
    end

    # ⚠⚠ **本文をそのまま出さない。**token endpoint への要求・応答には
    # `refresh_token` が乗りうるので、`error` と `error_description` だけ採る。
    def test_log_carries_description_but_not_the_whole_body
      logged = []
      double = Object.new
      double.define_singleton_method(:error) {|payload| logged.push(payload)}
      service.define_singleton_method(:logger) {double}
      service.send(:log_undecidable_oauth_error, {
        'error' => 'invalid_request',
        'error_description' => 'Refresh token revoked',
        'refresh_token' => 'SHOULD-NOT-BE-LOGGED',
      })
      payload = logged.first

      assert_equal('invalid_request', payload[:oauth_error])
      assert_equal('Refresh token revoked', payload[:oauth_error_description])
      assert_not_match(/SHOULD-NOT-BE-LOGGED/, payload.to_s)
    end
  end
end
