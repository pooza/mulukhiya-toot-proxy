module Mulukhiya
  class ChannelNotificationHandlerTest < TestCase
    def setup
      @handler = Handler.create(:channel_notification)
    end

    def test_channel_entries
      entries = @handler.channel_entries

      assert_kind_of(Array, entries)
      entries.each do |entry|
        assert_kind_of(Hash, entry)
      end
    end
  end
end
