module Mulukhiya
  class TaggingDictionaryUpdateTest < TestCase
    def setup
      @worker = TaggingDictionaryUpdateWorker.new
    end

    def test_perform
      assert_kind_of(Hash, @worker.perform)
    end
  end
end
