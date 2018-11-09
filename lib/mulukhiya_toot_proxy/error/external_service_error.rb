module MulukhiyaTootProxy
  class ExternalServiceError < StandardError
    def status
      return 502
    end
  end
end
