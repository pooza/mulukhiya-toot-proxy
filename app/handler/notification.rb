module MulukhiyaTootProxy
  class NotificationHandler < Handler
    def exec(body, headers = {})
      require 'worker/notification_worker'
      ::NotificationWorker.perform_async(1)
      increment!
    end
  end
end
