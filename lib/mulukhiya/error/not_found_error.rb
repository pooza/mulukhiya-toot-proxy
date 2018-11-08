module MulukhiyaTootProxy
  class NotFoundError < StandardError
    def status
      return 404
    end
  end
end
