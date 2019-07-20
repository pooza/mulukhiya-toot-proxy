module MulukhiyaTootProxy
  class ValidateError < Ginseng::Error
    def status
      return 422
    end
  end
end
