module Mulukhiya
  class AnnictPollingWorkerTest < TestCase
    def setup
      @worker = AnnictPollingWorker.new
    end

    def test_accounts
      @worker.accounts do |account|
        assert_kind_of(Environment.account_class, account)
      end
    end

    def test_perform
      @worker.perform
    end
  end
end
