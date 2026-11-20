module Mulukhiya
  class DecorationInitializeWorkerTest < TestCase
    def disable?
      return true unless Environment.misskey_type?
      return true unless Environment.dbms_class&.config?
      return true unless test_token
      return super
    end

    def setup
      return if disable?
      @worker = Worker.create(:decoration_initialize)
    end

    def test_worker_config
      worker = Worker.create(:decoration_initialize)

      assert_not_nil(worker)
      assert_equal('%{program}のために付けた%{decoration}を、番組が終わったので外しました。', worker.worker_config(:message))
    end
  end
end
