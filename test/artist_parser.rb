module Mulukhiya
  class ArtistParserTest < TestCase
    def test_parse
      tags = ArtistParser.new('キュア・カルテット').parse
      assert_equal(tags, Set['キュア・カルテット'])

      tags = ArtistParser.new('キュアソード/剣崎真琴(CV:宮本佳那子)').parse
      assert_equal(tags, Set['キュアソード', '剣崎真琴', '宮本佳那子'])

      tags = ArtistParser.new('秋元こまち(CV:永野 愛)').parse
      assert_equal(tags, Set['秋元こまち', '永野 愛'])

      tags = ArtistParser.new('沖 佳苗(as キュアピーチ)').parse
      assert_equal(tags, Set['沖 佳苗', 'キュアピーチ'])

      tags = ArtistParser.new('ゆいま～る ふぁみり (宮本佳那子、具志堅用高、ROLLY)').parse
      assert_equal(tags, Set['ゆいま~る ふぁみり', '宮本佳那子', '具志堅用高', 'ROLLY'])

      tags = ArtistParser.new('ハピネスチャージプリキュア!(CV:中島 愛、潘 めぐみ、北川里奈、戸松 遥)').parse
      assert_equal(tags, Set['ハピネスチャージプリキュア!', '中島 愛', '潘 めぐみ', '北川里奈', '戸松 遥'])

      tags = ArtistParser.new('歌:北川理恵 コーラス:五條真由美、うちやえゆか').parse
      assert_equal(tags, Set['北川理恵', '五條真由美', 'うちやえゆか'])

      tags = ArtistParser.new('歌:バッティ(CV:遊佐浩二)、スパルダ(CV: 小林ゆう)、語り:ガメッツ(CV:中田譲治)').parse
      assert_equal(tags, Set['バッティ', '遊佐浩二', 'スパルダ', '小林ゆう', 'ガメッツ', '中田譲治'])

      tags = ArtistParser.new('うちやえゆか、池田彩、五條真由美、工藤真由').parse
      assert_equal(tags, Set['うちやえゆか', '池田彩', '五條真由美', '工藤真由'])

      tags = ArtistParser.new('泉こなた(平野綾)、柊かがみ(加藤英美里)、柊つかさ(福原香織)、高良みゆき(遠藤綾)').parse
      assert_equal(tags, Set['泉こなた', '平野綾', '柊かがみ', '加藤英美里', '柊つかさ', '福原香織', '高良みゆき', '遠藤綾'])

      tags = ArtistParser.new('工藤真由(コーラス:五條真由美、うちやえゆか)').parse
      assert_equal(tags, Set['工藤真由', '五條真由美', 'うちやえゆか'])

      tags = ArtistParser.new('キュア・レインボーズ (コーラス:ヤング・フレッシュ)').parse
      assert_equal(tags, Set['キュア・レインボーズ', 'ヤング・フレッシュ'])

      tags = ArtistParser.new('琴爪ゆかり(CV:藤田咲)&剣城あきら(CV:森なな子)').parse
      assert_equal(tags, Set[])

      tags = ArtistParser.new('キュアミラクル(CV:高橋李依)・キュアマジカル(CV:堀江由衣)').parse
      assert_equal(tags, Set[])

      tags = ArtistParser.new('宮本佳那子／山野さと子／内田順子／他').parse
      assert_equal(tags, Set['宮本佳那子', '山野さと子', '内田順子', '他'])
    end
  end
end
