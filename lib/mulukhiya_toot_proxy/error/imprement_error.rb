module MulukhiyaTootProxy
  class ImprementError < StandardError
    def status
      return 500
    end
  end
end
