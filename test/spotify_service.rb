module MulukhiyaTootProxy
  class SpotifyServiceTest < Test::Unit::TestCase
    def test_create_tags
      assert_equal(
        SpotifyService.create_tags('キュアソード/剣崎真琴(CV:宮本佳那子)'),
        ['#キュアソード', '#剣崎真琴', 'CV:#宮本佳那子'],
      )
      assert_equal(
        SpotifyService.create_tags('秋元こまち(CV:永野 愛)'),
        ['#秋元こまち', 'CV:#永野愛'],
      )
    end
  end
end
