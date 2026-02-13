module Mulukhiya
  class MisskeyServiceTest < TestCase
    def setup
      WebMock.enable!
      @service = MisskeyService.new('https://misskey.test', 'test_token_abc123')
    end

    def test_parse_aid
      result = MisskeyService.parse_aid('00000000abcdefgh')

      assert_kind_of(Time, result)
      assert_equal(2000, result.getutc.year)
      assert_equal(1, result.getutc.month)
      assert_equal(1, result.getutc.day)
    end

    def test_create_headers
      headers = @service.create_headers({'Cookie' => 'session=abc123'})

      assert_kind_of(Hash, headers)
      refute(headers.any? {|k, _| k.to_s.downcase == 'cookie'})
    end

    def test_draft
      stub_request(:post, %r{misskey\.test/api/notes/drafts/create})
        .to_return(status: 200, body: fixture('misskey_draft.json'), headers: {'Content-Type' => 'application/json'})

      @service.draft('テスト下書き')

      assert_requested(:post, %r{misskey\.test/api/notes/drafts/create})
    end

    def test_update_draft
      stub_request(:post, %r{misskey\.test/api/notes/drafts/update})
        .to_return(status: 200, body: fixture('misskey_draft.json'), headers: {'Content-Type' => 'application/json'})

      @service.update_draft({draftId: 'test_draft_001', text: '更新テスト'})

      assert_requested(:post, %r{misskey\.test/api/notes/drafts/update})
    end
  end
end
