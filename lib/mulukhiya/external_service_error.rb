module MulukhiyaTootProxy
  class ExternalServiceError < StandardError
    def status
      return 503
    end
  end
end
