module Mulukhiya
  class StringTest < TestCase
    def setup
      config['/crypt/encoder'] = 'base64'
    end

    def test_escape_toot
      assert_equal('# キボウレインボウ#', '#キボウレインボウ#'.escape_toot)
      assert_equal('IDOLM@ STER', 'IDOLM@STER'.escape_toot)
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
