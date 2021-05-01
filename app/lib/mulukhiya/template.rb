module Mulukhiya
  class Template < Ginseng::Template
    include Package
    include SNSMethods

    def initialize(name)
      super
      self.params = assign_values
    end

    def self.assign_values
      return {
        package: Package,
        controller: controller_class,
        sns: info_agent_service,
        env: Environment,
        crypt: Crypt,
        config: config,
        annict: AnnictService.new,
      }
    end
  end
end
