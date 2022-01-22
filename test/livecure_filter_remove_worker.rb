module Mulukhiya
  class LivecureFilterRemoveWorkerTest < TestCase
    def setup
      @worker = LivecureFilterRemoveWorker.new
      sns_class.new.register_filter(phrase: '#実況')
    end

    def test_perform
      assert_raise Ginseng::RequestError do
        @worker.perform(account_id: -1)
      end
      assert_raise Ginseng::RequestError do
        @worker.perform(account_id: test_account.id)
      end
      @worker.perform(account_id: test_account.id, phrase: '#実況')
    end
  end
end
