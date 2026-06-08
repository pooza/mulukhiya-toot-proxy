module Mulukhiya
  class PronunciationDictionaryUpdateWorkerTest < TestCase
    def setup
      @worker = Worker.create(:pronunciation_dictionary_update)
    end

    def test_disable
      assert_boolean(@worker.disable?)
    end

    def test_perform_when_disabled
      # word_suggest/urls 未設定 (テスト既定) では disable? が true で no-op。
      return unless @worker.disable?

      assert_nil(@worker.perform)
    end
  end
end
