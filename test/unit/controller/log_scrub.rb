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

    # 処理に使う @params を壊さない (ログ用の複製だけを書き換える)。
    def test_does_not_mutate_source
      params = Sinatra::IndifferentHash['i' => 'SECRET']
      @controller.send(:scrub_log_params, params)

      assert_equal('SECRET', params['i'])
    end
  end
end
