module Mulukhiya
  class AnnictPollingWorkerTest < TestCase
    def disable?
      return true unless controller_class.annict?
      return super
    end

    def setup
      return if disable?
      @worker = Worker.create(:annict_polling)
    end

    def test_perform
      @worker.perform
    end
  end
end
