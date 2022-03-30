module Mulukhiya
  module SNSMethods
    def controller_class
      return Environment.controller_class
    end

    def sns_class
      return Environment.sns_class
    end

    def parser_class
      return Environment.parser_class
    end

    def status_field
      return controller_class.status_field
    end

    def visibility_field
      return controller_class.visibility_field
    end

    def reply_to_field
      return controller_class.reply_to_field
    end

    def attachment_field
      return controller_class.attachment_field
    end

    def poll_field
      return controller_class.poll_field
    end

    def poll_options_field
      return controller_class.poll_options_field
    end

    def spoiler_field
      return controller_class.spoiler_field
    end

    def chat_field
      return controller_class.chat_field
    end

    def status_key
      return controller_class.status_key
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

    def create_status_uri(src)
      dest = TootURI.parse(src.to_s)
      dest = NoteURI.parse(dest) unless dest&.valid?
      return dest if dest.valid?
    end

    def notify(message, options = {})
      options[:accounts] ||= Environment.account_class.administrators if options[:administrators]
      options[:accounts] ||= [@sns.account]
      message = message.deep_stringify_keys.to_yaml unless message.is_a?(String)
      options[:accounts].each do |account|
        return info_agent_service.notify(account, message, options.deep_symbolize_keys)
      rescue => e
        e.log(message:)
      end
    end

    def info_agent_service
      service = Environment.sns_service_class.new
      service.token = account_class.info_token
      return service
    end

    def test_account
      return account_class.test_account
    rescue => e
      e.log
    end

    def self.included(base)
      base.extend(ClassMethods)
    end

    module ClassMethods
      def controller_class
        return Environment.controller_class
      end

      def sns_class
        return Environment.sns_class
      end

      def info_agent_service
        service = Environment.sns_service_class.new
        service.token = Environment.account_class.info_token
        return service
      end
    end
  end
end
