module MulukhiyaTootProxy
  class RedisDSN < Ginseng::URI
    def db
      return path.sub(%r{^/}, '').to_i
    end
  end
end
