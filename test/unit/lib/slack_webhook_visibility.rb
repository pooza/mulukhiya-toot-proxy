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

    # ⚠⚠ **配線ごと押さえる (#4624)。**未知の値のとき、上流へ実際に送られるのが
    # **アカウント設定の既定**であって `public` ではないこと。
    def test_unknown_visibility_sends_account_default
      expected = parser_class.visibility_name('private')

      assert_equal(expected, visibility_for('bogus'))
      assert_equal(expected, visibility_for(nil))
    end

    # 既知の値は指定どおりに送る（既定を上書きする）。
    def test_known_visibility_sends_requested
      assert_equal(parser_class.visibility_name('unlisted'), visibility_for('unlisted'))
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

    # ⚠ **gem の `visibility_name` は未知の値を `public` へ丸める。**これは
    # fail-open の向きが**最も公開側**だということ。#4624 で `Webhook` 側が
    # ここへ未知の値を渡さないようにしたので、この性質は「踏んではいけない挙動」
    # として押さえておく（下の requested_visibility のテストが本丸）。
    def test_gem_rounds_unknown_visibility_to_public
      assert_equal(
        parser_class.visibility_name(:public),
        parser_class.visibility_name('bogus'),
      )
    end

    # ⚠⚠ **本丸 (#4624)。**未知の値は**アカウント設定の既定へ倒す**。
    # 素通しすると `private` に設定した webhook が、綴り誤りや Misskey 語彙
    # ひとつで**公開投稿になる**。
    def test_unknown_visibility_falls_back_to_account_default
      # ⚠ **`home` を未知の値として使わない。**Misskey 設定では `unlisted` の
      # 別名として**既知**なので、両系で走るテストでは成立しない（CI で踏んだ）。
      assert_nil(requested_visibility('bogus'))
      assert_nil(requested_visibility('sekret'))
    end

    # 既知の語は通す。⚠ キー（`:public` 等）と値（プラットフォーム名）の
    # **両方**が既知として扱われること。
    def test_known_visibility_is_accepted
      [:public, :unlisted, :private, :direct].each do |name|
        assert_equal(name.to_s, requested_visibility(name.to_s))
        platform = parser_class.visibility_name(name)

        assert_equal(platform, requested_visibility(platform))
      end
    end

    # 指定なしはそのまま既定へ倒す（未知の値と同じ扱いでよい）。
    def test_blank_visibility_falls_back_to_account_default
      assert_nil(requested_visibility(nil))
      assert_nil(requested_visibility(''))
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

    # `Webhook` の private メソッドを send で叩く。⚠ 実 SNS には触らない
    # （`visibility_names` も `@user_config` もパーサ・ハッシュを読むだけ）。
    def requested_visibility(name)
      return Webhook.allocate.send(:requested_visibility, name)
    end

    # アカウント設定の既定を `default` にした Webhook で、実際に送られる値を得る。
    def visibility_for(requested, default: 'private')
      webhook = Webhook.allocate
      webhook.instance_variable_set(:@user_config, {'/webhook/visibility' => default})
      return webhook.send(:visibility_for, requested)
    end

    def contract_errors(values = {})
      return SlackWebhookContract.new.exec({
        'digest' => 'a' * 64,
        'text' => '本文',
      }.merge(values))
    end
  end
end
