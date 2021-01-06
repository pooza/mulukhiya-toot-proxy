module Mulukhiya
  module SNSMethods
    def controller_class
      return Environment.controller_class
    end

    def status_field
      return controller_class.status_field
    end

    def status_key
      return controller_class.status_key
    end

    def attachment_field
      return controller_class.attachment_field
    end

    def notify(message, response = nil)
      message = message.to_yaml unless message.is_a?(String)
      return info_agent_service.notify(@sns.account, message, response)
    rescue => e
      logger.error(error: e, message: message)
    end

    def info_agent_service
      service = Environment.sns_service_class.new
      service.token = Environment.account_class.info_token
      return service
    end

    def test_account
      return Environment.account_class.test_account
    end

    def self.included(base)
      base.extend(Methods)
    end

    module Methods
      def controller_class
        return Environment.controller_class
      end
    end
  end
end
