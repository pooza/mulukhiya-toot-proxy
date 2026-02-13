module Mulukhiya
  class TaggingDictionaryUpdateWorderTest < TestCase
    def setup
      @worker = Worker.create(:tagging_dictionary_update)
    end

    def test_perform
      result = @worker.perform

      assert_kind_of(Hash, result)
      assert_respond_to(result, :matches)
    end
  end
end
