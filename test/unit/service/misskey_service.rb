module Mulukhiya
  class MisskeyServiceTest < TestCase
    def setup
      WebMock.disable_net_connect!
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

    def test_theme_color_from_api
      stub_request(:post, %r{misskey\.test/api/meta})
        .to_return(status: 200, body: '{"themeColor":"#86b300"}', headers: {'Content-Type' => 'application/json'})

      color = @service.theme_color

      assert_equal('#86b300', color)
    end

    def test_theme_color_fallback
      stub_request(:post, %r{misskey\.test/api/meta})
        .to_return(status: 500, body: '{}')

      color = @service.theme_color

      assert_equal(config['/misskey/theme/color'], color)
    end

    def test_fetch_avatar_decorations
      stub_request(:post, %r{misskey\.test/api/get-avatar-decorations})
        .to_return(status: 200, body: '[{"id":"deco1","name":"実況1","description":"","url":"https://example.com/1.png","roleIdsThatCanBeUsedThisDecoration":[]}]', headers: {'Content-Type' => 'application/json'})

      result = @service.fetch_avatar_decorations

      assert_kind_of(Array, result)
      assert_equal('deco1', result.first['id'])
    end

    def test_fetch_account_detail
      stub_request(:post, %r{misskey\.test/api/i$})
        .to_return(status: 200, body: '{"id":"user1","avatarDecorations":[{"id":"deco1"}]}', headers: {'Content-Type' => 'application/json'})

      result = @service.fetch_account_detail

      assert_kind_of(Hash, result)
      assert_equal([{'id' => 'deco1'}], result['avatarDecorations'])
    end

    def test_update_account
      stub_request(:post, %r{misskey\.test/api/i/update})
        .to_return(status: 200, body: '{"id":"user1","avatarDecorations":[]}', headers: {'Content-Type' => 'application/json'})

      @service.update_account(avatarDecorations: [])

      assert_requested(:post, %r{misskey\.test/api/i/update})
    end
  end
end
