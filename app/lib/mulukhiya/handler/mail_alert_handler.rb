module Mulukhiya
  class MailAlertHandler < Handler
    def handle_alert(error, params = {})
      mailer = Mailer.new
      mailer.prefix = @sns.info['metadata']['nodeName']
      mailer.deliver("#{error.source_class} #{error.message}", error.backtrace)
      return error
    end

    def disable?
      return false unless config['/alert/mail/to'] rescue false
      return super
    end
  end
end
