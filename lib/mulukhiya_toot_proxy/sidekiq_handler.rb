module MulukhiyaTootProxy
  class SidekiqHandler < Handler
    def exec(body, headers = {})
      @body = body
      @headers = headers
      return unless executable?
      require worker_path
      worker_name.constantize.perform_async(param)
      increment!
    end

    def worker_name
      return self.class.to_s.sub(/Handler$/, 'Worker')
    end

    def worker_path
      return "worker/#{worker_name.sub(/^MulukhiyaTootProxy::/, '').underscore}"
    end

    def executable?
      raise ImprementError, "#{__method__}が未実装です。"
    end

    def param
      raise ImprementError, "#{__method__}が未実装です。"
    end
  end
end
