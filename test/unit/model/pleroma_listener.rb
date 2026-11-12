module Mulukhiya
  # Akkoma（Pleroma 系）の listener の送り主の引き方（段階 6・#4901）。⚠ Akkoma の DB とテスト用アカウントが要る。
  class PleromaListenerTest < TestCase
    def disable?
      return true unless Environment.pleroma?
      return true unless account
      return super
    end

    # ストリーミングの `notification` の `account.id` は API の ID（FlakeId）。
    def test_sender
      sender = PleromaListener.sender({'account' => {'id' => account.api_id}})

      assert_kind_of(Pleroma::Account, sender)
      assert_equal(account.id, sender.id)
    end

    def test_sender_without_account
      assert_nil(PleromaListener.sender({}))
    end

    def test_sender_with_invalid_id
      assert_nil(PleromaListener.sender({'account' => {'id' => 'not-a-flake!'}}))
    end
  end
end
