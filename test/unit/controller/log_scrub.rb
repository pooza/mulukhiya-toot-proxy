module Mulukhiya
  # request ログに資格情報を書かないこと (#4511)。
  #
  # ⚠ /logger/mask_query_params は **URL のクエリ**にしか効かない。Misskey は
  # トークンをリクエストボディのキー `i` で渡す (MisskeyController#token の
  # フォールバック) ので、ボディ側は SCRUBBED_LOG_PARAMS で落とす必要がある。
  # 両方揃わないと、掃除した端からログが再汚染される。
  class LogScrubTest < TestCase
    def setup
      @controller = MisskeyController.new!
    end

    def scrub(params)
      return @controller.send(:scrub_log_params, Sinatra::IndifferentHash[params])
    end

    # ⚠ ここが本体。Misskey のアクセストークンはボディのキー `i` で来る。
    def test_scrubs_misskey_token
      assert_equal('[FILTERED]', scrub('i' => 'SECRET', 'noteId' => 'abc')['i'])
    end

    def test_scrubs_access_token
      assert_equal('[FILTERED]', scrub('access_token' => 'SECRET')['access_token'])
    end

    def test_scrubs_post_body
      scrubbed = scrub('text' => '本文', 'cw' => '注釈')

      assert_equal('[FILTERED]', scrubbed['text'])
      assert_equal('[FILTERED]', scrubbed['cw'])
    end

    # マスク対象外は素通しする (ログが役に立たなくなるため)。
    def test_keeps_other_params
      assert_equal('abc', scrub('i' => 'SECRET', 'noteId' => 'abc')['noteId'])
    end

    # ⚠⚠ **ここからが #4630。**Slack 互換 webhook が実際に使う Block Kit の本文は
    # `blocks` の入れ子の中にあり、トップレベル走査では素通りしていた。
    # **同じ本文を `text` で送れば伏せられるのに、`blocks` で送ると平文**という
    # 送り方依存の穴だった。
    def test_scrubs_nested_block_kit_text
      scrubbed = scrub(
        'blocks' => [{'type' => 'section', 'text' => {'type' => 'mrkdwn', 'text' => '（本文）'}}],
      )

      assert_equal('[FILTERED]', scrubbed['blocks'][0]['text'])
    end

    def test_scrubs_nested_attachments
      scrubbed = scrub(
        'attachments' => [{'text' => '（本文）', 'image_url' => 'https://example.com/a.png'}],
      )

      assert_equal('[FILTERED]', scrubbed['attachments'][0]['text'])
      assert_equal('https://example.com/a.png', scrubbed['attachments'][0]['image_url'])
    end

    # ⚠⚠ **legacy attachments は `text` 以外も投稿本文になる (#4630・Codex P1)。**
    # `SlackWebhookPayload#format_attachment` が pretext / author_name / title /
    # text / fields[].value / footer を**すべて本文へ組み立てる**ので、`text` だけ
    # 伏せても残りが平文で残る。
    def test_scrubs_legacy_attachment_body_fields
      scrubbed = scrub('attachments' => [{
        'pretext' => '前置き',
        'author_name' => '著者',
        'title' => '見出し',
        'text' => '本文',
        'fields' => [{'title' => '項目', 'value' => '値'}],
        'footer' => '脚注',
      }])
      attachment = scrubbed['attachments'][0]

      ['pretext', 'author_name', 'title', 'text', 'footer'].each do |key|
        assert_equal('[FILTERED]', attachment[key], "#{key} が伏せられていない")
      end
      assert_equal('[FILTERED]', attachment['fields'][0]['value'])
      assert_equal('[FILTERED]', attachment['fields'][0]['title'])
    end

    # 入れ子の資格情報も落とす。
    def test_scrubs_nested_token
      scrubbed = scrub('payload' => {'inner' => {'access_token' => 'SECRET'}})

      assert_equal('[FILTERED]', scrubbed['payload']['inner']['access_token'])
    end

    # ⚠ **際限なく潜らない。**外部から渡る JSON なのでスタックを掘り尽くせる。
    # 打ち切りは落とす側へ倒す（読めない深さを平文で通すより伏せる）。
    def test_truncates_deep_nesting
      deep = value = {}
      30.times do
        value['nested'] = {}
        value = value['nested']
      end
      value['text'] = '（本文）'

      dumped = scrub(deep).to_json

      # 本命は「本文がログに出ないこと」。打ち切り位置の off-by-one に依存しない形で見る。
      assert_not_match(/（本文）/, dumped)
      assert_match(/\[FILTERED\]/, dumped)
    end

    # 入れ子を壊さない（マスク対象外はそのまま残る）。
    def test_keeps_nested_other_params
      scrubbed = scrub('blocks' => [{'type' => 'section'}])

      assert_equal('section', scrubbed['blocks'][0]['type'])
    end

    # 処理に使う @params を壊さない (ログ用の複製だけを書き換える)。
    def test_does_not_mutate_source
      params = Sinatra::IndifferentHash['i' => 'SECRET']
      @controller.send(:scrub_log_params, params)

      assert_equal('SECRET', params['i'])
    end
  end
end
