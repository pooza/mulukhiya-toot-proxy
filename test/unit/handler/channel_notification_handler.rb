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
        assert_kind_of(Array, Array(entry[:notify_to]))
      end
    end

    def test_notify_to_accounts_with_array
      entry = {name: 'test', notify_to: ['@user1@example.com', '@user2@example.com']}
      accounts = @handler.notify_to_accounts(entry)

      assert_kind_of(Array, accounts)
    end

    def test_notify_to_accounts_with_empty
      entry = {name: 'test', notify_to: []}
      accounts = @handler.notify_to_accounts(entry)

      assert_kind_of(Array, accounts)
      assert_equal(0, accounts.length)
    end
  end
end
