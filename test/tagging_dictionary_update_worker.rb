module Mulukhiya
  class TaggingDictionaryUpdateTest < TestCase
    def setup
      @worker = TaggingDictionaryUpdateWorker.new
    end

    def test_perform
      assert_predicate(@worker.perform, :present?)
    end
  end
end
