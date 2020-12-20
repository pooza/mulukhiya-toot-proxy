module Mulukhiya
  class StringTest < TestCase
    def setup
      config['/crypt/encoder'] = 'base64'
    end

    def test_escape_toot
      assert_equal('#キボウレインボウ#'.escape_toot, '# キボウレインボウ#')
      assert_equal('IDOLM@STER'.escape_toot, 'IDOLM@ STER')
    end

    def test_crypt
      src = 'hoge'
      assert_equal(src, src.encrypt.decrypt)
    end
  end
end
