require 'addressable/uri'

module MulukhiyaTootProxy
  class RedisDSN < Addressable::URI
    def db
      return path.sub(%r{^/}, '').to_i
    end
  end
end
