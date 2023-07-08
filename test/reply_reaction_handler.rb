module Mulukhiya
  class ReplyReactionHandlerTest < TestCase
    def setup
      @handler = Handler.create(:reply_reaction)
    end

    def test_handle_post_reaction
      note = account.recent_status

      @handler.clear
      @handler.handle_post_reaction(status_id: note.id, emoji: '')

      assert_nil(@handler.debug_info)

      @handler.clear
      @handler.handle_post_reaction(status_id: note.id, emoji: ':borahorn:')

      assert_equal(':borahorn:', @handler.debug_info[:result].first[:reaction])

      @handler.clear
      @handler.handle_post_reaction(status_id: note.id, emoji: ':pacochi_wakaru_cat@.:')

      assert_equal(':pacochi_wakaru_cat:', @handler.debug_info[:result].first[:reaction])
    end
  end
end
