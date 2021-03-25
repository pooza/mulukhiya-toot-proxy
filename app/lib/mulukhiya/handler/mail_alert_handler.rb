module Mulukhiya
  class MailAlertHandler < AlertHandler
    def disable?
      return true unless config['/alert/mail/to'].present? rescue true
      return super
    end

    def alert(error, params = {})
      mailer = Mailer.new
      mailer.prefix = @sns.info['metadata']['nodeName']
      mailer.subject = "#{error.source_class} #{error.message}"
      mailer.body = error.backtrace
      mailer.deliver
    end
  end
end
