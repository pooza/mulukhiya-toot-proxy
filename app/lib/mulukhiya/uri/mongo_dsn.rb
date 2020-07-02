module Mulukhiya
  class MongoDSN < Ginseng::URI
    def dbname
      return path.sub(%r{^/}, '')
    end

    def valid?
      return absolute? && scheme == 'mongo'
    end
  end
end
