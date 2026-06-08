module Mulukhiya
  class DynamicFeaturesTest < TestCase
    def test_registry_keys
      assert_equal(
        ['annict_linked', 'media_catalog', 'program_editable', 'word_suggest'].to_set,
        DynamicFeatures::REGISTRY.keys.to_set,
      )
    end

    def test_to_h_returns_boolean_for_each_registered_key
      result = DynamicFeatures.new(sns_double(nil)).to_h

      assert_equal(DynamicFeatures::REGISTRY.keys.to_set, result.keys.to_set)
      result.each_value {|value| assert_boolean(value)}
    end

    def test_annict_linked_is_false_without_account
      assert_false(DynamicFeatures.new(sns_double(nil)).to_h['annict_linked'])
    end

    def test_annict_linked_reflects_linked_account
      assert_true(DynamicFeatures.new(sns_double(linked_account)).to_h['annict_linked'])
    end

    private

    # 実 SNS/Account モデル (DB 依存) を読み込まないための最小ダブル。
    def sns_double(account)
      return Struct.new(:account).new(account)
    end

    def linked_account
      account = Object.new
      def account.annict_linked? = true
      return account
    end
  end
end
