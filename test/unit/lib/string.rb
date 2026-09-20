module Mulukhiya
  class StringTest < TestCase
    def setup
      config['/crypt/encoder'] = 'base64'
    end

    def test_escape_toot
      assert_equal('# キボウレインボウ#', '#キボウレインボウ#'.escape_toot)
      assert_equal('@ pooza こんにちは', '@pooza こんにちは'.escape_toot)
    end

    # 区切りを入れるのは「投稿先が実際にリンク化する # / @」だけ (#4740)。
    # ginseng-fediverse v2.0.1 以前は無条件の gsub(/[@#]/) だったので、
    # リンクにならない @ を含む曲名が IDOLM@ STER のように壊れていた。
    # escape_toot はナウプレの曲名・アルバム名・アーティスト名が通る口なので回帰を張る。
    def test_escape_toot_keeps_non_linking_sigils
      assert_equal('IDOLM@STER', 'IDOLM@STER'.escape_toot)
      assert_equal('H@ppy Together!!!', 'H@ppy Together!!!'.escape_toot)
    end

    def test_crypt
      src = 'hoge'

      assert_equal(src, src.encrypt.decrypt)
    end

    def test_blockquote
      assert_equal("> aaa\n> bbb", "aaa\nbbb".blockquote)
      assert_equal("| aaa\n| bbb", "aaa\nbbb".blockquote('|'))
    end
  end
end
