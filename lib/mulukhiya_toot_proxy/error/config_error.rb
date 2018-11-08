module MulukhiyaTootProxy
  class ConfigError < StandardError
    def status
      return 500
    end
  end
end
