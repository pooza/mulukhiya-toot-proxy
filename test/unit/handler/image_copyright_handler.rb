module Mulukhiya
  class ImageCopyrightHandlerTest < TestCase
    def setup
      @handler = Handler.create(:image_copyright)
      config['/handler/image_copyright/tag'] = 'ダイ大魂の絆'
      config['/handler/image_copyright/message'] = '※画像有 著作権表示 参照のこと'
      config['/handler/image_copyright/url'] = 'https://blog.delmulin.com/articles/魂の絆'
    end

    def test_appendable?
      @handler.clear
      @handler.handle_pre_toot(status_field => 'こんにちは')

      assert_false(@handler.appendable?)

      @handler.clear
      @handler.handle_pre_toot(status_field => '聖王の正体に迫る。 #ダイ大魂の絆')

      assert_false(@handler.appendable?)

      @handler.clear
      @handler.handle_pre_toot(status_field => '聖王画像', attachment_field => [111, 222])

      assert_false(@handler.appendable?)

      @handler.clear
      @handler.handle_pre_toot(status_field => '聖王画像 #ダイ大魂の絆', attachment_field => [111, 222])

      assert_predicate(@handler, :appendable?)
    end

    def test_handle_pre_toot
      payload = {status_field => '聖王画像 #ダイ大魂の絆', attachment_field => [111, 222]}
      @handler.handle_pre_toot(payload)

      assert_equal("※画像有 著作権表示 参照のこと\nhttps://blog.delmulin.com/articles/魂の絆\n\n聖王画像 #ダイ大魂の絆", payload[status_field])
    end
  end
end
