module MulukhiyaTootProxy
  class ArtistParserTest < Test::Unit::TestCase
    def test_parse
      tags = TagContainer.new
      tags.concat(ArtistParser.new('キュア・カルテット').parse)
      assert_equal(tags.create_tags, ['#キュア_カルテット'])

      tags = TagContainer.new
      tags.concat(ArtistParser.new('キュアソード/剣崎真琴(CV:宮本佳那子)').parse)
      assert_equal(tags.create_tags, ['#キュアソード', '#剣崎真琴', '#宮本佳那子'])

      tags = TagContainer.new
      tags.concat(ArtistParser.new('秋元こまち(CV:永野 愛)').parse)
      assert_equal(tags.create_tags, ['#秋元こまち', '#永野愛'])

      tags = TagContainer.new
      tags.concat(ArtistParser.new('沖 佳苗(as キュアピーチ)').parse)
      assert_equal(tags.create_tags, ['#沖佳苗', '#キュアピーチ'])

      tags = TagContainer.new
      tags.concat(ArtistParser.new('ゆいま～る ふぁみり (宮本佳那子、具志堅用高、ROLLY)').parse)
      assert_equal(tags.create_tags, ['#ゆいま_るふぁみり', '#宮本佳那子', '#具志堅用高', '#ROLLY'])

      tags = TagContainer.new
      tags.concat(ArtistParser.new('ハピネスチャージプリキュア!(CV:中島 愛、潘 めぐみ、北川里奈、戸松 遥)').parse)
      assert_equal(tags.create_tags, ['#ハピネスチャージプリキュア', '#中島愛', '#潘めぐみ', '#北川里奈', '#戸松遥'])

      tags = TagContainer.new
      tags.concat(ArtistParser.new('歌:北川理恵 コーラス:五條真由美、うちやえゆか').parse)
      assert_equal(tags.create_tags, ['#北川理恵', '#五條真由美', '#うちやえゆか'])

      tags = TagContainer.new
      tags.concat(ArtistParser.new('歌:バッティ(CV:遊佐浩二)、スパルダ(CV: 小林ゆう)、語り:ガメッツ(CV:中田譲治)').parse)
      assert_equal(tags.create_tags, ['#バッティ', '#遊佐浩二', '#スパルダ', '#小林ゆう', '#ガメッツ', '#中田譲治'])

      tags = TagContainer.new
      tags.concat(ArtistParser.new('うちやえゆか、池田彩、五條真由美、工藤真由').parse)
      assert_equal(tags.create_tags, ['#うちやえゆか', '#池田彩', '#五條真由美', '#工藤真由'])

      tags = TagContainer.new
      tags.concat(ArtistParser.new('泉こなた(平野綾)、柊かがみ(加藤英美里)、柊つかさ(福原香織)、高良みゆき(遠藤綾)').parse)
      assert_equal(tags.create_tags, ['#泉こなた', '#平野綾', '#柊かがみ', '#加藤英美里', '#柊つかさ', '#福原香織', '#高良みゆき', '#遠藤綾'])

      tags = TagContainer.new
      tags.concat(ArtistParser.new('工藤真由(コーラス:五條真由美、うちやえゆか)').parse)
      assert_equal(tags.create_tags, ['#工藤真由', '#五條真由美', '#うちやえゆか'])

      tags = TagContainer.new
      tags.concat(ArtistParser.new('キュア・レインボーズ (コーラス:ヤング・フレッシュ)').parse)
      assert_equal(tags.create_tags, ['#キュア_レインボーズ', '#ヤング_フレッシュ'])

      tags = TagContainer.new
      tags.concat(ArtistParser.new('琴爪ゆかり(CV:藤田咲)&剣城あきら(CV:森なな子)').parse)
      assert_equal(tags.create_tags, ['#琴爪ゆかり', '#藤田咲', '#剣城あきら', '#森なな子'])
    end
  end
end
