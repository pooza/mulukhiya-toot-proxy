module MulukhiyaTootProxy
  class NotifyHandler < Handler
    def exec(body, headers = {})
      NotifyWorker.perform_async(1)
    end
  end
end
