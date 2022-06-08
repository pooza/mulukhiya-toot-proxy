module Mulukhiya
  class FilterUnregisterWorkerTest < TestCase
    def disable?
      return true unless controller_class.filter?
      return super
    end

    def setup
      @worker = Worker.create(:filter_unregister)
      sns_class.new.register_filter(tag: '実況')
    end

    def test_perform
      assert_raise Ginseng::RequestError do
        @worker.perform(account_id: -1)
      end
      assert_raise Ginseng::RequestError do
        @worker.perform(account_id: test_account.id)
      end
      @worker.perform(account_id: test_account.id, tag: '実況')
    end
  end
end
