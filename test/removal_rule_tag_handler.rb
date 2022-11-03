module Mulukhiya
  class RemovalRuleTagHandlerTest < TestCase
    def setup
      @handler = Handler.create(:removal_rule_tag)
    end

    def test_rules
      assert_kind_of(Array, @handler.rules)
      @handler.rules.each do |rule|
        assert_kind_of(String, rule['search'])
        assert_kind_of(Array, rule['removal_tags'])
      end
    end

    def test_handle_pre_toot
      config['/handler/removal_rule_tag/rules'] = [
        {'search' => '即売会', 'removal_tags' => ['ダイの大冒険']},
      ]

      @handler.clear
      @handler.handle_pre_toot(status_field => '超魔ゾンビ最強伝説 #ダイの大冒険')

      assert_nil(@handler.debug_info)

      @handler.clear
      @handler.handle_pre_toot(status_field => 'ザボエラオンリーイベント！ #即売会 #ダイの大冒険')

      assert_equal([{removal_tags: Set['ダイの大冒険']}], @handler.debug_info[:result])

      @handler.clear
      @handler.handle_pre_toot(status_field => "ザボエラオンリーイベント！ #ダイの大冒険\n#即売会")

      assert_equal([{removal_tags: Set['ダイの大冒険']}], @handler.debug_info[:result])
    end
  end
end
