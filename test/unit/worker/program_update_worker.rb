module Mulukhiya
  class ProgramUpdateWorkerTest < TestCase
    def disable?
      return true unless controller_class.livecure?
      return super
    end

    def setup
      return if disable?
      @worker = Worker.create(:program_update)
    end

    def test_perform
      @worker.perform

      assert_kind_of(Hash, Program.instance.data)
    end
  end
end
