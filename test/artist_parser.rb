module MulukhiyaTootProxy
  class ArtistParserTest < Test::Unit::TestCase
    def test_parse
      parser = ArtistParser.new('キュア・カルテット')
      assert_equal(parser.parse, ['#キュア_カルテット'])

      parser = ArtistParser.new('キュアソード/剣崎真琴(CV:宮本佳那子)')
      assert_equal(parser.parse, ['#キュアソード', '#剣崎真琴', 'CV:#宮本佳那子'])

      parser = ArtistParser.new('秋元こまち(CV:永野 愛)')
      assert_equal(parser.parse, ['#秋元こまち', 'CV:#永野愛'])

      parser = ArtistParser.new('沖 佳苗(as キュアピーチ)')
      assert_equal(parser.parse, ['CV:#沖佳苗', '#キュアピーチ'])

      parser = ArtistParser.new('ゆいま～る ふぁみり (宮本佳那子、具志堅用高、ROLLY)')
      assert_equal(parser.parse, ['#ゆいま_る_ふぁみり', '#宮本佳那子', '#具志堅用高', '#ROLLY'])

      parser = ArtistParser.new('ハピネスチャージプリキュア!(CV:中島 愛、潘 めぐみ、北川里奈、戸松 遥)')
      assert_equal(parser.parse, ['#ハピネスチャージプリキュア', 'CV:#中島愛', 'CV:#潘めぐみ', 'CV:#北川里奈', 'CV:#戸松遥'])

      parser = ArtistParser.new('歌:北川理恵 コーラス:五條真由美、うちやえゆか')
      assert_equal(parser.parse, ['#北川理恵', 'コーラス:#五條真由美', 'コーラス:#うちやえゆか'])

      parser = ArtistParser.new('歌:バッティ(CV:遊佐浩二)、スパルダ(CV: 小林ゆう)、語り:ガメッツ(CV:中田譲治)')
      assert_equal(parser.parse, ['#バッティ', 'CV:#遊佐浩二', '#スパルダ', 'CV:#小林ゆう', '#ガメッツ', 'CV:#中田譲治'])

      parser = ArtistParser.new('うちやえゆか、池田彩、五條真由美、工藤真由')
      assert_equal(parser.parse, ['#うちやえゆか', '#池田彩', '#五條真由美', '#工藤真由'])

      parser = ArtistParser.new('泉こなた(平野綾)、柊かがみ(加藤英美里)、柊つかさ(福原香織)、高良みゆき(遠藤綾)')
      assert_equal(parser.parse, ['#泉こなた', '#平野綾', '#柊かがみ', '#加藤英美里', '#柊つかさ', '#福原香織', '#高良みゆき', '#遠藤綾'])
    end
  end
end
