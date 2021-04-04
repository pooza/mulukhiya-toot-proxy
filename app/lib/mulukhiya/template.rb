module Mulukhiya
  class Template < Ginseng::Template
    include Package
    include SNSMethods

    def initialize(name)
      super
      self['sns'] = info_agent_service
    end
  end
end
