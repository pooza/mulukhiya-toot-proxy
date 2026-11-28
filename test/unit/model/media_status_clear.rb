module Mulukhiya
  # Mastodon 系のテスト用アカウントの添付の後始末（#4938）。DB と SNS に触らない作り物で見る。
  class MediaStatusClearTest < TestCase
    def test_media_statuses_requests_only_media
      stub = stub_request(:get, 'https://mastodon.test/api/v1/accounts/42/statuses')
        .with(query: {only_media: 'true', limit: '30'})
        .to_return(body: [{id: '1'}, {id: '2'}].to_json, headers: {'Content-Type' => 'application/json'})
      statuses = MastodonService.new('https://mastodon.test', 'token').media_statuses('42', limit: 30)

      assert_requested(stub)
      assert_equal(['1', '2'], statuses.map {|v| v['id']})
    end

    def test_clear_attachments_deletes_media_statuses
      account = fake_account(test: true, statuses: [{'id' => '1'}, {'id' => '2'}])

      assert_equal(2, account.clear_attachments)
      assert_equal(['1', '2'], account.service.deleted)
      assert_equal(['42', 30], account.service.requested)
    end

    # 1 件で落ちても残りは消す。
    def test_clear_attachments_continues_after_error
      account = fake_account(test: true, statuses: [{'id' => 'bad'}, {'id' => '2'}])

      assert_equal(2, account.clear_attachments)
      assert_equal(['2'], account.service.deleted)
    end

    def test_clear_attachments_requires_test_account
      account = fake_account(test: false, statuses: [{'id' => '1'}])

      assert_raise(Ginseng::AuthError) {account.clear_attachments}
      assert_empty(account.service.deleted)
    end

    private

    def fake_account(test:, statuses:)
      service = Struct.new(:statuses, :deleted, :requested) do
        def media_statuses(account_id, params = {})
          self.requested = [account_id, params[:limit]]
          return statuses
        end

        def delete_status(id)
          raise Ginseng::GatewayError, 'Bad response 500' if id == 'bad'
          deleted.push(id)
        end
      end.new(statuses, [])
      controller = Struct.new(:status_delete_limit).new(30)
      account = Struct.new(:test, :service, :controller_class) do
        include MediaStatusClearMethods

        def test? = test
        def api_id = '42'
        def acct = 'test@mastodon.test'
      end
      return account.new(test, service, controller)
    end
  end
end
