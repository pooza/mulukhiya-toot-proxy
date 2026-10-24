module Mulukhiya
  class URLNormalizeHandlerTest < TestCase
    def setup
      @handler = Handler.create(:url_normalize)
    end

    def test_handle_pre_toot
      @handler.clear
      @handler.handle_pre_toot(status_field => 'https://www.google.co.jp/?q=日本語')

      assert_equal({rewrited_url: 'https://www.google.co.jp/?q=%E6%97%A5%E6%9C%AC%E8%AA%9E', source_url: 'https://www.google.co.jp/?q=日本語'}, @handler.debug_info[:result].first)

      @handler.clear
      @handler.handle_pre_toot(status_field => 'https://ja.wikipedia.org/wiki/日本語')

      assert_equal({rewrited_url: 'https://ja.wikipedia.org/wiki/%E6%97%A5%E6%9C%AC%E8%AA%9E', source_url: 'https://ja.wikipedia.org/wiki/日本語'}, @handler.debug_info[:result].first)
    end

    # ⚠ ginseng-core v4.1.0 から、URL は直後の全角の句読点・括弧で切れる (#4848・pooza/ginseng-core#721)。
    # 以前は次の文まで URL として拾い、エンコードしてリンクを壊していた。
    # ⚠ **Mastodon 系だけ。**Misskey 系の `NoteParser#uris`（ginseng-fediverse）は `URI.scan` を通らず、
    # 空白と丸括弧でしか切らないので従来どおり。
    def test_handle_pre_toot_fullwidth_terminator
      @handler.clear
      @handler.handle_pre_toot(status_field => 'https://www.google.co.jp/?q=日本語。次の文')
      source = Environment.misskey_type? ? 'https://www.google.co.jp/?q=日本語。次の文' : 'https://www.google.co.jp/?q=日本語'

      assert_equal(source, @handler.debug_info[:result].first[:source_url])

      # ⚠ その代わり、パスに生の全角の括弧を含む URL はそこで切れ、エンコードされない（受け入れた挙動の変化）。
      @handler.clear
      @handler.handle_pre_toot(status_field => 'https://whattosay.net/2018/11/27/【nhk】ネット利用だけでも契約すべきなのか？/')
      if Environment.misskey_type?
        assert_equal('https://whattosay.net/2018/11/27/【nhk】ネット利用だけでも契約すべきなのか？/', @handler.debug_info[:result].first[:source_url])
      else
        assert_nil(@handler.debug_info)
      end
    end
  end
end
