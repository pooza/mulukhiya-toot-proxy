module Mulukhiya
  class UserDecorationInitializeWorker < Worker
    sidekiq_options retry: false

    def disable?
      return true unless controller_class.decoration?
      return super
    end

    def perform(params = {})
    end
  end
end
