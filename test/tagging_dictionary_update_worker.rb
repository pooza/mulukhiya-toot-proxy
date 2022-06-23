module Mulukhiya
  class TaggingDictionaryUpdateWorderTest < TestCase
    def setup
      @worker = Worker.create(:tagging_dictionary_update)
    end

    def test_perform
      assert_kind_of(Hash, @worker.perform)
    end
  end
end
