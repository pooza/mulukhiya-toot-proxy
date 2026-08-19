module Mulukhiya
  # Slack 互換 webhook のリクエストごとの公開範囲 (#4599)。
  #
  # ⚠ **SlackWebhookPayloadTest とは分けてある。**あちらは `SlackService.config?`
  # を前提に disable? するので、Slack を設定していない環境ではクラスごと omission
  # になる。ここで見るのは「payload が組む Hash」と「契約が受け付ける形」だけで
  # Slack の設定を必要としないため、常に実走させる (#4503 の教訓)。
  class SlackWebhookVisibilityTest < TestCase
    # ⚠ **Webhook#post が `body[visibility_field] || visibility` で既定へ倒す**ので、
    # payload 側は「指定が来たときだけキーを載せる」のが正しい。載せてしまうと
    # アカウント設定の既定が上書きされる。
    def test_values_includes_requested_visibility
      values = payload(visibility: 'unlisted').values

      assert_equal('unlisted', values[visibility_field])
    end

    def test_values_omits_visibility_when_not_given
      assert_not_operator(payload.values, :key?, visibility_field)
    end

    # 空文字は「指定なし」として扱う。ここでキーを載せると visibility_name が
    # public へ丸めてしまい、アカウント設定の既定を黙って踏み潰す。
    def test_values_omits_blank_visibility
      assert_not_operator(payload(visibility: '').values, :key?, visibility_field)
    end

    def test_values_keeps_text_and_spoiler
      values = payload(visibility: 'private').values

      assert_equal('本文', values[status_field])
      assert_equal('ネタバレ注意', values[spoiler_field])
    end

    def test_contract_accepts_visibility
      assert_empty(contract_errors('visibility' => 'private'))
    end

    # ⚠ **後方互換。**この項目を足したことで、`"visibility": null` を送っていた
    # クライアントが 422 になってはいけない。
    def test_contract_accepts_null_visibility
      assert_empty(contract_errors('visibility' => nil))
    end

    def test_contract_accepts_missing_visibility
      assert_empty(contract_errors)
    end

    # ⚠ **未知の値は契約で弾かず、既定へ丸める。**この保証があるので、
    # SlackWebhookContract 側で値の妥当性を見る必要がない。
    def test_unknown_visibility_falls_back_to_public
      assert_equal(
        parser_class.visibility_name(:public),
        parser_class.visibility_name('bogus'),
      )
    end

    def test_known_visibility_is_preserved
      [:public, :unlisted, :private, :direct].each do |name|
        assert_equal(
          parser_class.visibility_name(name),
          parser_class.visibility_name(parser_class.visibility_name(name)),
        )
      end
    end

    private

    def payload(values = {})
      return SlackWebhookPayload.new({
        'text' => '本文',
        'spoiler_text' => 'ネタバレ注意',
      }.merge(values.deep_stringify_keys))
    end

    def contract_errors(values = {})
      return SlackWebhookContract.new.exec({
        'digest' => 'a' * 64,
        'text' => '本文',
      }.merge(values))
    end
  end
end
