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
  end
end
