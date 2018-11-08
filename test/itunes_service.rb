module MulukhiyaTootProxy
  class ItunesServiceTest < Test::Unit::TestCase
    def test_create_tags
      assert_equal(
        ItunesService.create_tags('歌:バッティ(CV:遊佐浩二)、スパルダ(CV: 小林ゆう)、語り:ガメッツ(CV:中田譲治)'),
        ['#バッティ', 'CV:#遊佐浩二', '#スパルダ', 'CV:#小林ゆう', '#ガメッツ', 'CV:#中田譲治'],
      )
    end
  end
end
