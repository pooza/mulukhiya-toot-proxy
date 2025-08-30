module Mulukhiya
  class ScriptRenderer < Ginseng::Web::ScriptRenderer
    include Package

    attr_reader :name

    def dir
      return File.join(environment_class.dir, 'public/mulukhiya/script')
    end
  end
end
