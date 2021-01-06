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

    def account_class
      return Environment.account_class
    end

    def status_class
      return Environment.status_class
    end

    def attachment_class
      return Environment.attachment_class
    end

    def access_token_class
      return Environment.access_token_class
    end

    def hash_tag_class
      return Environment.hash_tag_class
    end

    def notify(message, response = nil)
      message = message.to_yaml unless message.is_a?(String)
      return info_agent_service.notify(@sns.account, message, response)
    rescue => e
      logger.error(error: e, message: message)
    end

    def info_agent_service
      service = Environment.sns_service_class.new
      service.token = account_class.info_token
      return service
    end

    def test_account
      return account_class.test_account
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
