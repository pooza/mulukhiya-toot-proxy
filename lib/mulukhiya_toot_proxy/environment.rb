module MulukhiyaTootProxy
  class Environment < Ginseng::Environment
    def self.name
      return File.basename(dir)
    end

    def self.dir
      return File.expand_path('../..', __dir__)
    end
  end
end
