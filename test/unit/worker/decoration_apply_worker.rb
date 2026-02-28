module Mulukhiya
  class DecorationApplyWorkerTest < TestCase
    def disable?
      return true unless Environment.misskey_type?
      return true unless Environment.dbms_class&.config?
      return true unless test_token
      return super
    end

    def setup
      return if disable?
      @worker = Worker.create(:decoration_apply)
    end

    def test_worker_config
      worker = Worker.create(:decoration_apply)

      assert_not_nil(worker)
    end
  end
end
