module MulukhiyaTootProxy
  class ArtistParserTest < Test::Unit::TestCase
    def test_parse
      parser = ArtistParser.new('キュアソード/剣崎真琴(CV:宮本佳那子)')
      assert_equal(parser.parse, ['#キュアソード', '#剣崎真琴', 'CV:#宮本佳那子'])

      parser = ArtistParser.new('秋元こまち(CV:永野 愛)')
      assert_equal(parser.parse, ['#秋元こまち', 'CV:#永野愛'])

      parser = ArtistParser.new('沖 佳苗(as キュアピーチ)')
      assert_equal(parser.parse, ['CV:#沖佳苗', '#キュアピーチ'])

      parser = ArtistParser.new('ゆいま～る ふぁみり (宮本佳那子、具志堅用高、ROLLY)')
      assert_equal(parser.parse, ['#ゆいま_る_ふぁみり', '#宮本佳那子', '#具志堅用高', '#ROLLY'])

      parser = ArtistParser.new('歌:バッティ(CV:遊佐浩二)')
      assert_equal(parser.parse, ['#バッティ', 'CV:#遊佐浩二'])

      parser = ArtistParser.new('スパルダ(CV: 小林ゆう)')
      assert_equal(parser.parse, ['#スパルダ', 'CV:#小林ゆう'])
    end
  end
end
