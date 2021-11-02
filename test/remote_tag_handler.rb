module Mulukhiya
  class RemoteTagHandlerTest < TestCase
    def setup
      @handler = Handler.create('remote_tag')
    end

    def test_handle_pre_toot
      @handler.handle_pre_toot(status_field => 'キュアホワイト「プリキュアの美しき魂が」')
      assert_equal(@handler.addition_tags, Set['precure_fun', 'キュアホワイト', '雪城 ほのか', 'ゆかな'])

      @handler.handle_pre_toot(status_field => 'ダイの大冒険 このあと9時30分から、テレビ東京系列にて第55話「黒の核晶（コア）」放送！')
      assert_equal(@handler.addition_tags, Set['delmulin', 'ダイ', '種﨑 敦美', 'ダイの大冒険', '黒の核晶'])
    end
  end
end
