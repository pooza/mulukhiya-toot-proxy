require 'slim'

module Mulukhiya
  class SlimRenderer < Ginseng::Web::HTMLRenderer
    include Package
    attr_reader :params

    def initialize(template = nil)
      Slim::Engine.set_options(
        shortcut: shortcuts,
      )
      @status = 200
      @params = {}.with_indifferent_access
      self.template = template if template
    end

    def template=(name)
      path = create_path(name)
      raise Ginseng::RenderError, "Template '#{name}' not found" unless File.exist?(path)
      @slim = Slim::Template.new(path)
    end

    def []=(key, value)
      @params[key] = value
    end

    def to_s
      raise Ginseng::RenderError, 'Template undefined' unless @slim
      return @slim.render({}, assign_values)
    end

    def self.render(name)
      return SlimRenderer.new(name).to_s
    rescue Ginseng::RenderError
      return nil
    end

    private

    def create_path(name)
      return File.join(Environment.dir, 'views', name.sub(/\.slim$/i, '') + '.slim')
    end

    def shortcuts
      return {
        '#' => {tag: 'div', attr: 'id'},
        '.' => {tag: 'div', attr: 'class'},
      }
    end

    def assign_values
      return {
        params: params,
        slim: SlimRenderer,
        package: Package,
        controller: Environment.controller_class
        crypt: Crypt,
      }
    end
  end
end
