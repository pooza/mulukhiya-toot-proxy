module Mulukhiya
  module SNSMethods
    def status_field
      return Environment.controller_class.status_field
    end

    def notify(message, response = nil)
      message = message.to_yaml unless message.is_a?(String)
      return info_agent_service.notify(@sns.account, message, response)
    rescue => e
      logger.error(error: e, message: message)
    end

    def info_agent_service
      service = Environment.sns_service_class.new
      service.token = config['/agent/info/token']
      return service
    end

    def test_account
      return Environment.account_class.test_account
    end
  end
end
