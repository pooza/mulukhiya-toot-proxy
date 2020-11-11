module Mulukhiya
  class StringTest < TestCase
    def test_escape_toot
      assert_equal('#キボウレインボウ#'.escape_toot, '# キボウレインボウ#')
      assert_equal('IDOLM@STER'.escape_toot, 'IDOLM@ STER')
    end
  end
end
