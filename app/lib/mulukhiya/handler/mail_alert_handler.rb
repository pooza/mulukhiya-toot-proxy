module Mulukhiya
  class MailAlertHandler < AlertHandler
    def disable?
      return true unless Mailer.config?
      return true unless exist?
      return super
    end

    def alert(params = {})
      mailer = Mailer.new
      mailer.prefix = sns.node_name
      mailer.subject = "#{error.source_class} #{error.message}"
      mailer.body = error.backtrace
      mailer.deliver
    end

    def receipt
      return handler_config(:to) || sns.maintainer_email
    end

    def exist?
      return File.exist?(handler_config(:sendmail_bin))
    end
  end
end
