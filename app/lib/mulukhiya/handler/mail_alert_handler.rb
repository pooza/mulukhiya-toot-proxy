module Mulukhiya
  class MailAlertHandler < Handler
    def handle_alert(error, params = {})
      mailer = Mailer.new
      mailer.prefix = @sns.info['metadata']['nodeName']
      mailer.subject = "#{error.source_class} #{error.message}"
      mailer.body = error.backtrace
      mailer.deliver
      return error
    end

    def disable?
      return true unless config['/alert/mail/to'].present?
      return super
    rescue Ginseng::ConfigError
      return true
    end
  end
end
