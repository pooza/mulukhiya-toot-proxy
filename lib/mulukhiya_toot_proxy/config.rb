module MulukhiyaTootProxy
  class Config < Ginseng::Config
    include Package

    def disable?(handler_name)
      return self["/handler/#{handler_name}/disable"]
    end
  end
end
