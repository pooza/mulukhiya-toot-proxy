module Mulukhiya
  module SNSMethods
    def status_field
      return Environment.controller_class.status_field
    end

    def notify(message, response = nil)
      message = message.to_yaml unless message.is_a?(String)
      return Environment.info_agent_service&.notify(@sns.account, message, response)
    rescue => e
      logger.error(error: e, message: message)
    end
  end
end
