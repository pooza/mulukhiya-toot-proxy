module MulukhiyaTootProxy
  class Config < Ginseng::Config
    def environment_class
      return 'MulukhiyaTootProxy::Environment'
    end
  end
end
