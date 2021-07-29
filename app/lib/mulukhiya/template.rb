module Mulukhiya
  class Template < Ginseng::Template
    include Package
    include SNSMethods

    def self.assign_values
      return {
        package: Package,
        controller: controller_class,
        sns: info_agent_service,
        env: Environment,
        crypt: Crypt,
        config: config,
        annict: AnnictService.new,
        dic: TaggingDictionary.new,
      }
    end
  end
end
