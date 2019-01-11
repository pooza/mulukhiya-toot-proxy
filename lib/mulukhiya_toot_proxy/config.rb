module MulukhiyaTootProxy
  class Config < Ginseng::Config
    private

    def env_name
      return 'MulukhiyaTootProxy::Environment'
    end
  end
end
