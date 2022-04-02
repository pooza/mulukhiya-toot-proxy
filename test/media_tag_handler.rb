module Mulukhiya
  class MediaTagHandlerTest < TestCase
    def setup
      @handler = Handler.create(:media_tag)
    end

    def test_all
      config['/handler/media_tag/disable'] = false
      assert_kind_of(Enumerator, @handler.all)
      assert_predicate(@handler.all.to_h[:image], :present?)
      assert_predicate(@handler.all.to_h[:video], :present?)
      assert_predicate(@handler.all.to_h[:audio], :present?)

      config['/handler/media_tag/disable'] = true
      assert_kind_of(Enumerator, @handler.all)
      assert_nil(@handler.all.to_h[:image])
      assert_nil(@handler.all.to_h[:video])
      assert_nil(@handler.all.to_h[:audio])
    end
  end
end
