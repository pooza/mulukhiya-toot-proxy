module Mulukhiya
  class DynamicFeaturesTest < TestCase
    def test_registry_keys
      assert_equal(
        ['annict_linked', 'annict_review', 'compose_templates', 'media_catalog',
          'media_update', 'program_editable', 'word_suggest', 'nowplaying_resolver',
          'nowplaying_url_resolver', 'spotify_enabled', 'spotify_linked',
          'user_handler_config'].to_set,
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

    # annict_review は SNS アカウント非依存で、サーバーの annict? 稼働可否を映す (#4433)。
    def test_annict_review_reflects_controller_annict
      assert_equal(
        Environment.controller_class.annict?,
        DynamicFeatures.new(sns_double(nil)).to_h['annict_review'],
      )
    end

    def test_spotify_linked_is_false_without_account
      assert_false(DynamicFeatures.new(sns_double(nil)).to_h['spotify_linked'])
    end

    def test_spotify_linked_reflects_linked_account
      assert_true(DynamicFeatures.new(sns_double(linked_account)).to_h['spotify_linked'])
    end

    # 利用者向けのハンドラーの切り替えはサーバー設定を要さないので、アカウントが無くても true (#4936)。
    def test_user_handler_config_is_always_true
      assert_true(DynamicFeatures.new(sns_double(nil)).to_h['user_handler_config'])
    end

    private

    # 実 SNS/Account モデル (DB 依存) を読み込まないための最小ダブル。
    def sns_double(account)
      return Struct.new(:account).new(account)
    end

    def linked_account
      account = Object.new
      def account.annict_linked? = true
      def account.spotify_linked? = true
      return account
    end
  end
end
